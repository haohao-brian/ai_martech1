---
issue: "ISSUE_053"
title: "D01_01.R Incorrect NA Validation Fields"
severity: "high"
component: "D01_derivations"
app: "shared"
created: "2025-08-23"
status: "open"
original_source: "recommendation/logs.md"
---

## Problem
is.na check is being performed on wrong fields - checking `customer_id` and `time` instead of the correct fields.

## Expected Behavior
NA validation should check:
- `amazon_order_id`
- `purchase_date`

## Actual Behavior
Currently checking:
- `customer_id` 
- `time`

## Proposed Resolution
1. Update NA validation to check correct fields
2. Ensure `time` is properly mutated from `purchase_date`
3. Use typed NA values: `mutate(across(where(is.character), ~na_if(., NA_character_)))`

## Additional Notes
- The `time` field should be derived from `purchase_date` via mutation
- NA values should be properly typed (NA_character_ for character columns)