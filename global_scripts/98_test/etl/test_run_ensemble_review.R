# Tests for run_ensemble_review.R orchestration helper (#500 Task 2.1)
#
# Function under test: classify_iteration_outcome(...) — pure verdict logic
# Decides CONVERGED / PLATEAUED / DIMINISHING / INSTABILITY / CONTINUE
# given current iteration's findings + previous iteration's metadata.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_run_ensemble_review.R')"

suppressPackageStartupMessages({
  library(testthat)
})

TEST_DIR <- if (!is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  getwd()
}
HELPER_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "00_principles/.claude/skills/glue-bridge/scripts/run_ensemble_review.R"),
  mustWork = FALSE
)

context("run_ensemble_review verdict classification")

test_that("helper file exists and exports classify_iteration_outcome", {
  expect_true(file.exists(HELPER_PATH),
              info = paste("Expected helper at", HELPER_PATH))
  source(HELPER_PATH, local = TRUE)
  expect_true(exists("classify_iteration_outcome"))
})

test_that("CONVERGED when 0 critical/high and remaining medium have resolutions", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 3,
    findings = list(),  # zero findings
    findings_hash = "abc",
    findings_count = 0,
    prev_findings_hash = "def",
    prev_findings_count = 5,
    has_resolutions = TRUE
  )
  expect_equal(outcome$verdict, "CONVERGED")
})

test_that("CONVERGED with remaining MEDIUM/LOW that have resolutions", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 4,
    findings = list(
      list(severity = "MEDIUM", rule_id = "X", summary = "minor issue accepted")
    ),
    findings_hash = "stable",
    findings_count = 1,
    prev_findings_hash = "different",
    prev_findings_count = 3,
    has_resolutions = TRUE
  )
  expect_equal(outcome$verdict, "CONVERGED")
})

test_that("CONTINUE when CRITICAL still present even if same hash twice", {
  source(HELPER_PATH, local = TRUE)
  # Hash stable BUT findings have CRITICAL — PLATEAUED takes precedence over CONTINUE
  outcome <- classify_iteration_outcome(
    iteration_n = 2,
    findings = list(
      list(severity = "CRITICAL", rule_id = "MP160", summary = "missing column")
    ),
    findings_hash = "same_hash",
    findings_count = 1,
    prev_findings_hash = "same_hash",
    prev_findings_count = 1,
    has_resolutions = FALSE
  )
  expect_equal(outcome$verdict, "PLATEAUED")
})

test_that("INSTABILITY when findings count grows iteration over iteration", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 3,
    findings = list(
      list(severity = "CRITICAL", rule_id = "X", summary = "a"),
      list(severity = "CRITICAL", rule_id = "Y", summary = "b"),
      list(severity = "HIGH", rule_id = "Z", summary = "c")
    ),
    findings_hash = "h3",
    findings_count = 3,
    prev_findings_hash = "h2",
    prev_findings_count = 2,
    has_resolutions = FALSE
  )
  expect_equal(outcome$verdict, "INSTABILITY")
})

test_that("CONTINUE when progress is being made (count decreasing, hash differs)", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 2,
    findings = list(
      list(severity = "CRITICAL", rule_id = "MP160", summary = "still bad")
    ),
    findings_hash = "h2",
    findings_count = 1,
    prev_findings_hash = "h1",
    prev_findings_count = 5,
    has_resolutions = FALSE
  )
  expect_equal(outcome$verdict, "CONTINUE")
})

test_that("DIMINISHING when only SUGGESTIONs added compared to previous", {
  source(HELPER_PATH, local = TRUE)
  # Previous iteration was CONVERGED-eligible (0 critical/high); new iteration
  # only adds SUGGESTION-level findings.
  outcome <- classify_iteration_outcome(
    iteration_n = 5,
    findings = list(
      list(severity = "SUGGESTION", rule_id = "X", summary = "minor polish")
    ),
    findings_hash = "h5",
    findings_count = 1,
    prev_findings_hash = "h4",
    prev_findings_count = 0,
    prev_max_severity = "NONE",  # previous iteration had nothing higher than NONE
    has_resolutions = TRUE
  )
  expect_equal(outcome$verdict, "DIMINISHING")
})

test_that("iteration 1 (no prev_findings_hash) returns CONTINUE on findings present", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 1,
    findings = list(
      list(severity = "CRITICAL", rule_id = "X", summary = "first iter issue")
    ),
    findings_hash = "h1",
    findings_count = 1,
    prev_findings_hash = NULL,
    prev_findings_count = NULL,
    has_resolutions = FALSE
  )
  expect_equal(outcome$verdict, "CONTINUE")
})

test_that("iteration 1 (no prev) returns CONVERGED on zero findings", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 1,
    findings = list(),
    findings_hash = "empty_hash",
    findings_count = 0,
    prev_findings_hash = NULL,
    prev_findings_count = NULL,
    has_resolutions = TRUE
  )
  expect_equal(outcome$verdict, "CONVERGED")
})

test_that("CONTINUE blocked by missing resolutions even with 0 critical/high", {
  source(HELPER_PATH, local = TRUE)
  outcome <- classify_iteration_outcome(
    iteration_n = 4,
    findings = list(
      list(severity = "MEDIUM", rule_id = "X", summary = "needs decision")
    ),
    findings_hash = "h4",
    findings_count = 1,
    prev_findings_hash = "h3",
    prev_findings_count = 3,
    has_resolutions = FALSE  # no findings_resolutions block in bridge yaml
  )
  # has_resolutions = FALSE for MEDIUM/LOW means user hasn't accepted them yet
  # → not CONVERGED yet; need codegen to fix or user to accept
  expect_equal(outcome$verdict, "CONTINUE")
})
