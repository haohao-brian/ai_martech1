---
issue: "ISSUE_056"
title: "Incorrect Date Aggregation Functions"
severity: "high"
component: "data_processing"
app: "shared"
created: "2025-08-23"
status: "open"
original_source: "recommendation/logs.md"
---

## Problem
Using `first(date)` to get the earliest date instead of `min(date)`.

## Expected Behavior
- First date should be calculated using `min(date)`
- Should have both `first_cols` and `min_cols` for different aggregation needs

## Actual Behavior
- Currently using `first(date)` which returns the first row's date, not necessarily the earliest
- Only has `first_cols` without `min_cols`

## Proposed Resolution
1. Change date aggregation to use `min(date)` for earliest date
2. Rename or expand `first_cols` to include both `first_cols` and `min_cols`
3. Document the difference between `first()` (row order) and `min()` (value order)

## Impact
This is a critical bug that could lead to incorrect date calculations in analytics.