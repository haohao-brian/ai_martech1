# 2026-01-25 Supabase Deployment Driver

## Summary
Added a deployment driver script to make the Supabase upload → deployment prep flow explicit and repeatable.

## Rationale
Deployments now depend on a data upload step (DuckDB → Supabase). A dedicated driver clarifies order, reduces missed steps, and keeps deployment preparation consistent.

## Changes
- New driver script: `scripts/global_scripts/23_deployment/03_deploy/deploy_app_driver.R`
  - Step 1: Upload app_data to Supabase (via existing upload script)
  - Step 2: Update manifest.json via `sc_deployment_config.R` (non-interactive)
  - Step 3: Print git commit/push instructions
- New rule (ZH): `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/rules/TD_R006_deployment_driver_orchestration.qmd`
- New rule (EN): `scripts/global_scripts/00_principles/docs/en/part1_principles/CH05_testing_deployment/rules/TD_R006_deployment_driver_orchestration.qmd`

## Documentation Alignment
- Added missing ZH CH05 principles/rules for completeness:
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/principles/TD_P001_deployment_patterns.qmd`
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/principles/TD_P002_dual_testing_approach.qmd`
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/principles/TD_P003_component_testing.qmd`
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/rules/TD_R001_shiny_test_data.qmd`
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/rules/TD_R002_test_app_building.qmd`
  - `scripts/global_scripts/00_principles/docs/zh/part1_principles/CH05_testing_deployment/rules/TD_R005_docker_deployment_standard.qmd`
- Updated Quarto indices to include TD_R006 and full CH05 ZH coverage:
  - `scripts/global_scripts/00_principles/_quarto-en.yml`
  - `scripts/global_scripts/00_principles/_quarto-zh.yml`
- Updated LLM index for TD_R006:
  - `scripts/global_scripts/00_principles/llm/CH05_testing.yaml`
  - `scripts/global_scripts/00_principles/llm/index.yaml`

## Principles Alignment
- **MP064 ETL-Derivation Separation**: Data sync happens before app deployment; responsibilities stay separated.
- **DM_R056 Posit Connect Deployment Assets**: Driver ensures deployment assets (manifest) are updated after data sync.
- **SO_R007 One Function One File**: New driver is a dedicated, single-purpose script.

## Naming Note
The driver is intentionally named **deploy_app_driver.R** (not `drv_...`) to avoid conflict with the DRV derivation layer conventions (MP140/DM_R042). This keeps “DRV” reserved for derivation scripts only.
