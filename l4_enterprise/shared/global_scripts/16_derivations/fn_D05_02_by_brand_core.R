#####
# CONSUMES: df_<platform>_sales_complete_time_series_<pl>, df_<platform>_products___transformed (brand)
# PRODUCES: df_macro_monthly_summary_by_brand
# DEPENDS_ON_ETL: <platform>_ETL_sales_2TR, <platform>_ETL_products_2TR
# DEPENDS_ON_DRV: D05_01 (provides month axis convention)
#####

#' D05_02:Macro Monthly Summary by Brand
#'
#' @description Aggregates sales into monthly macro trends **per brand**, complementing
#' the existing `df_macro_monthly_summary` (which aggregates per platform × product_line).
#' Supports per-brand MoM/QoQ trend chart per #799.
#'
#' QoQ(quarterly):per-brand quarterly aggregation + QoQ growth rate(new vs MoM/YoY in D05_01).
#'
#' #803 alignment:output table also includes `is_partial_month` / `is_partial_quarter`
#' columns per same convention as D05_01 (see fn_D05_01_core.R aggregate_monthly).
#'
#' Per A8 (qef-market-segmentation-redesign discussion.md): brand-level aggregation
#' is universal across companies(MP161 universal scope — every company has brand
#' concept,即使 platform 不同)。Not company-scoped.
#'
#' @param app_connection DBI connection to app_data layer
#' @param platform_id Platform identifier (e.g. "amz" / "cbz" / "eby")
#' @param verbose Whether to message progress
#' @return data.frame with columns: year_month, year_quarter, brand, platform_id,
#'   total_revenue, order_count, active_customers, new_customers, avg_order_value,
#'   mom_revenue_pct, yoy_revenue_pct, qoq_revenue_pct, is_partial_month, is_partial_quarter
#'
#' @note SKELETON / SCAFFOLD ONLY — full implementation needs:
#'   1. Trace platform-specific product brand column(amz: `df_amz_products___transformed.brand`)
#'   2. Join sales with brand mapping
#'   3. Quarterly aggregation logic + QoQ calculation
#'   4. Wire into update_scripts/DRV/all_D05_02.R orchestrator
#'   5. Add Wiki Term-QoQ.md
#'   6. IC_P002 cross-co verify (5 companies)
#' Multi-day work — out of scope for this scaffold commit. See FUNNEL_MATH_CLUSTER_AUDIT.md.

D05_02_by_brand_core <- function(app_connection, platform_id, verbose = TRUE) {
  if (verbose) message(sprintf("[D05_02] Starting per-brand aggregation for %s", platform_id))

  # ─── SCAFFOLD (real implementation deferred per multi-day scope) ──────
  # Step 1: Load sales with brand context
  #   sales_with_brand <- tbl2(app_connection, sprintf("df_%s_sales_complete_time_series_all", platform_id)) %>%
  #     left_join(tbl2(app_connection, sprintf("df_%s_products___transformed", platform_id)) %>%
  #               select(product_id, brand), by = "product_id") %>%
  #     filter(!is.na(brand) & !is.na(payment_time) & !is.na(revenue)) %>%
  #     collect()
  #
  # Step 2: Aggregate per (brand × year_month) — same template as D05_01 aggregate_monthly
  #   brands <- unique(sales_with_brand$brand)
  #   monthly_result <- map_dfr(brands, function(b) {
  #     b_sales <- sales_with_brand %>% filter(brand == b)
  #     # ... same aggregation logic as D05_01:total_revenue, order_count, etc.
  #   })
  #
  # Step 3: Quarterly aggregation + QoQ
  #   quarterly_result <- monthly_result %>%
  #     mutate(year_quarter = paste0(substr(year_month, 1, 4), "-Q", ceiling(as.integer(substr(year_month, 6, 7)) / 3))) %>%
  #     group_by(brand, platform_id, year_quarter) %>%
  #     summarise(total_revenue = sum(total_revenue), order_count = sum(order_count),
  #               active_customers = sum(active_customers), new_customers = sum(new_customers),
  #               avg_order_value = total_revenue / order_count, .groups = "drop") %>%
  #     # QoQ: same logic as D05_01 MoM but on quarter axis
  #     ...
  #
  # Step 4: is_partial_month / is_partial_quarter columns per #803 convention
  #   today <- Sys.Date(); ... is_partial_month / is_partial_quarter ...
  #
  # Step 5: Write to app_data
  #   DBI::dbWriteTable(app_connection, "df_macro_monthly_summary_by_brand", monthly_result, overwrite = TRUE)
  #   DBI::dbWriteTable(app_connection, "df_macro_quarterly_summary_by_brand", quarterly_result, overwrite = TRUE)

  stop("D05_02_by_brand_core: NOT_IMPLEMENTED — scaffold only per multi-day scope (#799). ",
       "See FUNNEL_MATH_CLUSTER_AUDIT.md § Option A.2 for full implementation steps. ",
       "Implementer:next session 走 `/spectra-discuss qef-d05-by-brand-redesign` 先對齊 scope")
}

# By-category variant follows same pattern — categorize by product_line_id 上層分類
# (per QEF 12 PL grouped into 3 categories per向創 internal taxonomy)。Implementer
# 需先跟向創業務確認 category taxonomy(per #799 Q3 — 卡方 baseline 設計議題)。

D05_02_by_category_core <- function(app_connection, platform_id, verbose = TRUE) {
  stop("D05_02_by_category_core: NOT_IMPLEMENTED — scaffold only (#799). ",
       "Implementer:先跟向創業務確認 category taxonomy mapping(per A8 product_line → category)")
}
