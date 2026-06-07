# Poisson Components Testing Checklist
**Date**: 2025-11-14
**Version**: v1.0
**Components**: poissonFeatureAnalysis, poissonCommentAnalysis, poissonTimeAnalysis

**Note (2026-01-03)**: `consolidate_to_app_data.R` is archived; app-facing tables are now written directly by DRV (MP110, DM_R055). This checklist references the legacy step for historical context.

## Pre-Testing Verification

### Database Preparation
- [x] **DRV Script Executed**: `cbz_DRV_product_line_poisson.R`
  - 5/6 product lines successful (IRF, PRE, REK, TUR, WAK)
  - ALF failed (model convergence issues - deferred)
  - Metadata columns added: `computed_at`, `data_version`

- [x] **Consolidation Script Executed**: `consolidate_to_app_data.R`
  - 3,506 rows synced with R120 metadata
  - Tables: df_cbz_poisson_analysis_rek, _tur, _irf, _pre, _wak, _alf
  - R120 fields verified: `predictor_min`, `predictor_max`, `track_multiplier`

- [x] **Configuration Initialized**: YAML covariate exclusion loaded at startup
  - Version: v1.1
  - Auto-initialization in `sc_Rprofile.R`

### Code Changes Summary
- [x] **Metadata Banner**: NULL/NA checks, security fixes, UX improvements
- [x] **Convergence Filter**: Changed from `TRUE` to `"converged"` (12 locations)
- [x] **Column Check**: Changed from `exists()` to `%in% names()`
- [x] **YAML Filtering**: Migrated to configuration-driven exclusion (43 structural columns)
- [x] **Initialization Pattern**: Implemented MP136 for startup configuration loading

---

## Test Sequence

### 1. Application Startup

#### 1.1 Configuration Loading
**Action**: Start MAMBA app
```bash
cd /Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/MAMBA
Rscript app.R
```

**Expected Output**:
```
📋 Initializing covariate exclusion configuration...
   Using config file: scripts/global_scripts/30_global_data/parameters/scd_type2/list_covariate_neglected.yaml
✅ Covariate exclusion configuration loaded successfully
   Version: v1.1
   Last updated: 2025-11-14
   Application types: poisson_regression, positioning_analysis
```

**Verification**:
- [ ] No "Configuration file not found" errors
- [ ] YAML loaded before any Poisson components render
- [ ] Version v1.1 confirmed

#### 1.2 Database Connection
**Expected**:
- [ ] Connection to `data/app_data/app_data.duckdb` successful
- [ ] No database lock errors
- [ ] Tables accessible: df_cbz_poisson_analysis_*

---

### 2. Feature Analysis Component

**Navigation**: Micro > 精準行銷 > 特徵分析 (or equivalent)

#### 2.1 Data Loading
**Expected**:
- [ ] No "object 'coefficient' not found" errors
- [ ] No "Unknown or uninitialised column" warnings
- [ ] Data loads for at least one product line (REK, TUR, IRF, PRE, or WAK)

#### 2.2 Metadata Banner Display

**Visual Check**:
- [ ] Metadata banner visible at top of component
- [ ] Background: Light blue (#e8f4f8)
- [ ] Border: Left 4px solid blue (#1e88e5)
- [ ] Text color: Dark gray (#495057) - readable on light background

**Content Check**:
- [ ] "基於全部歷史數據" (Based on all historical data) - displayed ✅
- [ ] "計算時間: YYYY-MM-DD HH:MM" (Computed time) - displayed ✅
- [ ] "數據至: YYYY-MM-DD" (Data until) - **NOT displayed** (security fix) ✅

**Error Check**:
- [ ] No "Error: missing value where TRUE/FALSE needed" messages
- [ ] No red error banner above metadata banner

#### 2.3 Structural Column Filtering

**Check Attributes Table**:
- [ ] **Product names EXCLUDED**: Should NOT see entries like:
  - "product_name"
  - "product_nameMAMBA 9-7 for AUDI S3..."
  - "seller_name"
  - "brand_name"
  - Any variables ending with "_name"

- [ ] **Marketing attributes INCLUDED**: Should see entries like:
  - "price"
  - "shipping_cost"
  - "competitor_count"
  - Product features (size, color, material, etc.)

**Verification Message**:
Check console for filtering message:
```
Filtered XX of YYY covariates (ZZ.Z% excluded)
```
- [ ] Message displays correctly
- [ ] Exclusion percentage reasonable (likely 5-15%)

#### 2.4 R120 Range Metadata

**Check Track Champion Section**:
- [ ] Track multipliers displayed correctly (based on actual data ranges)
- [ ] No placeholder values or errors

**Check Coefficient Table**:
- [ ] `predictor_min` column present
- [ ] `predictor_max` column present
- [ ] `track_multiplier` column present
- [ ] Values are numeric and non-NULL

#### 2.5 Convergence Filtering

**Check Analysis Results**:
- [ ] Only "converged" models displayed
- [ ] No "no_variation" entries visible in results
- [ ] Total count matches database query:
  ```sql
  SELECT COUNT(*) FROM df_cbz_poisson_analysis_rek
  WHERE convergence = 'converged'
  ```

#### 2.6 Box Overflow Handling

**Visual Check**:
- [ ] Long text in boxes displays with ellipsis (...)
- [ ] No text overflowing box boundaries
- [ ] Tooltip appears on hover showing full text
- [ ] Truncation at ~20 characters for compact display

#### 2.7 Plots and Visualizations

**Marginal Effect Plot**:
- [ ] Renders without errors
- [ ] Data points visible
- [ ] No "coefficient not found" errors

**Strategy Recommendation**:
- [ ] Displays correctly
- [ ] Based on filtered data (no structural columns)

---

### 3. Comment Analysis Component

**Navigation**: Micro > 精準行銷 > 評論分析 (or equivalent)

#### 3.1 Core Functionality
- [ ] Component loads without errors
- [ ] Data loads from correct table (df_cbz_poisson_analysis_comments_*)
- [ ] Convergence filter applies: `convergence == "converged"`

#### 3.2 YAML Filtering
- [ ] Structural columns excluded (product_name, seller_name, etc.)
- [ ] Marketing attributes included
- [ ] Filtering message displays in console

#### 3.3 Metadata Banner
- [ ] Banner displays (same format as Feature Analysis)
- [ ] Security fix applied (no "數據至" field)
- [ ] Text color: #495057

#### 3.4 Visualizations
- [ ] Comment analysis plots render correctly
- [ ] No "coefficient not found" errors

---

### 4. Time Analysis Component

**Navigation**: Micro > 精準行銷 > 時間分析 (or equivalent)

#### 4.1 Core Functionality
- [ ] Component loads without errors
- [ ] Data loads from correct table (df_cbz_poisson_analysis_time_*)
- [ ] All 10 instances of convergence filter use `"converged"` (not TRUE)

#### 4.2 YAML Filtering
- [ ] Time features correctly handled
- [ ] Structural columns excluded
- [ ] Marketing attributes included

#### 4.3 Metadata Banner
- [ ] Banner displays correctly
- [ ] Same format and security as other components

#### 4.4 Visualizations
- [ ] Time series plots render correctly
- [ ] Seasonal patterns visible (if applicable)
- [ ] No errors in reactive chain

---

## Error Scenarios to Test

### Database Issues
**Test**: Close database connection mid-session
- [ ] Appropriate error message displays
- [ ] No app crash
- [ ] Connection re-established on reload

### Missing Configuration
**Test**: Rename YAML file temporarily
- [ ] Initialization error displays clearly
- [ ] Error message references MP136
- [ ] Instructions for manual initialization provided

### Empty Tables
**Test**: Select product line with no data
- [ ] Graceful handling (empty state message)
- [ ] No "coefficient not found" errors
- [ ] UI doesn't break

---

## Performance Checks

### Load Times
- [ ] Initial component load: < 3 seconds
- [ ] Data filtering: < 1 second
- [ ] Plot rendering: < 2 seconds

### Memory Usage
- [ ] No memory leaks after switching between components
- [ ] Database connections properly closed
- [ ] Reactive chains don't accumulate

---

## Cross-Browser Testing (Optional)

### Desktop Browsers
- [ ] Chrome/Edge (Chromium)
- [ ] Firefox
- [ ] Safari (macOS)

### Mobile Responsiveness
- [ ] Metadata banner readable on mobile
- [ ] Tables scroll horizontally if needed
- [ ] Plots resize appropriately

---

## Accessibility Checks

### Contrast Ratios
- [ ] Metadata banner text: 7.8:1 (WCAG AA compliant) ✅
- [ ] All interactive elements: >= 4.5:1

### Keyboard Navigation
- [ ] Tab through UI elements works
- [ ] Tooltips accessible via keyboard

---

## Documentation Verification

### Code Comments
- [ ] MP031 referenced in NULL checks
- [ ] DM_R043 referenced in filtering
- [ ] MP136 referenced in initialization

### Changelog Entries
- [ ] `2025-11-14_yaml_configuration_migration.md` complete
- [ ] `2025-11-14_configuration_initialization_pattern.md` complete

### Principle Files
- [ ] DM_R043 (Predictor Data Classification) created
- [ ] MP136 (Configuration Initialization Pattern) created

---

## Final Verification

### Success Criteria
All of the following must be TRUE:
- [ ] No "coefficient not found" errors in any component
- [ ] No "configuration file not found" errors
- [ ] No "missing value where TRUE/FALSE" errors
- [ ] Metadata banners display correctly (security + UX fixes applied)
- [ ] Structural columns (product names) filtered out
- [ ] R120 range metadata visible in coefficients
- [ ] Only converged models displayed
- [ ] Box overflow handled with ellipsis
- [ ] All 3 Poisson components functional

### Known Limitations
- [ ] ALF product line skipped (model convergence issues - deferred)
- [ ] Precision marketing products use different table (df_precision_poisson_analysis)

---

## Issue Reporting Template

If any tests fail, document using this format:

```markdown
## Issue: [Short Description]

**Component**: poissonFeatureAnalysis | poissonCommentAnalysis | poissonTimeAnalysis
**Severity**: Critical | High | Medium | Low
**Reproducible**: Yes | No | Sometimes

### Steps to Reproduce:
1. Navigate to...
2. Click on...
3. Observe...

### Expected Behavior:
[What should happen]

### Actual Behavior:
[What actually happens]

### Error Messages:
```
[Paste error messages here]
```

### Screenshots:
[Attach if applicable]

### Environment:
- Database: app_data.duckdb
- Product Line: [REK|TUR|IRF|PRE|WAK|ALF]
- Data Version: [from metadata banner]
```

---

## Sign-Off

**Tester**: _______________
**Date**: _______________
**All Tests Passed**: ☐ Yes ☐ No
**Notes**:

_____________________________________________________________________
_____________________________________________________________________
_____________________________________________________________________

---

## Quick Reference: File Locations

### Modified Components
- `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`
- `scripts/global_scripts/10_rshinyapp_components/poisson/poissonCommentAnalysis/poissonCommentAnalysis.R`
- `scripts/global_scripts/10_rshinyapp_components/poisson/poissonTimeAnalysis/poissonTimeAnalysis.R`

### Utility Functions
- `scripts/global_scripts/04_utils/fn_initialize_covariate_exclusion.R` (NEW)
- `scripts/global_scripts/04_utils/fn_should_exclude_covariate.R` (MODIFIED)

### Configuration
- `scripts/global_scripts/30_global_data/parameters/scd_type2/list_covariate_neglected.yaml` (v1.1)
- `scripts/global_scripts/22_initializations/sc_Rprofile.R` (MODIFIED)

### Principles
- `scripts/global_scripts/00_principles/DM_R043_predictor_data_classification.qmd` (NEW)
- `scripts/global_scripts/00_principles/MP136_configuration_initialization_pattern.qmd` (NEW)

### Database
- `data/app_data/app_data.duckdb` (21 columns, 3,506 Poisson rows)
- `data/local_data/processed_data.duckdb` (source for R120 enriched data)

---

**END OF CHECKLIST**
