#!/usr/bin/env Rscript
# migrate_bridge_to_field_extractors.R — Convert legacy `column_mapping` shape
# to v2.0 `field_extractors` shape for glue bridge yamls.
#
# Per `glue-bridge-schema-driven-shape` capability spec Requirement:
# "Migration Tool SHALL Convert Legacy Bridge Shape to Schema-Driven Shape
# Idempotently".
#
# Usage:
#   Rscript migrate_bridge_to_field_extractors.R <bridge.yaml> [--in-place]
#   Rscript migrate_bridge_to_field_extractors.R --all
#
# Behavior:
#   - Reads legacy bridge yaml
#   - Translates column_mapping → field_extractors per type table
#   - Renames ignored_columns → unused_source_columns
#   - Removes apply_fallback: true entries (delegated to schema fallback implicitly)
#   - Preserves all other top-level keys (canonical_target, prerawdata_source,
#     reviewed_by, pre_filter, etc.)
#   - Idempotent: re-running on already-migrated yaml produces no changes
#
# Exit codes:
#   0 — migration successful (or no-op if already migrated)
#   1 — migration error
#   2 — usage error

suppressWarnings(suppressPackageStartupMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    message("FATAL: package `yaml` not available. install.packages('yaml').")
    quit(status = 2)
  }
}))

`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  message("Usage: Rscript migrate_bridge_to_field_extractors.R <bridge.yaml> [--in-place]")
  message("       Rscript migrate_bridge_to_field_extractors.R --all")
  quit(status = 2)
}

# Per `glue-bridge-schema-driven-shape` spec MODIFIED Requirement
# (fix-glue-layer-infra-blockers, #630): the translate function SHALL preserve
# all per-extractor extension fields. Whitelist enumerates known fields that
# carry semantic meaning at runtime. Adding a new field to the bridge yaml
# schema SHALL update this whitelist in the same spec change.
KNOWN_EXTENSION_FIELDS <- c(
  "value_map", "filter_when", "default_when_empty",
  "drop_when", "pre_filter_per_row", "validate_pattern"
)

# Fields that are part of standard extractor shape and handled explicitly
# below (do NOT iterate-copy these — they're decomposed into extractor structure)
STANDARD_ENTRY_FIELDS <- c(
  "from_column", "use_value", "coercion", "apply_fallback", "derive", "notes"
)

translate_column_mapping_to_field_extractors <- function(cm) {
  # Translate legacy column_mapping shape to v2.0 field_extractors shape.
  # Returns a named list mirroring field_extractors structure.
  fe <- list()
  unknown_fields_report <- list()  # collect per-extractor unknown fields for summary warning
  for (canonical_name in names(cm)) {
    entry <- cm[[canonical_name]]
    extractor <- list()

    if (!is.null(entry$from_column) && nzchar(entry$from_column)) {
      # Type: column
      extractor$type <- "column"
      extractor$name <- entry$from_column
      if (!is.null(entry$coercion)) extractor$coercion <- entry$coercion
    } else if (!is.null(entry$use_value)) {
      # Type: const
      extractor$type <- "const"
      extractor$value <- entry$use_value
      if (!is.null(entry$coercion)) extractor$coercion <- entry$coercion
    } else if (isTRUE(entry$apply_fallback)) {
      # apply_fallback maps to derive / sha256 / regex per derive expression form
      derive_expr <- entry$derive
      if (is.null(derive_expr)) {
        # Pure apply_fallback (no explicit derive) — schema fallback handles
        # Skip emission; field will be filled by schema fallback rule at runtime.
        # This is the "post-glue era removes apply_fallback stanzas" pattern.
        next
      }
      # Detect form via simple prefix grep
      if (grepl("^\\s*sha256\\s*\\(", derive_expr)) {
        # sha256(field_a + field_b + ...)
        components_raw <- sub("^\\s*sha256\\s*\\(([^)]+)\\)\\s*.*$", "\\1", derive_expr)
        components <- strsplit(components_raw, "\\s*\\+\\s*")[[1]]
        components <- trimws(components)
        components <- components[nchar(components) > 0]
        extractor$type <- "sha256"
        extractor$components <- as.list(components)
      } else if (grepl("^\\s*extract_regex\\s*\\(", derive_expr)) {
        # extract_regex(source_field, 'pattern')
        # Extract source_field (between '(' and ',')
        sf <- sub("^\\s*extract_regex\\s*\\(\\s*([^,]+)\\s*,.*$", "\\1", derive_expr)
        # Extract pattern (between single or double quotes)
        pat_single <- sub("^.*'([^']+)'.*$", "\\1", derive_expr)
        pat_double <- sub("^.*\"([^\"]+)\".*$", "\\1", derive_expr)
        pat <- if (pat_single != derive_expr) pat_single else if (pat_double != derive_expr) pat_double else NA
        if (!is.na(pat) && nzchar(pat) && pat != derive_expr) {
          extractor$type <- "regex"
          extractor$source_field <- trimws(sf)
          extractor$pattern <- pat
        } else {
          extractor$type <- "derive"
          extractor$expression <- derive_expr
        }
      } else {
        # Generic derive expression (e.g. unit_price * quantity, Sys.time())
        extractor$type <- "derive"
        extractor$expression <- derive_expr
      }
    } else {
      # No recognized extraction strategy — pass through as derive with warning
      warning(sprintf(
        "column_mapping.%s has no recognized extraction strategy (no from_column / use_value / apply_fallback); skipping",
        canonical_name
      ), call. = FALSE)
      next
    }

    # Preserve coercion if not already set
    if (is.null(extractor$coercion) && !is.null(entry$coercion)) {
      extractor$coercion <- entry$coercion
    }

    # Preserve notes
    if (!is.null(entry$notes)) extractor$notes <- entry$notes

    # Preserve known extension fields (per spec MODIFIED Requirement +
    # Scenario "Migration tool preserves value_map field" + fix #630).
    # value_map / filter_when / default_when_empty / drop_when /
    # pre_filter_per_row / validate_pattern — copy verbatim if present.
    for (ef in KNOWN_EXTENSION_FIELDS) {
      if (!is.null(entry[[ef]])) extractor[[ef]] <- entry[[ef]]
    }

    # Detect unknown fields per spec Scenario "Migration tool reports unknown
    # extension fields" — anything beyond STANDARD_ENTRY_FIELDS ∪ KNOWN_EXTENSION_FIELDS
    # is unrecognized; collect for summary WARNING below.
    recognized <- c(STANDARD_ENTRY_FIELDS, KNOWN_EXTENSION_FIELDS)
    unknown_in_entry <- setdiff(names(entry), recognized)
    if (length(unknown_in_entry) > 0L) {
      unknown_fields_report[[canonical_name]] <- unknown_in_entry
    }

    fe[[canonical_name]] <- extractor
  }

  # Emit summary WARNING listing any unknown extension fields encountered per
  # spec Scenario "Migration tool reports unknown extension fields".
  if (length(unknown_fields_report) > 0L) {
    warning(sprintf(
      "Migration encountered unknown extension fields (NOT propagated to v2 form):\n%s\nEither add to KNOWN_EXTENSION_FIELDS whitelist via spec amendment (per spec scenario 'Whitelist update accompanies any extractor-field schema extension'), or remove from source if obsolete.",
      paste(vapply(names(unknown_fields_report), function(en) {
        sprintf("  - %s: [%s]", en, paste(unknown_fields_report[[en]], collapse = ", "))
      }, character(1)), collapse = "\n")
    ), call. = FALSE)
  }

  fe
}

migrate_one_bridge <- function(bridge_path, in_place = FALSE) {
  if (!file.exists(bridge_path)) {
    message(sprintf("ERROR: file not found: %s", bridge_path))
    return(invisible(FALSE))
  }

  doc <- yaml::read_yaml(bridge_path)

  # Idempotency check
  if (!is.null(doc$field_extractors)) {
    message(sprintf("ALREADY MIGRATED: %s (already uses field_extractors shape)", bridge_path))
    return(invisible(TRUE))
  }

  if (is.null(doc$column_mapping)) {
    message(sprintf("SKIP: %s (no column_mapping found — invalid legacy shape)", bridge_path))
    return(invisible(FALSE))
  }

  # Translate column_mapping → field_extractors
  fe <- translate_column_mapping_to_field_extractors(doc$column_mapping)

  # Build new doc preserving order
  new_doc <- list()
  for (key in names(doc)) {
    if (key == "column_mapping") {
      new_doc$field_extractors <- fe
    } else if (key == "ignored_columns") {
      # Rename to unused_source_columns
      new_doc$unused_source_columns <- doc$ignored_columns
    } else {
      new_doc[[key]] <- doc[[key]]
    }
  }

  output_path <- if (in_place) bridge_path else sub("\\.bridge\\.yaml$", ".bridge.v2.yaml", bridge_path)
  yaml::write_yaml(new_doc, output_path)
  message(sprintf("MIGRATED: %s -> %s", bridge_path, output_path))
  return(invisible(TRUE))
}

# Main dispatch
if (args[1] == "--all") {
  # Find all bridge yamls — locate bridges/ directory relative to script
  # Use commandArgs to find script path (more robust than sys.frame in Rscript)
  script_arg <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", script_arg, value = TRUE)
  if (length(file_arg) > 0L) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]))
    here <- dirname(script_path)
  } else {
    here <- normalizePath(getwd())
  }
  bridges_dir <- file.path(here, "bridges")
  if (!dir.exists(bridges_dir)) {
    message("ERROR: bridges/ directory not found at: ", bridges_dir)
    quit(status = 1)
  }
  all_bridges <- list.files(bridges_dir, pattern = "\\.bridge\\.yaml$",
                            recursive = TRUE, full.names = TRUE)
  message(sprintf("Found %d bridge yamls", length(all_bridges)))
  for (bp in all_bridges) {
    migrate_one_bridge(bp, in_place = FALSE)
  }
} else {
  bridge_path <- args[1]
  in_place <- "--in-place" %in% args
  result <- migrate_one_bridge(bridge_path, in_place = in_place)
  if (!isTRUE(result)) quit(status = 1)
}

quit(status = 0)
