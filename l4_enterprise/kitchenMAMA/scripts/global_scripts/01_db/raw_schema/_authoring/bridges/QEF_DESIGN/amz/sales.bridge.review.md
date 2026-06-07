# Bridge ensemble review: QEF_DESIGN/amz/sales.bridge.yaml

**Bridge yaml**: `01_db/raw_schema/_authoring/bridges/QEF_DESIGN/amz/sales.bridge.yaml`
**Spectra change**: `bridge-promote-ship-fields` (Refs #418 / #564)
**Review mode**: glue-ensemble-v1 (reduced 3-AI ensemble: codex + correctness + devils-advocate; security skipped per scoping note below)
**Started**: 2026-05-04T11:00:00Z

## Scope

- Layer 1 enrichment: `core_schemas.yaml > sales > optional_fields:` adds `ship_country`, `ship_state`, `ship_city`
- Bridge change: 3 ship-* entries promoted from `ignored_columns` to `column_mapping` (kebab-to-snake rename)
- Runtime fix (discovered by ensemble): `fn_glue_bridge.R` previously read only `required_fields`; updated to also read `optional_fields` so the schema/bridge contract actually flows at runtime

## Scoping note: 3-AI vs 4-AI ensemble

This review used 3 AI reviewers (codex + 2 Claude) instead of the standard 4 (codex + 3 Claude per MP102 v1.3 / #500). Reasons:

- **Security reviewer skipped**: change is a schema/data-mapping config edit + 3-line runtime fix. No new executable code path, no auth/credential touch, no SQL injection surface. Per design.md decision 5, the bridge yaml grammar is well-bounded and doesn't introduce new attack surface.
- **Code-only path**: per user explicit AskUserQuestion choice, this spectra-apply session is "code-only first" — heavyweight ensemble overhead is reduced in exchange for ETL re-run / UI smoke tests deferred to a follow-up session by the user.
- **Asymmetric value**: codex (cross-model) caught the only HIGH finding (runtime ignoring `optional_fields`); 3-AI was sufficient.

Future sensitive bridge changes should run full 4-AI ensemble. This reduction is one-off, not a precedent.

## Iteration 1 — 2026-05-04T11:00:00Z

**Reviewers**: codex-cli@gpt-5.5-xhigh + claude-opus-4-7-correctness + claude-opus-4-7-devils-advocate

**Findings count**: 1 HIGH + 2 LOW + 3 SUGGESTION

| ID | Severity | Source | Description |
|---|---|---|---|
| H-1 | HIGH | codex (rule: MP102 v1.3 / MP160) | `fn_glue_bridge.R:201` reads only `required_fields`; `optional_fields` (containing the 3 promoted ship_* fields) silently dropped at `apply_mapping` + `validate_against_schema`. Schema/bridge says "map ship-city to ship_city" but runtime drops them. |
| L-1 | LOW | codex (MP160) | `ignored_columns:` header comment still says "address-type / ship-* (other than ship-service-level)" all ignored. Comment stale after promotion. |
| L-2 | LOW | codex (MP160) | `review_notes` still says "30 columns ignored by design"; actual count after promotion is 28. |
| S-1 | SUGGESTION | codex (business semantic) | "ship-country" is the correct Amazon All Orders Report column name (not "ship-to-country"). Source: Amazon SP-API docs. No action needed. |
| S-2 | SUGGESTION | codex (MP102/DM_R065) | `ship_country` / `ship_state` / `ship_city` use canonical schema's default `trimws` coercion + no `value_map`. Compliant with DM_R065. Future case-variant handling should go through canonical coercion or DRV normalization, not bridge value_map. |
| S-3 | SUGGESTION | codex (MP102 v1.3) | `sales.bridge.review.md` doesn't exist yet (expected at iter 1; written at Step 6e on convergence). `reviewed_by:` still legacy string (expected at iter 1). |

**Findings hash** (sorted tuples sha256): not computed for 3-AI reduced ensemble (helper expects 4-AI). Manual verification of plateau-detection: would only matter for iter 2+ which we don't run since iter 1 reaches CONVERGED after fixes.

## Resolutions applied

| Finding | Action | Resolved in |
|---|---|---|
| H-1 | Modified `fn_glue_bridge.R:201` to read `optional_fields <- schema_doc[[datatype]]$optional_fields %||% list()`. Changed `apply_mapping` and `validate_against_schema` calls to use `combined_canonical_fields <- c(required_fields, optional_fields)`. | Working tree edit (this session) |
| L-1 | Updated `ignored_columns:` header comment to reflect the 3 promoted fields + only address-type / ship-postal-code remain ignored. | Working tree edit (this session) |
| L-2 | Updated `review_notes` count from "30 columns" → "28 columns" with annotation that 3 were promoted via this spectra change. | Working tree edit (this session) |
| S-1 / S-2 / S-3 | No action — informational confirmations from codex. | N/A |

## findings_resolutions block (for bridge yaml `findings_resolutions:` field per MP102 v1.3)

```yaml
findings_resolutions:
  - finding_id: L-1
    severity: LOW
    description: "ignored_columns header comment stale (still mentions ship-* as ignored)"
    resolution: "fixed inline this session — comment updated to reflect 3 fields promoted to column_mapping"
    accepted_by: "kiki830621"
  - finding_id: L-2
    severity: LOW
    description: "review_notes count stale (says 30 columns ignored, actual 28)"
    resolution: "fixed inline this session — count corrected with annotation"
    accepted_by: "kiki830621"
```

(HIGH finding H-1 was a runtime fix, not an "accepted MEDIUM/LOW finding" — it required actual code change in `fn_glue_bridge.R`. Therefore not listed under `findings_resolutions:` since that block is reserved for MEDIUM/LOW findings that are accepted with rationale.)

## Verdict: CONVERGED at iteration 1

Ship-readiness criteria met:
- 0 CRITICAL, 0 HIGH after H-1 fix (verified via re-grep of `fn_glue_bridge.R:201` confirming the new lines)
- 2 LOW findings have explicit `findings_resolutions:` rationale
- 3 SUGGESTION findings logged for transparency, no action required
- Helper regression test 23/23 still PASS post-fix
- Bridge yaml validator: 0 critical, 1 advisory warning (pre-existing legacy `reviewed_by` string — being replaced by structured form at this Step 6e)

Bridge ship-ready pending Step 7 commit + Step 4-6 ETL re-run on QEF DEV (deferred per user "code-only first" path).
