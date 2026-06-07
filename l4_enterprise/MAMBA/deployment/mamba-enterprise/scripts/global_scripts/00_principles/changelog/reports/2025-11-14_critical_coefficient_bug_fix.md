# Critical Bug Fix: Coefficient Column Check Logic

**Date**: 2025-11-14
**Component**: poissonFeatureAnalysis.R
**Severity**: CRITICAL
**Status**: FIXED

## Problem Summary

### Root Cause
```r
# WRONG: Checks if FUNCTION exists, not if DATA has column
if (exists("poisson_regression")) {
  # Assumes data has 'coefficient' column
  data %>% filter(!is.na(coefficient) & ...)  # ERROR!
}
```

**Issue Flow**:
1. `exists("poisson_regression")` returns TRUE (function exists in environment)
2. Code enters IF branch
3. IF branch assumes data has `coefficient` column
4. But actual data might only have `incidence_rate_ratio` column
5. **Error**: `object 'coefficient' not found`

### Why This Happened
After YAML configuration migration, the condition checking logic was incorrectly based on **environment state** (function existence) rather than **data structure** (column presence).

## Principle Violations

### MP064: ETL-Derivation Separation
- **Violation**: Logic based on environment state, not data structure
- **Correct**: Data-driven logic that checks actual column names

### MP031: Defensive Programming
- **Violation**: Assumed column existence without verification
- **Correct**: Check column presence before accessing

## Solution

### Correct Pattern
```r
# CORRECT: Check if DATA has the column
if ("coefficient" %in% names(data)) {
  # Path 1: Data has coefficient
  data %>% filter(!is.na(coefficient) & ...)
} else {
  # Path 2: Data has incidence_rate_ratio
  data %>% filter(!is.na(incidence_rate_ratio) & ...)
}
```

## Changes Made

### 1. Data Fetching (Lines 425-449)
**Before**: Duplicated data fetching in IF/ELSE branches
**After**: Single data fetch, then check column structure
```r
# Fetch ONCE before checking structure
data <- tbl2(app_data_connection, table_name) %>%
  filter(...) %>%
  collect()

data <- filter_excluded_covariates(data, ...)

# THEN check column structure
if ("coefficient" %in% names(data)) {
  # Handle coefficient case
} else {
  # Handle incidence_rate_ratio case
}
```

### 2. Filtering Logic (Lines 619-633)
**Added**: Column check before filtering
```r
if ("coefficient" %in% names(data)) {
  filtered_data <- data %>%
    filter(!is.na(coefficient) & !is.na(p_value) & ...)
} else {
  filtered_data <- data %>%
    filter(!is.na(incidence_rate_ratio) & !is.na(p_value) & ...)
}
```

### 3. Table Rendering (Lines 921-1046)
**Added**: Dual-path table creation with appropriate column names
- Path 1: "係數" (Coefficient)
- Path 2: "發生率比" (Incidence Rate Ratio)

### 4. Download Handler (Lines 1200-1312)
**Added**: Conditional export based on column structure

### 5. AI Analysis (Lines 1373-1393)
**Added**: Conditional data frame creation for GPT analysis

### 6. Product Development (Lines 1434-1495)
**Added**: Conditional positive variable filtering and description

## Files Modified

- `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`

## Success Criteria

- [x] Data fetching happens once before if/else
- [x] Condition checks data columns, not function existence
- [x] Both paths handle YAML-filtered data correctly
- [x] No duplicate code for data fetching
- [x] Error "object 'coefficient' not found" resolved
- [x] All table rendering handles both column types
- [x] Download export supports both formats
- [x] AI analysis adapts to data structure

## Testing Required

1. **Test with coefficient data**:
   - Verify table displays "係數" column
   - Verify download includes coefficient
   - Verify AI analysis uses coefficient

2. **Test with incidence_rate_ratio data**:
   - Verify table displays "發生率比" column
   - Verify download includes IRR
   - Verify AI analysis uses IRR

3. **Test filters**:
   - Positive variables correctly identified
   - Extreme values correctly filtered
   - YAML exclusions applied

## Lessons Learned

### DO
- ✅ Check data structure, not environment state
- ✅ Fetch data once, then branch on structure
- ✅ Use defensive programming with column checks
- ✅ Document both code paths clearly

### DON'T
- ❌ Use `exists()` to check data columns
- ❌ Assume column presence without verification
- ❌ Duplicate data fetching in branches
- ❌ Base logic on function existence

## Related Issues

- Part of YAML configuration migration
- Follows MP064 (ETL-Derivation Separation)
- Follows MP031 (Defensive Programming)

## Impact

**Before**: App crashes with "coefficient not found" error
**After**: App handles both data structures gracefully

**User Experience**:
- No more mysterious crashes
- Correct column labels based on actual data
- Proper AI analysis regardless of data format
