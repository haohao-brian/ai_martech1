# legacy_setup_scripts/

Pre-2026 onboarding / update / env helper scripts with zero live source-code callers across all 5 公司 (QEF_DESIGN / D_RACING / MAMBA / WISER / kitchenMAMA) + `shared/update_scripts/`.

Archived in #580 (2026-05-06) + #585 (2026-05-06, sister cleanup).

## Files

- `02_setup/setup_posit_connect.R`, `02_setup/prepare_for_posit_connect.R`, `02_setup/setup_local_data.R` — pre-deploy bootstrap helpers, replaced by per-co `deployment/<co>-enterprise/` git repo + `make deploy-init` Makefile target
- `04_update/update_app.R`, `04_update/update_to_latest.R` — legacy R-based update scripts, replaced by `make deploy-sync` + `make deploy-push`
- `04_update/update_app.sh` — generic Bash helper for updating `app.R`; zero real consumers (only referenced by archived sibling scripts + vendored deploy snapshot). Archived in #585 as sister cleanup to #580.
- `06_env/prepare_env_for_posit_connect.R`, `06_env/quick_update_env.R` — env-var helpers; new flow uses Posit Connect Variable Sets directly

## Do not source

For audit reference only. The canonical onboarding flow is now `MAMBA/Makefile` (`deploy-init` / `deploy-sync` / `deploy-push` targets).
