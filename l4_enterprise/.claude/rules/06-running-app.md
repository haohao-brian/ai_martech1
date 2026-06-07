# 執行 App 時

**使用時機**: 啟動或測試 Shiny 應用程式時

---

## ⚠️ AI session 必看:`run_in_background: true` 對長 R subprocess silent kill(#594)

**症狀**:Claude Code Bash hook 用 `run_in_background: true` 跑長 R command 時,harness 在 R 還在 warm-up 階段就回報 `completed exit 0`,**SIGTERM/SIGHUP 整個 process group 殺掉 R subprocess**。Log 截在開頭幾行,看似 exit 0 success,實際 zero work done。

**已知影響範圍**:
- ✅ `Rscript -e 'testthat::test_dir(...)'` E2E 測試(#593,本問題首次 surface)
- 🟡 plausible:`make run`(ETL pipeline,20-60 min)/ `Rscript .../upload_app_data_to_supabase.R`(5-30 min)/ `Rscript -e 'rsconnect::writeManifest(...)'`(1-2 min)/ `Rscript .../sc_deployment_*.R`(1-5 min)
- ⚪ probably safe(< 30 sec):`make config-merge` / `make config-full` / `make config-validate`

**錯誤 pattern**:

```yaml
# ❌ Claude Code Bash 中這樣寫 — subprocess SIGTERM
Bash:
  command: "<長 R command> > /tmp/output.log 2>&1"
  run_in_background: true
```

**正確 pattern**:

```yaml
# ✅ Foreground synchronous(timeout 內)
Bash:
  command: "NOT_CRAN=true Rscript -e 'testthat::test_dir(...)'"
  # 不設 run_in_background — harness 同步等到結束
  timeout: 600000   # 10 min,依需求調整
```

```bash
# ✅ Shell-level & + pgrep 等候(處理超過 timeout 的長命令)
nohup <長 R command> > /tmp/output.log 2>&1 &
until ! pgrep -fl "Rscript.*<unique-pattern>" > /dev/null 2>&1; do sleep 5; done
cat /tmp/output.log
```

**驗證指令**(確認某 command 是否受影響):

```bash
# In Claude Code session:
Bash command "<your command>" with run_in_background: true
# 然後立即:
tail -20 /tmp/output.log    # 應該有 substantive output
ps aux | grep -i Rscript    # R subprocess 應該還活著
```

> 受影響:log 截在開頭、無 R process 還活著。
> 不受影響:log 持續寫、R process 持續存在。

**詳細資料**:見 #593(E2E case 的完整診斷)+ #594(generalize across long R commands)+ `08-shiny-testing.md` 的 `### ⚠️ AI session 必看` subsection。

---

## 執行方式

### 工作目錄
**專案根目錄** 是工作目錄，不是 app 資料夾：
```
/Users/che/.../MAMBA/   ← 從這裡執行
```

### 啟動 App
```r
# 在 RStudio 或 R console
source("app.R")

# 或使用 Rscript
Rscript app.R
```

---

## 登入資訊

### 測試用密碼（只要輸入密碼的情況）
```
VIBE
```

### 測試用帳號密碼（要輸入帳號密碼的情況）
```
帳號：admin
密碼：618112
```

---

## 常見問題

### 路徑錯誤
如果遇到 `Error in source()` 或找不到檔案：
- 確認工作目錄是專案根目錄
- 使用 `getwd()` 檢查目前目錄
- 使用 `setwd()` 切換到正確目錄

### 資料庫連線
App 啟動時會自動連接 `data/app_data/app_data.duckdb`。
確保資料庫檔案存在且未被其他程序鎖定。

---

## E2E 測試

修改核心功能後、部署前，使用 **shinytest2** 執行自動化 E2E 測試。

詳細說明請參考 `08-shiny-testing.md`。

### 快速執行
```bash
cd D_RACING
Rscript -e "testthat::test_dir('scripts/global_scripts/98_test/e2e')"
```

### 互動式測試（除錯用）

使用 `/shiny-debug` 指令進行探索性測試和即時除錯。

### 各 App 測試端口
| App | 端口 |
|-----|------|
| BrandEdge | 3838 |
| InsightForge | 3839 |
| VitalSigns | 3840 |
