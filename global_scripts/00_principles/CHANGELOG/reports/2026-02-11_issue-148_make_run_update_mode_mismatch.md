# Issue #148 Implementation Report: `make run` Mode Mismatch

## Source of Truth

- GitHub Issue: `#148`

## Problem

`make run` executed ETL/DRV targets through `R --vanilla -e`, and mode detection in initialization could fall back to `APP_MODE`, causing update-path DB access failures.

## Root Cause

`sc_Rprofile.R` mode detection relies on script path (`--file` / frame metadata). In `-e` execution, script path can be empty, so fallback mode becomes `APP_MODE`.

## Fix

Updated:

- `scripts/update_scripts/_targets.R`

Change:

- Inject `OPERATION_MODE <- 'UPDATE_MODE'` before `autoinit()` in `build_r_command()`.

## Validation

Executed on 2026-02-11:

1. `make clean`
2. `make run PLATFORM=amz LAYER=etl`
3. `make run PLATFORM=amz TARGET=amz_D01_06`

Observed:

- ETL run completed (`21 completed, 0 skipped`)
- DRV01 chain completed (`7 completed, 3 skipped`)
- Logs consistently show `OPERATION_MODE = UPDATE_MODE`

## Related Logs

- `scripts/update_scripts/logs/run_20260211_122535.log`
- `scripts/update_scripts/logs/run_20260211_122822.log`
