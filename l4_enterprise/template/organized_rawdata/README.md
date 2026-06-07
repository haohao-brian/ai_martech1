# template/organized_rawdata/

新公司 onboarding 的 rawdata 範本目錄。`/new-company` skill 會 copy 此目錄到 `<NEW_COMPANY>/data/local_data/rawdata_<NEW_COMPANY>/`。

## 檔案說明

| 檔案 | 用途 | Onboarding 後應該的狀態 |
|---|---|---|
| `KEYS.xlsx` | 產品線 / SKU / ASIN / 成本 / 利潤 master,各公司業務自填 | **0 data rows + 7-col header schema only**(ProductLine / 產品名稱 / 網址 / ASIN / SKU / 成本 / 利潤);本範本檔本身應保持空白 |
| `產品KEYS命名規範說明書.docx` | KEYS.xlsx 的命名與填寫規範文件 | 不變 |
| `資料夾命名規範說明書.docx` | rawdata 子資料夾(amazon_review / amazon_sales / official_website_sales)命名規範 | 不變 |
| `amazon_review/`, `amazon_sales/`, `official_website_sales/` | 業務各自把對應 platform 的 raw export 放這裡 | 視業務有無實際資料而定 |

## ⚠️ KEYS.xlsx 規則(MP029 No Fake Information)

**範本端**:
- `template/organized_rawdata/KEYS.xlsx` **必須是空白資料**(0 rows + header)
- **絕不**含任何真實 customer / company-specific 產品 row
- 範例與規範寫進 `產品KEYS命名規範說明書.docx`,**不**寫進 `KEYS.xlsx`(因為 xlsx 會被 `/new-company` skill copy 到新公司)

**Onboarding 端**:
- `/new-company` skill 在 copy template 後會自動跑 sanity check:
  - 若 new company 的 `KEYS.xlsx` 含 > 0 rows → AskUserQuestion 三選項(Truncate / Keep / Cancel)
  - 預設 Truncate(default-correct,因為範本理應是空的)
  - Keep 留給罕見的「我已自填」場景
  - Cancel 用於 onboarding 流程要重來

## 歷史污染 incident(2024-11-20 ~ 2025-08-22)

舊版 template 曾經內含一筆 `Electric Can Opener` 範例 row(來自 kitchenMAMA 的真實產品)。導致 4 公司(QEF_DESIGN / D_RACING / WISER / kitchenMAMA)的 KEYS.xlsx 都出現該 row。事件由 #438(QEF instance)發現,#477 修復:

- Template 已清乾淨(本目錄當前 KEYS.xlsx 是 0 rows)
- 3 公司(QEF / D_RACING / WISER)的歷史殘留已 truncate
- kitchenMAMA 的 row 是真實產品,保留不動
- `/new-company` skill 加 sanity check 防再發生

## 相關原則

- **MP029** No Fake Information:範本不該帶真實 customer data
- **IC_P002** Cross-Company Verification(2026-04-25):任何 template 改動需 verify 對所有公司影響中性
- **DEV_R050** Display data externalized:同精神延伸到「資料 placeholder externalize 到文件,不該住在 xlsx 中」

## 維護

新增 / 修改 template 內容請走 IDD flow:
- 開 issue → diagnose → 改 → cross-company verify → close
- 改完 README.md 同步寫進 close summary
