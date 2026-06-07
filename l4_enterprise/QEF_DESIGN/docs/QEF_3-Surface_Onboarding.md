# QEF Master / Status / DuckDB 三 Surface 操作指南

> 給 QEF_DESIGN 業務團隊閱讀的文件。
> 對應 spectra change `qef-gsheet-three-surface-redesign`(2026-04-26)。
> 落實 MP155 Minimize Human Input 原則。

---

## 1. 一張圖看懂三個 Surface

```
+---------------------------------------------------------------+
|                                                               |
|   [Master Gsheet]   <----  業務唯一輸入點  ----+              |
|   Human-Decided     |  product_line_id, brand, ...           |
|   editable          |                                        |
|                     |                                        |
|         |           |        Status Gsheet 出現異常          |
|         |           |        ↓ 看 suggested_action           |
|         | (ETL 讀)  |        ↓ 業務動作                       |
|         v           |                                        |
|                     |                                        |
|   [DuckDB]          |   [Status Gsheet]                      |
|   Source of Truth   --->  System-Suggested  ---> view-only   |
|   ETL pipeline       |    auto-refresh (daily)               |
|   write              |    anyone-with-link viewer            |
|                                                              |
+---------------------------------------------------------------+
```

| Surface | 你能做什麼 | 你不該做什麼 |
|---------|-----------|-------------|
| **Master Gsheet** | 補 / 改 Human-Decided 欄位 (product_line_id、brand、cost、...) | 不要再手填 ASIN、product_name (改從 sales 資料 derive) |
| **Status Gsheet** | 看異常清單、看 `suggested_action` 文字、把 link 分享給老闆 / 審計 | 不要試著編輯 (view-only)、不要等系統發通知 (沒設計通知) |
| **DuckDB** | (不用直接看) 是系統內部資料庫 | (內部用,沒對外介面) |

---

## 2. 你的工作流程怎麼變

### 變化前

```
業務:每月維護 Master Gsheet 整張表 (含 ASIN、product_name、brand、cost、...)
   |
   v
ETL:讀 Master Gsheet → 寫進系統
   |
   v
問題:ASIN 寫錯 / 漏寫 → 系統 silent override sales 的正確值 → 報表錯
```

### 變化後

```
業務:每月只維護 Master Gsheet 的 Human-Decided 欄位
                                   (product_line_id、brand、cost、...)
                                   ASIN / product_name 不用再手填
   |
   v
ETL:讀 Master Gsheet (Human-Decided) + 讀 sales 資料 (System-Sourced)
    → 系統 derive ASIN / product_name
    → 衝突時優先採 sales 端 (系統 ground truth) 不被業務手填覆蓋
   |
   v
偶發:出現 missing-master / brand 建議值 / 衝突
    → 寫進 Status Gsheet
    → 業務想看時打開 link,讀 suggested_action 補資料到 Master
```

---

## 3. 異常出現時 SOP

```
打開 Status Gsheet (link 在 app_config.yaml 裡)
   |
   v
看哪個 tab 有新行:
   _sys_anomalies      → 系統建議值 vs 業務值不一致
   _sys_missing_master → sales 有此 SKU 但 Master 沒對應 row
   _sys_drift          → System-Sourced 欄位最近變動 (通常是 sales 端調整,可不動作)
   |
   v
看 suggested_action 欄文字 (例:「Master Gsheet 補上 SKU=ABC 的 brand 為 X」)
   |
   v
打開 Master Gsheet,在對應位置補 / 改資料
   |
   v
等下次 ETL 跑完 (daily),Status Gsheet 該行異常自動消失
```

**要注意的地方**:

- ❌ Status Gsheet **沒有**「同意 / 拒絕」按鈕。改資料一律回 Master Gsheet。
- ❌ 系統**不會**主動發 email / Slack 通知。你想看就看。
- ❌ 「SKU to ASIN」tab 不再使用 (改名為 `_archive_sku_to_asin_legacy_2026-04`),歷史保留可查,但不要再維護。
- ✅ Status Gsheet 的 link 可以分享給老闆 / 審計;view-only,不需要加帳號。

---

## 4. Audit CSV (季度產出,自助查詢)

季度跑一次:

```bash
cd QEF_DESIGN
Rscript scripts/audit_qef_master_drift.R
```

產出位置:`QEF_DESIGN/data/audit_reports/qef_master_drift_<YYYY-MM>.csv`

CSV 欄位:

| 欄位 | 意義 |
|------|------|
| audit_date | 跑 audit 那天 |
| sku | 商品 SKU |
| marketplace | 平台 (amz_us 等) |
| field | 比較的欄位名 (例 amz_asin) |
| gsheet_value | Master Gsheet 上業務手填的值 |
| xlsx_value | KEYS.xlsx 內的值 |
| sku_asin_value | SKUtoASIN.xlsx 內的值 |
| distinct_values | 三個來源不同值用 `|` 分隔 |
| delta_indicator | DIFFERS = 不一致 |

業務可拿這份 CSV 跟老闆 / 審計討論「以前手填」vs「現在系統 derive」差多少。

---

## 5. 業務需要做的一次性動作 (Phase 2 onboarding,完成後本段可刪)

> 這些動作完成後,Phase 2 才算真的 ship。系統部分 (Phase 1 shared infrastructure + Phase 2 code) 已就緒。

### 5.1 建立 QEF Status Gsheet

1. 在 Google Drive 建一個新 Google Sheet,命名為 `QEF Master Status (System-Suggested)`
2. 在 sheet 內手動建以下三個 tab (空白即可,系統會自動寫):
   - `_sys_anomalies`
   - `_sys_missing_master`
   - `_sys_drift`
3. 點右上角「共用」,改為「知道連結的任何人」+「檢視者」(view-only)
4. 從 URL 取得 sheet_id (網址 `/d/` 後面那串)
5. 把 sheet_id 填進 `QEF_DESIGN/app_config.yaml` `platforms.amz.etl_sources.status_gsheet.sheet_id`,把 `"TBD"` 取代

### 5.2 整理 Master Gsheet

1. 開啟 Master Gsheet (sheet_id `1istNxsgutIfTC9faLM7HdsQzfnphHXLXtahGKYN5oCA`)
2. 找「SKU to ASIN」tab,**右鍵 → 重新命名** 為 `_archive_sku_to_asin_legacy_2026-04`
   - 不要刪除!保留歷史可查 (MP030 archive immutability)
3. 找 `product_profile_<line>` 各 tab (例 `product_profile_rpl`):
   - 把 `amz_asin` 欄整欄刪除 (改從 sales derive)
   - 把 `product_name` 欄整欄刪除 (同上)
   - 其他欄保留 (product_line_id、brand、cost、profit、...)
4. (選用) 在 Master Gsheet 加個 `_admin_dropdowns` tab,把 product_line_id / brand / status 的合法選項列出來,方便 data validation

### 5.3 跑一次 baseline audit + 觀察 Status Gsheet 一週

```bash
cd QEF_DESIGN
Rscript scripts/audit_qef_master_drift.R
# 預期產出:data/audit_reports/qef_master_drift_2026-04.csv

# 跑下一次 ETL (含 Status writeback)
make run PLATFORM=amz
# 完成後到 Status Gsheet 確認三個 tab 有資料
```

業務 review Status Gsheet 一週,如果發現有 `_sys_anomalies` 持續累積,代表還有 data quality issue 要處理。

---

## 6. Rollback Runbook (如需回退本 change)

> 用得到才看;一般情況不會用。

### Phase 1 (shared infrastructure) rollback

```bash
cd shared/global_scripts
git revert 4599f08  # the Phase 1 commit
git push
```

效果:`field_class` schema 仍在 yaml,但 R code 退回 v1 行為。所有 field 走 default Human-Decided。

### Phase 2 (QEF apply) rollback

1. 還原 Master Gsheet:
   - 在 Master Gsheet 把 `_archive_sku_to_asin_legacy_2026-04` 改回 `SKU to ASIN`
   - 在 product master 各 tab 把 `amz_asin` / `product_name` 欄重新加回 (從 audit CSV 復原值)
2. 還原 `QEF_DESIGN/app_config.yaml`:
   - 移除 `platforms.amz.etl_sources.status_gsheet` section
3. (選用) 刪除 Status Gsheet (Google Sheet)
4. (選用) 刪除 audit CSV (`QEF_DESIGN/data/audit_reports/`)

### Phase 3 (cross-company verification) rollback

無需動作 - Phase 3 沒有修改 4 公司任何檔案。

### 完整還原需要的 git revert 順序

```bash
# 1. l4_enterprise repo (QEF_DESIGN/app_config.yaml + QEF_DESIGN/scripts/audit_*)
cd /path/to/l4_enterprise
git revert <l4-commit-sha>

# 2. update_scripts subrepo (amz_ETL_company_product_master_0IM.R 加的 Status writeback hook)
cd shared/update_scripts
git revert <update-commit-sha>

# 3. global_scripts subrepo (Phase 1 infrastructure)
cd ../../shared/global_scripts
git revert 4599f08
```

---

## 7. ASIN 從 sales + catalogue derive 後業務看到什麼(Track C, 2026-04-26)

Track C(spectra change `amz-sales-derive-sku-asin`)正式落實「`amz_asin` 由系統 derive,不再由 KEYS.xlsx 主導」。

### 7.1 `_sys_anomalies` tab 多了什麼 row 類別

`review_action` 欄位新增一個 value:

| review_action | 來源 | 意義 |
|---|---|---|
| `route_to_status_gsheet`(原有) | System-Suggested 欄位 | 系統猜的 brand/cost,需要業務確認到 Master Gsheet |
| `system_sourced_override`(新) | sales / catalogue 與 KEYS.xlsx 不一致 | 系統觀察到的 ASIN 跟 KEYS.xlsx 記的不同 |

`system_sourced_override` row 的 `suggested_action` 文字會明確列出兩方值,例如:

> System-Sourced 衝突: sales 來源觀察到 amz_asin='B07SALES99',但 KEYS.xlsx 記錄為 'B07XLSX001'。請更新 KEYS.xlsx 改成 'B07SALES99' (若 sales 是對的) 或在 Master Gsheet 對應 row 標 status='trial' (若 KEYS 是對的、sales 為臨時值)。

### 7.2 業務該如何 review

當你在 `_sys_anomalies` 看到 `system_sourced_override` row 時:

1. 看 `suggested_action` 的兩個 ASIN 值
2. 比對自己的 KEYS.xlsx 該 SKU 的 ASIN 是不是過期了
3. **三選一動作**:
   - **A.** sales/catalogue 觀察到的是對的 → 更新 KEYS.xlsx,把 ASIN 改成系統觀察到的值
   - **B.** KEYS.xlsx 是對的,sales 觀察到的是暫時 promo / trial ASIN → 在 Master Gsheet 對應 (sku, marketplace) row 把 `status` 欄填 `trial`(後續 Track 會讓 trial 不觸發 override)
   - **C.** 兩個都對(同一 SKU 在不同時間綁不同 ASIN,marketplace 區隔)→ 確認 marketplace 欄是否區分,可能是 ETL 沒分 marketplace 就分到一起

### 7.3 trial ASIN 標註方式

Track C Phase 3 沒有實作 trial 排除邏輯(屬未來 Track)。目前 trial 標註只能用作業務內部紀錄,系統暫時還是會把 trial ASIN 當 override row 顯示。

### 7.4 `sales`/`catalogue` source 啟用前提

- `sales` 需要 `transformed_data.duckdb` 的 `df_amz_sales___transformed` 表,且資料 cover 最近 90 天(可改 `app_config.yaml > etl_sources.amz_sales_lookback_days`)
- `catalogue` 需要 `raw_data.duckdb` 的 `df_amz_product_master` 表**且該表有 `sku` column**;QEF 目前的 `amz_ETL_product_profiles_0IM.R` 只 union `amz_asin / marketplace / brand / product_line / product_name`,**沒 sku**,所以 catalogue source 對 QEF 目前回 empty

→ 結果:Track C 啟用後 QEF 主要靠 **sales** source 跟 KEYS.xlsx 做 override 比對

### 7.5 audit CSV 多了兩欄

從 `qef_master_drift_<YYYY-MM>.csv` 開始,業務多看到:
- `sales_value` — sales source 觀察到的 ASIN(per sku, marketplace)
- `catalogue_value` — catalogue source 提供的 ASIN(目前 QEF 全 NA,等 catalogue 加 sku)

差異判斷規則:`sales_value != xlsx_value` 或 `catalogue_value != xlsx_value` 也會列入 drift CSV(不再只有 Gsheet 衝突)

### 7.6 baseline 對比

- Track B 末期:`data/audit_reports/qef_master_drift_<YYYY-MM>.csv`(只有 gsheet/xlsx/sku_asin 欄)
- Track C 啟用後:`data/audit_reports/qef_master_drift_<YYYY-MM>_track-c.csv`(加 sales_value + catalogue_value 欄)

業務可比對兩份 CSV 看「Track C 帶來幾筆新 drift row」。

---

## 8. Mapping Gaps tab 解讀(2026-04-26 新增,Issue #471)

Status Gsheet 新增 `_sys_mapping_gaps` tab,涵蓋「sales 觀察到 (sku, amz_asin) 但 master 無法完整對應到 product_line」的所有 case。**舊的 `_sys_missing_master` 將於下個 release 移除,請改看本 tab。**

### 8.1 表格欄位

| 欄位 | 意義 |
|------|------|
| `sku` | 公司 SKU(若 sales 只有 ASIN 沒有 SKU 則 NA) |
| `amz_asin` | Amazon ASIN(若 sales 只有 SKU 沒有 ASIN 則 NA) |
| `marketplace` | `amz_us` / `amz_ca` 等 |
| `gap_type` | enum:`no_master_row` / `no_product_line` / `...and N more`(cap 摘要) |
| `suggested_action` | 引導業務該到哪個 surface 補資料 |

### 8.2 三種 gap_type 業務動作

| gap_type | 含義 | 業務該做什麼 |
|---|---|---|
| `no_master_row`(SKU 有,ASIN NA) | sales 看到此 SKU 但 KEYS.xlsx + Master Gsheet 都沒對應 row | 到 KEYS.xlsx 加 SKU,到 Master Gsheet 對應 row 補 product_line_id / brand 等 |
| `no_master_row`(SKU NA,ASIN 有) | sales 看到此 ASIN 但 master 完全沒對應 row | 到 Amazon listing 確認 ASIN 對應的 SKU,加進 KEYS.xlsx |
| `no_product_line` | master 有 SKU row 但 `product_line_id` 是 NA | 到 coding sheet 對應 `product_profile_<line>` tab 加入此 SKU 對應的 ASIN(讓 catalogue 能 derive) |

### 8.3 Phase 1 涵蓋範圍

本 change(Phase 1)**只**抓 SKU-keyed 兩種 gap:
- `no_master_row`(SKU-keyed)
- `no_product_line`(SKU-keyed)

**不抓**(Phase 2 等 #469 解決後再補):
- ASIN-keyed `no_master_row`(catalogue 補 SKU 欄後可加)
- `sku_asin_mismatch`(sales 與 master 的 (sku, asin) 配對不一致)

### 8.4 與舊 `_sys_missing_master` 的關係

並存 1 release cycle:
- 舊 `_sys_missing_master` 仍會寫(維持業務 muscle memory)
- 新 `_sys_mapping_gaps` 的 `no_master_row` row 是舊表 superset
- 業務確認新表 OK 後,後續 follow-up issue 移除舊 tab

### 8.5 Cap 行為

當缺漏 ASIN 數量超過 500 時,Status Gsheet 只寫 top 500(依 sales_volume desc),最後 append 一行 `gap_type="...and N more"` 提示有多少筆未寫。完整清單可從 audit CSV 取得(若有需要,聯繫工程團隊)。

---

## 9. 相關文件

- 原則:`shared/global_scripts/00_principles/docs/en/.../MP155_minimize_human_input.qmd`
- 命名規範:`shared/handbook/coding-standards/status-gsheet-tab-naming.md`(`_sys_*` tab 命名標準,2026-04-26 新增)
- Spectra changes:
  - `openspec/changes/qef-gsheet-three-surface-redesign/`(Track B,Phase 1+2 infra)
  - `openspec/changes/amz-sales-derive-sku-asin/`(Track C)
  - `openspec/changes/amz-mapping-gap-detection/`(本 change,Issue #471)
- GitHub issues: #464(QEF research)/ #466(Track B umbrella)/ #467(Track C umbrella)/ #471(本 change)/ #469(Phase 2 dependency)

---

*Section 7 added by `amz-sales-derive-sku-asin` Track C apply (2026-04-26)*
*Section 8 added by `amz-mapping-gap-detection` apply (2026-04-26, Issue #471, task 7.1)*
*Generated by `qef-gsheet-three-surface-redesign` spectra change apply, task 4.2 + 4.3*
