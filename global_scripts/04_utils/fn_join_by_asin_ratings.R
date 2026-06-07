# fn_join_by_asin_ratings.R
# Join per-ASIN comment-property ratings onto time-series data for D04 Poisson.
#
# Extracted from `update_scripts/DRV/D04/D04_02.R` per Plan PR #2 sub-decision
# D-B (suffix-rename strategy) + D-E (passthrough imputation) to:
#   1. enable unit testing of JOIN logic independent of DB connections, and
#   2. keep D04_02.R PL loop readable (call-site is ~5 lines instead of ~20).
#
# Spec coverage:
#   - poisson-analysis-comment-ratings > by_asin attribute ratings SHALL be
#     LEFT-joined onto the time series with `_rating` suffix so the (post-#745)
#     classify_predictor_type Stage 2.5 fast-path picks them up as
#     `comment_attribute` predictors.
#   - drv-progressive-completeness > Missing by_asin input SHALL NOT abort the
#     pipeline (MP163) — return ts_data unchanged so D04 proceeds.
#
# Refs #733 (Plan sub-decisions D-A / D-B / D-E)
# Refs #745 (PR #1 — Stage 2.5 fast-path that consumes these suffixed cols)

#' LEFT-join per-ASIN attribute ratings onto a time-series frame
#'
#' Renames each non-key column of `by_asin_data` with a `_rating` suffix so
#' downstream classifiers (Stage 2.5 in `fn_classify_predictor_type`, #733
#' D-D / #745) classify them as `comment_attribute`. Drops the overall
#' `rating` column from `by_asin_data` first to avoid collision with the
#' time-series' own product-listing-level `rating` column (Plan D-B —
#' avoids R `left_join` automatic `.x`/`.y` silent rename).
#'
#' Pure function: same `(ts_data, by_asin_data, ts_key, by_asin_key)` -> same
#' output. No DB connections, no side effects, fully testable in isolation.
#'
#' @param ts_data data.frame. Time series with a platform-specific ID column
#'   (e.g. `amz_asin` for Amazon, `cbz_item_id` / `eby_item_id` for others).
#' @param by_asin_data data.frame or NULL. Per-ASIN attribute averages from
#'   `df_comment_property_ratingonly_by_asin_<pl>`. Typically has
#'   `product_id` (or `asin` per fallback) + `rating` (overall avg) +
#'   N attribute columns. **NULL or 0-row → graceful no-op** (MP163
#'   Progressive Completeness): returns `ts_data` unchanged.
#' @param ts_key Character scalar. Name of the join column in `ts_data`
#'   (e.g. `"amz_asin"`).
#' @param by_asin_key Character scalar. Name of the join column in
#'   `by_asin_data` (typically `"product_id"`; `"asin"` for some pipelines).
#'
#' @return data.frame. `ts_data` with `<attr>_rating` columns appended.
#'   Same row count as `ts_data` (LEFT JOIN preserves all rows;
#'   missing ASINs receive NA in the joined columns).
#'
#' @export
join_by_asin_ratings <- function(ts_data, by_asin_data, ts_key, by_asin_key) {

  # MP163 graceful no-op for missing/empty by_asin input
  if (is.null(by_asin_data) || nrow(by_asin_data) == 0L) {
    return(ts_data)
  }

  # Pre-condition checks
  stopifnot(
    is.data.frame(ts_data),
    is.data.frame(by_asin_data),
    is.character(ts_key), length(ts_key) == 1L, !is.na(ts_key),
    is.character(by_asin_key), length(by_asin_key) == 1L, !is.na(by_asin_key)
  )
  if (!ts_key %in% names(ts_data)) {
    stop("join_by_asin_ratings: ts_key '", ts_key,
         "' not found in ts_data columns. Available: ",
         paste(head(names(ts_data), 10), collapse = ", "),
         if (ncol(ts_data) > 10) " ..." else "",
         call. = FALSE)
  }
  if (!by_asin_key %in% names(by_asin_data)) {
    stop("join_by_asin_ratings: by_asin_key '", by_asin_key,
         "' not found in by_asin_data columns. Available: ",
         paste(head(names(by_asin_data), 10), collapse = ", "),
         if (ncol(by_asin_data) > 10) " ..." else "",
         call. = FALSE)
  }
  # Guard against duplicate by_asin_key values: dplyr::left_join silently
  # expands ts_data rows on duplicate keys, biasing downstream Poisson IRR.
  # Production by_asin tables (per fn_process_comment_property_ratings_by_asin.R
  # group_by/summarise) guarantee unique keys, but defensive check prevents
  # silent corruption from ad-hoc / debugging by_asin constructions.
  # Refs verify HIGH-1 (PR #750, 2026-05-17).
  dup_keys <- by_asin_data[[by_asin_key]][duplicated(by_asin_data[[by_asin_key]])]
  if (length(dup_keys) > 0L) {
    stop("join_by_asin_ratings: by_asin_data has ", length(dup_keys),
         " duplicate value(s) in '", by_asin_key,
         "' column (would cause silent row expansion in LEFT JOIN). ",
         "First few: ", paste(head(unique(dup_keys), 5), collapse = ", "),
         call. = FALSE)
  }

  # Drop the by_asin `rating` overall-average column to avoid collision with
  # ts_data's existing `rating` column (product-listing-level). Per Plan D-B:
  # explicit drop avoids R `left_join`'s silent `.x`/`.y` rename behaviour.
  by_asin_renamed <- by_asin_data
  if ("rating" %in% names(by_asin_renamed)) {
    by_asin_renamed <- by_asin_renamed[, !names(by_asin_renamed) %in% "rating", drop = FALSE]
  }

  # Rename every non-key column with a `_rating` suffix so Stage 2.5
  # (#733 D-D / #745) classifies them as `comment_attribute`.
  rename_mask <- names(by_asin_renamed) != by_asin_key
  names(by_asin_renamed)[rename_mask] <-
    paste0(names(by_asin_renamed)[rename_mask], "_rating")

  # LEFT JOIN: preserves all ts_data rows; missing ASINs get NA in joined cols
  by_clause <- stats::setNames(by_asin_key, ts_key)
  dplyr::left_join(ts_data, by_asin_renamed, by = by_clause)
}
