# ETL Import: Remove Suffix, Config-Driven Import

**Date**: 2026-02-06
**Type**: Refactor + Architecture Decision
**Principles**: DM_R037 v3.0, DM_R028, MP064, MP099

## Summary

Migrated AMZ ETL 0IM scripts from `___SOURCE_TYPE_VERSION` filename suffix (DM_R037 v2.0) to config-driven import (DM_R037 v3.0). Source type and version metadata now lives exclusively in `app_config.yaml`.

## Changes

### 1. Renamed 10 0IM Files (removed suffix)

| Before | After |
|--------|-------|
| `amz_ETL_sales_0IM___excel_v1.R` | `amz_ETL_sales_0IM.R` |
| `amz_ETL_keys_0IM___excel_v1.R` | `amz_ETL_keys_0IM.R` |
| `amz_ETL_product_profiles_0IM___gsheets_v1.R` | `amz_ETL_product_profiles_0IM.R` |
| `amz_ETL_competitor_ids_0IM___gsheets_v1.R` | `amz_ETL_competitor_ids_0IM.R` |
| `amz_ETL_comment_properties_0IM___gsheets_v1.R` | `amz_ETL_comment_properties_0IM.R` |
| `amz_ETL_reviews_0IM___excel_v1.R` | `amz_ETL_reviews_0IM.R` |
| `amz_ETL_competitor_sales_0IM___excel_v1.R` | `amz_ETL_competitor_sales_0IM.R` |
| `amz_ETL_keepa_0IM___excel_v1.R` | `amz_ETL_keepa_0IM.R` |
| `amz_ETL_demographic_0IM___csv_v1.R` | `amz_ETL_demographic_0IM.R` |
| `amz_ETL_sku_mapping_0IM___excel_v1.R` | `amz_ETL_sku_mapping_0IM.R` |

### 2. Updated Script Internals

Each 0IM script now:
- Header references `DM_R037 v3.0` instead of `DM_R037(revised)` or `DM_R037: Source-Type + Version`
- Reads ETL profile from `app_config.yaml` via `get_platform_config("amz")`
- Logs `PROFILE: source_type=..., version=...` at initialization
- DEINITIALIZE message uses standard filename (no suffix)

### 3. Updated app_config.yaml

All `source_type` and `version` values changed from UPPERCASE to lowercase:
- `"EXCEL"` → `"excel"`, `"GSHEETS"` → `"gsheets"`, `"CSV"` → `"csv"`
- `"V1"` → `"v1"`

### 4. Updated DM_R037 Principle (v2.0 → v3.0)

- Removed `___SOURCE_TYPE_VERSION` suffix convention
- Added Config-Driven Import pattern
- Maintained backward compatibility for legacy `___MAMBA` suffixes

### 5. Customer Identification (amz_ETL_sales_2TS.R)

Added three-strategy customer identification:
- **Strategy A**: `customer_email` (when available, e.g., cbz/eby)
- **Strategy B**: `ship_postal_code::ship_address` composite key (for Amazon)
- **Strategy C**: Keep existing `customer_id` (fallback)

The composite key format `"zipcode::address"` is passed to `get_or_create_customer_ids()` which accepts any string identifier.
When street-level address is unavailable, script falls back to the next address-like field (including `ship_city`) and logs which column was used.

## Design Rationale

| Decision | Reason |
|----------|--------|
| Remove suffix from filenames | Source metadata belongs in config, not filenames |
| Use `get_platform_config()` | Existing function, no new code needed |
| Lowercase in config | Consistent with YAML conventions |
| zipcode+city for AMZ | Amazon Excel exports lack customer_email and ship_address_1 |
| Strategy in 2TS not 0IM | MP064: 0IM only imports; identity is standardization logic |

## Verification

```bash
# No suffix files remain (excluding archive)
ls ETL/amz/*___*.R  # should be empty

# No UPPERCASE source types in scripts
grep -r 'EXCEL_V1\|GSHEETS_V1\|CSV_V1' ETL/amz/  # should be 0

# No UPPERCASE in config
grep -E '"(EXCEL|GSHEETS|CSV|V[0-9])"' app_config.yaml  # should be 0

# Syntax check all modified files
for f in ETL/amz/amz_ETL_*_0IM.R ETL/amz/amz_ETL_sales_2TS.R; do
  Rscript -e "parse('$f')" && echo "OK: $f"
done
```
