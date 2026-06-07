---
issue: "ISSUE_039"
title: "下載檔案 UTF-8 編碼問題 - Excel 開啟中文亂碼"
severity: "high"
priority: "high"
component: "data_export"
app: "mamba"
created: "2025-11-05"
completed: "2025-11-05"
status: "resolved"
estimated_effort: "0.5 day"
actual_effort: "0.5 day"
assigned_to: "principle-coder"
labels: ["encoding", "utf-8", "csv", "excel", "i18n", "ux"]
affects_users: true
business_impact: "用戶無法正確查看下載的中文數據"
resolution: "創建標準化 UTF-8 BOM 工具函數並修復所有 5 個組件的下載功能；建立 UI_R020 規則文檔"
---

## Problem Statement

所有組件的下載功能在 Excel 中開啟時出現**中文亂碼問題**。雖然檔案使用 UTF-8 編碼，但 Excel 無法正確識別，導致中文顯示為亂碼（如：������）。

### User Impact

**嚴重性**: High
**影響範圍**: 所有包含中文的下載功能
**用戶體驗**: 用戶下載數據後無法直接使用，需要手動轉換編碼

## 🔍 Technical Analysis

### Root Cause

| 問題類型 | 根本原因 | 影響組件 |
|---------|---------|---------|
| **CSV UTF-8 無 BOM** | `write.csv(fileEncoding = "UTF-8")` 產生的是無 BOM 的 UTF-8 檔案 | poissonCommentAnalysis, poissonTimeAnalysis, positionTable |
| **Excel 預設編碼** | Excel 在 Windows 上預設使用系統編碼（Big5），無法自動偵測 UTF-8 | 所有 CSV 匯出 |
| **相容性問題** | `writexl::write_xlsx()` 在某些 Excel 版本可能有編碼問題 | poissonFeatureAnalysis |

### Current Implementation

#### CSV 匯出組件 (3個)

**poissonCommentAnalysis** (Line 599-640)
```r
output$download_analysis <- downloadHandler(
  filename = function() {
    paste0("InsightForge_口碑影響力分析_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    # ...
    write.csv(table_data, file, row.names = FALSE, fileEncoding = "UTF-8")
    # ❌ 問題：無 UTF-8 BOM，Excel 無法識別
  }
)
```

**poissonTimeAnalysis** (Line 638-690)
```r
output$download_time_data <- downloadHandler(
  filename = function() {
    paste0("時間區段分析結果_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    # ...
    write.csv(table_data, file, row.names = FALSE, fileEncoding = "UTF-8")
    # ❌ 問題：無 UTF-8 BOM，Excel 無法識別
  }
)
```

**positionTable** (Line 882-909, positionTable.R)
```r
output$download_position_data <- downloadHandler(
  filename = function() {
    paste0("position_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
  },
  content = function(file) {
    # ...
    write.csv(data, file, row.names = FALSE, fileEncoding = "UTF-8")
    # ❌ 問題：無 UTF-8 BOM，Excel 無法識別
  }
)
```

#### Excel 匯出組件 (1個)

**poissonFeatureAnalysis** (Line 892-959)
```r
output$download_significant <- downloadHandler(
  filename = function() {
    paste0("InsightForge_顯著屬性分析_", Sys.Date(), ".xlsx")
  },
  content = function(file) {
    # ...
    writexl::write_xlsx(table_data, path = file)
    # ⚠️ 問題：理論上支持 UTF-8，但在某些 Excel 版本可能有問題
  }
)
```

### Why UTF-8 BOM Matters

**UTF-8 BOM (Byte Order Mark)**:
- 檔案開頭的特殊標記：`EF BB BF`
- 告訴 Excel：「這是 UTF-8 編碼」
- 有 BOM = Excel 自動用 UTF-8 開啟 ✅
- 無 BOM = Excel 用系統編碼開啟 ❌

## 💡 Solution Architecture

### Strategy: UTF-8 BOM for CSV

採用 **UTF-8 with BOM** 策略，確保 Excel 相容性：

#### 優點
- ✅ Excel 可正確識別 UTF-8 編碼
- ✅ 不需要額外套件
- ✅ 檔案小，效能好
- ✅ 跨平台相容性佳
- ✅ 向後相容（其他軟體也能讀取）

#### 缺點
- ⚠️ 需要手動添加 BOM（3 bytes）
- ⚠️ 少數純文字編輯器可能顯示 BOM 字符（罕見）

### Implementation Plan

#### Phase 1: 創建標準化工具函數 (2h)

**檔案位置**: `scripts/global_scripts/04_utils/fn_write_utf8_csv.R`

```r
#' Write CSV with UTF-8 BOM for Excel Compatibility
#'
#' @description
#' Writes a CSV file with UTF-8 encoding and BOM (Byte Order Mark).
#' The BOM ensures Excel can correctly identify and display Chinese characters.
#'
#' @principle UI_R020 UTF-8 BOM for Excel Compatibility
#' @principle MP114 Input Validation
#'
#' @param data data.frame. The data to export
#' @param file character. The output file path
#' @param na character. String to use for missing values (default: "")
#' @param row.names logical. Include row names? (default: FALSE)
#'
#' @return Invisible NULL. File is written as side effect.
#'
#' @examples
#' write_utf8_csv_with_bom(mtcars, "output.csv")
#'
#' @export
write_utf8_csv_with_bom <- function(data, file, na = "", row.names = FALSE) {
  # MP114: Input validation
  if (!is.data.frame(data)) {
    stop("data must be a data.frame")
  }

  if (nrow(data) == 0) {
    warning("Exporting empty data frame")
  }

  # Create temporary file
  temp_file <- tempfile(fileext = ".csv")

  # Write CSV with UTF-8 encoding (without BOM)
  write.csv(data,
            file = temp_file,
            row.names = row.names,
            na = na,
            fileEncoding = "UTF-8")

  # Read the file as binary
  csv_content <- readBin(temp_file, "raw", file.info(temp_file)$size)

  # UTF-8 BOM: EF BB BF
  bom <- as.raw(c(0xEF, 0xBB, 0xBF))

  # Write BOM + content to final file
  writeBin(c(bom, csv_content), file)

  # Clean up
  unlink(temp_file)

  invisible(NULL)
}


#' Create Standard Download Handler with UTF-8 BOM
#'
#' @description
#' Creates a standardized downloadHandler for CSV exports with UTF-8 BOM.
#' Ensures Excel compatibility for Chinese characters.
#'
#' @principle UI_R020 UTF-8 BOM for Excel Compatibility
#' @principle UI_R018 Download Button Placement
#'
#' @param data_reactive reactive. Reactive expression returning data frame
#' @param filename_prefix character. Prefix for the filename
#' @param date_format character. Format for date in filename (default: "%Y%m%d")
#'
#' @return downloadHandler object for use in Shiny output
#'
#' @examples
#' output$download_data <- create_utf8_csv_download_handler(
#'   data_reactive = filtered_data,
#'   filename_prefix = "analysis_results"
#' )
#'
#' @export
create_utf8_csv_download_handler <- function(data_reactive,
                                               filename_prefix = "data",
                                               date_format = "%Y%m%d") {
  downloadHandler(
    filename = function() {
      paste0(filename_prefix, "_", format(Sys.Date(), date_format), ".csv")
    },
    content = function(file) {
      data <- data_reactive()

      # Validation
      if (is.null(data) || nrow(data) == 0) {
        # Write empty message with UTF-8 BOM
        empty_df <- data.frame(Message = "無可用資料")
        write_utf8_csv_with_bom(empty_df, file)
        return()
      }

      # Write data with UTF-8 BOM
      write_utf8_csv_with_bom(data, file)
    }
  )
}
```

#### Phase 2: 修復所有 CSV 匯出 (1.5h)

**2.1 poissonCommentAnalysis** (Line 599)
```r
# 修改前
output$download_analysis <- downloadHandler(
  filename = function() {
    paste0("InsightForge_口碑影響力分析_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    # ... prepare data ...
    write.csv(table_data, file, row.names = FALSE, fileEncoding = "UTF-8")  # ❌
  }
)

# 修改後
output$download_analysis <- downloadHandler(
  filename = function() {
    paste0("InsightForge_口碑影響力分析_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    # ... prepare data ...
    write_utf8_csv_with_bom(table_data, file)  # ✅ 使用工具函數
  }
)
```

**2.2 poissonTimeAnalysis** (Line 638)
```r
# 同樣替換 write.csv 為 write_utf8_csv_with_bom
```

**2.3 positionTable** (Line 882-909)
```r
# 同樣替換 write.csv 為 write_utf8_csv_with_bom
```

#### Phase 3: 驗證 Excel 匯出 (0.5h)

**3.1 poissonFeatureAnalysis** (Line 892)

檢查 `writexl::write_xlsx()` 在不同 Excel 版本的表現：
- Excel 2016+ (Windows)
- Excel 2019+ (macOS)
- Office 365

如果有問題，考慮：
- 選項 A: 改用 `openxlsx::write.xlsx()` with UTF-8
- 選項 B: 改用 CSV with UTF-8 BOM

#### Phase 4: 測試與驗證 (1h)

**測試清單**:

| 組件 | 格式 | Windows Excel | macOS Excel | 測試人員 |
|------|------|---------------|-------------|---------|
| poissonFeatureAnalysis | .xlsx | ⬜ | ⬜ | TBD |
| poissonCommentAnalysis | .csv | ⬜ | ⬜ | TBD |
| poissonTimeAnalysis | .csv | ⬜ | ⬜ | TBD |
| positionTable | .csv | ⬜ | ⬜ | TBD |

**驗證步驟**:
1. 下載檔案
2. 直接用 Excel 雙擊開啟
3. 檢查中文是否正確顯示
4. 檢查數據完整性
5. 檢查格式是否正確

#### Phase 5: 文檔更新 (0.5h)

**創建新規範**: `UI_R020_utf8_bom_excel_compatibility.qmd`

```markdown
# UI_R020: UTF-8 BOM for Excel Compatibility

## Core Rule

所有包含中文的 CSV 匯出必須使用 **UTF-8 with BOM** 編碼。

## Rationale

- Excel 在 Windows 上預設使用系統編碼（Big5）
- UTF-8 BOM 是唯一能讓 Excel 自動識別 UTF-8 的方法
- 確保用戶下載後可直接開啟，無需額外步驟

## Standard Pattern

```r
# 使用標準化工具函數
output$download_data <- downloadHandler(
  filename = function() {
    paste0("data_", Sys.Date(), ".csv")
  },
  content = function(file) {
    data <- prepare_data()
    write_utf8_csv_with_bom(data, file)  # ✅ 正確
  }
)
```

## Anti-Patterns

```r
# ❌ 錯誤：無 BOM
write.csv(data, file, fileEncoding = "UTF-8")

# ❌ 錯誤：使用 Big5（不跨平台）
write.csv(data, file, fileEncoding = "Big5")

# ❌ 錯誤：無指定編碼（系統相依）
write.csv(data, file)
```

## Related Principles

- UI_R018: Download Button Placement
- MP114: Input Validation
- MP122: Transparency (編碼資訊應明確)
```

## 📋 Implementation Checklist

### Phase 1: 工具函數 (2h)
- [ ] 創建 `fn_write_utf8_csv.R`
- [ ] 實作 `write_utf8_csv_with_bom()`
- [ ] 實作 `create_utf8_csv_download_handler()`
- [ ] 添加單元測試
- [ ] 添加範例文檔

### Phase 2: 修復組件 (1.5h)
- [ ] poissonCommentAnalysis (Line 599-640)
- [ ] poissonTimeAnalysis (Line 638-690)
- [ ] positionTable (Line 882-909, positionTable.R)
- [ ] 檢查其他可能的 CSV 匯出

### Phase 3: Excel 驗證 (0.5h)
- [ ] 測試 poissonFeatureAnalysis Excel 匯出
- [ ] 檢查不同 Excel 版本相容性
- [ ] 必要時切換到 UTF-8 BOM CSV

### Phase 4: 測試 (1h)
- [ ] Windows Excel 2016+ 測試
- [ ] macOS Excel 測試
- [ ] Office 365 測試
- [ ] 跨瀏覽器下載測試（Chrome, Firefox, Safari, Edge）

### Phase 5: 文檔 (0.5h)
- [ ] 創建 UI_R020 規範文件
- [ ] 更新組件文檔
- [ ] 更新開發指南

## 🎯 Acceptance Criteria

### Functional Requirements
- [ ] 所有 CSV 匯出使用 UTF-8 BOM
- [ ] Excel 可正確開啟並顯示中文
- [ ] 數據完整性保持（無資料遺失或損壞）
- [ ] 檔名包含中文時也能正確顯示

### Quality Requirements
- [ ] 跨平台相容（Windows, macOS）
- [ ] 跨瀏覽器相容
- [ ] 向後相容（舊檔案仍可讀取）
- [ ] 效能無明顯影響（< 100ms 額外時間）

### Documentation Requirements
- [ ] UI_R020 規範文件完成
- [ ] 工具函數有完整文檔和範例
- [ ] 開發者指南更新
- [ ] 遷移指南完成

## 📊 Testing Matrix

| 測試項目 | Windows | macOS | Linux | 結果 |
|---------|---------|-------|-------|------|
| **Excel 開啟** |
| - 中文檔名 | ⬜ | ⬜ | N/A | - |
| - 中文內容 | ⬜ | ⬜ | N/A | - |
| - 特殊字符 | ⬜ | ⬜ | N/A | - |
| **其他軟體** |
| - Google Sheets | ⬜ | ⬜ | ⬜ | - |
| - LibreOffice | ⬜ | ⬜ | ⬜ | - |
| - Numbers (macOS) | N/A | ⬜ | N/A | - |
| **文字編輯器** |
| - Notepad++ | ⬜ | N/A | N/A | - |
| - VSCode | ⬜ | ⬜ | ⬜ | - |
| - TextEdit | N/A | ⬜ | N/A | - |

## 🔧 Technical Details

### UTF-8 BOM Specification

**BOM Bytes**: `EF BB BF`
**Position**: First 3 bytes of file
**Purpose**: Signal to software that file is UTF-8 encoded

### File Size Impact

- BOM adds: **3 bytes**
- Typical CSV: ~10KB - 1MB
- Impact: **< 0.001%** increase
- Performance: **Negligible**

### Alternative Solutions Considered

#### Option A: UTF-8 without BOM ❌
- **Pros**: Standard UTF-8
- **Cons**: Excel can't detect, requires manual import
- **Verdict**: Not user-friendly

#### Option B: Big5 Encoding ❌
- **Pros**: Excel default on Windows Traditional Chinese
- **Cons**: Not portable, breaks on other systems
- **Verdict**: Not sustainable

#### Option C: UTF-16 LE with BOM ⚠️
- **Pros**: Excel auto-detects
- **Cons**: Double file size, non-standard for CSV
- **Verdict**: Overkill

#### Option D: UTF-8 with BOM ✅
- **Pros**: Excel compatible, standard, portable
- **Cons**: Minimal (3 byte overhead)
- **Verdict**: **Recommended**

## 📝 Communication Plan

### To Users

```
【數據匯出優化通知】

我們修復了下載檔案的編碼問題！

【問題】
之前下載的 CSV 檔案用 Excel 開啟時，中文會變成亂碼。

【解決方案】
所有下載檔案現在都使用 UTF-8 BOM 編碼，確保：
✅ Excel 可以直接開啟
✅ 中文正確顯示
✅ 無需手動轉換編碼

【影響範圍】
- 精準行銷分析下載
- 時間區段分析下載
- 品牌定位表格下載
- 所有其他資料匯出

【操作方式】
完全不變！下載後直接用 Excel 開啟即可。
```

### To Developers

```
【編碼標準更新 - UI_R020】

新規範：所有 CSV 匯出必須使用 UTF-8 BOM

【工具函數】
- write_utf8_csv_with_bom(data, file)
- create_utf8_csv_download_handler(data_reactive, prefix)

【遷移指南】
替換所有：
  write.csv(data, file, fileEncoding = "UTF-8")
改為：
  write_utf8_csv_with_bom(data, file)

【文檔】
- 工具函數文檔：scripts/global_scripts/04_utils/fn_write_utf8_csv.R
- 規範文件：UI_R020_utf8_bom_excel_compatibility.qmd

【問題回報】
如發現任何編碼問題，請回報 ISSUE_245
```

## 🔗 Related Issues

- ISSUE_244D: UI_R018 Download Button Placement (已完成)
- ISSUE_108: Enhanced Statistical Information in Exports (已完成)

## 📅 Timeline

**Target Completion**: 2025-11-06 (Day 2)

- **Hour 1-2**: 創建工具函數和測試
- **Hour 3**: 修復所有 CSV 匯出
- **Hour 4**: 測試和驗證
- **Hour 5**: 文檔更新

---
**Created**: 2025-11-05
**Last Updated**: 2025-11-05
**Status**: Open (Working) - **HIGH PRIORITY**
**Estimated Completion**: 2025-11-06
