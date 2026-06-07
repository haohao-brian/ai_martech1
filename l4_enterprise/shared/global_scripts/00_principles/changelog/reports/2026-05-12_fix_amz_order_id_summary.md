# fix-amz-order-id-pattern-permissiveness — Closing Summary

> **Spectra change**: `fix-amz-order-id-pattern-permissiveness`
> **Date**: 2026-05-12
> **Verdict**: ✓ End-to-end functional. amz-sales pilot fully unblocked.

## Two-axis fix

### Axis 1: Layer 1 schema permissiveness (#632 — original scope)
- `amz_extensions.yaml` amz_amazon_order_id pattern: `^[0-9]{3}-[0-9]{7}-[0-9]{7}$` → `^[A-Z0-9]{3}-[0-9]{7}-[0-9]{7}$`
- description + description_zh updated with S01 example
- DDL regenerated via `_build.R` — `_generated/platforms/amz/sales.sql` CHECK updated

### Axis 2: Runtime translator value_map preservation (#634 — surfaced during apply)
- `fn_glue_bridge.R` inline runtime translator extended with `KNOWN_EXTENSION_FIELDS` whitelist
- Sister bug to #630 in DIFFERENT location (runtime translator vs codegen tool)
- Without this fix, even with #632 + #628 + #630 + #631 all done, amz_fulfillment_channel value_map silently dropped at runtime

## End-to-end verification

amz-sales bridge runtime with all fixes (#628 / #630 / #631 / #632 / #634 / #633):
- Input: 294,526 source rows from 26 monthly xlsx
- After pre_filter (Cancelled / Pending / quantity=0): 281,919 rows
- INSERT to df_amz_sales___raw: **281,919 rows ✓**
- Baseline 281,784 — diff +135 = **0.048%, within ±0.1% tolerance ✓**
- S01-prefixed rows (Seller-Fulfilled): **392 ✓** (was 0 pre-fix)
- 0 CHECK constraint violations ✓
- 0 NOT NULL violations ✓
- 0 validation errors ✓
- Wall time: ~2s (post-fix; far below 1-hour cutoff per Risk 3)

## Files changed

| File | Change |
|---|---|
| `01_db/raw_schema/_authoring/platform_extensions/amz_extensions.yaml` | pattern + description + description_zh updated |
| `01_db/raw_schema/_generated/platforms/amz/sales.sql` | CHECK regex regenerated via `_build.R` |
| `01_db/raw_schema/_generated/companies/QEF_DESIGN/platforms/amz/product_attributes_its.sql` | regenerated (pre-existing yaml drift type=DOUBLE→VARCHAR; ancillary cleanup) |
| `05_etl_utils/glue/fn_glue_bridge.R` | inline runtime translator + #633 ext_path resolution fallback + #634 value_map preservation |
| `00_principles/changelog/reports/2026-05-12_fix_amz_order_id_pattern_validation.md` | Section 4 validation report |
| `00_principles/changelog/reports/2026-05-12_fix_amz_order_id_pattern_ic_p002.md` | Section 6 IC_P002 5公司 verdicts |
| `00_principles/changelog/reports/2026-05-12_fix_amz_order_id_summary.md` | This summary |

## Issues affected

### Closed
- **#632** Canonical schema CHECK pattern too strict for S01 — pattern relaxed + DDL regen
- **#633** fn_glue_bridge ext_path resolution lacks bridges_root-relative fallback — inline fix
- **#634** fn_glue_bridge inline runtime translator drops value_map — inline fix

### Unblocked
- **#627** amz-sales-pilot-execution — now ready to resume from Section 3+ (bridge run + 1ST/2TR trim + diff + IC_P002 + atomic cutover)

### Sister history
- **#628** fingerprint method (closed in fix-glue-layer-infra-blockers)
- **#630** migration tool value_map (closed in fix-glue-layer-infra-blockers)
- **#631** coerce_field coercion (closed in fix-glue-layer-infra-blockers)

## Pilot resume readiness

amz-sales-pilot-execution (#627) was parked at 11/26 with Section 3 INSERT blocked. With this change:
- Section 3: bridge run produces df_amz_sales___raw 281,919 rows ✓
- Section 4: trim 1ST/2TR R scripts (substantial work, ~1-2 hr each)
- Section 5: archive 0IM
- Section 6: transformed-layer diff verify (rowcount tolerance ✓ already proven)
- Section 7: IC_P002 + atomic cutover commit + close #627

## Cross-references

- Pattern validation: `2026-05-12_fix_amz_order_id_pattern_validation.md`
- IC_P002 dry-run: `2026-05-12_fix_amz_order_id_pattern_ic_p002.md`
- Spectra change: `openspec/changes/fix-amz-order-id-pattern-permissiveness/`
- Spec amendment: `glue-era-etl-vocabulary` (production-observed validity scenarios)
