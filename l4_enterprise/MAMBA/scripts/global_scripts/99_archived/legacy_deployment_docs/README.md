# legacy_deployment_docs/

Pre-2026 deployment docs + shinyapps.io / setup-env scripts. Replaced by GitHub-flow + Posit Connect Cloud per `MAMBA/Makefile` + `23_deployment/05_docs/POSIT_CONNECT_CLOUD_GITHUB_DEPLOYMENT.md`.

Archived in #580 (2026-05-06).

## Files

- `WF001_deployment_quickstart.md` / `WF002_deployment_complete.md` — legacy workflow guides referencing `sc_deployment.R` and `setup_deployment_env.R`
- `DEPLOYMENT_GUIDE.md` — `l1_basic/positioning_app` + `DEPLOY_TARGET=shinyapps` legacy
- `update_env_for_shinyapps.R` — shinyapps.io is no longer a target
- `check_deployment.R` — legacy pre-deploy check tied to `sc_deployment*.R`
- `setup_deployment_env.R` — legacy env-var setup for direct `rsconnect::deployApp()`

## Do not source / link

For audit reference only. Canonical doc is `23_deployment/05_docs/POSIT_CONNECT_CLOUD_GITHUB_DEPLOYMENT.md`.
