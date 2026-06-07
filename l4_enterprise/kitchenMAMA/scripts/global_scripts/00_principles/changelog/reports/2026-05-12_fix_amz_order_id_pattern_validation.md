# fix-amz-order-id-pattern-permissiveness — Pattern Validation Report

> **Spectra change**: `fix-amz-order-id-pattern-permissiveness` Section 4
> **Date**: 2026-05-12
> **Author**: Claude (autonomous /spectra-apply)
> **Decision basis**: design **Decision 5: Pattern test 對 294,526-row dataset** + **AC-5** + **Risk 1: Pattern change 對既有 legitimate IDs 有 false positive** mitigation

## Test setup

| Item | Value |
|---|---|
| Test data | 26 monthly xlsx files (2024-01 through 2026-02) |
| Source path | `QEF_DESIGN/data/local_data/rawdata_QEF_DESIGN/amazon_sales/` |
| Total rows | 294,526 |
| Test field | `amazon-order-id` (Amazon All Orders Report source column) |
| Pattern (old) | `^[0-9]{3}-[0-9]{7}-[0-9]{7}$` (FBA-only) |
| Pattern (new) | `^[A-Z0-9]{3}-[0-9]{7}-[0-9]{7}$` (FBA + Seller-Fulfilled) |

## Results

| Category | Count | Target | Pass |
|---|---:|---|---|
| **Newly accepted (S01-class)** — match new but not old | 402 | ~402 | ✓ |
| **False positives** — match old but not new (regression check) | 0 | 0 | ✓ |
| **Preserved FBA IDs** — match both | 294,124 | ~294,124 | ✓ |
| **Still rejected** — neither | 0 | n/a | ✓ |

## Verdict

✅ **Pattern fix correctly addresses S01-prefixed Seller-Fulfilled order IDs (#632) with zero regression on FBA IDs.**

## Sample newly-accepted values

```
S01-9374228-6992767
S01-2989556-7060363
S01-5128292-0300567
S01-1378234-5926903
S01-9371425-0401213
```

All 402 newly-accepted values have the same `S01-<7 digits>-<7 digits>` Seller-Fulfilled format. No other prefix variants observed in the 26-month dataset (good signal that `[A-Z0-9]{3}` strict-superset is sufficient; doesn't need wider relaxation).

## AC verification

| AC | Result |
|---|---|
| AC-5 Pattern validation against 294,526-row dataset | ✓ PASS — 0 false negatives (all 402 S01 PASS), 0 false positives (no FBA reject) |

## Cross-references

- **Spectra change**: `openspec/changes/fix-amz-order-id-pattern-permissiveness/`
- **Source bug**: #632
- **Test script**: `/tmp/validate_pattern.R` (transient — recoverable from this report's logic)
- **Authoring yaml**: `01_db/raw_schema/_authoring/platform_extensions/amz_extensions.yaml` (`amz_amazon_order_id.pattern`)
- **Generated DDL**: `01_db/raw_schema/_generated/platforms/amz/sales.sql` (CHECK regex updated by `_build.R`)
