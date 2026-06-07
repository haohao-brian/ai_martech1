# CHANGELOG

本目錄用於保存**本地報告與決策文件**。  
Issue 追蹤已全面改為 **GitHub Issues**（source of truth）。

## Policy (2026-02)

- Issue 狀態、優先級、討論、關閉流程：**GitHub Issues**
- Issue 範圍分類：
  - 公司：`company:<COMPANY_CODE>`（例如 `company:MAMBA`）
  - 模組：`module:<ModuleName>`（例如 `module:BrandEdge`）
- Project 管理：GitHub Project 是容器，不等於公司；每個 scope（`company:*` 或 `module:*`）可有對應看板，issue 需連到對應 scope 看板
- 停用分類前綴：`project:*`、`app:*`、`Company:*`
- `changelog/issues/`：**legacy 歷史資料，只讀，不新增**
- 本地僅新增：
  - `changelog/reports/`：實作報告、調查摘要、ADR、Plan 存檔
  - `changelog/archive/`：歷史/過時文件

## 建議檔名

- Plan 存檔：`YYYY-MM-DD_PLAN_<topic>.md`
- 一般報告：`YYYY-MM-DD_<topic>.md`
- 對應 GitHub issue 的報告：`YYYY-MM-DD_issue-<number>_<topic>.md`

## 最小流程

1. 在 GitHub 建立/更新 Issue（例如 `#148`）
2. 完成實作後，於 `reports/` 寫本地執行報告
3. 在報告中附上 Issue URL 與 commit/PR 連結

## 目錄說明

```
changelog/
├── issues/    # Legacy only (historical, no new tracking files)
├── reports/   # Active local reports and ADRs
└── archive/   # Historical or deprecated artifacts
```
