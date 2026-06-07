# P3 Tier A Archive — Pre-archive Review Report

> **Spectra change**: `legacy-etl-aggressive-deprecation` Tasks 2.1 + 2.2
> **Date**: 2026-05-11
> **Author**: Claude (autonomous /spectra-apply)

## Task 2.1 — Pre-archive grep verification

Per **Risk 2: Tier A archive 撞到 lost dependency** mitigation, verified 0 external references for all 6 Tier A file stems:

| File stem | External refs in update_scripts/ETL/* | Refs in shared/global_scripts/16_derivations/ |
|---|---|---|
| `amz_ETL_company_product_master` | 0 | 0 |
| `amz_ETL_demographic` | 0 | 0 |
| `amz_ETL_keepa` | 0 | 0 |
| `amz_ETL_keys` | 0 | 0 |
| `amz_ETL_sku_mapping` | 0 | 0 |
| `amz_ETL_competitor_sales` | 0 | 0 |

All 6 file stems safe for mechanical archive (no `source()` chains or DRV consumer references found).

## Task 2.2 — Useful-code review per file

Per **Risk 6: Tier A files 內含 useful code 被永久 archive** mitigation, inspected each file for unique parse logic / API parsing that should be extracted before archive.

| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `amz_ETL_company_product_master_0IM.R` | 230 | direct-archive | Standard xlsx import + dbWriteTable; no unique parse logic |
| `amz_ETL_company_product_master_1ST.R` | 119 | direct-archive | Standard structural staging; no unique logic |
| `amz_ETL_company_product_master_2TR.R` | 134 | direct-archive | Standard schema mapping; superseded by Layer 1 canonical declarations per MP064 v2.2 |
| `amz_ETL_demographic_0IM.R` | 186 | direct-archive | Standard import; truncated chain (no 1ST/2TR); no unique parse logic |
| `amz_ETL_keepa_0IM.R` | 193 | direct-archive | Standard Keepa API consumption via existing utilities; truncated chain |
| `amz_ETL_keys_0IM.R` | 387 | direct-archive | Largest file but follows standard pattern — Excel/CSV imports + dbWriteTable; truncated chain |
| `amz_ETL_sku_mapping_0IM.R` | 175 | direct-archive | Standard SKU mapping import; truncated chain |
| `amz_ETL_competitor_sales_0IM.R` | 215 | direct-archive | Standard competitor data import; truncated chain |

All 6 file stems (8 files total) classified as **direct-archive** — no extraction-then-archive needed.

Note: per **MP030 Archive Immutability**, files moved to `99_archived/legacy_etl_pre_glue/` remain accessible and can be referenced as historical patterns if needed for future onboarding. The `archived/` directory hook (per `archived-protection` rule in CLAUDE.md) prevents accidental deletion.

## Cross-references

- **Spectra change**: `openspec/changes/legacy-etl-aggressive-deprecation/`
- **Master plan**: `openspec/specs/etl-architecture-roadmap/spec.md` Requirement 2 P3 scope
- **#613**: cross-platform legacy ETL orphan audit (sourced Tier A categorization)
- **MP030**: Archive Immutability
