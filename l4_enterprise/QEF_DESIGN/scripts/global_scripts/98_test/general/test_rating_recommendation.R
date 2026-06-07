#!/usr/bin/env Rscript
# test_rating_recommendation.R
# ==============================================================================
# #777 — render-layer test coverage for poissonCommentAnalysis.R
#
# Background:
#   PR #772 (#731 D1 + DA-H1) made the poissonComment recommendation panel
#   sign-aware. After D1 lifted the `coefficient > 0` filter, negative-coef
#   rows reach `output$rating_recommendation`. The DA-H1 fix:
#     - `r_dir` is the ACTIONABLE direction (the predictor move that INCREASES
#       sales): coef>0 -> 提升, coef<0 -> 降低 (a negative coef means
#       predictor-up -> sales-down, so predictor-down -> sales-up).
#     - the sales verb is the CONSTANT 增加 — it must NOT flip with the sign.
#       An earlier draft flipped both verbs, producing "降低 X -> 減少銷量"
#       for negative coef, which is directionally backwards.
#
#   This logic lived inline in a `renderUI` closure with ZERO automated tests
#   (#731 marked it `[~]` SKIP). The DA-H1 bug was caught only because
#   /idd-verify's Devil's Advocate traced the direction by hand. #777 extracts
#   the phrasing logic into `build_rating_recommendation_phrase()` and pins it
#   here so a future refactor cannot silently re-introduce the trap.
#
# Refs #777 (render-layer test coverage), #731 (DA-H1 sign-aware recommendation)
#
# Principles:
# - MP029: real fn under test, no fake mocks
# - TD_R007: plain R + assert() pattern (98_test/general/ convention)
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
  file.path("shared", "global_scripts", "04_utils", "fn_rating_recommendation.R"),
  file.path("global_scripts", "04_utils", "fn_rating_recommendation.R"),
  file.path("..", "..", "04_utils", "fn_rating_recommendation.R"),
  file.path("04_utils", "fn_rating_recommendation.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_rating_recommendation.R not found in candidate paths")
}
source(fn_path)

message(sprintf("Testing build_rating_recommendation_phrase from: %s\n", fn_path))

# ---------- Tests ----------

# Case 1: positive coefficient -> 重點提升 + 每提升1分
phrase_pos <- build_rating_recommendation_phrase(
  coefficient = 0.42, display_name = "客戶滿意度", marginal_effect_pct = 12.5)
assert(
  grepl("重點提升", phrase_pos, fixed = TRUE) &&
    grepl("每提升1分", phrase_pos, fixed = TRUE),
  sprintf("coef>0 -> 重點提升 + 每提升1分 (got: %s)", phrase_pos)
)

# Case 2: negative coefficient -> 重點降低 + 每降低1分
phrase_neg <- build_rating_recommendation_phrase(
  coefficient = -0.42, display_name = "退貨率", marginal_effect_pct = 8.3)
assert(
  grepl("重點降低", phrase_neg, fixed = TRUE) &&
    grepl("每降低1分", phrase_neg, fixed = TRUE),
  sprintf("coef<0 -> 重點降低 + 每降低1分 (got: %s)", phrase_neg)
)

# Case 3 (DA-H1 keystone): negative coef STILL says 可增加銷量.
# `r_dir` always points at the sales-INCREASING move, so the sales verb is
# the constant 增加 — it must NOT become 減少 for negative-coef rows.
assert(
  grepl("可增加銷量", phrase_neg, fixed = TRUE) &&
    !grepl("減少", phrase_neg, fixed = TRUE),
  sprintf("DA-H1: coef<0 phrase keeps constant 可增加銷量, no 減少 (got: %s)", phrase_neg)
)

# Case 4: positive coef also says 可增加銷量 (verb constant on both signs)
assert(
  grepl("可增加銷量", phrase_pos, fixed = TRUE),
  sprintf("coef>0 phrase says 可增加銷量 (got: %s)", phrase_pos)
)

# Case 5: marginal_effect_pct rendered via abs() — a negative pct input
# still shows the positive magnitude (the sign is carried by r_dir, not the %).
phrase_negpct <- build_rating_recommendation_phrase(
  coefficient = -0.6, display_name = "缺貨次數", marginal_effect_pct = -8.3)
assert(
  grepl("8.3%", phrase_negpct, fixed = TRUE) &&
    !grepl("-8.3", phrase_negpct, fixed = TRUE),
  sprintf("negative marginal_effect_pct -> abs magnitude shown (got: %s)", phrase_negpct)
)

# Case 6: display_name interpolated verbatim inside the 「」 slot
assert(
  grepl("「客戶滿意度」", phrase_pos, fixed = TRUE),
  sprintf("display_name interpolated verbatim in 「」 (got: %s)", phrase_pos)
)

# Case 7: coefficient exactly 0 -> non-negative branch (提升), matching the
# `coefficient < 0` predicate (0 is NOT < 0).
phrase_zero <- build_rating_recommendation_phrase(
  coefficient = 0, display_name = "中性因子", marginal_effect_pct = 0)
assert(
  grepl("重點提升", phrase_zero, fixed = TRUE) &&
    !grepl("重點降低", phrase_zero, fixed = TRUE),
  sprintf("coef==0 -> 提升 branch (got: %s)", phrase_zero)
)

# Case 8: large negative coefficient (the QEF hsg `評論星級` coef ~ -5.45 case)
# -> 重點降低, no crash, finite magnitude.
phrase_big <- tryCatch(
  build_rating_recommendation_phrase(
    coefficient = -5.45, display_name = "評論星級", marginal_effect_pct = -500),
  error = function(e) structure(list(), class = "brrp_error",
                                msg = conditionMessage(e))
)
assert(
  !inherits(phrase_big, "brrp_error") &&
    grepl("重點降低", phrase_big, fixed = TRUE),
  sprintf("large negative coef -> 重點降低, no crash (%s)",
          if (inherits(phrase_big, "brrp_error")) attr(phrase_big, "msg")
          else phrase_big)
)

# Case 9 + 10 (verify #777 MEDIUM-2): exact-string equality. The grepl(fixed=)
# substring checks above would still pass if a literal fragment (「」，/ 每 /
# 可增加銷量 / %) were dropped or reordered — but the whole point of the
# extraction is byte-identity with the original inline paste0. Pin the WHOLE
# string for both signs.
assert(
  identical(phrase_pos, "重點提升「客戶滿意度」，每提升1分可增加銷量12.5%"),
  sprintf("exact-string equality, coef>0 (got: %s)", phrase_pos)
)
assert(
  identical(phrase_neg, "重點降低「退貨率」，每降低1分可增加銷量8.3%"),
  sprintf("exact-string equality, coef<0 (got: %s)", phrase_neg)
)

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
