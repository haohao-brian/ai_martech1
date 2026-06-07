---
issue: "ISSUE_034"
title: "統計分析組件應提供雙下載按鈕 - 完整數據與顯著結果"
severity: "medium"
priority: "medium"
component: "ui_components"
app: "mamba"
created: "2025-11-05"
status: "open"
estimated_effort: "0.5 day"
assigned_to: "principle-coder"
labels: ["ui", "download", "statistical-analysis", "ux", "data-export"]
affects_users: true
business_impact: "用戶無法靈活選擇下載完整數據或僅下載顯著結果"
---

## Problem Statement

統計分析組件（特別是 Poisson 回歸相關組件）目前的下載按鈕配置**不一致且不完整**。有些組件只提供「下載顯著結果」，有些只提供「下載完整數據」，用戶無法根據需求靈活選擇。

### User Impact

**嚴重性**: Medium
**影響範圍**: 所有統計分析組件（Poisson, Position, 等）
**用戶體驗**:
- 研究人員需要完整數據進行深入分析
- 業務人員只需要顯著結果用於決策
- 當前配置無法同時滿足兩種需求

## 📊 Current Status Audit

### Poisson Components Analysis

| 組件 | 當前下載按鈕 | 數據內容 | 缺少的按鈕 | 狀態 |
|------|------------|---------|-----------|------|
| **poissonFeatureAnalysis** | 「下載顯著結果」 | 僅 p < 0.05 數據 | ❌ 缺少「下載完整數據」 | 不合規 |
| **poissonCommentAnalysis** | 「下載完整數據」 | 所有數據（含顯著性標記） | ❌ 缺少「下載顯著結果」 | 不合規 |
| **poissonTimeAnalysis** | 「下載時間數據」 | 所有數據（含顯著性標記） | ❌ 缺少「下載顯著結果」 | 不合規 |

### 詳細分析

#### poissonFeatureAnalysis.R

**當前配置** (Line 260-264):
```r
downloadButton(ns("download_significant"),
              "下載顯著結果",
              class = "btn-success",
              icon = icon("download"))
```

**數據來源**:
- `positive_data()`: 包含所有符合條件的屬性（不只顯著的）
- 下載處理器中才篩選 `filter(p_value < 0.05)`

**問題**:
- ✅ 有「下載顯著結果」
- ❌ **缺少「下載完整數據」** - 研究人員無法獲得所有分析結果進行深入研究

**建議修復**:
```r
# 雙按鈕佈局
div(class = "table-control-bar",
    style = "display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 15px;",

    # 完整數據下載
    downloadButton(ns("download_full"),
                  "下載完整數據",
                  class = "btn-primary btn-sm",
                  icon = icon("download")),

    # 顯著結果下載
    downloadButton(ns("download_significant"),
                  "下載顯著結果",
                  class = "btn-success btn-sm",
                  icon = icon("download")))
```

#### poissonCommentAnalysis.R

**當前配置** (Line 134-137):
```r
downloadButton(ns("download_analysis"),
               "下載完整數據",
               class = "btn-success",
               icon = icon("download"))
```

**數據來源**:
- `positive_data()`: 包含所有口碑指標數據
- 下載時添加 `significance` 欄位標記，但不篩選

**問題**:
- ✅ 有「下載完整數據」
- ❌ **缺少「下載顯著結果」** - 業務人員需要快速聚焦顯著指標

**建議修復**: 同上雙按鈕模式

#### poissonTimeAnalysis.R

**當前配置** (Line 172-175):
```r
downloadButton(ns("download_time_data"),
               "下載時間數據",
               class = "btn-success",
               icon = icon("download"))
```

**數據來源**:
- `filtered_data()`: 包含所有時間維度分析結果
- 下載時添加 `significance` 欄位，但不篩選

**問題**:
- ✅ 有「下載完整數據」（雖然按鈕文字不清楚）
- ❌ **缺少「下載顯著結果」**
- ⚠️ 按鈕文字應改為「下載完整數據」更清楚

**建議修復**: 同上雙按鈕模式 + 更新按鈕文字

## 💡 Proposed Solution: UI_R021

### New Rule: Dual Download Buttons for Statistical Data

**規則編號**: UI_R021
**規則名稱**: Dual Download Buttons for Statistical Analysis Components

#### Core Requirements

1. **統計分析組件必須提供雙下載按鈕**（當數據包含統計顯著性時）:
   - **下載完整數據**: 包含所有分析結果（含不顯著的）
   - **下載顯著結果**: 僅包含統計顯著（通常 p < 0.05）的結果

2. **按鈕佈局標準**:
   - 兩個按鈕並排放置（使用 `gap` 間距）
   - **完整數據**: `btn-primary`（藍色，主要操作）
   - **顯著結果**: `btn-success`（綠色，次要但重要）
   - 統一使用 `btn-sm` 小尺寸

3. **數據內容要求**:
   - **完整數據**: 必須包含 `顯著性` 或 `significance` 欄位標記
   - **顯著結果**: 僅包含符合顯著性閾值的數據（預設 p < 0.05）

4. **命名一致性**:
   - 完整數據按鈕: `download_full` / `download_full_data`
   - 顯著結果按鈕: `download_significant` / `download_significant_data`

#### When to Apply This Rule

**必須應用** (統計分析組件):
- ✅ Poisson regression components
- ✅ Linear regression components
- ✅ Statistical hypothesis testing components
- ✅ Any component with p-values and significance testing

**不需要應用** (非統計組件):
- ❌ Simple data tables (no statistical testing)
- ❌ Visualization-only components
- ❌ Configuration/settings exports

### Standard Implementation Pattern

```r
# UI Layer
div(class = "table-control-bar",
    style = "display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 15px;",

    # Following UI_R021: Dual download buttons for statistical data
    downloadButton(ns("download_full"),
                  translate("Download Full Data"),
                  class = "btn-primary btn-sm",
                  icon = icon("download")),

    downloadButton(ns("download_significant"),
                  translate("Download Significant Results"),
                  class = "btn-success btn-sm",
                  icon = icon("download")))

# Server Layer - Full Data Download
output$download_full <- downloadHandler(
  filename = function() {
    paste0("分析完整數據_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    data <- analysis_results()  # All data

    # Add significance marker
    table_data <- data %>%
      mutate(
        significance = case_when(
          is.na(p_value) ~ "",
          p_value < 0.001 ~ "***",
          p_value < 0.01 ~ "**",
          p_value < 0.05 ~ "*",
          TRUE ~ ""
        )
      )

    # Following UI_R020: UTF-8 BOM
    write_utf8_csv_with_bom(table_data, file)
  }
)

# Server Layer - Significant Results Download
output$download_significant <- downloadHandler(
  filename = function() {
    paste0("分析顯著結果_", format(Sys.Date(), "%Y%m%d"), ".csv")
  },
  content = function(file) {
    data <- analysis_results() %>%
      filter(!is.na(p_value) & p_value < 0.05)  # Only significant

    # Add significance marker
    table_data <- data %>%
      mutate(
        significance = case_when(
          p_value < 0.001 ~ "***",
          p_value < 0.01 ~ "**",
          p_value < 0.05 ~ "*",
          TRUE ~ ""
        )
      )

    # Following UI_R020: UTF-8 BOM
    write_utf8_csv_with_bom(table_data, file)
  }
)
```

## 🔧 Implementation Plan

### Phase 1: 修復 poissonFeatureAnalysis (1h)

**添加「下載完整數據」按鈕**:

1. **UI 修改** (Line 255-264):
   - 將單按鈕改為雙按鈕佈局
   - 添加 `gap: 10px` 間距
   - 調整按鈕樣式（btn-sm）

2. **Server 修改**:
   - 重命名現有處理器為 `output$download_significant`（保持不變）
   - 新增 `output$download_full` 處理器
   - 下載 `positive_data()` 所有數據（不篩選 p-value）
   - 添加 `significance` 欄位標記

### Phase 2: 修復 poissonCommentAnalysis (1h)

**添加「下載顯著結果」按鈕**:

1. **UI 修改** (Line 132-137):
   - 改為雙按鈕佈局
   - 重命名現有按鈕為「下載完整數據」
   - 添加「下載顯著結果」按鈕

2. **Server 修改**:
   - 重命名現有處理器為 `output$download_full`（保持不變）
   - 新增 `output$download_significant` 處理器
   - 篩選 `p_value < 0.05` 的數據

### Phase 3: 修復 poissonTimeAnalysis (1h)

**更新按鈕文字並添加顯著結果下載**:

1. **UI 修改** (Line 170-175):
   - 改為雙按鈕佈局
   - 重命名「下載時間數據」為「下載完整數據」
   - 添加「下載顯著結果」按鈕

2. **Server 修改**:
   - 重命名 `download_time_data` 為 `download_full`
   - 新增 `output$download_significant` 處理器
   - 篩選 `p_value < 0.05 & significance == "顯著"` 的數據

### Phase 4: 創建 UI_R021 規則文檔 (1h)

使用 principle-revisor 創建規則文檔：
- 檔案: `UI_R021_dual_download_buttons_statistical.qmd`
- 位置: `scripts/global_scripts/00_principles/docs/en/part1_principles/CH04_ui_components/rules/`
- 內容: 參考上述 "Proposed Solution"

### Phase 5: 審核其他組件 (1h)

檢查是否有其他統計組件需要應用此規則：
- Position components
- Report components
- 其他回歸分析組件

## 📋 Implementation Checklist

### Phase 1: poissonFeatureAnalysis
- [ ] 修改 UI 為雙按鈕佈局
- [ ] 添加 `output$download_full` 處理器
- [ ] 測試兩個下載功能
- [ ] 驗證數據內容正確

### Phase 2: poissonCommentAnalysis
- [ ] 修改 UI 為雙按鈕佈局
- [ ] 添加 `output$download_significant` 處理器
- [ ] 測試兩個下載功能
- [ ] 驗證篩選邏輯正確

### Phase 3: poissonTimeAnalysis
- [ ] 修改 UI 為雙按鈕佈局
- [ ] 重命名按鈕和處理器
- [ ] 添加 `output$download_significant` 處理器
- [ ] 測試兩個下載功能

### Phase 4: 規則文檔
- [ ] 使用 principle-revisor 創建 UI_R021
- [ ] 包含實際程式碼範例
- [ ] 說明何時應用此規則
- [ ] 包含設計原理 (Rationale)

### Phase 5: 全面審核
- [ ] 審核所有 Position components
- [ ] 審核所有 Report components
- [ ] 更新組件清單
- [ ] 記錄合規狀態

## 🎯 Acceptance Criteria

### Functional Requirements
- [ ] 所有統計分析組件有雙下載按鈕
- [ ] 完整數據包含所有結果（含顯著性標記）
- [ ] 顯著結果僅包含 p < 0.05 的數據
- [ ] 按鈕文字清晰一致

### Quality Requirements
- [ ] 按鈕佈局一致（gap, size, color）
- [ ] 下載功能遵循 UI_R020（UTF-8 BOM）
- [ ] 檔名清楚區分完整/顯著
- [ ] 數據內容準確無誤

### Documentation Requirements
- [ ] UI_R021 規則文檔完成
- [ ] 包含完整實作範例
- [ ] 說明設計原理
- [ ] 列出適用範圍

## 📊 Design Rationale

### Why Dual Buttons?

#### User Personas

**研究人員 (Data Scientists)**:
- **需求**: 完整數據進行深入分析
- **使用情境**: 檢視不顯著結果，尋找趨勢，驗證假設
- **痛點**: 只有顯著結果無法進行完整分析

**業務人員 (Business Users)**:
- **需求**: 快速聚焦可行動的洞察
- **使用情境**: 基於顯著結果做決策
- **痛點**: 完整數據太多，難以快速找到重點

#### Benefits

1. **靈活性**: 用戶可根據需求選擇
2. **效率**: 業務人員不用手動篩選
3. **完整性**: 研究人員可獲得所有數據
4. **透明度**: 清楚標示數據範圍

### Why This Button Order?

**完整數據在左，顯著結果在右**:
- 完整數據是「原始」數據（Primary）
- 顯著結果是「篩選」數據（Secondary）
- 從左到右符合「從寬到窄」的認知順序

### Why These Colors?

- **btn-primary (藍色)**: 完整數據，主要資料來源
- **btn-success (綠色)**: 顯著結果，重要的發現

## 🔗 Related Principles

- **UI_R018**: Table Download Button Placement（按鈕位置）
- **UI_R020**: CSV UTF-8 BOM Standard（編碼標準）
- **MP114**: Input Validation（數據驗證）
- **MP122**: Transparency（透明度原則）

## 📝 User Communication

### To Users

```
【下載功能優化通知】

我們改進了統計分析的下載功能！

【新功能】
現在提供兩種下載選項：

✅ 下載完整數據
   • 包含所有分析結果
   • 適合深入研究和驗證
   • 含顯著性標記欄位

✅ 下載顯著結果
   • 僅包含統計顯著（p < 0.05）的結果
   • 適合快速決策和報告
   • 聚焦可行動的洞察

【適用組件】
• 精準行銷屬性分析
• 口碑影響力分析
• 時間區段分析
```

### To Developers

```
【UI_R021 規則發布】

新規則：統計分析組件雙下載按鈕標準

【核心要求】
1. 統計組件必須提供雙下載按鈕
2. 完整數據（所有結果 + 顯著性標記）
3. 顯著結果（僅 p < 0.05）

【實作要點】
• 按鈕佈局: flex + gap: 10px
• 顏色: btn-primary (完整), btn-success (顯著)
• 尺寸: btn-sm
• 編碼: 遵循 UI_R020 (UTF-8 BOM)

【參考文檔】
• 規則: UI_R021_dual_download_buttons_statistical.qmd
• 範例: poissonFeatureAnalysis.R (修復後)
```

## 📅 Timeline

**Target Completion**: 2025-11-06 (Day 2)

- **Hour 1**: Phase 1 - poissonFeatureAnalysis
- **Hour 2**: Phase 2 - poissonCommentAnalysis
- **Hour 3**: Phase 3 - poissonTimeAnalysis
- **Hour 4**: Phase 4 - UI_R021 規則文檔
- **Hour 5**: Phase 5 - 全面審核

---
**Created**: 2025-11-05
**Last Updated**: 2025-11-05
**Status**: Open (Working) - **MEDIUM PRIORITY**
**Estimated Completion**: 2025-11-06
