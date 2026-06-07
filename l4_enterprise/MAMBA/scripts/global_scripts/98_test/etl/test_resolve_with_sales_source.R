#' Tests for `try_read_sales` + `aggregate_sales_mode` (Track C).
#'
#' Spec: openspec/changes/amz-sales-derive-sku-asin/specs/qef-product-master-gsheet/spec.md
#'   - Sales source in resolver (mode aggregation)
#'   - Sales source graceful degradation (missing db / table / column)
#'
#' Pure helper `aggregate_sales_mode()` is tested standalone (no DB needed).
#' DB-level integration (`try_read_sales`) uses an in-memory DuckDB.

library(testthat)
library(dplyr)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/02_db_utils/tbl2/fn_tbl2.R"))
source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_resolve_company_product_master.R"))

# ==============================================================================
# Pure helper: aggregate_sales_mode
# ==============================================================================

test_that("aggregate_sales_mode picks dominant ASIN per (sku, marketplace)", {
  counts <- data.frame(
    sku        = c("F23A-BK", "F23A-BK", "F23A-WH"),
    marketplace = c("amz_us",  "amz_us",  "amz_us"),
    amz_asin   = c("B07ABC123", "B07XYZ999", "B07DEF456"),
    n          = c(100L,        1L,          50L),
    stringsAsFactors = FALSE
  )

  result <- aggregate_sales_mode(counts)

  expect_equal(nrow(result), 2L)
  bk <- result[result$sku == "F23A-BK", ]
  expect_equal(bk$amz_asin, "B07ABC123")  # mode wins (100 > 1)
  wh <- result[result$sku == "F23A-WH", ]
  expect_equal(wh$amz_asin, "B07DEF456")
})

test_that("aggregate_sales_mode returns empty df on empty/NULL input", {
  expect_equal(nrow(aggregate_sales_mode(NULL)), 0L)
  expect_equal(nrow(aggregate_sales_mode(data.frame())), 0L)
})

test_that("aggregate_sales_mode resolves ties deterministically (alphabetical sku then mp)", {
  counts <- data.frame(
    sku        = c("S1", "S1"),
    marketplace = c("amz_us", "amz_us"),
    amz_asin   = c("B0AAA", "B0BBB"),
    n          = c(10L, 10L),  # tie
    stringsAsFactors = FALSE
  )
  result <- aggregate_sales_mode(counts)
  expect_equal(nrow(result), 1L)
  # arrange(desc(n)) breaks tie by row order; first row wins → B0AAA
  expect_equal(result$amz_asin, "B0AAA")
})

test_that("aggregate_sales_mode handles multiple marketplaces independently", {
  counts <- data.frame(
    sku        = c("S1", "S1", "S1"),
    marketplace = c("amz_us", "amz_us", "amz_uk"),
    amz_asin   = c("B0US01", "B0US02", "B0UK01"),
    n          = c(5L, 3L, 2L),
    stringsAsFactors = FALSE
  )
  result <- aggregate_sales_mode(counts)
  expect_equal(nrow(result), 2L)
  us <- result[result$marketplace == "amz_us", ]
  uk <- result[result$marketplace == "amz_uk", ]
  expect_equal(us$amz_asin, "B0US01")
  expect_equal(uk$amz_asin, "B0UK01")
})

# ==============================================================================
# try_read_sales: graceful degradation (no DB, no table, no column)
# ==============================================================================

test_that("try_read_sales returns empty + message when transformed_data.duckdb missing", {
  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_sales(cfg, db_paths = list(transformed_data = "/nonexistent/path.duckdb")),
    regexp = "transformed_data.duckdb not found"
  )
  expect_equal(nrow(df), 0L)
  expect_true("source_origin" %in% names(df) || all(MASTER_SCHEMA_COLS %in% names(df)))
})

test_that("try_read_sales returns empty + message when df_amz_sales___transformed table absent", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE other_table (x INTEGER)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_sales(cfg, db_paths = list(transformed_data = tmp_db)),
    regexp = "df_amz_sales___transformed not found"
  )
  expect_equal(nrow(df), 0L)
})

test_that("try_read_sales stops with actionable error when amz_asin column missing", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE df_amz_sales___transformed (sku VARCHAR, marketplace VARCHAR, purchase_date DATE)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_error(
    try_read_sales(cfg, db_paths = list(transformed_data = tmp_db)),
    regexp = "missing required column 'amz_asin'"
  )
})

test_that("try_read_sales stops when no recognised date column", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE df_amz_sales___transformed (sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR, some_other_date DATE)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_error(
    try_read_sales(cfg, db_paths = list(transformed_data = tmp_db)),
    regexp = "missing date column"
  )
})

# ==============================================================================
# try_read_sales: end-to-end mode aggregation against real (in-memory) DuckDB
# ==============================================================================

test_that("try_read_sales produces mode-aggregated rows from sales table", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_sales___transformed (
      sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR, purchase_date DATE
    )
  ")
  # 100 rows of B07ABC123 + 1 row of B07XYZ999 for SKU=F23A-BK
  insert_rows <- function(con, n, sku, mp, asin, date) {
    for (i in seq_len(n)) {
      DBI::dbExecute(con, sprintf(
        "INSERT INTO df_amz_sales___transformed VALUES ('%s','%s','%s','%s')",
        sku, mp, asin, date
      ))
    }
  }
  recent <- format(Sys.Date() - 5, "%Y-%m-%d")
  insert_rows(con, 100, "F23A-BK", "amz_us", "B07ABC123", recent)
  insert_rows(con,   1, "F23A-BK", "amz_us", "B07XYZ999", recent)
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  df <- try_read_sales(cfg, db_paths = list(transformed_data = tmp_db))

  expect_equal(nrow(df), 1L)
  expect_equal(df$sku, "F23A-BK")
  expect_equal(df$amz_asin, "B07ABC123")
})

# ==============================================================================
# Pure helper: map_sales_channel_to_marketplace
# ==============================================================================

test_that("map_sales_channel_to_marketplace covers common Amazon storefronts", {
  expect_equal(map_sales_channel_to_marketplace("Amazon.com"),    "amz_us")
  expect_equal(map_sales_channel_to_marketplace("Amazon.ca"),     "amz_ca")
  expect_equal(map_sales_channel_to_marketplace("Amazon.com.mx"), "amz_mx")
  expect_equal(map_sales_channel_to_marketplace("Amazon.co.uk"),  "amz_uk")
  expect_equal(map_sales_channel_to_marketplace("Amazon.de"),     "amz_de")
  expect_equal(map_sales_channel_to_marketplace("Amazon.co.jp"),  "amz_jp")
})

test_that("map_sales_channel_to_marketplace returns NA for non-Amazon channels", {
  expect_true(is.na(map_sales_channel_to_marketplace("Non-Amazon")))
  expect_true(is.na(map_sales_channel_to_marketplace("Non-Amazon US")))
  expect_true(is.na(map_sales_channel_to_marketplace("eBay")))
  expect_true(is.na(map_sales_channel_to_marketplace("")))
  expect_true(is.na(map_sales_channel_to_marketplace(NA_character_)))
})

test_that("map_sales_channel_to_marketplace vectorises correctly", {
  result <- map_sales_channel_to_marketplace(
    c("Amazon.com", "Non-Amazon", "Amazon.ca", "Amazon.de", NA_character_)
  )
  expect_equal(result, c("amz_us", NA_character_, "amz_ca", "amz_de", NA_character_))
})

# ==============================================================================
# try_read_sales: real-world QEF-style schema (asin column + sales_channel)
# ==============================================================================

test_that("try_read_sales accepts 'asin' column alias + derives marketplace from sales_channel", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_sales___transformed (
      sku VARCHAR, asin VARCHAR, sales_channel VARCHAR, purchase_date DATE
    )
  ")
  recent <- format(Sys.Date() - 5, "%Y-%m-%d")
  DBI::dbExecute(con, sprintf("INSERT INTO df_amz_sales___transformed VALUES ('S1','B07US','Amazon.com','%s')",   recent))
  DBI::dbExecute(con, sprintf("INSERT INTO df_amz_sales___transformed VALUES ('S1','B07CA','Amazon.ca', '%s')",   recent))
  DBI::dbExecute(con, sprintf("INSERT INTO df_amz_sales___transformed VALUES ('S1','B07XX','Non-Amazon','%s')",   recent))
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  df <- try_read_sales(cfg, db_paths = list(transformed_data = tmp_db))

  expect_equal(nrow(df), 2L,
               info = "Non-Amazon sales_channel rows must be excluded")
  expect_setequal(df$marketplace, c("amz_us", "amz_ca"))
  expect_setequal(df$amz_asin, c("B07US", "B07CA"))
  # Returned column is canonical 'amz_asin' regardless of source name
  expect_true("amz_asin" %in% names(df))
})

test_that("try_read_sales stops when neither marketplace nor sales_channel present", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE df_amz_sales___transformed (sku VARCHAR, amz_asin VARCHAR, purchase_date DATE)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_error(
    try_read_sales(cfg, db_paths = list(transformed_data = tmp_db)),
    regexp = "missing required column 'marketplace'"
  )
})

test_that("try_read_sales respects lookback_days from app_config", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_sales___transformed (
      sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR, purchase_date DATE
    )
  ")
  recent  <- format(Sys.Date() - 10,  "%Y-%m-%d")  # within 30-day lookback
  ancient <- format(Sys.Date() - 200, "%Y-%m-%d")  # outside 30-day lookback
  DBI::dbExecute(con, sprintf("INSERT INTO df_amz_sales___transformed VALUES ('S1','amz_us','B0RECENT','%s')", recent))
  DBI::dbExecute(con, sprintf("INSERT INTO df_amz_sales___transformed VALUES ('S1','amz_us','B0OLD',   '%s')", ancient))
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg_30 <- list(platforms = list(amz = list(etl_sources = list(amz_sales_lookback_days = 30L))))
  df <- try_read_sales(cfg_30, db_paths = list(transformed_data = tmp_db))
  expect_equal(nrow(df), 1L)
  expect_equal(df$amz_asin, "B0RECENT")  # ancient row excluded
})
