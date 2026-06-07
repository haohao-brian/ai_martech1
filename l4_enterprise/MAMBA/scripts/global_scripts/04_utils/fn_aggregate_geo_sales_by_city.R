#' Aggregate Geographic Sales by US City (D03_01 helper for #418)
#'
#' Performs city-level aggregation of transformed sales data, restricted to
#' US ship_country and non-empty ship_state / ship_city. Produces both per-PL
#' rows (product_line_id_filter = product_line_id) and cross-PL rollup rows
#' (product_line_id_filter = 'all'), mirroring the existing `query_state`
#' pattern in `fn_D03_01_core.R`.
#'
#' @param con A DBI connection to transformed_data.duckdb (read-only)
#' @param source_table Name of the platform's transformed sales table
#'   (e.g. "df_amz_sales___standardized" or "df_amz_sales___transformed")
#' @param platform_id Platform code (e.g. "amz", "eby"). Used to stamp the
#'   `platform_id` column in output rows.
#'
#' @return data.frame with columns:
#'   - platform_id, product_line_id_filter, ship_state, ship_city
#'   - total_revenue, order_count, customer_count, avg_order_value, avg_quantity
#'   Each (state, city) combination appears once per active product_line plus
#'   one rollup row with product_line_id_filter = "all".
#'
#' Following:
#' - DM_R023 v1.2: Universal DBI Approach (tbl2 + dplyr, no raw SQL)
#' - MP064: ETL-Derivation separation (this helper is DRV-side aggregation)
#' - MP029: No fake data — operates on real transformed_data
#' - #418: US city drill-down extension (Plan-tier, 2026-05-04)
aggregate_geo_sales_by_city <- function(con, source_table, platform_id) {
  `%>%` <- magrittr::`%>%`

  if (!inherits(con, "DBIConnection") || !DBI::dbIsValid(con)) {
    stop("aggregate_geo_sales_by_city: 'con' must be a valid DBIConnection")
  }
  if (!is.character(source_table) || !nzchar(source_table)) {
    stop("aggregate_geo_sales_by_city: 'source_table' must be a non-empty string")
  }
  if (!is.character(platform_id) || !nzchar(platform_id)) {
    stop("aggregate_geo_sales_by_city: 'platform_id' must be a non-empty string")
  }
  if (!DBI::dbExistsTable(con, source_table)) {
    stop(sprintf("aggregate_geo_sales_by_city: source table '%s' not found", source_table))
  }

  # #418 verify-2 P2#7 fix: explicit required-column validation. Without this,
  # missing columns surface as cryptic dplyr errors deep inside lazy-eval,
  # and the outer D03_01 run aborts. Surface a clear error early so caller
  # (fn_D03_01_core.R) can decide whether to fall back gracefully.
  required_cols <- c("order_status", "ship_country", "ship_state", "ship_city",
                     "lineproduct_price", "amazon_order_id", "customer_id",
                     "quantity", "product_line_id", "platform_id")
  available_cols <- DBI::dbListFields(con, source_table)
  missing_cols <- setdiff(required_cols, available_cols)
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "aggregate_geo_sales_by_city: source '%s' missing required column(s): %s. Available: %s",
      source_table,
      paste(missing_cols, collapse = ", "),
      paste(available_cols, collapse = ", ")
    ))
  }

  base_lazy <- tbl2(con, source_table) %>%
    dplyr::filter(
      .data$order_status == "Shipped",
      .data$ship_country == "US",
      !is.na(.data$ship_state),
      .data$ship_state != "",
      !is.na(.data$ship_city),
      .data$ship_city != ""
    )

  # Per-PL aggregation
  per_pl <- base_lazy %>%
    dplyr::mutate(
      product_line_id_filter = dplyr::coalesce(.data$product_line_id, "unclassified")
    ) %>%
    dplyr::group_by(
      .data$platform_id,
      .data$product_line_id_filter,
      .data$ship_state,
      .data$ship_city
    ) %>%
    dplyr::summarise(
      total_revenue   = sum(.data$lineproduct_price, na.rm = TRUE),
      order_count     = dplyr::n_distinct(.data$amazon_order_id),
      customer_count  = dplyr::n_distinct(.data$customer_id),
      avg_order_value = sum(.data$lineproduct_price, na.rm = TRUE) /
                          dplyr::n_distinct(.data$amazon_order_id),
      avg_quantity    = mean(.data$quantity, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::collect()

  # Cross-PL rollup ('all')
  all_pl <- base_lazy %>%
    dplyr::group_by(
      .data$platform_id,
      .data$ship_state,
      .data$ship_city
    ) %>%
    dplyr::summarise(
      total_revenue   = sum(.data$lineproduct_price, na.rm = TRUE),
      order_count     = dplyr::n_distinct(.data$amazon_order_id),
      customer_count  = dplyr::n_distinct(.data$customer_id),
      avg_order_value = sum(.data$lineproduct_price, na.rm = TRUE) /
                          dplyr::n_distinct(.data$amazon_order_id),
      avg_quantity    = mean(.data$quantity, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::collect() %>%
    dplyr::mutate(product_line_id_filter = "all") %>%
    dplyr::select(
      "platform_id", "product_line_id_filter",
      "ship_state", "ship_city",
      "total_revenue", "order_count", "customer_count",
      "avg_order_value", "avg_quantity"
    )

  out <- dplyr::bind_rows(
    dplyr::select(
      per_pl,
      "platform_id", "product_line_id_filter",
      "ship_state", "ship_city",
      "total_revenue", "order_count", "customer_count",
      "avg_order_value", "avg_quantity"
    ),
    all_pl
  )

  # Trust caller's platform_id arg (input contract per DM_R028 + #418 plan).
  # Source table already filters one platform; we still stamp explicitly to
  # protect against rows where platform_id col was upstream-NULL.
  out$platform_id <- platform_id

  # Round consistent with existing run_D03_01() state output (#240, #348)
  out$total_revenue   <- round(out$total_revenue, 2)
  out$avg_order_value <- round(out$avg_order_value, 2)
  out$avg_quantity    <- round(out$avg_quantity, 2)

  as.data.frame(out)
}
