#' Tests for fn_detect_anomalies (anomalies / missing-master / drift outputs).
#'
#' Covers spec requirement from qef-gsheet-three-surface-redesign:
#'   - Anomaly detection with suggested_action
#'
#' Source: qef-gsheet-three-surface-redesign spectra change, task 2.6

library(testthat)

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  d
})

source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_detect_anomalies.R"))

# ==============================================================================
# Spec: every anomaly row has a non-empty suggested_action that mentions
#       Master Gsheet (Action-as-Input pattern, MP155 Decision 4)
# ==============================================================================

test_that("anomalies output: every row has suggested_action mentioning Master", {
  master <- data.frame(sku = "SKU1", marketplace = "amz_us",
                       stringsAsFactors = FALSE)
  attr(master, "system_suggested_queue") <- data.frame(
    sku = c("SKU1", "SKU2"),
    marketplace = c("amz_us", "amz_us"),
    field = c("brand", "brand"),
    value = c("X", "Y"),
    source_origin = c("gsheet_master", "keys_xlsx"),
    review_action = c("route_to_status_gsheet", "route_to_status_gsheet"),
    stringsAsFactors = FALSE
  )

  out <- detect_anomalies(master)
  anomalies <- out$anomalies

  expect_equal(nrow(anomalies), 2)
  expect_true(all(nzchar(anomalies$suggested_action)),
              info = "every anomaly row must have non-empty suggested_action")
  expect_true(all(grepl("Master Gsheet", anomalies$suggested_action)),
              info = "suggested_action must route business to Master Gsheet")
  expect_true(all(c("sku", "marketplace", "field", "suggested_value",
                    "source_origin", "review_action",
                    "suggested_action") %in% names(anomalies)))
})

test_that("anomalies output: empty when no system_suggested_queue attr", {
  master <- data.frame(sku = "SKU1", marketplace = "amz_us",
                       stringsAsFactors = FALSE)
  out <- detect_anomalies(master)
  expect_equal(nrow(out$anomalies), 0)
  expect_true("suggested_action" %in% names(out$anomalies))
})

# ==============================================================================
# Spec: missing-master output routes business to Master Gsheet
# ==============================================================================

test_that("missing-master row instructs business to add row to Master Gsheet", {
  master <- data.frame(sku = c("EXISTS_1", "EXISTS_2"),
                       marketplace = c("amz_us", "amz_us"),
                       stringsAsFactors = FALSE)

  sales_skus <- c("EXISTS_1", "EXISTS_2", "MISSING_A", "MISSING_B")
  out <- detect_anomalies(master, sales_skus = sales_skus)
  mm <- out$missing_master

  expect_equal(nrow(mm), 2)
  expect_setequal(mm$sku, c("MISSING_A", "MISSING_B"))
  expect_true(all(grepl("Master Gsheet", mm$suggested_action)),
              info = "missing-master suggested_action must route to Master Gsheet")
})

test_that("missing-master is NULL when sales_skus not supplied", {
  master <- data.frame(sku = "X", marketplace = "amz_us",
                       stringsAsFactors = FALSE)
  out <- detect_anomalies(master)
  expect_null(out$missing_master)
})

# ==============================================================================
# Spec: drift output detects value changes in System-Sourced fields
# ==============================================================================

test_that("drift detects value changes between current and prior master", {
  current <- data.frame(
    sku = c("S1", "S2"),
    marketplace = c("amz_us", "amz_us"),
    amz_asin = c("B_NEW", "B_SAME"),
    stringsAsFactors = FALSE
  )
  prior <- data.frame(
    sku = c("S1", "S2"),
    marketplace = c("amz_us", "amz_us"),
    amz_asin = c("B_OLD", "B_SAME"),
    stringsAsFactors = FALSE
  )

  out <- detect_anomalies(current, prior_master = prior,
                          drift_fields = "amz_asin")
  drift <- out$drift

  expect_equal(nrow(drift), 1)
  expect_equal(drift$sku, "S1")
  expect_equal(drift$prior_value, "B_OLD")
  expect_equal(drift$current_value, "B_NEW")
  expect_true(grepl("System-Sourced", drift$suggested_action))
})

test_that("drift returns empty when no changes exist", {
  current <- data.frame(sku = "S1", marketplace = "amz_us",
                        amz_asin = "B_SAME",
                        stringsAsFactors = FALSE)
  prior <- current
  out <- detect_anomalies(current, prior_master = prior,
                          drift_fields = "amz_asin")
  expect_equal(nrow(out$drift), 0)
})

test_that("drift is NULL when prior_master not supplied", {
  master <- data.frame(sku = "X", marketplace = "amz_us", amz_asin = "B",
                       stringsAsFactors = FALSE)
  out <- detect_anomalies(master)
  expect_null(out$drift)
})

# ==============================================================================
# Track C: anomalies output surfaces system_sourced_override_log
# Spec: amz-sales-derive-sku-asin "System-Sourced override surfaced in
#       anomalies output" (detect side)
# ==============================================================================

test_that("anomalies absorbs system_sourced_override_log into output rows", {
  master <- data.frame(sku = "SKU1", marketplace = "amz_us",
                       amz_asin = "B07SALES99",
                       stringsAsFactors = FALSE)
  attr(master, "system_sourced_override_log") <- data.frame(
    sku = "SKU1",
    marketplace = "amz_us",
    field = "amz_asin",
    default_value = "B07XLSX001",
    default_source = "keys_xlsx",
    system_sourced_value = "B07SALES99",
    system_sourced_source = "sales",
    stringsAsFactors = FALSE
  )

  out <- detect_anomalies(master)
  anomalies <- out$anomalies

  expect_true(nrow(anomalies) >= 1)
  override_rows <- anomalies[anomalies$review_action == "system_sourced_override", ]
  expect_equal(nrow(override_rows), 1)
  expect_equal(override_rows$sku, "SKU1")
  expect_equal(override_rows$field, "amz_asin")
  expect_equal(override_rows$suggested_value, "B07SALES99")
  expect_equal(override_rows$source_origin, "sales")

  # suggested_action MUST mention BOTH values + route business
  action <- override_rows$suggested_action
  expect_true(grepl("B07SALES99", action),
              info = "must mention sales-observed ASIN")
  expect_true(grepl("B07XLSX001", action),
              info = "must mention xlsx-recorded ASIN")
  expect_true(grepl("KEYS|xlsx|Master Gsheet", action, ignore.case = TRUE),
              info = "must route business to KEYS.xlsx or Master Gsheet")
})

test_that("anomalies merges suggested_queue + override_log when both present", {
  master <- data.frame(sku = "SKU1", marketplace = "amz_us",
                       amz_asin = "B07SALES99",
                       stringsAsFactors = FALSE)
  attr(master, "system_suggested_queue") <- data.frame(
    sku = "SKU1", marketplace = "amz_us",
    field = "brand", value = "GUESS_BRAND",
    source_origin = "gsheet_master",
    review_action = "route_to_status_gsheet",
    stringsAsFactors = FALSE
  )
  attr(master, "system_sourced_override_log") <- data.frame(
    sku = "SKU1", marketplace = "amz_us",
    field = "amz_asin",
    default_value = "B07XLSX001", default_source = "keys_xlsx",
    system_sourced_value = "B07SALES99", system_sourced_source = "sales",
    stringsAsFactors = FALSE
  )

  out <- detect_anomalies(master)
  expect_equal(nrow(out$anomalies), 2,
               info = "one row from suggested_queue + one from override_log")
  expect_setequal(out$anomalies$review_action,
                  c("route_to_status_gsheet", "system_sourced_override"))
})

test_that("anomalies empty when neither queue nor override_log present", {
  master <- data.frame(sku = "S1", marketplace = "amz_us", amz_asin = "B",
                       stringsAsFactors = FALSE)
  out <- detect_anomalies(master)
  expect_equal(nrow(out$anomalies), 0)
  expect_true(all(c("sku", "marketplace", "field", "suggested_value",
                    "source_origin", "review_action",
                    "suggested_action") %in% names(out$anomalies)))
})

test_that("anomalies override row uses 'sales' or 'catalogue' as source_origin", {
  master <- data.frame(sku = c("S1", "S2"),
                       marketplace = c("amz_us", "amz_us"),
                       amz_asin = c("B07S1", "B07S2"),
                       stringsAsFactors = FALSE)
  attr(master, "system_sourced_override_log") <- data.frame(
    sku = c("S1", "S2"),
    marketplace = c("amz_us", "amz_us"),
    field = c("amz_asin", "amz_asin"),
    default_value = c("B07X1", "B07X2"),
    default_source = c("keys_xlsx", "keys_xlsx"),
    system_sourced_value = c("B07S1", "B07S2"),
    system_sourced_source = c("sales", "catalogue"),
    stringsAsFactors = FALSE
  )

  out <- detect_anomalies(master)
  override_rows <- out$anomalies[out$anomalies$review_action == "system_sourced_override", ]
  expect_equal(nrow(override_rows), 2)
  expect_setequal(override_rows$source_origin, c("sales", "catalogue"))
})

# ==============================================================================
# Spec: amz-mapping-gap-detection (Issue #471)
# build_mapping_gaps and detect_anomalies(sales_sku_asin_pairs=...) integration.
# ==============================================================================

# Helper: build a resolved_master with optional sku_product_line_map attr.
mk_master <- function(rows, pl_map = NULL) {
  master <- if (length(rows) == 0) {
    data.frame(sku = character(0), marketplace = character(0),
               amz_asin = character(0), product_line_id = character(0),
               stringsAsFactors = FALSE)
  } else {
    do.call(rbind, lapply(rows, function(r) {
      data.frame(sku = r$sku %||% NA_character_,
                 marketplace = r$marketplace %||% "amz_us",
                 amz_asin = r$amz_asin %||% NA_character_,
                 product_line_id = r$product_line_id %||% NA_character_,
                 stringsAsFactors = FALSE)
    }))
  }
  if (!is.null(pl_map)) attr(master, "sku_product_line_map") <- pl_map
  master
}

`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("build_mapping_gaps emits no_master_row for SKU in sales but missing from master", {
  master <- mk_master(list(list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg")))
  sales <- data.frame(sku = c("S001", "S999_MISSING"),
                      amz_asin = c("B07A", "B07Z"),
                      marketplace = c("amz_us", "amz_us"),
                      stringsAsFactors = FALSE)

  gaps <- build_mapping_gaps(master, sales,
                             sku_pl_map = data.frame(sku = "S001",
                                                     product_line_id = "sfg",
                                                     stringsAsFactors = FALSE))

  miss_row <- gaps[gaps$gap_type == "no_master_row" & !is.na(gaps$sku) & gaps$sku == "S999_MISSING", ]
  expect_equal(nrow(miss_row), 1L)
  expect_match(miss_row$suggested_action, "KEYS\\.xlsx")
  expect_match(miss_row$suggested_action, "Master Gsheet")
})

test_that("build_mapping_gaps emits no_master_row for ASIN in sales but no master row (SKU NA)", {
  master <- mk_master(list(list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg")))
  sales <- data.frame(sku = c(NA_character_),
                      amz_asin = c("B07ORPHAN"),
                      marketplace = c("amz_us"),
                      stringsAsFactors = FALSE)

  gaps <- build_mapping_gaps(master, sales,
                             sku_pl_map = data.frame(sku = "S001",
                                                     product_line_id = "sfg",
                                                     stringsAsFactors = FALSE))

  asin_row <- gaps[gaps$gap_type == "no_master_row" & is.na(gaps$sku) & gaps$amz_asin == "B07ORPHAN", ]
  expect_equal(nrow(asin_row), 1L)
  expect_match(asin_row$suggested_action, "Amazon listing")
})

test_that("build_mapping_gaps emits no_product_line when master row exists but product_line_id NA", {
  master <- mk_master(list(
    list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg"),
    list(sku = "S002_NO_LINE", amz_asin = "B07B", product_line_id = NA_character_)
  ))
  sales <- data.frame(sku = c("S001", "S002_NO_LINE"),
                      amz_asin = c("B07A", "B07B"),
                      marketplace = c("amz_us", "amz_us"),
                      stringsAsFactors = FALSE)

  gaps <- build_mapping_gaps(master, sales,
                             sku_pl_map = data.frame(sku = "S001",
                                                     product_line_id = "sfg",
                                                     stringsAsFactors = FALSE))

  npl_row <- gaps[gaps$gap_type == "no_product_line" & gaps$sku == "S002_NO_LINE", ]
  expect_equal(nrow(npl_row), 1L)
  expect_match(npl_row$suggested_action, "coding sheet")
  expect_match(npl_row$suggested_action, "product_line")
})

test_that("build_mapping_gaps skips no_product_line check when sku_pl_map is empty", {
  master <- mk_master(list(
    list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg"),
    list(sku = "S002", amz_asin = "B07B", product_line_id = NA_character_)
  ))
  sales <- data.frame(sku = c("S001", "S002"),
                      amz_asin = c("B07A", "B07B"),
                      marketplace = c("amz_us", "amz_us"),
                      stringsAsFactors = FALSE)
  # sku_pl_map is empty (catalogue degraded per #469)
  empty_map <- data.frame(sku = character(0), product_line_id = character(0),
                          stringsAsFactors = FALSE)

  expect_message(
    gaps <- build_mapping_gaps(master, sales, sku_pl_map = empty_map),
    regexp = "catalogue empty.*no_product_line.*#469"
  )

  # All rows in master + sales OK -> no gaps at all (no_master_row not triggered, no_product_line skipped)
  expect_equal(nrow(gaps), 0L)
})

test_that("detect_anomalies output list lacks mapping_gaps element when sales_sku_asin_pairs is NULL", {
  master <- mk_master(list(list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg")))

  out <- detect_anomalies(master, sales_skus = "S001")

  expect_true(is.null(out$mapping_gaps),
              info = "Backwards compat: callers without sales_sku_asin_pairs see no mapping_gaps element")
})

test_that("detect_anomalies output list contains mapping_gaps when sales_sku_asin_pairs is supplied", {
  master <- mk_master(
    list(list(sku = "S001", amz_asin = "B07A", product_line_id = "sfg")),
    pl_map = data.frame(sku = "S001", product_line_id = "sfg",
                        stringsAsFactors = FALSE)
  )
  sales_pairs <- data.frame(sku = c("S001", "S_NEW"),
                            amz_asin = c("B07A", "B07X"),
                            marketplace = c("amz_us", "amz_us"),
                            stringsAsFactors = FALSE)

  out <- detect_anomalies(master, sales_sku_asin_pairs = sales_pairs)

  expect_false(is.null(out$mapping_gaps),
               info = "Caller passing sales_sku_asin_pairs sees mapping_gaps element")
  expect_true(is.data.frame(out$mapping_gaps))
  # S_NEW is in sales but not in master -> 1 no_master_row gap
  expect_equal(nrow(out$mapping_gaps), 1L)
  expect_equal(out$mapping_gaps$gap_type, "no_master_row")
  expect_equal(out$mapping_gaps$sku, "S_NEW")
})

# ==============================================================================
# Spec: Mapping gaps cap to bound Status Gsheet writes (Requirement)
# build_mapping_gaps must cap at top N by sales_volume + emit summary row.
# ==============================================================================

test_that("build_mapping_gaps does not cap when row count <= cap (87 rows)", {
  master <- mk_master(list(list(sku = "S_KEEP", amz_asin = "B07KEEP",
                                product_line_id = "sfg")))
  # Generate 87 missing-from-master SKUs; all should land in gaps
  n <- 87L
  sales <- data.frame(
    sku = sprintf("S_MISS_%03d", seq_len(n)),
    amz_asin = sprintf("B07MISS%03d", seq_len(n)),
    marketplace = rep("amz_us", n),
    sales_volume = seq_len(n) * 10,
    stringsAsFactors = FALSE
  )

  gaps <- build_mapping_gaps(master, sales,
                             sku_pl_map = data.frame(sku = "S_KEEP",
                                                     product_line_id = "sfg",
                                                     stringsAsFactors = FALSE),
                             cap = 500L)

  expect_equal(nrow(gaps), n,
               info = "below cap -> all rows preserved, no summary row appended")
  expect_false(any(grepl("\\.\\.\\.and .* more", gaps$gap_type)),
               info = "no '...and N more' summary row when below cap")
})

test_that("build_mapping_gaps caps at top 500 by sales_volume desc + summary row (1247 rows)", {
  master <- mk_master(list(list(sku = "S_KEEP", amz_asin = "B07KEEP",
                                product_line_id = "sfg")))
  n <- 1247L
  # sales_volume = i so highest volume is at the end (S_MISS_1247)
  sales <- data.frame(
    sku = sprintf("S_MISS_%04d", seq_len(n)),
    amz_asin = sprintf("B07MISS%04d", seq_len(n)),
    marketplace = rep("amz_us", n),
    sales_volume = seq_len(n),
    stringsAsFactors = FALSE
  )

  gaps <- build_mapping_gaps(master, sales,
                             sku_pl_map = data.frame(sku = "S_KEEP",
                                                     product_line_id = "sfg",
                                                     stringsAsFactors = FALSE),
                             cap = 500L)

  # 500 capped rows + 1 summary row = 501 total
  expect_equal(nrow(gaps), 501L,
               info = "exceeds cap -> exactly 500 capped + 1 summary row")

  # Summary row: last row, NA identifiers, "...and 747 more" literal in gap_type
  summary_rows <- gaps[gaps$gap_type == "...and 747 more", , drop = FALSE]
  expect_equal(nrow(summary_rows), 1L,
               info = "exactly one summary row with literal '...and 747 more'")
  expect_true(is.na(summary_rows$sku))
  expect_true(is.na(summary_rows$amz_asin))
  expect_true(is.na(summary_rows$marketplace))
  expect_match(summary_rows$suggested_action, "audit|CSV|download|完整",
               info = "suggested_action SHALL describe how to obtain full set")

  # The 500 retained rows are the highest sales_volume:
  # i.e., S_MISS_0748..S_MISS_1247 (the top-volume 500)
  capped_rows <- gaps[gaps$gap_type == "no_master_row", , drop = FALSE]
  expect_equal(nrow(capped_rows), 500L)
  # Lowest sku in capped set should be S_MISS_0748
  expect_setequal(capped_rows$sku, sprintf("S_MISS_%04d", 748:1247))
})

