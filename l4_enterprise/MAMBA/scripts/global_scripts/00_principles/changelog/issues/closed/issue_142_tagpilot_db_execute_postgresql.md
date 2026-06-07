# Issue 142: TagPilot 上傳功能 PostgreSQL 參數佔位符修復

## 狀態
- **建立日期**: 2025-01-08
- **關閉日期**: 2025-01-08
- **狀態**: 已完成 (Completed)
- **優先級**: P0 (生產環境錯誤)
- **影響範圍**: TagPilot Premium

## 問題描述

### 症狀
TagPilot Premium 在 Posit Connect 上傳檔案時連續出現兩個錯誤：

**錯誤 1**:
```
檔案處理錯誤: could not find function "db_execute"
```

**錯誤 2** (修復錯誤 1 後):
```
Failed to prepare query : ERROR: syntax error at or near ","
LINE 1: ...NSERT INTO rawdata (user_id,uploaded_at,json) VALUES (?,?,?)
```

### 根本原因

1. **缺少函數**: `db_connection.R` 沒有定義 `db_execute` 函數，但 `module_tagpilot_upload.R` 第 229 行呼叫了它

2. **佔位符不相容**: RPostgres (PostgreSQL) 不支援 `?` 佔位符，只支援 `$1, $2, $3` 格式
   - SQLite/RSQLite: 支援 `?`, `$1`, `:name`
   - PostgreSQL/RPostgres: 只支援 `$1`, `$2`, `$3`
   - DBI 不會自動轉換佔位符格式

參考: https://github.com/r-dbi/RPostgres/issues/201

## 解決方案

### 修復 1: 加入 `db_execute` 和 `db_query` 函數

在 `database/db_connection.R` 加入這兩個輔助函數，提供與 BrandEdge 相容的 API。

### 修復 2: 加入 `convert_placeholders` 函數

新增佔位符轉換函數，在執行 SQL 前自動將 `?` 轉換為 `$1, $2, $3`（僅 PostgreSQL 連接時）。

```r
convert_placeholders <- function(sql, con) {
  # 只有 PostgreSQL (Pool 或 PqConnection) 需要轉換
  if (inherits(con, "Pool") || inherits(con, "PqConnection")) {
    count <- 0
    while (grepl("\\?", sql)) {
      count <- count + 1
      sql <- sub("\\?", paste0("$", count), sql)
    }
  }
  return(sql)
}
```

### 修改檔案

| 檔案 | 修改內容 |
|------|---------|
| `sandbox_test/database/db_connection.R` | 加入 `convert_placeholders`, `db_query`, `db_execute` 函數 |

## 部署資訊

### GitHub Commits

| Commit | 說明 |
|--------|------|
| `7ffe267` | fix: add db_execute and db_query functions |
| `edfda72` | fix: use DBI::dbExecute instead of pool::dbExecute |
| `57b12b8` | fix: convert ? placeholders to PostgreSQL format $1, $2, $3 |

### 部署位置
- **App URL**: https://kyleyhl-sandbox-tagpilot.share.connect.posit.cloud/
- **GitHub Repo**: sandbox_tagpilot

## 技術說明

### 佔位符相容性表

| 資料庫 | 支援的佔位符 | 本地測試 | 正式環境 |
|--------|------------|----------|----------|
| SQLite (RSQLite) | `?`, `$1`, `:name` | ✅ | - |
| PostgreSQL (RPostgres) | `$1`, `$2`, `$3` | - | ✅ |

### 為什麼本地測試正常但正式環境失敗？

- **本地開發**: 使用 SQLite，支援 `?` 佔位符
- **正式環境**: 使用 PostgreSQL，只支援 `$1, $2, $3`
- **解決方案**: `convert_placeholders` 函數自動轉換，確保向下相容

## 相關原則

- **DM_R023**: Universal DBI Approach - 統一資料庫存取模式
- **MP064**: ETL-Derivation Separation - 資料處理分層

## 測試驗證

1. 登入 TagPilot Premium (admin / 12345)
2. 進入「資料上傳」功能
3. 上傳測試 CSV 檔案
4. 確認沒有 SQL 語法錯誤

---

**完成時間**: 2025-01-08
**執行者**: Claude Code
