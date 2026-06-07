#!/usr/bin/env Rscript
# test_coerce_field_pipeline.R
#
# Tests for fix-glue-layer-infra-blockers (#631):
# Verify apply_coercion_pipeline() and coerce_field() integration
# execute bridge yaml coercion strings as ordered whitelist pipelines.

suppressPackageStartupMessages({
  library(testthat)
})

PR <- "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise"
source(file.path(PR, "shared", "global_scripts", "05_etl_utils", "glue", "fn_apply_mapping.R"))

# === Case 1: identity (no coercion directive) ===
test_that("coerce_field with no coercion directive applies only canonical type coercion", {
  result <- coerce_field("  hello  ", list(type = "VARCHAR"), NULL)
  expect_equal(result, "hello")  # only trimws from canonical VARCHAR

  result2 <- coerce_field("  hello  ", list(type = "VARCHAR"), list())
  expect_equal(result2, "hello")

  result3 <- coerce_field("  hello  ", list(type = "VARCHAR"),
                         list(coercion = ""))
  expect_equal(result3, "hello")  # empty string also no-op
})

# === Case 2: single op (toupper) ===
test_that("apply_coercion_pipeline applies single op", {
  expect_equal(apply_coercion_pipeline("hello", "toupper"), "HELLO")
  expect_equal(apply_coercion_pipeline("HELLO", "tolower"), "hello")
  expect_equal(apply_coercion_pipeline("  hello  ", "trimws"), "hello")
})

# === Case 3: pipeline (ordered application) ===
test_that("apply_coercion_pipeline applies ops in declared order", {
  # Per spec Example: "  Amazon  " through "as.character + trimws + toupper"
  # → "AMAZON"
  result <- apply_coercion_pipeline("  Amazon  ",
                                    "as.character + trimws + toupper")
  expect_equal(result, "AMAZON")

  # Different order produces different intermediate state but same final
  # for this whitelist (toupper after trim is idempotent)
  result2 <- apply_coercion_pipeline("  Amazon  ",
                                     "trimws + as.character + toupper")
  expect_equal(result2, "AMAZON")
})

# === Case 4: unsupported op (format_date) — warning + skip + continue ===
test_that("apply_coercion_pipeline warns on unsupported op and skips", {
  # Pipeline: as.character runs, format_date skipped with warning, toupper runs
  expect_warning(
    result <- apply_coercion_pipeline("hello",
                                       "as.character + format_date + toupper"),
    regexp = "Unsupported coercion op 'format_date'"
  )
  expect_equal(result, "HELLO")
})

# === Case 5 (bonus): coerce_field integration with bridge yaml-style spec ===
test_that("coerce_field integrates pipeline AFTER canonical type coercion", {
  # amz_fulfillment_channel: VARCHAR + "as.character + toupper"
  # source "Amazon" → canonical trimws → "Amazon" → toupper → "AMAZON"
  result <- coerce_field(
    raw = "Amazon",
    spec = list(type = "VARCHAR"),
    mapping_entry = list(coercion = "as.character + toupper")
  )
  expect_equal(result, "AMAZON")
})

# === Case 6 (bonus): suppressWarnings on numeric coercion of non-numeric ===
test_that("as.numeric on non-numeric produces NA without raw warning leak", {
  # Should warn from the pipeline framework? No — as.numeric is in whitelist.
  # suppressWarnings is inside switch — outer caller should NOT see NA warning.
  # But coercion produces NA which is expected behavior.
  result <- expect_silent(
    apply_coercion_pipeline("not_a_number", "as.numeric")
  )
  expect_true(is.na(result))
})

cat("\n=== Test summary ===\n")
cat("All 6 test_that() blocks passed if no error above.\n")
