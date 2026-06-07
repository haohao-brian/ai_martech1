# MP103: Autodeinit Behavior and Resource Management

**Date**: 2025-08-28
**Type**: Meta-Principle Addition
**Impact**: High - Affects all scripts using autodeinit()

## Summary

Created MP103 to explicitly document that `autodeinit()` removes ALL user-created variables from the global environment, resolving critical errors in scripts that referenced variables after cleanup.

## Problem Identified

The `cbz_ETL01_0IM.R` script was failing after calling `autodeinit()` because it attempted to reference variables that had been removed:

```r
# ❌ INCORRECT: Variables no longer exist after autodeinit()
autodeinit()
script_total_elapsed <- as.numeric(Sys.time() - script_start_time, units = "secs")
# ERROR: script_start_time no longer exists!
```

## Solution Implemented

### 1. Created MP103 Documentation
- Location: `docs/en/part1_principles/CH00_fundamental_principles/02_structure_organization/MP103_autodeinit_behavior.qmd`
- Clearly defines autodeinit() behavior
- Provides correct usage patterns
- Documents common mistakes

### 2. Fixed cbz_ETL01_0IM.R
Applied the correct pattern:
```r
# ✅ CORRECT: Capture metrics BEFORE autodeinit()
final_metrics <- list(
  script_total_elapsed = as.numeric(Sys.time() - script_start_time, units = "secs"),
  # ... other metrics ...
)

autodeinit()  # Now safe to cleanup

# Use captured metrics
message(sprintf("Total time: %.2fs", final_metrics$script_total_elapsed))
```

## Key Principle Points

1. **Complete Cleanup**: autodeinit() removes ALL variables, not just connections
2. **Capture First**: Any values needed after cleanup must be captured before
3. **Late Execution**: Place autodeinit() as late as possible in DEINITIALIZE
4. **No References**: Never reference variables after autodeinit()

## Impact on Existing Code

### Scripts That Need Review
All scripts using autodeinit() should be reviewed to ensure they follow MP103:
- ETL scripts (cbz_ETL*, eby_ETL*, amz_ETL*)
- Update scripts
- Any script with DEINITIALIZE section

### Migration Path
1. Search for autodeinit() usage: `grep -r "autodeinit()" scripts/`
2. Check for variable references after the call
3. Apply the capture-before-cleanup pattern
4. Test to ensure no reference errors

## Benefits

1. **Clarity**: Developers now understand autodeinit() behavior
2. **Reliability**: Scripts won't fail due to missing variables
3. **Memory Management**: Ensures complete cleanup
4. **Documentation**: Behavior is now formally specified

## Related Principles

- **MP031**: autoinit() for initialization
- **MP033**: Resource management patterns
- **R113**: Four-part script structure

## Testing

Created compliance check function:
```r
check_autodeinit_usage <- function(script_path) {
  # Validates proper autodeinit() usage
  # Returns compliance status and messages
}
```

## Lessons Learned

This issue highlights the importance of:
1. Documenting destructive operations clearly
2. Testing cleanup code thoroughly
3. Making implicit behavior explicit in principles
4. Capturing state before cleanup operations

---

This change ensures robust resource management and prevents a common but critical error pattern in MAMBA scripts.