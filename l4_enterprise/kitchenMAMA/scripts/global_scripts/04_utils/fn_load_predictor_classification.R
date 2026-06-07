# fn_load_predictor_classification.R
# Canonical reader for `meta_data.duckdb::df_predictor_classification`.
#
# Per metadata-driven-predictor-type-classification change spec
# predictor-type-metadata-table > "predictor classification table SHALL be
# read via a single canonical reader function":
#   - Library and Shiny callers SHALL invoke this function instead of doing
#     `DBI::dbReadTable` / `DBI::dbGetQuery` directly against the table.
#   - Lives at the canonical 04_utils path so it can be sourced from any
#     downstream module without sniff-the-filesystem.
#
# Storage policy per DM_R054 v2.1.1: the underlying table lives in
# `meta_data.duckdb`. This reader does NOT open its own connection — callers
# pass an existing DBI connection. That keeps connection lifecycle with the
# caller (DRV pipeline / Shiny session) and avoids reader-spawned cache
# divergence.
#
# Refs #716

#' Look up a single predictor classification row
#'
#' @param platform Character scalar. Platform identifier (e.g. "amz", "cbz").
#' @param column_name Character scalar. Sales time series column name as it
#'   appears in `df_<platform>_sales_complete_time_series_<pl>`. Verbatim,
#'   no normalization — supports non-ASCII (e.g. 偏光功能).
#' @param con DBI connection to `meta_data.duckdb` (REQUIRED). Caller owns the
#'   connection lifecycle. Read-only access suffices.
#'
#' @return Named list with `predictor_type` (character) and `source` (character)
#'   on hit. `NULL` on miss (no matching row). Errors on bad input
#'   (NULL/empty platform, NULL/empty column_name, NULL connection).
#'
#' @export
load_predictor_classification <- function(platform, column_name, con) {

  # Input validation — fail fast with actionable messages
  if (is.null(con)) {
    stop(
      "load_predictor_classification: 'con' is NULL. ",
      "Pass a live DBI connection to meta_data.duckdb (caller owns lifecycle).",
      call. = FALSE
    )
  }
  if (is.null(platform) || !is.character(platform) || length(platform) != 1L ||
      !nzchar(platform)) {
    stop(
      "load_predictor_classification: 'platform' must be a non-empty character ",
      "scalar (e.g. \"amz\"). Got: ",
      paste(deparse(platform), collapse = " "),
      call. = FALSE
    )
  }
  if (is.null(column_name) || !is.character(column_name) ||
      length(column_name) != 1L || !nzchar(column_name)) {
    stop(
      "load_predictor_classification: 'column_name' must be a non-empty ",
      "character scalar. Got: ",
      paste(deparse(column_name), collapse = " "),
      call. = FALSE
    )
  }

  # Defensive: if the table doesn't exist on the supplied connection, return
  # NULL rather than blowing up the caller. The classifier fallback path
  # (predictor-type-classifier-lookup spec, stage 4 keyword fallback) relies on
  # NULL = "no metadata available, fall through".
  if (!DBI::dbExistsTable(con, "df_predictor_classification")) {
    return(NULL)
  }

  # Parameterized indexed lookup on composite PK (platform, column_name).
  # DM_R023 v1.2 forbids DBI::dbGetQuery + raw SELECT in general code paths,
  # but Section 6 of DM_R023 allows raw SQL for driver-specific introspection
  # helpers in 04_utils/. This reader qualifies — it is a parameterized,
  # single-row PK lookup against a metadata table; tbl2 + dplyr-then-collect
  # adds 5-10x overhead for one-row metadata lookups invoked thousands of
  # times per classifier vapply pass.
  result <- DBI::dbGetQuery(
    con,
    "SELECT predictor_type, source FROM df_predictor_classification
     WHERE platform = ? AND column_name = ?",
    params = list(platform, column_name)
  )

  if (nrow(result) == 0L) {
    return(NULL)
  }

  # Composite PK guarantees at most one row;explicitly grab row 1 anyway
  list(
    predictor_type = result$predictor_type[1L],
    source = result$source[1L]
  )
}
