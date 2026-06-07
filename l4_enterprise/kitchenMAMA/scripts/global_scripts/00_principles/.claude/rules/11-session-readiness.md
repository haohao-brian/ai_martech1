# Session-Start Toolchain Readiness (DEV_R057)

**使用時機**:每次要寫 / 跑 R code 之前(包含 ad-hoc `/tmp/*.R` smoke test、debug script、整段 ETL pipeline)

---

## 第一動作(任何 R 工作之前)

```bash
Rscript shared/global_scripts/98_test/check_packages.R
```

兩種輸出:

### A. 全部 OK

```
[OK] R 4.5 + core packages ready (DEV_R057)
```

→ 可以開始寫 / 跑 R code。

### B. 缺核心套件(actionable error)

```
Error: Session-start toolchain readiness check failed:
  Missing core packages: dbplyr, yaml
  Remedy: install.packages(c('dbplyr', 'yaml'))
  See DEV_R057 for details.
```

→ **直接複製貼上 remedy line 跑一次,然後再回頭做原本的 R 工作。**

---

## 重點規則

### 1. 缺套件 → install,不 workaround(CRITICAL)

撞 `library(X): there is no package called 'X'` 時,**不可**改寫程式繞過:

| ❌ 禁止(workaround) | ✅ 必須(install) |
|---|---|
| `dbplyr` 沒裝 → 改用 `dbReadTable + R-side filter` 取代 `tbl2 + dplyr` | `install.packages('dbplyr')` 然後繼續用 canonical pattern |
| `data.table` 沒裝 → 改用 `for loop + base R` 取代 vectorized | `install.packages('data.table')` 然後繼續用 canonical pattern |
| `lubridate` 沒裝 → 改用 `as.POSIXct + format` 字串拼接 | `install.packages('lubridate')` 然後繼續 |

理由:每個 workaround 都在 codebase 開出一條 non-canonical data access path,系統性侵蝕 DM_R023(universal data access)+ DEV_R056(R-first)的 canonical pattern。**修環境,不污染 code path**。

### 2. Ad-hoc `/tmp/*.R` 也適用(Gap C)

`Rscript /tmp/foo.R` 完全 bypass `autoinit()` package check(get_mode 路徑判斷不命中)。但**這條 ad-hoc path 是 #475 撞 dbplyr 的真正起源**。AI session 寫 ad-hoc smoke test / debug script 時:

1. 第一動作仍是 `Rscript shared/global_scripts/98_test/check_packages.R`
2. 缺則 install
3. 然後才寫 `/tmp/foo.R` 並 `Rscript` 跑

**機械上沒人擋你**,但這就是這條 rule 存在的目的 — AI session 自我約束。

### 3. R version 也是 readiness check 的一部分(R >= 4.4.0)

跨 R 版本 binary mixing 會直接 segfault(剛才 R 4.5/4.6 mixing data.table 就是)。Helper fn 第一個檢查就是 R version。

撞 R version 太舊時:

```
Error: Session-start R version assertion failed:
  Running: R 4.3.2
  Required: R 4.4.0 or higher
  Remedy: upgrade R via the macOS installer at https://cran.r-project.org/
```

→ 升級 R 4.4+。

---

## Canonical 套件清單(2026-05-02)

> **Single source of truth**:`shared/global_scripts/04_utils/fn_check_session_packages.R` — 修改清單必動這檔。本檔只是 illustrative reference,**不要**從這裡複製出去當 list。

### Core(MUST,缺則 fail-fast)

| 類別 | 套件 |
|---|---|
| 資料操作 | `data.table`, `dplyr`, `dbplyr`, `tidyr`, `purrr` |
| 資料庫 | `DBI`, `duckdb`, `RPostgres` |
| 檔案 / 設定 | `readxl`, `readr`, `yaml`, `jsonlite` |
| 時間 / 文字 | `lubridate`, `stringr` |
| 路徑 | `here` |

### Optional(SHOULD,缺則 warn)

| 類別 | 套件 |
|---|---|
| 測試 | `testthat`, `shinytest2` |
| 品質 | `lintr` |
| 統計 | `broom`, `zoo`, `knitr` |
| 整合 | `googlesheets4` |
| HTTP / OpenAI | `httr2`, `openssl` |

新增 / 移除 → 改 `fn_check_session_packages.R` + IC_P002 cross-co verify(5 公司)+ commit `Verified:` trailer。

---

## Mode-gated 行為

| Mode | 觸發 check? |
|---|---|
| `UPDATE_MODE`(ETL pipeline、make run、Rscript update_scripts/...) | ✅ 是,fail-fast on missing core |
| `GLOBAL_MODE`(dev script、global_scripts 下的 ad-hoc 工作) | ✅ 是,同上 |
| `APP_MODE`(Posit Connect / shinyapps deploy) | ❌ **完全 skip**(DM_R063 deploy bundle purity) |

`APP_MODE` deploy 環境靠 `manifest.json` + Posit / shinyapps.io 自身的 install 機制管 toolchain,**不**走 DEV_R057 check。

---

## Troubleshooting

### `install.packages()` 失敗(沒設 CRAN mirror)

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages(c('dbplyr', 'yaml'))
```

或 export 永久(`.Rprofile`):

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
```

### `install.packages()` 失敗(source compile)

某些 package 在 macOS 需要 system header(如 `xml2` 需 `libxml2`)。看 install 輸出,通常會指出缺什麼 system lib。

### 跑 check 還是說缺,但我裝了

可能裝在不同的 `.libPaths()`(R 4.4 / 4.5 / 4.6 各自 lib path)。檢查:

```r
.libPaths()  # 看 R 在哪找 packages
```

如果 R 4.6 用,但 packages 裝在 R 4.5 lib → 升 R 或重裝。

### Rollback escape hatch(臨時 bypass)

緊急狀況(deploy CRAN 連線斷等),臨時繞過 autoinit check:

```bash
SKIP_PKG_CHECK=true Rscript update_scripts/...
```

(實作待 deploy 真有需要時再加,目前為 placeholder。)

---

## 跟其他 rules 的關係

- **DM_R023**(Universal DBI Approach):DEV_R057 保護 DM_R023 的 canonical pattern(`tbl2 + dplyr`)不被 missing-package workaround 侵蝕。
- **DEV_R056**(R-first):sister rule。DEV_R056 說「用 R」,DEV_R057 說「並且你的 R 環境要先 ready」。
- **DM_R063**(Deploy Bundle Purity):sibling。兩個都 gate APP_MODE 行為。DM_R063 不讓 local DB 進 bundle,DEV_R057 不讓 package check 在 APP_MODE 跑。
- **MP029**(Never assume; verify before acting):parent。DEV_R057 把 MP029 從資料 / 函數 / 檔案 / 路徑 verify,延伸到**環境 readiness** verify。

---

## 觸發事件

#475 fix 過程,AI 在 `/tmp/test_475_integration.R` smoke test 撞 `dbplyr` 沒裝 → 改寫成 `dbReadTable + R-side filter` workaround → 隨後又撞 `data.table` 跨 R 版本 segfault → 跳過完整 E2E test。

User:「**理論上不會撞,我有指令裝套件**」 — 既有 `98_test/check_packages.R` 確實存在,但 list 停滯 + 沒被 mandate + ad-hoc path bypass。

#507 把這個 implicit 期待升為 explicit 原則。

---

## 完整原則

`docs/en/part1_principles/CH03_development_methodology/rules/DEV_R057_session_start_toolchain_readiness.qmd`(Layer 1 權威來源)
