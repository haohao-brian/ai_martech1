# Bridge ensemble review: QEF_DESIGN/amz/product_attributes_rpl.bridge.yaml

**Bridge yaml**: `01_db/raw_schema/_authoring/bridges/QEF_DESIGN/amz/product_attributes_rpl.bridge.yaml`
**Spectra context**: qef-batch-bridges-ensemble-2026-05-05 (4-bridge batch per #543 / #569)
**Review mode**: glue-ensemble-v1-batch (3-AI; security skipped per config-edit scoping)
**Started**: 2026-05-05T13:00:00Z

## Scope

rpl bridge: 57 source columns, 15 rows. Smallest CSV in the batch — small-sample blind spot risk for value_map completeness (DA-NEW 2.4).

## Pre-flight refingerprint

rpl refingerprinted with canonical helper produces hash `063b1ceb4a5cd8ab...` against current CSV.

## Iteration 1 — 2026-05-05T13:00:00Z

**Reviewers**: codex-cli + claude-correctness + claude-devils-advocate

**Findings**: 5 (0 CRITICAL / 0 HIGH / 1 MEDIUM / 3 LOW / 1 SUGGESTION)

| ID | Severity | Source | Description |
|---|---|---|---|
| M-1 | MEDIUM | structural | reviewed_by placeholder REQUIRES_HUMAN_REVIEW |
| L-1 | LOW | DA-downgraded | country_of_origin mojibake `'â‎China'` (1 row of 15; correctness HIGH downgraded by DA per cross-bridge isolation analysis) |
| L-2 | LOW | DA cross-bridge | Small sample (15 rows) — value_map may miss rare sentinels |
| L-3 | LOW | systemic | BOM-prefix first column header |
| S-1 | SUGGESTION | DA cross-bridge | rpl missing `url` and `is_benchmark_product` cols — verified intentional per schema |

## Cross-bridge note (DA)

DA verified mojibake is **isolated to rpl** (hex dump analysis: `b'\xc3\xa2\xc2\x80\xc2\x8eChina'` = U+200E LRM double-encoded UTF-8 → CP1252 → UTF-8). Not a generator bug; localized Gsheet copy-paste corruption in 1 of 15 rows.

DA also REJECTED correctness's HIGH systemic boolean concern as false positive (verified `fn_apply_mapping.R:175-179` runtime path).

## Resolutions applied

All 5 findings resolved inline in bridge yaml `findings_resolutions:` block. M-1 fixed by Step 6e replacement. L-1 (mojibake) accepted with follow-up to clean source row at next Gsheet audit.

## Verdict: CONVERGED at iteration 1

Bridge ship-ready. Note: 1 row will continue to surface as `'â‎China'` until Gsheet audit cleans the source — this is acceptable per MP163 progressive completeness (visible gap, not silent failure). Customer-facing impact: country_of_origin filter on dashboard will show one outlier value; cleaned at next Gsheet refresh.
