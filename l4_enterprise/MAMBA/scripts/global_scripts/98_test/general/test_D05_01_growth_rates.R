#!/usr/bin/env Rscript
# test_D05_01_growth_rates.R
# ==============================================================================
# Regression test for #416 — D05_01 QoQ + category aggregate + excess_growth
#
# Background:
#   D05_01 originally produces brand-level monthly aggregates with MoM and YoY.
#   #416 adds:
#     - QoQ (Quarter-over-Quarter, lag-3 same-month formula parallel to YoY)
#     - category_revenue (cross-platform sum per product_line per month)
#     - category_mom_pct / category_yoy_pct / category_qoq_pct
#     - excess_growth_yoy / excess_growth_mom / excess_growth_qoq
#       (= brand pct - category pct, in percentage points)
#
#   Decision 1 (locked, plan-tier approval): category = SUM across platforms
#     within same product_line_id_filter. Includes self.
#   Decision 2 (locked): excess_growth = brand_pct - category_pct (差值, pp).
#
# Functions Under Test:
#   - 04_utils/fn_compute_growth_rates.R::compute_growth_rates()  (pure helper)
#   - 16_derivations/fn_D05_01_finalize_category.R::finalize_D05_01_category()
#     (operates on a data.frame; DB write skipped in test mode)
#
# Usage (from project root, one of the company directories):
#   Rscript scripts/global_scripts/98_test/general/test_D05_01_growth_rates.R
#
# Principles:
# - MP029: No fake data — synthetic but deterministic; no production DB hit
# - TD_R007: Plain R + assert() pattern (matches test_dplyr_coalesce_prefix.R)
# - DEV_R052: Business logic uses English keys (not translated)
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
# Script may be invoked from project root (scripts/global_scripts/...) or from
# shared/ (shared/global_scripts/...). Probe both.
script_root <- NULL
for (cand in c("scripts/global_scripts", "shared/global_scripts",
               "../scripts/global_scripts", "../shared/global_scripts")) {
  if (dir.exists(file.path(cand, "16_derivations"))) {
    script_root <- normalizePath(cand, mustWork = TRUE)
    break
  }
}
if (is.null(script_root)) {
  stop("Cannot locate global_scripts root from getwd()=", getwd())
}
message(sprintf("Using script_root=%s", script_root))

helper_path  <- file.path(script_root, "04_utils", "fn_compute_growth_rates.R")
finalize_path <- file.path(script_root, "16_derivations", "fn_D05_01_finalize_category.R")

# ---------- Source under test ----------
if (!file.exists(helper_path)) {
  stop(sprintf("RED: helper not yet implemented: %s", helper_path))
}
if (!file.exists(finalize_path)) {
  stop(sprintf("RED: finalize not yet implemented: %s", finalize_path))
}
source(helper_path)
source(finalize_path)

main <- function() {
  message("=== test_D05_01_growth_rates ===")

  # ------------------------------------------------------------------------
  # S1: compute_growth_rates() — basic MoM / YoY / QoQ on single time series
  # ------------------------------------------------------------------------
  message("\n[S1] compute_growth_rates() returns mom_pct / yoy_pct / qoq_pct")
  # 24 months: 2024-01..2025-12, revenue = 100 + month_index * 10
  ym <- format(seq(as.Date("2024-01-01"), as.Date("2025-12-01"), by = "month"), "%Y-%m")
  rev_seq <- 100 + seq_along(ym) * 10  # 110, 120, ..., 340
  df_in <- data.frame(year_month = ym, total_revenue = rev_seq,
                      stringsAsFactors = FALSE)

  out <- compute_growth_rates(df_in, value_col = "total_revenue",
                              time_col = "year_month")

  assert("mom_pct" %in% names(out), "output has mom_pct column")
  assert("yoy_pct" %in% names(out), "output has yoy_pct column")
  assert("qoq_pct" %in% names(out), "output has qoq_pct column")
  assert(nrow(out) == nrow(df_in), "output row count preserved")

  # MoM at index 2 (2024-02 vs 2024-01): (120 - 110) / 110 * 100 = 9.0909...
  expected_mom_2 <- (120 - 110) / 110 * 100
  assert(approx_equal(out$mom_pct[2], expected_mom_2),
         sprintf("MoM at 2024-02: expected %.4f, got %.4f",
                 expected_mom_2, out$mom_pct[2]))

  # MoM at index 1 = NA (no prior month)
  assert(is.na(out$mom_pct[1]), "MoM at 2024-01 = NA (no prior month)")

  # YoY at index 13 (2025-01 vs 2024-01): (230 - 110) / 110 * 100 = 109.0909...
  expected_yoy_13 <- (230 - 110) / 110 * 100
  assert(approx_equal(out$yoy_pct[13], expected_yoy_13),
         sprintf("YoY at 2025-01: expected %.4f, got %.4f",
                 expected_yoy_13, out$yoy_pct[13]))

  # YoY at index 12 (2024-12) = NA (no 2023-12 data)
  assert(is.na(out$yoy_pct[12]), "YoY at 2024-12 = NA (no prior year same month)")

  # QoQ at index 4 (2024-04 vs 2024-01, lag 3): (140 - 110) / 110 * 100 = 27.27...
  expected_qoq_4 <- (140 - 110) / 110 * 100
  assert(approx_equal(out$qoq_pct[4], expected_qoq_4),
         sprintf("QoQ at 2024-04 (vs 2024-01, lag 3): expected %.4f, got %.4f",
                 expected_qoq_4, out$qoq_pct[4]))

  # QoQ at index 3 = NA (no 2023-12 data, lag 3 falls before series)
  assert(is.na(out$qoq_pct[3]), "QoQ at 2024-03 = NA (lag 3 before series start)")

  # ------------------------------------------------------------------------
  # S2: compute_growth_rates() — zero/NA handling (divide by zero)
  # ------------------------------------------------------------------------
  message("\n[S2] compute_growth_rates() handles zero / NA prior values")
  df_zero <- data.frame(
    year_month = c("2024-01", "2024-02", "2024-03"),
    total_revenue = c(0, 100, 200),
    stringsAsFactors = FALSE
  )
  out_zero <- compute_growth_rates(df_zero, "total_revenue", "year_month")
  assert(is.na(out_zero$mom_pct[2]),
         "MoM = NA when prior is 0 (no division by zero)")

  # ------------------------------------------------------------------------
  # S3: finalize_D05_01_category() — category aggregate (SUM across platforms)
  # ------------------------------------------------------------------------
  message("\n[S3] finalize_D05_01_category() sums revenue across platforms")
  # Build minimal brand-level df: 2 platforms × 1 product_line × 24 months
  # Platform amz: 100, 110, 120, ... per month
  # Platform cbz: 50, 55, 60, ... per month
  # Category sum at each month: amz + cbz
  ym24 <- format(seq(as.Date("2024-01-01"), as.Date("2025-12-01"), by = "month"), "%Y-%m")
  rev_amz <- 100 + (seq_along(ym24) - 1) * 10  # 100, 110, 120, ...
  rev_cbz <- 50  + (seq_along(ym24) - 1) * 5   # 50, 55, 60, ...
  brand_df <- rbind(
    data.frame(year_month = ym24, platform_id = "amz",
               product_line_id_filter = "blb",
               total_revenue = rev_amz,
               mom_revenue_pct = NA_real_, yoy_revenue_pct = NA_real_,
               qoq_revenue_pct = NA_real_,
               stringsAsFactors = FALSE),
    data.frame(year_month = ym24, platform_id = "cbz",
               product_line_id_filter = "blb",
               total_revenue = rev_cbz,
               mom_revenue_pct = NA_real_, yoy_revenue_pct = NA_real_,
               qoq_revenue_pct = NA_real_,
               stringsAsFactors = FALSE)
  )

  # Recompute brand-level pct columns to populate them realistically
  for (combo in list(c("amz", "blb"), c("cbz", "blb"))) {
    plat <- combo[1]; pl <- combo[2]
    sel <- brand_df$platform_id == plat & brand_df$product_line_id_filter == pl
    sub <- brand_df[sel, ]
    sub <- compute_growth_rates(sub, "total_revenue", "year_month")
    brand_df$mom_revenue_pct[sel] <- sub$mom_pct
    brand_df$yoy_revenue_pct[sel] <- sub$yoy_pct
    brand_df$qoq_revenue_pct[sel] <- sub$qoq_pct
  }

  out_cat <- finalize_D05_01_category(brand_df = brand_df, app_data = NULL)

  # New columns present
  for (col in c("category_revenue", "category_mom_pct", "category_yoy_pct",
                "category_qoq_pct", "excess_growth_mom", "excess_growth_yoy",
                "excess_growth_qoq")) {
    assert(col %in% names(out_cat), sprintf("column %s present", col))
  }

  # Category at (2024-01, blb) = 100 (amz) + 50 (cbz) = 150
  cat_jan <- out_cat$category_revenue[out_cat$year_month == "2024-01" &
                                      out_cat$product_line_id_filter == "blb"]
  assert(all(cat_jan == 150), "category_revenue at (2024-01, blb) = 150 for both platform rows")

  # Category at (2025-01, blb) = (100 + 12*10) + (50 + 12*5) = 220 + 110 = 330
  cat_2025_01 <- unique(out_cat$category_revenue[out_cat$year_month == "2025-01" &
                                                 out_cat$product_line_id_filter == "blb"])
  assert(length(cat_2025_01) == 1L && cat_2025_01 == 330,
         sprintf("category_revenue at (2025-01, blb) = 330; got=%s", toString(cat_2025_01)))

  # ------------------------------------------------------------------------
  # S4: category YoY at 2025-01 vs 2024-01: (330 - 150) / 150 * 100 = 120
  # ------------------------------------------------------------------------
  message("\n[S4] category_yoy_pct uses category time series")
  cat_yoy_2025_01 <- unique(out_cat$category_yoy_pct[out_cat$year_month == "2025-01" &
                                                     out_cat$product_line_id_filter == "blb"])
  expected_cat_yoy <- (330 - 150) / 150 * 100
  assert(length(cat_yoy_2025_01) == 1L && approx_equal(cat_yoy_2025_01, expected_cat_yoy),
         sprintf("category_yoy_pct at (2025-01, blb): expected %.2f, got %s",
                 expected_cat_yoy, toString(cat_yoy_2025_01)))

  # ------------------------------------------------------------------------
  # S5: excess_growth_yoy = brand_yoy_pct - category_yoy_pct
  # ------------------------------------------------------------------------
  message("\n[S5] excess_growth_yoy = brand_yoy - category_yoy (差值)")
  # amz at 2025-01: brand = 220, brand_yoy = (220-100)/100 * 100 = 120
  # category_yoy at 2025-01 = 120 (computed above)
  # excess = 120 - 120 = 0
  amz_row <- out_cat[out_cat$year_month == "2025-01" &
                     out_cat$platform_id == "amz" &
                     out_cat$product_line_id_filter == "blb", ]
  assert(nrow(amz_row) == 1L, "exactly one row for (2025-01, amz, blb)")
  assert(approx_equal(amz_row$excess_growth_yoy, 0),
         sprintf("excess_yoy at (2025-01, amz, blb): expected 0, got %.4f",
                 amz_row$excess_growth_yoy))

  # cbz at 2025-01: brand = 110, brand_yoy = (110-50)/50 * 100 = 120
  # excess = 120 - 120 = 0
  cbz_row <- out_cat[out_cat$year_month == "2025-01" &
                     out_cat$platform_id == "cbz" &
                     out_cat$product_line_id_filter == "blb", ]
  assert(nrow(cbz_row) == 1L, "exactly one row for (2025-01, cbz, blb)")
  assert(approx_equal(cbz_row$excess_growth_yoy, 0),
         sprintf("excess_yoy at (2025-01, cbz, blb): expected 0 (proportional growth), got %.4f",
                 cbz_row$excess_growth_yoy))

  # ------------------------------------------------------------------------
  # S6: Outperforming platform — brand grows faster than category
  # ------------------------------------------------------------------------
  message("\n[S6] excess_yoy positive when brand outperforms category")
  # New scenario: amz doubles, cbz stays flat
  brand_df2 <- rbind(
    data.frame(year_month = ym24, platform_id = "amz",
               product_line_id_filter = "blb",
               # 100 ramps linearly to 200 in 24 months → at 2025-01 (idx 13) = 100 + 12*100/23 ≈ 152.17
               # Simpler: 2024-01 = 100, 2025-01 = 200 (exact 2x) — set explicitly
               total_revenue = ifelse(ym24 == "2024-01", 100,
                                ifelse(ym24 == "2025-01", 200, 0)),
               mom_revenue_pct = NA_real_, yoy_revenue_pct = NA_real_,
               qoq_revenue_pct = NA_real_,
               stringsAsFactors = FALSE),
    data.frame(year_month = ym24, platform_id = "cbz",
               product_line_id_filter = "blb",
               # cbz flat: 100 in 2024-01 and 100 in 2025-01
               total_revenue = ifelse(ym24 == "2024-01", 100,
                                ifelse(ym24 == "2025-01", 100, 0)),
               mom_revenue_pct = NA_real_, yoy_revenue_pct = NA_real_,
               qoq_revenue_pct = NA_real_,
               stringsAsFactors = FALSE)
  )
  for (combo in list(c("amz", "blb"), c("cbz", "blb"))) {
    plat <- combo[1]; pl <- combo[2]
    sel <- brand_df2$platform_id == plat & brand_df2$product_line_id_filter == pl
    sub <- brand_df2[sel, ]
    sub <- compute_growth_rates(sub, "total_revenue", "year_month")
    brand_df2$yoy_revenue_pct[sel] <- sub$yoy_pct
    brand_df2$mom_revenue_pct[sel] <- sub$mom_pct
    brand_df2$qoq_revenue_pct[sel] <- sub$qoq_pct
  }
  out_cat2 <- finalize_D05_01_category(brand_df = brand_df2, app_data = NULL)

  # Brand amz YoY at 2025-01: (200 - 100) / 100 = 100%
  # Category at 2024-01: 100 + 100 = 200; at 2025-01: 200 + 100 = 300
  # Category YoY at 2025-01: (300 - 200) / 200 = 50%
  # Excess for amz: 100 - 50 = 50pp
  # Excess for cbz: 0 - 50 = -50pp
  amz_row2 <- out_cat2[out_cat2$year_month == "2025-01" &
                       out_cat2$platform_id == "amz" &
                       out_cat2$product_line_id_filter == "blb", ]
  cbz_row2 <- out_cat2[out_cat2$year_month == "2025-01" &
                       out_cat2$platform_id == "cbz" &
                       out_cat2$product_line_id_filter == "blb", ]
  assert(approx_equal(amz_row2$excess_growth_yoy, 50),
         sprintf("excess_yoy amz outperformer: expected 50pp, got %.4f",
                 amz_row2$excess_growth_yoy))
  assert(approx_equal(cbz_row2$excess_growth_yoy, -50),
         sprintf("excess_yoy cbz underperformer: expected -50pp, got %.4f",
                 cbz_row2$excess_growth_yoy))

  # ------------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------------
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
