---
issue: "ISSUE_030"A"
title: "清理 Poisson 分析表格中的冗餘商業意義文字"
severity: "low"
component: "ui_ux"
app: "mamba"
created: "2025-11-02"
status: "superseded"
resolution: "upgraded_to_244A_UPGRADE"
upgraded_date: "2025-11-02"
parent_issue: "ISSUE_030"
original_source: "20251021/曼巴問題_20251021.md#20"
priority: "low"
estimated_effort: "0.5-1 day"
---

## ⚠️ ISSUE SUPERSEDED

此 issue 經用戶提供實際截圖後發現嚴重性遠超預期。

**問題升級**：
- 原本認為是 UI 美觀問題（LOW priority）
- 實際是嚴重的邏輯錯誤（HIGH priority）
- 高度顯著且大效應的變數被錯誤標記為「影響很小」

**新 Issue**: `ACTIVE/working/ISSUE_244A_UPGRADE_to_HIGH.md`

---

## Problem

在 Poisson 迴歸分析結果表格中，「商業意義」欄位顯示重複的文字「影響很小，不是關鍵因素」，造成表格視覺上的冗餘。

**視覺證據**:
- 圖片路徑：`/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/docs/suggestion/MAMBA/20251021/media/media/image24.png`
- 問題：AI 生成的解讀文字在不重要的變數上重複出現

## Expected Behavior

表格的「商業意義」欄位應該：
1. **選項 1**: 完全移除此欄位（如果資訊價值低）
2. **選項 2**: 只顯示重要變數的商業意義，不重要的留空
3. **選項 3**: 使用更簡潔的標記方式（如圖標或分類）

## Actual Behavior

當前狀態：
- 「商業意義」欄位對所有變數都顯示 AI 生成的解讀
- 對於不顯著或影響小的變數，重複出現相同文字
- 造成表格視覺雜亂，降低可讀性

## Proposed Resolution

### 短期方案（推薦）
```r
# 在 Poisson 分析顯示模組中添加過濾邏輯
# 文件位置：scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/

# 只顯示重要變數的商業意義
if (significance_level <= 0.05 && abs(coefficient) > threshold) {
  business_meaning <- generate_business_interpretation(variable)
} else {
  business_meaning <- ""  # 或 "---" 或 NA
}
```

### 長期方案
重新設計商業意義呈現方式：
- 使用顏色編碼：綠色（正向關鍵）、紅色（負向關鍵）、灰色（不重要）
- 使用圖標系統：⭐ 關鍵因素、📊 次要因素、➖ 影響小
- 添加交互式 tooltip，滑鼠懸停時顯示詳細解讀

## Technical Context

**受影響組件**:
```
scripts/global_scripts/10_rshinyapp_components/poisson/
├── poissonFeatureAnalysis/
│   ├── poissonFeatureAnalysisUI.R
│   └── poissonFeatureAnalysisServer.R
└── [相關的結果顯示函數]
```

**相關原則**:
- UI/UX 最佳實踐：減少視覺雜訊
- MP099: Real-Time Progress Reporting（顯示有意義的資訊）

## Priority Justification

**優先級**: LOW
- **業務影響**: 低 - 美觀問題，不影響功能
- **用戶影響**: 中 - 改善使用體驗但不阻塞工作流程
- **技術複雜度**: 低 - 簡單的顯示邏輯調整
- **時機**: 可在 UI 優化階段批次處理

## Implementation Plan

1. **研究階段** (0.5 day)
   - 檢視當前 Poisson 分析顯示代碼
   - 確認「商業意義」文字的生成邏輯
   - 與 Product Owner 確認偏好方案

2. **實施階段** (0.5 day)
   - 實施選定的解決方案
   - 更新相關顯示邏輯
   - 測試不同場景下的顯示效果

3. **測試階段**
   - 驗證顯著變數正確顯示
   - 驗證非顯著變數正確處理
   - 用戶驗收測試

## Related Issues

- Parent: ISSUE_244 (已分解)
- Blocked by: None
- Blocks: None

## Notes

- 此 issue 從 ISSUE_244 分解而來
- 屬於 UI/UX 優化類別，非功能性缺陷
- 建議在 Milestone 3 (3DRV 層) 完成後處理
- 可與其他 UI 優化工作批次進行

## Acceptance Criteria

✅ 表格視覺更清晰，無冗餘文字
✅ 重要變數的商業意義仍能正確顯示
✅ 不影響現有分析功能
✅ 用戶反饋正面

---
**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Status**: Open (Backlog)
