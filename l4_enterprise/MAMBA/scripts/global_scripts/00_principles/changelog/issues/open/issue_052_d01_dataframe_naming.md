---
issue: "ISSUE_052"
title: "D01_01.R DataFrame Naming Conventions"
severity: "medium"
component: "D01_derivations"
app: "shared"
created: "2025-08-23"
status: "open"
original_source: "recommendation/logs.md"
---

## Problem
The temp data should be named with different name. Current naming doesn't follow the established pattern for cleansed data.

## Expected Behavior
- Cleansed data should be named: `df_amazon_sales___cleansed` (with triple underscore)
- Follow the pattern: `df_[platform]_sales`

## Actual Behavior
- Using generic "data.frame" naming
- Not following the platform-specific naming convention

## Proposed Resolution
Change data.frame cleansed data to `df_amazon_sales___cleansed` following the naming convention.

## Related Issues
- Incorrect data.frame reference (should be `df_amazon_sales`)
- Check uses `dbExistsTable(raw_data, "df_amazon_sales")`