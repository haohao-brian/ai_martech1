# MP165 Dashboard Presence Contracts

Per-company contract YAMLs governing dashboard rendering acceptance.

## Files

| File                  | Role                                                            |
| --------------------- | --------------------------------------------------------------- |
| `contracts.R`         | Primitive helper library (assertion functions + YAML validator) |
| `<company>.yaml`      | Per-company contract declarations                               |
| `_template/contract.yaml` | Starter template for new companies                          |

## How a contract YAML is consumed

1. **Tier 2 deploy gate** (`23_deployment/dashboard_presence_gate.R`) loads
   the YAML for the company being deployed, walks every active platform ×
   active product_line × declared contract, and exits non-zero on any
   `severity: critical` failure.

2. **Tier 1 DRV-end lite** (`update_scripts/DRV/_targets.R`'s
   `dashboard_smoke_lite` target) does NOT load contract YAML — it only
   checks for `[DEBUG_MODE_NULL_OUTPUT]` markers via `fn_debug_mode.R`.
   Severity is a Tier 2 concept.

3. **Tier 3 CI selective** loads only the subset of contracts whose
   modules were affected by the PR diff (`affected_modules.R`).

## Opt-out mechanisms (Hard Fail Discipline, MP165)

- **Natural opt-out**: Company's `update_scripts/DRV/_targets.R` does NOT
  declare the corresponding DRV target. Declarative dependency takes care
  of the rest — contract is not evaluated. Example: KITCHENMAMA does not
  implement BrandEdge so KITCHENMAMA's `_targets.R` has no `df_position`
  producer; the framework walks the DAG, sees no producer, skips
  BrandEdge contracts. **No flag needed.**

- **Explicit documentation flag**: `modules.<name>.enabled: false` makes
  the opt-out visible in the YAML for reviewer clarity. Useful for
  temporary disable during onboarding. The flag is documentation; the
  declarative DAG is authority.

**Forbidden**: global `soft_warn_mode`, `skip_contract`, or
`disable_contract` flags. MP165 has no soft-warn fallback.

## KITCHENMAMA example

KITCHENMAMA does not have a contract YAML at all in this directory.
That is intentional. KITCHENMAMA's pipeline does not produce BrandEdge
data, so no BrandEdge contracts are needed; the other modules
(`tagpilot`, `vitalsigns`, `dashboard_overview`) currently use
defaults appropriate to a small client. If MP165 deploy gate is ever
enabled for KITCHENMAMA in the future, copy `_template/contract.yaml`
to `kitchenmama.yaml` and tune.

## Adding a new company

1. `cp _template/contract.yaml <company_lowercase>.yaml`
2. Replace `TEMPLATE_REPLACE_ME` with the company name.
3. Delete `modules.<name>` blocks for unused modules (or set
   `enabled: false` to document the opt-out).
4. Tune `min_rows` / `min_choices` / KPI thresholds to the company's
   actual data scale.
5. List active product_lines explicitly in `active_product_lines`.
6. Run `Rscript -e 'source("contracts.R"); validate_contract_yaml(yaml::read_yaml("<company>.yaml"))'`
   to confirm schema validation passes.
7. IC_P002 cross-co verify: confirm the new YAML does not break the
   other 4 companies' contract execution.

## Threshold tuning principles

- **Critical floors**: should fail when data is genuinely missing
  (KPI = 0, table empty after placeholder exclusion). Should NOT fail
  on legitimate small data sets unless that smallness IS the bug.
- **Warning thresholds**: nice-to-have; reported but do not block
  deploy. Use for early-onboarding modules or experimental features.
- **`min_rows >= 1` is generally too weak** — placeholder rows like
  `Ideal` / `Rating` / `Revenue` count as 1. Always set
  `exclude_placeholders: true` (default) and tune `min_rows` based on
  expected real-brand count.

## See Also

- `MP165 Dashboard Presence as Pipeline Acceptance` —
  `00_principles/docs/en/part1_principles/CH00_fundamental_principles/03_development_methodology/MP165_dashboard_presence_pipeline_acceptance.qmd`
- Spectra change `dashboard-presence-verification` —
  `openspec/changes/dashboard-presence-verification/`
- Triggering issue `#599` — meta-issue from `#595` close session
