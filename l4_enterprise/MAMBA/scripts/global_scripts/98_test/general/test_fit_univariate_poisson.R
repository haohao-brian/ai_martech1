#!/usr/bin/env Rscript
# test_fit_univariate_poisson.R
# ==============================================================================
# #755 / #718 — per-predictor NA filtering + drop-reason classification
#
# Background:
#   D04_02.R historically did a GLOBAL complete-case `tidyr::drop_na()` on the
#   whole (sales + ~150 predictor) modeling table BEFORE the univariate loop.
#   With heterogeneous NA patterns (the #733 `_rating` JOIN adds 59 cols that
#   are NA for unmatched ASINs), no single row is non-NA across all predictors
#   -> `drop_na()` returns 0 rows -> every PL writes an empty schema.
#
#   But the loop fits UNIVARIATE models `glm(sales ~ predictor_k)` — model k
#   only needs `(sales, predictor_k)` non-NA. The global filter is wrong for
#   this design.
#
#   `fit_univariate_poisson()` (04_utils/fn_fit_univariate_poisson.R) does the
#   NA filtering PER PREDICTOR: each model fits on its own maximal non-NA
#   subset. It also emits per-predictor `n_obs` (#755 — real sample_size) and
#   `drop_reason` (#718 — explainable dropped rate).
#
# Refs #755 (per-predictor NA filter), #718 (drop-reason classification)
#
# Principles:
# - MP029: real fn under test, no fake mocks
# - TD_R007: plain R + assert() pattern (98_test/general/ convention)
# - MP163: estimate what you can; don't drop rows for absent inputs
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
  file.path("shared", "global_scripts", "04_utils", "fn_fit_univariate_poisson.R"),
  file.path("global_scripts", "04_utils", "fn_fit_univariate_poisson.R"),
  file.path("..", "..", "04_utils", "fn_fit_univariate_poisson.R"),
  file.path("04_utils", "fn_fit_univariate_poisson.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_fit_univariate_poisson.R not found in candidate paths")
}
source(fn_path)

message(sprintf("Testing fit_univariate_poisson from: %s\n", fn_path))

# ---------- Fixture: heterogeneous NA pattern ----------
# 100 rows. sales = Poisson counts (always present).
# predA: present rows 1-50,  NA rows 51-100
# predB: NA rows 1-50,        present rows 51-100
# Global complete-case drop_na(sales,predA,predB) -> 0 rows (every row has one NA).
# Per-predictor: predA fits on 50 rows, predB fits on 50 rows -> BOTH estimable.

set.seed(733)
n <- 100L
sales <- rpois(n, lambda = 3)

predA <- c(rnorm(50, mean = 1), rep(NA_real_, 50))   # present 1-50
predB <- c(rep(NA_real_, 50), rnorm(50, mean = 1))   # present 51-100

# predC: present only on rows 1-30, and CONSTANT there (all 1) -> not estimable
predC <- c(rep(1, 30), rep(NA_real_, 70))

fixture <- data.frame(sales = sales, predA = predA, predB = predB, predC = predC)

# ---------- Tests ----------

res <- tryCatch(
  fit_univariate_poisson(fixture, c("predA", "predB", "predC")),
  error = function(e) structure(list(), class = "fup_error", msg = conditionMessage(e))
)

assert(
  !inherits(res, "fup_error"),
  sprintf("fit_univariate_poisson runs without error (%s)",
          if (inherits(res, "fup_error")) attr(res, "msg") else "ok")
)

if (!inherits(res, "fup_error")) {

  # Case 1: returns one row per predictor
  assert(
    nrow(res) == 3L,
    sprintf("returns 1 row per predictor — expect 3, got %d", nrow(res))
  )

  # Case 2: predA estimable (heterogeneous NA does NOT zero it)
  rowA <- res[res$predictor == "predA", , drop = FALSE]
  assert(
    nrow(rowA) == 1L && identical(rowA$estimation_status, "estimated"),
    sprintf("predA estimable via per-predictor NA filter (status=%s)",
            if (nrow(rowA) == 1L) rowA$estimation_status else "MISSING")
  )

  # Case 3: predB estimable too (complementary NA pattern)
  rowB <- res[res$predictor == "predB", , drop = FALSE]
  assert(
    nrow(rowB) == 1L && identical(rowB$estimation_status, "estimated"),
    sprintf("predB estimable via per-predictor NA filter (status=%s)",
            if (nrow(rowB) == 1L) rowB$estimation_status else "MISSING")
  )

  # Case 4: #755 — per-predictor real N. predA fits on its own 50 non-NA rows.
  assert(
    nrow(rowA) == 1L && !is.na(rowA$n_obs) && rowA$n_obs == 50L,
    sprintf("predA n_obs == 50 (per-predictor real sample size, got %s)",
            if (nrow(rowA) == 1L) as.character(rowA$n_obs) else "MISSING")
  )

  # Case 5: #718 — predC constant within its non-NA subset -> not_estimable
  #         with an explainable drop_reason.
  rowC <- res[res$predictor == "predC", , drop = FALSE]
  assert(
    nrow(rowC) == 1L && identical(rowC$estimation_status, "not_estimable"),
    sprintf("predC (constant-in-subset) -> not_estimable (status=%s)",
            if (nrow(rowC) == 1L) rowC$estimation_status else "MISSING")
  )
  assert(
    nrow(rowC) == 1L && !is.na(rowC$drop_reason) &&
      grepl("constant", rowC$drop_reason, ignore.case = TRUE),
    sprintf("predC drop_reason names the constant-in-subset cause (got: %s)",
            if (nrow(rowC) == 1L) as.character(rowC$drop_reason) else "MISSING")
  )

  # Case 6: estimated rows carry a non-NA coefficient
  assert(
    nrow(rowA) == 1L && !is.na(rowA$coefficient),
    "estimated predA has a non-NA coefficient"
  )

  # Case 7: drop_reason is NA for successfully-estimated predictors
  assert(
    nrow(rowA) == 1L && is.na(rowA$drop_reason),
    "estimated predA has NA drop_reason (drop_reason only set on failures)"
  )

  # Case 8 (post-verify H1 fix): missing-column defensive guard.
  # Pass a name that isn't in model_data — helper must emit a not_estimable
  # row with drop_reason == "missing_column" instead of crashing the loop with
  # base R's cryptic "undefined columns selected".
  res_missing <- tryCatch(
    fit_univariate_poisson(fixture, c("predA", "no_such_col")),
    error = function(e) structure(list(), class = "fup_error",
                                  msg = conditionMessage(e))
  )
  assert(
    !inherits(res_missing, "fup_error"),
    sprintf("missing-column predictor doesn't crash the helper (%s)",
            if (inherits(res_missing, "fup_error")) attr(res_missing, "msg") else "ok")
  )
  if (!inherits(res_missing, "fup_error")) {
    row_missing <- res_missing[res_missing$predictor == "no_such_col", , drop = FALSE]
    assert(
      nrow(row_missing) == 1L &&
        identical(row_missing$estimation_status, "not_estimable") &&
        identical(row_missing$drop_reason, "missing_column") &&
        identical(as.integer(row_missing$n_obs), 0L),
      sprintf("missing-column predictor -> not_estimable + drop_reason='missing_column' + n_obs=0 (got status=%s reason=%s n_obs=%s)",
              if (nrow(row_missing) == 1L) row_missing$estimation_status else "MISSING",
              if (nrow(row_missing) == 1L) as.character(row_missing$drop_reason) else "MISSING",
              if (nrow(row_missing) == 1L) as.character(row_missing$n_obs) else "MISSING")
    )
    # And the OTHER predictor (predA) still fits successfully — guard doesn't
    # taint sibling predictors in the same call.
    rowA_in_mixed <- res_missing[res_missing$predictor == "predA", , drop = FALSE]
    assert(
      nrow(rowA_in_mixed) == 1L && identical(rowA_in_mixed$estimation_status, "estimated"),
      "missing-column guard preserves sibling predictors (predA still estimated)"
    )
  }
}

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
