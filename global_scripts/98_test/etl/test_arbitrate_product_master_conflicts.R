#' Tests for fn_arbitrate_product_master_conflicts
#'
#' Covers spec requirement "Hybrid conflict arbitration" scenarios:
#'   - Critical field conflict halts ETL
#'   - Non-critical field conflict resolves by priority
#'   - Strict mode opt-out (env var PRODUCT_MASTER_STRICT_CONFLICT=false)
#'
#' Source: qef-product-master-redesign spectra change, task 5.2

library(testthat)
library(dplyr)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_arbitrate_product_master_conflicts.R"))

# ==============================================================================
# Test Fixtures
# ==============================================================================

make_row <- function(sku, marketplace, asin, product_line_id, brand,
                    cost = NA_real_, profit = NA_real_,
                    product_name = NA_character_,
                    source_origin = "gsheet_master") {
  data.frame(
    sku = sku, marketplace = marketplace, amz_asin = asin,
    product_line_id = product_line_id, brand = brand,
    cost = cost, profit = profit, product_name = product_name,
    status = NA_character_, launch_date = NA_character_,
    source_origin = source_origin,
    stringsAsFactors = FALSE
  )
}

# Hook so tests can control env var without leaking across tests
with_strict_env <- function(value, expr) {
  old <- Sys.getenv("PRODUCT_MASTER_STRICT_CONFLICT", unset = NA_character_)
  on.exit({
    if (is.na(old)) Sys.unsetenv("PRODUCT_MASTER_STRICT_CONFLICT")
    else Sys.setenv(PRODUCT_MASTER_STRICT_CONFLICT = old)
  })
  Sys.setenv(PRODUCT_MASTER_STRICT_CONFLICT = as.character(value))
  force(expr)
}

# ==============================================================================
# Scenario: Critical field conflict halts ETL
# ==============================================================================

test_that("Critical field conflict halts ETL in strict mode", {
  rows <- rbind(
    make_row("F23A-BK-SK", "amz_us", "B0X01", "rpl", "ER00", source_origin = "gsheet_master"),
    make_row("F23A-BK-SK", "amz_us", "B0X02", "rpl", "ER00", source_origin = "keys_xlsx")
  )

  with_strict_env(TRUE, {
    expect_error(
      arbitrate_product_master_conflicts(rows),
      "CONFLICT.*sku=F23A-BK-SK.*marketplace=amz_us.*field=amz_asin"
    )
  })
})

# ==============================================================================
# Scenario: Non-critical field conflict resolves by priority
# ==============================================================================

test_that("Non-critical cost conflict resolves by source priority + logs OVERRIDE", {
  rows <- rbind(
    make_row("SKU1", "amz_us", "B0X01", "rpl", "ER00",
             cost = 5.53, source_origin = "gsheet_master"),
    make_row("SKU1", "amz_us", "B0X01", "rpl", "ER00",
             cost = 5.80, source_origin = "keys_xlsx")
  )

  with_strict_env(TRUE, {
    result <- expect_message(
      arbitrate_product_master_conflicts(rows),
      "OVERRIDE.*field=cost.*gsheet_master=5.53.*keys_xlsx=5.8.*chose=gsheet_master"
    )
  })

  expect_equal(nrow(result), 1)
  expect_equal(result$cost, 5.53)  # gsheet_master wins by priority
})

# ==============================================================================
# Scenario: Strict mode opt-out
# ==============================================================================

test_that("Strict mode opt-out: critical conflict logs warning + applies priority", {
  rows <- rbind(
    make_row("F23A-BK-SK", "amz_us", "B0X01", "rpl", "ER00", source_origin = "gsheet_master"),
    make_row("F23A-BK-SK", "amz_us", "B0X02", "rpl", "ER00", source_origin = "keys_xlsx")
  )

  with_strict_env(FALSE, {
    suppressMessages(
      expect_warning(
        result <- arbitrate_product_master_conflicts(rows),
        "CONFLICT"
      )
    )
    expect_equal(nrow(result), 1)
    # Track C Phase 3 (2026-04-26): amz_asin is System-Sourced; per
    # priority_per_class.System-Sourced (sales > catalogue > keys_xlsx >
    # sku_asin_xlsx > gsheet_master > gsheet_sku_asin), keys_xlsx wins
    # over gsheet_master for amz_asin specifically.
    expect_equal(result$amz_asin, "B0X02")  # keys_xlsx wins per System-Sourced
  })
})
