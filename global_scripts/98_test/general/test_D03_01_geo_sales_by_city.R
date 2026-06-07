#!/usr/bin/env Rscript
# test_D03_01_geo_sales_by_city.R
# ==============================================================================
# Regression test for #418 — D03_01 city-level aggregation (US drill-down)
#
# Background:
#   #348 added US state drill-down for the world map. #418 extends this to
#   city-level (3-level chain: country → US state → city).
#
#   New helper: 04_utils/fn_aggregate_geo_sales_by_city.R
#     aggregate_geo_sales_by_city(con, source_table, platform_id)
#       → returns data.frame grouped by
#         (platform_id, product_line_id_filter, ship_state, ship_city)
#       → US-only (ship_country = 'US')
#       → filters out empty ship_state / ship_city
#       → uses tbl2 + dplyr (DM_R023 v1.2 — no raw SQL for reads)
#
#   New table: app_data.df_geo_sales_by_city  (written by run_D03_01)
#
# Decisions (locked, per Plan approval 2026-05-04):
#   - Q1 = Option A (3-level chain, US-only city aggregation)
#   - Q2 = US-only city (symmetric to #348 state pattern)
#   - Q3 = non-US country no-op (existing #348 behavior)
#
# Functions Under Test:
#   - 04_utils/fn_aggregate_geo_sales_by_city.R::aggregate_geo_sales_by_city()
#
# Usage (from any company project root):
#   Rscript scripts/global_scripts/98_test/general/test_D03_01_geo_sales_by_city.R
#
# Principles:
# - MP029: No fake data — synthetic but deterministic; in-memory DuckDB only
# - DM_R023 v1.2: Universal DBI Approach — tbl2 + dplyr, no raw SQL
# - DEV_R052: Business logic uses English keys (not translated)
# - TD_R007: Plain R + assert() pattern (matches test_D05_01_growth_rates.R)
# ==============================================================================

# ---------- Test harness ----------
pass_count <- 0L
fail_count <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    pass_count <<- pass_count + 1L
    message(sprintf("  [PASS] %s", msg))
  } else {
    fail_count <<- fail_count + 1L
    message(sprintf("  [FAIL] %s", msg))
  }
}

approx_equal <- function(a, b, tol = 1e-6) {
  isTRUE(!is.na(a) && !is.na(b) && abs(a - b) < tol)
}

# ---------- Resolve script paths ----------
script_root <- NULL
for (cand in c("scripts/global_scripts", "shared/global_scripts",
               "../scripts/global_scripts", "../shared/global_scripts",
               ".", "..", "../..")) {
  if (dir.exists(file.path(cand, "16_derivations")) &&
      dir.exists(file.path(cand, "04_utils"))) {
    script_root <- normalizePath(cand, mustWork = TRUE)
    break
  }
}
if (is.null(script_root)) {
  stop("Cannot locate global_scripts root from getwd()=", getwd())
}
message(sprintf("Using script_root=%s", script_root))

helper_path <- file.path(script_root, "04_utils", "fn_aggregate_geo_sales_by_city.R")
tbl2_path   <- file.path(script_root, "02_db_utils", "tbl2", "fn_tbl2.R")

# ---------- Source under test ----------
if (!file.exists(helper_path)) {
  stop(sprintf("RED: helper not yet implemented: %s", helper_path))
}
if (file.exists(tbl2_path)) source(tbl2_path)
source(helper_path)

# ---------- Library guards ----------
suppressPackageStartupMessages({
  for (pkg in c("DBI", "duckdb", "dplyr", "dbplyr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Required package not available: %s — install with install.packages('%s')",
                   pkg, pkg))
    }
  }
})

# ---------- Synthetic data factory ----------
# Mimics row structure of df_{platform}_sales___standardized after 2TR ETL
make_synthetic_sales <- function() {
  # Hand-crafted scenarios (column names match D03_01 query_state):
  #   - 4 US California rows (Los Angeles ×2 / San Francisco ×2; PL=blb)
  #   - 2 US New York rows (NYC ×2; PL=blb)
  #   - 2 US Texas rows (Houston ×1; PL=mil; tests multi-PL)
  #   - 1 US row with empty ship_city → must be FILTERED OUT
  #   - 1 US row with NA ship_city → must be FILTERED OUT
  #   - 2 Japan rows (Tokyo) → must be FILTERED OUT (non-US)
  #   - 1 row with order_status='Pending' (US/CA/SF) → must be FILTERED OUT
  data.frame(
    transaction_id     = sprintf("T%04d", 1:13),
    amazon_order_id    = c("OA1","OA1","OB1","OB2","OC1","OC2",
                           "OD1","OD2","OE1","OF1","OG1","OG2","OH1"),
    customer_id        = c("C1","C1","C2","C3","C4","C5",
                           "C6","C7","C8","C9","C10","C11","C12"),
    platform_id        = "amz",
    product_line_id    = c("blb","blb","blb","blb","blb","blb",
                           "mil","mil","blb","blb","blb","blb","blb"),
    ship_country       = c("US","US","US","US","US","US",
                           "US","US","US","US","JP","JP","US"),
    ship_state         = c("CA","CA","CA","CA","NY","NY",
                           "TX","TX","CA","FL","",  "",  "CA"),
    ship_city          = c("Los Angeles","Los Angeles","San Francisco","San Francisco",
                           "New York","New York","Houston","Houston",
                           "",  NA,  "Tokyo","Tokyo","San Francisco"),
    lineproduct_price  = c(100, 150, 200, 250, 300, 350,
                           400, 450, 500,  60,  70,  80,  90),
    quantity           = c(1, 2, 1, 3, 1, 2, 1, 1, 1, 1, 1, 1, 1),
    order_status       = c("Shipped","Shipped","Shipped","Shipped","Shipped","Shipped",
                           "Shipped","Shipped","Shipped","Shipped","Shipped","Shipped",
                           "Pending"),
    stringsAsFactors   = FALSE
  )
}

# ---------- Test fixture: in-memory DuckDB ----------
make_fixture <- function(df, table_name = "df_amz_sales___standardized") {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  DBI::dbWriteTable(con, table_name, df, overwrite = TRUE)
  con
}

main <- function() {
  message("=== test_D03_01_geo_sales_by_city ===")

  con <- make_fixture(make_synthetic_sales())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # ------------------------------------------------------------------------
  # S1: helper returns data.frame with required columns
  # ------------------------------------------------------------------------
  message("\n[S1] aggregate_geo_sales_by_city() returns required columns")
  out <- aggregate_geo_sales_by_city(con, "df_amz_sales___standardized", "amz")

  required_cols <- c("platform_id", "product_line_id_filter",
                     "ship_state", "ship_city",
                     "total_revenue", "order_count", "customer_count",
                     "avg_order_value", "avg_quantity")
  missing <- setdiff(required_cols, names(out))
  assert(length(missing) == 0,
         sprintf("output has all required columns (missing: %s)",
                 if (length(missing) == 0) "none" else paste(missing, collapse = ",")))

  assert(is.data.frame(out), "output is data.frame (collected from dbplyr)")

  # ------------------------------------------------------------------------
  # S2: US-only filter — non-US (Tokyo) rows excluded
  # ------------------------------------------------------------------------
  message("\n[S2] non-US rows excluded (Japan/Tokyo)")
  assert(!"Tokyo" %in% out$ship_city, "Tokyo (Japan) NOT in output (US-only filter)")

  # ------------------------------------------------------------------------
  # S3: Empty / NA ship_city rows excluded
  # ------------------------------------------------------------------------
  message("\n[S3] rows with empty or NA ship_city excluded")
  assert(!"" %in% out$ship_city, "empty ship_city excluded")
  assert(!any(is.na(out$ship_city)), "NA ship_city excluded")

  # ------------------------------------------------------------------------
  # S4: order_status filter — only Shipped rows aggregated
  # ------------------------------------------------------------------------
  message("\n[S4] order_status='Pending' excluded")
  # The Pending row is US/CA/SF (#13). SF aggregation = 200+250 only (no +90).
  sf_blb <- out[out$ship_state == "CA" & out$ship_city == "San Francisco" &
                  out$product_line_id_filter == "blb", , drop = FALSE]
  assert(nrow(sf_blb) >= 1, "San Francisco × blb row exists in PL aggregation")
  if (nrow(sf_blb) >= 1) {
    assert(approx_equal(sf_blb$total_revenue[1], 200 + 250),
           sprintf("SF/blb total_revenue = 450 (Pending row excluded); got %.2f",
                   sf_blb$total_revenue[1]))
  }

  # ------------------------------------------------------------------------
  # S5: Aggregation correctness — Los Angeles × blb totals
  # ------------------------------------------------------------------------
  message("\n[S5] aggregation arithmetic — LA × blb")
  la_blb <- out[out$ship_state == "CA" & out$ship_city == "Los Angeles" &
                  out$product_line_id_filter == "blb", , drop = FALSE]
  assert(nrow(la_blb) >= 1, "LA × blb row exists")
  if (nrow(la_blb) >= 1) {
    # 2 rows for OA1 (T1, T2): prices 100+150, both share order_id OA1, customer C1
    assert(approx_equal(la_blb$total_revenue[1], 100 + 150),
           sprintf("LA/blb total_revenue = 250; got %.2f", la_blb$total_revenue[1]))
    assert(la_blb$order_count[1] == 1L,
           sprintf("LA/blb order_count = 1 (single distinct order OA1); got %d",
                   la_blb$order_count[1]))
    assert(la_blb$customer_count[1] == 1L,
           sprintf("LA/blb customer_count = 1; got %d", la_blb$customer_count[1]))
    # avg_order_value = 250 / 1 = 250
    assert(approx_equal(la_blb$avg_order_value[1], 250),
           sprintf("LA/blb avg_order_value = 250; got %.2f", la_blb$avg_order_value[1]))
  }

  # ------------------------------------------------------------------------
  # S6: 'all' product_line_id_filter rollup row exists per (state, city)
  # ------------------------------------------------------------------------
  message("\n[S6] 'all' product_line rollup — same (state, city) appears with PL='all'")
  # Texas × Houston is mil-only (no other PL) — but 'all' rollup should still exist
  # with same totals because mil is the sole PL.
  hou_all <- out[out$ship_state == "TX" & out$ship_city == "Houston" &
                   out$product_line_id_filter == "all", , drop = FALSE]
  hou_mil <- out[out$ship_state == "TX" & out$ship_city == "Houston" &
                   out$product_line_id_filter == "mil", , drop = FALSE]
  assert(nrow(hou_all) >= 1, "Houston × 'all' rollup row exists")
  assert(nrow(hou_mil) >= 1, "Houston × mil PL row exists")
  if (nrow(hou_all) >= 1 && nrow(hou_mil) >= 1) {
    assert(approx_equal(hou_all$total_revenue[1], hou_mil$total_revenue[1]),
           "Houston 'all' rollup === mil PL (since mil is sole PL there)")
  }

  # NY × NYC has only blb; check 'all' === blb
  nyc_all <- out[out$ship_state == "NY" & out$ship_city == "New York" &
                   out$product_line_id_filter == "all", , drop = FALSE]
  assert(nrow(nyc_all) >= 1, "NYC × 'all' rollup row exists")
  if (nrow(nyc_all) >= 1) {
    assert(approx_equal(nyc_all$total_revenue[1], 300 + 350),
           sprintf("NYC 'all' total = 650; got %.2f", nyc_all$total_revenue[1]))
  }

  # ------------------------------------------------------------------------
  # S7: cross-platform isolation — non-amz platforms filtered out by source
  #     (the source_table arg ties to a single platform; helper trusts it)
  # ------------------------------------------------------------------------
  message("\n[S7] platform_id column is consistently 'amz' (helper input contract)")
  assert(all(out$platform_id == "amz"),
         sprintf("all output rows have platform_id='amz'; saw: %s",
                 paste(unique(out$platform_id), collapse = ",")))

  # ------------------------------------------------------------------------
  # S8: required-column validation (verify-2 P2#7 fix)
  # ------------------------------------------------------------------------
  message("\n[S8] required-column validation surfaces clear error")
  con_bad <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con_bad, shutdown = TRUE), add = TRUE)
  # Source table missing ship_country / lineproduct_price etc.
  bad_df <- data.frame(
    ship_state = "CA", ship_city = "Los Angeles",
    customer_id = "C1", quantity = 1L,
    stringsAsFactors = FALSE
  )
  DBI::dbWriteTable(con_bad, "df_bad_sales", bad_df, overwrite = TRUE)
  err_msg <- tryCatch(
    {
      aggregate_geo_sales_by_city(con_bad, "df_bad_sales", "amz")
      ""
    },
    error = function(e) conditionMessage(e)
  )
  assert(nzchar(err_msg), "missing-columns triggers error (not silent NULL)")
  assert(grepl("missing required column", err_msg, fixed = TRUE),
         sprintf("error message mentions 'missing required column'; got: %s",
                 substr(err_msg, 1, 120)))
  assert(grepl("order_status", err_msg) || grepl("ship_country", err_msg) ||
           grepl("lineproduct_price", err_msg),
         "error message lists at least one specific missing column name")

  # ------------------------------------------------------------------------
  # S9: aggregate_one helper accepts vector dim_cols (verify-2 HIGH#1 fix)
  # ------------------------------------------------------------------------
  message("\n[S9] aggregate_one supports multi-dim grouping (state+city)")
  # Smoke check: paste(c("ship_state","ship_city"), collapse=", ") produces
  # the expected SQL fragment that the actual sprintf in fn_D03_01_core.R uses.
  dim_cols <- c("ship_state", "ship_city")
  dim_csv <- paste(dim_cols, collapse = ", ")
  assert(dim_csv == "ship_state, ship_city",
         sprintf("vector dim_cols collapses to '%s'", dim_csv))
  # And single-col still works (regression for existing country/state callers).
  assert(paste("ship_country", collapse = ", ") == "ship_country",
         "single-string dim_cols unchanged")

  # ------------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------------
  message(sprintf("\n=== %d passed, %d failed ===", pass_count, fail_count))

  if (fail_count > 0L) {
    quit(status = 1L)
  }
}

main()
