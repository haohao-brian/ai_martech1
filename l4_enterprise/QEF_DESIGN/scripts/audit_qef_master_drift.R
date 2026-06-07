#!/usr/bin/env Rscript
# audit_qef_master_drift.R
#
# Quantify the difference between business-entered values (from the resolved
# Master Gsheet snapshot) and sales-derived values for fields that should be
# System-Sourced under MP155.
#
# Implements the QEF master drift audit requirement of
# qef-gsheet-three-surface-redesign Phase 2 (Decision 7).
#
# Output: data/audit_reports/qef_master_drift_<YYYY-MM>.csv
#
# Pull-only: this script does NOT send notifications, emails, or webhooks.
# Run on demand (e.g. quarterly) to produce a CSV the business team can
# inspect on its own schedule.
#
# Usage:
#   cd QEF_DESIGN
#   Rscript scripts/audit_qef_master_drift.R
#
# Spectra change: qef-gsheet-three-surface-redesign, task 3.4.

suppressMessages({
  library(DBI)
  library(duckdb)
  library(dplyr)
})

# ---------- Working directory check ----------
if (!file.exists("app_config.yaml")) {
  stop("Must run from QEF_DESIGN project root (app_config.yaml not found in cwd)")
}

# ---------- Configurable parameters ----------
output_dir <- "data/audit_reports"
output_path <- file.path(
  output_dir,
  sprintf("qef_master_drift_%s.csv", format(Sys.Date(), "%Y-%m"))
)
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Fields that SHOULD be sales-derived once Phase 2 is complete (per design
# Decision 6: Master Gsheet drops these columns and they come from sales).
# Audit measures drift even when Master still has them filled in (transition
# period).
audited_fields <- c("amz_asin", "product_name")

# ---------- Resolve company master (one-shot, read-only) ----------
cat("[audit_qef_master_drift] Resolving company product master ...\n")

repo_root <- local({
  d <- getwd()
  while (!file.exists(file.path(d, ".spectra.yaml")) && d != "/") d <- dirname(d)
  if (d == "/") stop("Could not locate .spectra.yaml in any parent of getwd()")
  d
})

source(file.path(repo_root, "shared/global_scripts/02_db_utils/tbl2/fn_tbl2.R"))
source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_resolve_company_product_master.R"))
source(file.path(repo_root, "shared/global_scripts/05_etl_utils/amz/fn_arbitrate_product_master_conflicts.R"))

# Helper defined here (before first use). Mirrors fn_resolve_company_product_master.R
# sources collection but additionally tags source_origin so downstream
# filtering/grouping can compute per-source drift values.
collect_source_candidates <- function(app_config, rawdata_dir) {
  src_funcs <- environment(resolve_company_product_master)
  manual_fns <- c("try_read_gsheet_master", "try_read_gsheet_sku_asin",
                  "try_read_keys_xlsx", "try_read_sku_asin_xlsx")
  trackC_fns <- c("try_read_sales", "try_read_catalogue")
  origin_map <- c(
    try_read_gsheet_master   = "gsheet_master",
    try_read_gsheet_sku_asin = "gsheet_sku_asin",
    try_read_keys_xlsx       = "keys_xlsx",
    try_read_sku_asin_xlsx   = "sku_asin_xlsx",
    try_read_sales           = "sales",
    try_read_catalogue       = "catalogue"
  )

  parts <- list()
  for (fn in manual_fns) {
    if (!exists(fn, envir = src_funcs, inherits = FALSE)) next
    df <- tryCatch(
      get(fn, envir = src_funcs)(app_config, rawdata_dir),
      error = function(e) {
        message(sprintf("[audit] source '%s' failed: %s", fn, conditionMessage(e)))
        NULL
      }
    )
    if (is.null(df) || nrow(df) == 0) next
    df$source_origin <- origin_map[[fn]]
    parts[[fn]] <- df
  }

  for (fn in trackC_fns) {
    if (!exists(fn, envir = src_funcs, inherits = FALSE)) next
    df <- tryCatch(
      get(fn, envir = src_funcs)(app_config, db_paths = NULL),
      error = function(e) {
        message(sprintf("[audit] source '%s' failed: %s", fn, conditionMessage(e)))
        NULL
      }
    )
    if (is.null(df) || nrow(df) == 0) next
    df$source_origin <- origin_map[[fn]]
    parts[[fn]] <- df
  }

  if (length(parts) == 0) {
    stop("No source rows could be collected. Check Gsheet/xlsx availability.")
  }
  do.call(dplyr::bind_rows, parts)
}

app_config <- yaml::read_yaml("app_config.yaml")
rawdata_dir <- file.path(getwd(), app_config$RAW_DATA_DIR)

# Track C: set db_path_list so try_read_sales / try_read_catalogue can find
# transformed_data.duckdb / raw_data.duckdb. Audit script runs in standalone
# mode (no autoinit), so we populate the canonical paths directly.
db_path_list <- list(
  raw_data         = file.path(getwd(), "data/local_data/raw_data.duckdb"),
  transformed_data = file.path(getwd(), "data/local_data/transformed_data.duckdb")
)
assign("db_path_list", db_path_list, envir = .GlobalEnv)

resolved <- tryCatch(
  resolve_company_product_master(app_config, rawdata_dir),
  error = function(e) {
    stop(
      "Failed to resolve company product master: ", conditionMessage(e),
      "\nThe audit needs Gsheet access. Verify .env has the right credentials."
    )
  }
)

# ---------- Compute per-source values for audited fields ----------
# resolved has one row per (sku, marketplace) with source_origin telling us
# the winning source. To compute drift, we need per-source values - so we
# re-collect raw rows by re-running the source readers from the resolver.
cat("[audit_qef_master_drift] Loading per-source candidate rows ...\n")

source_rows <- collect_source_candidates(app_config, rawdata_dir)

# ---------- Build drift report ----------
cat("[audit_qef_master_drift] Computing drift across audited fields ...\n")

drift_chunks <- list()
for (field in audited_fields) {
  if (!field %in% names(source_rows)) next
  per_sku <- source_rows %>%
    dplyr::filter(!is.na(.data[[field]]), nzchar(.data[[field]])) %>%
    dplyr::group_by(sku, marketplace) %>%
    dplyr::summarise(
      distinct_values = paste(unique(.data[[field]]), collapse = " | "),
      gsheet_value = .data[[field]][source_origin == "gsheet_master"][1],
      xlsx_value = .data[[field]][source_origin == "keys_xlsx"][1],
      sku_asin_value = .data[[field]][source_origin == "sku_asin_xlsx"][1],
      sales_value = .data[[field]][source_origin == "sales"][1],
      catalogue_value = .data[[field]][source_origin == "catalogue"][1],
      n_sources = dplyr::n(),
      .groups = "drop"
    )

  # Track C: include rows where sales/catalogue differs from xlsx even when
  # there is no Gsheet conflict (so business sees system-derived drift).
  per_sku <- per_sku %>%
    dplyr::filter(
      grepl("\\|", distinct_values) |
        (!is.na(sales_value) & !is.na(xlsx_value) & sales_value != xlsx_value) |
        (!is.na(catalogue_value) & !is.na(xlsx_value) & catalogue_value != xlsx_value)
    )

  if (nrow(per_sku) == 0) next

  drift_chunks[[length(drift_chunks) + 1]] <- per_sku %>%
    dplyr::mutate(
      field = field,
      delta_indicator = "DIFFERS",
      audit_date = format(Sys.Date(), "%Y-%m-%d")
    ) %>%
    dplyr::select(audit_date, sku, marketplace, field,
                  gsheet_value, xlsx_value, sku_asin_value,
                  sales_value, catalogue_value,
                  distinct_values, delta_indicator)
}

drift_report <- if (length(drift_chunks) == 0) {
  cat("[audit_qef_master_drift] No drift detected across audited fields.\n")
  data.frame(
    audit_date = character(0), sku = character(0), marketplace = character(0),
    field = character(0), gsheet_value = character(0), xlsx_value = character(0),
    sku_asin_value = character(0),
    sales_value = character(0), catalogue_value = character(0),
    distinct_values = character(0), delta_indicator = character(0),
    stringsAsFactors = FALSE
  )
} else {
  do.call(rbind, drift_chunks)
}

# ---------- Write CSV with UTF-8 BOM (Excel-compatible per DEV_R051) ----------
con <- file(output_path, "wb")
writeBin(charToRaw("\xef\xbb\xbf"), con)
close(con)
utils::write.table(drift_report, output_path, row.names = FALSE,
                   sep = ",", quote = TRUE, append = TRUE,
                   fileEncoding = "UTF-8")

cat(sprintf(
  "[audit_qef_master_drift] Wrote %d drift rows to %s\n",
  nrow(drift_report), output_path
))
cat("[audit_qef_master_drift] Done. (No notification sent - pull-only per MP155.)\n")

