---
issue: "ISSUE_083"
title: "BrandEdge策略分析需確認"
severity: "high"
component: "brand_positioning"
app: "brandedge"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
1. 關鍵因素分析仍有26個變數而非8個理想點
2. 改善和劣勢沒有內容
3. 理想點計算可能有誤（4:6加權）

## Expected Behavior
- 8個理想點（基於評分和銷售4:6加權）
- 改善：理想點但品牌表現低
- 劣勢：非理想點且品牌表現低
- 清晰的策略分析

## Actual Behavior
- 26個變數全部顯示
- 改善和劣勢欄位空白
- 理想點計算邏輯不明

## Proposed Resolution
1. 重新實作理想點算法（4:6加權）
2. 修正改善/劣勢的判斷邏輯
3. 限制顯示為8個關鍵因素
4. 建立完整的測試案例

## Priority
High - 核心算法問題

## Related Issues
- ISSUE_105, ISSUE_106, ISSUE_116