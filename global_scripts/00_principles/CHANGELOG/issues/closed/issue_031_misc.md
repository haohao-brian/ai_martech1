---
issue: "ISSUE_031"B_ENHANCED"
title: "增強賽道倍數計算 - 支援中文虛擬變數和數據驅動範圍偵測"
severity: "medium"
priority: "high"
component: "poisson_analysis"
app: "mamba"
created: "2025-11-02"
status: "open"
depends_on: ["ISSUE_244A_CRITICAL"]
estimated_effort: "2 days"
assigned_to: "principle-coder"
parent_issue: "ISSUE_031"
labels: ["enhancement", "data-quality", "calculation-accuracy"]
---

## Problem Statement

`calculate_attribute_range()` 函數無法正確識別中文虛擬變數和分類變數的 dummy 編碼，導致賽道倍數（track_multiplier）計算不準確。

### Current Issues

1. **模式匹配僅使用英文關鍵字**: 無法識別中文虛擬變數
2. **無法偵測中文 dummy 變數**: 如「配送快速」、「完美匹配」等
3. **預設範圍不當**: 對 0/1 dummy 變數使用 `range=4` 是錯誤的
4. **缺乏數據驅動**: 沒有從實際數據查詢範圍

### User Variable Examples

用戶數據中的變數名稱：
- "配送快速" (Fast Delivery) - 可能是 dummy (0/1)
- "完美匹配" (Perfect Match) - 可能是 dummy (0/1)
- "套件內容_45_度飽腹按摩" - 分類變數的 dummy 編碼
- "客服品質" - 可能是評分變數 (1-5)
- "special_price" - 可能是 dummy (0/1)

**當前問題**: 這些變數都不匹配現有模式，全部使用預設 `range=4`，導致 track_multiplier 計算錯誤。

## Root Cause Analysis

### 當前實作 (Lines 28-56)

**檔案**: `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`

```r
calculate_attribute_range <- function(predictor_name, data_connection = NULL) {
  default_range <- 4  # ← 問題：對 dummy 變數來說太大了

  # 模式匹配（僅英文）
  if (grepl("rating|score|star", predictor_name, ignore.case = TRUE)) {
    return(4)  # 5 - 1 = 4
  } else if (grepl("binary|flag|is_|has_", predictor_name, ignore.case = TRUE)) {
    return(1)  # 1 - 0 = 1  ← 不匹配中文 dummy 變數！
  } else if (grepl("percentage|percent|rate", predictor_name, ignore.case = TRUE)) {
    return(100)
  } else if (grepl("count|quantity|number", predictor_name, ignore.case = TRUE)) {
    return(10)
  } else if (grepl("price|cost|revenue", predictor_name, ignore.case = TRUE)) {
    return(50)
  }

  # 數據連接檢查（未實作）
  # if (we have data connection, try to get actual range)
  # (Future enhancement: query actual data ranges from database)

  return(default_range)  # ← 大多數中文變數走這條路徑
}
```

### Track Multiplier 計算 (Lines 60-90)

```r
calculate_track_multiplier <- function(coefficient, predictor_name, incidence_rate_ratio = NULL) {
  # 獲取屬性範圍
  attr_range <- calculate_attribute_range(predictor_name)  # ← 這裡獲取範圍

  # 方法 1: 使用係數
  if (!is.na(coefficient)) {
    if (abs(coefficient) > 2) {
      track_multiplier <- exp(2) * (1 + (abs(coefficient) - 2) * 0.5)
    } else {
      effective_range <- min(attr_range, 10)
      track_multiplier <- exp(abs(coefficient) * sqrt(effective_range))
      # ← 如果 range 錯誤（4 vs 1），這裡計算就錯了
    }
  }
  # ...
  return(round(min(track_multiplier, 100), 1))
}
```

### 問題示例

假設「配送快速」是 dummy (0/1)：
- **實際範圍**: 1 (1 - 0 = 1)
- **當前範圍**: 4 (預設值)
- **係數**: -4.7003

**錯誤計算**:
```r
effective_range = min(4, 10) = 4
track_multiplier = exp(4.7003 * sqrt(4)) = exp(9.4) = 12,088 → 上限 100
```

**正確計算** (應該是):
```r
effective_range = min(1, 10) = 1
track_multiplier = exp(4.7003 * sqrt(1)) = exp(4.7) = 109.9 → 上限 100
```

但更重要的是，dummy 變數的 track_multiplier 概念本身就不太適用！

## Solution - Enhanced Attribute Range Detection

### 新的 calculate_attribute_range() 實作

```r
calculate_attribute_range <- function(predictor_name, data_connection = NULL) {
  # 優先級 1: 中文 dummy 變數模式偵測
  # 常見的中文 dummy 變數起始詞
  if (grepl("^(配送|完美|包含|是否|有無|使用|提供|含有|具備)", predictor_name)) {
    return(1)  # Likely dummy (0/1)
  }

  # 優先級 2: 底線模式（套件內容_XXX 表示分類變數）
  # 分類變數的 dummy 編碼通常有底線分隔
  if (grepl("_\\d+_|_[^_]+$", predictor_name)) {
    # 如：套件內容_45_度飽腹按摩, product_type_A
    return(1)  # Categorical dummy
  }

  # 優先級 3: 中文評分/分數詞彙
  if (grepl("(評分|分數|星級|等級|品質)", predictor_name)) {
    return(4)  # Likely 5-point scale (1-5)
  }

  # 優先級 4: 中文數量詞彙
  if (grepl("(數量|件數|次數|筆數)", predictor_name)) {
    return(10)  # Count variable
  }

  # 優先級 5: 英文模式（現有）
  if (grepl("rating|score|star", predictor_name, ignore.case = TRUE)) {
    return(4)  # 5-point scale
  } else if (grepl("binary|flag|is_|has_", predictor_name, ignore.case = TRUE)) {
    return(1)  # Binary
  } else if (grepl("percentage|percent|rate", predictor_name, ignore.case = TRUE)) {
    return(100)
  } else if (grepl("count|quantity|number", predictor_name, ignore.case = TRUE)) {
    return(10)
  } else if (grepl("price|cost|revenue", predictor_name, ignore.case = TRUE)) {
    return(50)
  }

  # 優先級 6: 數據驅動範圍偵測（新增）
  if (!is.null(data_connection)) {
    actual_range <- try_get_actual_range(predictor_name, data_connection)
    if (!is.null(actual_range) && !is.na(actual_range)) {
      # 偵測到實際範圍
      message(sprintf("Using actual range for '%s': %.2f", predictor_name, actual_range))
      return(actual_range)
    }
  }

  # 優先級 7: 保守預設（從 4 改為 2）
  # 較小的預設值更保守，避免過度誇大 track_multiplier
  return(2)
}
```

### 新增輔助函數: try_get_actual_range()

```r
# Following MP047: Functional Programming - create reusable helper
# Following R116: Enhanced Data Access - use tbl2() for data inspection
try_get_actual_range <- function(predictor_name, data_connection) {
  tryCatch({
    # 嘗試從數據庫獲取實際範圍
    # 需要知道哪個表包含這個變數

    # 方法 1: 如果有 predictor metadata table
    # range_info <- tbl2(data_connection, "predictor_metadata") %>%
    #   filter(predictor == predictor_name) %>%
    #   collect()
    # if (nrow(range_info) > 0) {
    #   return(range_info$max_value - range_info$min_value)
    # }

    # 方法 2: 直接查詢（需要知道表名）
    # 這部分需要根據實際數據結構實作
    # 暫時返回 NULL

    return(NULL)
  }, error = function(e) {
    # 如果查詢失敗，返回 NULL
    return(NULL)
  })
}
```

### 替代方案: 變數類型查找表

如果數據驅動方法太複雜，可以建立查找表：

```r
# 在腳本開頭定義
KNOWN_VARIABLE_RANGES <- list(
  # 用戶數據中的已知變數
  "配送快速" = 1,
  "完美匹配" = 1,
  "客服品質" = 4,
  "special_price" = 1,
  "評分" = 4,
  "星級" = 4,
  # ... 可以根據實際數據逐步完善
  "default" = 2
)

calculate_attribute_range <- function(predictor_name, data_connection = NULL) {
  # 優先級 0: 查找表（最快最準確）
  if (predictor_name %in% names(KNOWN_VARIABLE_RANGES)) {
    return(KNOWN_VARIABLE_RANGES[[predictor_name]])
  }

  # 然後是其他模式偵測...
}
```

## Implementation Plan

### Phase 2A: 增強模式偵測 (Day 1 Morning, 4h)

1. **實施中文模式偵測**
   - 添加中文 dummy 變數模式
   - 添加中文評分/數量詞彙模式
   - 添加底線分隔模式

2. **調整預設值**
   - 將預設範圍從 4 改為 2（更保守）

3. **添加詳細日誌**
   - 記錄每個變數偵測到的範圍
   - 幫助除錯和驗證

### Phase 2B: 數據驅動偵測 (Day 1 Afternoon, 4h)

1. **設計實際範圍查詢**
   - 分析數據結構
   - 實施 `try_get_actual_range()`

2. **或實施查找表方案**
   - 分析用戶數據中的所有變數
   - 建立 `KNOWN_VARIABLE_RANGES` 查找表

### Phase 2C: 測試和驗證 (Day 2, 8h)

1. **單元測試**
   - 測試所有模式偵測
   - 測試中文變數
   - 測試邊界情況

2. **真實數據驗證**
   - 使用用戶提供的 100+ 變數
   - 驗證範圍偵測準確率 >95%
   - 與用戶確認結果

3. **性能測試**
   - 確保不影響計算性能

## Testing Strategy

### Test Cases

```r
test_that("Chinese dummy variables detected correctly", {
  expect_equal(calculate_attribute_range("配送快速"), 1)
  expect_equal(calculate_attribute_range("完美匹配"), 1)
  expect_equal(calculate_attribute_range("包含折扣"), 1)
})

test_that("Chinese categorical dummies detected", {
  expect_equal(calculate_attribute_range("套件內容_45_度飽腹按摩"), 1)
  expect_equal(calculate_attribute_range("產品類型_A"), 1)
})

test_that("Chinese rating variables detected", {
  expect_equal(calculate_attribute_range("客服品質"), 4)
  expect_equal(calculate_attribute_range("評分"), 4)
  expect_equal(calculate_attribute_range("星級"), 4)
})

test_that("English patterns still work", {
  expect_equal(calculate_attribute_range("customer_rating"), 4)
  expect_equal(calculate_attribute_range("is_premium"), 1)
  expect_equal(calculate_attribute_range("has_discount"), 1)
})

test_that("Default is conservative", {
  expect_equal(calculate_attribute_range("unknown_variable_xyz"), 2)
})
```

### Validation with Real Data

使用用戶截圖中的所有變數：
- [ ] 配送快速 → 範圍 1
- [ ] 完美匹配 → 範圍 1
- [ ] 套件內容_45_度飽腹按摩 → 範圍 1
- [ ] 客服品質 → 範圍 4
- [ ] applicable_vehicle_count_x5 → 範圍 5
- [ ] special_price → 範圍 1

## Files to Modify

1. **poissonFeatureAnalysis.R**
   - Lines 28-56: `calculate_attribute_range()` 函數
   - 新增: `try_get_actual_range()` 輔助函數
   - 新增: `KNOWN_VARIABLE_RANGES` 查找表（可選）

## Acceptance Criteria

### Functional Requirements
- [ ] 中文 dummy 變數正確偵測（範圍=1）
- [ ] 中文分類 dummy 正確偵測（範圍=1）
- [ ] 中文評分變數正確偵測（範圍=4）
- [ ] 英文模式仍正常工作
- [ ] 預設值更保守（2 而非 4）
- [ ] 數據驅動偵測工作（或查找表實施）

### Quality Requirements
- [ ] 使用 100+ 真實變數測試
- [ ] 範圍偵測準確率 >95%
- [ ] 性能無明顯下降
- [ ] 詳細日誌幫助除錯

### User Acceptance
- [ ] 用戶確認賽道倍數現在更準確
- [ ] Track multiplier 值合理
- [ ] 為 Phase 3 整合做好準備

## Dependencies

### Depends On
- None（可以與 ISSUE_244A_CRITICAL 並行）

### Enables
- Phase 3: 整合「統計顯著性 + 賽道倍數」方法

## Timeline

**Target Completion**: 2025-11-04 to 2025-11-05 (2 days)

- **Day 1 Morning (4h)**: 增強模式偵測
- **Day 1 Afternoon (4h)**: 數據驅動偵測或查找表
- **Day 2 (8h)**: 測試、驗證、用戶確認

## Related Issues

- **Parent**: ISSUE_244 (已分解)
- **Related**: ISSUE_244A_CRITICAL (商業意義修復)
- **Enables**: Phase 3 整合工作

## Notes

- 此增強可以與 ISSUE_244A_CRITICAL 並行開發
- 完成後，可以在 Phase 3 實施用戶偏好的「顯著性 + 賽道倍數」方法
- 查找表方案更簡單，但需要持續維護
- 數據驅動方案更智能，但實施更複雜

---
**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Status**: Open (Backlog) - **PHASE 2**
**Estimated Start**: 2025-11-04 (after Phase 1 complete)
