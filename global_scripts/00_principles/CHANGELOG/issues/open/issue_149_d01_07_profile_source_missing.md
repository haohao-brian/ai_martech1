# Issue #149: D01_07 Product Line Coverage Missing Profile Source Data

**Status**: open
**Date**: 2026-02-28
**App**: shared
**Company**: amz
**Component**: D01_derivations
**Severity**: high
**Tags**: `D01_07`, `product_line_coverage`, `duckdb`, `profile_source`

---

## Summary

`amz_D01_07` 產出報表 `product_line_coverage_report_20260228_102550.csv` 時，`A_missing_profile_source` 被記錄到 9 個 product line，表示缺少 profile source 依賴表，導致該 product line coverage 審查失敗。

---

## Root Cause

`scripts/update_scripts/DRV/amz/amz_D01_07_product_line_coverage_audit.R` 會在判斷 profile source 時依賴下列資料表存在：

- `transformed_data` 中 `df_product_profile_<product_line_id>___transformed`
- `transformed_data` 中 `df_amz_competitor_product_id___transformed`
- `raw_data` 中 `df_amz_competitor_product_id`

實測這三類依賴在目前 `duckdb` 集合中皆缺失，導致 `A_missing_profile_source` 被全部命中。

---

## Evidence

### 報表結果

檔案：`/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/D_RACING/output/etl_validation/amz/product_line_coverage/product_line_coverage_report_20260228_102550.csv`

發生 `A_missing_profile_source` 的 product line：

- acc
- cgs
- wgs
- wsg
- csg
- mrn
- mil
- oth
- mnt

上述 8 筆與總結紀錄都顯示 `profile_distinct_asin=0`, `competitor_distinct_asin=0`, `sales_rows=0`, `dna_rows=0`。

### DuckDB 驗證

- `data/local_data/transformed_data.duckdb` 缺少：
  - `df_product_profile_acc___transformed`
  - `df_product_profile_cgs___transformed`
  - `df_product_profile_wgs___transformed`
  - `df_product_profile_wsg___transformed`
  - `df_product_profile_csg___transformed`
  - `df_product_profile_mrn___transformed`
  - `df_product_profile_mil___transformed`
  - `df_product_profile_oth___transformed`
  - `df_product_profile_mnt___transformed`
  - `df_amz_competitor_product_id___transformed`
- `data/local_data/raw_data.duckdb` 缺少：
  - `df_amz_competitor_product_id`
- `data/local_data/processed_data.duckdb`、`data/local_data/cleansed_data.duckdb`、`data/local_data/app_data.duckdb` 中未發現任何 `df_product_profile*` 相似命名表。

---

## Proposed Fix

1. 追溯 D01_07 之前步驟（尤其是 product profile 產生環節）確認該批來源表建立流程是否未執行或條件被跳過。
2. 補上對 `df_product_profile_<pl>___transformed` 與 `df_amz_competitor_product_id` 的前置檢查，並在缺失時提前 fail fast，附明確建議修復步驟。
3. 補齊缺失來源資料的 ETL 實作後，重新跑 D00/D01，確認該報表無 `A_missing_profile_source`。

---

## Verification

- 修正後重跑 amz_D01_07，確認報表不再出現 `A_missing_profile_source`。
- 驗證 `transformed_data` 與 `raw_data` 中上述必要表在輸出完成後存在且有資料。
