# fn_classify_rating_type.R
# Display-category classifier for comment_attribute predictors in
# poissonCommentAnalysis.R's chart + recommendation panel.
#
# Replaces the English-keyword-only `case_when` at poissonCommentAnalysis.R
# L320-330 that mis-classified every Chinese review-decoded sentiment into
# `其他因素`, degenerating the chart to a single bar + leaving the
# recommendation panel branches permanently empty.
#
# Refs #732
# Principles: MP064 (UI uses DRV pre-computed classification, doesn't reinvent
# name-based heuristics from scratch), DEV_R052 (business logic uses English
# canonical keys, UI translates — but the categories themselves are display
# labels, kept in zh-TW because the dashboard's UI language is zh-TW).

#' Classify each comment_attribute predictor into a display category for the
#' rating-type chart and the recommendation panel filters.
#'
#' Metadata-driven (#732 approach a): the input vector is already pre-filtered
#' upstream to `predictor_type == "comment_attribute"` via #716's metadata
#' classification path. This function maps within that space using:
#'   1. Structural conventions from #733 / Stage 2.5 (`_rating` suffix marks
#'      per-ASIN AI-decoded customer ratings).
#'   2. Canonical comment-meta names (`評論星級` = aggregate star, `評論則數`
#'      = review count).
#'   3. Legacy English keyword heuristic kept as fallback for platforms /
#'      companies with English review attributes (backward compat).
#'   4. A non-`其他因素` default (`產品口碑`) for bare Chinese sentiment names
#'      (`防護有效`, `穿戴舒適`, etc.) that don't match the structural rules.
#'
#' Recommendation-panel reachability: `整體評分` and `客戶評分` MUST remain
#' producible by this function — the panel hard-filters on those two
#' categories.
#'
#' @param predictor Character vector. Predictor variable names from the
#'   poisson analysis output (already filtered to comment_attribute upstream).
#'
#' @return Character vector of the same length, each element one of:
#'   `客戶評分` | `整體評分` | `客戶回饋` | `品質指標` | `價格因素` |
#'   `配送服務` | `服務品質` | `賣家信譽` | `產品規格` | `產品口碑`.
#'
#' @export
classify_rating_type <- function(predictor) {
  if (!is.character(predictor)) {
    stop("classify_rating_type: 'predictor' must be a character vector.")
  }

  dplyr::case_when(
    # Per-ASIN AI-decoded customer review ratings (Stage 2.5, #733)
    grepl("_rating$", predictor)                          ~ "客戶評分",
    # Aggregated overall star rating
    predictor %in% c("評論星級", "rating", "Rating")      ~ "整體評分",
    # Comment count meta-attribute (D3 excludes this upstream; defense in depth)
    predictor %in% c("評論則數", "review_count")           ~ "客戶回饋",
    # Backward-compat: legacy English keyword heuristic for platforms /
    # companies with English review attributes.
    grepl("customer_rating", predictor, ignore.case = TRUE) ~ "客戶評分",
    grepl("品質|質量|quality",   predictor, ignore.case = TRUE) ~ "品質指標",
    grepl("價格|price|cost",     predictor, ignore.case = TRUE) ~ "價格因素",
    grepl("配送|delivery|shipping", predictor, ignore.case = TRUE) ~ "配送服務",
    grepl("售後|服務|service|support", predictor, ignore.case = TRUE) ~ "服務品質",
    grepl("賣家|seller|vendor",  predictor, ignore.case = TRUE) ~ "賣家信譽",
    grepl("diameter|height|size|mm|ratio", predictor, ignore.case = TRUE) ~ "產品規格",
    # Default for bare Chinese sentiment names (e.g. `防護有效`, `穿戴舒適`)
    # — keep visible as `產品口碑` instead of dumping into `其他因素`.
    TRUE                                                   ~ "產品口碑"
  )
}
