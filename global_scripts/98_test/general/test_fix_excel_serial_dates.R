#!/usr/bin/env Rscript
# test_fix_excel_serial_dates.R
# ==============================================================================
# Test suite for fix_excel_serial_dates() helper (#445)
#
# Usage (from project root):
#   Rscript scripts/global_scripts/98_test/general/test_fix_excel_serial_dates.R
#
# The function converts Excel serial numbers (numeric or numeric-like strings)
# in a dataframe column to ISO timestamp strings, while leaving non-serial
# values (e.g. already-parsed ISO strings) and NAs unchanged.
#
# Principles:
# - MP029: No fake data — all test inputs are synthetic but empirically grounded
#   (45323.435208333336 is the real value surfaced by issue #436 verify).
# - TD_R007: Test pattern uses plain R + assert() helper, matches existing
#   98_test/general/ conventions.
# ==============================================================================

# ---------- Locate and source the function under test ----------

fn_candidates <- c(
  # From company-project update_scripts/ cwd:
  file.path("scripts", "global_scripts", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R"),
  # From project root:
  file.path("global_scripts", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R"),
  # From anywhere with ../ relative to global_scripts/:
  file.path("..", "global_scripts", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R"),
  file.path("..", "..", "global_scripts", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R"),
  file.path("..", "..", "..", "global_scripts", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R"),
  # From inside the test file's own directory (98_test/general/):
  file.path("..", "..", "05_etl_utils", "common",
            "fn_fix_excel_serial_dates.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_fix_excel_serial_dates.R not found in expected paths")
}
source(fn_path)

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

main <- function() {
  message("=== test_fix_excel_serial_dates ===")

  # ---- Scenario 1: Single Excel serial value ----
  message("\n[S1] Single Excel serial number string → ISO timestamp")
  # 45323.435208333336 = 2024-02-01 10:26:42 UTC
  # (45323 days since 1899-12-30; 0.435208333336 × 86400s = 37602s = 10h26m42s)
  # Note: issue #445 body cited "2024-02-27" but that was a hand-computed error;
  # verified via R: as.POSIXct(45323.435208333336 * 86400, origin="1899-12-30", tz="UTC")
  df1 <- data.frame(purchase_date = "45323.435208333336",
                    stringsAsFactors = FALSE)
  out1 <- fix_excel_serial_dates(df1, col_name = "purchase_date")
  expected1 <- "2024-02-01 10:26:42"
  assert(identical(out1$purchase_date, expected1),
         sprintf("serial → ISO; got='%s' expected='%s'",
                 out1$purchase_date, expected1))

  # ---- Scenario 2: Already-ISO string → unchanged ----
  message("\n[S2] ISO string → unchanged")
  df2 <- data.frame(purchase_date = "2024-11-01 15:30:00",
                    stringsAsFactors = FALSE)
  out2 <- fix_excel_serial_dates(df2, col_name = "purchase_date")
  assert(identical(out2$purchase_date, "2024-11-01 15:30:00"),
         sprintf("ISO unchanged; got='%s'", out2$purchase_date))

  # ---- Scenario 3: NA preserved ----
  message("\n[S3] NA preserved")
  df3 <- data.frame(purchase_date = NA_character_,
                    stringsAsFactors = FALSE)
  out3 <- fix_excel_serial_dates(df3, col_name = "purchase_date")
  assert(is.na(out3$purchase_date),
         "NA preserved")

  # ---- Scenario 4: Mixed input ----
  message("\n[S4] Mixed input: serial + ISO + NA + another serial")
  df4 <- data.frame(
    purchase_date = c("45323.435208333336", "2024-11-01",
                      NA_character_, "45324.25"),
    stringsAsFactors = FALSE
  )
  out4 <- fix_excel_serial_dates(df4, col_name = "purchase_date")
  assert(out4$purchase_date[1] == "2024-02-01 10:26:42",
         "mixed[1] serial → ISO")
  assert(out4$purchase_date[2] == "2024-11-01",
         "mixed[2] ISO unchanged")
  assert(is.na(out4$purchase_date[3]),
         "mixed[3] NA preserved")
  assert(out4$purchase_date[4] == "2024-02-02 06:00:00",
         sprintf("mixed[4] second serial → ISO; got='%s'",
                 out4$purchase_date[4]))

  # ---- Scenario 5: Missing column → return df unchanged ----
  message("\n[S5] Missing target column → no-op, no error")
  df5 <- data.frame(other_col = "foo", stringsAsFactors = FALSE)
  out5 <- fix_excel_serial_dates(df5, col_name = "purchase_date")
  assert(identical(out5, df5), "missing column handled gracefully")

  # ---- Scenario 6: Out-of-range serial → keep original, emit warning ----
  message("\n[S6] Out-of-range serial (year < 1954 or > 2089) → keep original")
  df6 <- data.frame(
    purchase_date = c("999999", "10", "-5"),
    stringsAsFactors = FALSE
  )
  out6 <- suppressWarnings(
    fix_excel_serial_dates(df6, col_name = "purchase_date")
  )
  # All three are out of sanity range → kept as original strings
  assert(identical(out6$purchase_date, c("999999", "10", "-5")),
         "out-of-range serials kept as strings")

  # ---- Scenario 7: Empty data frame ----
  message("\n[S7] Empty data frame")
  df7 <- data.frame(purchase_date = character(0),
                    stringsAsFactors = FALSE)
  out7 <- fix_excel_serial_dates(df7, col_name = "purchase_date")
  assert(nrow(out7) == 0L && is.character(out7$purchase_date),
         "empty df handled, column type preserved")

  # ---- Scenario 8: Custom column name ----
  message("\n[S8] Custom col_name argument")
  df8 <- data.frame(shipping_date = "45323.435208333336",
                    stringsAsFactors = FALSE)
  out8 <- fix_excel_serial_dates(df8, col_name = "shipping_date")
  assert(out8$shipping_date == "2024-02-01 10:26:42",
         "custom col_name works")

  # ---- Summary ----
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
