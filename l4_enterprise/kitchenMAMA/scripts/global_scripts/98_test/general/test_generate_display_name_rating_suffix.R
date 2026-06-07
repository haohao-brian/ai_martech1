#!/usr/bin/env Rscript
# test_generate_display_name_rating_suffix.R
# ==============================================================================
# #756 — Strip `_rating$` suffix in fn_generate_display_name before lookup
#
# Background:
#   #733 PR #2 introduced `fn_join_by_asin_ratings.R` which LEFT-JOINs per-ASIN
#   attribute rating columns from `df_comment_property_ratingonly_by_asin_<pl>`
#   onto the time-series with a `_rating` suffix (Plan sub-decision D-B avoids
#   dplyr `.x/.y` collision with ts_data's own `rating` column).
#
#   That suffix is a DB-layer naming detail. The display layer should hide it
#   so users see "光學清晰" instead of "光學清晰 rating" in InsightForge.
#
#   The fix adds a one-shot suffix strip near the top of
#   `fn_generate_display_name` (after category_languages loading, before
#   PRIORITY 1 DB lookup) so the rest of the function operates on the base
#   name. The classifier (`fn_classify_predictor_type` Stage 2.5, #745) still
#   sees the original suffixed name at DB layer.
#
# Test strategy:
#   Call fn_generate_display_name with cache_con = NULL (skip DB lookup) so
#   the test is hermetic — outcome depends only on the strip + the existing
#   pattern handlers + default fallback.
#
# Refs #756 (this issue), #733 (suffix introduction), #745 (Stage 2.5)
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_generate_display_name_rating_suffix.R
#
# Principles:
# - MP029: real fn under test, no fake mocks
# - TD_R007: Plain R + assert() pattern (matches 98_test/general/ convention)
# - IC_P002: strip is universal logic — 5 公司共用 fn 仍向後相容(regression cases)
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
  file.path("shared", "global_scripts", "04_utils", "fn_generate_display_name.R"),
  file.path("global_scripts", "04_utils", "fn_generate_display_name.R"),
  file.path("..", "..", "04_utils", "fn_generate_display_name.R"),
  file.path("04_utils", "fn_generate_display_name.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_generate_display_name.R not found in candidate paths")
}
source(fn_path)
message(sprintf("Testing fn_generate_display_name from: %s\n", fn_path))

# Helper: invoke fn with cache_con=NULL (no DB lookup) and return display_name
get_display <- function(predictor, locale = "zh_TW") {
  res <- fn_generate_display_name(predictor, locale = locale, cache_con = NULL)
  res$display_name
}

# ---------- Tests ----------

# Case 1: Chinese attribute + _rating suffix — primary use case
# Expected: strip kicks in → "光學清晰_rating" → "光學清晰" → no `_rating` or
# ` rating` substring in display.
res1 <- get_display("光學清晰_rating")
assert(
  !grepl("_rating", res1, fixed = TRUE) && !grepl(" rating", res1, fixed = TRUE),
  sprintf("`光學清晰_rating` → no _rating / ` rating` in display (got: '%s')", res1)
)

# Case 2: Another Chinese attribute + _rating — regression of Case 1 on
# different content to catch fn-level off-by-one (would only show on
# certain predictor lengths if logic were broken).
res2 <- get_display("配戴舒適_rating")
assert(
  !grepl("_rating", res2, fixed = TRUE) && !grepl(" rating", res2, fixed = TRUE),
  sprintf("`配戴舒適_rating` → no _rating / ` rating` in display (got: '%s')", res2)
)

# Case 3: `customer_ratings` (with trailing s, line 328 prefix handler)
# This goes through the existing `^(customer_ratings|rating)` prefix match.
# Strip MUST NOT interfere — `customer_ratings` doesn't end in `_rating$`
# (it ends in `_ratings`), so strip not triggered.
res3 <- get_display("customer_ratings")
assert(
  identical(res3, "顧客評分"),
  sprintf("`customer_ratings` → '顧客評分' via prefix handler unchanged (got: '%s')", res3)
)

# Case 4: standalone `rating` — nchar guard test.
# `rating` has 6 chars, equal to nchar("_rating") - 1. The strip's nchar
# guard (`nchar > nchar("_rating")`) prevents stripping it to empty string.
# Falls through to line 328 `^rating` prefix handler → "顧客評分".
res4 <- get_display("rating")
assert(
  identical(res4, "顧客評分"),
  sprintf("`rating` (standalone, nchar guard) → '顧客評分' via prefix handler (got: '%s')", res4)
)

# Case 5: `customer_rating_avg` (MAMBA reference, mentioned in fn line 127
# comment). Ends in `_avg` not `_rating` → strip MUST NOT trigger.
# After no-strip, falls to default `gsub("_", " ", ...)` → has "avg".
res5 <- get_display("customer_rating_avg")
assert(
  grepl("avg", res5, ignore.case = TRUE),
  sprintf("`customer_rating_avg` → no incorrect strip, 'avg' preserved in display (got: '%s')", res5)
)

# Case 6: ASCII non-rating predictor — regression for other companies'
# predictors that should be completely unaffected by the strip.
# `seller_nameEiji` is in fn line 31 example comment.
res6 <- get_display("seller_nameEiji")
assert(
  nchar(res6) > 0 && !grepl("_rating", res6, fixed = TRUE),
  sprintf("`seller_nameEiji` (non-rating ASCII regression) → non-empty, no _rating (got: '%s')", res6)
)

# ---------- Summary ----------

message(sprintf("\nResults: %d passed, %d failed", pass_count, fail_count))
if (fail_count > 0) {
  message("FAIL: Some cases did not pass.")
  quit(status = 1)
}
message("PASS: All cases.")
quit(status = 0)
