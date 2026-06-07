---
issue: "ISSUE_079"
title: "Excel下載功能限制"
severity: "medium"
component: "ui_ux"
app: "mamba"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
下載EXCEL選項僅能下載第一頁，沒辦法下載整個係數值檔案，或僅下載整個正的邊際效益檔案。

## Expected Behavior
- 可下載完整數據
- 選擇性下載（如只下載正值）
- 批量下載功能

## Actual Behavior
- 只能下載第一頁
- 無法選擇下載內容
- 數據不完整

## Proposed Resolution
1. 實作完整數據下載
2. 增加篩選下載選項
3. 支援批量導出
4. 優化下載格式

## Priority
Medium - 功能限制

## Related Issues
None