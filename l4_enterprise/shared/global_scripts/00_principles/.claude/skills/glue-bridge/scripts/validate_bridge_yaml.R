#!/usr/bin/env Rscript
# validate_bridge_yaml.R — Lint script for bridge yaml drafts produced by the
# glue-bridge skill (Step 7).
#
# Bound by MP102 v1.2 (Schema Contract). This validator enforces the bridge
# yaml contract documented in SKILL.md (Bridge YAML Schema section) and
# implemented in 05_etl_utils/glue/fn_glue_bridge.R as the deterministic
# interpreter.
#
# Usage:
#   Rscript validate_bridge_yaml.R <path/to/bridge.yaml> [--strict]
#
# Exit codes:
#   0 — all checks passed (warnings allowed)
#   1 — at least one CRITICAL violation (blocks Step 8 review)
#   2 — wrong invocation (file missing, etc.)
#
# Reviewer rejection patterns (the four guards from the skill):
#   - reviewed_by absent / placeholder / "AI" / "REQUIRES_HUMAN_REVIEW" / "TBD"
#   - schema_fingerprint missing or not 64-char sha256 hex
#   - column_mapping with no usable source (no from_column / use_value /
#     apply_fallback)
#   - generated_at not ISO-8601-ish

`%||%` <- function(a, b) if (is.null(a)) b else a

suppressWarnings(suppressPackageStartupMessages({
  has_yaml <- requireNamespace("yaml", quietly = TRUE)
}))
if (!has_yaml) {
  message("FATAL: package `yaml` not available. install.packages('yaml').")
  quit(status = 2)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  message("Usage: Rscript validate_bridge_yaml.R <bridge.yaml> [--strict]")
  quit(status = 2)
}
bridge_path <- args[[1L]]
strict_mode <- "--strict" %in% args

if (!file.exists(bridge_path)) {
  message("FATAL: file not found: ", bridge_path)
  quit(status = 2)
}

# ---- Parse yaml -----------------------------------------------------------

doc <- tryCatch(
  yaml::read_yaml(bridge_path),
  error = function(e) {
    message("CRITICAL: yaml parse failed for ", bridge_path)
    message("  ", conditionMessage(e))
    quit(status = 1)
  }
)

problems <- list()
record <- function(severity, msg) {
  problems[[length(problems) + 1L]] <<- list(severity = severity, msg = msg)
}
critical <- function(msg) record("CRITICAL", msg)
warn     <- function(msg) record("WARNING",  msg)
info     <- function(msg) record("INFO",     msg)

# ---- Shape detection (v2.0 schema-driven vs v1.x legacy) ------------------
#
# Per `glue-bridge-schema-driven-shape` capability spec + design Decision 5:
# detect bridge yaml shape via top-level key presence.
#
# - field_extractors present → schema-driven (v2.0)
# - column_mapping present → legacy prerawdata-driven (v1.x), deprecated 2026-08-31
# - both → ERROR (shape ambiguity)
# - neither → ERROR (invalid bridge)

has_field_extractors <- !is.null(doc$field_extractors)
has_column_mapping <- !is.null(doc$column_mapping)

if (has_field_extractors && has_column_mapping) {
  critical("bridge yaml contains BOTH `field_extractors` AND `column_mapping` top-level keys — shape is ambiguous. Use exactly one. `field_extractors` is the v2.0 schema-driven shape; `column_mapping` is the v1.x legacy shape (deprecated 2026-08-31).")
}
if (!has_field_extractors && !has_column_mapping) {
  critical("bridge yaml has neither `field_extractors` nor `column_mapping` top-level key — invalid shape. Required: declare extraction strategy under one of these two keys.")
}

bridge_shape <- if (has_field_extractors) "schema_driven_v2" else "legacy_v1"

# Emit deprecation warning for legacy shape during compat window
if (bridge_shape == "legacy_v1") {
  warning(sprintf(
    "column_mapping shape is deprecated. Migrate via shared/global_scripts/01_db/raw_schema/_authoring/migrate_bridge_to_field_extractors.R. Deadline: 2026-08-31. (bridge: %s)",
    bridge_path
  ), call. = FALSE)
}

# ---- Top-level required keys ---------------------------------------------
#
# Per-shape required keys: legacy needs `column_mapping`; schema-driven needs
# `field_extractors`. Common required: prerawdata_source, canonical_target,
# generated_at, generated_by, reviewed_by.

required_top_common <- c(
  "prerawdata_source", "canonical_target",
  "generated_at", "generated_by", "reviewed_by"
)
required_top_shape <- if (bridge_shape == "schema_driven_v2") "field_extractors" else "column_mapping"

required_top <- c(required_top_common, required_top_shape)
for (key in required_top) {
  if (is.null(doc[[key]])) {
    critical(sprintf("missing top-level key: `%s`", key))
  }
}

# ---- prerawdata_source ----------------------------------------------------

ps <- doc$prerawdata_source
if (!is.null(ps)) {
  for (k in c("company", "platform", "source_type", "schema_fingerprint")) {
    if (is.null(ps[[k]]) || identical(ps[[k]], "")) {
      critical(sprintf("prerawdata_source.%s missing or empty", k))
    }
  }

  fp <- ps$schema_fingerprint
  if (!is.null(fp)) {
    if (!identical(tolower(as.character(fp$algorithm %||% "")), "sha256")) {
      critical("prerawdata_source.schema_fingerprint.algorithm must be 'sha256'")
    }
    fp_val <- as.character(fp$value %||% "")
    if (!nzchar(fp_val)) {
      critical("prerawdata_source.schema_fingerprint.value missing")
    } else if (!grepl("^[0-9a-f]{64}$", fp_val, ignore.case = TRUE)) {
      critical(sprintf(
        "prerawdata_source.schema_fingerprint.value not 64-char sha256 hex (got %d chars)",
        nchar(fp_val)
      ))
    }
    if (is.null(fp$fingerprinted_against)) {
      warn("prerawdata_source.schema_fingerprint.fingerprinted_against missing — reviewers cannot reproduce the hash")
    }
    # Advisory per fix-glue-layer-infra-blockers (#628) Decision 3:
    # fingerprinted_at < 2026-05-12 suggests fingerprint may use deprecated raw class()[1].
    fp_at_str <- as.character(fp$fingerprinted_at %||% "")
    if (nzchar(fp_at_str)) {
      fp_date <- tryCatch(as.Date(substr(fp_at_str, 1, 10)),
                          error = function(e) NA, warning = function(w) NA)
      if (!is.na(fp_date) && fp_date < as.Date("2026-05-12")) {
        warn(sprintf(
          "prerawdata_source.schema_fingerprint.fingerprinted_at='%s' predates 2026-05-12 (fix-glue-layer-infra-blockers apply date) — fingerprint may use deprecated raw class()[1] method. Consider regenerating via regen_bridge_fingerprints.R (per #628 mitigation).",
          fp_at_str
        ))
      }
    }
  }

  if (identical(tolower(as.character(ps$source_type %||% "")), "xlsx")) {
    if (is.null(ps$source_uri)) {
      warn("xlsx source_type but no source_uri — runtime cannot locate the file")
    }
  }
}

# ---- canonical_target -----------------------------------------------------

ct <- doc$canonical_target
if (!is.null(ct)) {
  for (k in c("datatype", "platform", "table", "schema_yaml_path")) {
    if (is.null(ct[[k]]) || identical(ct[[k]], "")) {
      critical(sprintf("canonical_target.%s missing or empty", k))
    }
  }
  tbl <- as.character(ct$table %||% "")
  if (nzchar(tbl) && !grepl("___raw$", tbl)) {
    warn(sprintf("canonical_target.table = '%s' does not end with '___raw' (DM_R028 raw layer convention)", tbl))
  }
  pf <- as.character(ct$platform %||% "")
  if (nzchar(pf) && !is.null(ps) && !identical(pf, as.character(ps$platform %||% ""))) {
    critical(sprintf(
      "platform mismatch: prerawdata_source.platform='%s' but canonical_target.platform='%s'",
      ps$platform %||% "", pf
    ))
  }
}

# ---- column_mapping (legacy v1.x shape only) -------------------------------

cm <- doc$column_mapping
# Guard: skip column_mapping validation entirely under v2.0 schema-driven shape
if (bridge_shape == "schema_driven_v2") {
  # field_extractors validation handled in separate section below
} else if (is.null(cm) || !length(cm)) {
  critical("column_mapping is empty — at least one mapping required")
} else {
  if (is.null(names(cm)) || any(!nzchar(names(cm)))) {
    critical("column_mapping entries must be a named map (canonical field name -> mapping rule)")
  }
  for (canonical_name in names(cm)) {
    rule <- cm[[canonical_name]]
    if (!is.list(rule)) {
      critical(sprintf("column_mapping.%s must be a mapping (got %s)", canonical_name, class(rule)[[1L]]))
      next
    }
    has_from     <- !is.null(rule$from_column) && nzchar(as.character(rule$from_column))
    has_use      <- !is.null(rule$use_value)
    has_fallback <- isTRUE(rule$apply_fallback)
    if (!(has_from || has_use || has_fallback)) {
      critical(sprintf(
        "column_mapping.%s has no source: needs `from_column`, `use_value`, or `apply_fallback: true`",
        canonical_name
      ))
    }
    if (sum(has_from, has_use, has_fallback) > 1L) {
      warn(sprintf(
        "column_mapping.%s combines multiple sources (from_column / use_value / apply_fallback) — bridge interpreter prefers from_column > use_value > apply_fallback; explicit choice avoids surprise",
        canonical_name
      ))
    }
    vm <- rule$value_map
    if (!is.null(vm) && !is.list(vm)) {
      critical(sprintf("column_mapping.%s.value_map must be a mapping", canonical_name))
    }

    # ---- D13 check (c): value_map normalization detector ----
    # Detect case-variant brute force in value_map keys (e.g. "Amazon" + "AMAZON"
    # both mapping to same value). Suggests using coercion.rule tolower/toupper
    # first then keeping a single canonical key.
    if (is.list(vm) && length(vm) >= 2L) {
      vm_keys <- names(vm)
      vm_keys_lower <- tolower(vm_keys)
      dup_lower <- vm_keys_lower[duplicated(vm_keys_lower)]
      if (length(dup_lower) > 0L) {
        warn(sprintf(
          "column_mapping.%s.value_map has case-variant keys (e.g. %s) — consider `coercion.rule: 'tolower'` or `'toupper'` then a single canonical key per DM_R065",
          canonical_name,
          paste(unique(dup_lower), collapse = ", ")
        ))
      }
    }
  }
}

# ---- field_extractors (v2.0 schema-driven shape) --------------------------
#
# Per `glue-bridge-schema-driven-shape` capability spec. Each canonical field
# SHALL have exactly one extractor declaring its extraction strategy:
#   - column: direct source column mapping
#   - const:  constant value
#   - derive: computed from other extracted fields
#   - sha256: cryptographic hash of multiple components
#   - regex:  pattern extraction from a source field

fe <- doc$field_extractors
if (bridge_shape == "schema_driven_v2") {
  if (is.null(fe) || !length(fe)) {
    critical("field_extractors is empty — at least one extractor required for v2.0 schema-driven bridges")
  } else if (is.null(names(fe)) || any(!nzchar(names(fe)))) {
    critical("field_extractors entries must be a named map (canonical field name -> extractor declaration)")
  } else {
    valid_types <- c("column", "const", "derive", "sha256", "regex")
    for (canonical_name in names(fe)) {
      extractor <- fe[[canonical_name]]
      if (!is.list(extractor)) {
        critical(sprintf("field_extractors.%s must be a mapping (got %s)", canonical_name, class(extractor)[[1L]]))
        next
      }
      etype <- extractor$type
      if (is.null(etype) || !nzchar(etype)) {
        critical(sprintf("field_extractors.%s.type missing — required one of: %s", canonical_name, paste(valid_types, collapse = ", ")))
        next
      }
      if (!(etype %in% valid_types)) {
        critical(sprintf("field_extractors.%s.type = '%s' is not recognized. Valid types: %s",
                         canonical_name, etype, paste(valid_types, collapse = ", ")))
        next
      }
      # Per-type required parameters
      if (etype == "column") {
        if (is.null(extractor$name) || !nzchar(extractor$name)) {
          critical(sprintf("field_extractors.%s (type=column) requires `name:` (source column name)", canonical_name))
        }
      } else if (etype == "const") {
        if (is.null(extractor$value)) {
          critical(sprintf("field_extractors.%s (type=const) requires `value:` (constant value)", canonical_name))
        }
      } else if (etype == "derive") {
        if (is.null(extractor$expression) || !nzchar(extractor$expression)) {
          critical(sprintf("field_extractors.%s (type=derive) requires `expression:` (R-syntax derivation)", canonical_name))
        }
      } else if (etype == "sha256") {
        if (is.null(extractor$components) || !is.list(extractor$components) || !length(extractor$components)) {
          critical(sprintf("field_extractors.%s (type=sha256) requires `components:` (list of field names to hash)", canonical_name))
        }
      } else if (etype == "regex") {
        if (is.null(extractor$source_field) || !nzchar(extractor$source_field)) {
          critical(sprintf("field_extractors.%s (type=regex) requires `source_field:` (source column to extract from)", canonical_name))
        }
        if (is.null(extractor$pattern) || !nzchar(extractor$pattern)) {
          critical(sprintf("field_extractors.%s (type=regex) requires `pattern:` (regex extraction pattern)", canonical_name))
        }
      }

      # Advisory per fix-glue-layer-infra-blockers (#630) Decision 7:
      # column extractor with value_map — INFO mentioning post-coercion key matching
      if (etype == "column" && !is.null(extractor$value_map) && length(extractor$value_map) > 0L) {
        info(sprintf(
          "field_extractors.%s.value_map present (%d entries) — runtime applies lookup post-coercion (per DM_R065 rule 3 + MP102 v1.3). Verify value_map keys match the post-coercion form (e.g. if `coercion: 'as.character + toupper'`, keys must be uppercase).",
          canonical_name, length(extractor$value_map)
        ))
      }

      # Advisory per fix-glue-layer-infra-blockers (#631) Decision 7:
      # column extractor with unsupported coercion ops — WARN with whitelist guidance
      if (!is.null(extractor$coercion) && nzchar(as.character(extractor$coercion))) {
        coercion_whitelist <- c("as.character", "as.numeric", "as.integer",
                                "as.logical", "trimws", "toupper", "tolower")
        ops <- trimws(strsplit(as.character(extractor$coercion), "\\+")[[1]])
        ops <- ops[nchar(ops) > 0]
        unsupported <- setdiff(ops, coercion_whitelist)
        if (length(unsupported) > 0L) {
          warn(sprintf(
            "field_extractors.%s.coercion contains unsupported op(s): %s — runtime will SKIP these ops with WARNING (per #631). For complex transformations (e.g. date format), use `type: derive` extractor with explicit `expression:` instead. Whitelist: %s",
            canonical_name,
            paste(unsupported, collapse = ", "),
            paste(coercion_whitelist, collapse = " / ")
          ))
        }
      }
    }
  }

  # ---- Reverse-coverage check (v2.0 replacement for MP160 enumeration tax) ----
  #
  # Every source column should appear in either an extractor's reference OR be
  # explicitly listed in `unused_source_columns:`. Source columns not covered
  # emit WARNING (advisory, non-blocking) — drift signal for human review.
  #
  # Note: requires reading actual source xlsx/csv to enumerate columns. For
  # offline validation (no source file access), this check is skipped with a
  # diagnostic message.

  ps_path_or_pattern <- if (!is.null(doc$prerawdata_source$path)) doc$prerawdata_source$path else doc$prerawdata_source$pattern
  if (is.null(ps_path_or_pattern) || !nzchar(ps_path_or_pattern)) {
    # No source path — skip reverse-coverage check
    info("reverse-coverage check skipped (prerawdata_source.path/pattern not set)")
  } else {
    # Reverse-coverage check is left for runtime fn_glue_bridge.R when source
    # data access is available. validate_bridge_yaml.R operates statically and
    # cannot enumerate source columns without reading actual xlsx/csv.
    info("reverse-coverage check deferred to runtime (fn_glue_bridge.R verifies during interpret)")
  }
}

# ---- D12/D13 schema-aware checks (canonical-field existence + alias dedup) ----
#
# These checks read core_schemas.yaml + applicable platform_extensions/{platform}
# _extensions.yaml. If those files are not findable from the bridge yaml's
# location (e.g. bridge yaml in a sandbox), the checks become INFO-level
# observations rather than hard CRITICAL failures.

# Walk up from the bridge yaml to find `_authoring/` directory.
find_authoring_dir <- function(start_path) {
  dir <- normalizePath(dirname(start_path), winslash = "/", mustWork = FALSE)
  for (i in seq_len(20L)) {  # walk up at most 20 levels
    candidate <- file.path(dir, "01_db", "raw_schema", "_authoring")
    if (dir.exists(candidate)) return(candidate)
    parent <- dirname(dir)
    if (parent == dir) break  # reached filesystem root
    dir <- parent
  }
  NULL
}

# D12 + D13 dedup-aware normalize (Unicode-aware; matches DM_R065 + 9.0e probe).
norm_alias <- function(s) {
  s <- tolower(trimws(as.character(s)))
  # Keep Unicode word chars (CJK + Latin alphanumerics + underscore)
  gsub("[^\\w]", "", s, perl = TRUE)
}

authoring_dir <- find_authoring_dir(bridge_path)
ct <- doc$canonical_target  # may be NULL if bridge is malformed (already flagged above)
ct_datatype <- if (!is.null(ct)) as.character(ct$datatype %||% "") else ""
ct_platform <- if (!is.null(ct)) as.character(ct$platform %||% "") else ""

# ---- DDL pre-flight check (#611) ------------------------------------------
# Verify that canonical_target.table has a corresponding generated DDL file
# under 01_db/raw_schema/_generated/. Three candidate paths per MP161
# (Universal vs Company-Scoped) + per-platform extension:
#
#   1. companies/{COMPANY}/platforms/{platform}/{datatype}.sql  (company-scoped)
#   2. platforms/{platform}/{datatype}.sql                      (platform extension)
#   3. core/{datatype}.sql                                       (universal core)
#
# If NONE of these exist → CRITICAL with actionable message ("Run _build.R first").
# If at least one exists → INFO confirming which DDL the bridge will write to.
# If _generated/ directory missing → INFO (graceful degradation for sandbox layouts).

if (!is.null(authoring_dir) && nzchar(ct_datatype) && nzchar(ct_platform)) {
  ps_co <- if (!is.null(ps)) as.character(ps$company %||% "") else ""
  generated_dir <- file.path(dirname(authoring_dir), "_generated")
  if (dir.exists(generated_dir)) {
    candidates <- character(0)
    if (nzchar(ps_co)) {
      candidates <- c(candidates,
        file.path(generated_dir, "companies", ps_co,
                  "platforms", ct_platform, paste0(ct_datatype, ".sql")))
    }
    candidates <- c(candidates,
      file.path(generated_dir, "platforms", ct_platform, paste0(ct_datatype, ".sql")),
      file.path(generated_dir, "core", paste0(ct_datatype, ".sql"))
    )

    found <- candidates[file.exists(candidates)]
    rel_paths <- function(paths) {
      sub(paste0("^", normalizePath(generated_dir, mustWork = FALSE), "/"),
          "_generated/", paths)
    }
    if (length(found) == 0L) {
      critical(sprintf(
        paste0(
          "DDL pre-flight: no generated DDL found for canonical_target ",
          "{datatype='%s', platform='%s', company='%s'}. ",
          "Searched %d path(s): %s. ",
          "Likely cause: _build.R not run since canonical schema added/changed. ",
          "Run: cd shared/global_scripts/01_db/raw_schema && Rscript _build.R"
        ),
        ct_datatype, ct_platform, ps_co,
        length(candidates),
        paste(rel_paths(candidates), collapse = ", ")
      ))
    } else {
      info(sprintf(
        "DDL pre-flight: found %d matching DDL file(s): %s",
        length(found),
        paste(rel_paths(found), collapse = ", ")
      ))
    }
  } else {
    info(sprintf(
      "DDL pre-flight: _generated directory not found at %s — skipping check (sandbox layout?)",
      generated_dir
    ))
  }
}

if (!is.null(authoring_dir) && nzchar(ct_datatype)) {
  core_yaml_path <- file.path(authoring_dir, "core_schemas.yaml")
  ext_yaml_path  <- file.path(authoring_dir, "platform_extensions",
                              paste0(ct_platform, "_extensions.yaml"))

  if (file.exists(core_yaml_path)) {
    core_doc <- tryCatch(yaml::read_yaml(core_yaml_path),
                         error = function(e) NULL)
    ext_doc <- if (file.exists(ext_yaml_path)) {
      tryCatch(yaml::read_yaml(ext_yaml_path), error = function(e) NULL)
    } else NULL

    # Build the set of canonical field names available for this datatype.
    canonical_fields <- character(0L)
    if (!is.null(core_doc) && !is.null(core_doc[[ct_datatype]])) {
      core_dt <- core_doc[[ct_datatype]]
      canonical_fields <- c(canonical_fields,
                            names(core_dt$required_fields %||% list()),
                            names(core_dt$optional_fields %||% list()))
    }
    if (!is.null(ext_doc) && !is.null(ext_doc[[ct_datatype]])) {
      ext_dt <- ext_doc[[ct_datatype]]
      canonical_fields <- c(canonical_fields,
                            names(ext_dt$fields %||% list()),
                            names(ext_dt$required_fields %||% list()),
                            names(ext_dt$optional_fields %||% list()))
    }

    # ---- MP161 extension: also look in companies/{COMPANY}/ ----
    # Per MP161 (Company-Scoped Schema Recognition, #499), schema yamls may
    # live at _authoring/companies/{COMPANY}/{schema}.yaml. The bridge's
    # prerawdata_source.company tells us which company directory to search.
    # This extension restores the schema-aware check for QEF-specific datatypes
    # like product_attributes_blb..sss that previously emitted INFO "skipped".
    company_scoped_doc <- NULL  # captured for D13 dedup re-check below
    if (!is.null(ps) && nzchar(as.character(ps$company %||% ""))) {
      companies_dir <- file.path(authoring_dir, "companies",
                                  as.character(ps$company))
      if (dir.exists(companies_dir)) {
        company_yamls <- list.files(companies_dir, pattern = "\\.yaml$",
                                     full.names = TRUE)
        for (cy in company_yamls) {
          cy_doc <- tryCatch(yaml::read_yaml(cy), error = function(e) NULL)
          if (is.null(cy_doc)) next
          if (!is.null(cy_doc[[ct_datatype]])) {
            cy_dt <- cy_doc[[ct_datatype]]
            if (is.list(cy_dt) && !is.null(cy_dt$required_fields)) {
              canonical_fields <- c(canonical_fields,
                                    names(cy_dt$required_fields %||% list()),
                                    names(cy_dt$optional_fields %||% list()))
              company_scoped_doc <- cy_doc  # for D13 dedup re-check
              break  # stop at first match (datatype names are unique within
                     # a company directory per MP161)
            }
          }
        }
      }
    }

    canonical_fields <- unique(canonical_fields)

    # ---- D12 check (a): canonical field existence ----
    # Every name in column_mapping SHALL exist in the current canonical schema
    # for the bridge's datatype. A missing reference suggests the bridge author
    # silently relied on a Layer 1 mutation that was reverted (or was authored
    # against a temporarily-edited schema) — MP159 violation symptom.
    if (length(canonical_fields) > 0L && !is.null(cm)) {
      for (canonical_name in names(cm)) {
        if (!(canonical_name %in% canonical_fields)) {
          critical(sprintf(
            "column_mapping.%s — canonical field '%s' is not declared in core_schemas.yaml or platform_extensions/%s_extensions.yaml under datatype '%s'. This may indicate the bridge was authored against a temporarily-modified Layer 1 schema (MP159 violation symptom).",
            canonical_name, canonical_name, ct_platform, ct_datatype
          ))
        }
      }
    } else if (length(canonical_fields) == 0L) {
      company_str <- if (!is.null(ps)) as.character(ps$company %||% "<unknown>") else "<unknown>"
      info(sprintf(
        "canonical field existence check skipped — datatype '%s' not found in core_schemas.yaml, platform_extensions/%s_extensions.yaml, or companies/%s/*.yaml",
        ct_datatype, ct_platform, company_str
      ))
    }

    # ---- D13 checks (b1 + b2): within-field + cross-field alias dedup ----
    # Re-run the dedup probe against the bridge's datatype. Failure here means
    # the canonical schema itself drifted from DM_R065; the bridge inherits the
    # ambiguity. Backstop against 9.0e fixes regressing in future edits.
    if (!is.null(core_doc) && !is.null(core_doc[[ct_datatype]])) {
      core_dt <- core_doc[[ct_datatype]]
      norm_to_field <- list()
      for (sec in c("required_fields", "optional_fields")) {
        section <- core_dt[[sec]]
        if (!is.list(section)) next
        for (fname in names(section)) {
          fdef <- section[[fname]]
          if (!is.list(fdef)) next
          aliases <- fdef$aliases
          if (is.null(aliases)) next
          # Within-field
          norm_each <- vapply(aliases, norm_alias, character(1L))
          norm_each <- norm_each[nzchar(norm_each)]
          dup_within <- norm_each[duplicated(norm_each)]
          if (length(dup_within) > 0L) {
            critical(sprintf(
              "Schema dedup regression: %s.%s.%s.aliases has within-field duplicates after normalize (DM_R065 rule 1): %s",
              ct_datatype, sec, fname, paste(unique(dup_within), collapse = ", ")
            ))
          }
          # Cross-field map
          for (a in aliases) {
            n <- norm_alias(a)
            if (!nzchar(n)) next
            prev <- norm_to_field[[n]]
            if (!is.null(prev) && prev != fname) {
              critical(sprintf(
                "Schema dedup regression: alias '%s' (normalized '%s') in datatype '%s' appears in BOTH .%s.aliases AND .%s.aliases (DM_R065 rule 2 cross-field collision)",
                a, n, ct_datatype, prev, fname
              ))
            } else {
              norm_to_field[[n]] <- fname
            }
          }
        }
      }
    }
  } else {
    info(sprintf(
      "schema-aware checks skipped — core_schemas.yaml not found at %s (bridge yaml may be in a sandbox without authoring tree)",
      core_yaml_path
    ))
  }
} else {
  if (is.null(authoring_dir)) {
    info("schema-aware checks skipped — could not locate _authoring/ directory walking up from bridge yaml location")
  }
}

# ---- pre_filter (optional) -----------------------------------------------

pf_list <- doc$pre_filter
if (!is.null(pf_list)) {
  if (!is.list(pf_list) || !length(pf_list)) {
    warn("pre_filter present but empty — remove the key if no filtering is needed")
  } else {
    for (i in seq_along(pf_list)) {
      f <- pf_list[[i]]
      if (is.null(f$column) || !nzchar(as.character(f$column))) {
        critical(sprintf("pre_filter[%d] missing `column`", i))
      }
      has_inc <- !is.null(f$include_values)
      has_exc <- !is.null(f$exclude_values)
      if (!(has_inc || has_exc)) {
        critical(sprintf("pre_filter[%d] needs either include_values or exclude_values", i))
      }
      if (has_inc && has_exc) {
        warn(sprintf("pre_filter[%d] has both include_values and exclude_values — only one applies; clarify intent", i))
      }
    }
  }
}

# ---- ignored_columns (optional) ------------------------------------------

ic <- doc$ignored_columns
if (!is.null(ic)) {
  if (!is.character(ic) && !is.list(ic)) {
    critical("ignored_columns must be a list of column-name strings")
  }
  ic_chr <- unlist(ic, use.names = FALSE)
  dup <- ic_chr[duplicated(ic_chr)]
  if (length(dup)) {
    warn(sprintf("ignored_columns has duplicates: %s", paste(unique(dup), collapse = ", ")))
  }

  # Cross-check: any canonical mapping that uses a from_column also listed in
  # ignored_columns is a contradiction.
  if (!is.null(cm)) {
    for (canonical_name in names(cm)) {
      from_col <- cm[[canonical_name]]$from_column
      if (!is.null(from_col) && from_col %in% ic_chr) {
        critical(sprintf(
          "column_mapping.%s.from_column = '%s' but '%s' is also listed in ignored_columns",
          canonical_name, from_col, from_col
        ))
      }
    }
  }
}

# ---- MP160 exhaustive enumeration check ----------------------------------
#
# MP160 (AI Schema/Bridge Authoring Completeness) requires:
#   set(source_columns) === set(column_mapping_keys.from_column /
#                               from_columns) ∪ set(ignored_columns)
# Every source column SHALL be either mapped or explicitly ignored.
#
# This check is mechanical: re-fingerprint the source file, compute the
# mapped + ignored sets, and report any source columns that are not
# accounted for.
#
# Skip rules (per design R3 + graceful-degradation):
#   - bridge_path contains "/wip/" segment       -> INFO + skip (WIP bridge)
#   - source file not reachable from this env    -> INFO + skip (CI / sandbox)
#   - fingerprint mismatch (source mutated)      -> CRITICAL, suspend MP160
#
# Implementation note (per design R2 — false-positive prevention):
# `apply_fallback: true` and `use_value:` entries do NOT consume a source
# column — they emit a constant or fallback value. They are excluded from
# the `mapped` set, so source columns NOT mentioned in column_mapping
# are NOT made compliant by these entries. They must still appear in
# ignored_columns or be a from_column source.

is_wip_bridge <- grepl("/wip/", bridge_path, fixed = TRUE)

if (is_wip_bridge) {
  info("MP160: wip/ bridge — exempt from exhaustive-enumeration enforcement")
} else if (is.null(ps) || is.null(ps$source_uri) || is.null(ps$schema_fingerprint)) {
  info("MP160: prerawdata_source incomplete — cannot run exhaustive-enumeration check")
} else {
  # ---- Resolve source file path -----------------------------------------
  # The skill's "fingerprinted_against" stores a relative-to-project hint
  # like "amazon_sales/2024-1/2024-01.xlsx (full read, 8492 rows)".
  # We construct candidate absolute paths by walking up from the bridge
  # location to find the project root (where data/local_data lives), then
  # try the source_uri pattern + fingerprinted_against.

  fp_against <- as.character(ps$schema_fingerprint$fingerprinted_against %||% "")
  fp_file <- sub("\\s*\\(.*\\)\\s*$", "", fp_against)  # strip "(full read, N rows)"
  fp_file <- trimws(fp_file)

  # Walk up to find a directory containing data/local_data (project root)
  find_project_root <- function(start_path) {
    dir <- normalizePath(dirname(start_path), winslash = "/", mustWork = FALSE)
    for (i in seq_len(20L)) {
      if (dir.exists(file.path(dir, "data", "local_data"))) return(dir)
      parent <- dirname(dir)
      if (parent == dir) break
      dir <- parent
    }
    NULL
  }

  proj_root <- find_project_root(bridge_path)
  source_file_path <- NULL
  if (!is.null(proj_root) && nzchar(fp_file)) {
    # Try data/local_data/rawdata_<COMPANY>/<fp_file>
    co <- as.character(ps$company %||% "")
    if (nzchar(co)) {
      cand <- file.path(proj_root, "data", "local_data",
                        paste0("rawdata_", co), fp_file)
      if (file.exists(cand)) source_file_path <- cand
    }
    # Try direct under data/local_data/<fp_file>
    if (is.null(source_file_path)) {
      cand <- file.path(proj_root, "data", "local_data", fp_file)
      if (file.exists(cand)) source_file_path <- cand
    }
  }

  if (is.null(source_file_path)) {
    info(sprintf(
      "MP160: source file '%s' not reachable from this environment — exhaustive-enumeration check skipped (run validator on a machine with rawdata_%s/ to enforce)",
      fp_file, ps$company %||% "<unknown>"
    ))
  } else {
    # ---- Read source columns + types ----------------------------------
    src_type_str <- tolower(as.character(ps$source_type %||% ""))
    source_cols <- NULL
    source_types <- NULL
    read_err <- NULL

    if (identical(src_type_str, "xlsx")) {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        info("MP160: package `readxl` not available — cannot read xlsx source for exhaustive-enumeration check")
      } else {
        sheet <- ps$sheet_name %||% 1L
        df <- tryCatch(
          readxl::read_excel(source_file_path,
                             sheet = if (is.null(sheet)) 1L else sheet),
          error = function(e) { read_err <<- conditionMessage(e); NULL }
        )
        if (!is.null(df)) {
          source_cols  <- names(df)
          source_types <- vapply(df, function(x) class(x)[[1L]], character(1L))
        }
      }
    } else if (identical(src_type_str, "csv")) {
      df <- tryCatch(
        utils::read.csv(source_file_path, nrows = 0L,
                        check.names = FALSE, stringsAsFactors = FALSE),
        error = function(e) { read_err <<- conditionMessage(e); NULL }
      )
      if (!is.null(df)) {
        source_cols  <- names(df)
        source_types <- rep("character", length(source_cols))  # csv types are read-time
      }
    } else {
      info(sprintf("MP160: source_type '%s' not yet supported for exhaustive-enumeration check (xlsx / csv supported)", src_type_str))
    }

    if (!is.null(read_err)) {
      info(sprintf("MP160: failed to read source file '%s': %s — exhaustive-enumeration check skipped", source_file_path, read_err))
    }

    if (!is.null(source_cols) && length(source_cols) > 0L) {
      # ---- Optional fingerprint pre-check ----------------------------
      # If hash_prerawdata_schema is available, verify the fingerprint
      # matches before trusting MP160 results. Mismatch -> CRITICAL.
      hash_fn_path <- file.path(proj_root, "shared", "global_scripts",
                                "05_etl_utils", "glue",
                                "fn_hash_prerawdata_schema.R")
      fingerprint_ok <- TRUE  # default-trust if we can't hash
      if (file.exists(hash_fn_path) && requireNamespace("digest", quietly = TRUE)) {
        local_env <- new.env()
        suppressWarnings(tryCatch(sys.source(hash_fn_path, envir = local_env),
                                  error = function(e) NULL))
        if (exists("hash_prerawdata_schema", envir = local_env)) {
          actual_fp <- tryCatch(
            local_env$hash_prerawdata_schema(source_cols, source_types),
            error = function(e) NULL
          )
          stored_fp <- as.character(ps$schema_fingerprint$value %||% "")
          if (!is.null(actual_fp) && nzchar(stored_fp) &&
              !identical(actual_fp$value, stored_fp)) {
            fingerprint_ok <- FALSE
            critical(sprintf(
              "MP160 pre-check: fingerprint inconsistency. Stored=%s; computed=%s. Source schema has drifted since the bridge was authored — re-run /glue-bridge to regenerate the bridge yaml. MP160 enumeration check suspended until fingerprint is repaired.",
              substr(stored_fp, 1L, 12L),
              substr(actual_fp$value, 1L, 12L)
            ))
          }
        }
      }

      if (fingerprint_ok) {
        # ---- Compute mapped set ----------------------------------------
        mapped_cols <- character(0L)
        if (!is.null(cm)) {
          for (canonical_name in names(cm)) {
            rule <- cm[[canonical_name]]
            if (!is.list(rule)) next
            # from_column (single)
            fc <- as.character(rule$from_column %||% "")
            if (nzchar(fc)) mapped_cols <- c(mapped_cols, fc)
            # from_columns (multi, DM_R065 merge syntax)
            fcs <- rule$from_columns
            if (!is.null(fcs)) {
              fcs_chr <- as.character(unlist(fcs, use.names = FALSE))
              fcs_chr <- fcs_chr[nzchar(fcs_chr)]
              mapped_cols <- c(mapped_cols, fcs_chr)
            }
            # NOTE: apply_fallback / use_value entries do NOT consume a
            # source column and are intentionally NOT added to mapped_cols.
          }
        }
        mapped_set <- unique(mapped_cols)

        # ---- Compute ignored set ---------------------------------------
        ignored_set <- if (is.null(ic)) character(0L)
                       else unique(unlist(ic, use.names = FALSE))

        # ---- Compute unaccounted ---------------------------------------
        accounted_set <- unique(c(mapped_set, ignored_set))
        unaccounted <- setdiff(source_cols, accounted_set)

        if (length(unaccounted) > 0L) {
          # Truncate display list at 12 columns to keep error message readable
          display <- head(unaccounted, 12L)
          extra <- length(unaccounted) - length(display)
          tail_str <- if (extra > 0L) sprintf(" ... and %d more", extra) else ""
          critical(sprintf(
            "MP160 violation: %d source columns are neither in column_mapping nor ignored_columns: %s%s. Per MP160 (AI Schema/Bridge Authoring Completeness), every source column SHALL be either mapped or explicitly ignored. Add each unaccounted column to either column_mapping (with from_column) or ignored_columns:.",
            length(unaccounted),
            paste(sprintf("'%s'", display), collapse = ", "),
            tail_str
          ))
        }

        # Reverse-direction sanity: mapped/ignored references that are NOT
        # in source_cols suggest the bridge references columns the source
        # does not actually expose (could indicate stale bridge after
        # source columns were renamed).
        phantom <- setdiff(c(mapped_set, ignored_set), source_cols)
        if (length(phantom) > 0L) {
          warn(sprintf(
            "MP160 sanity: %d column(s) referenced in column_mapping or ignored_columns do not exist in source: %s. Source may have been renamed; verify against current source schema.",
            length(phantom),
            paste(sprintf("'%s'", head(phantom, 8L)), collapse = ", ")
          ))
        }
      }
    }
  }
}

# ---- reviewed_by guard (MP102 v1.3: structured form OR legacy string) ----
#
# Per spectra change `glue-bridge-self-converging-review` (#500):
#   - Structured (canonical, MP102 v1.3): yaml mapping with required fields
#     human_reviewer / review_mode / ai_reviewers / findings_summary /
#     approved_at / review_artifacts. Requires sibling *.bridge.review.md
#     with Verdict: CONVERGED or DIMINISHING. Requires findings_summary
#     critical == 0 && high == 0.
#   - Legacy string (deprecated until 2026-07-31): non-empty string outside
#     the placeholder blacklist. Emits WARNING about deprecation. After
#     2026-07-31 the runtime gate rejects the legacy form.

rb <- doc$reviewed_by

# Cutoff for legacy string form acceptance
LEGACY_CUTOFF_DATE <- as.Date("2026-07-31")
is_past_cutoff <- Sys.Date() > LEGACY_CUTOFF_DATE

# ---- Structured form path -------------------------------------------------
if (is.list(rb)) {
  required_fields <- c("human_reviewer", "review_mode", "ai_reviewers",
                       "findings_summary", "approved_at", "review_artifacts")
  missing_fields <- setdiff(required_fields, names(rb))
  if (length(missing_fields) > 0L) {
    critical(sprintf(
      "reviewed_by structured form is missing required fields: %s",
      paste(missing_fields, collapse = ", ")
    ))
  }

  # findings_summary.critical and high must be zero for ship-ready
  fs <- rb$findings_summary
  if (is.list(fs)) {
    fs_critical <- as.integer(fs$critical %||% NA_integer_)
    fs_high <- as.integer(fs$high %||% NA_integer_)
    if (is.na(fs_critical) || is.na(fs_high)) {
      critical("reviewed_by.findings_summary requires integer fields `critical` and `high`")
    } else {
      if (fs_critical > 0L) {
        critical(sprintf(
          "reviewed_by.findings_summary.critical = %d (must be 0 for ship-ready)",
          fs_critical
        ))
      }
      if (fs_high > 0L) {
        critical(sprintf(
          "reviewed_by.findings_summary.high = %d (must be 0 for ship-ready)",
          fs_high
        ))
      }
    }

    # findings_resolutions required when medium + low > 0
    fs_medium <- as.integer(fs$medium %||% 0L)
    fs_low <- as.integer(fs$low %||% 0L)
    if ((fs_medium + fs_low) > 0L) {
      resolutions <- doc$findings_resolutions
      if (is.null(resolutions) || !is.list(resolutions) ||
          length(resolutions) == 0L) {
        critical(sprintf(
          "findings_summary has %d MEDIUM + %d LOW findings but `findings_resolutions:` block is missing or empty",
          fs_medium, fs_low
        ))
      }
    }
  }

  # Sibling .bridge.review.md file with Verdict: CONVERGED or DIMINISHING
  bridge_dir <- dirname(bridge_path)
  bridge_basename <- sub("\\.bridge\\.yaml$", "", basename(bridge_path))
  review_log_path <- file.path(bridge_dir,
                               paste0(bridge_basename, ".bridge.review.md"))
  artifact_ref <- as.character(rb$review_artifacts %||% "")
  if (nzchar(artifact_ref)) {
    # If review_artifacts is a relative path, resolve relative to bridge_dir
    artifact_resolved <- if (startsWith(artifact_ref, "/")) artifact_ref
                        else file.path(bridge_dir, artifact_ref)
  } else {
    artifact_resolved <- review_log_path
  }
  if (!file.exists(artifact_resolved)) {
    critical(sprintf(
      "review_artifacts references '%s' but file does not exist (expected sibling %s)",
      artifact_ref, basename(review_log_path)
    ))
  } else {
    log_lines <- readLines(artifact_resolved, warn = FALSE)
    has_converged <- any(grepl("^## Verdict:\\s*(CONVERGED|DIMINISHING)",
                               log_lines, ignore.case = TRUE))
    if (!has_converged) {
      critical(sprintf(
        "review log %s lacks `## Verdict: CONVERGED` or `## Verdict: DIMINISHING` line — bridge not ship-ready",
        artifact_ref
      ))
    }
  }

# ---- Legacy string form path ----------------------------------------------
} else {
  rb_raw <- as.character(rb %||% "")
  rb_str <- trimws(rb_raw)
  placeholder_patterns <- c(
    "^$",
    "^AI$",
    "^REQUIRES[_ ]HUMAN[_ ]REVIEW$",
    "^REQUIRES[_ ]REVIEW$",
    "^TBD$",
    "^TODO$",
    "^FIXME$",
    "^claude$",
    "^codex$",
    "^assistant$"
  )
  is_placeholder <- any(vapply(
    placeholder_patterns,
    function(p) grepl(p, rb_str, ignore.case = TRUE),
    logical(1L)
  ))
  if (is_placeholder) {
    critical(sprintf(
      "reviewed_by = '%s' is a placeholder. Bridge yamls SHALL be reviewed (use structured form per MP102 v1.3 or a real human identifier).",
      rb_raw
    ))
  } else if (is_past_cutoff) {
    critical(sprintf(
      "reviewed_by = '%s' uses legacy string form. After 2026-07-31, only structured form (MP102 v1.3) is accepted. Migrate via /glue-bridge skill.",
      rb_raw
    ))
  } else {
    warn(sprintf(
      "reviewed_by = '%s' uses legacy string form (deprecated). Migrate to structured form before 2026-07-31 (see MP102 v1.3 / spectra change glue-bridge-self-converging-review).",
      rb_raw
    ))
  }
}

# ---- generated_at: ISO-8601-ish ------------------------------------------

ga <- as.character(doc$generated_at %||% "")
if (nzchar(ga) && !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", ga)) {
  warn(sprintf("generated_at = '%s' does not start with YYYY-MM-DD — use ISO-8601 timestamp", ga))
}

# ---- Output ---------------------------------------------------------------

sevs <- vapply(problems, function(p) p$severity, character(1L))
n_critical <- sum(sevs == "CRITICAL")
n_warn     <- sum(sevs == "WARNING")
n_info     <- sum(sevs == "INFO")

cat(sprintf("\nvalidate_bridge_yaml.R — %s\n", bridge_path))
cat(sprintf("  CRITICAL: %d   WARNING: %d   INFO: %d\n\n",
            n_critical, n_warn, n_info))

if (length(problems)) {
  for (p in problems) {
    cat(sprintf("  [%-8s] %s\n", p$severity, p$msg))
  }
  cat("\n")
}

if (n_critical > 0L) {
  cat("RESULT: BLOCKED — fix CRITICAL issues before requesting human review.\n")
  quit(status = 1)
}
if (strict_mode && n_warn > 0L) {
  cat("RESULT: BLOCKED (--strict) — warnings present.\n")
  quit(status = 1)
}
cat("RESULT: PASSED — bridge yaml satisfies the contract. Reviewer name OK; replace if still pending review.\n")
quit(status = 0)
