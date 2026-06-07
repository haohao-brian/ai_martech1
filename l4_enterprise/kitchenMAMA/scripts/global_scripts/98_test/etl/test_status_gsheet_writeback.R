#' Tests for fn_write_status_gsheet (Status Gsheet auto-refresh writeback).
#'
#' Covers spec requirements from qef-gsheet-three-surface-redesign:
#'   - Status Gsheet auto-refresh writeback
#'   - ETL integration of Status writeback (silent skip when config missing)
#'
#' Source: qef-gsheet-three-surface-redesign spectra change, task 2.6

library(testthat)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_write_status_gsheet.R"))

# ==============================================================================
# Test fixtures
# ==============================================================================

sample_df <- function() {
  data.frame(
    sku = c("A", "B"),
    marketplace = c("amz_us", "amz_us"),
    field = c("brand", "brand"),
    value = c("X", "Y"),
    suggested_action = c("補資料", "補資料"),
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# Spec: ETL integration of Status writeback - silent skip when config missing
# ==============================================================================

test_that("write_status_gsheet returns empty result when config is NULL", {
  result <- write_status_gsheet(status_gsheet_config = NULL,
                                anomalies = sample_df())
  expect_equal(length(result), 0)
})

test_that("write_status_gsheet warns and skips when sheet_id is empty", {
  cfg <- list(sheet_id = "", tabs = list(anomalies = "_sys_anomalies"))
  expect_warning(
    result <- write_status_gsheet(cfg, anomalies = sample_df()),
    "sheet_id is empty"
  )
  expect_equal(length(result), 0)
})

test_that("write_status_gsheet silently skips when sheet_id is 'TBD'", {
  # 'TBD' is the conventional placeholder used in app_config.yaml between
  # Phase 2 config commit and the business creating the real Status Gsheet.
  cfg <- list(sheet_id = "TBD", tabs = list(anomalies = "_sys_anomalies"))
  result <- expect_silent(write_status_gsheet(cfg, anomalies = sample_df()))
  expect_equal(length(result), 0)
})

# ==============================================================================
# Spec: Status Gsheet auto-refresh writeback - API failure does not break ETL
# ==============================================================================

test_that("Google Sheets API failure produces warning, not error", {
  # Use mockery-free approach: stub googlesheets4::sheet_write to throw
  # by temporarily unlocking the namespace binding.
  skip_if_not_installed("googlesheets4")

  mock_ns <- asNamespace("googlesheets4")
  original_fn <- mock_ns$sheet_write
  unlockBinding("sheet_write", mock_ns)
  on.exit({
    assign("sheet_write", original_fn, envir = mock_ns)
    lockBinding("sheet_write", mock_ns)
  })

  assign("sheet_write", function(...) stop("Simulated API quota exceeded"),
         envir = mock_ns)

  cfg <- list(sheet_id = "fake_id_12345",
              tabs = list(anomalies = "_sys_anomalies"))

  expect_warning(
    result <- write_status_gsheet(cfg, anomalies = sample_df()),
    "failed to write tab.*Simulated API quota exceeded"
  )
  expect_false(result[["anomalies"]],
               info = "Result should record FALSE for failed tab")
})

test_that("write_status_gsheet skips NULL payloads", {
  skip_if_not_installed("googlesheets4")

  mock_ns <- asNamespace("googlesheets4")
  original_fn <- mock_ns$sheet_write
  unlockBinding("sheet_write", mock_ns)
  on.exit({
    assign("sheet_write", original_fn, envir = mock_ns)
    lockBinding("sheet_write", mock_ns)
  })

  call_log <- list()
  assign("sheet_write", function(data, ss, sheet, ...) {
    call_log[[length(call_log) + 1]] <<- list(ss = ss, sheet = sheet, nrows = nrow(data))
    invisible(NULL)
  }, envir = mock_ns)

  cfg <- list(sheet_id = "fake_id",
              tabs = list(anomalies = "A_tab",
                          missing_master = "M_tab",
                          drift = "D_tab"))

  result <- write_status_gsheet(
    cfg,
    anomalies = sample_df(),
    missing_master = NULL,    # skipped
    drift = sample_df()
  )

  expect_true(result[["anomalies"]])
  expect_true(is.na(result[["missing_master"]]))
  expect_true(result[["drift"]])
  expect_equal(length(call_log), 2)
  expect_setequal(vapply(call_log, function(c) c$sheet, character(1)),
                  c("A_tab", "D_tab"))
})

# ==============================================================================
# Spec: amz-mapping-gap-detection (Issue #471)
#   - Status Gsheet tab naming convention compliance: mapping_gaps -> _sys_mapping_gaps
#   - Missing master deprecation parallel-write window (both tabs simultaneously)
# ==============================================================================

mk_mapping_gaps_sample <- function() {
  data.frame(
    sku = c("S_NEW1", NA_character_),
    amz_asin = c("B07AAA", "B07ZZZ"),
    marketplace = c("amz_us", "amz_us"),
    gap_type = c("no_master_row", "no_master_row"),
    suggested_action = c("加入 KEYS.xlsx", "查 Amazon listing"),
    stringsAsFactors = FALSE
  )
}

test_that("write_status_gsheet writes mapping_gaps to '_sys_mapping_gaps' tab by default", {
  skip_if_not_installed("googlesheets4")

  mock_ns <- asNamespace("googlesheets4")
  original_fn <- mock_ns$sheet_write
  unlockBinding("sheet_write", mock_ns)
  on.exit({
    assign("sheet_write", original_fn, envir = mock_ns)
    lockBinding("sheet_write", mock_ns)
  })

  call_log <- list()
  assign("sheet_write", function(data, ss, sheet, ...) {
    call_log[[length(call_log) + 1]] <<- list(ss = ss, sheet = sheet,
                                              nrows = nrow(data))
    invisible(NULL)
  }, envir = mock_ns)

  # No tabs override -> use default tabs map (which MUST include mapping_gaps -> _sys_mapping_gaps)
  cfg <- list(sheet_id = "fake_id_mapping_gaps")

  result <- write_status_gsheet(
    cfg,
    mapping_gaps = mk_mapping_gaps_sample()
  )

  expect_true(result[["mapping_gaps"]],
              info = "mapping_gaps payload SHALL be written successfully")
  expect_equal(length(call_log), 1L,
               info = "exactly one Sheets API call for mapping_gaps")
  expect_equal(call_log[[1]]$sheet, "_sys_mapping_gaps",
               info = "default tab name SHALL match handbook tab-naming convention")
})

test_that("write_status_gsheet writes both '_sys_missing_master' AND '_sys_mapping_gaps' during parallel-write deprecation window", {
  skip_if_not_installed("googlesheets4")

  mock_ns <- asNamespace("googlesheets4")
  original_fn <- mock_ns$sheet_write
  unlockBinding("sheet_write", mock_ns)
  on.exit({
    assign("sheet_write", original_fn, envir = mock_ns)
    lockBinding("sheet_write", mock_ns)
  })

  call_log <- list()
  assign("sheet_write", function(data, ss, sheet, ...) {
    call_log[[length(call_log) + 1]] <<- list(ss = ss, sheet = sheet,
                                              nrows = nrow(data))
    invisible(NULL)
  }, envir = mock_ns)

  cfg <- list(sheet_id = "fake_id_parallel")

  result <- write_status_gsheet(
    cfg,
    missing_master = sample_df(),
    mapping_gaps = mk_mapping_gaps_sample()
  )

  expect_true(result[["missing_master"]])
  expect_true(result[["mapping_gaps"]])

  written_tabs <- vapply(call_log, function(c) c$sheet, character(1))
  # Both legacy and new tabs SHALL be written during deprecation window
  expect_setequal(written_tabs, c("_sys_missing_master", "_sys_mapping_gaps"))
})

# ==============================================================================
# Spec: write_status_gsheet handles missing googlesheets4 package gracefully
# ==============================================================================

test_that("write_status_gsheet warns and skips when googlesheets4 unavailable", {
  # Cannot reliably uninstall googlesheets4 in test, so verify the guard
  # path manually by inspecting the function source for the requireNamespace
  # check. This is a smoke test for code presence.
  src <- deparse(write_status_gsheet)
  expect_true(any(grepl("requireNamespace.*googlesheets4", src)))
})
