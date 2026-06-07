---
issue: "ISSUE_077"
title: "不適當變數納入分析且變數名稱不完整"
severity: "high"
component: "precision_marketing_model"
app: "mamba"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
1. 精準行銷子模組的屬性未納入口碑變數
2. url、Is_missing、Manufacturer、wastegate_type、fuel_type、trubin_a_rate_NA等不適當變數顯著
3. 英文變數名稱不完整
4. 應該刪除不適當變數，先留下邊際效用正值的變數

## Expected Behavior
- 納入口碑變數
- 排除無意義的變數（Is_missing、NA結尾變數）
- 完整的變數名稱
- 只保留邊際效用正值的有意義變數

## Actual Behavior
- 缺少口碑變數
- 包含許多不適當的變數
- 變數名稱被截斷
- 負邊際效用變數仍在分析中

## Proposed Resolution
1. 加入口碑相關變數
2. 建立變數篩選規則：
   - 排除Is_missing類變數
   - 排除_NA結尾的變數
   - 排除url等元數據變數
3. 修正變數名稱顯示長度限制
4. 實作邊際效用篩選機制

## Priority
High - 影響分析準確性

## Related Issues
- ISSUE_108, ISSUE_154