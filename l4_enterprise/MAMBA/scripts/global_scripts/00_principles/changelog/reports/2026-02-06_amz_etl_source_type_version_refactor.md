# AMZ ETL Source-Type + Version Refactor Report

- **Date**: 2026-02-06
- **Status**: implemented
- **Principles**: DM_R028, DM_R037 (v2.0), DM_R038, MP064, DM_R053

## Summary

Restructured Amazon ETL architecture from mixed numbering + `___COMPANY` suffix to unified datatype naming + `___SOURCE_TYPE_VERSION` suffix. DM_R037 revised from v1.0 to v2.0.

---

## Changes

### 1. New Files (6)

#### Adapter Functions (3)

| File | Description |
|------|-------------|
| `global_scripts/05_etl_utils/adapters/fn_import_adapter_excel.R` | Generic Excel reader via `readxl`, supports directory scanning, column mapping, snake_case standardization |
| `global_scripts/05_etl_utils/adapters/fn_import_adapter_csv.R` | Generic CSV reader via `data.table::fread`, same pattern |
| `global_scripts/05_etl_utils/adapters/fn_import_adapter_gsheets.R` | Google Sheets reader via `googlesheets4`, with retry logic |

#### New ETL Scripts (3)

| File | Source | Output Table |
|------|--------|-------------|
| `ETL/amz/amz_ETL_keepa_0IM___EXCEL_V1.R` | `rawdata/Product sales rank.../keepa-*.xlsx` | `df_amz_keepa` |
| `ETL/amz/amz_ETL_demographic_0IM___CSV_V1.R` | `rawdata/amazon_demographic/*.csv` | `df_amz_demographic` |
| `ETL/amz/amz_ETL_sku_mapping_0IM___EXCEL_V1.R` | `rawdata/SKUtoeBay numbers/SKUtoASIN number.xlsx` | `df_amz_sku_mapping` |

### 2. git mv Renames (19)

#### Archived to `ETL/amz/archive_20260206/` (4)

| Original | Reason |
|----------|--------|
| `amz_ETL01_0IM.R` | Legacy MAMBA API script |
| `amz_ETL001_0IM.R` | Legacy WISER script |
| `amz_ETL001_1ST.R` | Legacy staging |
| `amz_ETL001_2TR.R` | Legacy transform |

#### Suffix Change (2)

| Old | New |
|-----|-----|
| `amz_ETL_sales_0IM___QEF_DESIGN.R` | `amz_ETL_sales_0IM___EXCEL_V1.R` |
| `amz_ETL_keys_0IM___QEF_DESIGN.R` | `amz_ETL_keys_0IM___EXCEL_V1.R` |

#### Number to Datatype Naming (13)

| Old | New |
|-----|-----|
| `amz_ETL03_0IM.R` | `amz_ETL_product_profiles_0IM___GSHEETS_V1.R` |
| `amz_ETL03_1ST.R` | `amz_ETL_product_profiles_1ST.R` |
| `amz_ETL03_2TR.R` | `amz_ETL_product_profiles_2TR.R` |
| `amz_ETL04_0IM.R` | `amz_ETL_competitor_ids_0IM___GSHEETS_V1.R` |
| `amz_ETL04_1ST.R` | `amz_ETL_competitor_ids_1ST.R` |
| `amz_ETL04_2TR.R` | `amz_ETL_competitor_ids_2TR.R` |
| `amz_ETL05_0IM.R` | `amz_ETL_comment_properties_0IM___GSHEETS_V1.R` |
| `amz_ETL05_1ST.R` | `amz_ETL_comment_properties_1ST.R` |
| `amz_ETL05_2TR.R` | `amz_ETL_comment_properties_2TR.R` |
| `amz_ETL06_0IM.R` | `amz_ETL_reviews_0IM___EXCEL_V1.R` |
| `amz_ETL06_1ST.R` | `amz_ETL_reviews_1ST.R` |
| `amz_ETL06_2TR.R` | `amz_ETL_reviews_2TR.R` |
| `amz_ETL07_0IM.R` | `amz_ETL_competitor_sales_0IM___EXCEL_V1.R` |

### 3. Internal Reference Updates (7 renamed 0IM scripts)

| File | Changes |
|------|---------|
| `amz_ETL_sales_0IM___EXCEL_V1.R` | Header, `script_name` variable, messages: `___QEF_DESIGN` -> `___EXCEL_V1`, "Company" -> "Source" |
| `amz_ETL_keys_0IM___EXCEL_V1.R` | Same pattern as above |
| `amz_ETL_product_profiles_0IM___GSHEETS_V1.R` | Header comments updated |
| `amz_ETL_competitor_ids_0IM___GSHEETS_V1.R` | Header, messages: "ETL04" -> "ETL competitor_ids", filename refs |
| `amz_ETL_comment_properties_0IM___GSHEETS_V1.R` | Header, messages: "ETL05" -> "ETL comment_properties", filename refs |
| `amz_ETL_reviews_0IM___EXCEL_V1.R` | Header, messages: "ETL06" -> "ETL reviews", DEINITIALIZE filename ref |
| `amz_ETL_competitor_sales_0IM___EXCEL_V1.R` | Header, messages: "ETL07" -> "ETL competitor_sales", DEINITIALIZE filename ref |

### 4. DRV Dependency Marker Updates (5 files)

| File | Line | Change |
|------|------|--------|
| `DRV/amz/amz_DRV03_segments.R` | :64 | `ETL06` -> `ETL reviews (amz_ETL_reviews)` |
| `DRV/amz/amz_DRV03_insights.R` | :81 | `ETL06` -> `ETL reviews (amz_ETL_reviews)` |
| `DRV/amz/amz_D03_06.R` | :72 | `ETL06` -> `ETL reviews (amz_ETL_reviews)` |
| `DRV/amz/amz_D03_08.R` | :89 | `ETL06` -> `ETL reviews (amz_ETL_reviews)` |
| `DRV/amz/amz_D01_00.R` | :3,:8,:17,:18,:21 | `ETL01 Output` -> `ETL sales Output`; `ETL01 output table` -> `ETL sales output table` |

**Note**: `DRV/backup_DRV_20250929/` backup files were NOT modified.

### 5. Configuration Update

#### `app_config.yaml`

Added `etl_sources` block under `platforms.amz` defining 10 datatypes with source_type, version, and rawdata patterns:

- sales: EXCEL V1
- keys: EXCEL V1
- product_profiles: GSHEETS V1
- competitor_ids: GSHEETS V1
- comment_properties: GSHEETS V1
- reviews: EXCEL V1
- competitor_sales: EXCEL V1
- keepa: EXCEL V1
- demographic: CSV V1
- sku_mapping: EXCEL V1

### 6. Principle Document Update

#### `DM_R037_company_specific_etl_naming.qmd`

Full rewrite from v1.0 to v2.0:

| Aspect | v1.0 | v2.0 |
|--------|------|------|
| Title | "Company-Specific ETL Naming Rule" | "ETL Import Source Naming Rule" |
| Suffix format | `___COMPANY` | `___SOURCE_TYPE_VERSION` |
| Validation regex | `^[A-Z]{3,10}$` | `^[A-Z]{2,10}_V\d+$` |
| Scope | All phases | 0IM phase only |
| Version tracking | None | V1, V2, V3... |
| Backward compat | N/A | Legacy `___MAMBA` etc. still valid |

---

## Not Modified

- All `1ST`/`2TR`/`2TS` scripts: only git mv renamed, internal code unchanged
- `DRV/backup_DRV_20250929/` backup directory: untouched
- `cbz`/`eby` platform ETL and DRV scripts: out of scope

## Verification Results

- 10/10 0IM scripts pass `^[a-z]{3}_ETL_[a-z_]+_0IM___[A-Z]{2,10}_V[0-9]+\.R$`
- 11/11 1ST/2TR/2TS scripts have no `___` suffix
- 0 residual old numbered references (ETL01-ETL07) in DRV/amz/
- 4 legacy scripts properly archived
