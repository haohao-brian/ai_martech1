#####
# test_D03_01_platform_agnostic.R — fn_D03_01_core column_spec verification
#
# Refs #671: fn_D03_01_core.R was hardcoded to amz columns (ship_country,
# ship_state, lineproduct_price, amz_amazon_order_id) and silently no-op'd
# for cbz / eby standardized schemas with different source column names.
#
# Tests cover:
#   T1 default_amz_column_spec() returns canonical 5-key list (api stability)
#   T2 amz default column_spec: in-memory amz-shaped fixture → produces non-empty country+state output
#   T3 cbz-style partial column_spec (state = NULL): country output written, state skipped gracefully (MP163)
#   T4 missing required keys: graceful no-op + WARN (NOT stop) per MP163
#
# Pattern: in-memory DuckDB fixtures with minimal shape per platform,
# call run_D03_01() with column_spec, assert outputs + check WARN emission.
#####

library(testthat)
library(DBI)
library(duckdb)

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Locate fn_D03_01_core.R (try project-root-relative, fallback to test-dir-relative)
core_candidates <- c(
  "shared/global_scripts/16_derivations/fn_D03_01_core.R",
  file.path(dirname(testthat::test_path() %||% "."), "..", "16_derivations", "fn_D03_01_core.R")
)
core_path <- core_candidates[file.exists(core_candidates)][1]
stopifnot(!is.na(core_path), file.exists(core_path))

# GLOBAL_DIR is referenced by the function for sourcing db utilities
if (!exists("GLOBAL_DIR")) {
  GLOBAL_DIR <- normalizePath(dirname(dirname(core_path)))
}

source(core_path, local = TRUE)


# ---------- Helper: build minimal fixture DBs (amz / cbz shapes) ----------

make_fixture_dbs <- function(platform_shape = "amz") {
  # Returns list(transformed = <con>, app = <con>, source_table = <chr>)
  transformed <- dbConnect(duckdb(), tempfile(fileext = ".duckdb"))
  app <- dbConnect(duckdb(), tempfile(fileext = ".duckdb"))

  if (platform_shape == "amz") {
    src_tbl <- "df_amz_sales___standardized"
    df <- data.frame(
      platform_id           = rep("amz", 8),
      product_line_id       = rep(c("blb", "bys"), each = 4),
      ship_country          = c("US", "US", "US", "US", "CA", "US", "US", "GB"),
      ship_state            = c("CA", "TX", "NY", "FL", NA, "WA", "OR", NA),
      lineproduct_price     = c(100, 200, 150, 80, 120, 90, 60, 200),
      amz_amazon_order_id   = paste0("AMZ-", 1:8),
      customer_id           = paste0("C-", c(1, 2, 1, 3, 4, 2, 5, 6)),
      quantity              = c(1, 2, 1, 1, 2, 1, 1, 3),
      stringsAsFactors      = FALSE
    )
    dbWriteTable(transformed, src_tbl, df)
  } else if (platform_shape == "cbz") {
    src_tbl <- "df_cbz_sales___standardized"
    df <- data.frame(
      platform_id                                       = rep("cbz", 6),
      product_line_id                                   = rep("default", 6),
      billing_address_detail_address_country            = c("TW", "TW", "TW", "TW", "TW", "JP"),
      billing_address_detail_address_province           = c("台北市", "新北市", "台中市", "台北市", "高雄市", NA),
      lineproduct_price                                 = c(500, 300, 800, 200, 1000, 600),
      order_id                                          = paste0("CBZ-", 1:6),
      customer_id                                       = paste0("C-", c(1, 1, 2, 3, 2, 4)),
      quantity                                          = c(1, 1, 2, 1, 1, 1),
      stringsAsFactors                                  = FALSE
    )
    dbWriteTable(transformed, src_tbl, df)
  } else {
    stop("Unknown platform_shape: ", platform_shape)
  }

  list(transformed = transformed, app = app, source_table = src_tbl)
}

cleanup_fixture <- function(fixt) {
  try(dbDisconnect(fixt$transformed, shutdown = TRUE), silent = TRUE)
  try(dbDisconnect(fixt$app, shutdown = TRUE), silent = TRUE)
  if (exists("transformed_data", envir = globalenv())) rm("transformed_data", envir = globalenv())
  if (exists("app_data", envir = globalenv())) rm("app_data", envir = globalenv())
}

# Inject fixture DBI connections into globalenv so run_D03_01() can find them
# via its `exists("transformed_data")` / `exists("app_data")` guards (R scoping:
# functions defined at top-level have global closure, so look up names in globalenv).
inject_globals <- function(fixt) {
  assign("transformed_data", fixt$transformed, envir = globalenv())
  assign("app_data", fixt$app, envir = globalenv())
}


# ---------- T1: default_amz_column_spec() shape stability ----------

test_that("T1 default_amz_column_spec returns canonical 5-key list", {
  spec <- default_amz_column_spec()
  expect_type(spec, "list")
  expect_named(spec, c("order_id", "revenue", "country", "state", "quantity"),
               ignore.order = TRUE)
  expect_equal(spec$order_id, "amz_amazon_order_id")
  expect_equal(spec$revenue,  "lineproduct_price")
  expect_equal(spec$country,  "ship_country")
  expect_equal(spec$state,    "ship_state")
  expect_equal(spec$quantity, "quantity")
})


# ---------- T2: amz default works on amz-shaped fixture ----------

test_that("T2 amz default column_spec aggregates country + state from amz fixture", {
  fixt <- make_fixture_dbs("amz")
  on.exit(cleanup_fixture(fixt))

  inject_globals(fixt)

  result <- run_D03_01("amz", config = NULL, column_spec = default_amz_column_spec())

  # state validation: should produce all 3 output tables
  expect_true(result$success || !is.null(result$outputs))
  expect_true("df_geo_sales_by_country" %in% result$outputs)
  expect_true("df_geo_sales_by_state" %in% result$outputs)

  # Verify country table has rows (3 countries: US/CA/GB)
  expect_true(dbExistsTable(app_data, "df_geo_sales_by_country"))
  country_rows <- dbGetQuery(app_data, "SELECT * FROM df_geo_sales_by_country")
  expect_gt(nrow(country_rows), 0)
  # canonical output column name: ship_country (regardless of source)
  expect_true("ship_country" %in% names(country_rows))
  expect_setequal(unique(country_rows$ship_country), c("US", "CA", "GB"))
})


# ---------- T3: cbz-style spec with state=NULL — graceful skip ----------

test_that("T3 cbz column_spec with state=NULL produces country output, skips state aggregation gracefully", {
  fixt <- make_fixture_dbs("cbz")
  on.exit(cleanup_fixture(fixt))

  inject_globals(fixt)

  cbz_spec <- list(
    order_id = "order_id",
    revenue  = "lineproduct_price",
    country  = "billing_address_detail_address_country",
    state    = NULL,                # cbz Taiwan-only: state aggregation skipped
    quantity = "quantity"
  )

  result <- run_D03_01("cbz", config = NULL, column_spec = cbz_spec)

  # state aggregation must NOT be in outputs (state was NULL)
  expect_false("df_geo_sales_by_state" %in% result$outputs)
  # country aggregation MUST be in outputs
  expect_true("df_geo_sales_by_country" %in% result$outputs)

  # Verify country output table has cbz rows + correct column names
  expect_true(dbExistsTable(app_data, "df_geo_sales_by_country"))
  cbz_rows <- dbGetQuery(app_data, "SELECT * FROM df_geo_sales_by_country")
  expect_gt(nrow(cbz_rows), 0)
  expect_setequal(unique(cbz_rows$ship_country), c("TW", "JP"))

  # df_geo_sales_by_state should NOT exist in app
  expect_false(dbExistsTable(app_data, "df_geo_sales_by_state"))
})


# ---------- T4: missing required keys → graceful no-op + WARN (MP163) ----------

test_that("T4 column_spec missing required key triggers WARN + early return (NOT stop)", {
  fixt <- make_fixture_dbs("amz")
  on.exit(cleanup_fixture(fixt))

  inject_globals(fixt)

  # Drop required key: country
  bad_spec <- list(
    order_id = "amz_amazon_order_id",
    revenue  = "lineproduct_price",
    # country MISSING (required)
    state    = "ship_state",
    quantity = "quantity"
  )

  # Should NOT stop() — should emit WARN + return result with success=FALSE
  result <- expect_warning(
    run_D03_01("amz", config = NULL, column_spec = bad_spec),
    regexp = "missing.*required|column_spec"
  )

  expect_false(result$success)
  expect_equal(result$rows_processed, 0L)
  expect_length(result$outputs, 0)
  expect_equal(result$skipped_reason, "missing_required_column_spec")

  # app_data should be untouched (no tables written)
  expect_false(dbExistsTable(app_data, "df_geo_sales_by_country"))
})


# ---------- T5 (additional): NULL revenue (different required key) ----------

test_that("T5 column_spec with NULL revenue also triggers graceful skip", {
  fixt <- make_fixture_dbs("amz")
  on.exit(cleanup_fixture(fixt))

  inject_globals(fixt)

  bad_spec <- list(
    order_id = "amz_amazon_order_id",
    revenue  = NULL,                 # required — NULL → skip
    country  = "ship_country",
    state    = "ship_state",
    quantity = "quantity"
  )

  result <- expect_warning(
    run_D03_01("amz", config = NULL, column_spec = bad_spec),
    regexp = "missing.*required|column_spec"
  )

  expect_false(result$success)
})
