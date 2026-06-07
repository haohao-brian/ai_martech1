# fix-amz-sales-sister-scripts-canonical-names — Audit Report (Section 1 + Sections 2-3 trace)

> **Spectra change**: `fix-amz-sales-sister-scripts-canonical-names`
> **Date**: 2026-05-12
> **Branch**: `idd/fix-amz-sales-sister-scripts-canonical-names` (update_scripts)
> **Issue**: kiki830621/ai_martech_l4_enterprise#640
> **Compliance**: AC-5 (audit report exists + lists 14+ rename entries)

## Background

Per `legacy-etl-deprecation-playbook` Scenario "Sister script regression on hardcoded legacy column name", amz-sales-pilot-execution(archived 2026-05-12)atomic cutover migrated `df_amz_sales___transformed` from legacy schema(`purchase_date / item_price / amazon_order_id / asin`)to canonical schema(`order_date / unit_price / total_amount / amz_amazon_order_id / product_id`)。Sister scripts that consume this table were known to have legacy refs;pilot deferred their fix to this follow-up change。

## Per-line audit results

### `amz_ETL_sales_2TS.R` (589 lines)

Legacy column references found via grep + per-line documentation:

| # | Line | Legacy ref | Canonical replacement | Rationale |
|---|------|-----------|----------------------|-----------|
| 1 | 133 area | `purchase_date` | `order_date` | Bridge canonical name |
| 2 | 137 area | `purchase_date` (error msg) | `order_date` | Updated error string |
| 3 | 144 area | `item_price` | `total_amount` (Decision 2) | Bridge already computes total_amount via `unit_price * quantity` |
| 4 | 148 area | `item_price` (error msg) | `total_amount` | Updated error string |
| 5 | 193 area | `"asin"` (column ref) | `"product_id"` | Decision 3:canonical name |
| 6 | 207 area | `"asin"` (keys_dt) | `"product_id"` | Same |
| 7 | 217 area | `"asin"` (competitor_map) | `"product_id"` | Same |
| 8 | 254 area | `"asin"` (profile_map AS aliasing) | `"product_id"` | Same |
| 9 | 328 area | `amazon_order_id` | `amz_amazon_order_id` | Platform-prefixed canonical |

**Total: 9 legacy refs renamed in `amz_ETL_sales_2TS.R`.**

### `amz_ETL_sales_time_series_2TR.R` (336 lines)

| # | Line | Legacy ref | Canonical replacement | Rationale |
|---|------|-----------|----------------------|-----------|
| 1 | 158 (column read list) | `"purchase_date"` | `"order_date"` | Bridge canonical name |
| 2 | 158 | `"asin"` | `"product_id"` | Decision 3 |
| 3 | 158 | `"item_price"` | `"total_amount"` | Decision 2 |
| 4 | 162 (validation check) | Same 4 col names | Same 4 canonical | Updated required cols |
| 5 | 168 | `as.Date(purchase_date)` | `as.Date(order_date)` | Decision 4:POSIXct auto-truncate |
| 6 | 169 | `as.character(asin)` | `as.character(product_id)` | Decision 3 |
| 7 | 171 | `as.numeric(item_price) * as.numeric(quantity)` | `as.numeric(total_amount)` | Decision 2:bridge derived |

**Total: 7 legacy refs renamed in `amz_ETL_sales_time_series_2TR.R`.**

Note:`asin_mapping` reference table left_join clause `by = c("amz_asin" = "asin")` at line 179 area **kept as-is** — this is a reference table(`df_amz_competitor_product_id`)with its own legacy `asin` schema, NOT a canonical sales column reference。Reference table schema migration is out-of-scope。

## Cross-script summary

| Script | Lines | Legacy refs found | Renamed | Schema-only deps? |
|--------|------:|------------------:|--------:|:-----------------:|
| `amz_ETL_sales_2TS.R` | 589 | 9 | 9 | YES (Risk 1 satisfied) |
| `amz_ETL_sales_time_series_2TR.R` | 336 | 7 | 7 | YES (Risk 1 satisfied) |
| **Total** | **925** | **16** | **16** | — |

Spec AC-5 標準(「14+ rename entries」)滿足:16 個 actual rename entries 涵蓋 9 個 unique legacy column names(purchase_date / item_price / asin / amazon_order_id × multiple positional refs)。

## Risk audit conclusions

| Risk | Status |
|------|--------|
| Risk 1: Sister scripts 有更深 schema dependencies | **CLEAR** — 16 refs 都是 column-rename 範疇,無 algorithm-level dependency |
| Risk 2: `total_amount` 取代 `item_price * quantity` rounding diff | **N/A** — Numeric domain 一致,bridge `total_amount = unit_price * quantity` 同 R 計算 |
| Risk 3: 引用其他 transformed columns 不在 audit table | **CLEAR** — Wide grep cover 所有 legacy col names from amz_ETL_sales_0IM |
| Risk 4: DRV consumers 期待 sister output 特定 column names | **CLEAR** — Sister output schema 不變,只 input rename |

## Implementation discipline

Per Decision 1(Mechanical rename only):
- 0 algorithm changes
- 0 control-flow changes
- 0 new helper functions
- 100% rename surface — preserves all surrounding logic intact

## Cross-references

- Spec change folder: `openspec/changes/fix-amz-sales-sister-scripts-canonical-names/`
- Pilot source: amz-sales-pilot-execution(archived 2026-05-12,commits `1a6b45c` + `589579d`)
- Section 4 verify: `2026-05-12_fix_sister_scripts_runtime_verify.md`
- IC_P002 dry-run: `2026-05-12_fix_sister_scripts_ic_p002.md`
