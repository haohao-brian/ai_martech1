---
issue: "ISSUE_080"
title: "關鍵字廣告與新產品開發AI建議"
severity: "medium"
component: "ai_report_generation"
app: "mamba"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
關鍵字廣告與新產品開發功能缺少AI生成的新產品開發建議。

## Expected Behavior
- 系統應能夠根據邊際效用正值變數生成新產品開發建議
- 建議應按係數大小排序
- 提供具體可行的產品開發方向

## Actual Behavior
- 缺少新產品開發建議功能
- 無法基於數據提供產品開發指引

## Proposed Resolution
1. 實作新產品開發建議AI功能
2. 使用以下prompt模板：
   ```
   請詳實列出所有邊際效用正值的變數，
   並依據係數大小排序，
   依序提出新產品開發的建議。
   ```
3. 整合到關鍵字廣告與新產品開發模組
4. 確保建議的實用性和可操作性

## Priority
Medium - 增值功能，提升產品價值

## Related Issues
- ISSUE_119, ISSUE_135