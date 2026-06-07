# 2026-05-10 — Dashboard Presence as Pipeline Acceptance (MP165 + framework)

**Spectra change**: `dashboard-presence-verification`
**Triggering issues**: `#595` (BrandEdge dashboard reproducibly empty) → `#599` (meta-issue: acceptance ladder gap exposed)
**Status**: Phase 1 implementation shipped; Phase 2 + Phase 3 deferred (see Migration Plan in design.md).
**Author**: Claude (Opus 4.7 1M context)

---

## Why this report exists

Two weeks of `#595` cycle exposed a recurring AI-agent failure mode:
1. AI claimed acceptance based on narrow verification chains (deploy mode, db connection, HTTP smoke).
2. User exposed gaps by reproducing the bug locally without deploying.
3. The "verification chain" was technically correct but missed the actual user-facing rendering failure.

This report locks the lesson so future work does not regress.

---

## #595 reproduction findings (the ground truth)

`#595` user complaint: 「向創 BrandEdge + TagPilot 還是沒有數據」(reproducibly empty).

`#595` Phase A/B/C verification chain claimed:
- ✅ `app_config.yaml database.mode` corrected `duckdb` → `auto` across QEF + deploy bundle + D_RACING (3 PRs)
- ✅ `dbConnect_universal()` regression tests lock fail-loud behavior
- ✅ `preflight_deploy_check.R` blocks deploy-time configuration mismatches
- ✅ `check_production_data.R` HTTP smoke against deployed Connect Cloud URL

User pushback (during `/idd-implement #595` close):
> 「你可以說你是怎麼確認資料都會出現在儀表版上呢?就是我現在其實還先不用部署就看到 QEF 沒正常顯示了」

Direct local reproduction (before any further code change) revealed three independent root causes:

| Bug | Root cause | Surface |
|-----|------------|---------|
| **A** | `positionTable.R:380` returns `data.frame()` when `prod_line == "all"` (intentional but UX-hostile) | sidebar shows hardcoded English「Please select a specific product line」, table shows「No data available」; default state of every fresh login lands here |
| **B** | `df_position` for QEF hsg has 50/54 rows with all attributes NA (AI scoring data gap) | even after selecting a specific product line, complete-case filter retains only 1 row (`Ideal` placeholder); chart renders empty |
| **C** | `fn_translation.R:38` `if (text %in% names(lang_dict))` fails on vector input from `dplyr::rename_with(translate, ...)` | red error text "Error: the condition has length > 1" surfaces in the dashboard card |

`#595` Phase A/B/C **fixed none of these three bugs**. The 5 PRs were all about deploy-mode configuration, which was a separate (legitimate) bug class but not the one user reported.

---

## Three orthogonal axes of pipeline acceptance

The investigation surfaced an architectural commitment that was implicit and inconsistent:

```
                Time/Ship-Readiness Axis (when bridge is "done")
                  ↓ MP162 Bridge End-to-End Realization (L1-L5)
                  
Input-Completeness Axis ────────────┐
  ← MP163 Progressive Completeness   │
    (sentinel discipline)            │
                                     ▼
                              ┌────────────┐
                              │  Pipeline  │ Three axes must each
                              │ Acceptance │ be satisfied
                              │            │ independently for
                              │            │ user-facing
                              │            │ completeness.
                              └────────────┘
                                     ▲
                                     │
              Rendering-Acceptance Axis
              ↑ MP165 Dashboard Presence as Pipeline Acceptance
                (per-tab × per-platform × per-product_line every-field)
```

`#595` reproduction proved all three axes can fail independently:

- **MP162 axis**: Bridge yaml correct; df_position bridge passes L1-L5 in MAMBA #378 sense.
- **MP163 axis**: Pipeline runs end-to-end; gaps materialize as 1-row `Ideal` placeholder (sentinel-like). MP163 says "pipeline keeps running" — and it does. MP163 alone does not require the rendered output to be useful.
- **MP165 axis** (new): The rendered dashboard must satisfy per-element contracts. Bug A + Bug B + Bug C all live in this axis.

A pipeline can satisfy MP163 (gracefully sentinel-bucket gaps) yet fail MP165 (those gaps render as user-visible empty tabs that surface no actionable hint). The `#595` reproduction was exactly this case.

---

## Why MP165 is a new principle, not an extension of MP163

**Considered**: extend MP163 with "Gate 5: Dashboard-Presence Verification".

**Rejected** because MP163 is scoped to **input-completeness** axis (per its done proposal: "pipeline 與 derivation 永遠要可跑到底,不論人工輸入完整度為何"). All MP163 trigger scenarios are about absent human-curated input. Dashboard rendering is downstream of input completeness; conflating them would lose MP163's thesis focus.

**Considered**: extend MP162 L5 to include per-dashboard-tab.

**Rejected** because MP162's unit is per-bridge (L4: at least one Shiny module renders > 0 rows). MP165 needs per-tab × per-platform × per-product_line granularity. Different unit; sister relationship preserved.

**Considered**: pure TD_R-tier rule without an MP.

**Rejected** because user explicitly requested 「也需要進入 principle」. A rule alone would describe HOW to test but not WHAT contract pipeline acceptance carries.

**Selected**: new MP165 + supporting framework + DOC_R009 triple-layer sync. Keeps MP163 thesis focused and gives the rendering-acceptance axis an explicit Tier-1 home.

---

## What shipped (Phase 1)

11 of 35 tasks complete in this session:

### Principle codification (DOC_R009 triple-layer sync)
- Layer 1 EN qmd: `00_principles/docs/en/.../MP165_dashboard_presence_pipeline_acceptance.qmd`
- Layer 1 zh qmd: same path under `docs/zh/...` (UI_R025 Taiwan zh_TW conventions)
- Layer 2 LLM index: `llm/CH00_meta.yaml` MP165 entry; `principle_count` 142 → 143
- Layer 3 quick reference: `.claude/rules/01-always.md` MP165 short reference
- Sister back-edits: MP162, MP163, MP102, MP029 each got `related_to: MP165` cross-reference (both in their qmd files and in their LLM yaml entries)

### Framework backbone
- `98_test/e2e/contracts/contracts.R` — primitive helpers + YAML schema validator
  - 5 primitives: `assert_kpi_card_value`, `assert_datatable_meaningful_rows`, `assert_plotly_has_data_points`, `assert_filter_dropdown_choices`, `assert_chart_axis_non_empty`
  - Pure helpers (testable without Shiny): `exclude_placeholder_rows`, `compare_value`, `format_contract_failure`, `check_*` family
  - `validate_contract_yaml()` enforces top-level + per-module + per-tab + per-contract schema
- `98_test/test_contract_primitives.R` — 31 unit tests, all GREEN
  - Critical regression test: QEF hsg 1-row Ideal case shows strong contract `min_rows=5 + exclude_placeholders=TRUE` FAILS while legacy weak `min_rows=1` PASSES (the contract gap that #595 exposed)
  - Hard fail discipline tests: no `soft_warn_mode` / `skip_contract` / `disable_contract` toggles in scope

### Per-company contract YAMLs
- `qef_design.yaml` — 4 modules (BrandEdge, TagPilot, VitalSigns, dashboard_overview), 20 contracts
- `d_racing.yaml` — 4 modules, ~15 contracts (lower brand thresholds)
- `mamba.yaml` — 4 modules with brandedge.enabled=false (documents opt-out + #378 incident-class contracts)
- `_template/contract.yaml` — starter for new companies; documents both opt-out paths
- `README.md` — usage guide for the contracts directory

### Tier 2 deploy gate
- `23_deployment/dashboard_presence_gate.R` — orchestrator
  - `--company`, `--app-dir`, `--module`, `--dry-run`, `--allow-warnings`/`--block-warnings`
  - Exit codes: 0 pass / 1 critical fail / 2 schema invalid / 3 usage error / 4 missing YAML
  - Assertion DSL parser: `row_count_excluding_placeholders >= N`, `kpi >= N`, `kpi != NA`, `plotly_non_empty_traces >= N`, `filter_choice_count >= N`, `no_red_error_text`, `non_empty_text`
- `98_test/test_gate_severity.R` — 12 PASS + 1 SKIP (skip blocks on Tier 1 task 6.1)

### Tier 3 CI selective
- `98_test/e2e/affected_modules.R` — diff-driven module mapper
  - Reverse-dependency expansion (touch fn_translation.R → all modules)
  - 6 manual smoke tests pass
- `.github/workflows/dashboard-contracts.yml` — CI workflow file

### Hard fail audit
- Grep audit confirms: no `soft_warn_mode` / `skip_contract` / `disable_contract` flag implementations; only negative references in documentation/tests asserting absence

---

## What did NOT ship (deferred)

24 of 35 tasks remain pending, blocked by external prerequisites:

**Phase 2** (blocked by `#588` plotly stability fix):
- 5.1-5.4: Strengthen existing `test-brandedge.R`, `test-vitalsigns.R`, `test-tab-navigation.R` (replace weak primitive, parameterize per-product_line, remove `#587` skip)
- 6.1-6.3: DRV `_targets.R` Tier 1 lite integration (`run_dashboard_smoke_lite_check`, `dashboard_smoke_lite` target, runtime budget validation)

`#588`: dashboardOverview reactives may run on every tab — investigate isolation. Until #588 ships, the `wait_for_idle` plotly-heavy abort blocks any e2e suite expansion.

**Phase 3** (post-ship optimization):
- 7.2: Wire `dashboard_presence_gate.R` into per-company `make deploy-push` Makefile recipes (5 Makefiles)
- 7.3: Verify warning severity does not block deploy via shinytest2 launch
- 8.3: Validate helper-touches-many-modules CI case via synthetic PR
- 10.1-10.5: Cross-company IC_P002 verify (run gate against each of 5 companies + commit `Verified:` trailer)
- 11.2-11.3: INDEX.md update + final reproduce of `#595`

---

## The reproduce-driven lesson (for future AI agents)

> **Acceptance ladder claims must rest on user-side rendering verification, not just on internal verification chains. Code-trace + db-query is necessary but not sufficient.**

Three-step pattern that should now be standard for any "dashboard data" bug fix:

1. **Reproduce locally** before claiming acceptance. Launch the actual app, log in, navigate the actual user path, observe what renders. Read both browser DOM and R log.
2. **Trace to root cause** based on observed behavior, not assumed behavior. UI red text + R log "condition has length > 1" trace to a specific line; "No data available" + 1-row table trace to a different specific line. Don't conflate.
3. **Fix at the right layer**. Bug A is UX (translate empty-state). Bug B is data quality (AI scoring pipeline gap, owner-action). Bug C is code (vectorize translate). Three different fixes, not one.

Without `MP165` framework the "fix at the right layer" check is ad-hoc. With the framework, every fix can be locked by a contract assertion that would have caught the original bug class — making future regressions visible at the DRV gate or deploy gate, not at the user's screen.

---

## Rollback plan (if framework causes unintended regression)

The framework is purely additive:
- `_targets.R` Tier 1 lite target (when shipped in 6.2): remove the target → DRV pipeline behavior reverts to current
- Deploy gate (7.2 wiring): remove the gate invocation from Makefile → deploy bypasses gate
- MP165 principle, contracts framework, contract YAMLs: leave in place; they have no runtime side effect when the gates are not invoked

The framework cannot break existing ETL / DRV / dashboard rendering, because it only inspects them. Rollback is removing the gates, not removing the framework.

---

## Sister issues filed in this cycle

- `#600` (P3): BrandEdge 5 sister sub-tabs hardcoded English empty-state — independent UX issue tracked separately
- `#601` (P1): QEF hsg AI review scoring gap — 92.6% of products have all attributes NA; needs product/DRV owner action

These are NOT MP165 framework concerns; they are concrete bugs surfaced by the same `#595` reproduction. The framework's value is that once shipped, both `#600` and `#601` would be caught at the deploy gate or DRV gate before user reaches the dashboard.

---

## Audit trail

| Phase | Commits | PRs |
|-------|---------|-----|
| `#595` Phase A (yaml mode) | bd60960 / 2cc4e78 / 4deca46 | merged 2026-05-09 |
| `#595` Phase B+C (preflight + tests) | e4ecc17 | merged 2026-05-09 |
| `#595` Phase E (translate vectorize) | 65aca42 | merged 2026-05-10 |
| `#595` Phase D (UX empty-state) | 1d4f070 | merged 2026-05-10 |
| MP165 framework (Phase 1) | (this session, in progress) | — |

Spectra change directory: `openspec/changes/dashboard-presence-verification/`
- `proposal.md`, `design.md`, `specs/dashboard-presence-verification/spec.md`, `tasks.md`
- All artifacts validated; analyzer Critical=0 / Warning=0 / Coverage=Clean / Consistency=Clean

---

🤖 Generated by `/spectra-apply dashboard-presence-verification` Phase 1.
