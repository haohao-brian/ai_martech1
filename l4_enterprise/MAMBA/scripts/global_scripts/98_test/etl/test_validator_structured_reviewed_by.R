# Tests for validate_bridge_yaml.R structured reviewed_by support (#500 Tasks 3.1-3.3)
#
# Strategy: write minimal but valid bridge yaml fixtures + sibling review log
# files into a tempdir, run the validator script, parse stdout for severity tally.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_validator_structured_reviewed_by.R')"

suppressPackageStartupMessages({
  library(testthat)
  library(yaml)
})

TEST_DIR <- if (!is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  getwd()
}
VALIDATOR_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "00_principles/.claude/skills/glue-bridge/scripts/validate_bridge_yaml.R"),
  mustWork = TRUE
)

# Helper: build a minimally valid bridge yaml structure for testing
.build_minimal_bridge <- function(reviewed_by_value, ...) {
  list(
    prerawdata_source = list(
      company = "TESTCO",
      platform = "amz",
      source_type = "csv",
      source_uri = "test.csv",
      schema_fingerprint = list(
        algorithm = "sha256",
        value = strrep("a", 64),
        fingerprinted_against = "test.csv (full read, 5 rows)",
        fingerprinted_at = "2026-04-29T00:00:00Z"
      )
    ),
    canonical_target = list(
      datatype = "sales",
      platform = "amz",
      table = "df_amz_sales___raw",
      schema_yaml_path = "01_db/raw_schema/_authoring/core_schemas.yaml"
    ),
    column_mapping = list(
      order_id = list(from_column = "order_id"),
      total_amount = list(from_column = "total_amount")
    ),
    ignored_columns = list("etl_meta_phase"),
    generated_at = "2026-04-29T00:00:00Z",
    generated_by = "glue-bridge skill v1.2",
    reviewed_by = reviewed_by_value,
    ...
  )
}

# Helper: write yaml + optional review log; return path
.setup_fixture <- function(reviewed_by_value, review_log_content = NULL,
                            extra_doc = list()) {
  tmp <- file.path(tempdir(), paste0("bridge_test_", as.integer(Sys.time())))
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  bridge_path <- file.path(tmp, "test_source.bridge.yaml")
  doc <- .build_minimal_bridge(reviewed_by_value)
  for (k in names(extra_doc)) {
    doc[[k]] <- extra_doc[[k]]
  }
  yaml::write_yaml(doc, bridge_path)
  if (!is.null(review_log_content)) {
    log_path <- file.path(tmp, "test_source.bridge.review.md")
    writeLines(review_log_content, log_path)
  }
  bridge_path
}

# Helper: run validator, capture stdout + exit code
.run_validator <- function(bridge_path) {
  result <- system2("Rscript", args = c(VALIDATOR_PATH, bridge_path),
                    stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status") %||% 0L
  list(
    output = paste(result, collapse = "\n"),
    status = as.integer(status),
    n_critical = as.integer(sub(".*CRITICAL:\\s+(\\d+).*", "\\1",
                                 paste(result, collapse = " "))),
    n_warn = as.integer(sub(".*WARNING:\\s+(\\d+).*", "\\1",
                              paste(result, collapse = " ")))
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

context("validator: structured reviewed_by")

test_that("structured form with 0 critical/0 high + valid review log PASSES", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "kiki830621",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex-cli@0.124", "claude-correctness"),
      findings_summary = list(critical = 0L, high = 0L,
                              medium = 0L, low = 0L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "test_source.bridge.review.md"
    ),
    review_log_content = c(
      "# Test review log",
      "## Iteration 1 - 2026-04-29T00:00:00Z",
      "**Findings**: 0 (0 CRITICAL / 0 HIGH / 0 MEDIUM)",
      "## Verdict: CONVERGED at iteration 1"
    )
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 0L,
               info = paste("Validator output:", result$output))
  expect_equal(result$n_critical, 0L)
})

test_that("structured form with critical > 0 FAILS", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "kiki830621",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex-cli@0.124"),
      findings_summary = list(critical = 2L, high = 0L,
                              medium = 0L, low = 0L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "test_source.bridge.review.md"
    ),
    review_log_content = c("## Verdict: CONVERGED at iteration 1")
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("findings_summary.critical = 2", result$output))
})

test_that("structured form with high > 0 FAILS", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "x",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex"),
      findings_summary = list(critical = 0L, high = 1L,
                              medium = 0L, low = 0L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "test_source.bridge.review.md"
    ),
    review_log_content = c("## Verdict: CONVERGED at iteration 1")
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("findings_summary.high = 1", result$output))
})

test_that("structured form missing review log FAILS", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "x",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex"),
      findings_summary = list(critical = 0L, high = 0L,
                              medium = 0L, low = 0L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "missing.bridge.review.md"
    )
    # no review log written
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("does not exist", result$output))
})

test_that("structured form with review log lacking Verdict FAILS", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "x",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex"),
      findings_summary = list(critical = 0L, high = 0L,
                              medium = 0L, low = 0L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "test_source.bridge.review.md"
    ),
    review_log_content = c(
      "# Some log",
      "## Iteration 1 - x",
      "(but no Verdict line)"
    )
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("lacks `## Verdict:", result$output))
})

test_that("structured form missing required fields FAILS", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "x"
      # missing review_mode, ai_reviewers, findings_summary, approved_at, review_artifacts
    )
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("missing required fields", result$output))
})

test_that("findings_resolutions required when medium + low > 0", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = list(
      human_reviewer = "x",
      review_mode = "glue-ensemble-v1",
      ai_reviewers = list("codex"),
      findings_summary = list(critical = 0L, high = 0L,
                              medium = 2L, low = 1L),
      approved_at = "2026-04-29T01:00:00Z",
      review_artifacts = "test_source.bridge.review.md"
    ),
    review_log_content = c("## Verdict: CONVERGED at iteration 1")
    # no findings_resolutions block in bridge yaml
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("findings_resolutions", result$output))
})

context("validator: legacy string reviewed_by")

test_that("legacy string PASSES with deprecation WARNING", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = "che (kiki830621)"
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 0L,
               info = paste("Validator output:", result$output))
  expect_true(result$n_warn >= 1L)
  expect_true(grepl("legacy string form", result$output))
})

test_that("placeholder string still BLOCKS (REQUIRES_HUMAN_REVIEW)", {
  bridge_path <- .setup_fixture(
    reviewed_by_value = "REQUIRES_HUMAN_REVIEW"
  )
  result <- .run_validator(bridge_path)
  expect_equal(result$status, 1L)
  expect_true(grepl("placeholder", result$output))
})
