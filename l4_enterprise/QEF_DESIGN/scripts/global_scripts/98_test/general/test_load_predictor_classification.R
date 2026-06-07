#!/usr/bin/env Rscript

# Test: load_predictor_classification() canonical reader for df_predictor_classification
#
# Spec coverage:
#   - predictor-type-metadata-table > "predictor classification table SHALL be
#     read via a single canonical reader function"
#   - predictor-type-metadata-table > "predictor classification metadata SHALL
#     live in meta_data.duckdb"
#
# TDD: This test is written BEFORE fn_load_predictor_classification.R exists.
# Initial run should FAIL (RED) because the source path does not exist yet.
# After implementation, all expectations SHALL pass (GREEN).
#
# Refs #716 (metadata-driven-predictor-type-classification change)

suppressPackageStartupMessages({
  library(testthat)
  library(DBI)
  library(duckdb)
})

# ---------------------------------------------------------------------------
# Locate paths
# ---------------------------------------------------------------------------

get_script_path <- function() {
  cargs <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cargs, value = TRUE)
  if (length(file_arg) > 0) return(sub("^--file=", "", file_arg[1]))
  if (!is.null(sys.frames()[[1]]$ofile)) return(sys.frames()[[1]]$ofile)
  NA_character_
}

this_file <- tryCatch(
  normalizePath(get_script_path(), mustWork = FALSE),
  error = function(e) NA_character_
)

if (!is.na(this_file) && file.exists(this_file)) {
  utils_dir <- normalizePath(
    file.path(dirname(this_file), "..", "..", "04_utils"),
    mustWork = FALSE
  )
  schema_dir <- normalizePath(
    file.path(dirname(this_file), "..", "..", "01_db", "raw_schema",
              "_authoring", "r_definitions"),
    mustWork = FALSE
  )
} else {
  utils_dir <- "shared/global_scripts/04_utils"
  schema_dir <- "shared/global_scripts/01_db/raw_schema/_authoring/r_definitions"
}

reader_path <- file.path(utils_dir, "fn_load_predictor_classification.R")
schema_path <- file.path(schema_dir, "SCHEMA_006_predictor_classification.R")

# Source schema first (provides fn_initialize_predictor_classification + spec)
stopifnot(file.exists(schema_path))
source(schema_path)

# Reader may not exist yet (RED phase). Skip remaining tests with explanatory
# message when it is absent so the RED state is visible without crashing the
# test runner with "file not found".
if (!file.exists(reader_path)) {
  cat("\n[RED] Reader fn_load_predictor_classification.R does not exist yet.\n")
  cat("       Expected path: ", reader_path, "\n", sep = "")
  cat("       Run again after implementation to see GREEN.\n")
  quit(status = 1)
}

source(reader_path)

# ---------------------------------------------------------------------------
# Test fixtures: in-memory meta_data.duckdb with the canonical schema
# ---------------------------------------------------------------------------

# Build a fresh in-memory DB with the table for each test_that block
make_fixture <- function() {
  con <- dbConnect(duckdb::duckdb(), ":memory:")
  fn_initialize_predictor_classification(con, db_type = "duckdb")

  # Seed a small predictable row set
  dbExecute(con, "
    INSERT INTO df_predictor_classification (platform, column_name, predictor_type, source, added_at) VALUES
      ('amz', 'review_count',     'comment_attribute', 'review_agg',                CURRENT_TIMESTAMP),
      ('amz', '偏光功能',         'comment_attribute', 'review_agg',                CURRENT_TIMESTAMP),
      ('amz', '鏡框寬度',         'product_attribute', 'product_attributes_gsheet', CURRENT_TIMESTAMP),
      ('amz', 'month_1',          'time_feature',      'time_features',             CURRENT_TIMESTAMP),
      ('cbz', '偏光功能',         'product_attribute', 'product_attributes_gsheet', CURRENT_TIMESTAMP)
  ")

  con
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_that("load_predictor_classification hits known (platform, column_name)", {
  con <- make_fixture()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  result <- load_predictor_classification("amz", "偏光功能", con = con)

  expect_type(result, "list")
  expect_equal(result$predictor_type, "comment_attribute")
  expect_equal(result$source, "review_agg")
})

test_that("load_predictor_classification returns NULL on miss", {
  con <- make_fixture()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  result <- load_predictor_classification("amz", "no_such_column", con = con)
  expect_null(result)
})

test_that("load_predictor_classification distinguishes same column across platforms", {
  # '偏光功能' is comment_attribute for amz (review_agg) and product_attribute
  # for cbz (product_attributes_gsheet) per fixture
  con <- make_fixture()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  amz_result <- load_predictor_classification("amz", "偏光功能", con = con)
  cbz_result <- load_predictor_classification("cbz", "偏光功能", con = con)

  expect_equal(amz_result$predictor_type, "comment_attribute")
  expect_equal(cbz_result$predictor_type, "product_attribute")
  expect_equal(amz_result$source, "review_agg")
  expect_equal(cbz_result$source, "product_attributes_gsheet")
})

test_that("load_predictor_classification raises actionable error on NULL connection", {
  expect_error(
    load_predictor_classification("amz", "偏光功能", con = NULL),
    regexp = "connection|con|NULL"
  )
})

test_that("load_predictor_classification raises on missing platform / column_name args", {
  con <- make_fixture()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_error(load_predictor_classification(NULL, "偏光功能", con = con))
  expect_error(load_predictor_classification("amz", NULL, con = con))
})

cat("\n[#716] All load_predictor_classification tests PASSED.\n")
