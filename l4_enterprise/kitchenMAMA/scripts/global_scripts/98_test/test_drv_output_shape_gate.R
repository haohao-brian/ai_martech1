#####
# test_drv_output_shape_gate.R - MP165 v1.3 DRV-layer Step 2 propagation gate tests
#
# Issue #668 / spectra change mp165-drv-output-shape-gate
#
# Tests the gate script at shared/global_scripts/23_deployment/drv_output_shape_gate.R
# against a synthetic in-memory DuckDB so the suite stays fast (< 5s) and
# independent of any company's app_data state.
#
# Coverage map:
#   2.11.1  L1 fail (table missing) -> critical fail in strict-mode
#   2.11.2  L2 fail (row count below threshold)
#   2.11.3  L3 fail (missing required predictor_type)
#   2.11.4  L3 skipped when not declared
#   2.11.5  Sentinel rows count toward L2 (MP163 compat)
#   2.11.6  sentinel_ratio_max opt-in warning fires
#   2.11.7  warn-mode: critical fail does NOT cause non-zero exit
#   2.11.8  strict_mode flag pre-sunset overrides calendar default
#   2.11.9  Calendar sunset date triggers strict-mode
#   2.11.10 Missing contracts file: warn-mode exits 0, strict-mode exits non-zero
#####

library(testthat)
library(DBI)
library(duckdb)
library(yaml)
library(dplyr)
library(dbplyr)

# Locate the gate script — try multiple candidate paths so the test works
# whether invoked from project root, from 98_test/, or via testthat
`%||%` <- function(a, b) if (!is.null(a)) a else b

resolve_gate_path <- function() {
  candidates <- c(
    "shared/global_scripts/23_deployment/drv_output_shape_gate.R",
    "../23_deployment/drv_output_shape_gate.R",
    "../../23_deployment/drv_output_shape_gate.R",
    file.path(dirname(testthat::test_path() %||% "."),
              "..", "23_deployment", "drv_output_shape_gate.R")
  )
  for (p in candidates) {
    if (!is.null(p) && file.exists(p)) return(normalizePath(p))
  }
  stop("Cannot locate drv_output_shape_gate.R. Tried: ",
       paste(candidates, collapse = " | "))
}
gate_script_path <- resolve_gate_path()

# Source as library (suppress CLI main() entry)
options(drv_gate.library_mode = TRUE)
source(gate_script_path, local = TRUE)


# ---------- helpers ----------

# Make a synthetic in-memory DuckDB pre-populated with a table the
# tests can target. Returns a `(con, db_path)` pair so callers can
# also re-open in read-only when the gate runs.
make_synthetic_db <- function(rows = NULL, predictor_types = NULL) {
  db_path <- tempfile(fileext = ".duckdb")
  con <- dbConnect(duckdb(), db_path)
  on.exit({}, add = TRUE)

  if (!is.null(rows)) {
    df <- data.frame(
      id = seq_len(rows),
      stringsAsFactors = FALSE
    )
    if (!is.null(predictor_types)) {
      df$predictor_type <- predictor_types
    }
    dbWriteTable(con, "df_amz_poisson_analysis_all", df)
  }
  list(con = con, db_path = db_path)
}

cleanup_db <- function(db) {
  try(dbDisconnect(db$con, shutdown = TRUE), silent = TRUE)
  try(unlink(db$db_path), silent = TRUE)
}

write_contracts <- function(content_list) {
  path <- tempfile(fileext = "_drv.yaml")
  yaml::write_yaml(content_list, path)
  path
}


# ---------- tests ----------

test_that("2.11.1 L1 fail: missing table is critical fail in strict-mode", {
  # GIVEN: contract declares a table that does not exist in the DB
  db <- make_synthetic_db()  # no tables
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          severity = "critical"
        )
      )
    )
  ))

  # WHEN: gate runs in strict-mode
  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  # THEN: critical L1 fail, exit non-zero
  expect_false(result$ok)
  expect_true(any(grepl("\\[L1\\]", result$messages)))
  expect_true(any(grepl("df_amz_poisson_analysis_all", result$messages)))
})


test_that("2.11.2 L2 fail: row count below threshold reports observed vs expected", {
  db <- make_synthetic_db(rows = 30L)
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 50L,
          severity = "critical"
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  expect_false(result$ok)
  expect_true(any(grepl("\\[L2\\]", result$messages)))
  # Failure message names table + observed + expected
  msg <- paste(result$messages, collapse = "\n")
  expect_match(msg, "df_amz_poisson_analysis_all")
  expect_match(msg, "30")
  expect_match(msg, ">= 50")
})


test_that("2.11.3 L3 fail: missing required predictor_type lists missing types", {
  db <- make_synthetic_db(
    rows = 189L,
    predictor_types = rep("time_feature", 189L)
  )
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          l3_predictor_types = list(
            required = c("time_feature", "comment_attribute", "product_attribute"),
            min_count_per_type = 1L
          ),
          severity = "critical"
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  expect_false(result$ok)
  expect_true(any(grepl("\\[L3\\]", result$messages)))
  msg <- paste(result$messages, collapse = "\n")
  expect_match(msg, "comment_attribute")
  expect_match(msg, "product_attribute")
})


test_that("2.11.4 L3 skipped when not declared in contract", {
  # Table without predictor_type column; contract doesn't declare L3
  db <- make_synthetic_db(rows = 5L)  # no predictor_type column
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          severity = "critical"
          # No l3_predictor_types declared
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  # Should PASS (no error on missing predictor_type column)
  expect_true(result$ok)
  # And no L3 messages at all
  l3_msgs <- grep("\\[L3\\]", result$messages, value = TRUE)
  expect_length(l3_msgs, 0)
})


test_that("2.11.5 Sentinel rows count toward L2 (MP163 compatibility)", {
  # 50 rows total: 30 unclassified + 20 real. L2 min = 40 -> should PASS.
  predictor_types <- c(
    rep("unclassified", 30L),
    rep("time_feature", 20L)
  )
  db <- make_synthetic_db(rows = 50L, predictor_types = predictor_types)
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 40L,
          severity = "critical"
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  # Gate must NOT filter out sentinel rows from L2 (per MP163)
  expect_true(result$ok)
})


test_that("2.11.6 sentinel_ratio_max opt-in warning fires but never hard-fails", {
  # 50 rows, 30 sentinel (ratio 0.6), threshold 0.5 -> warning expected
  predictor_types <- c(
    rep("unclassified", 30L),
    rep("time_feature", 20L)
  )
  db <- make_synthetic_db(rows = 50L, predictor_types = predictor_types)
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          sentinel_ratio_max = 0.5,
          severity = "critical"  # critical severity but warning still soft
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "strict",
    db_path = db$db_path
  )

  # Should still pass overall (sentinel warning is never hard-fail)
  expect_true(result$ok)
  msg <- paste(result$messages, collapse = "\n")
  expect_match(msg, "sentinel")
  expect_match(msg, "0\\.6|0\\.60")  # observed ratio
})


test_that("2.11.7 warn-mode: critical contract failure does NOT cause non-zero exit", {
  db <- make_synthetic_db()  # no tables
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          severity = "critical"
        )
      )
    )
  ))

  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "warn",
    db_path = db$db_path
  )

  # Gate reports the L1 fail but exits ok (mode=warn overrides severity)
  expect_true(result$ok)
  expect_true(any(grepl("\\[L1\\]", result$messages)))
})


test_that("2.11.8 strict_mode flag pre-sunset overrides calendar default", {
  db <- make_synthetic_db()  # no tables
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          severity = "critical"
        )
      )
    ),
    strict_mode = TRUE
  ))

  # mode=auto + pre-sunset date but strict_mode=TRUE in yaml
  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "auto",
    db_path = db$db_path,
    today = as.Date("2026-05-20")  # before 2026-06-13 sunset
  )

  # Per-company opt-in overrides calendar default
  expect_false(result$ok)
})


test_that("2.11.9 Calendar sunset date triggers strict-mode (auto mode)", {
  db <- make_synthetic_db()
  on.exit(cleanup_db(db), add = TRUE)

  contracts_path <- write_contracts(list(
    drv_contracts = list(
      amz = list(
        df_amz_poisson_analysis_all = list(
          l2_row_count_min = 1L,
          severity = "critical"
        )
      )
    )
  ))

  # Auto mode + post-sunset date -> strict
  result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = contracts_path,
    mode = "auto",
    db_path = db$db_path,
    today = as.Date("2026-06-14")  # after sunset
  )

  expect_false(result$ok)
})


test_that("2.11.10 Missing contracts file: warn-mode ok, strict-mode fails", {
  db <- make_synthetic_db()
  on.exit(cleanup_db(db), add = TRUE)

  nonexistent_path <- tempfile(fileext = "_drv.yaml")

  warn_result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = nonexistent_path,
    mode = "warn",
    db_path = db$db_path
  )
  expect_true(warn_result$ok)
  expect_true(any(grepl("WARNING.*no DRV contracts", warn_result$messages, ignore.case = TRUE)))

  strict_result <- run_drv_output_shape_gate(
    company = "TEST_CO",
    contracts_path = nonexistent_path,
    mode = "strict",
    db_path = db$db_path
  )
  expect_false(strict_result$ok)
  expect_true(any(grepl("ERROR.*required", strict_result$messages, ignore.case = TRUE)))
})
