#' @file fn_glue_bridge.R
#' @use yaml
#' @use DBI
#' @use duckdb
#' @use digest
#' @requires fn_apply_mapping.R
#' @requires fn_validate_against_schema.R
#' @requires fn_hash_prerawdata_schema.R
#' @principle MP102 v1.2 (consumer of bound spec); MP156; MP154; MP029
#' @author Claude (#489 Phase 4)
#'
#' Deterministic R interpreter for prerawdata -> canonical raw mappings.
#' NO LLM CALL, NO eval/parse, NO REMOTE NETWORK ACCESS at runtime.
#' All intelligence lives in the committed bridge yaml + canonical schema yaml.

#' Run a glue bridge end-to-end
#'
#' @param company Character: company code (e.g. "QEF_DESIGN")
#' @param platform Character: platform_id (e.g. "amz")
#' @param source Character: bridge file basename without extension
#'        (e.g. "sales" -> reads sales.bridge.yaml). Often equal to datatype
#'        but bridges MAY exist per source-document (e.g. "sales_2026_q1").
#' @param prerawdata data.frame with the prerawdata source columns. The
#'        caller is responsible for loading from gsheet/xlsx/csv/api before
#'        passing in. (Loading is intentionally outside this function so
#'        the interpreter stays pure / testable.)
#' @param target_con DBI connection where the canonical raw table lives.
#'        Must already have the canonical table created (via the committed
#'        DDL in `01_db/raw_schema/_generated/`).
#' @param bridges_root Character: path to bridges/ directory. Defaults to
#'        the canonical authoring location.
#' @return List with:
#'        n_input_rows   — rows in prerawdata
#'        n_output_rows  — rows successfully INSERTed
#'        n_errors       — validation errors
#'        errors         — data.frame of per-row validation issues
#'        bridge_path    — absolute path to the bridge yaml used
#' @export
fn_glue_bridge <- function(company,
                           platform,
                           source,
                           prerawdata,
                           target_con,
                           bridges_root = NULL) {
  if (!is.character(company) || length(company) != 1) {
    stop("company must be a single character string")
  }
  if (!is.character(platform) || length(platform) != 1) {
    stop("platform must be a single character string")
  }
  if (!is.character(source) || length(source) != 1) {
    stop("source must be a single character string")
  }
  if (!is.data.frame(prerawdata)) {
    stop("prerawdata must be a data.frame")
  }
  if (!inherits(target_con, "DBIConnection")) {
    stop("target_con must be a DBI connection")
  }

  # ----- Resolve bridge yaml path -----
  if (is.null(bridges_root)) {
    # Try to locate via common path patterns
    here <- normalizePath(getwd())
    candidates <- c(
      file.path(here, "shared", "global_scripts", "01_db", "raw_schema",
                "_authoring", "bridges"),
      file.path(here, "01_db", "raw_schema", "_authoring", "bridges"),
      # Walk up from this script's location
      file.path(dirname(sys.frame(1)$ofile %||% "."),
                "..", "..", "01_db", "raw_schema", "_authoring", "bridges")
    )
    for (cand in candidates) {
      if (dir.exists(cand)) {
        bridges_root <- cand
        break
      }
    }
    if (is.null(bridges_root)) {
      stop("Could not locate bridges root; pass `bridges_root` explicitly. ",
           "Canonical: shared/global_scripts/01_db/raw_schema/_authoring/bridges/")
    }
  }

  bridge_path <- file.path(bridges_root, company, platform,
                           paste0(source, ".bridge.yaml"))
  if (!file.exists(bridge_path)) {
    stop("Bridge yaml not found: ", bridge_path,
         "\nGenerate via the glue-bridge Claude skill, then commit.")
  }

  bridge <- yaml::read_yaml(bridge_path)

  # ----- Reviewer guard (MP102 v1.3 Change Discipline) -----
  # Two acceptable forms (per spectra change `glue-bridge-self-converging-review` / #500):
  #   1. Structured (canonical): yaml mapping with required fields including
  #      findings_summary.{critical,high} == 0 AND sibling *.bridge.review.md
  #      with "## Verdict: CONVERGED" or "## Verdict: DIMINISHING" line.
  #   2. Legacy string (deprecated until 2026-07-31): non-empty string outside
  #      placeholder blacklist. After cutoff date the runtime rejects it.
  reviewed_by <- bridge$reviewed_by
  LEGACY_CUTOFF <- as.Date("2026-07-31")

  if (is.list(reviewed_by)) {
    # Structured form
    fs <- reviewed_by$findings_summary
    if (!is.list(fs)) {
      stop("Bridge yaml ", bridge_path,
           " has structured reviewed_by but missing findings_summary block. ",
           "Regenerate via /glue-bridge skill (per MP102 v1.3).")
    }
    fs_critical <- as.integer(fs$critical %||% NA_integer_)
    fs_high <- as.integer(fs$high %||% NA_integer_)
    if (is.na(fs_critical) || is.na(fs_high)) {
      stop("Bridge yaml ", bridge_path,
           " findings_summary requires integer fields `critical` and `high` ",
           "(per MP102 v1.3).")
    }
    if (fs_critical > 0L || fs_high > 0L) {
      stop("Bridge yaml ", bridge_path,
           " has unresolved findings: ", fs_critical, " CRITICAL, ",
           fs_high, " HIGH. Bridge is NOT ship-ready ",
           "(per MP102 v1.3 Change Discipline). Re-run /glue-bridge to converge.")
    }

    # Verify sibling review log exists with proper verdict
    bridge_dir <- dirname(bridge_path)
    artifact_ref <- as.character(reviewed_by$review_artifacts %||% "")
    if (!nzchar(artifact_ref)) {
      stop("Bridge yaml ", bridge_path,
           " structured reviewed_by missing review_artifacts field.")
    }
    artifact_resolved <- if (startsWith(artifact_ref, "/")) artifact_ref
                        else file.path(bridge_dir, artifact_ref)
    if (!file.exists(artifact_resolved)) {
      stop("Bridge review log not found at ", artifact_resolved,
           " (referenced by ", bridge_path, "). ",
           "Audit trail is required for runtime use (per MP102 v1.3).")
    }
    log_lines <- readLines(artifact_resolved, warn = FALSE)
    has_verdict <- any(grepl("^## Verdict:\\s*(CONVERGED|DIMINISHING)",
                             log_lines, ignore.case = TRUE))
    if (!has_verdict) {
      stop("Bridge review log ", artifact_resolved,
           " lacks `## Verdict: CONVERGED` or `## Verdict: DIMINISHING`. ",
           "Bridge is not ship-ready (per MP102 v1.3).")
    }

  } else {
    # Legacy string form (or NULL/missing)
    rb_str <- as.character(reviewed_by %||% "")
    if (!nzchar(rb_str) ||
        rb_str %in% c("AI", "ai", "REQUIRES_HUMAN_REVIEW",
                       "TBD", "unknown")) {
      stop("Bridge yaml ", bridge_path,
           " has reviewed_by = '", rb_str, "'. ",
           "A reviewer identifier is required before runtime use. ",
           "Use /glue-bridge skill to produce a structured form (MP102 v1.3) ",
           "or provide a real human identifier.")
    }
    if (Sys.Date() > LEGACY_CUTOFF) {
      stop("Bridge yaml ", bridge_path,
           " uses legacy string reviewed_by = '", rb_str,
           "' which is rejected after 2026-07-31. ",
           "Migrate via /glue-bridge skill (per MP102 v1.3).")
    }
    # else: legacy string accepted with implicit deprecation (warning emitted by validator,
    # not by runtime — runtime stays quiet to avoid spam)
  }

  # ----- Drift check (design D4) -----
  expected_fp <- bridge$prerawdata_source$schema_fingerprint
  if (is.null(expected_fp) || is.null(expected_fp$value)) {
    stop("Bridge yaml ", bridge_path,
         " missing prerawdata_source.schema_fingerprint. Regenerate.")
  }
  src_cols <- colnames(prerawdata)
  # DA-NEW 3.1 (qef-batch-bridges-ensemble 2026-05-05) fix:
  # Use the same helper that the generator uses, otherwise the runtime
  # fingerprint diverges from the codegen fingerprint for any CSV with
  # all-NA columns (R defaults class(empty) = "logical", but generator
  # normalizes to "character"). Without this, every product_attributes_*
  # bridge halts at false-positive drift even when source is unchanged.
  src_types <- infer_column_types_for_fingerprint(prerawdata)
  actual_fp <- hash_prerawdata_schema(src_cols, src_types)
  drift_msg <- fingerprint_diff_message(expected_fp, actual_fp)
  if (nzchar(drift_msg)) {
    stop(drift_msg)
  }

  # ----- Load canonical schema + extension -----
  schema_path_yaml <- bridge$canonical_target$schema_yaml_path %||% ""
  schema_path <- ""
  if (nzchar(schema_path_yaml) && file.exists(schema_path_yaml)) {
    schema_path <- schema_path_yaml
  } else if (nzchar(schema_path_yaml)) {
    # Bridge yaml gives path like "01_db/raw_schema/.../product_attribute_schemas.yaml"
    # Resolve relative to global_scripts root (4 levels up from bridges_root):
    #   bridges_root: shared/global_scripts/01_db/raw_schema/_authoring/bridges
    #   global_scripts root: shared/global_scripts
    gs_root <- dirname(dirname(dirname(dirname(bridges_root))))
    candidate <- file.path(gs_root, schema_path_yaml)
    if (file.exists(candidate)) {
      schema_path <- candidate
    }
  }
  if (!nzchar(schema_path) || !file.exists(schema_path)) {
    # Final fallback: try canonical core_schemas.yaml (one level up from bridges)
    schema_path <- file.path(dirname(dirname(bridges_root)),
                             "core_schemas.yaml")
  }
  if (!file.exists(schema_path)) {
    stop("Cannot resolve canonical_target.schema_yaml_path from bridge yaml. Tried: ",
         schema_path_yaml, " and fallback core_schemas.yaml")
  }
  schema_doc <- yaml::read_yaml(schema_path)
  datatype <- bridge$canonical_target$datatype
  if (is.null(datatype) || !datatype %in% names(schema_doc)) {
    stop("Bridge canonical_target.datatype '", datatype %||% "<NULL>",
         "' not found in canonical schema")
  }
  required_fields <- schema_doc[[datatype]]$required_fields
  optional_fields <- schema_doc[[datatype]]$optional_fields %||% list()

  # Per #633 fix: ext_path resolution needs bridges_root-relative fallback,
  # mirroring schema_path resolution at lines 192-211. Bridge yaml stores path
  # relative to shared/global_scripts/; runtime cwd may differ. Without
  # fallback, ext_fields silently becomes empty list and platform extension
  # fields are dropped from INSERT (causing NOT NULL violations downstream).
  ext_fields <- list()
  ext_path_yaml <- bridge$canonical_target$platform_extension_yaml_path %||% ""
  ext_path <- ""
  if (nzchar(ext_path_yaml) && file.exists(ext_path_yaml)) {
    ext_path <- ext_path_yaml
  } else if (nzchar(ext_path_yaml)) {
    # Resolve relative to global_scripts root (same logic as schema_path above)
    gs_root <- dirname(dirname(dirname(dirname(bridges_root))))
    candidate <- file.path(gs_root, ext_path_yaml)
    if (file.exists(candidate)) {
      ext_path <- candidate
    }
  }
  if (nzchar(ext_path) && file.exists(ext_path)) {
    ext_doc <- yaml::read_yaml(ext_path)
    if (datatype %in% names(ext_doc) && !is.null(ext_doc[[datatype]]$fields)) {
      ext_fields <- ext_doc[[datatype]]$fields
    }
  } else if (nzchar(ext_path_yaml)) {
    # Path declared but unresolvable — warn, don't silently drop
    warning(sprintf(
      "platform_extension_yaml_path '%s' declared in bridge yaml but not resolvable (tried direct + bridges_root-relative). Platform extension fields will be dropped from INSERT. Per #633.",
      ext_path_yaml
    ), call. = FALSE)
  }

  # ----- Shape detection (v2.0 schema-driven vs v1.x legacy) -----
  # Per `glue-bridge-schema-driven-shape` capability spec + design Decision 5.
  has_field_extractors <- !is.null(bridge$field_extractors)
  has_column_mapping <- !is.null(bridge$column_mapping)

  if (has_field_extractors && has_column_mapping) {
    stop("Bridge yaml ", bridge_path,
         " contains BOTH `field_extractors` AND `column_mapping` — shape ambiguous. ",
         "Use exactly one. `field_extractors` is the v2.0 schema-driven shape;",
         " `column_mapping` is the v1.x legacy shape (deprecated 2026-08-31).")
  }
  if (!has_field_extractors && !has_column_mapping) {
    stop("Bridge yaml ", bridge_path,
         " has neither `field_extractors` nor `column_mapping` — invalid shape. ",
         "Required: declare extraction strategy under one of these two keys.")
  }

  bridge_shape <- if (has_field_extractors) "schema_driven_v2" else "legacy_v1"

  if (bridge_shape == "legacy_v1") {
    warning(sprintf(
      "column_mapping shape is deprecated. Migrate via shared/global_scripts/01_db/raw_schema/_authoring/migrate_bridge_to_field_extractors.R. Deadline: 2026-08-31. (bridge: %s)",
      bridge_path
    ), call. = FALSE)
  }

  # ----- v2.0 shape: translate field_extractors → column_mapping (runtime adapter) -----
  # Per design Decision 1 (backward-compat-then-deprecate) + Decision 5 (shape detection).
  # Inline translation reuses the existing apply_mapping() logic; full traversal-
  # direction rewrite is deferred to a future amendment once schema-driven shape
  # is the only form (post 2026-08-31 deprecation deadline).
  effective_column_mapping <- if (bridge_shape == "schema_driven_v2") {
    fe <- bridge$field_extractors
    translated <- list()
    # Per fix-amz-order-id-pattern-permissiveness (#634 surfaced during apply):
    # the inline runtime translator must preserve extension fields (value_map +
    # 5 others) — same whitelist as migration tool fix #630. Without this,
    # value_map is silently dropped at runtime even though it's correctly
    # preserved in the v2 yaml. Sister-bug to #630 but in runtime translator
    # not codegen tool.
    KNOWN_EXTENSION_FIELDS <- c(
      "value_map", "filter_when", "default_when_empty",
      "drop_when", "pre_filter_per_row", "validate_pattern"
    )
    copy_extensions <- function(target, ext) {
      for (f in KNOWN_EXTENSION_FIELDS) {
        if (!is.null(ext[[f]])) target[[f]] <- ext[[f]]
      }
      target
    }
    for (canonical_name in names(fe)) {
      ext <- fe[[canonical_name]]
      etype <- ext$type
      if (etype == "column") {
        translated[[canonical_name]] <- copy_extensions(list(
          from_column = ext$name,
          coercion = ext$coercion
        ), ext)
      } else if (etype == "const") {
        translated[[canonical_name]] <- copy_extensions(list(
          use_value = ext$value
        ), ext)
      } else if (etype == "derive") {
        # derive maps to apply_fallback with derive expression
        translated[[canonical_name]] <- list(
          apply_fallback = TRUE,
          derive = ext$expression
        )
      } else if (etype == "sha256") {
        # sha256 emits derive expression in canonical sha256(a + b + c) form
        translated[[canonical_name]] <- list(
          apply_fallback = TRUE,
          derive = paste0("sha256(", paste(ext$components, collapse = " + "), ")")
        )
      } else if (etype == "regex") {
        # regex emits derive expression interpretable by fn_apply_mapping (extension)
        # Note: regex extractor type may need fn_apply_mapping.R extension for
        # full equivalence. For now translates to apply_fallback with marker.
        translated[[canonical_name]] <- list(
          apply_fallback = TRUE,
          derive = paste0("extract_regex(", ext$source_field, ", '", ext$pattern, "')")
        )
      } else {
        warning(sprintf(
          "Unknown field_extractors.%s.type = '%s' — skipping translation",
          canonical_name, etype
        ), call. = FALSE)
      }
    }
    translated
  } else {
    bridge$column_mapping %||% list()
  }

  # ----- Apply mapping -----
  # Spectra change `bridge-promote-ship-fields` (codex ensemble HIGH#1 fix):
  # Combine required + optional canonical fields so bridge column_mapping
  # entries for optional fields (e.g. ship_country / ship_state / ship_city)
  # actually flow through apply_mapping + validate_against_schema. Without
  # this, the bridge yaml says "map ship-city to ship_city" but the runtime
  # silently drops it at the apply_mapping step (bug pre-existing #418).
  combined_canonical_fields <- c(required_fields, optional_fields)
  mapped <- apply_mapping(
    prerawdata = prerawdata,
    column_mapping = effective_column_mapping,
    required_fields = combined_canonical_fields,
    ext_fields = ext_fields,
    canonical_target_platform = bridge$canonical_target$platform %||%
      platform,
    pre_filter = bridge$pre_filter
  )

  # ----- Validate -----
  validation <- validate_against_schema(
    df = mapped,
    required_fields = combined_canonical_fields,
    ext_fields = ext_fields
  )

  # ----- INSERT into canonical table (DDL re-validates per generated SQL) -----
  target_table <- bridge$canonical_target$table %||%
    paste0("df_", platform, "_", datatype, "___raw")

  # Bridge identifier for idempotent re-run (#572):
  # Tag every row with this bridge's identity, then DELETE WHERE before INSERT
  # so re-running the same bridge replaces its prior rows while preserving
  # rows written by other bridges into the same canonical table (e.g. cross-
  # bridge rollup case per MP055). Without this, append=TRUE accumulated
  # duplicates on every re-run (verified QEF DEV 2026-05-05: 2x run = 30 rows
  # from 15-row source CSV).
  this_source_id <- sprintf("glue_bridge:%s:%s:%s", company, platform, source)

  n_output <- 0L
  if (validation$n_errors == 0) {
    # Override import_source so DELETE WHERE scopes to this bridge alone.
    # Schema default fallback is "UNKNOWN_SOURCE" (per core_schemas.yaml);
    # we replace with bridge-specific id for source-of-truth attribution.
    if ("import_source" %in% names(mapped)) {
      mapped$import_source <- this_source_id
    }

    if (DBI::dbExistsTable(target_con, target_table)) {
      DBI::dbExecute(target_con, sprintf(
        "DELETE FROM %s WHERE import_source = %s",
        DBI::dbQuoteIdentifier(target_con, target_table),
        DBI::dbQuoteString(target_con, this_source_id)))
    }

    DBI::dbWriteTable(target_con, target_table, mapped, append = TRUE)
    n_output <- nrow(mapped)
  }

  list(
    n_input_rows = nrow(prerawdata),
    n_output_rows = n_output,
    n_errors = validation$n_errors,
    errors = validation$errors,
    bridge_path = bridge_path,
    target_table = target_table
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
