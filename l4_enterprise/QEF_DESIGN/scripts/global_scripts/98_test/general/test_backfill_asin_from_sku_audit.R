#!/usr/bin/env Rscript
# test_backfill_asin_from_sku_audit.R
# ==============================================================================
# Regression test for #473 — backfill_asin_from_sku() return_audit parameter.
#
# Background:
#   #472 added A' (Step 2.5 backfill in amz_ETL_sales_2TR.R) + C (note in
#   build_mapping_gaps for asin-as-sku rows). A' runs before C so C never
#   fires in production. #473 fixes the surfacing gap by adding return_audit
#   parameter to backfill_asin_from_sku() — when TRUE, returns list with dt +
#   audit_rows matching df_amazon_sales_coverage_audit schema for MP163
#   surface-to-attention loop.
#
# Test scenarios:
#   S1 (Scenario A): return_audit=TRUE with N asin-shaped rows — N audit rows
#                    correctly populated with reason/detector/observed values
#   S2 (Scenario B): return_audit=TRUE with 0 asin-shaped rows — empty audit
#   S3 (Scenario C): backward compat — no return_audit arg returns dt only
#   S4 (Scenario D): schema cross-compat — audit_rows columns match
#                    fn_validate_amz_sales_row_integrity::empty_audit
#
# Usage (from project root or any subdir):
#   Rscript shared/global_scripts/98_test/general/test_backfill_asin_from_sku_audit.R
#
# Principles:
# - MP029: No fake data — test fixtures constructed minimally + per scenario
# - MP163: Coverage audit table used as MP163 §3 surface-to-attention channel
# - TD_R007: Plain R + assert() pattern (matches sibling test files)
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

# ---------- Locate helpers ----------
locate_file <- function(rel_path) {
  for (cand in c(rel_path,
                 file.path("scripts/global_scripts", rel_path),
                 file.path("shared/global_scripts", rel_path),
                 file.path("../global_scripts", rel_path),
                 file.path("../shared/global_scripts", rel_path),
                 file.path("../../shared/global_scripts", rel_path),
                 file.path("../../../shared/global_scripts", rel_path))) {
    if (file.exists(cand)) return(normalizePath(cand, mustWork = TRUE))
  }
  NULL
}

backfill_path <- locate_file("05_etl_utils/amz/fn_backfill_asin_from_sku.R")
validator_path <- locate_file("05_etl_utils/amz/fn_validate_amz_sales_row_integrity.R")

if (is.null(backfill_path)) {
  stop("Cannot locate fn_backfill_asin_from_sku.R from getwd()=", getwd())
}
if (is.null(validator_path)) {
  stop("Cannot locate fn_validate_amz_sales_row_integrity.R from getwd()=", getwd())
}
message(sprintf("Using backfill helper: %s", backfill_path))
message(sprintf("Using validator helper: %s", validator_path))

source(backfill_path)
source(validator_path)

# ---------- Fixture builders ----------
make_dt_with_n_asin_shaped <- function(n_match, n_other = 1L) {
  # n_match rows have sku=ASIN-shape + asin=NA → backfill triggers
  # n_other rows have proper sku + proper asin → no trigger
  data.frame(
    sku  = c(sprintf("B0TEST%04d", seq_len(n_match)),
             rep("MERCHANT-SKU-001", n_other)),
    asin = c(rep(NA_character_, n_match),
             rep("B0VALID0001", n_other)),
    other_col = seq_len(n_match + n_other),
    stringsAsFactors = FALSE
  )
}

main <- function() {
  message("=== test_backfill_asin_from_sku_audit (#473) ===")

  # ------------------------------------------------------------------------
  # S1 (Scenario A): return_audit=TRUE with N asin-shaped rows
  # ------------------------------------------------------------------------
  message("\n[S1] return_audit=TRUE with N=3 asin-shaped rows")
  dt_in <- make_dt_with_n_asin_shaped(n_match = 3L, n_other = 2L)
  result <- backfill_asin_from_sku(dt_in, return_audit = TRUE)

  assert(is.list(result) && setequal(names(result), c("dt", "audit_rows")),
         "S1: return is list(dt, audit_rows)")
  assert(nrow(result$dt) == 5L,
         sprintf("S1: dt preserves row count (got %d, expected 5)", nrow(result$dt)))
  assert(nrow(result$audit_rows) == 3L,
         sprintf("S1: audit_rows has 3 entries (got %d)", nrow(result$audit_rows)))
  # Verify backfilled asin matches sku
  asin_filled <- result$dt$asin[1:3]
  sku_orig <- result$dt$sku[1:3]
  assert(all(asin_filled == sku_orig),
         "S1: backfilled asin equals original ASIN-shaped sku")
  # Verify untouched rows (4 + 5)
  assert(result$dt$asin[4] == "B0VALID0001" && result$dt$asin[5] == "B0VALID0001",
         "S1: non-matching rows unchanged (asin preserved)")
  # Verify audit row content
  assert(all(result$audit_rows$reason == "asin_as_sku_fallback"),
         "S1: audit reason='asin_as_sku_fallback'")
  assert(all(result$audit_rows$detected_via == "asin_shaped_sku_pattern"),
         "S1: audit detected_via='asin_shaped_sku_pattern'")
  assert(all(is.na(result$audit_rows$observed_asin)),
         "S1: audit observed_asin captured pre-backfill NA")
  assert(all(result$audit_rows$observed_sku == sku_orig),
         "S1: audit observed_sku captured the ASIN-shaped sku values")
  assert(setequal(result$audit_rows$source_row_index, 1:3),
         "S1: audit source_row_index = which(needs_backfill) positions")
  assert(inherits(result$audit_rows$detected_at, "POSIXct"),
         "S1: audit detected_at is POSIXct")

  # ------------------------------------------------------------------------
  # S2 (Scenario B): return_audit=TRUE with 0 asin-shaped rows → empty audit
  # ------------------------------------------------------------------------
  message("\n[S2] return_audit=TRUE with 0 asin-shaped rows")
  dt_in <- make_dt_with_n_asin_shaped(n_match = 0L, n_other = 4L)
  result <- backfill_asin_from_sku(dt_in, return_audit = TRUE)

  assert(is.list(result) && setequal(names(result), c("dt", "audit_rows")),
         "S2: return is list(dt, audit_rows) even with no matches")
  assert(nrow(result$audit_rows) == 0L,
         sprintf("S2: audit_rows is empty data.frame (got %d rows)",
                 nrow(result$audit_rows)))
  # dt unchanged from input
  assert(all(result$dt$asin == dt_in$asin),
         "S2: dt unchanged when no asin-shaped sku")

  # ------------------------------------------------------------------------
  # S3 (Scenario C): backward compat — no return_audit arg returns dt only
  # ------------------------------------------------------------------------
  message("\n[S3] backward compat: no return_audit arg returns dt directly")
  dt_in <- make_dt_with_n_asin_shaped(n_match = 2L, n_other = 1L)
  result_default <- backfill_asin_from_sku(dt_in)

  assert(is.data.frame(result_default) && !is.list(result_default[["dt"]]),
         "S3: default return is data.frame (not list)")
  assert(nrow(result_default) == 3L,
         "S3: default return preserves row count")
  # Same backfill behavior
  assert(result_default$asin[1] == result_default$sku[1] &&
         result_default$asin[2] == result_default$sku[2],
         "S3: backfill behavior unchanged when return_audit not specified")

  # Also test return_audit=FALSE explicit
  result_explicit_false <- backfill_asin_from_sku(dt_in, return_audit = FALSE)
  assert(is.data.frame(result_explicit_false) &&
         !is.list(result_explicit_false[["dt"]]),
         "S3: explicit return_audit=FALSE returns data.frame")

  # ------------------------------------------------------------------------
  # S4 (Scenario D): schema cross-compat with validate_amz_sales_row_integrity
  # ------------------------------------------------------------------------
  message("\n[S4] schema cross-compat with df_amazon_sales_coverage_audit")
  dt_in <- make_dt_with_n_asin_shaped(n_match = 2L, n_other = 0L)
  bf_result <- backfill_asin_from_sku(dt_in, return_audit = TRUE)

  # Get reference schema from validator empty case
  validator_result <- validate_amz_sales_row_integrity(
    data.frame(asin = character(0), sku = character(0),
               stringsAsFactors = FALSE),
    source_file = "test", verbose = FALSE
  )
  ref_cols <- names(validator_result$audit_rows)
  bf_cols <- names(bf_result$audit_rows)

  assert(setequal(ref_cols, bf_cols),
         sprintf("S4: backfill audit columns match validator empty_audit: ref=[%s] bf=[%s]",
                 paste(ref_cols, collapse = ","),
                 paste(bf_cols, collapse = ",")))

  # Column types must also match (so dbWriteTable to same table works)
  for (col in intersect(ref_cols, bf_cols)) {
    ref_class <- class(validator_result$audit_rows[[col]])[1]
    bf_class  <- class(bf_result$audit_rows[[col]])[1]
    assert(identical(ref_class, bf_class),
           sprintf("S4: column %s class matches (ref=%s bf=%s)",
                   col, ref_class, bf_class))
  }

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
