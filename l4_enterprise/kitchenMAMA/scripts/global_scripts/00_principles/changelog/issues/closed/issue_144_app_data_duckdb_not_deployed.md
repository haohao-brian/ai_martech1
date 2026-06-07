# Issue #144: app_data.duckdb Not Included in Posit Connect Deployment

## Status: CLOSED (Revised Solution)

## Problem

Posit Connect deployment failed with multiple errors:

### Initial Error
```
DuckDB 連線失敗：Cannot open database "/cloud/project/data/app_data/app_data.duckdb"
in read-only mode: database does not exist
```

### After Git LFS Attempt
```
The file "/cloud/project/data/app_data/app_data.duckdb" exists,
but it is not a valid DuckDB database file!
```

## Root Cause

Two-stage failure:

### Stage 1: File Not Tracked
`.gitignore` excluded duckdb files, so the file wasn't in the deployment bundle.

### Stage 2: Git LFS Not Supported
After setting up Git LFS, Posit Connect only cloned the LFS pointer file (~134 bytes)
instead of the actual DuckDB file (109MB). **Posit Connect does not support Git LFS**.

## Resolution (Current)
Deployment now uploads `app_data` directly to Supabase during deploy, so the Parquet workaround is no longer needed.

Historical details for the deprecated Parquet approach are recorded in:
`scripts/global_scripts/00_principles/changelog/reports/2026-02-04_supabase_upload_replaces_parquet.md`

## Related

- Issue #142: Connect startup db missing (fn_check_staged.R side effects)
- Issue #143: Symlink df_platform.csv caused deployment failure
- DEV_R039: Side-Effect-Free Function Files
- DEV_R040: No Symlinks in Deployable Code
- DM_R056: Posit Connect Deployment Assets

## Discovery

- **Found by**: Posit Connect deployment log
- **Date**: 2026-01-08
- **Context**: Deployment testing - initial fix (Git LFS) failed, Parquet solution implemented
