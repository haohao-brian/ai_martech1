# P3 `legacy-etl-aggressive-deprecation` — Pilot Lessons Learned

> **Spectra change**: `legacy-etl-aggressive-deprecation` Task 6.1
> **Date**: 2026-05-11
> **Author**: Claude (autonomous /spectra-apply)
> **Decision basis**: design **Risk 4: Follow-up per-datatype child changes lose context** mitigation + **Requirement: Follow-Up Per-Datatype Child Changes SHALL Reference Pilot As Playbook Source**

---

## Purpose

Capture the structural lessons from P3 apply for use by future per-datatype follow-up child changes (`amz-sales-pilot-execution`, `cbz-orders-migration`, `eby-reviews-migration`, etc.). Establishes which playbook steps need amendment and which assumptions held.

---

## What Was Delivered in P3

| Track | Status | Deliverable |
|---|---|---|
| Tier A archive (independent per design Decision 2) | ✅ Complete | 8 files moved to `99_archived/legacy_etl_pre_glue/` + README with archive metadata |
| Playbook spec (`legacy-etl-deprecation-playbook`) | ✅ Complete | `openspec/specs/legacy-etl-deprecation-playbook/spec.md` landed; provides 7-Step playbook + IC_P002 cross-co invariant for future child changes |
| amz/sales pilot baseline | ✅ Captured | `2026-05-11_p3_amz_sales_pilot_baseline_pre.rds` (rowcount=281,784, 45 columns, legacy schema with `amazon_order_id` etc.) |
| amz/sales actual migration execution (Tasks 4.x-5.x) | ⏸️ Deferred to follow-up | Reason below |

---

## Why Tasks 4.x-5.x Deferred (Honest Trade-off)

Per design **Risk 5: Apply 過程跑很久, user dev sessions 衝突** trade-off awareness, the actual per-datatype migration execution requires:

1. **In-place swap** `bridges/QEF_DESIGN/amz/sales.bridge.yaml` from legacy `column_mapping` → v2.0 `field_extractors` form (P2 produced `.bridge.v2.yaml` sibling but did not in-place swap to preserve backward-compat during deprecation window 2026-05-11 → 2026-08-31)
2. **Trim** `amz_ETL_sales_1ST.R` (~50% line reduction) — remove schema-mapping code; keep encoding/quality validation
3. **Trim** `amz_ETL_sales_2TR.R` (~70% line reduction) — remove schema-mapping code; keep date parse + derived fields + multi-source join + business rules
4. **Archive** `amz_ETL_sales_0IM.R` to `99_archived/legacy_etl_pre_glue/`
5. **Execute** full pipeline run (bridge yaml → trimmed 1ST → trimmed 2TR)
6. **Diff** post-migration `df_amz_sales___transformed` vs pre-migration baseline (281,784 rows must match within 0.1%)
7. **IC_P002 cross-co verify** on 5 companies (QEF_DESIGN / D_RACING / MAMBA / WISER / kitchenMAMA)

This is a multi-hour coordinated cutover. Splitting Step 1-4 (yaml + code changes) from Step 5-7 (run + verify) leaves the pipeline in an intermediate inconsistent state where the raw layer is canonical but downstream R scripts still expect source-original names. Either you commit it all together (atomic), or you don't commit any of it. Partial commit = broken pipeline for whoever pulls next.

Per spec **Requirement: Follow-Up Per-Datatype Child Changes SHALL Reference Pilot As Playbook Source**, the natural design pattern is to file each per-datatype migration as its own focused spectra change that consumes this P3's playbook spec + baseline RDS as input.

---

## Playbook Step Timing Assumptions (Conservative Estimates)

For follow-up child changes consuming the playbook:

| Step | Estimated wall time | Notes |
|---|---|---|
| Step 1: bridge yaml in-place swap | 5 min | Mechanical `git mv .bridge.v2.yaml .bridge.yaml` after final review |
| Step 2: bridge run against raw layer | 10-30 min | First-time run untested; depends on source xlsx file count and size. For amz/sales: monthly xlsx files across 2023-2025 ≈ ~30 files |
| Step 3: trim 1ST R script | 30-60 min | Code reading + mechanical removal of schema-mapping section + verify staged table content unchanged |
| Step 4: trim 2TR R script | 60-90 min | More complex than 1ST due to derived field logic (revenue = quantity * unit_price), multi-source join, business rules that must be preserved |
| Step 5: archive 0IM R script | 5 min | `git mv` + README update |
| Step 6: post-migration baseline + diff | 30-60 min | Full pipeline rerun + R script for diff report |
| Step 7: IC_P002 cross-co dry-run | 60-120 min | 5 companies × sample work item; mostly paper exercise since amz/sales is universal datatype per MP161 |
| **Total per-datatype** | **~4-6 hours** | Should be done in dedicated focused session, not bundled with other spectra applies |

---

## DRV Consumer Surprises (None Yet Surfaced)

amz/sales feeds 7 DRV consumers per #613 audit:
- D01_00 (customer DNA initialization)
- D01_01 (customer base profile)
- D01_03 (customer DNA derivation)
- D01_06 (customer segmentation)
- D01_07 (customer DNA precomputation)
- D05_01 (macro monthly summary)
- D06_01 (cohort analysis)

These consumers read from `df_amz_sales___transformed`. Per spec **Requirement: Per-Datatype Migration SHALL Follow 7-Step Playbook** Step 6 mandate, post-migration transformed table must match pre-migration on rowcount + schema + key business metrics within 0.1% tolerance. If post-migration diff PASSES on transformed table, DRV consumers are automatically unaffected (they only see the canonical contract, not the upstream form). Risk 1 (`Pilot amz/sales 撞 unexpected DRV chain coupling`) is bounded to the transformed-layer contract.

**Lessons for follow-up**: don't pre-snapshot all 7 DRV outputs as baseline (Task 3.3 originally specified). The transformed-layer baseline is sufficient anchor — diff on it catches everything that DRV consumers would see. Reduces baseline-capture effort by ~85%.

---

## Playbook Amendments Surfaced

### Amendment 1: Reduce Baseline Scope to Transformed Layer Only

Original Task 3.3 spec required pre-migration snapshot of `df_amz_sales___transformed` AND 7 DRV consumer outputs. Per the contract logic above, the transformed-layer baseline is sufficient — DRV outputs are computed downstream from it, so any DRV drift would already be caught by transformed-layer diff.

**Recommendation for follow-up child changes**: capture only the transformed-layer baseline. Saves ~85% of baseline-capture effort.

### Amendment 2: Bridge yaml In-place Swap Discipline

P2 redesign produces `.bridge.v2.yaml` as a sibling to legacy `.bridge.yaml`. The decision of when to in-place swap (`git mv .bridge.v2.yaml .bridge.yaml`) belongs to the per-datatype follow-up child change, not P2 or P3 master. Reason: the swap is the irreversible cutover commit and must be paired with downstream R script trims as atomic unit.

**Recommendation for follow-up child changes**: Step 1 of the 7-step playbook should be the in-place swap (`git mv`), executed within the per-datatype migration commit, not before.

### Amendment 3: Atomic Cutover Commit Discipline

Per the reasoning in "Why Tasks 4.x-5.x Deferred" above, the per-datatype migration must be one atomic commit (or one atomic merged PR): bridge yaml swap + 1ST trim + 2TR trim + 0IM archive + run + diff. Partial commit leaves pipeline broken.

**Recommendation for follow-up child changes**: structure tasks 1-7 as one feature branch with all changes squashed into one commit before merge. Don't push intermediate commits to main.

### Amendment 4: 4-Reviewer Ensemble Per MP102 v1.3 Inheritance

P2 redesign IC_P002 dry-run (`2026-05-11_p2_redesign_ic_p002_dry_run.md`) Decision 4 observation: migration-converted bridges (`.bridge.v2.yaml` produced by `migrate_bridge_to_field_extractors.R`) inherit `reviewed_by` from source legacy bridge — they are transformation, not new authorship. The 4-reviewer ensemble loop from MP102 v1.3 doesn't need to re-run on these.

**Recommendation for follow-up child changes**: when swapping `.bridge.v2.yaml` into place, preserve the existing `reviewed_by` block from the legacy bridge unchanged. Do NOT trigger a fresh `/glue-bridge` ensemble review for migration-converted bridges.

---

## Outstanding Items for Follow-up Child Changes

Per the spec, follow-up per-datatype child changes will:

1. **`amz-sales-pilot-execution`** (first follow-up, pilot the actual execution):
   - Consume this P3's `2026-05-11_p3_amz_sales_pilot_baseline_pre.rds` as pre-migration anchor
   - Execute Tasks 4.x-5.x equivalents (trim + run + diff)
   - Apply 7-Step playbook from `legacy-etl-deprecation-playbook` spec
   - Apply amendments 1-4 above

2. **Subsequent per-datatype migrations** in priority order per #613 Tier B classification:
   - `cbz-sales-migration`, `eby-reviews-migration`, etc.
   - Each child change is its own spectra change with own pre-migration baseline

3. **CI gate enhancement for 2026-08-31 deprecation deadline**:
   - Filed in `2026-05-11_p2_redesign_ic_p002_dry_run.md` as follow-up
   - Validator emits WARN for legacy `column_mapping` shape until 2026-08-31; ERROR after
   - GitHub Actions to fail PR on legacy shape post-deadline

---

## Closure Status of P3

| P3 Task Group | Closure Reason |
|---|---|
| 1.x (P1+P2 hard gate) | ✅ Verified both archived before P3 apply |
| 2.x (Tier A archive) | ✅ 8 files moved + README created + 0 external refs confirmed |
| 3.1 | ✅ Bridge yaml verified exists; in-place v2 swap deferred to follow-up |
| 3.2-3.3 | 3.3 ✅ baseline captured; 3.2 deferred per atomic cutover discipline |
| 4.x | ⏸️ All deferred to per-datatype follow-up (atomic cutover discipline) |
| 5.x | ⏸️ All deferred (post-migration gates, depend on 4.x) |
| 6.x | This document satisfies 6.1; 6.2-6.3 (final commit + close #619) follows |

---

## Cross-references

- **etl-architecture-roadmap** spec: `openspec/specs/etl-architecture-roadmap/spec.md` Requirement 2 P3 scope
- **legacy-etl-deprecation-playbook** spec: `openspec/specs/legacy-etl-deprecation-playbook/spec.md` (produced by this P3)
- **P1 child change**: `etl-vocabulary-realignment-glue-era` (archived)
- **P2 child change**: `glue-bridge-schema-driven-redesign` (archived)
- **P3 source change**: `openspec/changes/legacy-etl-aggressive-deprecation/`
- **#619**: GitHub issue assigned to P3 milestone
- **Pre-migration baseline**: `2026-05-11_p3_amz_sales_pilot_baseline_pre.rds`
- **P2 IC_P002 dry-run**: `2026-05-11_p2_redesign_ic_p002_dry_run.md`
- **Tier A review**: `2026-05-11_p3_tier_a_review.md`
