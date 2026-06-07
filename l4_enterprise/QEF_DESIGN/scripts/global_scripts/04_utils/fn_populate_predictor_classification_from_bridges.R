# fn_populate_predictor_classification_from_bridges.R
# Bridge-yaml-driven populate of df_predictor_classification metadata table.
#
# Reads bridges/<company>/<platform>/*.bridge.yaml field_extractors, derives
# predictor_type from canonical name semantic prefix (per design.md
# Refinement 1+2), writes rows to df_predictor_classification.
#
# Spec coverage:
#   - predictor-type-metadata-table > Producer ETL enforces schema
#   - predictor-type-source-emit > Source provenance SHALL be the sole driver
#     of predictor_type (bridge yaml prefix encoding IS provenance)
#   - "predictor classification emit SHALL be idempotent" (DELETE+INSERT per
#     platform)
#
# Bound by spectra change: metadata-driven-predictor-type-classification
# Refs #716

#' Derive predictor_type from a canonical name via semantic-prefix rules.
#'
#' Mapping (per design.md Refinement 1):
#'   rating_*      / review_count / review_rating         -> comment_attribute
#'   feature_*     / protection_* / dimension_*           -> product_attribute
#'   color_*       / material_* / accessory_*             -> product_attribute
#'   activity_*    / scene_* / demographic_* / user_*     -> product_attribute (conservative, Refinement 3)
#'   cleaning_*    / rank / is_*                          -> product_attribute
#'   brand / sku / asin / url / product_name              -> structural
#'   default                                              -> product_attribute
#'
#' @param canonical_name Character scalar. Canonical column name from
#'   bridge yaml field_extractors key (e.g. "rating_no_distortion").
#' @return Character. One of "comment_attribute" / "product_attribute" /
#'   "structural" / "time_feature".
#' @export
derive_predictor_type_from_canonical_name <- function(canonical_name) {
  if (is.null(canonical_name) || !is.character(canonical_name) ||
      length(canonical_name) != 1L || is.na(canonical_name) ||
      !nzchar(canonical_name)) {
    stop("derive_predictor_type_from_canonical_name: canonical_name must be ",
         "a non-empty character scalar. Got: ",
         paste(deparse(canonical_name), collapse = " "),
         call. = FALSE)
  }

  cn_lower <- tolower(canonical_name)

  # Structural identifiers (exact match)
  if (cn_lower %in% c("brand", "sku", "asin", "url", "product_name",
                      "sales_platform")) {
    return("structural")
  }

  # Time features (exact / prefix match)
  if (grepl("^(month_[0-9]+|monday|tuesday|wednesday|thursday|friday|saturday|sunday|year|day|week|quarter|is_holiday|is_weekend)$", cn_lower)) {
    return("time_feature")
  }

  # Comment / sentiment prefixes
  if (cn_lower %in% c("review_count", "review_rating") ||
      grepl("^rating_", cn_lower)) {
    return("comment_attribute")
  }

  # Default: product_attribute (covers feature_*/protection_*/dimension_*/
  # color_*/material_*/accessory_*/activity_*/scene_*/demographic_*/user_*/
  # cleaning_*/rank/is_*/etc + unknown canonical names per Refinement 3
  # conservative classification)
  "product_attribute"
}

#' Populate df_predictor_classification from bridge yaml field_extractors.
#'
#' Algorithm:
#'   1. Scan bridge_root/<company>/<platform>/*.bridge.yaml (skip wip/)
#'   2. For each yaml: read field_extractors mapping
#'   3. For each (canonical_name -> source_chinese_name): derive predictor_type
#'   4. Build per-platform emit_df with columns (platform, column_name,
#'      predictor_type, source='bridge_yaml')
#'   5. Idempotent DELETE WHERE platform=X AND source='bridge_yaml',
#'      then INSERT new rows
#'
#' @param company Character. Company namespace (e.g. "QEF_DESIGN").
#' @param meta_con DBI connection to meta_data.duckdb (writable).
#' @param bridge_root Character. Root directory containing bridge yamls.
#'   Default: shared/global_scripts/01_db/raw_schema/_authoring/bridges
#' @return Integer. Total rows written.
#' @export
populate_predictor_classification_from_bridges <- function(company,
                                                          meta_con,
                                                          bridge_root = NULL) {
  if (is.null(company) || !is.character(company) || length(company) != 1L ||
      !nzchar(company)) {
    stop("populate_predictor_classification_from_bridges: 'company' must be ",
         "a non-empty character scalar. Got: ",
         paste(deparse(company), collapse = " "), call. = FALSE)
  }
  if (is.null(meta_con) || !DBI::dbIsValid(meta_con)) {
    stop("populate_predictor_classification_from_bridges: 'meta_con' must be ",
         "a valid DBI connection to meta_data.duckdb.", call. = FALSE)
  }
  if (is.null(bridge_root)) {
    stop("populate_predictor_classification_from_bridges: 'bridge_root' must ",
         "be provided. Typical value: ",
         "shared/global_scripts/01_db/raw_schema/_authoring/bridges",
         call. = FALSE)
  }
  if (!dir.exists(bridge_root)) {
    stop("populate_predictor_classification_from_bridges: bridge_root does ",
         "not exist: ", bridge_root, call. = FALSE)
  }

  company_dir <- file.path(bridge_root, company)
  if (!dir.exists(company_dir)) {
    # No bridge yamls for this company yet -> 0 rows is valid outcome
    return(0L)
  }

  # Discover platform subdirs (e.g. amz/, cbz/, eby/)
  platform_dirs <- list.dirs(company_dir, recursive = FALSE)
  platform_dirs <- platform_dirs[basename(platform_dirs) != "wip"]

  total_rows <- 0L

  for (plat_dir in platform_dirs) {
    platform_code <- basename(plat_dir)

    # Find non-wip bridge yamls (top-level only; skip wip/ subdir)
    yamls <- list.files(plat_dir, pattern = "\\.bridge\\.yaml$",
                        full.names = TRUE, recursive = FALSE)
    if (length(yamls) == 0L) next

    # Accumulate per-platform mapping (dedup canonical names across PLs)
    seen_source_names <- character(0)
    rows_for_platform <- list()

    for (yaml_path in yamls) {
      parsed <- tryCatch(
        yaml::read_yaml(yaml_path),
        error = function(e) {
          stop("populate_predictor_classification_from_bridges: failed to ",
               "parse yaml at ", yaml_path, ": ", conditionMessage(e),
               call. = FALSE)
        }
      )

      fe <- parsed$field_extractors
      if (is.null(fe) || length(fe) == 0L) next

      for (canonical in names(fe)) {
        entry <- fe[[canonical]]
        source_name <- entry$name %||% entry$from_column %||% NULL
        if (is.null(source_name) || !nzchar(as.character(source_name))) next

        source_name <- as.character(source_name)

        # Dedup: skip if already seen this source name for this platform
        if (source_name %in% seen_source_names) next
        seen_source_names <- c(seen_source_names, source_name)

        ptype <- derive_predictor_type_from_canonical_name(canonical)
        rows_for_platform[[length(rows_for_platform) + 1L]] <- data.frame(
          platform       = platform_code,
          column_name    = source_name,
          predictor_type = ptype,
          source         = "bridge_yaml",
          added_at       = Sys.time(),
          stringsAsFactors = FALSE
        )
      }
    }

    if (length(rows_for_platform) == 0L) next

    emit_df <- do.call(rbind, rows_for_platform)

    # Idempotent: meta_init is the SINGLE producer (per design.md Refinement 2),
    # so clear ALL existing rows for this platform, then insert fresh.
    # This self-heals legacy rows from prior implementations (e.g. sources
    # 'product_attributes_gsheet'/'review_agg'/'sales_meta'/'time_features'
    # emitted by the reverted sales_time_series 2TR emit block).
    DBI::dbExecute(meta_con,
      "DELETE FROM df_predictor_classification WHERE platform = ?",
      params = list(platform_code)
    )
    DBI::dbWriteTable(meta_con, "df_predictor_classification",
                      emit_df, append = TRUE)

    total_rows <- total_rows + nrow(emit_df)
  }

  total_rows
}

# Null-coalescing operator (avoid rlang dep)
`%||%` <- function(a, b) if (is.null(a)) b else a
