---
issue: "ISSUE_073"
title: "精準行銷模型無法查看個別品項"
severity: "medium"
component: "precision_marketing_model"
app: "mamba"
created: "2025-09-08"
status: "closed"
closed_date: "2025-11-02"
closed_reason: "merged"
merged_into: "ISSUE_109"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
精準行銷模型沒辦法看個別品項，需要像KM一樣，可以挑KM特定ASIN看影響因素，來布置網頁行銷重點。

## Expected Behavior
- 支援個別品項（ASIN）篩選
- 顯示特定品項的影響因素
- 協助網頁行銷重點布置
- 類似KM系統的功能

## Actual Behavior
- 無法篩選個別品項
- 缺乏品項層級的分析
- 無法針對特定產品制定行銷策略

## Proposed Resolution
1. 實作ASIN篩選器
2. 建立品項層級的影響因素分析
3. 整合到網頁行銷重點建議
4. 參考KM系統的實作方式

## Priority
Medium - 重要功能缺失

## Related Issues
- ISSUE_109 (this issue merged into ISSUE_109)

## Closure Notes
This issue has been identified as a duplicate of ISSUE_109. Both issues describe the same feature request: the ability to filter and view individual products (ASIN) in the precision marketing model, similar to the functionality available in the KM system. The consolidation into ISSUE_109 allows for unified tracking and implementation of this feature enhancement.