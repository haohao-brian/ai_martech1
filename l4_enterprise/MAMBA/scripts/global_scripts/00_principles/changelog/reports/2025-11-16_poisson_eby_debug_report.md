# Poisson Feature Analysis eBay Error - Debug Report

**Date**: 2025-11-16
**Component**: poissonFeatureAnalysis
**Platform**: eby (eBay)
**Error**: Failed to collect lazy table

---

## Executive Summary

**ROOT CAUSE IDENTIFIED**: The eBay Poisson analysis tables DO NOT EXIST in `app_data.duckdb`.

The component is trying to query `df_eby_poisson_analysis_all` (or product-line specific tables), but these tables were never created because the eBay DRV script has **NOT BEEN EXECUTED**.

**Status**: ❌ **MISSING DATA - CODE EXISTS BUT NOT RUN**

---

## Error Chain Analysis

### 1. Initial Error
```
ERROR applying platform filter: eby
Error loading analysis_data: Failed to collect lazy table.
Call stack: collect(.)
analysis_data() returned empty dataframe
```

### 2. Cascading Errors
```
object 'track_multiplier' not found
object 'marginal_effect_pct' not found
```

### 3. Root Cause
The `analysis_data()` reactive in `poissonFeatureAnalysis.R` (line 410-662) tries to query:

```r
# Line 422-430
platform <- "cbz"  # HARDCODED - ignores eby filter!
# But when platform_id() returns "eby", the table lookup fails

table_name <- paste0("df_", platform, "_poisson_analysis_all")
# Constructs: "df_eby_poisson_analysis_all"

data <- tbl2(app_data_connection, table_name) %>%
  filter(...) %>%
  collect()  # ← FAILS HERE - table doesn't exist
```

---

## Investigation Findings

### Code Status
✅ **DRV Script Exists**: `scripts/update_scripts/DRV/eby/eby_DRV_product_line_poisson.R`
- Created: 2025-11-14 (per script header v1.0)
- Purpose: Generate eBay Poisson analysis tables
- Compliance: DM_R047 (Multi-Platform Synchronization)
- Schema: Matches CBZ version (26 columns with Type B metadata)

### Database Status
❌ **Expected Tables MISSING** in `data/app_data/app_data.duckdb`:
- `df_eby_poisson_analysis_all` (merged)
- `df_eby_poisson_analysis_alf` (Aluminum fin)
- `df_eby_poisson_analysis_irf` (Copper fin)
- `df_eby_poisson_analysis_pre` (Dryer fin)
- `df_eby_poisson_analysis_rek` (Evaporator fin)
- `df_eby_poisson_analysis_tur` (Heater fin)
- `df_eby_poisson_analysis_wak` (Oil cooler)

### Prerequisite Data Status
**UNKNOWN** - Need to verify if input data exists:
- Input tables: `df_eby_sales_complete_time_series_{product_line}`
- If these don't exist, the DRV script will also fail

---

## Code Bug Identified

### Bug Location
File: `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`

**Lines 420-423**:
```r
# 載入 Poisson 分析結果
# 暫時統一使用 Cyberbiz 的數據
# platform <- platform_id()
platform <- "cbz"  # 固定使用 Cyberbiz ← BUG: Hardcoded!
```

**Impact**:
- Comment says "temporarily use Cyberbiz data"
- Platform filter from config is completely ignored
- When user selects "eby" platform, code still tries to use "cbz"
- Then logic changes at line 426-430 to use the original platform variable
- **Inconsistent behavior**: Hardcoded override defeats platform switching

### Expected Behavior
```r
# Should respect platform_id() from config
platform <- platform_id()  # Use actual platform filter
prod_line <- product_line_id()

if (prod_line == "all") {
  table_name <- paste0("df_", platform, "_poisson_analysis_all")
} else {
  table_name <- paste0("df_", platform, "_poisson_analysis_", prod_line)
}
```

---

## Principle Violations

### MP064: ETL-Derivation Separation
- **Violation**: UI component has hardcoded data source logic
- **Expected**: Data source should be determined by configuration/filters
- **Impact**: Platform switching broken

### DM_R047: Multi-Platform Data Synchronization
- **Violation**: Code prevents platform switching from working
- **Expected**: Both CBZ and EBY should work identically
- **Impact**: Cannot test eBay data even if it exists

### MP031: Defensive Programming
- **Violation**: No existence check before `tbl2()` call
- **Expected**: Check `dbExistsTable()` before query
- **Impact**: Cryptic "failed to collect" error instead of clear "table not found"

---

## Fix Strategy

### Phase 1: Verify Prerequisites (15 minutes)

**Step 1**: Check if eBay time series data exists
```r
# Quick verification script
library(DBI); library(duckdb)
con <- dbConnect(duckdb(), "data/app_data/app_data.duckdb")

# Check for eBay time series tables
ts_tables <- dbListTables(con) %>%
  grep("df_eby_sales_complete_time_series", ., value = TRUE)

if (length(ts_tables) == 0) {
  cat("❌ BLOCKER: eBay time series tables missing!\n")
  cat("Must run ETL pipeline first.\n")
} else {
  cat("✓ Found", length(ts_tables), "eBay time series tables\n")
  for (tbl in ts_tables) {
    cat("  -", tbl, ":",
        dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]],
        "rows\n")
  }
}

dbDisconnect(con, shutdown = TRUE)
```

**Decision Point**:
- ✅ If time series exists → Proceed to Phase 2
- ❌ If missing → Must run eBay ETL first (see separate pipeline investigation)

### Phase 2: Execute eBay DRV (30 minutes)

**Step 2**: Run eBay Poisson DRV script
```bash
# Navigate to MAMBA root
cd /Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/MAMBA

# Execute eBay DRV (creates all 7 tables)
Rscript scripts/update_scripts/DRV/eby/eby_DRV_product_line_poisson.R

# Expected output:
# - Processing 6 product lines (alf, irf, pre, rek, tur, wak)
# - Running Poisson regression for each
# - Writing to df_eby_poisson_analysis_{product_line}
# - Merging into df_eby_poisson_analysis_all
# - Validation checks pass
```

**Step 3**: Verify output tables
```r
library(DBI); library(duckdb)
con <- dbConnect(duckdb(), "data/app_data/app_data.duckdb")

# Expected tables
expected <- c(
  "df_eby_poisson_analysis_all",
  "df_eby_poisson_analysis_alf",
  "df_eby_poisson_analysis_irf",
  "df_eby_poisson_analysis_pre",
  "df_eby_poisson_analysis_rek",
  "df_eby_poisson_analysis_tur",
  "df_eby_poisson_analysis_wak"
)

all_exist <- all(sapply(expected, function(t) dbExistsTable(con, t)))

if (all_exist) {
  cat("✅ All eBay Poisson tables created successfully\n\n")

  # Verify schema matches CBZ (DM_R047)
  eby_cols <- sort(dbListFields(con, "df_eby_poisson_analysis_all"))
  cbz_cols <- sort(dbListFields(con, "df_cbz_poisson_analysis_all"))

  if (identical(eby_cols, cbz_cols)) {
    cat("✅ Schema matches CBZ (DM_R047 compliant)\n")
  } else {
    cat("⚠️ Schema mismatch detected:\n")
    cat("EBY only:", setdiff(eby_cols, cbz_cols), "\n")
    cat("CBZ only:", setdiff(cbz_cols, eby_cols), "\n")
  }

  # Check metadata
  metadata_cols <- c("computed_at", "data_version", "display_name")
  has_metadata <- all(metadata_cols %in% eby_cols)

  if (has_metadata) {
    cat("✅ Type B metadata present\n")
  } else {
    cat("⚠️ Missing metadata:",
        setdiff(metadata_cols, eby_cols), "\n")
  }

} else {
  cat("❌ Missing tables:",
      expected[!sapply(expected, function(t) dbExistsTable(con, t))], "\n")
}

dbDisconnect(con, shutdown = TRUE)
```

### Phase 3: Fix Code Bug (10 minutes)

**Step 4**: Remove hardcoded platform override

File: `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`

**Change Lines 420-423**:
```r
# OLD (buggy):
# 載入 Poisson 分析結果
# 暫時統一使用 Cyberbiz 的數據
# platform <- platform_id()
platform <- "cbz"  # 固定使用 Cyberbiz

# NEW (fixed):
# Respect platform filter from config (DM_R047)
platform <- platform_id()
```

**Step 5**: Add defensive table existence check

**After Line 430**, add:
```r
# Defensive check: verify table exists before query (MP031)
if (!dbExistsTable(app_data_connection@con, table_name)) {
  warning(sprintf("Table not found: %s (platform: %s, product_line: %s)",
                  table_name, platform, prod_line))
  component_status("error")
  return(data.frame())
}
```

### Phase 4: Verification (10 minutes)

**Step 6**: Test platform switching in UI
1. Launch app with eBay platform filter
2. Navigate to Poisson Feature Analysis
3. Verify:
   - No "failed to collect" error
   - Data loads successfully
   - Metadata banner shows correct timestamps
   - Track multiplier and marginal effect calculated
   - All visualizations render

**Step 7**: Test both platforms
- Switch between CBZ and EBY
- Verify both load without errors
- Compare schemas are identical (DM_R047)

---

## Prevention Measures

### Code Review Checklist
- [ ] Never hardcode platform/data source in UI components
- [ ] Always respect reactive config/filter values
- [ ] Add defensive existence checks before database queries
- [ ] Provide clear error messages (not cryptic "failed to collect")

### Testing Requirements
- [ ] Test with both platforms (CBZ and EBY)
- [ ] Test with missing data (graceful error handling)
- [ ] Test with malformed data (schema validation)
- [ ] Test platform switching (no cached values)

### Documentation Updates
- [ ] Update component README with platform support status
- [ ] Document prerequisite DRV tables required
- [ ] Add troubleshooting section for missing tables

---

## Related Principles

### MP029: No Fake Data Principle
✅ **Compliant**: Script correctly identified that tables don't exist
❌ **Violation Risk**: Could generate fake data to "fix" the error
✅ **Proper Fix**: Run real DRV script to create tables from real data

### MP064: ETL-Derivation Separation
❌ **Violation**: Component has business logic about data sources
✅ **Fix**: Remove hardcoded platform, respect configuration

### DM_R047: Multi-Platform Synchronization
❌ **Violation**: Hardcoded override prevents synchronization
✅ **Fix**: Execute both platform DRVs, remove override

---

## Execution Plan Summary

**Total Time**: ~65 minutes

| Phase | Task | Time | Blocker? |
|-------|------|------|----------|
| 1 | Verify eBay time series exists | 15 min | ⚠️ Critical |
| 2 | Run eBay DRV script | 30 min | Required |
| 3 | Fix code bug | 10 min | Required |
| 4 | Test verification | 10 min | Required |

**Next Steps**:
1. Start with Phase 1 verification (is input data available?)
2. If blocked, investigate eBay ETL pipeline status
3. If clear, execute Phases 2-4 in sequence

---

## Additional Context

### Related Files
- DRV Script: `scripts/update_scripts/DRV/eby/eby_DRV_product_line_poisson.R`
- Component: `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`
- Orchestrator: `scripts/update_scripts/DRV/update_all_platforms_poisson.R`

### Pipeline Investigation Report
See: `validation/PIPELINE_STATUS_INVESTIGATION_2025-11-13.md`
- Reports that CBZ pipeline is functional
- No mention of eBay pipeline execution status
- Week 1-4 implementation complete but NOT executed

### Principle References
- **MP029**: No Fake Data
- **MP031**: Defensive Programming
- **MP064**: ETL-Derivation Separation
- **MP135 v2.0**: Analytics Temporal Classification (Type B)
- **DM_R046**: Variable Display Name Metadata Rule
- **DM_R047**: Multi-Platform Data Synchronization
- **R113**: Four-Part Script Structure
- **R118**: Statistical Significance Documentation
- **R120**: Variable Range Metadata Requirement
- **UI_R024**: Metadata Display for Steady-State Analytics

---

**Report Complete**
Awaiting decision on execution plan.
