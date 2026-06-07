# 23_deployment/ — Deployment toolkit

部署相關共享資源。**Canonical 部署流程是 GitHub-flow 配 Posit Connect Cloud git integration**。直接呼叫 `rsconnect::deployApp()` 的舊腳本已於 #580 (2026-05-06) 全部歸檔。

## Canonical references (請以這幾個為準)

| 來源 | 用途 |
|------|------|
| `MAMBA/Makefile` | Production reference 實作。`deploy-init` / `deploy-sync` / `deploy-push` targets |
| `05_docs/POSIT_CONNECT_CLOUD_GITHUB_DEPLOYMENT.md` | Posit Connect Cloud git 整合部署指南 |
| `05_docs/COMPLETE_DEPLOYMENT_GUIDE.md` | 完整部署流程說明 |
| `05_docs/POSIT_CONNECT_DEPLOYMENT.md` | 部署原則與快速開始 |
| `05_docs/POSIT_CONNECT_ENV_VARIABLES.md` | 環境變數設定指南 |
| `05_docs/NEW_COMPANY_DEPLOYMENT.md` | 新公司 onboarding 部署流程 |

## 流程概述

```
local dev (l4_enterprise/<COMPANY>/)
    │
    │ make deploy-sync       # rsync 應用 + global_scripts 進獨立的 deploy repo
    ▼
deployment/<co>-enterprise/  # 獨立 git repo
    │
    │ make deploy-push       # commit + push to GitHub
    ▼
github.com/.../<co>-enterprise
    │
    │ Posit Connect Cloud git integration
    ▼ (auto-rebuild on push)
share.connect.posit.cloud
```

### deploy-sync rsync policy (#581)

`deploy-sync` 必須用 `rsync -avL --delete` 才能讓 source-side 的 archive moves 自動 propagate 到 vendored snapshot。`--delete` flag 會移除 destination 內 source 已不存在的檔案,避免 orphan legacy scripts 殘留在 deploy bundle。

MAMBA `Makefile` 已是 canonical reference 實作(line 49)。新公司 bootstrap 自己的 deploy-sync 時應沿用同一 pattern:

```makefile
@rsync -avL --delete \
    --exclude='.DS_Store' \
    --exclude='*.duckdb' \
    --exclude='*.wal' \
    --exclude='.git' \
    --exclude='.gitrepo' \
    --exclude='__pycache__' \
    --exclude='.Rproj.user' \
    scripts/global_scripts/ $(DEPLOY_DIR)/scripts/global_scripts/
```

## 目錄結構

```
23_deployment/
├── README.md                       (本檔)
├── app_config_template.yaml        (公司 app_config.yaml 起家樣板)
├── 03_deploy/
│   └── upload_app_data_to_supabase.R   (Supabase data sync utility)
├── 05_docs/                        (canonical 部署指南,5 篇)
└── .claude/                        (per-skill metadata)
```

## Removed in #580 / #585 (2026-05-06)

以下檔案因 legacy framing 移到 `99_archived/`,不再使用:

| 歸檔位置 | 內容 |
|---------|------|
| `99_archived/legacy_rsconnect_deployapp/` | 14 個 `rsconnect::deployApp()` 直接呼叫腳本 + positioning_app legacy templates (#580) |
| `99_archived/legacy_deployment_docs/` | 8 個 shinyapps.io / legacy workflow docs (#580) |
| `99_archived/legacy_setup_scripts/` | 8 個 zero-consumer setup/update/env helpers (7 from #580 + `update_app.sh` from #585) |

User decision (2026-05-06): 「我是不喜歡 fallback 的，用 B，只是幫我把舊檔案都放到 archived 裡面」 — single canonical deployment path = MAMBA Makefile GitHub-flow, no `rsconnect::deployApp` fallback.

## 新公司 onboarding

依 `05_docs/NEW_COMPANY_DEPLOYMENT.md`。簡述:

1. `cp app_config_template.yaml <COMPANY>/app_config.yaml`,編輯 `app_name` / `github_repo` / `app_path`
2. 建立 `deployment/<co>-enterprise/` 獨立 git repo
3. 設定 Posit Connect Cloud git integration 指向該 repo
4. `make deploy-init` (一次性) → `make deploy-sync` → `make deploy-push`

## Principles

- **MP064**: ETL-Derivation Separation
- **MP122**: Penta-Track Subrepo Architecture
- **DM_R063**: Deploy Bundle Purity (deploy bundle 不含 local DB 檔)
- **IC_P002**: Cross-Company Verification (修改本目錄需 5 公司驗證)

## Related issues

- #580 — legacy framing cleanup (this directory's last reorganization)
- #585 — `update_app.sh` consumer audit + archive (sister cleanup)
- #581 — MAMBA vendored snapshot rebuild policy (verified: --delete handles it)
- #584 — `/new-company` skill template audit (post-#580 alignment)
