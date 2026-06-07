# =============================================================================
# fn_D03_01_core.R — Geographic Sales Aggregation (World Market Map)
# GROUP: D03 (Positioning Analysis)
# CONSUMES: transformed_data.df_{platform}_sales___standardized
#           (platform-agnostic via column_spec parameter — Refs #671)
# PRODUCES: app_data.df_geo_sales_by_country, app_data.df_customer_country_map,
#           app_data.df_geo_sales_by_state, app_data.df_geo_sales_by_city
#           (country + state + city tables include cross-platform platform_id='all'
#           rollup rows — #417, MP055; city is US-only with graceful no-op when
#           source lacks ship_city — #418)
# DEPENDS_ON_ETL: {platform}_ETL_sales_2TS / _2TR
# Following: MP064, MP029, MP140, MP055, DM_R023 v1.2, DM_R025, DM_R066
# EXPORTS:
#   default_amz_column_spec()               — canonical amz source column mapping
#   run_D03_01(platform_id, config, column_spec) — per-platform aggregation
#   aggregate_D03_01_all_platforms(app_data) — platform_id='all' rollup (#417)
#
# Output column names (downstream UI dependency):
#   ship_country, ship_state, ship_city — these are CANONICAL output names
#   regardless of platform. The column_spec maps SOURCE column names → output
#   canonical names via SELECT <source> AS <canonical>. Downstream worldMap
#   module reads ship_country / ship_state unchanged.
# =============================================================================

#' Default column spec for amz platform (backward-compatible baseline).
#' @return Named list mapping output role → source column name.
#'
#' Roles:
#'   order_id : column with one row per order line (for COUNT DISTINCT order_count)
#'   revenue  : column with already-computed line revenue (unit_price × qty)
#'   country  : geo country dimension (output as ship_country)
#'   state    : geo state/province dimension (output as ship_state) — NULL to skip state aggregation
#'   quantity : line quantity column (for AVG quantity stat)
default_amz_column_spec <- function() {
  list(
    order_id = "amz_amazon_order_id",
    revenue  = "lineproduct_price",
    country  = "ship_country",
    state    = "ship_state",
    quantity = "quantity"
  )
}

run_D03_01 <- function(platform_id, config = NULL, column_spec = default_amz_column_spec()) {

  # Guard
  if (missing(platform_id) || is.null(platform_id) || !nzchar(platform_id)) {
    stop("platform_id is required")
  }

  # ---- column_spec validation (Refs #671) ----
  # Required keys: order_id, revenue, country (state + quantity optional)
  # Per MP163 progressive completeness: missing required → graceful no-op + WARN
  # (NOT stop()) so multi-platform orchestrator can continue with other platforms.
  required_spec_keys <- c("order_id", "revenue", "country")
  missing_spec_keys <- setdiff(required_spec_keys, names(column_spec))
  null_required <- vapply(required_spec_keys, function(k)
    is.null(column_spec[[k]]) || !nzchar(column_spec[[k]]),
    logical(1))
  if (length(missing_spec_keys) > 0 || any(null_required)) {
    gap <- c(missing_spec_keys, required_spec_keys[null_required])
    msg <- sprintf("[%s_D03_01] SKIP — column_spec missing/NULL required keys: %s",
                   platform_id, paste(unique(gap), collapse = ", "))
    message(msg)
    warning(msg, call. = FALSE)
    return(list(success = FALSE, platform_id = platform_id,
                rows_processed = 0L,
                execution_time_secs = 0,
                outputs = character(0),
                skipped_reason = "missing_required_column_spec"))
  }

  # ---- PART 1: INITIALIZE ----
  connection_created_transformed <- FALSE
  connection_created_app_data    <- FALSE
  state <- new.env(parent = emptyenv())
  state$error_occurred <- FALSE
  state$test_passed    <- FALSE
  state$rows_processed <- 0
  start_time <- Sys.time()

  message(sprintf("[%s_D03_01] START: Geographic Sales Aggregation", platform_id))

  # Source DB utility
  db_util_path <- file.path(GLOBAL_DIR, "02_db_utils", "duckdb", "fn_dbConnectDuckdb.R")
  if (file.exists(db_util_path)) source(db_util_path)

  # Open transformed_data (read)
  if (!exists("transformed_data") || !inherits(transformed_data, "DBIConnection") || !DBI::dbIsValid(transformed_data)) {
    transformed_data <- dbConnectDuckdb(db_path_list$transformed_data, read_only = TRUE)
    connection_created_transformed <- TRUE
  }

  # Open app_data (write)
  if (!exists("app_data") || !inherits(app_data, "DBIConnection") || !DBI::dbIsValid(app_data)) {
    app_data <- dbConnectDuckdb(db_path_list$app_data, read_only = FALSE)
    connection_created_app_data <- TRUE
  }

  # Cross-platform-safe write: preserve rows for other platforms (issue #374,
  # same pattern as fn_D01_02_core.R::write_platform_table fix from #371 blocker 13).
  # Without this, sequential per-platform calls (cbz then eby) cause silent data loss
  # because dbWriteTable(overwrite=TRUE) drops earlier platform rows.
  write_platform_table_d03 <- function(con, table_name, data, platform_value) {
    if (!DBI::dbExistsTable(con, table_name)) {
      DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
      return(invisible())
    }

    other_rows <- tryCatch({
      existing <- DBI::dbReadTable(con, table_name)
      if ("platform_id" %in% names(existing)) {
        as.data.frame(existing[existing$platform_id != platform_value, , drop = FALSE])
      } else {
        existing[FALSE, , drop = FALSE]
      }
    }, error = function(e) {
      message(sprintf("[%s] Could not read existing %s: %s", platform_value, table_name, e$message))
      NULL
    })

    DBI::dbRemoveTable(con, table_name)

    if (!is.null(other_rows) && nrow(other_rows) > 0) {
      merged <- tryCatch(
        dplyr::bind_rows(as.data.frame(other_rows), as.data.frame(data)),
        error = function(e) {
          message(sprintf(
            "[%s] WARNING: schema cannot be unified with existing rows for platforms (%s); dropping them. Re-run those platforms after this completes.",
            platform_value,
            paste(unique(other_rows$platform_id), collapse = ", ")
          ))
          as.data.frame(data)
        }
      )
      DBI::dbWriteTable(con, table_name, merged, overwrite = TRUE)
      message(sprintf("[%s] Merged: %d new + %d preserved from other platforms",
                      platform_value, nrow(data), nrow(other_rows)))
    } else {
      DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
    }
  }

  # ---- PART 2: MAIN ----
  tryCatch({
    # Validate source table
    source_table <- sprintf("df_%s_sales___standardized", platform_id)
    if (!DBI::dbExistsTable(transformed_data, source_table)) {
      stop(sprintf("Source table '%s' not found in transformed_data", source_table))
    }

    message(sprintf("[%s_D03_01] Reading from: %s", platform_id, source_table))

    # Build SQL identifier references from column_spec (Refs #671).
    # DBI::dbQuoteIdentifier handles backticks/double-quotes per DuckDB ANSI mode.
    # Note: aliases (AS ship_country / AS ship_state / AS total_revenue etc) stay
    # CANONICAL — downstream worldMap UI reads these names. Only the SOURCE column
    # being aggregated varies per platform.
    quote_id <- function(name) DBI::dbQuoteIdentifier(transformed_data, name)
    src_country  <- quote_id(column_spec$country)
    src_revenue  <- quote_id(column_spec$revenue)
    src_order_id <- quote_id(column_spec$order_id)
    src_quantity <- if (!is.null(column_spec$quantity) && nzchar(column_spec$quantity)) {
                       quote_id(column_spec$quantity)
                     } else { "NULL" }   # AVG(NULL) → NULL, downstream tolerates

    # Aggregate by country + product_line
    # Filter: Shipped orders only, non-NA country dim
    query <- sprintf("
      SELECT
        platform_id,
        COALESCE(product_line_id, 'unclassified') AS product_line_id_filter,
        %s AS ship_country,
        SUM(%s)                                              AS total_revenue,
        COUNT(DISTINCT %s)                                   AS order_count,
        COUNT(DISTINCT customer_id)                          AS customer_count,
        SUM(%s) / NULLIF(COUNT(DISTINCT %s), 0)              AS avg_order_value,
        AVG(%s)                                              AS avg_quantity
      FROM %s
      WHERE 1=1
        AND %s IS NOT NULL
        AND %s != ''
      GROUP BY platform_id, COALESCE(product_line_id, 'unclassified'), %s
    ", src_country, src_revenue, src_order_id,
       src_revenue, src_order_id, src_quantity,
       source_table, src_country, src_country, src_country)

    df_by_line <- DBI::dbGetQuery(transformed_data, query)
    message(sprintf("[%s_D03_01] Per product_line rows: %d", platform_id, nrow(df_by_line)))

    # Also aggregate 'all' product lines combined
    query_all <- sprintf("
      SELECT
        platform_id,
        'all' AS product_line_id_filter,
        %s AS ship_country,
        SUM(%s)                                              AS total_revenue,
        COUNT(DISTINCT %s)                                   AS order_count,
        COUNT(DISTINCT customer_id)                          AS customer_count,
        SUM(%s) / NULLIF(COUNT(DISTINCT %s), 0)              AS avg_order_value,
        AVG(%s)                                              AS avg_quantity
      FROM %s
      WHERE 1=1
        AND %s IS NOT NULL
        AND %s != ''
      GROUP BY platform_id, %s
    ", src_country, src_revenue, src_order_id,
       src_revenue, src_order_id, src_quantity,
       source_table, src_country, src_country, src_country)

    df_all <- DBI::dbGetQuery(transformed_data, query_all)
    message(sprintf("[%s_D03_01] 'all' product_line rows: %d", platform_id, nrow(df_all)))

    # Combine
    df_geo <- rbind(df_by_line, df_all)

    # Round numeric columns
    df_geo$total_revenue   <- round(df_geo$total_revenue, 2)
    df_geo$avg_order_value <- round(df_geo$avg_order_value, 2)
    df_geo$avg_quantity    <- round(df_geo$avg_quantity, 2)

    message(sprintf("[%s_D03_01] Total output rows: %d, countries: %d",
                    platform_id, nrow(df_geo), length(unique(df_geo$ship_country))))

    # Write to app_data — cross-platform safe (#374)
    write_platform_table_d03(app_data, "df_geo_sales_by_country", df_geo, platform_id)
    state$rows_processed <- nrow(df_geo)

    message(sprintf("[%s_D03_01] Written df_geo_sales_by_country to app_data (%d rows)",
                    platform_id, nrow(df_geo)))

    # ---- Customer → Country mapping (Issue #237) ----
    # Each customer's primary country (mode = most frequent)
    query_ccm <- sprintf("
      SELECT customer_id, platform_id, ship_country
      FROM (
        SELECT customer_id, platform_id, %s AS ship_country,
               ROW_NUMBER() OVER (PARTITION BY customer_id, platform_id
                                  ORDER BY COUNT(*) DESC) AS rn
        FROM %s
        WHERE 1=1
          AND %s IS NOT NULL AND %s != ''
        GROUP BY customer_id, platform_id, %s
      ) sub
      WHERE rn = 1
    ", src_country, source_table, src_country, src_country, src_country)

    df_ccm <- DBI::dbGetQuery(transformed_data, query_ccm)
    write_platform_table_d03(app_data, "df_customer_country_map", df_ccm, platform_id)
    message(sprintf("[%s_D03_01] Written df_customer_country_map (%d customers)",
                    platform_id, nrow(df_ccm)))

    # ---- State-level aggregation for US drill-down (Issue #240) ----
    # Refs #671: state aggregation is optional — column_spec$state == NULL → skip
    # (e.g. cbz Taiwan-only has no meaningful state dimension within US filter).
    # Per MP163: graceful skip with informative message, country aggregation still
    # written for downstream consumers.
    if (!is.null(column_spec$state) && nzchar(column_spec$state)) {
      src_state <- quote_id(column_spec$state)
      query_state <- sprintf("
        SELECT
          platform_id,
          COALESCE(product_line_id, 'unclassified') AS product_line_id_filter,
          %s AS ship_state,
          SUM(%s)                                              AS total_revenue,
          COUNT(DISTINCT %s)                                   AS order_count,
          COUNT(DISTINCT customer_id)                          AS customer_count,
          SUM(%s) / NULLIF(COUNT(DISTINCT %s), 0)              AS avg_order_value,
          AVG(%s)                                              AS avg_quantity
        FROM %s
        WHERE 1=1
          AND %s = 'US'
          AND %s IS NOT NULL AND %s != ''
        GROUP BY platform_id, COALESCE(product_line_id, 'unclassified'), %s
      ", src_state, src_revenue, src_order_id,
         src_revenue, src_order_id, src_quantity,
         source_table, src_country, src_state, src_state, src_state)

      df_state_by_line <- DBI::dbGetQuery(transformed_data, query_state)

      query_state_all <- sprintf("
        SELECT
          platform_id,
          'all' AS product_line_id_filter,
          %s AS ship_state,
          SUM(%s)                                              AS total_revenue,
          COUNT(DISTINCT %s)                                   AS order_count,
          COUNT(DISTINCT customer_id)                          AS customer_count,
          SUM(%s) / NULLIF(COUNT(DISTINCT %s), 0)              AS avg_order_value,
          AVG(%s)                                              AS avg_quantity
        FROM %s
        WHERE 1=1
          AND %s = 'US'
          AND %s IS NOT NULL AND %s != ''
        GROUP BY platform_id, %s
      ", src_state, src_revenue, src_order_id,
         src_revenue, src_order_id, src_quantity,
         source_table, src_country, src_state, src_state, src_state)

      df_state_all <- DBI::dbGetQuery(transformed_data, query_state_all)
      df_state <- rbind(df_state_by_line, df_state_all)
      df_state$total_revenue   <- round(df_state$total_revenue, 2)
      df_state$avg_order_value <- round(df_state$avg_order_value, 2)
      df_state$avg_quantity    <- round(df_state$avg_quantity, 2)

      write_platform_table_d03(app_data, "df_geo_sales_by_state", df_state, platform_id)
      message(sprintf("[%s_D03_01] Written df_geo_sales_by_state (%d rows, %d states)",
                      platform_id, nrow(df_state), length(unique(df_state$ship_state))))
    } else {
      message(sprintf(
        "[%s_D03_01] SKIP df_geo_sales_by_state — column_spec$state is NULL/missing (Refs #671 MP163 progressive completeness)",
        platform_id))
    }

    # ---- City-level aggregation for US drill-down (Issue #418) ----
    # Use canonical tbl2 + dplyr helper (DM_R023 v1.2). Graceful no-op if
    # ship_city column not present in source (ETL not yet propagating it).
    #
    # #418 verify-2 P2#4 fix: wrap city block in INNER tryCatch so that a
    # city-derivation failure (malformed source, transient lock, missing
    # required cols beyond ship_city) does NOT poison the whole D03_01 run
    # and fail the country/state writes that already succeeded.
    tryCatch({
      source_cols <- DBI::dbListFields(transformed_data, source_table)
      if ("ship_city" %in% source_cols) {
        city_helper_path <- file.path(GLOBAL_DIR, "04_utils",
                                      "fn_aggregate_geo_sales_by_city.R")
        if (file.exists(city_helper_path)) source(city_helper_path)
        df_city <- aggregate_geo_sales_by_city(transformed_data, source_table, platform_id)
        write_platform_table_d03(app_data, "df_geo_sales_by_city", df_city, platform_id)
        message(sprintf("[%s_D03_01] Written df_geo_sales_by_city (%d rows, %d cities)",
                        platform_id, nrow(df_city), length(unique(df_city$ship_city))))
      } else {
        message(sprintf(
          "[%s_D03_01] SKIP df_geo_sales_by_city — source '%s' missing ship_city column (ETL propagation pending #418)",
          platform_id, source_table))
      }
    }, error = function(city_err) {
      message(sprintf(
        "[%s_D03_01] WARN city derivation failed (country+state still ok): %s",
        platform_id, city_err$message))
    })

  }, error = function(e) {
    state$error_occurred <- TRUE
    message(sprintf("[%s_D03_01] MAIN: ERROR - %s", platform_id, e$message))
  })

  # ---- PART 3: TEST ----
  if (!state$error_occurred) {
    tryCatch({
      # Verify output exists
      if (!DBI::dbExistsTable(app_data, "df_geo_sales_by_country")) {
        stop("Output table df_geo_sales_by_country not found")
      }
      row_count <- DBI::dbGetQuery(app_data, "SELECT COUNT(*) AS n FROM df_geo_sales_by_country")$n
      if (row_count == 0) stop("Output table is empty")

      # Verify required columns
      cols <- DBI::dbListFields(app_data, "df_geo_sales_by_country")
      required <- c("platform_id", "product_line_id_filter", "ship_country",
                     "total_revenue", "order_count", "customer_count",
                     "avg_order_value", "avg_quantity")
      missing_cols <- setdiff(required, cols)
      if (length(missing_cols) > 0) {
        stop(sprintf("Missing columns: %s", paste(missing_cols, collapse = ", ")))
      }

      # Verify df_customer_country_map
      if (!DBI::dbExistsTable(app_data, "df_customer_country_map")) {
        stop("Output table df_customer_country_map not found")
      }
      ccm_count <- DBI::dbGetQuery(app_data, "SELECT COUNT(*) AS n FROM df_customer_country_map")$n

      # Verify df_geo_sales_by_state (conditional — column_spec$state may be NULL)
      state_aggregated <- !is.null(column_spec$state) && nzchar(column_spec$state)
      if (state_aggregated) {
        if (!DBI::dbExistsTable(app_data, "df_geo_sales_by_state")) {
          stop("Output table df_geo_sales_by_state not found (column_spec$state was set but state aggregation produced no table)")
        }
        state_count <- DBI::dbGetQuery(app_data, "SELECT COUNT(*) AS n FROM df_geo_sales_by_state")$n
      } else {
        state_count <- NA_integer_  # state skipped per column_spec
      }

      state$test_passed <- TRUE
      message(sprintf("[%s_D03_01] TEST: PASSED (geo=%d rows, ccm=%d customers, states=%s)",
                      platform_id, row_count, ccm_count,
                      ifelse(state_aggregated, paste0(state_count, " rows"), "skipped (no state col)")))
    }, error = function(e) {
      state$test_passed <- FALSE
      message(sprintf("[%s_D03_01] TEST: FAILED - %s", platform_id, e$message))
    })
  }

  # ---- PART 4: SUMMARIZE ----
  execution_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  outputs <- c("df_geo_sales_by_country", "df_customer_country_map")
  if (!is.null(column_spec$state) && nzchar(column_spec$state)) {
    outputs <- c(outputs, "df_geo_sales_by_state")
  }
  summary_report <- list(
    success           = !state$error_occurred && state$test_passed,
    platform_id       = platform_id,
    rows_processed    = state$rows_processed,
    execution_time_secs = execution_time,
    outputs           = outputs
  )
  message(sprintf("[%s_D03_01] SUMMARY: %s | Rows: %d | Time: %.2fs",
                  platform_id,
                  ifelse(summary_report$success, "SUCCESS", "FAILED"),
                  state$rows_processed, execution_time))

  # ---- PART 5: DEINITIALIZE ----
  if (connection_created_transformed && exists("transformed_data") && DBI::dbIsValid(transformed_data)) {
    DBI::dbDisconnect(transformed_data, shutdown = FALSE)
  }
  if (connection_created_app_data && exists("app_data") && DBI::dbIsValid(app_data)) {
    DBI::dbDisconnect(app_data, shutdown = FALSE)
  }

  summary_report
}

# =============================================================================
# aggregate_D03_01_all_platforms — compose platform_id='all' aggregate rows (#417)
# =============================================================================
# CALLED BY: all_D03_01.R orchestrator AFTER the per-platform run_D03_01() loop.
# WRITES  : platform_id='all' rows into df_geo_sales_by_country + df_geo_sales_by_state.
#
# Rationale (#417):
#   run_D03_01() is per-platform and does not produce cross-platform 'all'
#   rollup rows. UI components (e.g. worldMap.R) default to platform_id='all'
#   filter, which returned 0 rows -> blank world map tab. This helper fills
#   the gap per MP055 (Special Treatment of 'ALL' Category).
#
# Semantics of 'all' platform row:
#   total_revenue, order_count : SUM across platforms (exact — orders do not
#                                overlap across platforms).
#   customer_count             : SUM across platforms (UPPER BOUND for multi-
#                                platform companies — same customer_id may
#                                exist on amz + cbz. Precise de-duplication
#                                requires raw transformed_data access and is
#                                tracked as a follow-up issue).
#   avg_order_value            : SUM(total_revenue) / SUM(order_count).
#   avg_quantity               : order-count-weighted average.
#
# Idempotent: safe to re-run — existing platform_id='all' rows are dropped
# before the aggregation is re-inserted.
# =============================================================================
aggregate_D03_01_all_platforms <- function(app_data) {
  if (!inherits(app_data, "DBIConnection") || !DBI::dbIsValid(app_data)) {
    stop("aggregate_D03_01_all_platforms: app_data must be a valid DBI connection")
  }

  # Helper: aggregate one geo table into platform='all' rows.
  # `dim_cols` accepts a single dim col (country/state) or vector (state+city — #418).
  aggregate_one <- function(table_name, dim_cols) {
    if (!DBI::dbExistsTable(app_data, table_name)) {
      message(sprintf("[all_D03_01_agg] table %s not found; skipping", table_name))
      return(invisible(FALSE))
    }
    dim_csv <- paste(dim_cols, collapse = ", ")
    # Idempotent: drop existing platform_id='all' rows first.
    DBI::dbExecute(app_data, sprintf(
      "DELETE FROM %s WHERE platform_id = 'all'", table_name))
    # Re-aggregate from per-platform rows and INSERT SELECT.
    DBI::dbExecute(app_data, sprintf("
      INSERT INTO %1$s (platform_id, product_line_id_filter, %2$s,
                        total_revenue, order_count, customer_count,
                        avg_order_value, avg_quantity)
      SELECT
        'all' AS platform_id,
        product_line_id_filter,
        %2$s,
        ROUND(SUM(total_revenue), 2)                                           AS total_revenue,
        SUM(order_count)                                                       AS order_count,
        SUM(customer_count)                                                    AS customer_count,
        ROUND(SUM(total_revenue) / NULLIF(SUM(order_count), 0), 2)             AS avg_order_value,
        ROUND(SUM(avg_quantity * order_count) / NULLIF(SUM(order_count), 0), 2) AS avg_quantity
      FROM %1$s
      WHERE platform_id != 'all'
      GROUP BY product_line_id_filter, %2$s
    ", table_name, dim_csv))
    new_rows <- DBI::dbGetQuery(app_data, sprintf(
      "SELECT COUNT(*) AS n FROM %s WHERE platform_id = 'all'", table_name))$n
    message(sprintf("[all_D03_01_agg] %s: wrote %d 'all'-platform rows",
                    table_name, new_rows))
    invisible(TRUE)
  }

  tryCatch({
    aggregate_one("df_geo_sales_by_country", "ship_country")
    aggregate_one("df_geo_sales_by_state",   "ship_state")
    # #418 verify-2 HIGH#1 fix: city table has 2 dim cols (state + city).
    # Without this, default platform_id='all' UI filter shows blank city map
    # for any multi-platform company (caught by codex + regression + DA review).
    aggregate_one("df_geo_sales_by_city",    c("ship_state", "ship_city"))
    TRUE
  }, error = function(e) {
    message(sprintf("[all_D03_01_agg] ERROR: %s", e$message))
    FALSE
  })
}
