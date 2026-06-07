# fn_make_skip_sentinel.R
# Build a 1-row MP163 sentinel for a skipped / empty product line.
#
# D04_02.R has several skip paths (time-series table not found / empty / no
# date column / no sales column / no valid observations / no non-zero sales).
# Each historically wrote an empty schema to processed_data and `next`'d — but
# NEVER added the product line to `all_results`, so the PL vanished from the
# merged `df_<platform>_poisson_analysis_all` entirely. The UI then listed the
# PL as a valid dropdown option (df_position has it) while the poisson query
# returned nothing → empty-df crash (#713) + user confusion.
#
# This helper builds a schema-complete 1-row sentinel so the skipped PL still
# appears in `_all` with an explicit "no input data" marker.
#
# Refs #715
# Principle: MP163 (progressive completeness — visible-gap sentinel, never
#            silently drop), MP029 (sentinel is an explicit gap marker, not
#            fabricated data).

#' Build a 1-row sentinel row for a skipped product line.
#'
#' @param pl Character. Product line id.
#' @param platform Character. Platform id (runtime-resolved, DM_R066).
#' @param reason Character. Human-readable skip reason (becomes display_name /
#'   display_description).
#' @param schema_template data.frame / tibble. A 0-row table carrying the exact
#'   output schema (column names + types). The returned row is schema-identical
#'   so it can be `bind_rows()`-ed with real per-predictor output.
#' @param drv_version Character. DRV version string for the analysis_version
#'   column.
#'
#' @return A 1-row data.frame schema-identical to `schema_template`, with
#'   `estimation_status = "not_estimable"`, `convergence = "skipped"`,
#'   `predictor = "__no_input_data__"`, `sample_size = 0L`, and unset columns
#'   as typed NA.
#'
#' @export
make_skip_sentinel <- function(pl, platform, reason, schema_template,
                               drv_version) {
  if (!is.data.frame(schema_template)) {
    stop("make_skip_sentinel: 'schema_template' must be a data.frame/tibble.")
  }

  sentinel_values <- tibble::tibble(
    product_line_id     = pl,
    platform            = platform,
    predictor           = "__no_input_data__",
    predictor_type      = "structural",
    data_type           = "sentinel",
    estimation_status   = "not_estimable",
    convergence         = "skipped",
    sample_size         = 0L,
    analysis_date       = Sys.Date(),
    analysis_version    = drv_version,
    computed_at         = Sys.time(),
    display_name        = reason,
    display_name_zh     = reason,
    display_category    = "sentinel",
    display_description = paste0("Product line skipped: ", reason)
  )

  # bind_rows against the 0-row template fills every other column with a
  # type-correct NA and guarantees schema identity for the downstream merge.
  dplyr::bind_rows(schema_template, sentinel_values)
}
