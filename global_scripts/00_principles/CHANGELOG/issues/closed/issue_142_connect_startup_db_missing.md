---
issue: "ISSUE_142"
title: "Connect startup fails when staged_data.duckdb is missing"
severity: "high"
component: "deployment"
app: "mamba"
created: "2026-01-08"
status: "closed"
---

## Problem
Posit Connect startup loads `fn_check_staged.R` via global utils. The script executes immediately and attempts to open `data/local_data/staged_data.duckdb`, which is not present in deployment, causing the app to crash before startup completes.

## Expected Behavior
Startup should not require local_data databases. Staged DB checks should run only when explicitly invoked.

## Actual Behavior
Startup fails with: `cannot open file 'data/local_data/staged_data.duckdb': No such file or directory`.

## Resolution
Convert `fn_check_staged.R` into a pure helper function that checks existence before connecting and returns safely when missing.

## Fix
- `scripts/global_scripts/04_utils/fn_check_staged.R`: wrap logic in `check_staged_db()` and guard missing file.

## Tests
Not run (Connect-only failure).
