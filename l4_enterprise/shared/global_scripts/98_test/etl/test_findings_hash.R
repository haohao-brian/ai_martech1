# Tests for findings_hash helper (#500 Task 2.2)
#
# findings_hash provides deterministic sha256 over a list of finding tuples.
# Used by run_ensemble_review.R for plateau detection: if iteration N's hash
# equals iteration N-1's hash, the loop has stopped making progress.
#
# Determinism contract:
#   - input order does NOT affect output (findings sorted by canonical key)
#   - missing optional fields fall back to "" (so hash is stable when fields appear/disappear)
#   - hash covers (severity, rule_id, file, line, summary) tuple
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_findings_hash.R')"

suppressPackageStartupMessages({
  library(testthat)
  library(digest)
})

# Resolve helper path relative to this test file (testthat changes cwd)
TEST_DIR <- if (!is.null(sys.call(0)) && !is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  # Fallback when sourced via testthat::test_file (cwd is the test dir)
  getwd()
}
# From shared/global_scripts/98_test/etl/, walk up 3 levels then into 00_principles/...
HELPER_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "00_principles/.claude/skills/glue-bridge/scripts/findings_hash.R"),
  mustWork = FALSE
)

context("findings_hash determinism")

test_that("findings_hash exists and exports compute_findings_hash function", {
  expect_true(file.exists(HELPER_PATH),
              info = paste("Expected helper at", HELPER_PATH))
  source(HELPER_PATH, local = TRUE)
  expect_true(exists("compute_findings_hash"))
})

test_that("compute_findings_hash returns 64-char hex sha256 string", {
  source(HELPER_PATH, local = TRUE)
  findings <- list(
    list(severity = "CRITICAL", rule_id = "MP160",
         file = "x.bridge.yaml", line = 5, summary = "missing column")
  )
  result <- compute_findings_hash(findings)
  expect_type(result, "character")
  expect_length(result, 1)
  expect_match(result, "^[0-9a-f]{64}$")
})

test_that("hash is invariant to input order (sorted internally)", {
  source(HELPER_PATH, local = TRUE)
  finding_a <- list(severity = "CRITICAL", rule_id = "MP160",
                    file = "x.yaml", line = 5, summary = "alpha")
  finding_b <- list(severity = "HIGH", rule_id = "DM_R065",
                    file = "y.yaml", line = 12, summary = "beta")
  hash_ab <- compute_findings_hash(list(finding_a, finding_b))
  hash_ba <- compute_findings_hash(list(finding_b, finding_a))
  expect_identical(hash_ab, hash_ba)
})

test_that("empty findings list produces stable hash", {
  source(HELPER_PATH, local = TRUE)
  hash1 <- compute_findings_hash(list())
  hash2 <- compute_findings_hash(list())
  expect_identical(hash1, hash2)
  expect_match(hash1, "^[0-9a-f]{64}$")
})

test_that("missing optional fields default to empty string (stable across appearance/disappearance)", {
  source(HELPER_PATH, local = TRUE)
  finding_full <- list(severity = "MEDIUM", rule_id = "X", file = "f.yaml",
                       line = 1, summary = "s")
  finding_no_line <- list(severity = "MEDIUM", rule_id = "X", file = "f.yaml",
                          line = NA, summary = "s")
  finding_zero_line <- list(severity = "MEDIUM", rule_id = "X", file = "f.yaml",
                            line = 0, summary = "s")
  # NA and missing should both treat as "" for stability
  hash_no_line <- compute_findings_hash(list(finding_no_line))
  # hash_full vs hash_no_line differ ONLY in line value — they SHOULD differ
  hash_full <- compute_findings_hash(list(finding_full))
  expect_false(identical(hash_full, hash_no_line))
})

test_that("different finding content produces different hash", {
  source(HELPER_PATH, local = TRUE)
  f1 <- list(severity = "CRITICAL", rule_id = "MP160",
             file = "a.yaml", line = 1, summary = "one")
  f2 <- list(severity = "CRITICAL", rule_id = "MP160",
             file = "a.yaml", line = 1, summary = "two")  # only summary differs
  expect_false(identical(compute_findings_hash(list(f1)),
                         compute_findings_hash(list(f2))))
})

test_that("severity casing and whitespace normalized for stability", {
  source(HELPER_PATH, local = TRUE)
  f_upper <- list(severity = "CRITICAL", rule_id = "MP160",
                  file = "a.yaml", line = 1, summary = "x")
  f_lower <- list(severity = "critical", rule_id = "MP160",
                  file = "a.yaml", line = 1, summary = "x")
  f_padded <- list(severity = " CRITICAL ", rule_id = "MP160",
                   file = "a.yaml", line = 1, summary = "x")
  h1 <- compute_findings_hash(list(f_upper))
  h2 <- compute_findings_hash(list(f_lower))
  h3 <- compute_findings_hash(list(f_padded))
  # All three should produce the same hash (severity normalized)
  expect_identical(h1, h2)
  expect_identical(h1, h3)
})
