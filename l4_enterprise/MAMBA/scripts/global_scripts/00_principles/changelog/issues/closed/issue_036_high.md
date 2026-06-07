---
issue: "ISSUE_036"A_UPGRADE"
title: "【升級為 HIGH】修復商業意義判斷邏輯 - 忽略統計顯著性和效應大小"
severity: "high"
component: "data_analysis"
app: "mamba"
created: "2025-11-02"
status: "open"
parent_issue: "ISSUE_036"A"
priority: "high"
estimated_effort: "1 day"
labels: ["bug", "data-quality", "user-facing"]
---

## 🔴 問題升級說明

原本 ISSUE_244A 被歸類為 LOW 優先級的 UI 美觀問題，但經用戶反饋實際圖片後發現，這是一個**嚴重的邏輯錯誤**，會導致用戶對分析結果產生誤解。

## Problem - 問題嚴重性升級

### 當前錯誤行為

**極度顯著且影響巨大的變數被錯誤標記為「影響很小，不是關鍵因素」**

| 變數 | 係數 | P值 | 顯著性 | 過際效應% | 商業意義（錯誤）| 應該顯示 |
|------|------|-----|--------|----------|---------------|---------|
| 配送快速 | -4.7003 | 0.0009 | *** | **-90%** | ❌ 影響很小 | ✅ 極重要負面因素 |
| 完美匹配 | -2.0193 | 0 | *** | -86.7% | ❌ 影響很小 | ✅ 極重要負面因素 |
| special_price | -1.7693 | 0 | *** | -83% | ❌ 影響很小 | ✅ 重要負面因素 |

### 業務影響

**CRITICAL** - 這不是美觀問題，而是：
1. **誤導決策**：用戶可能忽略實際上最重要的影響因素
2. **數據可信度**：降低用戶對整個分析系統的信任
3. **戰略錯誤**：可能導致錯誤的行銷策略和資源配置

### 根本原因

**檔案**: `scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`

**Line 340-345**:
```r
practical_meaning = case_when(
  track_multiplier >= 3.0 ~ "極重要因素，核心競爭力",
  track_multiplier >= 2.0 ~ "重要影響因素，應重點關注",
  track_multiplier >= 1.2 ~ "有一定影響，可考慮優化",
  TRUE ~ "影響很小，不是關鍵因素"  # ❌ 問題：完全忽略 P 值和效應大小！
)
```

**問題**：
1. ❌ 完全沒有檢查統計顯著性（P值）
2. ❌ 沒有考慮絕對效應大小（marginal_effect_pct）
3. ❌ track_multiplier 的計算可能不適用於所有變數類型

## Expected Behavior - 正確邏輯

商業意義判斷應該**同時考慮三個維度**：

### 1. 統計顯著性（P值）
- P < 0.001 (***): 高度顯著
- P < 0.01 (**): 顯著
- P < 0.05 (*): 邊緣顯著
- P >= 0.05: 不顯著

### 2. 效應大小（絕對值）
- |marginal_effect_pct| >= 50%: 極大影響
- |marginal_effect_pct| >= 20%: 重要影響
- |marginal_effect_pct| >= 5%: 中等影響
- |marginal_effect_pct| < 5%: 小影響

### 3. 效應方向
- 正向: 提升銷量/流量
- 負向: 降低銷量/流量

## Proposed Resolution - 修復方案

### 方案 A：快速修復（推薦，1天內完成）

```r
practical_meaning = case_when(
  # 優先檢查統計顯著性
  p_value >= 0.05 ~ "影響不顯著，暫不關注",

  # 高度顯著 (P < 0.001) - 根據效應大小判斷
  p_value < 0.001 & abs(marginal_effect_pct) >= 50 ~
    paste0(ifelse(coefficient > 0, "極重要正向因素", "極重要負面因素"), "，核心競爭力"),
  p_value < 0.001 & abs(marginal_effect_pct) >= 20 ~
    paste0(ifelse(coefficient > 0, "重要正向因素", "重要負面因素"), "，應重點關注"),
  p_value < 0.001 & abs(marginal_effect_pct) >= 5 ~
    paste0(ifelse(coefficient > 0, "有正向影響", "有負向影響"), "，可考慮優化"),

  # 顯著 (P < 0.01) - 根據效應大小判斷
  p_value < 0.01 & abs(marginal_effect_pct) >= 30 ~
    paste0(ifelse(coefficient > 0, "重要正向因素", "重要負面因素"), "，應重點關注"),
  p_value < 0.01 & abs(marginal_effect_pct) >= 10 ~
    paste0(ifelse(coefficient > 0, "有正向影響", "有負向影響"), "，可考慮優化"),

  # 邊緣顯著 (P < 0.05) - 謹慎解讀
  p_value < 0.05 & abs(marginal_effect_pct) >= 20 ~
    paste0(ifelse(coefficient > 0, "可能有正向影響", "可能有負向影響"), "，建議進一步驗證"),

  # 默認情況
  TRUE ~ "影響較小或不確定"
)
```

### 方案 B：增強版（2-3天完成）

結合 P 值、marginal_effect_pct 和 track_multiplier 三個維度的綜合評分系統：

```r
# Step 1: 計算綜合重要性分數
importance_score = case_when(
  p_value >= 0.05 ~ 0,  # 不顯著直接給 0 分
  p_value < 0.001 ~ 3,  # 高度顯著
  p_value < 0.01 ~ 2,   # 顯著
  p_value < 0.05 ~ 1    # 邊緣顯著
) + case_when(
  abs(marginal_effect_pct) >= 50 ~ 3,  # 極大效應
  abs(marginal_effect_pct) >= 20 ~ 2,  # 大效應
  abs(marginal_effect_pct) >= 5 ~ 1,   # 中等效應
  TRUE ~ 0                              # 小效應
)

# Step 2: 根據綜合分數和方向生成商業意義
practical_meaning = case_when(
  importance_score == 0 ~ "影響不顯著或很小",
  importance_score >= 5 ~ paste0(
    ifelse(coefficient > 0, "⭐ 極重要正向因素", "⚠️ 極重要負面因素"),
    " (效應: ", round(marginal_effect_pct, 1), "%)"
  ),
  importance_score >= 4 ~ paste0(
    ifelse(coefficient > 0, "✓ 重要正向因素", "✗ 重要負面因素"),
    " (效應: ", round(marginal_effect_pct, 1), "%)"
  ),
  importance_score >= 2 ~ paste0(
    ifelse(coefficient > 0, "有正向影響", "有負向影響"),
    " (效應: ", round(marginal_effect_pct, 1), "%)"
  ),
  TRUE ~ "影響較小"
)
```

## Implementation Plan

### Phase 1: 快速修復（推薦）

**Day 1 - Morning (4h)**:
1. ✅ 在 `poissonFeatureAnalysis.R` 實施方案 A
2. ✅ 更新兩個計算分支（line 340-345 和 line 375-380）
3. ✅ 添加詳細註釋說明邏輯

**Day 1 - Afternoon (4h)**:
4. ✅ 創建測試案例
5. ✅ 使用真實數據驗證修復
6. ✅ 部署到開發環境
7. ✅ 請用戶驗證

### Phase 2: 增強版（可選，未來實施）

**Week 2**:
- 實施綜合評分系統（方案 B）
- 添加圖標和顏色編碼
- 實施交互式 tooltip 詳細解讀

## Testing Strategy

### Test Case 1: 高度顯著 + 大效應
```r
test_data <- data.frame(
  coefficient = -4.7003,
  p_value = 0.0009,
  marginal_effect_pct = -90
)
expected_meaning = "極重要負面因素，核心競爭力"
```

### Test Case 2: 顯著 + 中等效應
```r
test_data <- data.frame(
  coefficient = 0.5,
  p_value = 0.03,
  marginal_effect_pct = 15
)
expected_meaning = "有正向影響，可考慮優化"
```

### Test Case 3: 不顯著
```r
test_data <- data.frame(
  coefficient = 0.1,
  p_value = 0.45,
  marginal_effect_pct = 2
)
expected_meaning = "影響不顯著，暫不關注"
```

## Priority Justification

**從 LOW 升級到 HIGH** 的理由：

| 維度 | 評估 | 說明 |
|------|------|------|
| 業務影響 | ⚠️ CRITICAL | 誤導決策，影響戰略 |
| 用戶體驗 | ⚠️ HIGH | 破壞對分析系統的信任 |
| 技術複雜度 | ✅ LOW | 邏輯修改，1天可完成 |
| 修復緊急度 | ⚠️ HIGH | 用戶正在使用，需立即修復 |
| 數據完整性 | ⚠️ CRITICAL | 核心分析邏輯錯誤 |

## Risk Assessment

### LOW Risk: 修復影響其他功能
- **機率**: Low
- **緩解**: 修改限於 practical_meaning 欄位計算

### MEDIUM Risk: 用戶習慣改變
- **機率**: Medium
- **影響**: Low
- **緩解**: 新邏輯更符合統計學標準，用戶應該歡迎

## Acceptance Criteria

✅ 高度顯著（P < 0.001）且大效應（>50%）的變數正確標記為「極重要」
✅ 不顯著（P >= 0.05）的變數正確標記為「不顯著」
✅ 所有邏輯同時考慮 P 值和效應大小
✅ 用戶驗證新邏輯正確
✅ 添加單元測試防止回歸
✅ 更新用戶文檔說明新的商業意義判斷標準

## Related Issues

- Parent: ISSUE_244 (已分解)
- Supersedes: ISSUE_244A (原本的 LOW 優先級 issue)
- Related: 所有使用 Poisson 分析的模組

## Notes

- 此 issue 從 ISSUE_244A 升級而來
- 用戶反饋實際圖片後發現嚴重性遠超預期
- **建議立即處理**，優先級高於 ISSUE_244B
- 修復後應主動通知所有使用此功能的用戶

## Communication to User

```
感謝您提供的詳細截圖！

我們發現這不僅僅是美觀問題，而是一個嚴重的邏輯錯誤：
系統在判斷「商業意義」時完全忽略了統計顯著性和實際效應大小。

您截圖中的例子：
- 「配送快速」: P=0.0009 (***), 效應 -90%
  → 當前錯誤顯示：「影響很小」
  → 應該顯示：「極重要負面因素，核心競爭力」

我們將在 1 個工作日內修復此邏輯錯誤，並部署到您的環境。
修復後，所有高度顯著的變數都會正確顯示其商業重要性。

再次感謝您的細心發現！
```

---
**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Status**: Open (Working) - **URGENT - 優先於 244B 和 244C**
**Target Resolution**: 2025-11-03
