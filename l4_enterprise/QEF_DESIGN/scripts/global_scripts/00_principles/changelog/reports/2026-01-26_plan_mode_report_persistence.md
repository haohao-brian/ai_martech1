---
type: implementation_report
created_at: 2026-01-26
status: completed
principles: [MP030, SO_P018, IC_P001]
---

# Plan Mode 報告持久化系統實施報告

## 問題摘要

Plan mode 產出的規劃文件存在以下問題：
1. **暫時性**：存在 `~/.claude/plans/` 隱藏目錄，下次會被覆蓋
2. **不可見**：不在專案目錄內，無法 git 追蹤
3. **知識流失**：設計決策的「為什麼」隨著 plan 檔消失而遺失

## 解決方案

### 1. PostToolUse Hook 自動存檔

建立 `.claude/hooks/archive-plan.sh`，在 ExitPlanMode 時自動觸發：
- 從 `~/.claude/plans/` 找到最新的 plan 文件
- 複製到 `changelog/reports/` 並重新命名
- 加入 YAML metadata header

### 2. 目錄結構簡化

廢除 `plans/` 目錄，統一納入 `reports/`：

| 之前 | 之後 |
|------|------|
| `plans/` | (已刪除) |
| `reports/` | 所有報告和規劃文件 |

### 3. 命名規則

| 命名模式 | 類型 |
|----------|------|
| `YYYY-MM-DD_PLAN_*.md` | Plan Mode 自動存檔 |
| `YYYY-MM-DD_*.md` | 實施報告 |
| `ADR-NNN_*.md` | 架構決策記錄 |

## 實施結果

| 檔案 | 修改類型 | 狀態 |
|------|----------|------|
| `.claude/settings.json` | 新增 | ✅ 完成 |
| `.claude/hooks/archive-plan.sh` | 新增 | ✅ 完成 |
| `changelog/README.md` | 修改 | ✅ 完成 |
| `changelog/plans/` | 刪除 | ✅ 完成 |
| `.claude/rules/05-documentation.md` | 修改 | ✅ 完成 |
| `reports/2025-01-19_PLAN_monorepo_conversion.md` | 遷移 | ✅ 完成 |

## 驗證結果

- [x] PostToolUse hook 配置正確
- [x] archive-plan.sh 腳本可執行
- [x] plans/ 目錄已移除
- [x] 現有 plan 文件已遷移到 reports/
- [x] 文檔規則已更新

## 使用方式

### 自動觸發（預設）

每次 `ExitPlanMode` 執行後，hook 自動存檔到：
```
changelog/reports/YYYY-MM-DD_PLAN_{topic}.md
```

### 排除存檔

在 plan 最上方加：
```markdown
<!-- NO_ARCHIVE -->
```

## 相關原則

- **MP030**: Archive Immutability - 報告一旦存檔不應修改
- **SO_P018**: Directory Governance - 使用現有 `reports/` 目錄
- **IC_P001**: Universal Immediate Sync - 報告應納入版本控制
