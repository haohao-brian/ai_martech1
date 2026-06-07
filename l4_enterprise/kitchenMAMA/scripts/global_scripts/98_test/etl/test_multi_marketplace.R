#' Tests for Multi-marketplace support from day one
#'
#' Covers spec requirement "Multi-marketplace support from day one" scenarios:
#'   - Same SKU across three marketplaces (rows differ by (sku, marketplace))
#'   - SKU sold on only one marketplace
#'
#' Source: qef-product-master-redesign spectra change, task 5.3

library(testthat)
library(dplyr)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_resolve_company_product_master.R"))

# Helper
stub_row <- function(sku, marketplace, asin,
                     product_line_id = "rpl", brand = "ER00") {
  data.frame(
    sku = sku, marketplace = marketplace, amz_asin = asin,
    product_line_id = product_line_id, brand = brand,
    cost = NA_real_, profit = NA_real_,
    product_name = NA_character_, status = NA_character_,
    launch_date = NA_character_,
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# Scenario: Same SKU across three marketplaces
# ==============================================================================

test_that("Same SKU across amz_us + amz_ca + amz_mx produces 3 distinct rows", {
  rows <- rbind(
    stub_row("F23A-BK-SK", "amz_us", "B0XAAAA001"),
    stub_row("F23A-BK-SK", "amz_ca", "B0XAAAA002"),
    stub_row("F23A-BK-SK", "amz_mx", "B0XAAAA003")
  )

  result <- resolve_company_product_master_from_sources(list(
    gsheet_master = rows,
    gsheet_sku_asin = rows[0, ],
    keys_xlsx = rows[0, ],
    sku_asin_xlsx = rows[0, ]
  ))

  expect_equal(nrow(result), 3)
  # PK = (sku, marketplace) unique
  expect_false(any(duplicated(result[, c("sku", "marketplace")])))
  # Each marketplace has distinct ASIN
  expect_equal(length(unique(result$amz_asin)), 3)
})

# ==============================================================================
# Scenario: SKU sold on only one marketplace
# ==============================================================================

test_that("SKU sold only on amz_us: exactly one row, no phantoms elsewhere", {
  rows <- stub_row("US_ONLY_SKU", "amz_us", "B0XUS0001")

  result <- resolve_company_product_master_from_sources(list(
    gsheet_master = rows,
    gsheet_sku_asin = rows[0, ],
    keys_xlsx = rows[0, ],
    sku_asin_xlsx = rows[0, ]
  ))

  expect_equal(nrow(result), 1)
  expect_equal(result$marketplace, "amz_us")
  expect_equal(result$amz_asin, "B0XUS0001")
})
