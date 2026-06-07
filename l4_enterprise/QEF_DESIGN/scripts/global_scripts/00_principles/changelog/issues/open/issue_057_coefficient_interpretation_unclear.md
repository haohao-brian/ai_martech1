---
issue: "ISSUE_057"
title: "係數解讀與影響效果不明確"
severity: "high"
component: "precision_marketing_model"
app: "mamba"
created: "2025-09-08"
status: "in_progress"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
品牌效應能帶進16.9倍的銷售？factor是屬性？numeric昨天說是口碑量，對銷售會帶來1560倍影響，price也會影響銷售，但看不出影響效果是多少？無法點擊查看詳細資訊。

## Expected Behavior
- 清楚顯示各因素對銷售的實際影響倍數
- 明確定義factor, numeric等變數類型
- 可點擊查看詳細解釋
- 合理的影響倍數（1560倍過高）

## Actual Behavior
- 影響倍數解讀不清（16.9倍、1560倍）
- 變數類型定義混亂
- 無法點擊獲得更多資訊
- price影響效果不明

## Root Cause Analysis (根本原因分析)

### 1. 數學原因 - Poisson 迴歸的指數轉換問題
Poisson 迴歸使用對數連結函數，導致係數解釋時需要指數轉換：

```r
# 現有計算方式
log(λ) = β₀ + β₁*X₁ + β₂*X₂ + ...
λ = exp(β₀ + β₁*X₁ + β₂*X₂ + ...)

# 問題：當變數值很大時
# 例：track_width = 20, coefficient = 0.35
# impact = exp(20 * 0.35) = exp(7) = 1097倍！
```

### 2. 缺乏變數標準化
- **問題**：不同變數的尺度差異巨大
  - track_width：範圍 0-30
  - price：範圍 0-100
  - rating：範圍 0-5
- **結果**：相同係數產生極端不同的影響倍數

### 3. Track Multiplier 計算問題 (已修正 2025-09-09)
**原問題**：固定使用 4 次方計算，假設所有屬性範圍為 4 個單位
```r
# 舊計算方式 (line 295)
track_multiplier = round(pmin(incidence_rate_ratio ^ 4, 100), 1)
```

**已修正為**：使用實際範圍計算
```r
# 新計算方式 - 使用 actual_range 欄位
actual_range <- df_cbz_poisson_analysis_alf$actual_range[
  df_cbz_poisson_analysis_alf$feature == feature_name
]
track_multiplier = round(pmin(incidence_rate_ratio ^ actual_range, 100), 1)
```

**修正理由**：
- 用戶發現「為什麼是4次方？」的問題
- 調查後發現假設所有屬性都有 4 個單位的範圍不合理
- 應從 `df_cbz_poisson_analysis_alf` 表獲取實際範圍
- 1560倍可能是合理的，如果它真實反映了最好與最壞的差別

### 4. UI 展示不完整
**目前顯示**：
- ✅ 變數名稱
- ✅ 影響倍數（但計算有誤）

**缺少的關鍵資訊**：
- ❌ p-value（統計顯著性）
- ❌ 信賴區間
- ❌ 原始係數值
- ❌ 變數的實際範圍
- ❌ 標準誤差
- ❌ 解釋性文字

## Business Impact (業務影響)

1. **決策風險**：
   - 管理層可能基於「1560倍」的錯誤數據做出錯誤投資決策
   - 可能過度投資在實際影響不大的因素上

2. **信任危機**：
   - 極端數值讓使用者質疑整個分析系統的可靠性
   - 難以向老闆解釋為什麼某個因素有如此巨大影響

3. **溝通困難**：
   - 無法清楚傳達哪些因素真正重要
   - 缺乏統計支持導致說服力不足

## Detailed Solution (詳細解決方案)

### Phase 1: 立即修正（1-2天）

#### 1.1 加入變數標準化
```r
# 檔案：/scripts/global_scripts/04_utils/fn_Poisson_Regression.R

# 修正前
model <- glm(sales ~ ., family = poisson(), data = data)

# 修正後
# 標準化數值變數
numeric_vars <- sapply(data, is.numeric)
data_scaled <- data
data_scaled[, numeric_vars] <- scale(data[, numeric_vars])
model <- glm(sales ~ ., family = poisson(), data = data_scaled)
```

#### 1.2 設定合理上限保護
```r
# 防止極端值
calculate_impact <- function(coef, value = 1) {
  raw_impact <- exp(coef * value)
  # 設定上限為 100 倍
  capped_impact <- pmin(raw_impact, 100)
  return(capped_impact)
}
```

#### 1.3 改進係數解釋
```r
# 新的解釋格式
interpret_coefficient <- function(var_name, coef, se, p_val) {
  list(
    variable = var_name,
    coefficient = round(coef, 4),
    std_error = round(se, 4),
    p_value = round(p_val, 4),
    # 使用標準化後的解釋
    pct_change = round((exp(coef) - 1) * 100, 1),
    interpretation = case_when(
      p_val > 0.05 ~ "統計上不顯著",
      abs(coef) < 0.01 ~ "影響極微弱",
      coef > 0 ~ paste0("每增加1個標準差，銷量增加", 
                        round((exp(coef)-1)*100, 1), "%"),
      TRUE ~ paste0("每增加1個標準差，銷量減少", 
                   round((1-exp(coef))*100, 1), "%")
    ),
    significance = case_when(
      p_val < 0.001 ~ "***",
      p_val < 0.01 ~ "**",
      p_val < 0.05 ~ "*",
      TRUE ~ ""
    )
  )
}
```

### Phase 2: UI 改進（3-5天）

#### 2.1 增強顯示資訊
```r
# 檔案：/scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis.R

# 新的顯示格式
renderTable({
  results %>%
    mutate(
      `變數` = variable_chinese_name,
      `影響程度` = paste0(
        round(pct_change, 1), "%",
        significance
      ),
      `解釋` = interpretation,
      `信賴區間` = paste0(
        "[", round(ci_lower, 1), "%, ",
        round(ci_upper, 1), "%]"
      ),
      `p值` = format.pval(p_value, digits = 3)
    ) %>%
    select(`變數`, `影響程度`, `解釋`, `信賴區間`, `p值`)
})
```

#### 2.2 加入互動式詳細資訊
```r
# 點擊顯示詳細統計資訊
observeEvent(input$table_click, {
  showModal(modalDialog(
    title = "係數詳細解釋",
    h4("統計資訊"),
    tableOutput("detailed_stats"),
    h4("視覺化"),
    plotOutput("coefficient_plot"),
    h4("解釋說明"),
    verbatimTextOutput("interpretation_text"),
    footer = modalButton("關閉")
  ))
})
```

### Phase 3: 長期改進（1-2週）

#### 3.1 建立新的 Meta-Principle
**MP122: Statistical Interpretation Transparency**
- 所有統計結果必須提供完整、可理解的解釋
- 包含原始係數、轉換效果、統計檢定
- 提供視覺化輔助理解

#### 3.2 開發專門的解釋工具
```r
# 新建：/scripts/global_scripts/04_utils/fn_coefficient_interpreter.R

coefficient_interpreter <- function(model, data, language = "zh") {
  # 完整的係數解釋系統
  # 包含多語言支持
  # 自動生成解釋報告
  # 視覺化係數影響
}
```

## Expected Results (預期結果)

### 修正前的顯示
```
track_width: 1560倍 ⚠️ [無法理解的極端數值]
price: 影響不明 [缺少資訊]
brand: 16.9倍 [缺少統計支持]
```

### 修正後的顯示
```
軌道寬度 (track_width)
├─ 影響程度：+42%*** (高度顯著)
├─ 解釋：每增加1個標準差(約5cm)，銷量預期增加42%
├─ 信賴區間：[28%, 58%]
├─ p值：< 0.001
└─ [點擊查看詳細統計圖表]

價格 (price)
├─ 影響程度：-15%** (顯著)
├─ 解釋：每增加1個標準差(約$10)，銷量預期減少15%
├─ 信賴區間：[-22%, -7%]
├─ p值：0.003
└─ [點擊查看詳細統計圖表]

品牌 (brand_A vs others)
├─ 影響程度：+23%* (顯著)
├─ 解釋：品牌A相對於其他品牌，銷量高出23%
├─ 信賴區間：[5%, 44%]
├─ p值：0.024
└─ [點擊查看詳細統計圖表]
```

## Implementation Files (需要修改的檔案)

1. **核心計算邏輯**
   - `/scripts/global_scripts/04_utils/fn_Poisson_Regression.R`
   - 加入標準化、修正極端值

2. **UI 元件** (已部分修正 2025-09-09)
   - `/scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`
   - ✅ 已修正 track_multiplier 計算 (line 295)
   - ⏳ 待增強顯示、加入互動

3. **新建工具函數**
   - `/scripts/global_scripts/04_utils/fn_interpret_coefficient.R`
   - 統一的係數解釋邏輯

4. **配置檔案**
   - `/scripts/global_scripts/30_global_data/parameters/statistical_thresholds.yaml`
   - 定義顯著性標準、上限值等

## Success Criteria (成功標準)

1. ✅ 消除不合理的極端倍數（如 1560倍）
2. ✅ 所有係數都有清晰的中文解釋
3. ✅ 提供完整的統計檢定資訊（p值、信賴區間）
4. ✅ 可點擊查看詳細資訊
5. ✅ 建立一致的顯著性判斷標準
6. ✅ 使用者能理解並信任分析結果

## Proposed Resolution
1. 立即修正 Poisson 迴歸計算邏輯（加入標準化）
2. 設定合理的影響倍數上限（最多 100倍）
3. 增強 UI 顯示完整統計資訊
4. 建立統一的係數解釋框架
5. 新增互動式詳細資訊視窗

## Priority
High - 核心分析功能錯誤，直接影響決策品質

## Related Issues
- ISSUE_123（變數品質問題）
- ISSUE_154（顯著性一致性）

## Change Log
- **2025-09-09**: 修正 track_multiplier 計算，從固定 4 次方改為使用實際範圍
  - 檔案：`poissonFeatureAnalysis.R` line 295
  - 修正文檔：`InsightForge_Calculation_Methods.md`
- **2025-09-22**: 移至 IN_PROGRESS - 當前解決方案為暫時性，需要呈現真實的數字倍數關係