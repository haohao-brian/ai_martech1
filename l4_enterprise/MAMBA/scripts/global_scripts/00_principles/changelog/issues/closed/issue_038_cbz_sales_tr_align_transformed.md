---
title: "CBZ Sales 2TR: Align transformed schema and financial fields"
app: "mamba"
status: "active"
created: "2025-12-23"
owner: "principle-coder"
tags: ["ETL", "2TR", "schema", "cbz", "sales", "DM_R041", "MP064"]
---

## Summary
- `cbz_ETL_sales_2TR.R` initially missed required fields (`product_name`, `unit_price`, `line_total`) from `transformed_schemas.yaml#sales_transformed`.
- I added mappings/derivations:
  - `product_name` <- `title`
  - `unit_price` <- `price` (fallback: `total_price_after_discounts / quantity`)
  - `line_total` <- `total_price_after_discounts` (fallback: `quantity * unit_price`)
- After rerun via `targets::tar_make()`, required fields are present; D01 derivation succeeds.
- Outstanding warning: 543 records where `line_total != quantity * unit_price` because line_total currently maps to `total_price_after_discounts` (includes discounts/tax effects). Schema expects `line_total = quantity × unit_price`.

## Impact / Risk
- Schema validation now passes for presence but financial consistency check warns.
- DRV/D01 runs and writes outputs; however, downstream calculations expecting `line_total = qty × unit_price` may see discrepancies if discounts/taxes are folded into `total_price_after_discounts`.

## Proposed Fix
- Realign financial fields per schema intent:
  - `unit_price`: net unit price before discounts.
  - `line_total`: `quantity * unit_price`.
  - Introduce `discount_amount` when `total_price_after_discounts` differs (if source supports).
  - Optionally map `tax_amount` if available.
- Keep mapping paths documented for CBZ API fields; verify upstream 0IM/1ST availability of `price`, `total_price_after_discounts`, `quantity`.

## Repro
1) Run `Sys.setenv(R_PROCESSX_IGNORE_CLEANUP='1'); targets::tar_make()` after invalidate.
2) Observe ETL 2TR log: `⚠️ Found 543 records where line_total != quantity × unit_price`.
3) Validation now reports `Present required fields (15/15)`; D01 completes with ~807 rows.

## Files
- `scripts/update_scripts/ETL/cbz/cbz_ETL_sales_2TR.R` (mapping added)
- `scripts/global_scripts/00_principles/docs/en/part2_implementations/CH07_database_specifications/etl_schemas/transformed_schemas.yaml` (schema definition)

## Next Steps
- Decide on financial field alignment strategy and implement in `cbz_ETL_sales_2TR.R`.
- Re-run targets to ensure warnings are resolved and financial consistency holds.
