---
issue: "ISSUE_106"
title: "四大模組AI報告Prompt整合"
severity: "high"
component: "ai_report_generation"
app: "brandedge"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
renamed_from: "ISSUE_119"
renamed_date: "2025-10-03"
renamed_reason: "Numbering conflict with Posit Connect variable timing fix (ISSUE_119)"
---

## Problem
四大模組的AI prompt需要加上去，目前無法輸出四大模組的整體AI報告。

## Expected Behavior
- 每個模組都應該有對應的AI prompt
- 能夠輸出四大模組的整體AI報告
- Prompt應參考Martech行銷洞察報告的格式

## Actual Behavior
- 四大模組缺少AI prompt
- 無法生成整體報告
- 缺乏統一的報告格式

## Proposed Resolution
1. 為四大模組分別建立AI prompt：
   - 精準行銷模組
   - 市場區隔分析模組
   - 品牌定位策略模組
   - 客戶DNA分析模組
2. 參考Martech行銷洞察報告的prompt格式
3. 建立整體報告生成機制
4. 確保報告內容的連貫性和完整性

## Detailed Implementation Plan (2025-09-23)

### 問題分析
使用者面臨的主要挑戰：
- **分散的結果**：四大模組的 AI 分析結果分散在不同的點擊介面
- **整合困難**：難以將分散的結果整合成一份完整報告
- **PDF 困難**：匯出 PDF 有技術障礙
- **老闆需求**：需要一份專業、完整的整體報告

### 解決方案：報告整合模組

#### 1. 核心架構
創建報告整合層，不需重構現有系統：
```
四大模組 → 報告整合中心 → 統一報告輸出
├─ Marketing Vital-Signs (行銷生命體徵)
├─ TagPilot (標籤導航)
├─ BrandEdge (品牌優勢，含6個子模組)
└─ InsightForge 360 (洞察熔爐，含3個子模組)
```

#### 2. 技術方案

##### A. 報告整合模組 (`reportIntegration.R`)
```r
reportIntegrationServer <- function(id, module_results, config = NULL) {
  moduleServer(id, function(input, output, session) {

    # 收集各模組結果
    collect_module_results <- function() {
      list(
        vital_signs = module_results$vital_signs(),
        tag_pilot = module_results$tag_pilot(),
        brand_edge = module_results$brand_edge(),
        insight_forge = module_results$insight_forge()
      )
    }

    # 生成整合報告
    generate_integrated_report <- function(results, type) {
      # 使用 AI 分析各模組結果的關聯性
      # 生成跨模組的策略建議
      # 輸出 HTML/PDF/Word 格式
    }
  })
}
```

##### B. 報告類型選擇
提供三種報告類型以滿足不同需求：
1. **執行摘要** (1-2頁) - 老闆急需時使用
2. **完整報告** (10-15頁) - 詳細分析
3. **技術報告** (含數據表格) - 技術團隊使用

##### C. 輸出格式（解決 PDF 困難）
```r
# 優先使用 HTML（易實現、美觀）
output$download_report <- downloadHandler(
  filename = function() {
    paste("martech_report_", Sys.Date(), ".", input$format, sep = "")
  },
  content = function(file) {
    if (input$format == "html") {
      # HTML 輸出 - 推薦方案
      writeLines(report_html, file)
    } else if (input$format == "pdf") {
      # PDF 輸出 - 使用 pagedown 或 chrome_print
      pagedown::chrome_print(html_file, file)
    } else if (input$format == "docx") {
      # Word 輸出 - 方便編輯
      officer::read_docx() %>%
        body_add_par(report_content) %>%
        print(target = file)
    }
  }
)
```

#### 3. 報告模板結構
```markdown
# MarTech AI 行銷洞察報告

## 執行摘要
- 關鍵發現（AI 自動總結）
- 建議優先行動（跨模組整合）

## 第一部分：Marketing Vital-Signs 分析
- RFM 指標現況
- 客戶健康度評估
- 趨勢分析

## 第二部分：TagPilot 市場區隔
- 客戶分群結果
- 各分群特徵
- 目標市場建議

## 第三部分：BrandEdge 品牌定位
- 競爭態勢分析
- 品牌差異化策略
- 定位建議

## 第四部分：InsightForge 360 深度洞察
- Poisson 迴歸分析
- 顧客DNA解析
- 預測模型結果

## 整合性策略建議
- 跨模組綜合分析（AI 生成）
- 行動方案優先順序
- KPI 設定建議
```

#### 4. UI 介面設計
```r
reportIntegrationUI <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "report-integration-panel",
      h3("AI 行銷洞察報告生成"),

      # 報告設定
      fluidRow(
        column(4,
          selectInput(ns("report_type"),
            "報告類型",
            choices = list(
              "執行摘要 (1-2頁)" = "executive",
              "完整報告 (10-15頁)" = "full",
              "技術報告 (含數據)" = "technical"
            )
          )
        ),
        column(4,
          selectInput(ns("output_format"),
            "輸出格式",
            choices = list(
              "HTML (推薦)" = "html",
              "PDF" = "pdf",
              "Word" = "docx"
            )
          )
        ),
        column(4,
          br(),
          actionButton(ns("generate"),
            "生成報告",
            class = "btn-primary",
            icon = icon("file-alt")
          )
        )
      ),

      # 模組選擇
      checkboxGroupInput(ns("modules"),
        "選擇要包含的模組",
        choices = list(
          "Marketing Vital-Signs" = "vital_signs",
          "TagPilot 市場區隔" = "tag_pilot",
          "BrandEdge 品牌定位" = "brand_edge",
          "InsightForge 360" = "insight_forge"
        ),
        selected = c("vital_signs", "tag_pilot", "brand_edge", "insight_forge"),
        inline = TRUE
      ),

      # 報告預覽
      uiOutput(ns("report_preview")),

      # 下載按鈕
      downloadButton(ns("download_report"), "下載報告")
    )
  )
}
```

#### 5. 實施步驟

##### Phase 1: 基礎架構 (2天)
1. 創建 `reportIntegration` 模組
2. 實作結果收集機制
3. 建立基本 HTML 報告模板

##### Phase 2: AI 整合 (2天)
1. 設計跨模組分析 prompt
2. 實作 AI 洞察生成
3. 整合到報告內容

##### Phase 3: 輸出優化 (1天)
1. 美化 HTML 報告樣式
2. 測試 PDF 輸出（可選）
3. 加入圖表和視覺化

##### Phase 4: 整合測試 (1天)
1. 與四大模組整合
2. 端到端測試
3. 效能優化

### 關鍵優勢

1. **不需重構**：只需加入整合層，不影響現有模組
2. **彈性選擇**：用戶可選擇包含哪些模組
3. **快速輸出**：老闆急需時可只生成執行摘要
4. **HTML 優先**：避開 PDF 技術困難
5. **AI 加值**：不只拼接，而是智能分析關聯性

### 替代方案（如果上述太複雜）

#### 簡化版：靜態報告頁面
創建獨立的報告 nav_panel，預先載入所有模組結果：
```r
nav_panel(
  title = "整體報告",
  div(class = "integrated-report",
    h2("MarTech AI 行銷洞察報告"),
    tabsetPanel(
      tabPanel("執行摘要", summaryUI()),
      tabPanel("Vital-Signs", vitalSignsReportUI()),
      tabPanel("TagPilot", tagPilotReportUI()),
      tabPanel("BrandEdge", brandEdgeReportUI()),
      tabPanel("InsightForge", insightForgeReportUI())
    )
  )
)
```

這樣至少能在一個頁面看到所有結果，用瀏覽器的列印功能也能輸出 PDF。

### 預期成果
- 老闆可以看到整合的專業報告
- 解決了分散結果的問題
- HTML 格式避開 PDF 技術困難
- AI 加值提供跨模組洞察

## 實施結果 (2025-09-23)

### 已完成的實作

#### 1. 報告整合模組
創建了 `/scripts/global_scripts/10_rshinyapp_components/report/reportIntegration/reportIntegration.R`
- 實作 `extract_reactive_value()` 函數安全擷取 reactive 資料
- 整合九個分析組件的實際結果
- 生成 HTML 格式的專業報告

#### 2. UI 整合調整
根據使用者回饋修改：
- **移除模組選擇**：報告自動包含所有分析，不需手動選擇
- **調整按鈕位置**：生成報告按鈕移到左下角 filter panel
- **簡化操作流程**：一鍵生成完整報告

#### 3. 資料擷取驗證
確認報告真正擷取各組件的實際分析結果：
```
Marketing Vital-Signs
├─ 宏觀指標 (kpi_data)
└─ 顧客DNA分佈 (distribution_data)

TagPilot
└─ 顧客DNA分析 (analysis_result)

BrandEdge
├─ 品牌定位策略 (strategy_result)
├─ 市場區隔分析 (segment_data)
└─ 關鍵因素分析 (key_factors)

InsightForge 360
├─ 市場賽道分析 (track_analysis)
├─ 時間趨勢 (trend_data)
└─ 精準行銷 (precision_data)
```

#### 4. 技術問題解決
**問題**：初始版本輸出函數對象而非資料
```
function () { .dependents$register() if (.invalidated || .running)...
```

**解決方案**：
- 診斷出 reactive 值未正確呼叫的問題
- 實作智能的 `extract_reactive_value()` 函數
- 處理各種 reactive 結構（reactive、reactiveVal、list、普通值）

### 關鍵技術細節

#### extract_reactive_value 函數
```r
extract_reactive_value <- function(obj, field = NULL) {
  tryCatch({
    # 處理 reactive 或 reactiveVal
    if (is.reactive(obj) || is.function(obj)) {
      val <- obj()
    } else {
      val <- obj
    }

    # 如果指定了 field，嘗試提取
    if (!is.null(field) && is.list(val)) {
      return(val[[field]])
    }

    return(val)
  }, error = function(e) {
    return(NULL)
  })
}
```

這個函數解決了不同模組返回不同結構的問題，確保報告能正確擷取資料。

### 使用方式
1. 點擊側邊欄 "Report Center"
2. 在左下角 filter panel 點擊「生成整合報告」
3. 系統自動收集所有模組結果並生成報告
4. 報告基於當前選擇的 platform 和 product_line

### 待優化項目
1. 加入 AI 整合分析（跨模組洞察）
2. 美化 HTML 報告樣式
3. 加入圖表視覺化
4. 實作 PDF 輸出（未來需求）

## Priority
High - 核心功能缺失，影響報告生成

## Related Issues
- ISSUE_134, ISSUE_135, ISSUE_138, ISSUE_139