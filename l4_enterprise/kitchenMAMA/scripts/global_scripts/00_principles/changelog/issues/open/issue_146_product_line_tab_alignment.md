# Issue #146: Product Line Tab Name Alignment

**Status**: open
**Priority**: high
**Date**: 2026-02-07
**Component**: ETL / Google Sheets / Product Line

---

## Problem

The `Product Line` tab in the QEF_DESIGN coding sheet has naming misalignment with the actual product line coding tabs, which will cause `import_product_profiles()` and `import_comment_properties()` to fail at runtime.

### Details

1. **Product Line tab** (ID: `1istNxsgutIfTC9faLM7HdsQzfnphHXLXtahGKYN5oCA`) has only **2 of 12** product lines filled in:
   - `太陽眼鏡_自行車` (uses half-width underscore `_`)
   - Another partial entry

2. **Coding sheet tabs** use a different naming convention:
   - `太陽眼鏡＿Cycling adult` (uses fullwidth underscore `＿`, bilingual naming)
   - 12 product lines total with format: `{Chinese}＿{English}`

3. **Import functions affected**:
   - `import_product_profiles()` (`fn_import_product_profiles.R:73`): Uses `paste0(sheet_name_prefix, product_line_name)` where `product_line_name` comes from `product_line_name_chinese` column
   - `import_comment_properties()` (`fn_import_comment_properties.R:68`): Uses `product_line_name` directly as tab name

### Root Cause

The `product_line_name_chinese` values in the `Product Line` tab do not match the actual Google Sheets tab names. The tab names contain bilingual names (Chinese + English) with fullwidth underscores, while the Product Line metadata uses Chinese-only names with half-width underscores.

---

## Impact

- `amz_ETL_product_profiles_0IM.R` will fail to read product profile tabs
- `amz_ETL_comment_properties_0IM.R` will fail to read comment property tabs
- All downstream derivations depending on these tables will be blocked

---

## Proposed Solutions

### Option A: Update Product Line tab
Fill in all 12 product lines with names matching the actual tab names (bilingual with fullwidth underscore).

### Option B: Update import function logic
Modify `import_product_profiles()` and `import_comment_properties()` to:
1. Read available tab names from the sheet
2. Match by Chinese prefix (fuzzy match)
3. Use the matched tab name instead of deriving it from `product_line_name_chinese`

### Option C: Add tab_name column to Product Line
Add a dedicated `tab_name` column to the Product Line tab that stores the exact Google Sheets tab name for each product line.

---

## Related

- `app_config.yaml`: `etl_sources.product_profiles`, `etl_sources.comment_properties`
- DM_R037 v3.0: Config-Driven Import
- `/setup-etl-source` skill: Mode B batch scan
