#' Tests for per-field priority arbitration (MP155 field_class).
#'
#' Covers spec requirements from qef-gsheet-three-surface-redesign:
#'   - Field classification schema in product_master_fields.yaml
#'   - Per-field priority arbitration
#'   - Cross-company backwards compatibility
#'
#' Source: qef-gsheet-three-surface-redesign spectra change, task 2.6

library(testthat)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_arbitrate_product_master_conflicts.R"))

# ==============================================================================
# Test fixtures
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

with_strict_env <- function(value, expr) {
  old <- Sys.getenv("PRODUCT_MASTER_STRICT_CONFLICT", unset = NA_character_)
  on.exit({
    if (is.na(old)) Sys.unsetenv("PRODUCT_MASTER_STRICT_CONFLICT")
    else Sys.setenv(PRODUCT_MASTER_STRICT_CONFLICT = old)
  })
  Sys.setenv(PRODUCT_MASTER_STRICT_CONFLICT = as.character(value))
  force(expr)
}

# Helper: write a temp config with given field_class + priority_per_class
write_temp_config <- function(field_class = list(),
                              system_sourced_priority = NULL,
                              suggested_review_action = "route_to_status_gsheet") {
  tmp <- tempfile(fileext = ".yaml")
  cfg_lines <- c(
    "company_product_master:",
    "  critical:",
    "    - amz_asin",
    "    - product_line_id",
    "    - sku",
    "  non_critical:",
    "    - cost",
    "    - profit",
    "    - product_name",
    "    - brand",
    "    - status",
    "    - launch_date"
  )

  if (length(field_class) > 0) {
    cfg_lines <- c(cfg_lines, "  field_class:")
    for (f in names(field_class)) {
      cfg_lines <- c(cfg_lines, sprintf("    %s: %s", f, field_class[[f]]))
    }
  } else {
    cfg_lines <- c(cfg_lines, "  field_class: {}")
  }

  cfg_lines <- c(cfg_lines, "  priority_per_class:")
  if (!is.null(system_sourced_priority)) {
    cfg_lines <- c(cfg_lines, "    System-Sourced:")
    for (s in system_sourced_priority) {
      cfg_lines <- c(cfg_lines, sprintf("      - %s", s))
    }
  }
  cfg_lines <- c(cfg_lines,
    "    System-Suggested:",
    sprintf("      review_action: %s", suggested_review_action)
  )

  cfg_lines <- c(cfg_lines,
    "source_priority:",
    "  - gsheet_master",
    "  - gsheet_sku_asin",
    "  - keys_xlsx",
    "  - sku_asin_xlsx",
    "env_var_name: PRODUCT_MASTER_STRICT_CONFLICT",
    "schema_version: 2"
  )

  writeLines(cfg_lines, tmp)
  tmp
}

# ==============================================================================
# Spec: Per-field priority arbitration - System-Sourced reverses default
# ==============================================================================

test_that("System-Sourced field uses reversed priority (xlsx > gsheet)", {
  cfg_path <- write_temp_config(
    field_class = list(brand = "System-Sourced"),
    system_sourced_priority = c("keys_xlsx", "sku_asin_xlsx",
                                "gsheet_master", "gsheet_sku_asin")
  )
  on.exit(unlink(cfg_path))

  rows <- rbind(
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "GSHEET_BRAND", source_origin = "gsheet_master"),
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "XLSX_BRAND",   source_origin = "keys_xlsx")
  )

  with_strict_env(TRUE, {
    suppressMessages({
      result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
    })
  })

  expect_equal(nrow(result), 1)
  expect_equal(result$brand, "XLSX_BRAND",
               info = "System-Sourced brand should pick xlsx over gsheet")
})

# ==============================================================================
# Spec: System-Suggested field excluded from master, routed to queue
# ==============================================================================

test_that("System-Suggested field is excluded from master output", {
  cfg_path <- write_temp_config(
    field_class = list(brand = "System-Suggested")
  )
  on.exit(unlink(cfg_path))

  rows <- make_row("SKU1", "amz_us", "B0X01", "rpl",
                   brand = "AMAZON_REVIEW_BRAND",
                   source_origin = "gsheet_master")

  result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)

  expect_false("brand" %in% names(result),
               info = "System-Suggested column should be removed from master")
})

test_that("System-Suggested values appear in suggested_queue attribute", {
  cfg_path <- write_temp_config(
    field_class = list(brand = "System-Suggested"),
    suggested_review_action = "route_to_status_gsheet"
  )
  on.exit(unlink(cfg_path))

  rows <- rbind(
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "BRAND_A", source_origin = "gsheet_master"),
    make_row("SKU2", "amz_us", "B0X02", "rpl",
             brand = "BRAND_B", source_origin = "keys_xlsx")
  )

  result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
  queue <- attr(result, "system_suggested_queue")

  expect_false(is.null(queue), info = "queue attr should be set")
  expect_equal(nrow(queue), 2)
  expect_setequal(queue$value, c("BRAND_A", "BRAND_B"))
  expect_true(all(queue$review_action == "route_to_status_gsheet"))
  expect_true(all(c("sku", "marketplace", "field", "value",
                    "source_origin", "review_action") %in% names(queue)))
})

# ==============================================================================
# Spec: Backwards compatibility - field_class missing -> Human-Decided default
# ==============================================================================

test_that("Field without field_class behaves as Human-Decided (default priority)", {
  # Empty field_class config -> all fields use default source_priority
  cfg_path <- write_temp_config(field_class = list())
  on.exit(unlink(cfg_path))

  rows <- rbind(
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "GSHEET_BRAND", cost = 5.53, source_origin = "gsheet_master"),
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "XLSX_BRAND",   cost = 5.80, source_origin = "keys_xlsx")
  )

  with_strict_env(TRUE, {
    suppressMessages({
      result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
    })
  })

  expect_equal(result$brand, "GSHEET_BRAND",
               info = "Human-Decided default keeps gsheet > xlsx priority")
  expect_equal(result$cost, 5.53)
})

# ==============================================================================
# Spec: System-Sourced priority emits OVERRIDE log per field_class
# ==============================================================================

test_that("System-Sourced field emits OVERRIDE[System-Sourced] log on reversal", {
  cfg_path <- write_temp_config(
    field_class = list(brand = "System-Sourced"),
    system_sourced_priority = c("keys_xlsx", "sku_asin_xlsx",
                                "gsheet_master", "gsheet_sku_asin")
  )
  on.exit(unlink(cfg_path))

  rows <- rbind(
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "GSHEET_BRAND", source_origin = "gsheet_master"),
    make_row("SKU1", "amz_us", "B0X01", "rpl",
             brand = "XLSX_BRAND",   source_origin = "keys_xlsx")
  )

  with_strict_env(TRUE, {
    expect_message(
      arbitrate_product_master_conflicts(rows, config_path = cfg_path),
      "OVERRIDE\\[System-Sourced\\].*field=brand.*chose=keys_xlsx"
    )
  })
})

# ==============================================================================
# Spec: Singleton row with System-Suggested still routes to queue
# ==============================================================================

# ==============================================================================
# Track C: system_sourced_override_log attribute (Phase 2)
# Spec: amz-sales-derive-sku-asin "System-Sourced override surfaced in
#       anomalies output" (arbitrator side)
# ==============================================================================

test_that("system_sourced_override_log captures sales-vs-xlsx ASIN reversal", {
  cfg_path <- write_temp_config(
    field_class = list(amz_asin = "System-Sourced"),
    system_sourced_priority = c("sales", "catalogue", "keys_xlsx",
                                "sku_asin_xlsx", "gsheet_master",
                                "gsheet_sku_asin")
  )
  on.exit(unlink(cfg_path))

  rows <- rbind(
    make_row("SKU1", "amz_us", "B07XLSX001", "rpl",
             brand = "B", source_origin = "keys_xlsx"),
    make_row("SKU1", "amz_us", "B07SALES99", "rpl",
             brand = "B", source_origin = "sales")
  )

  with_strict_env(FALSE, {  # critical-field conflict expected; warn not stop
    suppressMessages(suppressWarnings({
      result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
    }))
  })

  log <- attr(result, "system_sourced_override_log")
  expect_false(is.null(log),
               info = "System-Sourced override should produce log attribute")
  expect_equal(nrow(log), 1)
  row <- log[1, ]
  expect_equal(row$sku, "SKU1")
  expect_equal(row$marketplace, "amz_us")
  expect_equal(row$field, "amz_asin")
  expect_equal(row$default_value, "B07XLSX001")
  expect_equal(row$default_source, "keys_xlsx")
  expect_equal(row$system_sourced_value, "B07SALES99")
  expect_equal(row$system_sourced_source, "sales")
  expect_equal(result$amz_asin, "B07SALES99")  # winner is sales
})

test_that("system_sourced_override_log records catalogue source when sales empty", {
  cfg_path <- write_temp_config(
    field_class = list(amz_asin = "System-Sourced"),
    system_sourced_priority = c("sales", "catalogue", "keys_xlsx",
                                "sku_asin_xlsx", "gsheet_master",
                                "gsheet_sku_asin")
  )
  on.exit(unlink(cfg_path))

  # Sales empty, catalogue has value, xlsx has different value
  rows <- rbind(
    make_row("SKU1", "amz_us", "B07XLSX001", "rpl",
             brand = "B", source_origin = "keys_xlsx"),
    make_row("SKU1", "amz_us", "B07CATALOG", "rpl",
             brand = "B", source_origin = "catalogue")
  )

  with_strict_env(FALSE, {
    suppressMessages(suppressWarnings({
      result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
    }))
  })

  log <- attr(result, "system_sourced_override_log")
  expect_false(is.null(log))
  expect_equal(nrow(log), 1)
  expect_equal(log$system_sourced_value, "B07CATALOG")
  expect_equal(log$system_sourced_source, "catalogue")
  expect_equal(result$amz_asin, "B07CATALOG")
})

test_that("system_sourced_override_log absent when no override happens", {
  cfg_path <- write_temp_config(
    field_class = list(amz_asin = "System-Sourced"),
    system_sourced_priority = c("sales", "catalogue", "keys_xlsx",
                                "sku_asin_xlsx", "gsheet_master",
                                "gsheet_sku_asin")
  )
  on.exit(unlink(cfg_path))

  # Both sources agree on ASIN — no override
  rows <- rbind(
    make_row("SKU1", "amz_us", "B07SAME", "rpl",
             brand = "B", source_origin = "keys_xlsx"),
    make_row("SKU1", "amz_us", "B07SAME", "rpl",
             brand = "B", source_origin = "sales")
  )

  with_strict_env(TRUE, {
    suppressMessages({
      result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
    })
  })

  log <- attr(result, "system_sourced_override_log")
  # log may be NULL or 0-row data.frame; either is acceptable
  expect_true(is.null(log) || nrow(log) == 0)
})

test_that("Singleton row with System-Suggested field routes value to queue", {
  cfg_path <- write_temp_config(
    field_class = list(brand = "System-Suggested")
  )
  on.exit(unlink(cfg_path))

  rows <- make_row("SKU1", "amz_us", "B0X01", "rpl",
                   brand = "SOLO_BRAND",
                   source_origin = "gsheet_master")

  result <- arbitrate_product_master_conflicts(rows, config_path = cfg_path)
  queue <- attr(result, "system_suggested_queue")

  expect_false(is.null(queue))
  expect_equal(nrow(queue), 1)
  expect_equal(queue$value, "SOLO_BRAND")
})
