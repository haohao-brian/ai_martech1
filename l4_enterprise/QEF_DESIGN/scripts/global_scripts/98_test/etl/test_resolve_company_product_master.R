#' Tests for fn_resolve_company_product_master
#'
#' Covers spec requirement "Multi-source resolver with priority order" scenarios:
#'   - Only Gsheet master populated
#'   - All sources empty
#'   - Mixed sources, no overlap
#'
#' Source: qef-product-master-redesign spectra change, task 5.1
#' Spec: openspec/changes/qef-product-master-redesign/specs/product-master-canonical/spec.md

library(testthat)
library(dplyr)

# Locate repo root (tests may be run from anywhere)
repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_resolve_company_product_master.R"))

# ==============================================================================
# Test Fixtures: stub source readers so tests don't need real Gsheet / xlsx
# ==============================================================================

# A minimal valid row — all required columns present.
stub_row <- function(sku, marketplace = "amz_us", asin = paste0("B0X", sku),
                     product_line_id = "rpl", brand = "ER00",
                     cost = NA_real_, profit = NA_real_,
                     product_name = NA_character_, status = NA_character_,
                     launch_date = NA_character_) {
  data.frame(
    sku = sku, marketplace = marketplace, amz_asin = asin,
    product_line_id = product_line_id, brand = brand,
    cost = cost, profit = profit,
    product_name = product_name, status = status, launch_date = launch_date,
    stringsAsFactors = FALSE
  )
}

empty_master <- function() {
  data.frame(
    sku = character(0), marketplace = character(0), amz_asin = character(0),
    product_line_id = character(0), brand = character(0),
    cost = numeric(0), profit = numeric(0),
    product_name = character(0), status = character(0), launch_date = character(0),
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# Scenario: Only Gsheet master populated
# ==============================================================================

test_that("Only Gsheet master populated: returns rows from source 1", {
  sources <- list(
    gsheet_master = stub_row("SKU1"),
    gsheet_sku_asin = empty_master(),
    keys_xlsx = empty_master(),
    sku_asin_xlsx = empty_master()
  )
  result <- resolve_company_product_master_from_sources(sources)

  expect_equal(nrow(result), 1)
  expect_equal(result$sku, "SKU1")
  expect_equal(result$source_origin, "gsheet_master")
})

# ==============================================================================
# Scenario: All sources empty
# ==============================================================================

test_that("All sources empty: returns empty df with correct schema + warning", {
  sources <- list(
    gsheet_master = empty_master(),
    gsheet_sku_asin = empty_master(),
    keys_xlsx = empty_master(),
    sku_asin_xlsx = empty_master()
  )

  expect_warning(
    result <- resolve_company_product_master_from_sources(sources),
    "sources were checked"
  )
  expect_equal(nrow(result), 0)
  expect_true(all(
    c("sku", "marketplace", "amz_asin", "product_line_id", "brand",
      "cost", "profit", "product_name", "status", "launch_date",
      "source_origin") %in% names(result)
  ))
})

# ==============================================================================
# Scenario: Mixed sources, no overlap
# ==============================================================================

test_that("Mixed sources no overlap: union preserves provenance", {
  sources <- list(
    gsheet_master = stub_row("SKU_A"),
    gsheet_sku_asin = empty_master(),
    keys_xlsx = stub_row("SKU_B", asin = "B0XSKU_B"),
    sku_asin_xlsx = empty_master()
  )
  result <- resolve_company_product_master_from_sources(sources)

  expect_equal(nrow(result), 2)
  expect_setequal(result$sku, c("SKU_A", "SKU_B"))

  # Provenance preserved per row
  expect_equal(
    result$source_origin[result$sku == "SKU_A"],
    "gsheet_master"
  )
  expect_equal(
    result$source_origin[result$sku == "SKU_B"],
    "keys_xlsx"
  )
})
