#!/usr/bin/env Rscript

# Test: filter_excluded_covariates handles empty data.frame without throwing
# "invalid 'type' (list) of argument" (issue #713)
#
# Root cause being tested:
#   sapply(character(0), should_exclude_covariate, ...) returns list() not
#   logical(0); subsequent `data[!exclude_mask, ]` then evaluates `!list()`
#   which throws "invalid 'type' (list) of argument". This propagates as
#   "Error loading rating analysis data: ..." in poissonCommentAnalysis when
#   a PL has zero rows in df_amz_poisson_analysis_all (e.g. QEF sfg).
#
# Fix: empty-df guard added at top of filter_excluded_covariates returning
#      the empty df verbatim before sapply is called.
#
# Run from repo root:
#   Rscript shared/global_scripts/98_test/general/test_filter_excluded_covariates_empty_df.R
#
# Refs #713

suppressPackageStartupMessages({
  library(testthat)
})

# Locate this file via commandArgs --file=... (Rscript style)
get_script_path <- function() {
  cargs <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cargs, value = TRUE)
  if (length(file_arg) > 0) {
    return(sub("^--file=", "", file_arg[1]))
  }
  if (!is.null(sys.frames()[[1]]$ofile)) return(sys.frames()[[1]]$ofile)
  NA_character_
}

this_file <- tryCatch(normalizePath(get_script_path(), mustWork = FALSE),
                      error = function(e) NA_character_)
if (!is.na(this_file) && file.exists(this_file)) {
  utils_dir <- normalizePath(file.path(dirname(this_file), "..", "..", "04_utils"))
} else {
  candidates <- c(
    "shared/global_scripts/04_utils",
    "scripts/global_scripts/04_utils",
    "04_utils"
  )
  candidates <- candidates[dir.exists(candidates)]
  if (length(candidates) == 0) {
    stop("Cannot locate 04_utils. Run from repo root.")
  }
  utils_dir <- candidates[1]
}

# Source helpers in dependency order. Auto-init's path resolution depends on
# cwd matching specific repo layouts; pass explicit config_path so the test
# is portable across run locations.
source(file.path(utils_dir, "fn_initialize_covariate_exclusion.R"))
source(file.path(utils_dir, "fn_should_exclude_covariate.R"))

config_yaml <- normalizePath(
  file.path(utils_dir, "..", "30_global_data", "parameters", "scd_type2",
            "exclusion_rules.yaml"),
  mustWork = TRUE
)
suppressMessages(initialize_covariate_exclusion(config_path = config_yaml,
                                                 verbose = FALSE))

if (!exists(".covariate_exclusion_config", envir = .GlobalEnv)) {
  stop("Covariate exclusion config init failed even with explicit path: ",
       config_yaml)
}

# ---------------------------------------------------------------------------
# Test 1: empty data.frame must not throw "invalid 'type' (list) of argument"
# ---------------------------------------------------------------------------

test_that("filter_excluded_covariates on empty df returns empty df without error", {
  empty_df <- data.frame(
    predictor = character(0),
    coefficient = double(0),
    p_value = double(0),
    stringsAsFactors = FALSE
  )

  # Capture messages (the guard prints "Filtered 0 of 0 covariates (empty input)")
  expect_no_error(
    filtered <- suppressMessages(
      filter_excluded_covariates(empty_df, predictor_col = "predictor",
                                  app_type = "poisson_regression")
    )
  )
  expect_s3_class(filtered, "data.frame")
  expect_equal(nrow(filtered), 0L)
  expect_named(filtered, c("predictor", "coefficient", "p_value"))
})

# ---------------------------------------------------------------------------
# Test 2: non-empty df behavior unchanged — at least one predictor known to
# trigger exclusion AND at least one known to pass through.
# ---------------------------------------------------------------------------

test_that("filter_excluded_covariates on non-empty df preserves existing behavior", {
  # "review_count" is a meta-attribute excluded for poisson_regression context
  # (per exclusion_rules.yaml). "diameter_mm" is a product spec that should
  # pass through. We test both rows survive structurally and the exclusion
  # filter removes review_count.
  non_empty <- data.frame(
    predictor = c("review_count", "diameter_mm"),
    coefficient = c(0.05, 0.20),
    p_value = c(0.001, 0.001),
    stringsAsFactors = FALSE
  )

  filtered <- suppressMessages(
    filter_excluded_covariates(non_empty, predictor_col = "predictor",
                                app_type = "poisson_regression")
  )
  expect_s3_class(filtered, "data.frame")
  # diameter_mm should remain (not in exclusion list)
  expect_true("diameter_mm" %in% filtered$predictor)
  # review_count should be excluded
  expect_false("review_count" %in% filtered$predictor)
})

# ---------------------------------------------------------------------------
# Test 3: missing predictor_col still raises actionable error
# (regression guard — the empty-df short-circuit must come AFTER the existing
# column-check stop(), not before, so users still get clear error on bad input)
# ---------------------------------------------------------------------------

test_that("filter_excluded_covariates still raises on missing predictor_col", {
  bad_df <- data.frame(other_col = character(0))
  expect_error(
    filter_excluded_covariates(bad_df, predictor_col = "predictor"),
    regexp = "Column 'predictor' not found"
  )
})

cat("\n[#713] All filter_excluded_covariates empty-df guard tests PASSED.\n")
