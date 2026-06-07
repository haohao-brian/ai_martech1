# legacy_rsconnect_deployapp/

Pre-2026 direct-deploy R scripts. Replaced by Makefile GitHub-push flow per `MAMBA/Makefile` + `23_deployment/05_docs/POSIT_CONNECT_CLOUD_GITHUB_DEPLOYMENT.md`.

Archived in #580 (2026-05-06) per user decision: 「我是不喜歡 fallback 的，用 B，只是幫我把舊檔案都放到 archived 裡面」.

## Files

- `sc_deployment*.R` — direct `rsconnect::deployApp()` callers (5 variants)
- `03_deploy_deploy*.R` — positioning_app legacy deploy entry points (4 variants)
- `01_checks_check_*.R` — positioning_app legacy pre-deploy checks (2 variants)

## Do not source

These files are kept for git-history audit reference only. Do not `source()` them. The canonical deployment path is now:

1. Each company has its own `deployment/<co>-enterprise/` dedicated git repo
2. Local dev → `make deploy-sync` (rsync source into deploy repo)
3. `make deploy-push` (commit + push deploy repo to GitHub)
4. Posit Connect Cloud git integration auto-rebuilds from the deploy repo

See `MAMBA/Makefile` for the production reference implementation.
