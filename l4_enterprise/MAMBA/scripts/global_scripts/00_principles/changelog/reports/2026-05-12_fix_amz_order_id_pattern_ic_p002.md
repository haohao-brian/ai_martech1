# fix-amz-order-id-pattern-permissiveness — IC_P002 Cross-Company Dry-Run

> **Spectra change**: `fix-amz-order-id-pattern-permissiveness` Section 6
> **Date**: 2026-05-12
> **Author**: Claude (autonomous /spectra-apply)
> **Decision basis**: design **Decision 4: 對 5 公司 IC_P002 用 paper exercise + actual data verify(QEF)** + **AC-7**

## Scope summary

This change is a **two-axis fix**:
1. **Layer 1 schema (the #632 root issue)**: `amz_extensions.yaml` amz_amazon_order_id pattern relaxed from `^[0-9]{3}-` to `^[A-Z0-9]{3}-` to accept Seller-Fulfilled IDs
2. **Runtime translator (#634 surfaced during apply)**: `fn_glue_bridge.R` inline translator extended to preserve value_map + 5 extension fields (sister bug to #630 in different location)

Both fixes ship as atomic cutover commit. IC_P002 verifies both axes across 5 companies.

## Per-Company Verification

### QEF_DESIGN — actual runtime verification

| Test surface | Result | Detail |
|---|---|---|
| amz_extensions.yaml pattern updated | ✓ PASS | grep `pattern.*A-Z0-9.*\[0-9\]{7}` returns expected line |
| description + description_zh updated with S01 example | ✓ PASS | grep S01 in both description fields |
| `_build.R` codegen produces DDL with new CHECK regex | ✓ PASS | `_generated/platforms/amz/sales.sql` CHECK updated to `^[A-Z0-9]{3}-[0-9]{7}-[0-9]{7}$` |
| Pattern validation against 294,526-row dataset | ✓ PASS | 402 newly accepted (S01), 0 false positives, 294,124 preserved FBA |
| #634 fix — runtime translator preserves value_map | ✓ PASS | amz_fulfillment_channel = AFN (was AMAZON) — value_map lookup working |
| amz-sales end-to-end INSERT | ✓ PASS | 281,919 rows inserted (within 0.05% of baseline 281,784); 392 S01 rows successfully INSERTed |
| 0 CHECK violations | ✓ PASS | No "Constraint Error: CHECK constraint failed" in run output |
| 0 NOT NULL violations | ✓ PASS | No "Constraint Error: NOT NULL constraint failed" |

**Verdict**: PASS. amz-sales bridge runtime end-to-end functional with both #632 + #634 fixes.

### D_RACING

| Test surface | Result | Detail |
|---|---|---|
| Legacy R script ETL (pre-glue) | ✓ NO REGRESSION | Change only touches amz_extensions.yaml + fn_glue_bridge.R; D_RACING uses neither (no amz bridges yet) |
| Future Amazon onboarding | ✓ COMPATIBLE | When D_RACING adds amz/sales bridge, new pattern accepts all production-observed FBA + Seller-Fulfilled IDs automatically; runtime translator preserves value_map |

**Verdict**: PASS.

### MAMBA

| Test surface | Result | Detail |
|---|---|---|
| Company-suffix legacy R scripts | ✓ NO REGRESSION | Same — unaffected |
| Future MAMBA amz bridges | ✓ COMPATIBLE | Same benefit as D_RACING |

**Verdict**: PASS.

### WISER

| Test surface | Result | Detail |
|---|---|---|
| Template platform behavior | ✓ NO REGRESSION | amz_extensions.yaml propagates via shared/global_scripts symlink; WISER inherits same canonical schema |
| Future WISER amz bridges | ✓ COMPATIBLE | Pattern + runtime fixes available out of box |

**Verdict**: PASS.

### kitchenMAMA

| Test surface | Result | Detail |
|---|---|---|
| Active legacy chains | ✓ NO REGRESSION | KM uses cbz/eby — not affected by amz schema change |
| Future kitchenMAMA amz bridges | ✓ COMPATIBLE | Same |

**Verdict**: PASS.

## Cross-Company Conflict Analysis

| Conflict scenario | Found? | Resolution |
|---|---|---|
| Pattern relaxation accepts invalid values | NO | New pattern `[A-Z0-9]{3}-[0-9]{7}-[0-9]{7}` is strict superset of old. 0 false positives in 294,526-row dataset |
| Pattern relaxation breaks downstream consumer expecting old format | NO | All canonical schema CHECK constraints + DRV scripts treat amz_amazon_order_id as opaque string; format introspection only via regex pattern in DDL itself |
| #634 fix unintentionally exposes other extension fields | NO | Whitelist limited to 6 documented fields (value_map + 5 others). Other entry fields not in whitelist still dropped (same as before) |
| 5 公司 share fix automatically via symlink | YES — INTENDED | Universal infra fix propagates via shared/global_scripts symlink. Future amz bridge onboarding by any company benefits without per-company work |

## Verdict

✅ **fix-amz-order-id-pattern-permissiveness IC_P002 cross-co dry-run PASSES across 5 consuming companies.**

amz-sales pilot (#627) now FULLY unblocked end-to-end:
- 3 infra bugs (#628 / #630 / #631) fixed in fix-glue-layer-infra-blockers
- Schema permissiveness (#632) fixed in this change
- Runtime translator value_map preservation (#634) fixed inline in this change

Pilot can resume from Section 3+ in next session.

**Commit trailer format**: `Verified: QEF_DESIGN, D_RACING, MAMBA, WISER, kitchenMAMA`

## Out-of-scope (this dry-run)

- Per-datatype bridge migrations for cbz/eby/other amz datatypes — separate per-datatype follow-up changes per `legacy-etl-deprecation-playbook` spec

## Cross-references

- **Pattern validation**: `2026-05-12_fix_amz_order_id_pattern_validation.md`
- **Source change**: `openspec/changes/fix-amz-order-id-pattern-permissiveness/`
- **Closes**: #632 (Layer 1 schema CHECK pattern) + #634 (runtime translator value_map preservation)
- **Sister fix**: #628 / #630 / #631 (closed in fix-glue-layer-infra-blockers)
- **Unblocks**: #627 amz-sales-pilot-execution end-to-end
