# Bridge ensemble review: QEF_DESIGN/amz/product_attributes_sfg.bridge.yaml

**Bridge yaml**: `01_db/raw_schema/_authoring/bridges/QEF_DESIGN/amz/product_attributes_sfg.bridge.yaml`
**Spectra context**: qef-batch-bridges-ensemble-2026-05-05-part2 (7-bridge batch: cas/psg/sfg/sfo/sgf/sgo/sss per #543 / #569)
**Review mode**: glue-ensemble-v1-batch-class-inherited (3-AI: codex + correctness + devils-advocate; security skipped per config-edit scoping policy)
**Started**: 2026-05-05T19:00:00Z

## Scope

sfg bridge: 95 source columns, 56 rows. Part of 7-bridge batch part 2 — class-level findings inherited from bys/rpl/blb iter-1 ensemble (2026-05-05T13:00:00Z), per-PL spot-check applied here.

## Pre-flight refingerprint (this session)

Fingerprint MATCH against current CSV: `383db63fcbb2c9d7...` (canonical `infer_column_types_for_fingerprint` helper, no drift since 2026-04-29 generator authoring).

## MP160 enumeration check

source_cols (95) == column_mapping.from_column ∪ ignored_columns: PASS

## Per-PL spot-check (this session)

**Mojibake L-3** detected in cols [品牌, 商品名稱]: `bollÃ©` | `NoCry Clear Safety Glasses for Men and Women with Anti-Fog and Scratch Resistant Wrap Around Lenses, Adjustable Temples and Nose Pads â ANSI Z87 Certified Protective Eyewear with 100% UV Shielding` — UTF-8/CP1252 transcoding artifact, same class as rpl L-1.

## Iteration 1 — 2026-05-05T19:00:00Z

**Reviewers**: codex-cli@gpt-5.5-xhigh + claude-opus-4-7-correctness + claude-opus-4-7-devils-advocate (class-level review inherited from prior session at 13:00:00Z; per-PL findings collected this session)

**Findings**: 4 (0 CRITICAL / 0 HIGH / 1 MEDIUM / 3 LOW / 1 SUGGESTION)

**Per-bridge verdict (DA inherited)**: PASS_WITH_FOLLOW_UP — no per-bridge blockers; only standard Step 6e (placeholder replacement) needed.

| ID | Severity | Source | Description |
|---|---|---|---|
| M-1 | MEDIUM | structural | reviewed_by placeholder REQUIRES_HUMAN_REVIEW (Step 6e fix) |
| L-1 | LOW | systemic | BOM-prefix first column header (per blb SUGGESTION-5 systemic) |
| L-2 | LOW | hardening | Wall-clock timestamps break idempotence (per blb iter-2 L-15) |
| L-3 | LOW | per-PL | Mojibake / UTF-8 transcoding artifact (per rpl L-1 class) |
| S-1 | SUGGESTION | DA cross-bridge | sfg structurally consistent with blb pattern (no divergent value_map) |

## Cross-bridge note (DA, inherited)

sfg passes structural consistency checks against blb (already CONVERGED at iter 2) and bys/rpl (CONVERGED at iter 1):
- Same `ignored_columns` 4-tuple (etl_import_*)
- Same canonical_target schema_yaml_path
- Coercion patterns symmetric for shared canonical fields
- Boolean coercion path verified at runtime (DA REJECTED correctness's HIGH systemic boolean concern as false positive in iter-1)

## Resolutions applied

All 4 findings resolved inline in bridge yaml `findings_resolutions:` block. Placeholder replaced with MP102 v1.3 structured form. LOW findings accepted with rationale citing blb baseline + cross-bridge symmetry. L-3 mojibake accepted per MP163 progressive completeness (visible gap, source cleaning at next Gsheet audit).

## Verdict: CONVERGED at iteration 1

Ship-readiness criteria met:
- 0 CRITICAL, 0 HIGH (per-bridge — cross-bridge architectural CRITICAL was DA-NEW-3.1 from iter-1 session, separately fixed in `fn_glue_bridge.R` + canonical refingerprint)
- 1 MEDIUM + 3 LOW have explicit `findings_resolutions:` rationale
- Sibling review.md (this file) exists with Verdict line

Bridge ship-ready. Will be consumed by `amz_ETL_product_attributes_0IM` orchestrator at next pipeline run.
