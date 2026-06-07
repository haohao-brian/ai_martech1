#####
# Test: Contract primitive R helper library (MP165 backbone)
#
# Issue #599 / spectra change dashboard-presence-verification
#
# Locks contracts:
#   - assert_datatable_meaningful_rows: excludes placeholder rows
#     (Ideal/Rating/Revenue) before counting; QEF hsg 1-row Ideal case
#     SHALL fail when min_rows >= 5 with exclude_placeholders = TRUE
#   - assert_kpi_card_value: comparison operator dispatch (>=, >, ==)
#   - assert_plotly_has_data_points: trace count > 0
#   - assert_filter_dropdown_choices: choice count >= threshold
#   - All primitives surface (selector, expected, observed, severity)
#     on failure
#####

library(testthat)

# Source under test — robust path resolution (test_file may change cwd)
.locate_contracts <- function() {
  rel_candidates <- c(
    "shared/global_scripts/98_test/e2e/contracts/contracts.R",
    "scripts/global_scripts/98_test/e2e/contracts/contracts.R",
    "global_scripts/98_test/e2e/contracts/contracts.R",
    "98_test/e2e/contracts/contracts.R",
    "../e2e/contracts/contracts.R",
    "e2e/contracts/contracts.R"
  )
  hit <- Find(file.exists, rel_candidates)
  if (!is.null(hit)) return(hit)

  # Try anchoring to this script's location via sys.frames
  frames <- sys.frames()
  for (f in rev(frames)) {
    if (is.null(f)) next
    sf <- attr(f$ofile, "srcfile", exact = TRUE)
    path <- f$ofile %||% NULL
    if (!is.null(path) && nzchar(path) && file.exists(path)) {
      anchor <- normalizePath(dirname(path), mustWork = FALSE)
      cand <- file.path(anchor, "e2e/contracts/contracts.R")
      if (file.exists(cand)) return(cand)
    }
  }

  # Last resort: hardcoded absolute path under the canonical layout
  abs_paths <- c(
    "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/shared/global_scripts/98_test/e2e/contracts/contracts.R"
  )
  hit <- Find(file.exists, abs_paths)
  hit
}
`%||%` <- function(a, b) if (!is.null(a)) a else b
contracts_file <- .locate_contracts()
if (is.null(contracts_file)) {
  stop("Cannot locate contracts.R")
}
source(contracts_file)


# ---------- exclude_placeholder_rows (pure helper) ----------

test_that("exclude_placeholder_rows drops Ideal/Rating/Revenue by default", {
  df <- data.frame(
    brand = c("Ideal", "Rating", "Revenue", "GUNNAR", "Tifosi"),
    score = c(NA, NA, NA, 4.5, 3.8),
    stringsAsFactors = FALSE
  )
  out <- exclude_placeholder_rows(df, brand_col = "brand")
  expect_equal(nrow(out), 2L)
  expect_equal(sort(out$brand), c("GUNNAR", "Tifosi"))
})

test_that("exclude_placeholder_rows is no-op when brand_col missing", {
  df <- data.frame(value = 1:3)
  out <- exclude_placeholder_rows(df, brand_col = "brand")
  expect_equal(nrow(out), 3L)
})

test_that("exclude_placeholder_rows accepts custom placeholder list", {
  df <- data.frame(
    label = c("All", "ABC", "XYZ"),
    stringsAsFactors = FALSE
  )
  out <- exclude_placeholder_rows(df, brand_col = "label", placeholders = "All")
  expect_equal(nrow(out), 2L)
})

test_that("exclude_placeholder_rows drops 1-row Ideal-only (#595 hsg case)", {
  df <- data.frame(brand = "Ideal", value = NA, stringsAsFactors = FALSE)
  out <- exclude_placeholder_rows(df, brand_col = "brand")
  expect_equal(nrow(out), 0L)
})


# ---------- compare_value (op dispatch) ----------

test_that("compare_value dispatches >=, >, ==, <=, < correctly", {
  expect_true(compare_value(5, ">=", 5))
  expect_true(compare_value(6, ">=", 5))
  expect_false(compare_value(4, ">=", 5))
  expect_true(compare_value(6, ">", 5))
  expect_false(compare_value(5, ">", 5))
  expect_true(compare_value(5, "==", 5))
  expect_false(compare_value(5, "==", 6))
  expect_true(compare_value(4, "<=", 5))
  expect_true(compare_value(4, "<", 5))
  expect_false(compare_value(5, "<", 5))
})

test_that("compare_value rejects unknown operator", {
  expect_error(compare_value(5, "><", 4), "operator")
})

test_that("compare_value handles NA observed value as failure", {
  expect_false(compare_value(NA, ">=", 1))
})


# ---------- format_contract_failure ----------

test_that("format_contract_failure includes selector, expected, observed, severity", {
  msg <- format_contract_failure(
    selector = "position-position_table",
    expected = "rows >= 5 (excluding placeholders)",
    observed = "rows = 0 (5 placeholders excluded from 5 total)",
    severity = "critical"
  )
  expect_match(msg, "position-position_table")
  expect_match(msg, "rows >= 5")
  expect_match(msg, "rows = 0")
  expect_match(msg, "critical", ignore.case = TRUE)
})


# ---------- assert_datatable_meaningful_rows: data-frame fast path ----------

test_that("assert_datatable_meaningful_rows passes when meaningful rows >= min_rows", {
  df <- data.frame(
    brand = c("Ideal", "GUNNAR", "Tifosi", "ESS", "Wiley X", "Magpul", "FEISEDY"),
    score = c(NA, 4.5, 3.8, 4.2, 4.0, 3.9, 4.1),
    stringsAsFactors = FALSE
  )
  result <- check_datatable_meaningful_rows(
    data = df,
    min_rows = 5,
    exclude_placeholders = TRUE,
    brand_col = "brand"
  )
  expect_true(result$pass)
  expect_equal(result$observed, 6L)
})

test_that("assert_datatable_meaningful_rows fails on QEF hsg 1-row Ideal placeholder (#595 case)", {
  # Reproduces #595 reproduction state
  df <- data.frame(
    brand = "Ideal",
    score = NA_real_,
    stringsAsFactors = FALSE
  )
  result <- check_datatable_meaningful_rows(
    data = df,
    min_rows = 5,
    exclude_placeholders = TRUE,
    brand_col = "brand"
  )
  expect_false(result$pass)
  expect_equal(result$observed, 0L)
  expect_match(result$message, "0", fixed = TRUE)
})

test_that("legacy weak contract (min_rows=1, exclude_placeholders=FALSE) misclassifies hsg as success", {
  # This test documents the contract gap that #595 exposed.
  df <- data.frame(brand = "Ideal", stringsAsFactors = FALSE)
  legacy_result <- check_datatable_meaningful_rows(
    data = df,
    min_rows = 1,
    exclude_placeholders = FALSE,
    brand_col = "brand"
  )
  # Legacy weak contract PASSES (this is the bug)
  expect_true(legacy_result$pass)

  # Strong contract FAILS (this is the fix)
  strong_result <- check_datatable_meaningful_rows(
    data = df,
    min_rows = 5,
    exclude_placeholders = TRUE,
    brand_col = "brand"
  )
  expect_false(strong_result$pass)
})


# ---------- check_filter_dropdown_choices ----------

test_that("check_filter_dropdown_choices counts non-empty choices", {
  res <- check_filter_dropdown_choices(
    choices = c("hsg", "sfg", "sfo", "bys"),
    min_choices = 3
  )
  expect_true(res$pass)
  expect_equal(res$observed, 4L)
})

test_that("check_filter_dropdown_choices excludes empty-string sentinel", {
  # When app shows a placeholder hint like c("Select product line first" = "")
  # the value is "" — that should not count as a real choice.
  choices <- setNames("", "Select product line first")
  res <- check_filter_dropdown_choices(
    choices = choices,
    min_choices = 1
  )
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})

test_that("check_filter_dropdown_choices handles NULL", {
  res <- check_filter_dropdown_choices(
    choices = NULL,
    min_choices = 1
  )
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})


# ---------- check_plotly_has_data_points ----------

test_that("check_plotly_has_data_points counts non-empty traces", {
  # Mimic shinytest2's plotly trace structure: list of traces
  traces <- list(
    list(x = c(1, 2, 3), y = c(4, 5, 6)),
    list(x = c(7, 8), y = c(9, 10))
  )
  res <- check_plotly_has_data_points(traces = traces, min_traces = 1)
  expect_true(res$pass)
  expect_equal(res$observed, 2L)
})

test_that("check_plotly_has_data_points fails when all traces empty", {
  traces <- list(
    list(x = numeric(0), y = numeric(0)),
    list(x = NA, y = NA)
  )
  res <- check_plotly_has_data_points(traces = traces, min_traces = 1)
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})

test_that("check_plotly_has_data_points handles empty list", {
  res <- check_plotly_has_data_points(traces = list(), min_traces = 1)
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})


# ---------- check_chart_axis_non_empty ----------

test_that("check_chart_axis_non_empty passes when tick labels populated", {
  # Mimic Plotly axis tick labels
  ticks <- c("Jan", "Feb", "Mar", "Apr")
  res <- check_chart_axis_non_empty(tick_labels = ticks)
  expect_true(res$pass)
  expect_equal(res$observed, 4L)
})

test_that("check_chart_axis_non_empty fails on empty axis", {
  res <- check_chart_axis_non_empty(tick_labels = character(0))
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})

test_that("check_chart_axis_non_empty fails on all-empty-string ticks", {
  res <- check_chart_axis_non_empty(tick_labels = c("", "", ""))
  expect_false(res$pass)
  expect_equal(res$observed, 0L)
})


# ---------- check_kpi_card_value ----------

test_that("check_kpi_card_value compares numeric KPI", {
  res <- check_kpi_card_value(value = 71098, op = ">=", threshold = 1000)
  expect_true(res$pass)

  res <- check_kpi_card_value(value = 0, op = ">", threshold = 0)
  expect_false(res$pass)
})

test_that("check_kpi_card_value handles formatted numeric strings", {
  # MAMBA / QEF KPI cards often show "8,206,169" or "$43" or "77.3%"
  res <- check_kpi_card_value(value = "8,206,169", op = ">=", threshold = 1000)
  expect_true(res$pass)

  res <- check_kpi_card_value(value = "$43", op = ">", threshold = 10)
  expect_true(res$pass)

  res <- check_kpi_card_value(value = "77.3%", op = ">", threshold = 0)
  expect_true(res$pass)
})

test_that("check_kpi_card_value fails on NA / NULL / non-parseable", {
  expect_false(check_kpi_card_value(value = NA, op = ">=", threshold = 0)$pass)
  expect_false(check_kpi_card_value(value = NULL, op = ">=", threshold = 0)$pass)
  expect_false(check_kpi_card_value(value = "-", op = ">=", threshold = 0)$pass)
  expect_false(check_kpi_card_value(value = "loading...", op = ">=", threshold = 0)$pass)
})


# ---------- contract YAML schema validator ----------

test_that("validate_contract_yaml accepts well-formed contract YAML", {
  cfg <- list(
    company = "QEF_DESIGN",
    modules = list(
      brandedge = list(
        enabled = TRUE,
        sub_tabs = list(
          position = list(
            active_product_lines = c("hsg", "sfg"),
            contracts = list(
              list(
                selector = "position-position_table",
                assertion = "row_count_excluding_placeholders >= 5",
                severity = "critical"
              )
            )
          )
        )
      )
    )
  )
  res <- validate_contract_yaml(cfg)
  expect_true(res$valid)
})

test_that("validate_contract_yaml rejects missing company", {
  cfg <- list(modules = list())
  res <- validate_contract_yaml(cfg)
  expect_false(res$valid)
  expect_match(res$errors[[1]], "company", ignore.case = TRUE)
})

test_that("validate_contract_yaml rejects invalid severity", {
  cfg <- list(
    company = "QEF_DESIGN",
    modules = list(
      brandedge = list(
        enabled = TRUE,
        sub_tabs = list(
          position = list(
            active_product_lines = "hsg",
            contracts = list(
              list(
                selector = "x",
                assertion = "y",
                severity = "fatal"  # invalid; must be critical or warning
              )
            )
          )
        )
      )
    )
  )
  res <- validate_contract_yaml(cfg)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " "), "severity")
})


# ---------- soft_warn_mode forbidden (Hard fail discipline) ----------

test_that("contracts.R does not export a soft_warn_mode toggle", {
  # MP165 hard fail discipline: no global soft_warn_mode
  exports <- ls(envir = .GlobalEnv)
  expect_false("soft_warn_mode" %in% exports)
  expect_false("set_soft_warn_mode" %in% exports)
})


# =============================================================================
# Phase 1 — Predicate strictness fix (spectra change adaptive-dashboard-test-loop)
#
# Locks the 3 new primitives added per issue #653:
#   - check_no_error_text: scan UI text for Error:/[object Object]/<NA>/NaN
#   - check_no_hardcoded_english: detect i18n regressions
#   - check_kpi_no_error_placeholder: stricter KPI value check
# =============================================================================


# ---------- check_no_error_text ----------

test_that("check_no_error_text passes on clean Chinese-only text", {
  expect_true(check_no_error_text("關鍵因素分析")$pass)
})

test_that("check_no_error_text passes on clean numeric strings", {
  expect_true(check_no_error_text("12,220,098")$pass)
  expect_true(check_no_error_text("4.2%")$pass)
})

test_that("check_no_error_text fails on Error: [object Object] (F1 evidence)", {
  res <- check_no_error_text("Error: [object Object]")
  expect_false(res$pass)
  expect_true("Error:" %in% res$matched_patterns)
  expect_true("[object Object]" %in% res$matched_patterns)
})

test_that("check_no_error_text fails on <NA> in KPI text", {
  res <- check_no_error_text("Total: <NA>")
  expect_false(res$pass)
  expect_true("<NA>" %in% res$matched_patterns)
})

test_that("check_no_error_text fails on NaN displayed", {
  expect_false(check_no_error_text("Score: NaN")$pass)
})

test_that("check_no_error_text accepts custom patterns", {
  res <- check_no_error_text("Custom diagnostic banner", patterns = c("Custom"))
  expect_false(res$pass)
  expect_true("Custom" %in% res$matched_patterns)
})

test_that("check_no_error_text passes on NULL / empty / NA", {
  expect_true(check_no_error_text(NULL)$pass)
  expect_true(check_no_error_text("")$pass)
  expect_true(check_no_error_text(NA)$pass)
})

test_that("check_no_error_text handles character vector input", {
  res <- check_no_error_text(c("Healthy row 1", "Error: bad"))
  expect_false(res$pass)
  expect_true("Error:" %in% res$matched_patterns)
})


# ---------- check_no_hardcoded_english ----------

test_that("check_no_hardcoded_english passes on Chinese-only text", {
  expect_true(check_no_hardcoded_english("關鍵因素分析")$pass)
  expect_true(check_no_hardcoded_english("品牌定位策略建議")$pass)
})

test_that("check_no_hardcoded_english fails on 'Key Factor Evaluation' (F4 evidence)", {
  res <- check_no_hardcoded_english("Key Factor Evaluation")
  expect_false(res$pass)
  expect_true(length(res$found_phrases) >= 1L)
})

test_that("check_no_hardcoded_english fails on 'Importance-Performance Quadrant'", {
  res <- check_no_hardcoded_english("Importance-Performance Quadrant")
  expect_false(res$pass)
})

test_that("check_no_hardcoded_english fails on 'Product ranking based on ideal point distance' (F5 evidence)", {
  res <- check_no_hardcoded_english("Product ranking based on ideal point distance and key factor performance")
  expect_false(res$pass)
})

test_that("check_no_hardcoded_english allows DT controls by default", {
  expect_true(check_no_hardcoded_english("Show 10 entries Previous Next")$pass)
  expect_true(check_no_hardcoded_english("Search:")$pass)
})

test_that("check_no_hardcoded_english accepts custom whitelist", {
  res <- check_no_hardcoded_english(
    "Custom Component Name",
    allowed_phrases = c("Custom Component Name")
  )
  expect_true(res$pass)
})

test_that("check_no_hardcoded_english ignores short labels", {
  expect_true(check_no_hardcoded_english("ID Tag")$pass)  # both < 4 chars
})

test_that("check_no_hardcoded_english passes on NULL / empty", {
  expect_true(check_no_hardcoded_english(NULL)$pass)
  expect_true(check_no_hardcoded_english("")$pass)
})

test_that("check_no_hardcoded_english passes on mixed Chinese with DT control terms", {
  expect_true(check_no_hardcoded_english("顯示 10 entries 共 50 筆")$pass)
})


# ---------- check_kpi_no_error_placeholder ----------

test_that("check_kpi_no_error_placeholder passes on valid formatted values", {
  expect_true(check_kpi_no_error_placeholder("12,220,098")$pass)
  expect_true(check_kpi_no_error_placeholder("4.2%")$pass)
  expect_true(check_kpi_no_error_placeholder("$43")$pass)
  expect_true(check_kpi_no_error_placeholder("狩獵安全眼鏡")$pass)
})

test_that("check_kpi_no_error_placeholder fails on 'Error: [object Object]' (F1 evidence)", {
  expect_false(check_kpi_no_error_placeholder("Error: [object Object]")$pass)
})

test_that("check_kpi_no_error_placeholder fails on '--' / '-' (F2 evidence)", {
  expect_false(check_kpi_no_error_placeholder("--")$pass)
  expect_false(check_kpi_no_error_placeholder("-")$pass)
})

test_that("check_kpi_no_error_placeholder fails on N/A / loading...", {
  expect_false(check_kpi_no_error_placeholder("N/A")$pass)
  expect_false(check_kpi_no_error_placeholder("loading...")$pass)
  expect_false(check_kpi_no_error_placeholder("Loading...")$pass)
})

test_that("check_kpi_no_error_placeholder fails on NULL / empty / NA", {
  expect_false(check_kpi_no_error_placeholder(NULL)$pass)
  expect_false(check_kpi_no_error_placeholder("")$pass)
  expect_false(check_kpi_no_error_placeholder(NA)$pass)
})

test_that("check_kpi_no_error_placeholder reports observed value in failure", {
  res <- check_kpi_no_error_placeholder("Error: [object Object]")
  expect_match(res$observed, "Error", fixed = TRUE)
})


# ---------- Default constants exported ----------

test_that(".MP165_DEFAULT_ERROR_PATTERNS includes core defects", {
  expect_true("Error:" %in% .MP165_DEFAULT_ERROR_PATTERNS)
  expect_true("[object Object]" %in% .MP165_DEFAULT_ERROR_PATTERNS)
  expect_true("<NA>" %in% .MP165_DEFAULT_ERROR_PATTERNS)
  expect_true("NaN" %in% .MP165_DEFAULT_ERROR_PATTERNS)
})

test_that(".MP165_DEFAULT_ALLOWED_ENGLISH includes DT pagination controls", {
  expect_true("Show" %in% .MP165_DEFAULT_ALLOWED_ENGLISH)
  expect_true("Search" %in% .MP165_DEFAULT_ALLOWED_ENGLISH)
  expect_true("Previous" %in% .MP165_DEFAULT_ALLOWED_ENGLISH)
  expect_true("Next" %in% .MP165_DEFAULT_ALLOWED_ENGLISH)
})

test_that(".MP165_DEFAULT_PLACEHOLDERS unchanged by Phase 1 (Ideal/Rating/Revenue)", {
  expect_setequal(.MP165_DEFAULT_PLACEHOLDERS, c("Ideal", "Rating", "Revenue"))
})

test_that("contracts.R does not export skip_contract / disable_contract toggles", {
  exports <- ls(envir = .GlobalEnv)
  expect_false(any(grepl("^skip_contract|^disable_contract", exports)))
})
