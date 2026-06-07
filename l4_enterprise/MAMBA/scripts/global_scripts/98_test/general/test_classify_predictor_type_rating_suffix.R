#!/usr/bin/env Rscript
# test_classify_predictor_type_rating_suffix.R
# ==============================================================================
# #733 — Stage 2.5 `_rating$` suffix fast-path in classify_predictor_type
#
# Background:
#   PR #733 (this) adds Stage 2.5 to fn_classify_predictor_type.R between
#   Stage 2 (structural identifiers) and Stage 3 (metadata lookup):
#
#     # ---- Stage 2.5: rating suffix fast-path ----
#     if (grepl("_rating$", term_lower)) return("comment_attribute")
#
#   Without Stage 2.5, `光學清晰_rating` would either:
#   (a) Match Stage 3 metadata if present (unreliable — depends on seed)
#   (b) Fall to Stage 4 substring `rating` (catches false positive `rating_count`,
#       `rating_threshold` too — imprecise)
#   (c) Require `platform` argument since past Stage 2 platform is mandatory
#
#   Stage 2.5 is precise (suffix-only) AND no platform required (runs before
#   Stage 3 lookup).
#
# Test strategy:
#   The cleanest RED→GREEN signal is calling classify_predictor_type with
#   platform="" — currently Stage 2 falls through to platform-required check
#   and stops; AFTER Stage 2.5, `_rating$` short-circuits and returns
#   "comment_attribute" without needing platform.
#
# Refs #733 sub-decision D-D (5-stage → 6-stage with Stage 2.5)
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_classify_predictor_type_rating_suffix.R
#
# Principles:
# - MP029: real fn under test, no fake mocks
# - TD_R007: Plain R + assert() pattern (matches 98_test/general/ convention)
# - IC_P002: stage 2.5 is pure-additive, 5 公司共用 fn 仍向後相容
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

# Resolve fn_classify_predictor_type.R via standard candidate-path pattern
# (matches sourcing convention in D04_02.R)
fn_candidates <- c(
  file.path("shared", "global_scripts", "04_utils", "fn_classify_predictor_type.R"),
  file.path("global_scripts", "04_utils", "fn_classify_predictor_type.R"),
  file.path("..", "..", "04_utils", "fn_classify_predictor_type.R"),
  file.path("04_utils", "fn_classify_predictor_type.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_classify_predictor_type.R not found in candidate paths")
}
source(fn_path)

message(sprintf("Testing classify_predictor_type from: %s\n", fn_path))

# ---------- Tests ----------

# Case 1: Chinese attribute + _rating suffix, no platform required
# Stage 2.5 should short-circuit return "comment_attribute" without
# triggering the platform-required stop.
res1 <- tryCatch(
  classify_predictor_type("光學清晰_rating", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res1, "comment_attribute"),
  sprintf("Chinese `光學清晰_rating` with platform='' → 'comment_attribute' via Stage 2.5 (got: %s)", res1)
)

# Case 2: English mixed + _rating suffix, no platform required
res2 <- tryCatch(
  classify_predictor_type("customer_rating", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res2, "comment_attribute"),
  sprintf("English `customer_rating` with platform='' → 'comment_attribute' via Stage 2.5 (got: %s)", res2)
)

# Case 3: Uppercase + _rating suffix (tolower coverage)
res3 <- tryCatch(
  classify_predictor_type("CUSTOMER_RATING_rating", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res3, "comment_attribute"),
  sprintf("Uppercase `CUSTOMER_RATING_rating` with platform='' → 'comment_attribute' via Stage 2.5 (got: %s)", res3)
)

# Case 4: Substring `rating` but NO `_rating$` suffix — Stage 2.5 must NOT match.
# `rating_threshold` should fall through Stage 2.5 → require platform → with
# platform="amz" reach Stage 4 substring match → return comment_attribute.
# This is the regression test for stage 2.5 precision (suffix not substring).
res4_no_plat <- tryCatch(
  classify_predictor_type("rating_threshold", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  grepl("platform.*required", res4_no_plat, ignore.case = TRUE),
  sprintf("`rating_threshold` (no suffix) with platform='' should fall past Stage 2.5 to platform-required stop (got: %s)", res4_no_plat)
)

# Case 5: Stage 2 (structural) still wins — regression
# Note: use `product_id` not `amz_asin` — stage 2 regex `^asin$` is anchored
# to full-string match, doesn't match `amz_asin`. `product_id` matches `_id$`.
res5 <- tryCatch(
  classify_predictor_type("product_id", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res5, "structural"),
  sprintf("`product_id` → 'structural' via Stage 2 (got: %s)", res5)
)

# Case 6: Stage 1 (time feature) still wins — regression
res6 <- tryCatch(
  classify_predictor_type("month_1", platform = ""),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res6, "time_feature"),
  sprintf("`month_1` → 'time_feature' via Stage 1 (got: %s)", res6)
)

# ============================================================================
# #747 — Stage 1 regex `$` end anchor (year|day|week|quarter|is_holiday|is_weekend)
# ============================================================================
#
# Background:
#   Stage 1 third alternation at fn_classify_predictor_type.R:67 lacked `$`
#   end anchor:
#     grepl("^(year|day|week|quarter|is_holiday|is_weekend)", term_lower)
#   This caused `<time-prefix>_rating` terms (e.g. `day_rating`) to short-
#   circuit at Stage 1 with `time_feature` instead of falling to Stage 2.5
#   `_rating$` fast-path → `comment_attribute`. Empirically reproduced in
#   /idd-verify #733 --pr 745 DA-1 (HIGH) and re-confirmed for #747.
#
# Test strategy:
#   - Cases 7-12: `<time-prefix>_rating` MUST classify as `comment_attribute`
#     (Stage 2.5 wins after fix). Before fix → Stage 1 wins → bug.
#   - Cases 13-18: Canonical Stage 1 tokens MUST still classify as
#     `time_feature` (regression guard — `$` anchor allows exact-match).
#   - Cases 19-20: `year_2024` / `day_of_week` compound names — document
#     intentional behavior change (after fix: falls past Stage 1+2+2.5 to
#     Stage 5 default `product_attribute`; before fix: `time_feature`).
#
# Refs #747 (Stage 1 regex `$` end anchor)

# ---------- Cases 7-12: <time-prefix>_rating → comment_attribute via Stage 2.5 ----------

time_prefix_rating_cases <- list(
  list(term = "day_rating",        label = "day_rating"),
  list(term = "year_rating",       label = "year_rating"),
  list(term = "week_rating",       label = "week_rating"),
  list(term = "quarter_rating",    label = "quarter_rating"),
  list(term = "is_holiday_rating", label = "is_holiday_rating"),
  list(term = "is_weekend_rating", label = "is_weekend_rating")
)

for (tc in time_prefix_rating_cases) {
  res <- tryCatch(
    classify_predictor_type(tc$term, platform = ""),
    error = function(e) paste0("ERROR: ", e$message)
  )
  assert(
    identical(res, "comment_attribute"),
    sprintf("`%s` with platform='' → 'comment_attribute' via Stage 2.5 (got: %s)",
            tc$label, res)
  )
}

# ---------- Cases 13-18: canonical time tokens still win Stage 1 (regression) ----------

canonical_time_tokens <- c("day", "year", "week", "quarter", "is_holiday", "is_weekend")

for (term in canonical_time_tokens) {
  res <- tryCatch(
    classify_predictor_type(term, platform = ""),
    error = function(e) paste0("ERROR: ", e$message)
  )
  assert(
    identical(res, "time_feature"),
    sprintf("`%s` (canonical) → 'time_feature' via Stage 1 (got: %s)", term, res)
  )
}

# ---------- Cases 19-20: compound names — intentional behavior change after #747 ----------
# Before #747 fix: `year_2024` / `day_of_week` matched unanchored Stage 1 prefix
#                  → `time_feature` (latent bug)
# After #747 fix:  falls past Stage 1 (no exact match) + Stage 2 (no structural)
#                  + Stage 2.5 (no `_rating$`) + Stage 3 (no metadata, platform="amz")
#                  + Stage 4 (no keyword match) → Stage 5 default `product_attribute`
#
# These cases DOCUMENT the regression. If a real caller emerges that needs
# `year_2024` / `day_of_week` to be `time_feature`, add an explicit Stage 1
# rule rather than relying on unanchored regex.

res_year_2024 <- tryCatch(
  classify_predictor_type("year_2024", platform = "amz"),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res_year_2024, "product_attribute"),
  sprintf("`year_2024` (compound) → 'product_attribute' via Stage 5 default after #747 (got: %s)",
          res_year_2024)
)

res_day_of_week <- tryCatch(
  classify_predictor_type("day_of_week", platform = "amz"),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  identical(res_day_of_week, "product_attribute"),
  sprintf("`day_of_week` (compound) → 'product_attribute' via Stage 5 default after #747 (got: %s)",
          res_day_of_week)
)

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
