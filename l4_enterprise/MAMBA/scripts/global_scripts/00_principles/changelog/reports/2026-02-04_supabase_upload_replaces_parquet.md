# 2026-02-04 Supabase Upload Replaces Parquet Workflow

## Summary
The deployment flow now uploads `app_data` directly to Supabase, so the Parquet export workaround is no longer required.

## Rationale
The previous Parquet-based workaround existed to bypass Git LFS limitations on Posit Connect. With Supabase upload in the deployment driver, data sync no longer depends on bundling DuckDB or Parquet files in the repo.

## Changes
- Deprecated the Parquet workaround documentation in `issue_144_app_data_duckdb_not_deployed.md`.
- Deployment now relies on Supabase upload during deploy (see deployment driver in `scripts/global_scripts/23_deployment/03_deploy/`).

## Current Status
- Parquet export workflow is retired.
- Deployment uses Supabase upload as the authoritative data sync step.
