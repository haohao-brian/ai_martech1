---
date: "2025-11-13"
issue: "Data Consolidation to app_data.duckdb"
severity: "high"
status: "resolved"
author: "principle-product-manager"
---

**Note (2026-01-03)**: `consolidate_to_app_data.R` is archived; app-facing tables are now written directly by DRV (MP110, DM_R055). This report documents the legacy consolidation workflow.

# Data Consolidation Verification Report

## Problem Statement

User reported: "現在看不到" (can't see data now) - indicating that recently updated data was not visible in `app_data.duckdb`.

## Root Cause Analysis

### Issue 1: Database Path Mismatch
- **Consolidation script configured**: `/data/app_data/appdata.duckdb` (WRONG)
- **Actual database location**: `/data/app_data/app_data.duckdb` (CORRECT)
- **Result**: Consolidation script would create new empty database instead of updating existing one

### Issue 2: Table Naming Prefix Mismatch
- **Script searched for**: `df_` prefix tables
- **Actual tables in processed_data.duckdb**: `drv_` prefix tables
- **Result**: Script couldn't find any tables to copy

### Issue 3: Multiple Database Locations
- `/data/processed_data.duckdb` - Contains 3 tables with `drv_` prefix (last modified: 2025-11-13 01:29:36)
- `/data/local_data/processed_data.duckdb` - Contains 6 tables with `df_` prefix (last modified: 2025-11-13 12:58:03) ✅ Most recent
- `/data/app_data/app_data.duckdb` - Target for application consumption

## Solution Implemented

### 1. Fixed Consolidation Script Path

```r
# BEFORE
app_data_path <- ".../data/app_data/appdata.duckdb"

# AFTER
app_data_path <- ".../data/app_data/app_data.duckdb"
```

### 2. Updated Table Pattern Matching

```r
# BEFORE - only matched df_ prefix
df_pattern <- "^df_(cbz|eby|precision)_(product_features|time_series|poisson_analysis)"

# AFTER - matches both df_ and drv_ prefixes
drv_pattern <- "^(df|drv)_(cbz|eby|precision)_(product_features|time_series|poisson_analysis)"
```

### 3. Added Prefix Conversion Logic

```r
# Convert drv_ prefix to df_ prefix when copying to app_data
target_tbl <- sub("^drv_", "df_", tbl)
dbWriteTable(con_app, target_tbl, data, overwrite = TRUE)
```

## Consolidation Results

### Execution Summary
- **Execution Time**: 2025-11-13 17:06:17
- **Tables Copied**: 5 tables
- **Total Rows Synced**: 780 rows
- **Target Database**: `/data/app_data/app_data.duckdb`

### Source 1: `/data/processed_data.duckdb`
```
drv_precision_poisson_analysis → df_precision_poisson_analysis (0 rows)
drv_precision_time_series → df_precision_time_series (1 row)
```

### Source 2: `/data/local_data/processed_data.duckdb`
```
df_cbz_poisson_analysis (2 rows)
df_cbz_product_features (670 rows)
df_cbz_time_series (107 rows)
```

## Current State: app_data/app_data.duckdb

### Total Tables: 32 tables

### CBZ Poisson Analysis Tables (8 tables - ALL PRESENT ✅)
```
df_cbz_poisson_analysis          2 rows     (summary table)
df_cbz_poisson_analysis_alf    161 rows     (Aluminum Fin product line)
df_cbz_poisson_analysis_all  1,753 rows     (All product lines combined)
df_cbz_poisson_analysis_irf    185 rows     (Iron Fin product line)
df_cbz_poisson_analysis_pre    375 rows     (Precision product line)
df_cbz_poisson_analysis_rek    332 rows     (REK product line)
df_cbz_poisson_analysis_tur    480 rows     (Turbo product line)
df_cbz_poisson_analysis_wak    220 rows     (WAK product line)
```

### CBZ Feature Tables
```
df_cbz_product_features                    670 rows
df_cbz_time_series                         107 rows
```

### CBZ Time Series Tables (7 tables)
```
df_cbz_sales_complete_time_series       38,658 rows
df_cbz_sales_complete_time_series_alf    1,516 rows
df_cbz_sales_complete_time_series_irf   10,612 rows
df_cbz_sales_complete_time_series_pre    8,338 rows
df_cbz_sales_complete_time_series_rek   11,370 rows
df_cbz_sales_complete_time_series_tur   14,402 rows
df_cbz_sales_complete_time_series_wak    4,548 rows
df_cbz_time_frame_complete                 758 rows
```

### EBY Poisson Analysis Tables (7 tables)
```
df_eby_poisson_analysis_alf     30 rows
df_eby_poisson_analysis_all    180 rows
df_eby_poisson_analysis_irf     30 rows
df_eby_poisson_analysis_pre     30 rows
df_eby_poisson_analysis_rek     30 rows
df_eby_poisson_analysis_tur     30 rows
df_eby_poisson_analysis_wak     30 rows
```

### Precision/Position Tables
```
df_precision_features              6 rows
df_precision_poisson_analysis      0 rows
df_precision_time_series           1 row
df_position                      156 rows
```

### Customer/DNA Tables (2 tables)
```
df_customer_profile   127,762 rows
df_dna_by_customer    127,762 rows
```

### Metadata Tables
```
df_time_range  2 rows
```

## Data Quality Checks

### R120 Range Metadata Verification
All poisson analysis tables contain proper R120 range metadata columns:
- All CBZ poisson analysis tables have complete range metadata
- Proper tracking of predictor min/max/range values
- Analysis timestamps recorded

### Sample Data Verification
Spot-checked multiple tables:
- CBZ poisson analysis tables: Contains proper coefficients, p-values, significance flags
- Time series tables: Contains date ranges and sales data
- Product features: Contains product characteristics

## Timestamps
```
processed_data.duckdb:              2025-11-13 01:29:36
local_data/processed_data.duckdb:   2025-11-13 12:58:03 ✅ Most recent source
app_data/app_data.duckdb:           2025-11-13 17:06:18 ✅ Just updated
```

## Verification Status

✅ **CONSOLIDATION SUCCESSFUL**

- All 8 CBZ poisson analysis product line tables are present
- All time series data is available
- Customer/DNA data is intact
- R120 range metadata preserved
- Latest data from local_data/processed_data.duckdb successfully synced

## Next Steps

### Immediate
1. ✅ Fixed consolidation script path and logic
2. ✅ Re-ran consolidation - all data synced
3. ✅ Verified all CBZ product line tables present

### Recommended
1. Update any documentation referencing the old `appdata.duckdb` filename
2. Consider automating consolidation to run after ETL/DRV processes
3. Add validation checks to ensure app_data is always in sync

## Compliance
- **MP110**: Application Data Consolidation - IMPLEMENTED
- **R120**: Range metadata preserved in all analysis tables
- **Architecture**: Proper 5-tier separation maintained (0IM → 1ST → 2TR → 3DRV → 4APP)

## Files Modified
- `/scripts/update_scripts/DRV/consolidate_to_app_data.R`
  - Fixed target path: `appdata.duckdb` → `app_data.duckdb`
  - Updated pattern matching: `^df_` → `^(df|drv)_`
  - Added prefix conversion: `drv_` → `df_` when copying
  - Enhanced logging to track source/target table names

---
**Status**: RESOLVED
**Date**: 2025-11-13 17:06
**Verified By**: principle-product-manager
