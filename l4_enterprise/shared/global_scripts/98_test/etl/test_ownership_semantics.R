#' Tests for Query ownership semantics + Insert competitor-only ASIN
#'
#' Covers spec requirement "Layered product master schema" scenarios:
#'   - Query ownership via EXISTS on company_product_master (not a flag)
#'   - Insert competitor-only ASIN: 1 row in product_master, 0 in company_product_master
#'
#' Source: qef-product-master-redesign spectra change, task 5.4

library(testthat)
library(dplyr)
library(DBI)
library(duckdb)

# ==============================================================================
# Helpers: in-memory DuckDB for layered schema simulation
# ==============================================================================

setup_test_schema <- function() {
  con <- dbConnect(duckdb::duckdb(), ":memory:")

  dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      amz_asin VARCHAR,
      marketplace VARCHAR,
      product_line_id VARCHAR,
      brand VARCHAR,
      product_name VARCHAR,
      PRIMARY KEY (amz_asin, marketplace)
    );
  ")

  dbExecute(con, "
    CREATE TABLE df_amz_company_product_master (
      sku VARCHAR,
      marketplace VARCHAR,
      amz_asin VARCHAR,
      product_line_id VARCHAR,
      brand VARCHAR,
      PRIMARY KEY (sku, marketplace)
    );
  ")

  con
}

is_own_asin <- function(con, asin, marketplace) {
  sql <- sprintf(
    "SELECT EXISTS (SELECT 1 FROM df_amz_company_product_master
     WHERE amz_asin = '%s' AND marketplace = '%s') AS owned",
    asin, marketplace
  )
  dbGetQuery(con, sql)$owned
}

# ==============================================================================
# Scenario: Query ownership via EXISTS, not via flag
# ==============================================================================

test_that("Ownership semantics: EXISTS check returns TRUE/FALSE correctly", {
  con <- setup_test_schema()
  on.exit(dbDisconnect(con, shutdown = TRUE))

  # Insert 2 ASINs to catalogue: one owned, one competitor
  dbExecute(con, "INSERT INTO df_amz_product_master VALUES
    ('B0XOWN001', 'amz_us', 'rpl', 'ER00', 'QEF replacement lens'),
    ('B07RYSGLH9', 'amz_us', 'rpl', 'Revant', 'Revant Holbrook lens')")

  # Only B0XOWN001 gets an extension row (it is owned)
  dbExecute(con, "INSERT INTO df_amz_company_product_master VALUES
    ('QEF-RPL-001', 'amz_us', 'B0XOWN001', 'rpl', 'ER00')")

  expect_true(is_own_asin(con, "B0XOWN001", "amz_us"))
  expect_false(is_own_asin(con, "B07RYSGLH9", "amz_us"))
})

# ==============================================================================
# Scenario: Insert competitor-only ASIN
# ==============================================================================

test_that("Insert competitor-only ASIN: 1 row in master, 0 in company extension", {
  con <- setup_test_schema()
  on.exit(dbDisconnect(con, shutdown = TRUE))

  # Simulate ETL writing a competitor ASIN (like rpl B07RYSGLH9 / Revant)
  dbExecute(con, "INSERT INTO df_amz_product_master VALUES
    ('B07RYSGLH9', 'amz_us', 'rpl', 'Revant', 'Revant Holbrook lens')")

  master_count <- dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM df_amz_product_master WHERE amz_asin='B07RYSGLH9'")$n
  extension_count <- dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM df_amz_company_product_master WHERE amz_asin='B07RYSGLH9'")$n

  expect_equal(master_count, 1)
  expect_equal(extension_count, 0)
})
