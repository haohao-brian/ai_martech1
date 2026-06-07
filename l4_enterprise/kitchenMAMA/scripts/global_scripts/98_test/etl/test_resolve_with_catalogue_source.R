#' Tests for `try_read_catalogue` + `dedup_catalogue` (Track C).
#'
#' Spec: openspec/changes/amz-sales-derive-sku-asin/specs/qef-product-master-gsheet/spec.md
#'   - Catalogue source in resolver (read df_amz_product_master + dedup)
#'   - Catalogue source graceful degradation (missing db / table / column)
#'
#' Note: `df_amz_product_master` is produced by `amz_ETL_product_profiles_0IM.R`
#' (unions per-line `product_profile_<line>` Gsheet tabs); this resolver only
#' reads, never rebuilds.

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
# Pure helper: dedup_catalogue
# ==============================================================================

test_that("dedup_catalogue returns empty df on empty/NULL input", {
  expect_equal(nrow(dedup_catalogue(NULL)), 0L)
  expect_equal(nrow(dedup_catalogue(data.frame())), 0L)
})

test_that("dedup_catalogue passes through unique (sku, marketplace) rows untouched", {
  raw <- data.frame(
    sku        = c("S1", "S2", "S3"),
    marketplace = c("amz_us", "amz_us", "amz_uk"),
    amz_asin   = c("B0AAA", "B0BBB", "B0CCC"),
    stringsAsFactors = FALSE
  )
  result <- dedup_catalogue(raw)
  expect_equal(nrow(result), 3L)
  expect_setequal(result$amz_asin, c("B0AAA", "B0BBB", "B0CCC"))
})

test_that("dedup_catalogue keeps first row + emits warning on duplicate (sku, marketplace)", {
  raw <- data.frame(
    sku        = c("F23A-BK", "F23A-BK", "F23A-WH"),
    marketplace = c("amz_us",  "amz_us",  "amz_us"),
    amz_asin   = c("B07AAA111", "B07BBB222", "B07WHT999"),
    stringsAsFactors = FALSE
  )
  expect_warning(
    result <- dedup_catalogue(raw),
    regexp = "duplicate"
  )
  expect_equal(nrow(result), 2L)
  bk <- result[result$sku == "F23A-BK", ]
  expect_equal(bk$amz_asin, "B07AAA111")  # first row kept
})

test_that("dedup_catalogue treats different marketplaces as different keys", {
  raw <- data.frame(
    sku        = c("S1", "S1"),
    marketplace = c("amz_us", "amz_uk"),
    amz_asin   = c("B0US", "B0UK"),
    stringsAsFactors = FALSE
  )
  # No warning: different marketplaces => different keys
  result <- dedup_catalogue(raw)
  expect_equal(nrow(result), 2L)
})

# ==============================================================================
# try_read_catalogue: graceful degradation
# ==============================================================================

test_that("try_read_catalogue returns empty + message when raw_data.duckdb missing", {
  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_catalogue(cfg, db_paths = list(raw_data = "/nonexistent/path.duckdb")),
    regexp = "raw_data.duckdb not found"
  )
  expect_equal(nrow(df), 0L)
})

test_that("try_read_catalogue returns empty + message when df_amz_product_master table absent", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE other_table (x INTEGER)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db)),
    regexp = "df_amz_product_master not found"
  )
  expect_equal(nrow(df), 0L)
})

test_that("try_read_catalogue stops with actionable error when amz_asin column missing", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "CREATE TABLE df_amz_product_master (sku VARCHAR, marketplace VARCHAR)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_error(
    try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db)),
    regexp = "missing required column 'amz_asin'"
  )
})

test_that("try_read_catalogue gracefully returns empty when sku column absent (ASIN-keyed catalogue)", {
  # QEF-style real-world case: df_amz_product_master is unioned from
  # product_profile tabs that are ASIN-keyed only (no SKU column).
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      amz_asin VARCHAR, marketplace VARCHAR,
      product_line_id VARCHAR, brand VARCHAR
    )
  ")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('B07AAA','amz_us','rpl','BrandA')")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db)),
    regexp = "no 'sku' column"
  )
  expect_equal(nrow(df), 0L,
               info = "ASIN-only catalogue must return empty (cannot supply sku-keyed tuples)")
})

# ==============================================================================
# try_read_catalogue: end-to-end against real (in-memory) DuckDB
# ==============================================================================

test_that("try_read_catalogue produces deduplicated rows from product master table", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR
    )
  ")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-BK','amz_us','B07AAA111')")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-BK','amz_us','B07BBB222')")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-WH','amz_us','B07WHT999')")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_warning(
    df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db)),
    regexp = "duplicate"
  )

  expect_equal(nrow(df), 2L)
  bk <- df[df$sku == "F23A-BK", ]
  expect_equal(bk$amz_asin, "B07AAA111")  # first row wins
})

# ==============================================================================
# Spec: amz-mapping-gap-detection (Issue #471)
# Catalogue must additionally project (sku, product_line_id) into
# attr(result, "sku_product_line_map") so detect_anomalies can compute
# no_product_line gaps.
# ==============================================================================

test_that("try_read_catalogue attaches sku_product_line_map attr when catalogue has product_line_id", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR, product_line_id VARCHAR
    )
  ")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-BK','amz_us','B07AAA111','sfg')")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-WH','amz_us','B07WHT999','sfg')")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('NoLine-1','amz_us','B07NOPE001',NULL)")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db))

  pl_map <- attr(df, "sku_product_line_map")
  expect_false(is.null(pl_map),
               info = "try_read_catalogue must attach sku_product_line_map attr (Issue #471)")
  expect_true(is.data.frame(pl_map))
  expect_setequal(names(pl_map), c("sku", "product_line_id"))
  # Only rows with non-NA product_line_id contribute to the map
  expect_equal(nrow(pl_map), 2L)
  expect_setequal(pl_map$sku, c("F23A-BK", "F23A-WH"))
})

test_that("try_read_catalogue attaches empty sku_product_line_map attr when catalogue lacks sku column (ASIN-keyed graceful degrade)", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      amz_asin VARCHAR, marketplace VARCHAR, product_line_id VARCHAR
    )
  ")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('B07AAA','amz_us','sfg')")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  expect_message(
    df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db)),
    regexp = "no 'sku' column"
  )
  pl_map <- attr(df, "sku_product_line_map")
  expect_false(is.null(pl_map),
               info = "attr must be present even when catalogue degrades to empty (callers rely on this contract)")
  expect_true(is.data.frame(pl_map))
  expect_equal(nrow(pl_map), 0L)
  expect_setequal(names(pl_map), c("sku", "product_line_id"))
})

test_that("try_read_catalogue attaches empty sku_product_line_map attr when catalogue has sku but no product_line_id column", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), tmp_db)
  DBI::dbExecute(con, "
    CREATE TABLE df_amz_product_master (
      sku VARCHAR, marketplace VARCHAR, amz_asin VARCHAR
    )
  ")
  DBI::dbExecute(con, "INSERT INTO df_amz_product_master VALUES ('F23A-BK','amz_us','B07AAA111')")
  DBI::dbDisconnect(con, shutdown = TRUE)

  cfg <- list(platforms = list(amz = list(etl_sources = list())))
  df <- try_read_catalogue(cfg, db_paths = list(raw_data = tmp_db))

  pl_map <- attr(df, "sku_product_line_map")
  expect_false(is.null(pl_map))
  expect_equal(nrow(pl_map), 0L,
               info = "no product_line_id column -> empty map (no_product_line check will be skipped)")
})
