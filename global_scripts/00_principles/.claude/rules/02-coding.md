# 寫程式碼時

**使用時機**: 建立或修改 R 腳本時

---

## global_scripts 版本規則 (CRITICAL)

`scripts/global_scripts/` 是 symlink，指向 `l4_enterprise/shared/global_scripts/`。

**修改共用函數時，必須改 shared 版本：**
```
✅ l4_enterprise/shared/global_scripts/08_ai/fn_rate_comments.R
❌ global_scripts/08_ai/fn_rate_comments.R  ← 最上層的是另一份，改了不會生效
```

所有 l4_enterprise 公司（QEF_DESIGN、MAMBA、WISER 等）共用 `shared/global_scripts/`。
最上層的 `global_scripts/` 是獨立的副本，不被 l4_enterprise 使用。

---

## 程式語言選擇 (DEV_R056)

**核心規則**：專案主要語言是 R。新程式碼一律 R 撰寫，除非屬於明文列舉的 exempt 範圍。

### R 範圍（必須用 R）

| 領域 | 路徑 | 檔名 pattern |
|------|------|--------------|
| ETL 腳本 | `update_scripts/ETL/{platform}/` | `{platform}_ETL_{datatype}_{phase}.R` |
| DRV 腳本 | `update_scripts/DRV/` + `16_derivations/` | `all_D{NN}_{NN}.R`、`fn_D{NN}_{NN}_core.R` |
| Shiny 元件 | `10_rshinyapp_components/` | `*UI.R`、`*Server.R`、`*Defaults.R` |
| Schema codegen / 驗證 | `01_db/raw_schema/_build.R`、`validate_*.R` | `*.R` |
| Schema 撰寫工具 | generator(讀來源 → 產 yaml) | `gen_*.R` |
| 測試腳本 | `98_test/` | `test_*.R` |
| 部署輔助 | `23_deployment/03_deploy/` | `*.R` |
| 通用 utility | `04_utils/`、`05_etl_utils/`、`11_rshinyapp_utils/` | `fn_*.R` |

讀 CSV/yaml/Excel + transformation 一律 R(`readr::read_csv` / `yaml::write_yaml` / `readxl::read_excel` / `dplyr`)。

### 各語言範圍

| 語言 | 允許位置 | 禁止 |
|---|---|---|
| **Python** | 僅 `shared/global_scripts/09_python_scripts/`(4 個 NLP/AI 檔案) | 其他位置一律禁止 |
| **Bash** | 部署 wrapper(`bash/`)、OS-level ops、git ops | business logic;部署計算用 `Rscript` invoke |
| **JS/TS** | Shiny custom JS 在 `19_CSS/`、`24_assets/` | 獨立 CLI/build script |

### 三大反 pattern(AI 必須拒絕的合理化)

| 理由 | 反駁 |
|---|---|
| 「Python 寫得快」(Pandas one-liner) | 專案慣例蓋過個別腳本;10 行 Pandas vs 15 行 dplyr 是 rounding error |
| 「我比較熟 Python」(training data bias) | AI 熟悉度不是合法 override;用 `r-docs-guide` skill 學 R |
| 「Python 有那個 library」 | 先驗 R 對等(CRAN 20000+;tidyverse / jsonlite / readxl / survival / quanteda 涵蓋多數場景);**只有** R 沒對等 **且** NLP/AI 才考慮 |

### 強度與 enforcement

| 原則 | 強度 | 機制 |
|------|------|------|
| MP159 / MP160 | Mechanical | Validator CRITICAL |
| **DEV_R056** | **Advisory** | Soft hook(`check-language-discipline.sh`:warning, exit 0) |
| DEV_R052 | Advisory | 無 checker |

Hook gap:Bash-mediated `.py` write(`cat > foo.py`)可能繞過,primary defense 在本檔 + `01-always.md` 的 principle context。

### 邊界擴張流程

擴張 Python 範圍需 (1) spectra change (2) IC_P002 cross-co verify (3) DEV_R056 列舉更新 (4) commit `Verified:` trailer。

完整原則:`docs/en/part1_principles/CH03_development_methodology/rules/DEV_R056_project_primary_language.qmd`(含相關原則 list、觸發 #498)

---

## Schema 範圍分類 (MP161)

**核心規則**:Schema yamls 與 generated DDL **必須**分類為 UNIVERSAL(共用)或 COMPANY-SCOPED(單家公司),且**從檔案路徑可見**。

### 路徑分類

| 範圍 | Authoring 路徑 | DDL 輸出路徑 | 範例 |
|------|---|---|---|
| **Universal** | `_authoring/core_schemas.yaml`、`_authoring/platform_extensions/`、`_authoring/_meta_schema.yaml`、`_authoring/transformed_schemas.yaml`、`_authoring/r_definitions/` | `_generated/{core,platforms}/` | sales / customers / orders / products / reviews |
| **Company-Scoped** | `_authoring/companies/{COMPANY}/{schema,translation}.yaml`、`companies/{COMPANY}/gen_*.R` | `_generated/companies/{COMPANY}/platforms/{platform}/` | `companies/QEF_DESIGN/product_attribute_schemas.yaml` |

目前只有 `QEF_DESIGN` 有 company-scoped schemas(12 個 per-PL 屬性 datatypes);其他 4 公司只用 universal。

### 決策準則

**核心問題**:「如果另一家公司明天加入,他們會不會用一模一樣的 shape?」 — YES → Universal;NO → Company-scoped。

### Promotion / Demotion

分類需改變時走 spectra change(不可悄悄移檔):2nd 公司採用 → promote;發現只 1 家用 → demote。流程含 IC_P002 verify + commit `Verified:` trailer 列 5 公司。

### 反 pattern

(A) company-scoped 放 universal 路徑;(B) universal 放 company 路徑(藉口「只有一家用」);(C) DDL 輸出路徑與 source 不一致;(D) 缺 `companies/` 前綴。

### 例外

`company_product_extension` 留 universal(目前只 QEF,但 fields 是 generic accounting 概念,Chinese source col 名活在 QEF bridge column_mapping)。`bridges/{COMPANY}/{platform}/` 不回頭遷移。`r_definitions/` legacy 不分類。

完整原則:`docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP161_company_scoped_schema_recognition.qmd`(含相關原則 MP157/158/159/160、enforcement 表、觸發 #499)

---

## Bridge `reviewed_by` 結構化 (MP102 v1.3)

**核心規則**(2026-04-29 起):bridge yaml 的 `reviewed_by` 從字串升級為**結構化 yaml mapping**。兩種形式並存到 2026-07-31,之後只接受結構化。

### 結構化必要欄位

```yaml
reviewed_by:
  human_reviewer: "<github-handle>"
  review_mode: "glue-ensemble-v1"
  ai_reviewers: [codex-cli@<ver>, claude-opus-4-7-{correctness,security,devils-advocate}]
  findings_summary:
    critical: 0                # 必為 0
    high: 0                    # 必為 0
    medium: <N>                # > 0 時須在 findings_resolutions 列出
    low: <M>
    suggestions: <K>
    resolved_in_iterations: <N>
  approved_at: "<ISO 8601 UTC>"
  approved_in_commit: "<git-sha>"
  review_artifacts: "<source>.bridge.review.md"
# findings_resolutions: 當 medium + low > 0 時必要(每筆含 finding_id/severity/description/resolution/accepted_by)
```

**前提**:bridge yaml 旁邊必有 sibling `<source>.bridge.review.md`,內含 `## Verdict: CONVERGED at iteration <N>` 或 `## Verdict: DIMINISHING at iteration <N>`。缺 → CRITICAL,runtime gate stop。

### 自動產出

用 `/glue-bridge` skill 跑 self-converging loop(Step 6e 自動填),**不手寫**。詳見 `.claude/skills/glue-bridge/SKILL.md`。

### 四種收斂 Verdict

| Verdict | 條件 | Ship-ready |
|---|---|---|
| `CONVERGED` | 0 critical + 0 high + 剩餘有 resolutions | ✅ |
| `DIMINISHING` | 只剩 SUGGESTION-level | ✅ with notes |
| `PLATEAUED` | findings_hash 連兩 iter 不變且有未解 critical/high | ❌ |
| `blocked-on-codegen-instability` | findings_count 增加且新增 critical/high | ❌ |

### 常見違規

CRITICAL → runtime stop:`findings_summary.critical > 0` / 缺 sibling review log / `medium > 0` 但缺 `findings_resolutions`。

完整原則:`docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP102_etl_output_standardization.qmd` 「v1.3 Self-Converging Review」section(含相關原則 MP159/160/161/IC_P002/DOC_R009、觸發 #500)

---

## ETL 6-Layer 架構

### 資料庫層級

**ETL Phase (Extract-Transform-Load)**
```
raw_data.duckdb (0IM) → staged_data.duckdb (1ST) → transformed_data.duckdb (2TR)
```

**DRV Phase (Derivation)**
```
processed_data.duckdb (3PR) → cleansed_data.duckdb (4CL) → app_data.duckdb (5NM)
```

---

## 命名模式

### 檔案命名
```
{platform}_ETL_{datatype}_{phase}.R
```
範例：
- `cbz_ETL_orders_0IM.R` - Cyberbiz 訂單 Import
- `eby_ETL_sales_1ST.R` - eBay 銷售 Staging
- `amz_ETL_products_2TR.R` - Amazon 產品 Transform

### 表格命名
```
df_{platform}_{datatype}___{layer}
```
範例：
- `df_cbz_orders___raw` - 原始訂單資料
- `df_eby_sales___staged` - 已暫存銷售資料
- `df_amz_products___transformed` - 已轉換產品資料

---

## ETL vs Derivation 分離 (MP064 v2.2, 2026-05-10 glue-era amendment)

### ETL 階段（0IM/1ST/2TR）
- 只處理資料移動和格式轉換
- 不包含商業邏輯
- 不進行計算（如 RFM 分數）

#### 0IM 階段:雙形式(post-glue era)

per MP064 v2.2 + DM_R028 + `etl-architecture-roadmap` Requirement 3,0IM 階段可用兩種等價形式實作:

| 形式 | 路徑 | 機制 |
|---|---|---|
| Legacy R script | `update_scripts/ETL/<platform>/<platform>_ETL_<datatype>_0IM.R` | R script + dbWriteTable 寫 raw_data.duckdb |
| Post-glue bridge yaml | `bridges/<COMPANY>/<platform>/<datatype>.bridge.yaml` | `fn_glue_bridge.R` 直譯 yaml,輸出至 raw_data.duckdb |

兩種形式輸出**相同 canonical schema** 至 raw 層。撰寫者依 datatype migration 狀態選擇。

#### Post-glue raw 層是 canonical(v2.2 amendment)

- Layer 1 schema 在 `01_db/raw_schema/_authoring/core_schemas.yaml` 集中聲明 universal canonical names
- raw 層 `df_<platform>_<datatype>___raw` 採 canonical 欄位名(如 `order_id`),不是 source-original(如 `amazon-order-id`)
- **post-migration 1ST 範圍**:僅 quality validation(編碼/NA/範圍檢查),不做 schema mapping
- **post-migration 2TR 範圍**:僅 post-canonical transformation(date parse / 衍生欄位 / 跨來源 join / 商業規則),不做 schema mapping

詳見 `openspec/specs/etl-architecture-roadmap/spec.md` 跟 MP064 v2.2 全文。

### Derivation 階段（3PR/4CL/5NM）
- 商業邏輯在此處理
- 計算衍生欄位
- 建立分析用資料

---

## DRV 群組定義（重要！）

**建立 DRV 腳本前必須確認正確群組：**

| 群組 | 名稱 | 用途 | 範例 |
|------|------|------|------|
| **D00** | App Data Init | 基礎資料結構初始化 | `D00_01` 初始化 app_data |
| **D01** | Customer DNA Analysis | 客戶 DNA 分析（RFM、NES、DNA 分數）| `D01_05` df_dna_by_customer |
| **D02** | Filtered Customer Views | 分段客戶視圖 | `D02_01` 客戶分群視圖 |
| **D03** | Positioning Analysis | 市場定位分析 | `D03_01` 定位矩陣 |
| **D04** | Poisson Precision Marketing | Poisson 分析、時序分析 | `D04_02` Poisson 分析 |
| **D05** | Macro Trend Analysis | 總體趨勢分析（月度聚合、MoM/YoY） | `D05_01` df_macro_monthly_summary |

### 常見錯誤

| 錯誤 | 正確 | 原因 |
|------|------|------|
| DNA 相關放 D04 | DNA 相關放 **D01** | D01 = Customer DNA Analysis |
| Poisson 放 D01 | Poisson 放 **D04** | D04 = Poisson Precision Marketing |

### DRV 檔案命名

```
核心函數: fn_D{群組}_{序號}_core.R
執行腳本: all_D{群組}_{序號}.R
```

範例：
- `fn_D01_07_core.R` - D01 群組第 7 號核心函數（DNA 預計算）
- `all_D01_07.R` - D01 群組第 7 號執行腳本

### 新增 DRV 輸出時:必更新 DRV 契約 yaml (MP165 v1.3, #668)

每次新增 DRV 腳本產出新的 `df_*` 表(預期儀表板會用),**必須**同時在對應公司的 `<company>_drv.yaml` 加 contract:

```yaml
# shared/global_scripts/98_test/e2e/contracts/<company>_drv.yaml
drv_contracts:
  <platform>:                              # amz / cbz / eby / all
    <new_table_name>:                      # 例如 df_amz_new_analysis
      l2_row_count_min: 50                 # 預期最少列數
      l3_predictor_types:                  # 選用 — 僅當表有 predictor_type 欄
        required: [time_feature, ...]
        min_count_per_type: 1
      sentinel_ratio_max: 0.5              # 選用 — sentinel 比例警告閾值
      severity: critical                   # 新表預設 critical;若 upstream 還在修改: warning
```

**設計準則**(per Phase 3 lessons-learned):
- **Contract = 期望宣告,不是現狀紀錄**:即使新表還沒填好資料,先寫 `severity: warning` 讓 gate 持續 surface gap;修好後改成 `critical` 一行 diff
- Sunset 後(2026-06-13+)缺 `<company>_drv.yaml` 會 hard-fail `make run`;預先寫好不會被打到
- 5 公司 yaml 都在 `shared/global_scripts/98_test/e2e/contracts/` — 新表通常只影響某 1-2 家,但 review 時記得跨公司一致(IC_P002)

完整 schema + 行為見 MP165 v1.3 `## DRV-Layer Step 2 Propagation` section + spectra change `mp165-drv-output-shape-gate`。Pipeline 整合 `make verify-drv` 跟 `make run` 行為見 `04-pipeline.md`。

---

## 程式碼品質 Checklist

### 架構合規
- [ ] 資料庫路徑符合 6-Layer 架構
- [ ] ETL phase 正確分離（Import/Stage/Transform）
- [ ] ETL 中無商業邏輯（商業邏輯在 Derivation）
- [ ] 使用 `dbConnect_universal()` 連接資料庫
- [ ] DuckDB 可重建性正確：raw_data 不可重建（不可刪），其餘皆可重建（DM_R061）
- [ ] DB 檔案放在 `db_paths.yaml` 定義的 canonical 路徑;發現錯位置時**移動資料,不改程式**（DM_R062）
- [ ] Metadata tables 放 `meta_data.duckdb`,**不放 app_data** 也**不走 6-layer ETL**（DM_R054 v2）

### 命名合規
- [ ] 檔案名稱符合 `{platform}_ETL_{datatype}_{phase}.R`
- [ ] 表格名稱符合 `df_{platform}_{datatype}___{layer}`
- [ ] 變數使用描述性名稱

### 文件合規
- [ ] 原則引用記錄在程式碼註解（如 `# Following MP064`）
- [ ] 五段式腳本結構（INITIALIZE/MAIN/TEST/DEINITIALIZE/AUTODEINIT）
- [ ] Console 輸出遵循 DEV_P022 透明度原則

### 資料合規 (MP029)
- [ ] 無假資料、樣本資料、模擬資料
- [ ] 所有測試使用真實資料子集
- [ ] 資料來源明確標註

### 程式碼字元合規 (MP100)
- [ ] 程式碼註解只用 ASCII + 基本中文，不用特殊 unicode（圈數字 ①②③、全形括號（）、emoji 等）
- [ ] 若需編號用 `(1)` `(2)` `(3)` 或 `layer 1` `layer 2` `layer 3`

### 副作用防禦 (MP154 / DEV_R055)
- [ ] mapping/lookup 失敗時使用 sentinel（如 `"UNKNOWN"`），不可用 NA
- [ ] ID 欄位語意一致（不混用 ID 和原始名稱）
- [ ] 部分失敗時有 `warning()` 並列出未映射值和修正指引

### 欄位取用 (DM_R064)
- [ ] 讀取 tabular 資料(Sheet / CSV / DataFrame / SQL)只用欄位名,**不用** positional index
- [ ] **禁止** `col_idx + N` 偏移算術、`df[[4]]` 整數索引、`SELECT column_4` 無別名
- [ ] **必須** `df$brand` / `df[["brand"]]` / `tbl2 %>% select(brand)` / `row_bind` named data.frames
- [ ] 例外:raw matrix、positional is the semantic、parse-time 一次性 resolve 後存欄位名

### Schema 去重規範 (DM_R065)
- [ ] **Within-field aliases**(`core_schemas.yaml`):每個 field 的 `aliases:` 列表內,normalize 後(lowercase + trimws + strip 非字母數字)不可有重複。`"asin"` 和 `"ASIN"` 都 normalize 成 `"asin"`,只能留一個。
- [ ] **Cross-field aliases**:同一個 datatype 內,**禁止** 同一個 normalized alias 出現在兩個不同 field 的 `aliases:`(例:`"SKU"` 不可同時出現在 `products.product_id.aliases` 和 `products.sku.aliases`)。Resolution 順序:field-name suffix match > source-canonical match > most-specific field。
- [ ] **Multi-column merge** 在 Layer 2 處理:source 有多欄對應同一 canonical field 時,bridge yaml 用 `from_columns: [...]` + `merge_strategy: coalesce|concat|first_non_null`,**不可**回頭加 alias 到 `core_schemas.yaml`(會違反 MP159)。`from_column:`(單)和 `from_columns:`(複)互斥。
- [ ] **value_map** 不寫 case-variants:用 `coercion.rule: "tolower"` 先 normalize,再保留一個 canonical key(避免 `"Amazon": "AFN"` + `"AMAZON": "AFN"` 並列)。
- [ ] Linter 在 `validate_bridge_yaml.R` 強制執行;within-field dup 和 cross-field collision 是 CRITICAL,value_map case-variant 是 WARNING。

### Schema authoring 命名規範 (SO_R038 v1.1, 2026-05-02)
- [ ] **Field 命名**:`required_fields` / `optional_fields` / `column_mapping` 的 keys 必須是 snake_case lowercase ASCII(`^[a-z][a-z0-9_]*$`)。**禁止** camelCase / PascalCase / kebab-case / 大寫 / 非 ASCII。
- [ ] **Sentinel 格式**:`fallback.value` 為字串且代表「missing/unknown 實體」時,必須是 `UNKNOWN_<ENTITY>`(uppercase + snake_case,`^UNKNOWN(_[A-Z][A-Z0-9_]*)?$`)。**禁止** 小寫 `"unknown"`(這是 #492 修正的 canonical 違例)。ETL meta 也適用 — 用 `UNKNOWN_SOURCE`,不是 `"unknown"`。
- [ ] **Sentinel ENTITY 語意(v1.1, #506)**:`<ENTITY>` 必須描述「該欄位代表的實體」(field semantics),**不可**描述 row meta-state / 失敗原因 / 處理階段。**辨識測試**:「這個 ENTITY 換到別的 field 還能用嗎?」能 → 不是 entity,reject;只能用一處 → 是 entity,accept。
  - ✅ `UNKNOWN_ASIN`(只能用在 asin field)/ `UNKNOWN_SOURCE`(只能用在 source field)/ `UNKNOWN_PRODUCT`
  - ❌ `UNKNOWN_BAD_ROW`(BAD_ROW 是 row state)/ `UNKNOWN_MALFORMED`(失敗原因)/ `UNKNOWN_TODO`(處理階段)
- [ ] **Sentinel granularity(v1.1)**:預設用 `UNKNOWN_<ENTITY>`(具名)。bare `UNKNOWN` 只在「同 datatype 內只有 1 field 用 sentinel」**且**「無 downstream join 比對其他欄位」時可。多 field 都用 sentinel → **必須**各自 `UNKNOWN_<ENTITY>` 區分;跨 datatype join 比對 → **必須** specific。
- [ ] **Multi-Field Row Corruption(v1.1, #506,MP163-aligned)**:當單一 source row 同時有 2+ 個欄位 corruption(column shift / structural source defect)→ **不可**對每 field 寫 sentinel 然後保留 row;必須 **drop row + 寫到 `df_<datatype>_coverage_audit`**(記 source_file / source_row_id / reason / detected_via)。Per-field sentinel 是 field-level missing data 的工具;row-level corruption 升級到 row-level audit。
- [ ] **Sentinel boundary cases**(明文允許):`""`(optional empty 語意)/ `0`(numeric 有意義 sentinel)/ `"1970-01-01"`(date Unix epoch)/ `false`(is_* 保守預設),需在 `notes:` 說明選擇理由。
- [ ] **機器讀取欄位**(`coercion.rule` / `pattern` / `fallback.derive`):純 ASCII。半形標點 only。**禁止** 全形 / emoji / 控制字元。
- [ ] **人類讀取欄位**(`description` / `description_zh` / `notes` / `comment` / `rationale`):允許 UTF-8(中文 / 日文 / 重音拉丁)。`description_zh` 可用全形 `（）`。**仍禁止** emoji 和控制字元。
- [ ] **Layer 1 binding header**:`core_schemas.yaml` 和每個 `platform_extensions/*.yaml` 開頭 1-30 行必須有 normative 註解區塊,列出 binding principles(MP102 v1.2 + MP156 + MP157 Layer 1)+「Most recent significant edit: spectra change <name>」+ change discipline 提示。
- [ ] **Datatype-level keys** 必須在 `_meta_schema.yaml` 註冊。typo 例如 `phyiscal_realization` 會被 `_build.R` 用 Levenshtein hint 擋下。新增 key 是 deliberate act,需另開 change spec。
- [ ] Linter 嚴重度:field 命名違例 / sentinel 格式違例 / 未註冊 key = CRITICAL;sentinel ENTITY blacklist match(BAD_ROW / MALFORMED / TODO 等)= WARNING(advisory,full 語意檢查仍需 code review);ASCII 違例(machine-read 含非 ASCII)/ missing header = WARNING;Multi-field row corruption 規則 = code review only(無法 lint time mechanically detect)。

### Glue authoring 不可改 Layer 1 (MP159)

### Glue authoring 不可改 Layer 1 (MP159)
- [ ] Bridge yaml 寫作 session 期間,**不可**修改 `core_schemas.yaml` 或 `platform_extensions/*.yaml`(Layer 1 immutable)。
- [ ] Source 對映困難時,在 bridge 內用既有 primitives 解決:`ignored_columns`(多餘欄位)/`apply_fallback`(缺必要欄位)/`value_map`(per-language 翻譯)/`pre_filter`(per-source 品質)/`from_columns + merge_strategy`(多欄合併)。
- [ ] 決策準則:「per-source 還是 universal?」per-source → bridge yaml;universal → 中止 bridge 寫作,另開 Layer 1 change spec(走 IC_P002 cross-co verify)。
- [ ] 例外:dedicated Layer 1 refactor task(task intent 明文是 Layer 1 work)是合法的;區分依據是 task intent,不是檔案路徑。
- [ ] Enforcement:`/glue-bridge` skill Step 0 preflight + `validate_bridge_yaml.R` 驗證每個 column_mapping 引用都在當前 schema(不在 → CRITICAL,暗示 Layer 1 被偷改過)。

---

## 關鍵函數

```r
# 資料庫連接
source("scripts/global_scripts/02_db_utils/duckdb/fn_dbConnectDuckdb.R")
con <- dbConnectDuckdb(db_path_list$staged_data, read_only = TRUE)

# 初始化
source("scripts/global_scripts/22_initializations/sc_Rprofile.R")
autoinit()

# 結束
autodeinit()  # 必須是腳本最後一行
```

---

## DB 路徑 Canonical 強制 (DM_R062)

### 核心規則

所有 `.duckdb` 檔案**必須**放在 `shared/global_scripts/30_global_data/parameters/scd_type1/db_paths.yaml` 的 `databases:` / `domain:` section 定義的 canonical 路徑。

**發現錯位置時:移動資料 → canonical path,不改程式。**

### 為什麼

- code 期望 canonical path 但 file 在其他位置 → 兩種修法:
  - ❌ **改程式加 fallback**(e.g. `if exists(A) use A else B`) → 累積 legacy + 未來新人困惑
  - ✅ **移動檔案到 canonical**(一次到位)
- 事實(data location)錯了要改事實,不是改讀取邏輯(呼應 MP029「No Fake Information」)

### 違規

```r
# BAD: autoinit 試多個路徑
raw_data_path <- if (file.exists(file.path(base, "data", "raw_data.duckdb"))) {
  file.path(base, "data", "raw_data.duckdb")  # legacy 位置
} else {
  file.path(base, "data", "local_data", "raw_data.duckdb")  # canonical
}
```

### 符合

```r
# GOOD: 只讀 canonical;錯位置由人類移動
raw_data_path <- file.path(base, db_config$databases$raw_data)
if (!file.exists(raw_data_path)) {
  stop("raw_data.duckdb not at canonical path: ", raw_data_path,
       "\nMove the file to this path; do not add fallback paths to code.")
}
```

### 修復流程(錯位置檔案)

```bash
# 1. Archive(non-destructive)
mkdir -p <project_root>/data/archived/wrong_location
mv <wrong_path> <project_root>/data/archived/wrong_location/<name>_YYYYMMDD.duckdb

# 2. 若 canonical path 該有檔案但沒 → 跑 ETL rebuild
# autoinit 會在 db 缺失時報 actionable error(autoinit-failfast-policy)
```

### 相關原則

- **MP029**:No Fake Information(不假設,直接面對事實)
- **DM_R028**:ETL Data Type Separation(6-layer canonical 結構)
- **DM_R056**:Mode-Specific DB Paths(db_paths.yaml 為 source of truth)
- **autoinit-failfast-policy** spec:缺 canonical 檔案時立即報錯

---

## Metadata 必在 `meta_data.duckdb` (DM_R054 v2.1.1)

### 核心規則

所有 metadata tables(`df_platform`、`df_product_line`、`df_product_mapping`、`df_category_hierarchy` 等 reference/lookup/mapping)**必須**住在 `meta_data.duckdb`:

- **不**寫入 `app_data.duckdb`、**不**流經 6-layer ETL、每表只**一個** canonical 位置(無跨 DB 重複)
- 理由:`app_data` 是 rebuildable(`rm app_data.duckdb && make run`),metadata 不是 — 必須獨立 non-rebuildable 位置

### 第 7 層定位

```
6-layer flow: raw → staged → transformed → processed → cleansed → app_data
7th parallel: meta_data.duckdb  ← survives app_data rebuild
```

### 讀寫範例

```r
# 讀(必用 tbl2,DM_R023):直連 or DuckDB ATTACH
con_meta <- dbConnectDuckdb(db_path_list$meta_data, read_only = TRUE)
df_platform <- tbl2(con_meta, "df_platform") %>% collect()

# 跨 DB JOIN:ATTACH 時用 DBI::dbQuoteString 引用路徑,讀表用 dbplyr::in_schema()
dbExecute(con_app, paste0("ATTACH DATABASE ", DBI::dbQuoteString(con_app, db_path_list$meta_data), " AS meta (READ_ONLY)"))
tbl2(con_app, dbplyr::in_schema("meta", "df_platform")) %>% collect()

# 寫:single canonical
dbWriteTable(con_meta, "df_platform", df_platform, overwrite = TRUE)
```

違規:寫 `app_data`、跨 DB 重複、fallback `if exists(app) use app else meta`。

### Producer 契約

每 metadata table 有 **exactly 一個** producer ETL,命名 `all_ETL_{type}_0IM.R`,idempotent,**不**清 `___COMPANY` suffix 診斷表(DM_R037 v3.0)。

### v2.1.1 runtime addendum(2026-04-20)

三條 runtime + 一條 deploy 規則:

1. **Runtime MAY NOT read CSV seeds** — CSV 只給 producer ETL,其他程式無 fallback
2. **Readers 走 `fn_load_product_lines`** — 不直接 `DBI::dbReadTable("df_product_line")`。Backend 由 `app_config.yaml > database.mode` 決定(`duckdb`/`supabase`/`auto`)
3. **APP_MODE `autoinit()` populate `meta_data` IFF 檔案存在** — DuckDB mode 強制 populate;Supabase-only deploy 可缺(`auto` 走 `dbConnectAppData()`);`app_data` 仍 fail-fast
4. **Deploy bundle 不 ship `meta_data.duckdb`** — Posit Connect 走 Supabase;`.rsconnectignore` 保持 `*.duckdb`,不加 `!` exception

> **DOC_R009 分層提醒**:本段是 quick reference;規範修改改 `.qmd`(Layer 1)為主,本檔只同步摘要(#429)。

完整原則:`docs/en/part1_principles/CH02_data_management/rules/DM_R054_metadata_table_storage_pattern.qmd` Section 6-8(含相關原則 DM_R061/062/037、版本歷史 v1→v2→v2.1→v2.1.1、觸發 #422/#424)

---

## Deploy Bundle Purity (DM_R063)

**Posit Connect / Shinyapps.io 部署 bundle 絕不含 local DB files。APP_MODE autoinit 容忍本地 DB 缺失。**

核心 4 條:

1. **Bundle denylist** — `*.duckdb`、`*.wal`、`data/local_data/**`、`data/app_data/*.duckdb`、`_targets/**`、`*.log`、`_cache/**`、`renv/**` 一律不進 bundle
2. **Makefile `deploy-sync`** — 不得 `cp *.duckdb`;rsync 必須 `--exclude='*.duckdb'`
3. **`.rsconnectignore`** — `*.duckdb` unqualified,**不**加 `!data/local_data/meta_data.duckdb` 之類 negated exception
4. **APP_MODE precheck** — autoinit fail-fast 僅 scope 到 UPDATE_MODE/GLOBAL_MODE:`run_precheck <- !identical(OPERATION_MODE, "APP_MODE")`

違例 pattern:Makefile `cp *.duckdb` 進 bundle / `.rsconnectignore` negated `!` exception / APP_MODE autoinit 無 mode guard 就 `stop("ETL pipeline incomplete")`。

完整規範、exemption_list、enforcement 見 `docs/en/part1_principles/CH02_data_management/rules/DM_R063_deploy_bundle_purity.qmd`(含 #424 三層 bug 教訓)。

---

## 資料庫讀取規範 (DM_R023 v1.2)

**強制**:資料庫讀取必須用 `tbl2()` + dplyr verbs。Raw SQL `dbGetQuery(... SELECT ...)` 一律禁止;含 `?` positional placeholder 更不行(DuckDB 收,PostgreSQL 拒,MAMBA #365 因此爆)。

### Good / Bad pattern

```r
# ✅ tbl2 + dplyr(簡單表 / in_schema / group_by-summarise 都可)
tbl2(con, "df_macro_monthly_summary") %>% filter(platform_id == "amz") %>% collect()
tbl2(con, dbplyr::in_schema("transformed_data", "df_amz_review___transformed")) %>% collect()
tbl2(con, "df_sales") %>% group_by(platform_id) %>% summarise(total = sum(amount)) %>% collect()

# ❌ 禁止
DBI::dbGetQuery(con, "SELECT * FROM df_customers")                     # raw SQL read
DBI::dbGetQuery(con, "SELECT * FROM df_x WHERE id = ?", params=list(x)) # ? placeholder
dbGetQuerySafe(con, sql, params=list(...))                              # deprecated 2026-04-13, 移除 2026-07-13
tbl2(con, "schema.table")                                               # dot-syntax 已移除,改用 in_schema()
```

### 三個允許的例外

| 情境 | 用什麼 |
|---|---|
| 寫入(DDL/DML) | `DBI::dbExecute()` + raw SQL |
| Driver 專屬 introspection | `02_db_utils/` 下的 helper |
| 過渡期 `dbGetQuerySafe()` | 舊程式碼到 2026-07-13;新程式碼禁止 |

PreToolUse hook `.claude/hooks/check-tbl2-compliance.sh` 偵測違規(advisory non-blocking)。完整規範 + 相關原則 DM_R002/003/011-014 見 `DM_R023_universal_dbi_approach.qmd` Section 6。

---

## 錯誤模式監控

### DuckDB 錯誤
| 模式 | 意義 | 解決方案 |
|------|------|----------|
| `rapi_register_df` | DuckDB 註冊錯誤 | 檢查 DataFrame 類型和欄位 |
| `std::exception` | DuckDB C++ 例外 | 檢查 SQL 語法和資料類型 |
| `Conflicting lock` | 資料庫鎖定 | **先 `ps -p <PID> -o command=` 看是誰**,再決定動作(見 #437 規範) |
| `column.*not found` | 欄位不存在 | 驗證表格 schema |

### API 錯誤
| 狀態碼 | 意義 | 解決方案 |
|--------|------|----------|
| `401` | 未授權 | 檢查 API key |
| `403` | 禁止存取 | 檢查權限設定 |
| `404` | 資源不存在 | 驗證 endpoint URL |
| `500` | 伺服器錯誤 | 檢查請求格式或稍後重試 |

### R 常見錯誤
| 模式 | 意義 | 解決方案 |
|------|------|----------|
| `Error in source()` | 找不到檔案 | 驗證路徑和工作目錄 |
| `could not find function` | 套件未載入 | 確認 library() 呼叫 |
| `replacement has.*rows` | 向量長度不符 | 檢查資料維度 |

---

## 即時監控指令

### 執行 R 腳本並監控輸出
```bash
stdbuf -oL -eL Rscript script.R 2>&1 | tee log.txt &
```

### 追蹤特定錯誤
```bash
stdbuf -oL -eL Rscript script.R 2>&1 | grep -E "(Error|Warning|✗)" | tee errors.txt
```

### 監控長時間執行的 ETL
```bash
# 背景執行並保存 log
nohup Rscript scripts/update_scripts/ETL/cbz/cbz_ETL_orders_0IM.R > etl_log.txt 2>&1 &

# 即時追蹤
tail -f etl_log.txt
```

---

## ETL 偵錯流程

1. **確認資料庫連線**
   ```r
   con <- dbConnectDuckdb(db_path_list$staged_data)
   dbIsValid(con)  # 應回傳 TRUE
   ```

2. **檢查來源表格**
   ```r
   dbExistsTable(con, "source_table")
   dbGetQuery(con, "SELECT * FROM source_table LIMIT 5")
   ```

3. **驗證資料類型**
   ```r
   str(df)
   sapply(df, class)
   ```

4. **檢查 NA 分布**
   ```r
   colSums(is.na(df))
   ```

5. **驗證轉換結果**
   ```r
   nrow(df_before)
   nrow(df_after)
   names(df_after)
   ```

---

## 常見問題排解

### 資料庫鎖定 — **不要盲目 kill**(#437 規範)

撞到 `Conflicting lock is held ... by user X` 時,**禁止**直接 `kill -9 <PID>`,必須先確認持鎖者身份:

```bash
# Step 1: 看 command 是什麼
ps -p <PID> -o command=

# Step 2: 按 command 決定動作
# → R --file=app.R / Rscript app.R           = 使用者本地 Shiny dev session,不可殺
# → Rscript --vanilla .../test_*.R           = 可能是 stale test process,確認後可殺
# → make run / targets / _targets tar_make   = 另一次 pipeline 執行,等它結束
# → /Library/Frameworks/R.framework/...      = REPL / RStudio,可能是使用者互動中,問再殺
```

**AI agent 特別提醒**:執行除錯流程遇到 DuckDB lock 時:
1. 先用 `fn_check_db_locks`(`04_utils/fn_check_db_locks.R`)取 holder info(PID + command + user)
2. 看 command 看起來是不是使用者 active session
3. **禁止** `kill -9` 不屬於自己 session 的 process 沒先問使用者
4. 優先 `kill -TERM`(signal,允許 cleanup);真的 unresponsive 才 `-9`

2026-04-21 有 incident:AI agent 誤 kill 使用者的 `R --file=app.R`(PID 89166),原因是誤判成 stale test process。本規範防止再發生。

### 一般做法(資料庫鎖定)
```r
# 解決方案 1: 關閉所有連線
DBI::dbDisconnect(con)
gc()  # 強制垃圾回收

# 解決方案 2: 重啟 R session
.rs.restartR()
```

### 記憶體不足
```r
# 檢查記憶體使用
pryr::mem_used()

# 清理大型物件
rm(large_object)
gc()

# 使用 data.table 取代 tibble 以節省記憶體
library(data.table)
dt <- as.data.table(df)
```

### 編碼問題
```r
# 確保 UTF-8
Sys.setlocale("LC_ALL", "en_US.UTF-8")

# 檢查字串編碼
Encoding(text_column)
```

---

## 顯示資料外部化 (DEV_R050)

### 核心規則

**禁止**在 R 函數中 hardcode 顯示用文字（行銷建議、分類描述、UI 長文本等）。

顯示資料**必須**存放在外部檔案：
- 位置：`30_global_data/parameters/` 下的 YAML 或 CSV
- R 函數只負責邏輯判斷，透過 key 從外部檔案載入顯示內容

### 正確做法

```r
# 好：從 YAML 載入顯示內容
strategies <- yaml::read_yaml("30_global_data/parameters/marketing_strategies.yaml")
purpose <- strategies[["Awakening / Return"]]$purpose
```

### 錯誤做法

```r
# 不好：hardcode 在 R 函數中
purpose <- "防流失"
recommendation <- paste0("1. 定期發送關懷訊息...<br>", "2. S1 給小額折扣...")
```

### 適用範圍

| 類型 | 放哪裡 | 範例 |
|------|--------|------|
| 行銷策略建議 | `30_global_data/parameters/marketing_strategies.yaml` | 13 策略的中文建議 |
| 分類標籤映射 | `30_global_data/parameters/*.yaml` | RSV 客戶類型名稱 |
| UI 短標籤 | `11_rshinyapp_utils/translation/ui_terminology.csv` | 按鈕、欄位名 |
| 程式邏輯常數 | R 函數內（可 hardcode） | 閾值 0.7、分位數 0.2 |

### 理由

- 內容可由非工程人員修改（改 YAML 比改 R 安全）
- 避免中文 unicode escape 造成可讀性問題
- 符合 configuration-driven 開發原則（MP142）
- 單一修改點：改一次 YAML，所有引用處自動更新

---

## CSV 下載必須含 UTF-8 BOM (DEV_R051)

### 核心規則

所有 `downloadHandler` 產出的 CSV 檔案**必須**包含 UTF-8 BOM（Byte Order Mark），確保 Excel 正確辨識中文編碼。

### 禁止使用 `write.csv` + `append`

R 的 `write.csv()` 會**靜默忽略** `append = TRUE` 參數（設計限制），導致先寫入的 BOM 被覆蓋。

### 正確做法

```r
output$download_csv <- downloadHandler(
  filename = function() paste0("export_", Sys.Date(), ".csv"),
  content = function(file) {
    df <- reactive_data()
    if (!is.null(df)) {
      # Step 1: Write UTF-8 BOM (Excel compatibility)
      con <- file(file, "wb")
      writeBin(charToRaw("\xef\xbb\xbf"), con)
      close(con)
      # Step 2: write.table (NOT write.csv) to support append=TRUE
      utils::write.table(df, file, row.names = FALSE, sep = ",",
                         quote = TRUE, append = TRUE, fileEncoding = "UTF-8")
    }
  }
)
```

### 錯誤做法

```r
# 不好：write.csv 忽略 append=TRUE，BOM 被覆蓋
utils::write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8", append = TRUE)
```

### 理由

- Excel 在 Windows/macOS 預設以系統 locale 開啟 CSV，無 BOM 時中文會亂碼
- `write.csv` 是 `write.table` 的嚴格包裝器，強制 `append=FALSE`
- 使用 `write.table` + 明確的 `sep=","` 和 `quote=TRUE` 等同於 `write.csv` 的行為，但支援 `append`

---

## 業務邏輯用英文 Key，UI 才 translate (DEV_R052)

### 核心規則

所有非 UI 的程式碼**必須**使用英文 canonical key。`translate()` **只能**在 UI 渲染層呼叫。

### 架構邊界

```
┌─────────── 非 UI（全英文）──────────┐
│  DRV:    r_label = "Recent Buyer"   │
│  switch: "Recent Buyer" = ...       │
│  filter: df$r_label == "Recent..."  │
│  config: key: "High Value"          │
├──────── translate() 邊界 ───────────┤
│  UI:     translate("Recent Buyer")  │
│  pie:    sapply(levels, translate)   │
│  table:  colnames = translate(...)  │
└─────────────────────────────────────┘
```

### 適用範圍

| 層級 | 語言 | 用 translate()? |
|------|------|-----------------|
| ETL / DRV 腳本 | 英文 | 否 |
| 函數檔案 (`fn_*.R`) | 英文 | 否 |
| switch / if-else / case_when | 英文 | 否 |
| 設定檔 (YAML / CSV) | 英文 key | 否 |
| Shiny server 邏輯 | 英文 | 否 |
| **Shiny UI 渲染** | **英文 → 翻譯** | **是（必須）** |

### 正確做法

```r
# DRV: 存英文
r_label = case_when(r_ecdf >= 0.67 ~ "Recent Buyer", ...)

# 業務邏輯: 用英文比對
switch(segment, "Recent Buyer" = list(strategy = "Deepen Engagement", ...))

# UI: translate 顯示
tags$h6(translate(segment))
```

### 錯誤做法

```r
# 不好：業務邏輯用中文 unicode escape
switch(segment, "\u9ad8\u6d3b\u8e8d" = ...)

# 不好：中間加 band-aid mapping
label_map <- c("Recent Buyer" = "\u9ad8\u6d3b\u8e8d")

# 不好：UI 不翻譯，直接顯示英文
tags$h6(segment)  # 應該用 translate(segment)
```

### 理由

- 英文 key 無 encoding 問題，中文 `\uXXXX` escape 不可讀且易出錯
- 業務邏輯不依賴顯示語言，未來加新語言零修改
- 防止 `switch()` 靜默 fall-through（Issue #241 的根因）
- **UI 必須 translate**：確保使用者看到的是其語言的內容

> **例外：AI Prompt 內容** — AI prompt 的多語系不用 `translate()`，改用 `load_openai_prompt(key, locale=)` 從 `ai_prompts.yaml` 載入。詳見 DEV_R053 和 `09-openai-integration.md`。

---

## 臺灣正體中文用語規範 (UI_R025)

### 核心規則

翻譯必須使用**臺灣正體中文**的慣用語，避免大陸慣用語造成的語意偏移。

注意：部分詞彙在臺灣有其**特定語意**，並非完全禁用。例如「數據」在臺灣可用於學術或統計脈絡（如「數據分析」），但泛指 data 時應用「資料」；「質量」在臺灣指物理的 mass，不指 quality。本規範針對的是**大陸用法語意外溢到臺灣不使用的場景**。

### 詞彙對照表

| 大陸用法（本專案避免） | 臺灣用法 | 說明 |
|---|---|---|
| 數據（泛指 data） | 資料 | 臺灣「數據」偏指 numerical data / statistics |
| 激活 | 活化、啟動 | |
| 捆綁 | 組合、搭售 | |
| 批量 | 批次、大量 | |
| 信息 | 資訊 | |
| 軟件 | 軟體 | |
| 網絡 | 網路 | |
| 視頻 | 影片 | |
| 用戶（泛指 user） | 使用者 | 臺灣「用戶」偏指帳戶持有人（如銀行用戶） |
| 反饋 | 回饋 | |

### 適用範圍

- `ui_terminology.csv` 的 `zh_tw` 欄位
- 所有經 `translate()` 顯示的文字
- AI prompts 中的中文 system prompt（如適用）
- 任何使用者可見的中文文字

### 理由

- 臺灣市場的產品必須使用在地化用語
- 大陸用語會讓臺灣使用者感到不自然且不專業
- 維護品牌的在地親和力

---

## 欄位/指標顯示名稱格式 (UI_R027)

### 核心規則

當資料項目有公認的英文縮寫或代碼時，顯示格式為：

**`中文全稱（英文縮寫）`**

中文全稱在前（因為 zh_TW 是主要 UI 語言），英文縮寫在全形括號 `（）` 內。

### 範例

| English Key | zh_TW 顯示 | 類別 |
|-------------|------------|------|
| CLV | 顧客終生價值（CLV） | 指標 |
| RFM | 顧客價值分數（RFM） | 指標 |
| NES | 新舊客狀態（NES） | 指標 |
| CAI | 客戶活躍指數（CAI） | 指標 |
| IPT | 平均購買間隔（IPT） | 指標 |
| P(alive) | 存活機率（P(alive)） | 指標 |
| E0 | 主力客（E0） | NES 狀態 |
| S1 | 瞌睡客（S1） | NES 狀態 |
| S2 | 半睡客（S2） | NES 狀態 |
| S3 | 沈睡客（S3） | NES 狀態 |
| MoM | 月增率（MoM） | 增長率 |
| YoY | 年增率（YoY） | 增長率 |

**無標準縮寫的項目**：純中文顯示（如「總營收」、「訂單數」）。

### 實作方式

格式存放在 `ui_terminology.csv`，不在 runtime 組合：

```csv
en_us,zh_tw
CLV,顧客終生價值（CLV）
NES Status - E0,主力客（E0）
Total Revenue,總營收
```

程式碼使用 `translate()` 即可取得正確格式：

```r
# translate("CLV") → "顧客終生價值（CLV）"
# translate("Total Revenue") → "總營收"
```

### 違規範例

```r
# 違規：只有縮寫，無中文
colnames(show_df) <- c("CLV", "RFM", "NES")

# 違規：有中文但缺少縮寫（有標準縮寫的項目）
# translate("CLV") → "顧客終生價值"

# 違規：英文在前
# translate("CLV") → "CLV 顧客終生價值"

# 違規：NES 狀態缺少代碼
# translate("NES Status - E0") → "主力客"
```

### 適用範圍

- DT::datatable 欄位名稱
- KPI 卡片標題
- 圖表軸標籤與圖例
- Sidebar filter 標籤
- 任何使用者可見的欄位名或指標標籤
