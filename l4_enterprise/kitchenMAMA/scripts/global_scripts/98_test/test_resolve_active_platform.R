#####
# CONSUMES: shared/global_scripts/04_utils/fn_resolve_active_platform.R
# PRODUCES: testthat assertions only
# TESTS: resolve_active_platform() — Issue #655 fix
#####

suppressPackageStartupMessages({
  library(testthat)
})

source(here::here("scripts", "global_scripts", "04_utils", "fn_resolve_active_platform.R"))

# Realistic configs (Format A: canonical named-list)
cfg_qef <- list(platforms = list(amz = list(status = "active")))
cfg_mamba <- list(platforms = list(
  cbz = list(status = "active"),
  eby = list(status = "active")
))
cfg_mixed <- list(platforms = list(
  cbz = list(status = "active"),
  eby = list(status = "inactive"),
  amz = list(status = "active")
))
cfg_empty <- list(platforms = list())
cfg_no_platforms <- list()

# Legacy format B (WISER/kitchenMAMA): `platform` char vector
cfg_wiser_legacy <- list(platform = c("amz", "officialwebsite"))
cfg_kitchen_legacy <- list(platform = c("amz", "officialwebsite"))

test_that("resolves specific platform when active", {
  expect_equal(resolve_active_platform("amz", cfg_qef), "amz")
  expect_equal(resolve_active_platform("cbz", cfg_mamba), "cbz")
  expect_equal(resolve_active_platform("eby", cfg_mamba), "eby")
})

test_that("'all' falls back to first active platform", {
  expect_equal(resolve_active_platform("all", cfg_qef), "amz")
  expect_equal(resolve_active_platform("all", cfg_mamba), "cbz")
  expect_equal(resolve_active_platform("all", cfg_mixed), "cbz")
})

test_that("NULL/NA/empty platform_id falls back to first active", {
  expect_equal(resolve_active_platform(NULL, cfg_qef), "amz")
  expect_equal(resolve_active_platform(NA_character_, cfg_qef), "amz")
  expect_equal(resolve_active_platform("", cfg_qef), "amz")
})

test_that("requested platform not in active list falls back to first active", {
  # User somehow picked "cbz" but only amz is active (e.g., stale URL state)
  expect_equal(resolve_active_platform("cbz", cfg_qef), "amz")
  # Requested inactive platform falls back
  expect_equal(resolve_active_platform("eby", cfg_mixed), "cbz")
})

test_that("no active platforms triggers fallback or stop", {
  expect_equal(resolve_active_platform("amz", cfg_empty, fallback = "amz"), "amz")
  expect_error(resolve_active_platform("all", cfg_empty),
               regexp = "no active platform")
  expect_error(resolve_active_platform("all", cfg_no_platforms),
               regexp = "no active platform")
})

test_that("config = NULL triggers fallback or stop", {
  expect_equal(resolve_active_platform("amz", NULL, fallback = "amz"), "amz")
  expect_error(resolve_active_platform("all", NULL),
               regexp = "no active platform")
})

test_that("legacy 'platform' (char vector) format works", {
  # Format B: config$platform = c(...) used by WISER + kitchenMAMA
  expect_equal(resolve_active_platform("amz", cfg_wiser_legacy), "amz")
  expect_equal(resolve_active_platform("all", cfg_wiser_legacy), "amz")
  expect_equal(resolve_active_platform("officialwebsite", cfg_wiser_legacy),
               "officialwebsite")
  expect_equal(resolve_active_platform("all", cfg_kitchen_legacy), "amz")
  expect_equal(resolve_active_platform(NULL, cfg_kitchen_legacy), "amz")
})

cat("[OK] resolve_active_platform tests passed (Issue #655)\n")
