# ==============================================================================
# fn_backfill_asin_from_sku.R
#
# Backfill empty `asin` from ASIN-shaped `sku` (#472).
#
# Amazon Seller Central auto-fallback: when a seller has no merchant SKU for
# an active listing, the platform populates the `sku` column with the ASIN.
# Because the SKU is immutable for active listings with sales history (changing
# it requires rebuilding the listing and losing review/sales history), we
# accept the auto-fallback and merely fill the empty `asin` column.
#
# This is non-destructive (MP154-compliant): we never overwrite a non-empty
# `asin`, and we never modify `sku`. We only fill rows where:
#   - sku matches `^B0[A-Z0-9]{8}$` (Amazon ASIN shape)
#   - asin is NA or empty string
#
# Cross-company impact: companies without amz_mx (or amz_us) listings that
# trigger this fallback will see no rows match the predicate -> no-op.
#
# Tested by: 98_test/etl/test_amz_472_asin_normalization.R
# ==============================================================================

#' Backfill `asin` from ASIN-shaped `sku`
#'
#' @param dt A data.frame with at least `sku` and `asin` columns. Other columns
#'   are preserved untouched. Missing column(s) -> returns dt unchanged.
#' @param verbose Logical. If TRUE, emits one `message()` reporting the
#'   backfill count (suppressed when count == 0). Default FALSE.
#' @param return_audit Logical. If TRUE, returns a list with `dt` (modified
#'   data) and `audit_rows` (data.frame of fallback events with schema matching
#'   `df_amazon_sales_coverage_audit`). When FALSE (default), returns dt only
#'   for backward compatibility. Added per #473 to support MP163-aligned
#'   coverage audit integration: A' backfill silently absorbs ASIN-as-sku
#'   rows in production, so the educational note in `build_mapping_gaps`
#'   never fires; the audit table is the proper surfacing channel for
#'   business operators.
#'
#' @return When `return_audit=FALSE` (default): the data.frame with `asin`
#'   populated for matching rows. `sku` is never modified. Row count and
#'   column order are preserved.
#'
#'   When `return_audit=TRUE`: a list with two elements:
#'   - `dt`: the modified data.frame (same as default return)
#'   - `audit_rows`: data.frame with one row per backfill event, schema
#'     matching `validate_amz_sales_row_integrity` audit_rows for cross-table
#'     consumer compatibility (etl_source_file / source_row_index / reason /
#'     detected_via / observed_asin / observed_sku / detected_at). Empty
#'     data.frame (0 rows) when no rows match the backfill pattern.
#'
#' @export
backfill_asin_from_sku <- function(dt, verbose = FALSE, return_audit = FALSE) {
  # #473: empty audit row schema (matches df_amazon_sales_coverage_audit
  # schema established by fn_validate_amz_sales_row_integrity for #475)
  empty_audit <- data.frame(
    etl_source_file  = character(0),
    source_row_index = integer(0),
    reason           = character(0),
    detected_via     = character(0),
    observed_asin    = character(0),
    observed_sku     = character(0),
    detected_at      = as.POSIXct(character(0)),
    stringsAsFactors = FALSE
  )

  # Defensive: missing columns or empty -> no-op
  if (!all(c("sku", "asin") %in% names(dt))) {
    if (isTRUE(return_audit)) return(list(dt = dt, audit_rows = empty_audit))
    return(dt)
  }
  if (nrow(dt) == 0L) {
    if (isTRUE(return_audit)) return(list(dt = dt, audit_rows = empty_audit))
    return(dt)
  }

  # #472 verify finding (Logic P2): factor columns silently coerce to NA on
  # indexed assignment with non-level character values, violating MP154.
  # Cast to character defensively so the assignment below is well-typed.
  if (is.factor(dt$sku))  dt$sku  <- as.character(dt$sku)
  if (is.factor(dt$asin)) dt$asin <- as.character(dt$asin)

  asin_pattern <- "^B0[A-Z0-9]{8}$"
  needs_backfill <- !is.na(dt$sku) &
                    grepl(asin_pattern, dt$sku) &
                    (is.na(dt$asin) | !nzchar(dt$asin))

  n_backfill <- sum(needs_backfill)
  audit_rows <- empty_audit

  if (n_backfill > 0L) {
    backfill_indices <- which(needs_backfill)
    # Capture pre-backfill values (asin was NA/empty, sku was the ASIN-shaped value)
    observed_asin_pre <- dt$asin[backfill_indices]
    observed_sku_pre  <- dt$sku[backfill_indices]

    # Apply backfill
    dt$asin[needs_backfill] <- dt$sku[needs_backfill]

    # #473: build audit rows for MP163 coverage audit integration.
    # Schema mirrors fn_validate_amz_sales_row_integrity::empty_audit so a
    # single df_amazon_sales_coverage_audit table accepts both column-shift
    # (#475) and asin-as-sku-fallback (#473) reasons via reason / detected_via.
    audit_rows <- data.frame(
      etl_source_file  = rep(NA_character_, n_backfill),
      source_row_index = backfill_indices,
      reason           = "asin_as_sku_fallback",
      detected_via     = "asin_shaped_sku_pattern",
      observed_asin    = observed_asin_pre,
      observed_sku     = observed_sku_pre,
      detected_at      = Sys.time(),
      stringsAsFactors = FALSE
    )

    if (isTRUE(verbose)) {
      message(sprintf("Backfilled asin from ASIN-shaped sku for %d row(s)",
                      n_backfill))
    }
  }

  if (isTRUE(return_audit)) {
    return(list(dt = dt, audit_rows = audit_rows))
  }
  dt
}
