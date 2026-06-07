# fix-glue-layer-infra-blockers — Legacy Bridge Audit Report

> **Spectra change**: `fix-glue-layer-infra-blockers` Task 1.3 (Section 1)
> **Date**: 2026-05-12
> **Author**: Claude (autonomous /spectra-apply)
> **Source**: `shared/global_scripts/01_db/raw_schema/_authoring/bridges/QEF_DESIGN/amz/*.bridge.yaml` on `main` branch

## Per-bridge inventory

| Bridge | Shape | # extractors | value_map count | unique coercion strings | unsupported coercion ops | src reachable |
|---|---|---:|---:|---:|---:|---|
| company_product_extension | legacy | 20 | 0 | 2 | 0 | NO |
| product_attributes_blb | legacy | 95 | 15 | 0 | 0 | NO |
| product_attributes_bys | legacy | 93 | 11 | 0 | 0 | NO |
| product_attributes_cas | legacy | 95 | 12 | 0 | 0 | NO |
| product_attributes_hsg | legacy | 74 | 10 | 0 | 0 | NO |
| product_attributes_its | legacy | 86 | 14 | 0 | 0 | NO |
| product_attributes_psg | legacy | 81 | 3 | 0 | 0 | NO |
| product_attributes_rpl | legacy | 53 | 7 | 0 | 0 | NO |
| product_attributes_sfg | legacy | 91 | 91 | 0 | 0 | NO |
| product_attributes_sfo | legacy | 80 | 80 | 0 | 0 | NO |
| product_attributes_sgf | legacy | 117 | 108 | 0 | 0 | NO |
| product_attributes_sgo | legacy | 104 | 11 | 0 | 0 | NO |
| product_attributes_sss | legacy | 83 | 13 | 0 | 0 | NO |
| sales | legacy | 22 | 1 | 8 | 1 | YES |

## Findings

### All 14 bridges are in legacy `column_mapping` shape on `main`

P2 spectra change `glue-bridge-schema-driven-redesign` produced `.bridge.v2.yaml` sibling files but the in-place swap never landed on `main`. Pilot session `idd/amz-sales-pilot-execution` did swap `sales.bridge.yaml` to v2 form (with manual value_map restore + 4 new extractors + pre_filter), but this is only on that branch — not yet merged to `main`.

**Implication**: This change must apply the fixed migration tool to ALL 14 legacy bridges to produce v2 forms with value_map preserved.

### 13 of 14 bridges have value_map fields

Only `company_product_extension` has 0 value_maps. The 13 others have value_map counts ranging from 1 (sales) to 108 (product_attributes_sgf). The migration tool whitelist fix is critical for all 13.

### 1 unsupported coercion op found (out of 10 unique coercion strings)

| Bridge | Extractor | Coercion | Whitelist status |
|---|---|---|---|
| sales | order_date | `format(., '%Y-%m-%d') from POSIXct` | NOT in whitelist |

All other coercion strings use only whitelisted ops: `trimws / tolower / as.character / as.integer / as.numeric / as.logical / toupper`. After fix-glue-layer-infra-blockers apply, the sales `order_date` extractor will emit a runtime WARNING and the format expression will be skipped (per spec scenario "Interpreter encounters unsupported coercion op"). The fallback is canonical-type-only coercion (VARCHAR → trimws + as.character). Author should refactor `order_date` to a `type: derive` extractor with explicit `format()` call as a follow-up.

### 13 of 14 source URIs are unreachable from this environment

Only `sales` has source at `data/local_data/rawdata_QEF_DESIGN/amazon_sales/` (the 26 xlsx files from pilot work). The other 13 reference paths not present in this checkout.

**Implication per design Risk 1 mitigation**: The fingerprint regen helper SHALL skip unreachable bridges with WARN + file follow-up issue. Re-migrate (from git history) still works because migration tool reads source yaml not source data. Only fingerprint regen step needs source.

## Next steps in this change

- Section 2: SKILL.md update + helper script(`regen_bridge_fingerprints.R`)
- Section 4: Migration tool whitelist patch (preserves value_map for 13 bridges)
- Section 5: `apply_coercion_pipeline()` helper (executes 7 whitelist ops, warns on `format(., ...)` etc)
- Section 6: 2 test files
- Section 7: Re-migrate all 14 bridges, regen fingerprint for 1 reachable (sales), file follow-up issue for 13 unreachable
- Section 7 also: 3 validator advisory checks
- Section 8: Runtime verify(only sales has actual source data → full end-to-end; other 13 verify via migration-output round-trip)
- Section 9: IC_P002 cross-co
- Section 10: Atomic commit + close #628 / #630 / #631 + signal #627 unblock

## Cross-references

- Spectra change: `openspec/changes/fix-glue-layer-infra-blockers/`
- Bug issues: #628 (fingerprint method) / #630 (migration tool value_map) / #631 (coerce_field coercion)
- Blocked pilot: #627 (amz-sales-pilot-execution)
