# DEBUG REPORT: App Issues

**Last Updated**: 2025-11-14

---

## ISSUE 1: App Hang at Initialization (RESOLVED)

**Date**: 2025-11-13
**Issue**: Application hangs after "Found 5348 files to scan"
**Severity**: CRITICAL - App cannot start
**Status**: RESOLVED - Migration scripts moved

### ROOT CAUSE
Migration script in `04_utils/` had top-level executable code that processed 5348 files on every app startup.

### FIX APPLIED
Moved migration scripts to `28_migration_scripts/` to prevent automatic sourcing during initialization.

---

## ISSUE 2: "object 'incidence_rate_ratio' not found" Error (CURRENT)

**Date**: 2025-11-14
**Component**: poissonFeatureAnalysis
**Severity**: HIGH - Component crashes on load
**Status**: DEBUGGING - Defensive fixes applied

### Error Message
```
Warning: Error in filter: object 'incidence_rate_ratio' not found
At: positive_data reactive (line 611)
```

### Root Cause Analysis

#### Problem Flow

1. **analysis_data()** reactive (lines 410-620):
   - ✅ Fetches data successfully with all columns (coefficient, incidence_rate_ratio, predictor, p_value, etc.)
   - ✅ Calls `filter_excluded_covariates()` - **works correctly, preserves all columns**
   - ✅ Enters Path 1 (coefficient exists)
   - ❌ Attempts `mutate()` operation with:
     - `mapply(calculate_track_multiplier, ...)`
     - `sapply(predictor, calculate_attribute_range)`
   - ❌ **Silent error occurs in mutate()** (likely in one of the mapply/sapply calls)
   - ⚠️ Error caught by `tryCatch` block (line 603)
   - ❌ Returns `data.frame()` - **empty dataframe with zero rows and zero columns**

2. **positive_data()** reactive (lines 616-670):
   - Calls `data <- analysis_data()` (line 617)
   - Receives empty dataframe
   - No defensive check for empty dataframe (BEFORE FIX)
   - Attempts `if ("coefficient" %in% names(data))` - returns FALSE (no columns)
   - Falls into `else` block (line 637)
   - Attempts `filter(!is.na(incidence_rate_ratio) ...)`
   - ❌ **ERROR: Column doesn't exist in empty dataframe**

#### Key Finding

**`filter_excluded_covariates()` is NOT the problem!**

The function correctly:
- ✅ Filters ROWS based on predictor names
- ✅ Preserves ALL COLUMNS in the dataframe
- ✅ Works as designed per DM_R043 principle

**Test Results**:
```r
# Database fetch: 339 rows, 21 columns (including coefficient, incidence_rate_ratio)
# After filter_excluded_covariates(): 171 rows, 21 columns (all columns preserved)
# Has coefficient? TRUE
```

The actual problem is a **silent failure in the `mutate()` operation** that calls helper functions.

### Fixes Applied

#### 1. Enhanced Error Logging (lines 603-612)
```r
}, error = function(e) {
  # Enhanced error logging for debugging
  error_msg <- paste0("Error loading analysis data: ", e$message, "\n",
                     "Call stack: ", paste(deparse(e$call), collapse = "\n"))
  warning(error_msg)
  message("DEBUG: ", error_msg)  # Force console output
  print(traceback())  # Print full traceback
  component_status("error")
  data.frame()
})
```

**Purpose**: Expose the actual error message that was being silently caught.

#### 2. Empty Dataframe Protection (lines 619-647)
```r
positive_data <- reactive({
  data <- analysis_data()

  # Check if data is empty (error occurred in analysis_data)
  if (nrow(data) == 0 || ncol(data) == 0) {
    message("DEBUG: analysis_data() returned empty dataframe - check error logs above")
    return(data.frame())  # Return empty dataframe gracefully
  }

  # ... filtering logic

  # Handle case where neither column exists
  } else {
    message("DEBUG: Neither 'coefficient' nor 'incidence_rate_ratio' found in data")
    message("DEBUG: Available columns: ", paste(names(data), collapse = ", "))
    return(data.frame())
  }
```

**Purpose**: Prevent "object not found" error by checking for empty dataframe first.

#### 3. Defensive Column Checks (lines 455-460, 552-557)
```r
# Path 1: coefficient
required_cols <- c("coefficient", "predictor", "p_value")
missing_cols <- setdiff(required_cols, names(data))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}

# Path 2: incidence_rate_ratio
required_cols <- c("incidence_rate_ratio", "predictor", "p_value")
missing_cols <- setdiff(required_cols, names(data))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}
```

**Purpose**: Explicit validation before attempting mutate operations.

#### 4. Protected mapply Calls (lines 471-479, 567-575)
```r
track_multiplier = tryCatch({
  mapply(calculate_track_multiplier,
         coefficient,
         predictor,
         MoreArgs = list(incidence_rate_ratio = NULL))
}, error = function(e) {
  message("DEBUG: Error in calculate_track_multiplier: ", e$message)
  rep(NA_real_, length(coefficient))
}),
```

**Purpose**: Prevent single row errors from failing entire mutate operation.

#### 5. Protected sapply Calls (lines 533-546, 629-642)
```r
track_explanation = tryCatch({
  ranges <- sapply(predictor, calculate_attribute_range)
  paste0(...)
}, error = function(e) {
  message("DEBUG: Error in calculate_attribute_range: ", e$message)
  paste0(...)  # Fallback without ranges
})
```

**Purpose**: Graceful degradation - still show track_multiplier even if range calculation fails.

### Expected Outcomes

#### Immediate Benefits
1. ✅ **No more crashes**: App won't crash with "object not found" error
2. ✅ **Visible errors**: DEBUG messages will show exactly which function is failing
3. ✅ **Graceful degradation**: Partial failures won't break entire component

#### Next Steps for Full Fix

Once the DEBUG messages reveal the actual error:

1. **If `calculate_track_multiplier()` is failing**:
   - Check for NA values in coefficient/incidence_rate_ratio
   - Check for invalid predictor names (encoding issues?)
   - Check for division by zero or other math errors

2. **If `calculate_attribute_range()` is failing**:
   - Check for special characters in predictor names
   - Check regex patterns for Chinese characters
   - Verify all pattern matching logic

3. **If entire mutate is failing**:
   - Check for memory issues (too many rows?)
   - Check for package dependency issues
   - Verify all required functions are in scope

### Testing Instructions

#### Run the App
```bash
cd /Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/MAMBA
Rscript app.R
```

#### Look for DEBUG Messages in Console
```
DEBUG: Starting mutate() with XXX rows
DEBUG: Error in calculate_track_multiplier: [specific error]
DEBUG: Error in calculate_attribute_range: [specific error]
DEBUG: analysis_data() returned empty dataframe - check error logs above
```

#### Expected Behavior
- ✅ App should NOT crash
- ✅ DEBUG messages should reveal the actual failing function
- ✅ UI should show "No data available" instead of error message

### Architecture Compliance

#### Principles Followed

1. **MP064**: Data-driven logic - check data structure before operations
2. **MP099**: Real-time progress reporting - DEBUG messages for monitoring
3. **R113**: Proper error handling with informative messages
4. **DM_R043**: Presentation layer filtering (filter_excluded_covariates works correctly)

#### Principles Violated (Previously)

1. **MP099**: Silent failures without reporting
2. **R113**: Missing defensive checks before operations

### Files Modified

- `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`
  - Lines 603-612: Enhanced error logging
  - Lines 619-647: Empty dataframe protection
  - Lines 455-460: Defensive column checks (Path 1)
  - Lines 471-479: Protected mapply (Path 1)
  - Lines 533-546: Protected sapply (Path 1)
  - Lines 552-557: Defensive column checks (Path 2)
  - Lines 567-575: Protected mapply (Path 2)
  - Lines 629-642: Protected sapply (Path 2)

### Verification Checklist

- [ ] App starts without immediate crash
- [ ] DEBUG messages appear in console
- [ ] Can identify which specific function is failing
- [ ] Error messages are informative and actionable
- [ ] UI shows appropriate "No data" message instead of crash
- [ ] Can navigate to other components without issues

---

**Next Action**: Run app and check DEBUG messages to identify exact failure point in mutate() operation.
