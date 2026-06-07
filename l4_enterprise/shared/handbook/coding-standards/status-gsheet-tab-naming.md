# Status Gsheet System-Managed Tab 命名標準

> **適用範圍**: 所有由 ETL pipeline 自動寫入 Status Gsheet 的 system-managed tabs(例:`_sys_anomalies`、`_sys_missing_master`、`_sys_drift`、`_sys_mapping_gaps`)
>
> **與 [`sheet-naming-convention.md`](sheet-naming-convention.md) 的職責邊界**:本檔規範 **system 寫入** 的 tabs(寫者是 ETL),那份規範 **業務維護** 的 source tabs(寫者是業務在 Google Sheet 直接編輯)。兩者格式不同、規則不同。

## Sheet-level naming(整本 Google Sheet 檔名)

Status Gsheet 整本 Sheet 檔名遵循既有 source-sheet convention `{role}_{COMPANY}`:

```
status_{COMPANY}
```

| Surface | Sheet name 範例 | 寫者 |
|---|---|---|
| Source(coding) | `coding_QEF_DESIGN` | 業務 |
| Source(KEYS) | `KEYS_QEF_DESIGN` | 業務 |
| Master | `master_QEF_DESIGN` | 業務 |
| **Status** | **`status_QEF_DESIGN`** | **ETL(本規範對象)** |

新公司複製貼上時直接替換前綴:`status_MAMBA`、`status_D_RACING`、`status_WISER`、`status_kitchenMAMA`。

### Sheet description(建議)

建立 Sheet 時在 file description 寫:

> 此 Sheet 由 ETL 自動產生,人工修改會在下次 ETL 跑完時被覆寫。
> 看完後請去 KEYS.xlsx / Master Gsheet / coding sheet 改源頭資料(每個 tab 的 `suggested_action` 欄會告訴你改哪)。
> Tab 命名規則見 handbook `coding-standards/status-gsheet-tab-naming.md`。

### Share 設定

- 把 ETL service account(目前 `kiki830621@gmail.com`)加為 **Editor**(寫入需要)
- 業務 viewer 視需要再加(`anyone-with-link` viewer 通常足夠)

## Tab-level naming 格式

```
_sys_{snake_case_concept}
```

- `_sys_`:強制前綴(底線開頭),區隔 system 寫入的 tab 與業務可能新增的 tab
- `{snake_case_concept}`:英文 snake_case,descriptive 概念名,複數形(因為 row 是「multiple instances of」概念)

## 範例

| 概念 | Tab 名稱 |
|------|----------|
| 仲裁衝突與 System-Sourced overrides | `_sys_anomalies` |
| Sales 看到的 (sku, asin) 在 master 缺對應 row 或無 product_line | `_sys_mapping_gaps` |
| System-Sourced 欄位的 snapshot 變動 | `_sys_drift`(legacy 單數,新增 tab 一律用複數) |
| Sales 看到 SKU 但 master 完全沒對應 row(legacy,即將被 `_sys_mapping_gaps` 取代) | `_sys_missing_master`(legacy 單數)|

## 規則

1. **`_sys_` 前綴強制** — 業務看到 `_sys_` 開頭就知道是 system 寫的,不該手動編輯;同時讓業務若要新增手動 tab,可確保不撞名
2. **snake_case 英文** — 不用 kebab-case(避免與 source tab 規範混淆)、不用 CamelCase、不用中文
3. **複數慣例** — 新增 tab 一律用複數(`mapping_gaps`、`anomalies`)。Row 是 instance,tab 是 collection
4. **不放 marketplace 或 company suffix** — Status Gsheet 本身就是 per-company,marketplace 是 row 內欄位;不要寫 `_sys_anomalies_qef_amz_us`
5. **保留底線給概念分隔** — `mapping_gaps` 不寫 `mappinggaps`;但避免無意義底線堆疊

## 為什麼

Status Gsheet 既有 tabs 是 ad-hoc 命名:

```
_sys_anomalies      ← 複數
_sys_missing_master ← 單數
_sys_drift          ← 單數
```

新增 tab(`_sys_mapping_gaps`)時若不立 convention,會繼續累積不一致。本標準把「複數慣例」與「`_sys_` 前綴強制」明文化,作為**新增 tab 的必要規則**。

既有單數 tabs 不強制改名(避免 churn 影響業務 muscle memory);改名只在 deprecate 時順便做(例:`_sys_missing_master` 將被 `_sys_mapping_gaps` 取代,直接消失,不需先改成 `_sys_missing_masters`)。

## 怎麼新增 tab

1. 在 `shared/global_scripts/05_etl_utils/<platform>/fn_write_status_gsheet.R` 的 `tabs` default 加 entry:
   ```r
   tabs <- status_gsheet_config$tabs %||% list(
     anomalies      = "_sys_anomalies",
     missing_master = "_sys_missing_master",
     mapping_gaps   = "_sys_mapping_gaps",  # 新增
     drift          = "_sys_drift"
   )
   ```
2. 在對應 `fn_detect_anomalies.R`(或同層 builder)加 builder function 產出 data.frame
3. 對應 `detect_anomalies()` 回傳 list 加新 element(name 與 tab key 對齊)
4. 寫 unit tests 涵蓋新 tab name 寫入

## 與 source tab convention 的對照

| 面向 | Source tab(業務維護) | System tab(ETL 寫入) |
|------|---------------------|----------------------|
| 寫者 | 業務在 Google Sheet 直接編輯 | ETL 透過 `googlesheets4::sheet_write` |
| 格式 | `{product_line_id}_{english-name-kebab}` | `_sys_{snake_case_concept}` |
| 大小寫 | kebab-case 連字號 | snake_case 底線 |
| 前綴 | product_line_id | `_sys_` |
| 規範文件 | [`sheet-naming-convention.md`](sheet-naming-convention.md) | 本檔 |

兩個 convention 在大小寫上故意不同,業務看到 tab 名第一個字元就能判斷該不該手動編輯。
