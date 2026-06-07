# amz-sales-pilot-execution — Section 3 Bridge Run Verification

> **Spectra change**: `amz-sales-pilot-execution` Section 3
> **Date**: 2026-05-12
> **Branch**: `idd/amz-sales-pilot-execution-resume` (rebased fresh from `idd/fix-amz-order-id-pattern-permissiveness`)
> **Verdict**: ✓ PASS — bridge runtime end-to-end functional

## Bridge runtime verification

Re-ran `fn_glue_bridge` against amz/sales bridge yaml + 26 monthly xlsx data with all 6 glue-layer fixes in place (#628 / #630 / #631 / #632 / #633 / #634):

| Metric | Value | Verdict |
|---|---|---|
| Input rows (26 xlsx combined) | 294,526 | ✓ |
| After pre_filter (Cancelled/Pending/quantity=0) | 281,919 | ✓ |
| INSERT to df_amz_sales___raw | **281,919 rows** | ✓ (within 0.05% of baseline 281,784) |
| S01-prefixed rows inserted | **392** | ✓ (was 0 pre-fix) |
| Validation errors | 0 | ✓ |
| CHECK constraint violations | 0 | ✓ |
| NOT NULL constraint violations | 0 | ✓ |
| Bridge wall time | ~2.8s | ✓ (far below 1-hour Risk 3 cutoff) |

## Section 3 task outcomes

| Task | Status | Detail |
|---|---|---|
| 3.1 Bridge yaml shape verify | ✓ PASS | sales.bridge.yaml uses `field_extractors:` v2 form; no `column_mapping:`; 20 extractors + 2 pre_filter entries + value_map for amz_fulfillment_channel; surgical-merged with pilot's 4 added extractors (total_amount/platform_id/import_timestamp/import_source) |
| 3.2 fn_glue_bridge against 26 xlsx | ✓ PASS | df_amz_sales___raw produced with canonical schema; 281,919 rows |
| 3.3 Canonical schema verify | ✓ PASS | Columns include canonical names (order_id, customer_id, product_id, etc) not source-original (amazon_order_id only as amz_amazon_order_id extension); S01-class Seller-Fulfilled IDs accepted per #632 fix |

## Ready for Section 4-7

Pilot is now blocked only on the code-editing work in next session:

| Section | Tasks | Estimated effort |
|---|---|---|
| Section 4 | Trim 1ST (249→~125 lines) + 2TR (367→~110 lines) + sister script verify | 2-3 hr code editing |
| Section 5 | Archive 0IM R script to 99_archived/legacy_etl_pre_glue/ | 10 min |
| Section 6 | Post-migration baseline + transformed-layer diff verify | 30 min |
| Section 7 | IC_P002 cross-co + atomic commit + close #627 | 30 min |

## Branch state

- `kiki830621/ai_martech_global_scripts` `idd/amz-sales-pilot-execution-resume` (commit `80032634` — rebased base from fix-amz-order-id-pattern-permissiveness; sales.bridge.yaml has all 6 fixes + surgical-merged pilot additions)
- `kiki830621/ai_martech_update_scripts` `idd/amz-sales-pilot-execution` (commit `58cb72f` — Tier A archive from earlier; 1ST/2TR/0IM/2TS/time_series_2TR all still in ETL/amz/ untrimmed)

## Cross-references

- **Pilot change**: `openspec/changes/amz-sales-pilot-execution/`
- **All 6 blockers closed**: #628 / #630 / #631 / #632 / #633 / #634
- **End-to-end fix change**: fix-amz-order-id-pattern-permissiveness (archived 2026-05-12)
