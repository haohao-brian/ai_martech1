# fix-glue-layer-infra-blockers — Closing Summary

> **Spectra change**: `fix-glue-layer-infra-blockers`
> **Date**: 2026-05-12
> **Commit**: `18c703d` on `idd/fix-glue-layer-infra-blockers` (kiki830621/ai_martech_global_scripts)
> **Verdict**: ✓ All Sections complete

## Deliverables

### Code changes (atomic cutover commit)

| File | Change |
|---|---|
| `00_principles/.claude/skills/glue-bridge/SKILL.md` | Step 2/3/6a updated to use `infer_column_types_for_fingerprint()` (#628) + coercion whitelist documentation (#631) |
| `01_db/raw_schema/_authoring/migrate_bridge_to_field_extractors.R` | Brought from P2 archive + KNOWN_EXTENSION_FIELDS whitelist + unknown-field WARNING (#630) |
| `01_db/raw_schema/_authoring/regen_bridge_fingerprints.R` | NEW — idempotent helper for mechanical fingerprint regen (#628) |
| `05_etl_utils/glue/fn_apply_mapping.R` | `apply_coercion_pipeline()` helper + integration into `coerce_field()` (#631) |
| `05_etl_utils/glue/fn_glue_bridge.R` | Brought from P2 archive with v2 shape detection + inline translator |
| `00_principles/.claude/skills/glue-bridge/scripts/validate_bridge_yaml.R` | Brought from P2 archive + 3 advisory checks (timestamp/value_map/unsupported coercion) |
| `01_db/raw_schema/_authoring/bridges/QEF_DESIGN/amz/*.bridge.yaml` (14 files) | All re-migrated to v2 + 13/14 fingerprints regenerated + sales surgical-merged with pilot additions |
| `98_test/test_migrate_bridge_value_map_preservation.R` | NEW — 4 fixture cases for #630 |
| `98_test/test_coerce_field_pipeline.R` | NEW — 6 fixture cases for #631 |
| `00_principles/changelog/reports/2026-05-12_fix_glue_infra_*.md` | 4 reports (audit / runtime_verify / ic_p002 / summary) |

### Spec amendments landed (when /spectra-archive applies)

| Spec | MODIFIED |
|---|---|
| `glue-bridge-schema-driven-shape` | (a) coercion pipeline execution scenarios (#631) + (b) migration tool whitelist + unknown extension fields (#630) |
| `glue-self-converging-review` | mechanical fingerprint regeneration preserves reviewed_by (#628) |

### Bug closure

- ✅ **#628** Fingerprint method inconsistency — CLOSED
- ✅ **#630** Migration tool value_map drop — CLOSED
- ✅ **#631** coerce_field ignores coercion — CLOSED

### Follow-up surfaced

- ⚠️ **#632** Canonical schema CHECK pattern too strict for Seller-Fulfilled order IDs (S01-prefix) — Layer 1 concern, separate change recommended

## Verification trail

| AC | Status | Evidence |
|---|---|---|
| AC-1 SKILL.md normalized | ✓ PASS | `infer_column_types_for_fingerprint` × 5 matches in SKILL.md |
| AC-2 migration tool whitelist | ✓ PASS | KNOWN_EXTENSION_FIELDS in tool + both type=column + type=const paths iterate copy |
| AC-3 apply_coercion_pipeline | ✓ PASS | Helper defined + integrated in coerce_field after canonical type switch |
| AC-4 validator 3 advisories | ✓ PASS | Stub yaml fixtures emit corresponding WARN/INFO |
| AC-5 regen helper idempotent | ✓ PASS | 2 consecutive runs on sales.bridge.yaml produce identical output |
| AC-6 test files | ✓ PASS | 10 test_that blocks across 2 files all PASS |
| AC-7 14 bridges re-processed | ✓ PASS | 14/14 migrated to v2 + 13/14 fingerprints regenerated (1 unreachable per Risk 1) |
| AC-8 14 bridges runtime | ✓ PASS (9 PASS + 5 BLOCKED with pre-existing CRITICALs outside this change scope) |
| AC-9 amz-sales INSERT | ~ PARTIAL (apply_mapping correct, DB INSERT blocked on #632 — separate Layer 1 concern) |
| AC-10 pilot resume preflight | ✓ PASS at apply_mapping; INSERT depends on #632 |
| AC-11 IC_P002 5 公司 | ✓ PASS | All 5 companies verdict PASS, no REGRESSION |
| AC-12 atomic cutover | ✓ PASS | Single commit 18c703d with all changes + Closes #628 #630 #631 + Verified trailer |
| AC-13 3 issues closed | ✓ PASS | #628 / #630 / #631 all CLOSED with cross-link to commit + reports |

**Overall**: 12 of 13 AC PASS, 1 PARTIAL (AC-9 INSERT blocked on out-of-scope #632 which design Risk 4 explicitly anticipated).

## What this change enables

amz-sales-pilot-execution (#627) Section 4-7 can resume once #632 lands:
- Section 4 trim 1ST/2TR R scripts (no infra blockers remaining)
- Section 5 archive 0IM
- Section 6 pre/post transformed-layer diff (mapping layer proven within 0.05% tolerance)
- Section 7 IC_P002 cross-co (this change pre-verified for amz/sales)

Or pilot can workaround #632 by adding pre_filter rule for S01-prefixed order IDs (rejected per design — loses 402 legitimate orders).

## Cross-references

- Spectra change directory: `openspec/changes/fix-glue-layer-infra-blockers/`
- Atomic commit: `18c703d` on `idd/fix-glue-layer-infra-blockers`
- Closed issues: #628 / #630 / #631
- Follow-up: #632
- Unblocks (at mapping level): #627 amz-sales-pilot-execution
- IC_P002 verify: QEF_DESIGN / D_RACING / MAMBA / WISER / kitchenMAMA
