---
issue: "ISSUE_082"
title: "網頁停留時間延長到1小時"
severity: "medium"
component: "ui_ux"
app: "mamba"
created: "2025-09-08"
status: "rejected"
closed_date: "2025-11-02"
closed_reason: "platform_limitation"
rejection_category: "platform_limitation"
original_source: "曼巴儀表板問題_20250807"
---

## REJECTION NOTICE

**Status**: REJECTED
**Date**: 2025-11-02
**Reason**: Platform Limitation

**Explanation**:
Session timeout 設定由 Posit Connect Cloud 平台統一控制，無法在應用程式層級進行調整。這是基礎設施層的限制，不是應用程式可以解決的問題。

**Platform Details**:
- **Platform**: Posit Connect Cloud
- **Limitation**: Session timeout 由平台統一管理
- **Scope**: Infrastructure-level, not application-level

**Recommended Action**:
如需調整 session timeout，請聯繫 Posit Connect Cloud 管理員或考慮：
1. 企業版 Posit Connect 自行部署（可自訂設定）
2. 調整用戶使用習慣（定期儲存工作）
3. 實作前端自動儲存機制（在現有 timeout 限制內）

---

## Original Problem Description

曼巴網頁停留時間需要拉長到1小時。

## Expected Behavior
- Session timeout設為1小時
- 自動保存進度
- 超時前提醒

## Actual Behavior
- 目前超時時間過短
- 用戶需要重新登入

## Proposed Resolution (Not Feasible)
1. ~~調整session timeout到60分鐘~~ (平台限制)
2. 實作自動保存機制 (可行，但不影響 session timeout)
3. 加入超時預警 (可行，但不影響 session timeout)
4. 提供延長選項 (平台限制)

## Priority
~~Medium - 用戶體驗~~ → REJECTED (Platform Limitation)

## Related Issues
None