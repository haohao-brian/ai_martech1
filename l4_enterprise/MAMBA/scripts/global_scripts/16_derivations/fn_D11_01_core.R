#' @title D11_01 Core: Product Master UNION across product_attributes raw tables
#' @description
#' Consumes 10 per-PL canonical raw tables (df_amz_product_attributes_*___raw)
#' produced by the bridge orchestrator (#569) and emits a unified
#' `app_data.df_product_master` via UNION ALL across all available PL slices.
#'
#' This closes the bridge → DRV gap from #573. Per #543, the bridge layer
#' (raw_data) is QEF-scoped product_attributes for amz; DRV consumption was
#' missing. D11 is the canonical aggregation layer.
#'
#' @principles
#' - MP064: ETL-Derivation Separation (DRV phase, not ETL)
#' - MP102 v1.3: Bridge layer feeds canonical raw, DRV unifies
#' - MP161: company_product_extension scope (sister bridge concept)
#' - MP163: Progressive Completeness — surface what we have, gaps tracked separately by D01_07 audit
#' - DM_R023 v1.2: Universal DBI (tbl2 + dplyr — no raw SELECT)
#' - DEV_R038: Core Function + Platform Wrapper Pattern
#'
#' @section Schema:
#' Output `df_product_master` columns:
#'   - product_line_id  (derived from source table name, e.g. 'blb', 'sgf')
#'   - asin             (canonical key)
#'   - sku
#'   - brand
#'   - product_name
#'   - is_competitor
#'   - sales_platform
#'   - rank
#'   - review_rating
#'   - review_count
#'   - product_line_source  (provenance: source table name)
#'
#' @section Sentinel handling:
#' v1 (this implementation): emits **only classified ASINs** (those present in
#' product_attributes raw tables). Unmapped ASIN detection (those in sales but
#' not in product_attributes) is deferred to a follow-up D11_02 that
#' LEFT JOINs against sales/transformed and emits 'unclassified' sentinel rows.
#' Existing D01_07 audit already tracks per-PL coverage gaps via CSV reporting.
#'
#' @param platform_id Character. Platform to process (default 'amz' — only platform with product_attributes bridges)
#' @param config Optional configuration list
#' @return List with execution summary
#' @export
run_D11_01 <- function(platform_id = "amz",
                       config = NULL) {

  start_time <- Sys.time()
  test_passed <- FALSE

  if (!exists("db_path_list", inherits = TRUE)) {
    stop("db_path_list not initialized. Run autoinit() first.")
  }

  message("D11_01: Starting product_master UNION derivation")
  message(sprintf("D11_01: platform_id = %s", platform_id))

  # ===========================================================================
  # PART 1: Discover product_attributes raw tables
  # ===========================================================================

  raw_data <- dbConnectDuckdb(db_path_list$raw_data, read_only = TRUE)
  on.exit(try(DBI::dbDisconnect(raw_data), silent = TRUE), add = TRUE)

  all_tables <- DBI::dbListTables(raw_data)
  pa_tables <- grep(
    sprintf("^df_%s_product_attributes_.*___raw$", platform_id),
    all_tables, value = TRUE
  )

  if (length(pa_tables) == 0L) {
    stop(sprintf(
      "D11_01: No %s_product_attributes raw tables found. Run amz_ETL_product_attributes_0IM first.",
      platform_id
    ))
  }

  message(sprintf("D11_01: Found %d product_attributes raw tables: %s",
                  length(pa_tables), paste(sort(pa_tables), collapse = ", ")))

  # Canonical fields all 10 PL raw tables share (intersection per spec)
  canonical_cols <- c(
    "asin", "sku", "brand", "product_name", "is_competitor",
    "sales_platform", "rank", "review_rating", "review_count"
  )

  # ===========================================================================
  # PART 2: UNION ALL across PL raw tables, project canonical fields
  # ===========================================================================

  union_dfs <- list()
  for (tbl_name in sort(pa_tables)) {
    pl_id <- sub(
      sprintf("^df_%s_product_attributes_(.*?)___raw$", platform_id),
      "\\1", tbl_name
    )

    # Verify canonical cols exist (defense; should always pass since bridges
    # generate canonical fields uniformly)
    cols <- DBI::dbListFields(raw_data, tbl_name)
    missing <- setdiff(canonical_cols, cols)
    if (length(missing) > 0) {
      warning(sprintf(
        "D11_01: %s missing canonical cols [%s] — projecting NA for those.",
        tbl_name, paste(missing, collapse = ", ")
      ))
    }

    # Per DM_R023 v1.2: tbl2 + dplyr (no raw SELECT)
    df <- tbl2(raw_data, tbl_name) |>
      dplyr::select(dplyr::any_of(canonical_cols)) |>
      dplyr::collect()

    # Fill missing canonical cols with NA (defensive — should not happen)
    for (col in missing) df[[col]] <- NA

    df$product_line_id <- pl_id
    df$product_line_source <- tbl_name

    union_dfs[[pl_id]] <- df
    message(sprintf("D11_01:   %s (PL=%s): %d rows", tbl_name, pl_id, nrow(df)))
  }

  # data.table::rbindlist or base rbind — base is fine since 10 small dfs
  product_master <- do.call(rbind, c(union_dfs, list(make.row.names = FALSE)))

  message(sprintf("D11_01: UNION total: %d rows across %d product lines",
                  nrow(product_master), length(union_dfs)))

  # ===========================================================================
  # PART 3: Reorder columns; canonical key first, provenance last
  # ===========================================================================

  ordered_cols <- c(
    "product_line_id", "asin", "sku", "brand", "product_name",
    "is_competitor", "sales_platform", "rank", "review_rating", "review_count",
    "product_line_source"
  )
  product_master <- product_master[, intersect(ordered_cols, colnames(product_master)), drop = FALSE]

  # ===========================================================================
  # PART 4: Write to app_data.df_product_master (overwrite — idempotent)
  # ===========================================================================

  app_data <- dbConnectDuckdb(db_path_list$app_data, read_only = FALSE)
  on.exit(try(DBI::dbDisconnect(app_data), silent = TRUE), add = TRUE)

  target_table <- "df_product_master"
  DBI::dbWriteTable(app_data, target_table, product_master, overwrite = TRUE)

  # ===========================================================================
  # PART 5: TEST
  # ===========================================================================

  written_n <- as.integer(DBI::dbGetQuery(app_data,
    sprintf("SELECT COUNT(*) AS n FROM \"%s\"", target_table))$n)

  test_passed <- (written_n == nrow(product_master)) && (written_n > 0)

  if (!test_passed) {
    warning(sprintf("D11_01: TEST FAILED — wrote %d but expected %d (or zero)",
                    written_n, nrow(product_master)))
  }

  duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  list(
    platform_id = platform_id,
    n_product_lines = length(union_dfs),
    n_rows = nrow(product_master),
    target_table = target_table,
    test_passed = test_passed,
    duration_secs = duration,
    sources = sort(pa_tables)
  )
}
