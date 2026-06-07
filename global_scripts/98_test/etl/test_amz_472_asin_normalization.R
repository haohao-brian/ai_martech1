# ==============================================================================
# test_amz_472_asin_normalization.R
# Tests for #472: Amazon platform auto-fallback handling
#
# S1: backfill_asin_from_sku() — when sku is ASIN-shaped + asin is empty,
#     fill asin from sku without modifying sku (MP154 non-destructive).
# S2: build_mapping_gaps() — append "Amazon auto-fallback" note to
#     suggested_action when no_master_row gap entry has ASIN-shaped sku.
# ==============================================================================

library(testthat)

# ---- Locate global_scripts root (works from project root or test dir) -------
gs_root <- if (dir.exists("05_etl_utils/amz")) {
  "."
} else if (dir.exists("../05_etl_utils/amz")) {
  ".."
} else if (dir.exists("../../05_etl_utils/amz")) {
  "../.."
} else {
  stop("Cannot locate global_scripts root from cwd=", getwd())
}

source(file.path(gs_root, "05_etl_utils/amz/fn_backfill_asin_from_sku.R"))
source(file.path(gs_root, "05_etl_utils/amz/fn_detect_anomalies.R"))

# ==============================================================================
# S1: backfill_asin_from_sku() — fills asin only when sku is ASIN-shaped
# ==============================================================================

test_that("S1 fills asin when sku is ASIN-shaped and asin is NA", {
  dt <- data.frame(
    sku  = c("B0B5PNCFSF", "F23A-BK", "B0BBRXP6GH", "regular-sku"),
    asin = c(NA_character_, "B07EXAMPLE", NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  out <- backfill_asin_from_sku(dt)

  # Row 1: sku=ASIN, asin=NA -> asin filled from sku
  expect_equal(out$asin[1], "B0B5PNCFSF")
  # Row 2: sku=non-ASIN, asin=existing -> unchanged
  expect_equal(out$asin[2], "B07EXAMPLE")
  # Row 3: sku=ASIN, asin=NA -> asin filled from sku
  expect_equal(out$asin[3], "B0BBRXP6GH")
  # Row 4: sku=non-ASIN, asin=NA -> stays NA (we do not invent asins)
  expect_true(is.na(out$asin[4]))

  # sku column is never modified (MP154)
  expect_equal(out$sku, dt$sku)
})

test_that("S1 preserves asin when sku is ASIN-shaped but asin already populated", {
  dt <- data.frame(
    sku  = c("B0B5PNCFSF"),
    asin = c("B07ALREADY"),
    stringsAsFactors = FALSE
  )
  out <- backfill_asin_from_sku(dt)
  # Even though sku looks like ASIN, asin is non-empty -> do NOT overwrite
  expect_equal(out$asin, "B07ALREADY")
  expect_equal(out$sku, "B0B5PNCFSF")
})

test_that("S1 treats empty-string asin as backfillable (same as NA)", {
  dt <- data.frame(
    sku  = c("B0B5PNCFSF"),
    asin = c(""),
    stringsAsFactors = FALSE
  )
  out <- backfill_asin_from_sku(dt)
  expect_equal(out$asin, "B0B5PNCFSF")
})

test_that("S1 ignores rows where sku is not ASIN-shaped", {
  dt <- data.frame(
    sku  = c("F23A-BK", "B0123",        "B0XXXXXXX", "AB0B5PNCFSF"),
    asin = c(NA,         NA,             NA,          NA),
    stringsAsFactors = FALSE
  )
  out <- backfill_asin_from_sku(dt)
  # B0123 is too short; B0XXXXXXX is 9 chars; AB0... has prefix; F23A-BK has dash
  expect_true(all(is.na(out$asin)))
  expect_equal(out$sku, dt$sku)
})

test_that("S1 returns dt unchanged when columns missing (defensive)", {
  # Missing asin column entirely
  dt_no_asin <- data.frame(sku = "B0B5PNCFSF", stringsAsFactors = FALSE)
  expect_equal(backfill_asin_from_sku(dt_no_asin), dt_no_asin)

  # Missing sku column entirely
  dt_no_sku <- data.frame(asin = NA_character_, stringsAsFactors = FALSE)
  expect_equal(backfill_asin_from_sku(dt_no_sku), dt_no_sku)
})

test_that("S1 returns 0-row dt unchanged", {
  empty <- data.frame(sku = character(0), asin = character(0),
                      stringsAsFactors = FALSE)
  expect_equal(backfill_asin_from_sku(empty), empty)
})

test_that("S1 reports backfill count via message when verbose=TRUE", {
  dt <- data.frame(
    sku  = c("B0B5PNCFSF", "regular"),
    asin = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  expect_message(
    backfill_asin_from_sku(dt, verbose = TRUE),
    "Backfilled asin from ASIN-shaped sku for 1 row"
  )
})

# ==============================================================================
# S2: build_mapping_gaps() — Amazon auto-fallback note in suggested_action
# ==============================================================================

test_that("S2 appends auto-fallback note when sku is ASIN-shaped no_master_row", {
  resolved_master <- data.frame(
    sku = "FA-001", amz_asin = "B0XXXXXX01", marketplace = "amz_us",
    product_line_id = "pl1", brand = "BrandA",
    stringsAsFactors = FALSE
  )
  # ASIN-shaped sku in sales, no master row -> sku_missing branch
  sales_pairs <- data.frame(
    sku = "B0B5PNCFSF", amz_asin = "B0B5PNCFSF", marketplace = "amz_mx",
    sales_volume = 24,
    stringsAsFactors = FALSE
  )
  sku_pl_map <- data.frame(sku = character(0), product_line_id = character(0),
                            stringsAsFactors = FALSE)

  out <- build_mapping_gaps(resolved_master, sales_pairs, sku_pl_map)

  expect_equal(nrow(out), 1L)
  expect_equal(out$gap_type, "no_master_row")
  expect_equal(out$sku, "B0B5PNCFSF")
  # New note must mention Amazon auto-fallback context
  expect_match(out$suggested_action, "Amazon auto-fallback", fixed = TRUE)
  expect_match(out$suggested_action, "amz_ETL_sales_2TR", fixed = TRUE)
})

test_that("S2 does NOT append auto-fallback note for normal sku no_master_row", {
  resolved_master <- data.frame(
    sku = "FA-001", amz_asin = "B0XXXXXX01", marketplace = "amz_us",
    product_line_id = "pl1", brand = "BrandA",
    stringsAsFactors = FALSE
  )
  # Regular SKU (not ASIN-shape) in sales, no master row
  sales_pairs <- data.frame(
    sku = "F23A-BK", amz_asin = "B0NORMAL01", marketplace = "amz_us",
    sales_volume = 5,
    stringsAsFactors = FALSE
  )
  sku_pl_map <- data.frame(sku = character(0), product_line_id = character(0),
                            stringsAsFactors = FALSE)

  out <- build_mapping_gaps(resolved_master, sales_pairs, sku_pl_map)

  expect_equal(nrow(out), 1L)
  expect_equal(out$gap_type, "no_master_row")
  # Original "請在 KEYS.xlsx" guidance retained, no auto-fallback note appended
  expect_match(out$suggested_action, "KEYS.xlsx", fixed = TRUE)
  expect_false(grepl("Amazon auto-fallback", out$suggested_action, fixed = TRUE))
})
