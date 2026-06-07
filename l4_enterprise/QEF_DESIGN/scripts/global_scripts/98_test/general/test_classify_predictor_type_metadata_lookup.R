#!/usr/bin/env Rscript

# Test: classify_predictor_type() metadata-driven dispatch
#
# Spec coverage:
#   - predictor-type-classifier-lookup > "classify_predictor_type SHALL accept
#     a platform parameter"
#   - predictor-type-classifier-lookup > "classify_predictor_type SHALL dispatch
#     through fast-path, metadata lookup, then keyword fallback"
#   - predictor-type-classifier-lookup > "classify_predictor_type SHALL be a
#     pure function"
#   - drv-platform-agnosticism > "Platform-agnostic DRV helpers SHALL accept
#     platform as a function parameter"
#
# TDD: This test is written BEFORE the refactored classify_predictor_type
# function exists with metadata lookup support. Initial run should FAIL (RED)
# because the new 3-arg signature does not exist yet.
#
# Refs #716

suppressPackageStartupMessages({
  library(testthat)
})

# ---------------------------------------------------------------------------
# Locate fn_classify_predictor_type.R (extracted helper, sourced by D04_02.R)
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
} else {
  utils_dir <- "shared/global_scripts/04_utils"
}

classifier_path <- file.path(utils_dir, "fn_classify_predictor_type.R")

if (!file.exists(classifier_path)) {
  cat("\n[RED] fn_classify_predictor_type.R does not exist yet.\n")
  cat("       Expected path: ", classifier_path, "\n", sep = "")
  cat("       Run again after implementation to see GREEN.\n")
  quit(status = 1)
}

source(classifier_path)

if (!is.function(classify_predictor_type)) {
  cat("\n[RED] classify_predictor_type not exported by fn_classify_predictor_type.R\n")
  quit(status = 1)
}

fn_formals <- names(formals(classify_predictor_type))
if (!"platform" %in% fn_formals) {
  cat("\n[RED] classify_predictor_type does not accept `platform` parameter.\n")
  cat("       Formal args found: ", paste(fn_formals, collapse = ", "), "\n", sep = "")
  quit(status = 1)
}
if (!"predictor_meta_lookup" %in% fn_formals) {
  cat("\n[RED] classify_predictor_type does not accept `predictor_meta_lookup` parameter.\n")
  cat("       Formal args found: ", paste(fn_formals, collapse = ", "), "\n", sep = "")
  quit(status = 1)
}

# ---------------------------------------------------------------------------
# Fixtures: in-memory predictor_meta_lookup function
# ---------------------------------------------------------------------------

# Mock lookup that returns metadata for specific (platform, column) pairs
make_lookup <- function(rows) {
  function(platform, column_name) {
    hit <- rows[rows$platform == platform & rows$column_name == column_name, ]
    if (nrow(hit) == 0L) return(NULL)
    list(predictor_type = hit$predictor_type[1L],
         source = hit$source[1L])
  }
}

mock_meta <- data.frame(
  platform = c("amz", "amz", "amz", "cbz"),
  column_name = c("偏光功能", "鏡框寬度", "review_count", "偏光功能"),
  predictor_type = c("comment_attribute", "product_attribute",
                     "comment_attribute", "product_attribute"),
  source = c("review_agg", "product_attributes_gsheet", "review_agg",
             "product_attributes_gsheet"),
  stringsAsFactors = FALSE
)
mock_lookup <- make_lookup(mock_meta)

empty_lookup <- function(platform, column_name) NULL

# ---------------------------------------------------------------------------
# Tests — Stage 1 (time fast-path)
# ---------------------------------------------------------------------------

test_that("Stage 1 time fast-path hits for month_N / weekday / quarter / year", {
  expect_equal(classify_predictor_type("month_1", "amz", mock_lookup),
               "time_feature")
  expect_equal(classify_predictor_type("monday", "amz", mock_lookup),
               "time_feature")
  expect_equal(classify_predictor_type("quarter", "amz", mock_lookup),
               "time_feature")
  expect_equal(classify_predictor_type("is_weekend", "amz", mock_lookup),
               "time_feature")
})

# ---------------------------------------------------------------------------
# Tests — Stage 2 (structural fast-path)
# ---------------------------------------------------------------------------

test_that("Stage 2 structural fast-path hits for *_id / *_name / sku / asin (exact)", {
  # Note: Stage 2 regex requires `^asin$` exact match — `amz_asin` does NOT
  # match by regex alone. Source-driven metadata classifies `amz_asin` as
  # structural via source='sales_meta' (see "metadata-overrides-default-for-
  # amz_asin" test below). This Stage 2 test covers terms that the regex
  # DOES match directly.
  expect_equal(classify_predictor_type("asin", "amz", mock_lookup),
               "structural")
  expect_equal(classify_predictor_type("product_name", "amz", mock_lookup),
               "structural")
  expect_equal(classify_predictor_type("customer_id", "amz", mock_lookup),
               "structural")
  expect_equal(classify_predictor_type("sku", "amz", mock_lookup),
               "structural")
})

test_that("Metadata-driven path covers amz_asin (regex misses, metadata wins)", {
  # `amz_asin` does not match Stage 2 regex (`^asin$` is anchored).
  # Production data shows `amz_asin` rows with predictor_type=product_attribute
  # in legacy classifier output. Under metadata-driven dispatch, ETL emit with
  # source='sales_meta' classifies it correctly as `structural`.
  amz_asin_lookup <- make_lookup(data.frame(
    platform = "amz",
    column_name = "amz_asin",
    predictor_type = "structural",
    source = "sales_meta",
    stringsAsFactors = FALSE
  ))
  expect_equal(classify_predictor_type("amz_asin", "amz", amz_asin_lookup),
               "structural")
  # Without metadata, falls through to default (regex miss; not a stage-2 win)
  expect_equal(classify_predictor_type("amz_asin", "amz", empty_lookup),
               "product_attribute")
})

# ---------------------------------------------------------------------------
# Tests — Stage 3 (metadata lookup) — the new behavior
# ---------------------------------------------------------------------------

test_that("Stage 3 metadata lookup hits Chinese review-decoded sentiment", {
  # The bug fix: 偏光功能 used to fall through to product_attribute default;
  # with metadata-driven lookup it now correctly returns comment_attribute
  expect_equal(classify_predictor_type("偏光功能", "amz", mock_lookup),
               "comment_attribute")
})

test_that("Stage 3 distinguishes same column name across platforms", {
  # Critical: 偏光功能 is comment_attribute for amz, product_attribute for cbz
  expect_equal(classify_predictor_type("偏光功能", "amz", mock_lookup),
               "comment_attribute")
  expect_equal(classify_predictor_type("偏光功能", "cbz", mock_lookup),
               "product_attribute")
})

test_that("Stage 3 metadata overrides English keyword for same column", {
  # review_count matches stage 4 English keyword `review`, BUT metadata
  # explicitly classifies it as comment_attribute (review_agg source) —
  # stage 3 wins because dispatch is ordered
  expect_equal(classify_predictor_type("review_count", "amz", mock_lookup),
               "comment_attribute")
})

# ---------------------------------------------------------------------------
# Tests — Stage 4 (keyword fallback) — backward compat
# ---------------------------------------------------------------------------

test_that("Stage 4 English keyword fallback fires when metadata misses", {
  # No metadata for customer_rating;keyword `rating` matches → comment_attribute
  expect_equal(classify_predictor_type("customer_rating", "amz", empty_lookup),
               "comment_attribute")
  expect_equal(classify_predictor_type("sentiment_score", "amz", empty_lookup),
               "comment_attribute")
})

# ---------------------------------------------------------------------------
# Tests — Stage 5 (default product_attribute)
# ---------------------------------------------------------------------------

test_that("Stage 5 default returns product_attribute when no other stage hits", {
  # No metadata, no fast-path, no keyword
  expect_equal(classify_predictor_type("unknown_column", "amz", empty_lookup),
               "product_attribute")
  # Chinese column without metadata — falls all the way through to default
  # (this is the documented "Risks" behavior — Chinese names need real
  # metadata to be classified comment_attribute)
  expect_equal(classify_predictor_type("某個未知欄位", "amz", empty_lookup),
               "product_attribute")
})

# ---------------------------------------------------------------------------
# Tests — predictor_meta_lookup default behavior
# ---------------------------------------------------------------------------

test_that("predictor_meta_lookup defaults to NULL (no metadata)", {
  # Calling without explicit lookup — should behave as empty metadata
  # (falls through to keyword + default)
  expect_equal(classify_predictor_type("customer_rating", "amz"),
               "comment_attribute")  # keyword fallback fires
  expect_equal(classify_predictor_type("unknown_col", "amz"),
               "product_attribute")  # default fires
})

# ---------------------------------------------------------------------------
# Tests — Platform parameter required
# ---------------------------------------------------------------------------

test_that("Missing platform raises actionable error", {
  # Save & clear env var; should fall through to error
  old <- Sys.getenv("DRV_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old)
  })
  Sys.unsetenv("DRV_PLATFORM")
  expect_error(classify_predictor_type("某個欄位", ""),
               regexp = "platform|DRV_PLATFORM")
})

# ---------------------------------------------------------------------------
# Tests — Pure function (idempotent, no side effects)
# ---------------------------------------------------------------------------

test_that("classify_predictor_type is pure (same input -> same output)", {
  r1 <- classify_predictor_type("偏光功能", "amz", mock_lookup)
  r2 <- classify_predictor_type("偏光功能", "amz", mock_lookup)
  expect_equal(r1, r2)
})

cat("\n[#716] All classify_predictor_type metadata lookup tests PASSED.\n")
