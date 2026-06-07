---
date: 2026-05-13
issue: kiki830621/ai_martech_global_scripts#650
related: MP165 v1.1, IC_P002, #648, #649
status: PASS
company: QEF_DESIGN
context: local (dev-time)
---

# QEF amz Dashboard — Local Check (MP165 v1.1 Step 1 + Step 2)

## Result: PASS

| Axis | Result |
|---|---|
| **Step 1 — No Red Errors** | ✅ PASS (0 NULL output markers, 18.7s walk) |
| **Step 2 — Meaningful Values** | ✅ PASS (119 / 119 contracts, 0 critical, 0 warning) |
| **Context** | Local check (`--allow-warnings`, dev-time stringency) |
| **Verdict per MP165 v1.1** | Local check satisfied; Deploy check pending (separate follow-up) |

## Scope

Per [MP165 v1.1](../docs/en/part1_principles/CH00_fundamental_principles/03_development_methodology/MP165_dashboard_presence_pipeline_acceptance.qmd):

- **Quality Axis**: Step 1 (no red errors) + Step 2 (meaningful values)
- **Context Axis**: Local check (dev-time, `--allow-warnings`, warning ≠ blocker, critical = blocker)

This report covers QEF_DESIGN's amz platform after the 8h 51m full DRV rerun (26 DRV completed, 0 errored).

## Step 1 — No Red Errors

**Tool**: `scripts/global_scripts/98_test/e2e/run_smoke_lite.R::run_dashboard_smoke_lite_check()`

**Procedure**: launch app with `SHINY_DEBUG_MODE=TRUE`, walk all 6 top-level tabs (總覽儀表板 / TagPilot / Marketing Vital-Signs / BrandEdge / InsightForge 360 / 報告中心), scan log for `[DEBUG_MODE_NULL_OUTPUT]` markers from `04_utils/fn_debug_mode.R::debug_log_output()`.

**Result**:

```
[smoke-lite] starting for QEF_DESIGN at /Users/che/.../QEF_DESIGN
[smoke-lite] app listening at http://127.0.0.1:7973
[smoke-lite] click @e8 (總覽儀表板)
[smoke-lite] click @e9 (TagPilot)
[smoke-lite] click @e10 (Marketing Vital-Signs)
[smoke-lite] click @e19 (BrandEdge)
[smoke-lite] click @e18 (InsightForge 360)
[smoke-lite] click @e16 (報告中心)
[smoke-lite] QEF_DESIGN walk complete in 18.7s (0 NULL markers)
```

→ **Step 1 PASS**: 0 NULL output markers across all top-level tabs.

## Step 2 — Meaningful Values

**Tool**: `scripts/global_scripts/23_deployment/dashboard_presence_gate.R`

**Contracts**: `scripts/global_scripts/98_test/e2e/contracts/qef_design.yaml` (20 base selectors × per-product-line expansion = 119 contracts at runtime)

**Invocation**:

```bash
Rscript dashboard_presence_gate.R \
  --company QEF_DESIGN \
  --app-dir "$(pwd)" \
  --allow-warnings \
  --password VIBE \
  --timeout 90
```

**Result**:

```
=== MP165 Dashboard Presence Gate - QEF_DESIGN ===
  Total contracts: 119
  Passed:          119
  Critical failed: 0
  Warning failed:  0

PASS: all contracts satisfied.
```

→ **Step 2 PASS**: 100% contract pass rate (119/119).

**Primitives exercised**: `assert_kpi_card_value` / `assert_datatable_meaningful_rows(exclude_placeholders=TRUE)` / `assert_plotly_has_data_points` / `assert_filter_dropdown_choices` / `assert_chart_axis_non_empty` (per `contracts.R`).

## Out of scope

- **Deploy check** — `dashboard_presence_gate.R` without `--allow-warnings` (strict mode, warning = blocker) on Posit Connect Cloud. Per MP165 v1.1, separate context axis; will be filed as sister issue.
- **Per-product-line drill-down** — gate walks summary-level contracts. Deep-dive per product line (台灣禮品線 / 美國禮品線) deferred to dashboard QA review.
- **Cross-company verification** — D_RACING / MAMBA / WISER / kitchenMAMA local checks via sister issues per IC_P002.

## Cross-references

- MP165 v1.1 amendment: [PR #649 merged 2026-05-13](https://github.com/kiki830621/ai_martech_global_scripts/pull/649)
- Pipeline run baseline: 8h 51m, 26 DRV completed 0 errored (gpt-5.5 migration + 2TS Strategy C fix + canonical schema)
- Source contracts: 20 base selectors in `qef_design.yaml` (BrandEdge position fails per #601 are known exempted, not in the 119 expansion)

## Next steps

1. **File sister Deploy check issue** — QEF amz dashboard Deploy check (strict mode, no `--allow-warnings`)
2. **Optional**: Posit Connect Cloud redeploy if needed (DRV outputs all populated, no blockers from local check)
3. **Cross-company** (advisory, per IC_P002): run same local check on D_RACING / MAMBA / WISER / kitchenMAMA when convenient
