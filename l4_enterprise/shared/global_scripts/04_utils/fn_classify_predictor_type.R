# fn_classify_predictor_type.R
# Predictor type classification with metadata-driven dispatch.
#
# Extracted from `update_scripts/DRV/D04/D04_02.R` to a standalone utility per
# `metadata-driven-predictor-type-classification` change. Sourced by D04_02.R
# and any future DRV / Shiny consumer that needs to classify predictor names.
#
# Spec coverage:
#   - predictor-type-classifier-lookup > classify_predictor_type SHALL accept
#     a platform parameter, dispatch through fast-path / metadata / keyword
#     fallback / default, and remain a pure function.
#   - drv-platform-agnosticism > Platform-agnostic DRV helpers SHALL accept
#     platform as a function parameter.
#
# Refs #716

#' Classify a predictor term into one of four canonical types
#'
#' Five-stage dispatch:
#'   1. Time fast-path (month_N, weekday names, is_holiday, is_weekend,
#'      quarter, year, day, week)
#'   2. Structural fast-path (_name$, _id$, _code$, ^sku$, ^asin$, _series_name)
#'   3. Metadata lookup via predictor_meta_lookup(platform, term)
#'   4. English keyword fallback (rating|sentiment|review|comment|stars|feedback)
#'   5. Default `product_attribute`
#'
#' Stages are evaluated in order; first match wins. Pure function: same
#' (term, platform, predictor_meta_lookup snapshot) -> same output.
#'
#' @param term Character. Predictor variable name (e.g. "month_1",
#'   "amz_asin", "偏光功能", "customer_rating", "鏡框寬度").
#' @param platform Character. Platform identifier; defaults to
#'   `Sys.getenv("DRV_PLATFORM")`. Required for stage 3 metadata lookup.
#'   Raises actionable error when empty AND falling through past stage 2.
#' @param predictor_meta_lookup Function or NULL. Optional lookup function
#'   accepting `(platform, column_name)` and returning either a list with
#'   `predictor_type` and `source` fields, or NULL on miss. When NULL or
#'   when the lookup returns NULL, dispatch falls through to stage 4
#'   keyword fallback. The classifier itself does NOT open DB connections;
#'   callers wire this via `load_predictor_classification` or a cached
#'   in-memory function (see DRV/D04/D04_02.R for the canonical caller).
#'
#' @return Character. One of:
#'   `time_feature` | `product_attribute` | `comment_attribute` | `structural`.
#'
#' @export
classify_predictor_type <- function(term,
                                     platform = Sys.getenv("DRV_PLATFORM"),
                                     predictor_meta_lookup = NULL) {

  if (is.null(term) || !is.character(term) || length(term) != 1L ||
      is.na(term)) {
    stop(
      "classify_predictor_type: 'term' must be a non-NA character scalar. ",
      "Got: ", paste(deparse(term), collapse = " "),
      call. = FALSE
    )
  }

  term_lower <- tolower(term)

  # ---- Stage 1: time features (no metadata, no platform needed) ----
  is_time <-
    grepl("^month_[0-9]+$", term_lower) ||
    grepl("^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$",
          term_lower) ||
    grepl("^(year|day|week|quarter|is_holiday|is_weekend)$", term_lower)
  if (is_time) return("time_feature")

  # ---- Stage 2: structural identifiers (no metadata, no platform needed) ----
  is_structural <- grepl("_name$|_id$|_code$|^sku$|^asin$|_series_name",
                          term_lower)
  if (is_structural) return("structural")

  # ---- Stage 2.5: rating suffix fast-path (no metadata, no platform needed) ----
  # Per #733 sub-decision D-D: `<attr>_rating` columns added by D04_02 LEFT JOIN
  # from `df_comment_property_ratingonly_by_asin_<pl>` are per-ASIN aggregated
  # review ratings. The `_rating$` suffix is a canonical signal — precise
  # (suffix only, not substring) and platform-independent.
  #
  # Without this stage, `_rating`-suffixed columns would either:
  #   - require platform argument to reach Stage 3/4 (operational friction), or
  #   - match Stage 4 substring `rating` (catches false positives like
  #     `rating_count` / `rating_threshold` too)
  #
  # Refs #733 (Plan tier sub-decision D-D, plan body issuecomment-4470211851).
  if (grepl("_rating$", term_lower)) return("comment_attribute")

  # Beyond stage 2.5, all remaining stages either consult per-platform metadata
  # or operate per-platform semantics — platform must be resolvable.
  if (is.null(platform) || !nzchar(platform) || is.na(platform)) {
    stop(
      "classify_predictor_type: 'platform' is required for metadata-driven ",
      "stages (3-5). Pass via function argument, or set ",
      "Sys.setenv(DRV_PLATFORM = \"<code>\") in the orchestrator. ",
      "Resolution sources tried: function arg + Sys.getenv(\"DRV_PLATFORM\").",
      call. = FALSE
    )
  }

  # ---- Stage 3: metadata lookup (source-driven) ----
  if (is.function(predictor_meta_lookup)) {
    meta <- tryCatch(
      predictor_meta_lookup(platform, term),
      error = function(e) {
        # Per spec predictor-type-classifier-lookup > "pure function" >
        # "SHALL NOT raise unrecoverable errors on metadata miss":
        # swallow lookup errors and fall through to keyword fallback.
        warning(
          "classify_predictor_type: predictor_meta_lookup failed (", e$message,
          "); falling through to keyword stage. term=", term, " platform=",
          platform,
          call. = FALSE
        )
        NULL
      }
    )
    if (!is.null(meta) && !is.null(meta$predictor_type) &&
        nzchar(meta$predictor_type)) {
      return(meta$predictor_type)
    }
  }

  # ---- Stage 4: English keyword fallback (legacy / backward compat) ----
  # Preserved to keep behavior identical on platforms that have not yet been
  # migrated to emit metadata, AND to handle genuinely English review-decoded
  # column names (e.g. customer_rating_avg in MAMBA).
  is_comment <- grepl("rating|sentiment|review|comment|stars|feedback",
                       term_lower)
  if (is_comment) return("comment_attribute")

  # ---- Stage 5: default ----
  "product_attribute"
}
