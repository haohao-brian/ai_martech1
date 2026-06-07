#!/usr/bin/env Rscript
# test_classify_rating_type.R
# ==============================================================================
# #732 — classify_rating_type() metadata-driven display-category mapping for
# poissonCommentAnalysis.R's chart + recommendation panel
#
# Background:
#   poissonCommentAnalysis.R L320-330 historically used an English-keyword-only
#   `case_when` to assign each comment_attribute predictor to one of 8 display
#   categories. QEF (and any company with Chinese review-decoded sentiments)
#   had every predictor fall to the `其他因素` default — chart degenerated to
#   a single bar, recommendation panel branches stayed permanently empty.
#
#   classify_rating_type() (04_utils/fn_classify_rating_type.R) replaces that
#   case_when with a metadata-driven mapping using #716/#733 conventions
#   (Stage 2.5 `_rating` suffix, canonical comment-meta names, English keyword
#   fallback for backward compat).
#
# Refs #732
#
# Principles:
# - MP029 (real fn under test)
# - TD_R007 (plain R + assert pattern, 98_test/general/ convention)
# - MP064 (UI reuses DRV pre-computed classification — no name-based reinvention)
# ==============================================================================

# ---------- Test harness ----------

pass_count <- 0L
fail_count <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    pass_count <<- pass_count + 1L
    message(sprintf("  [PASS] %s", msg))
  } else {
    fail_count <<- fail_count + 1L
    message(sprintf("  [FAIL] %s", msg))
  }
}

# ---------- Setup: source fn under test ----------

fn_candidates <- c(
  file.path("shared", "global_scripts", "04_utils", "fn_classify_rating_type.R"),
  file.path("global_scripts", "04_utils", "fn_classify_rating_type.R"),
  file.path("..", "..", "04_utils", "fn_classify_rating_type.R"),
  file.path("04_utils", "fn_classify_rating_type.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_classify_rating_type.R not found in candidate paths")
}
source(fn_path)
suppressMessages(library(dplyr))

message(sprintf("Testing classify_rating_type from: %s\n", fn_path))

# ---------- Fixture: realistic QEF hsg comment_attribute predictors ----------
# Mix of: Stage 2.5 _rating columns (from #733 by-asin JOIN), canonical
# Chinese comment-meta names, bare Chinese sentiment names, legacy English
# review attributes (for backward-compat coverage).

fixture <- c(
  # Per-ASIN AI-decoded customer ratings (Stage 2.5)
  "防護有效_rating", "性價比佳_rating", "視覺清晰_rating",
  # Aggregated overall ratings
  "評論星級", "rating",
  # Comment count meta-attribute
  "評論則數", "review_count",
  # Bare Chinese sentiment (no _rating suffix)
  "穿戴舒適", "耐用性", "視野清晰",
  # Legacy English with explicit keywords (backward-compat coverage)
  "customer_rating_avg", "product_quality_score", "shipping_speed",
  "service_response", "seller_reliability", "lens_diameter_mm"
)

result <- tryCatch(
  classify_rating_type(fixture),
  error = function(e) structure(character(0), class = "crt_error",
                                msg = conditionMessage(e))
)

assert(
  !inherits(result, "crt_error"),
  sprintf("classify_rating_type runs without error (%s)",
          if (inherits(result, "crt_error")) attr(result, "msg") else "ok")
)

if (!inherits(result, "crt_error")) {

  # Case 1: returns one category per input element
  assert(
    length(result) == length(fixture),
    sprintf("returns 1 category per input (expect %d, got %d)",
            length(fixture), length(result))
  )

  # Helper: lookup one fixture's result
  cat_of <- function(pred) result[fixture == pred]

  # Case 2: #732 core — `_rating` suffix → `客戶評分`
  assert(
    identical(cat_of("防護有效_rating"), "客戶評分"),
    sprintf("`防護有效_rating` → `客戶評分` (got `%s`)", cat_of("防護有效_rating"))
  )
  assert(
    identical(cat_of("性價比佳_rating"), "客戶評分"),
    sprintf("`性價比佳_rating` → `客戶評分` (got `%s`)", cat_of("性價比佳_rating"))
  )

  # Case 3: 評論星級 → 整體評分 (recommendation-panel filter MUST reach this)
  assert(
    identical(cat_of("評論星級"), "整體評分"),
    sprintf("`評論星級` → `整體評分` (got `%s`)", cat_of("評論星級"))
  )
  assert(
    identical(cat_of("rating"), "整體評分"),
    sprintf("`rating` → `整體評分` (got `%s`)", cat_of("rating"))
  )

  # Case 4: 評論則數 / review_count → 客戶回饋 (defense in depth after D3)
  assert(
    identical(cat_of("評論則數"), "客戶回饋"),
    sprintf("`評論則數` → `客戶回饋` (got `%s`)", cat_of("評論則數"))
  )
  assert(
    identical(cat_of("review_count"), "客戶回饋"),
    sprintf("`review_count` → `客戶回饋` (got `%s`)", cat_of("review_count"))
  )

  # Case 5: bare Chinese sentiment (no _rating suffix, not in meta list)
  # → `產品口碑` (NOT `其他因素` — that's the #732 regression)
  for (pred in c("穿戴舒適", "耐用性", "視野清晰")) {
    cat_val <- cat_of(pred)
    assert(
      identical(cat_val, "產品口碑"),
      sprintf("bare Chinese sentiment `%s` → `產品口碑` (got `%s`) [#732 regression test — was `其他因素`]",
              pred, cat_val)
    )
  }

  # Case 6: backward-compat English keyword paths still work
  bc_expect <- list(
    customer_rating_avg     = "客戶評分",
    product_quality_score   = "品質指標",
    shipping_speed          = "配送服務",
    service_response        = "服務品質",
    seller_reliability      = "賣家信譽",
    lens_diameter_mm        = "產品規格"
  )
  for (pred in names(bc_expect)) {
    expected <- bc_expect[[pred]]
    cat_val <- cat_of(pred)
    assert(
      identical(cat_val, expected),
      sprintf("English `%s` → `%s` (got `%s`)", pred, expected, cat_val)
    )
  }

  # Case 7: #732 user-visible regression — recommendation panel needs
  # `整體評分` and `客戶評分` BOTH to be producible from realistic input.
  assert(
    "整體評分" %in% result,
    "recommendation-panel category `整體評分` is reachable from QEF fixture"
  )
  assert(
    "客戶評分" %in% result,
    "recommendation-panel category `客戶評分` is reachable from QEF fixture"
  )

  # Case 8: chart should NOT degenerate to a single bar — categories diverse.
  unique_cats <- length(unique(result))
  assert(
    unique_cats >= 4L,
    sprintf("rating_type yields multiple categories (expect >= 4, got %d) — chart no longer single-bar",
            unique_cats)
  )

  # Case 9: empty input → empty output (no crash)
  empty_res <- tryCatch(
    classify_rating_type(character(0)),
    error = function(e) NA
  )
  assert(
    length(empty_res) == 0L && !is.na(empty_res[1]) || identical(empty_res, character(0)),
    sprintf("empty input → empty output (got length %d)",
            if (is.character(empty_res)) length(empty_res) else NA)
  )
}

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
