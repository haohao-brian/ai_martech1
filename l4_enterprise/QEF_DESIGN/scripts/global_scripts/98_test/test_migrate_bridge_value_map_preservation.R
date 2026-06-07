#!/usr/bin/env Rscript
# test_migrate_bridge_value_map_preservation.R
#
# Round-trip test for fix-glue-layer-infra-blockers (#630):
# Verify migrate_bridge_to_field_extractors.R preserves value_map +
# extension fields when translating legacy column_mapping -> v2
# field_extractors shape.

suppressPackageStartupMessages({
  library(testthat)
  library(yaml)
})

PR <- "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise"
GS <- file.path(PR, "shared", "global_scripts")
MIG_TOOL <- file.path(GS, "01_db", "raw_schema", "_authoring",
                     "migrate_bridge_to_field_extractors.R")

# Helper: write legacy yaml fixture + run migration tool + parse v2 output
migrate_fixture <- function(legacy_yaml_str) {
  tmp_legacy <- tempfile(fileext = ".bridge.yaml")
  writeLines(legacy_yaml_str, tmp_legacy)
  expected_v2 <- sub("\\.bridge\\.yaml$", ".bridge.v2.yaml", tmp_legacy)

  result <- system2("Rscript", c(MIG_TOOL, tmp_legacy),
                    stdout = TRUE, stderr = TRUE)
  if (!file.exists(expected_v2)) {
    cat("Migration output not found. Tool stdout/stderr:\n")
    cat(paste(result, collapse = "\n"), "\n")
    stop("v2 yaml not produced at: ", expected_v2)
  }
  v2_doc <- yaml::read_yaml(expected_v2)

  # Cleanup
  unlink(c(tmp_legacy, expected_v2))
  list(v2 = v2_doc, output = result)
}

# Fixture base (canonical_target + minimal review metadata required by tool)
fixture_base <- function(column_mapping_body) {
  paste(
    "canonical_target:",
    "  datatype: test_dt",
    "  platform: amz",
    "  table: df_amz_test_dt___raw",
    "prerawdata_source:",
    "  company: TESTCO",
    "  platform: amz",
    "  source_type: csv",
    "  source_uri: /tmp/test.csv",
    "  schema_fingerprint:",
    "    algorithm: sha256",
    "    value: deadbeef",
    "    fingerprinted_against: test.csv",
    "    fingerprinted_at: '2026-05-12T00:00:00Z'",
    "reviewed_by: 'che (kiki830621)'",
    "column_mapping:",
    column_mapping_body,
    sep = "\n"
  )
}

# === Case 1: column extractor WITH value_map ===
test_that("migration preserves value_map for column extractor", {
  legacy <- fixture_base(paste(
    "  fulfillment_channel:",
    "    from_column: 'fulfillment-channel'",
    "    coercion: 'as.character + toupper'",
    "    value_map:",
    "      AMAZON: AFN",
    "      MERCHANT: MFN",
    sep = "\n"
  ))
  r <- migrate_fixture(legacy)
  fe <- r$v2$field_extractors$fulfillment_channel
  expect_equal(fe$type, "column")
  expect_equal(fe$name, "fulfillment-channel")
  expect_equal(fe$coercion, "as.character + toupper")
  expect_false(is.null(fe$value_map))
  expect_equal(fe$value_map$AMAZON, "AFN")
  expect_equal(fe$value_map$MERCHANT, "MFN")
})

# === Case 2: column extractor WITHOUT value_map ===
test_that("migration produces v2 without value_map when legacy lacks it", {
  legacy <- fixture_base(paste(
    "  order_id:",
    "    from_column: 'amazon-order-id'",
    "    coercion: 'as.character + trimws'",
    sep = "\n"
  ))
  r <- migrate_fixture(legacy)
  fe <- r$v2$field_extractors$order_id
  expect_equal(fe$type, "column")
  expect_equal(fe$name, "amazon-order-id")
  expect_equal(fe$coercion, "as.character + trimws")
  expect_null(fe$value_map)
})

# === Case 3: const extractor (use_value) preserved ===
test_that("migration translates use_value to type=const + value", {
  legacy <- fixture_base(paste(
    "  marketplace_id:",
    "    use_value: ATVPDKIKX0DER",
    sep = "\n"
  ))
  r <- migrate_fixture(legacy)
  fe <- r$v2$field_extractors$marketplace_id
  expect_equal(fe$type, "const")
  expect_equal(fe$value, "ATVPDKIKX0DER")
})

# === Case 4: unknown extension field emits WARNING + drops field ===
test_that("migration warns on unknown extension fields", {
  legacy <- fixture_base(paste(
    "  order_id:",
    "    from_column: 'amazon-order-id'",
    "    experimental_quack: true",
    "    value_map:",
    "      A: B",
    sep = "\n"
  ))
  r <- migrate_fixture(legacy)
  fe <- r$v2$field_extractors$order_id

  # value_map preserved (in whitelist)
  expect_false(is.null(fe$value_map))
  expect_equal(fe$value_map$A, "B")

  # experimental_quack NOT preserved (not in whitelist)
  expect_null(fe$experimental_quack)

  # Migration output mentioned the unknown field
  warning_emitted <- any(grepl("experimental_quack", r$output, fixed = TRUE))
  expect_true(warning_emitted,
              info = paste("expected output to mention 'experimental_quack', got:\n",
                          paste(r$output, collapse = "\n")))
})

cat("\n=== Test summary ===\n")
cat("All 4 cases passed if no error above.\n")
