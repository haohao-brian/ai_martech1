# fn_rating_recommendation.R
# Sign-aware recommendation-phrasing for poissonCommentAnalysis.R's
# 口碑策略建議 (rating recommendation) panel.
#
# Extracted from `poissonCommentAnalysis.R`'s `output$rating_recommendation`
# renderUI per the #777 fix. The phrasing logic previously lived inline in a
# `renderUI` closure with ZERO automated tests (#731 marked it `[~]` SKIP),
# and the DA-H1 sign-direction bug lived there undetected until /idd-verify's
# Devil's Advocate traced the direction by hand. Lifting it into a pure helper
# makes the sign-direction invariant unit-testable (test_rating_recommendation.R).
#
# Refs #777 (render-layer test coverage), #731 (DA-H1 sign-aware recommendation)
# Principles:
# - SO_R007 (one function per file), SO_R026 (fn_ prefix)
# - DEV_R052: business logic uses canonical keys / UI translates — but the
#   recommendation text is the dashboard's user-facing zh-TW prose, kept as-is
#   (same convention as fn_classify_rating_type.R's display labels).

#' Build the 評分優化 recommendation phrase for one comment-attribute factor.
#'
#' The DA-H1 invariant lives here. `r_dir` is the ACTIONABLE direction — the
#' predictor move that INCREASES sales:
#'   - coefficient > 0  -> 提升 (raise the factor)
#'   - coefficient < 0  -> 降低 (lower it: a negative coef means predictor-up
#'                          -> sales-down, so predictor-down -> sales-up)
#'   - coefficient == 0 -> 提升 (non-negative branch; 0 is not `< 0`)
#'
#' Because `r_dir` always points at the sales-increasing move, the sales verb
#' is the CONSTANT 增加 — it must NOT flip with the sign. `marginal_effect_pct`
#' is rendered via `abs()`: the sign is carried by `r_dir`, not by the %.
#'
#' @param coefficient Numeric scalar — the Poisson coefficient for this factor.
#'   Non-NA (the caller's `comment_data` reactive drops NA-coefficient rows).
#' @param display_name Character scalar — the user-facing factor name, placed
#'   verbatim inside the 「」 slot.
#' @param marginal_effect_pct Numeric scalar — per-1-point marginal effect on
#'   sales, in percent. Rendered as `abs()`.
#'
#' @return Character scalar: the recommendation sentence, e.g.
#'   `"重點提升「客戶滿意度」，每提升1分可增加銷量12.5%"` (coef>0) or
#'   `"重點降低「退貨率」，每降低1分可增加銷量8.3%"` (coef<0).
#'
#' @export
build_rating_recommendation_phrase <- function(coefficient,
                                               display_name,
                                               marginal_effect_pct) {

  if (!is.numeric(coefficient) || length(coefficient) != 1L || is.na(coefficient)) {
    stop("build_rating_recommendation_phrase: 'coefficient' must be a non-NA numeric scalar.")
  }
  if (!is.numeric(marginal_effect_pct) || length(marginal_effect_pct) != 1L ||
      is.na(marginal_effect_pct)) {
    stop("build_rating_recommendation_phrase: 'marginal_effect_pct' must be a non-NA numeric scalar.")
  }
  display_name <- as.character(display_name)
  if (length(display_name) != 1L) {
    stop("build_rating_recommendation_phrase: 'display_name' must be a length-1 value.")
  }

  # DA-H1: r_dir = the sales-increasing predictor move. Sales verb is the
  # constant 增加 (inside 可增加銷量) — never flips with the sign.
  r_dir <- if (coefficient < 0) "降低" else "提升"

  paste0("重點", r_dir, "「", display_name, "」，",
         "每", r_dir, "1分可增加銷量",
         abs(marginal_effect_pct), "%")
}
