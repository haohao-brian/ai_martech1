# Issue #143: Symlink df_platform.csv Caused Deployment Failure

## Status: CLOSED

## Problem

Posit Connect deployment failed with error:
```
Error: object 'df_platform' not found
```

## Root Cause

`scripts/global_scripts/30_global_data/parameters/scd_type1/df_platform.csv` was a **symbolic link** pointing to another file. When rsconnect bundles the application for deployment:

1. Symbolic links are not always followed correctly
2. The target file may not be included in the deployment bundle
3. Result: `df_platform` cannot be loaded on Connect

## Solution

Replaced the symbolic link with an actual file containing the platform data.

### Files Changed

| File | Change |
|------|--------|
| `30_global_data/parameters/scd_type1/df_platform.csv` | Symlink → Real file |
| `30_global_data/parameters/scd_type1/platform_registry.csv` | Deleted (redundant) |
| `04_utils/fn_load_app_config.R` | Updated to use df_platform only |
| `04_utils/fn_get_platform_config.R` | Updated to use df_platform only |
| `04_utils/fn_load_customer_data.R` | Updated to use df_platform only |

## Prevention

New principle added: **DEV_R040 - No Symlinks in Deployable Code**

Files that will be deployed to Posit Connect must be real files, not symbolic links.

## Discovery

- **Found by**: Codex
- **Date**: 2026-01-08
- **Context**: Posit Connect deployment debugging

## Related

- DEV_R040: No Symlinks in Deployable Code
- DM_R056: Mode-Specific Database Path Loading
- Issue #142: Side-effect function file
