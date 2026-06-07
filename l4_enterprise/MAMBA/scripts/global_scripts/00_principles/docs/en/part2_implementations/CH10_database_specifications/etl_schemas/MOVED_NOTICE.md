# MOVED — ETL Schema Authoring Source-of-Truth

**Relocation date**: 2026-04-27
**Spectra change**: `glue-layer-prerawdata-bridge` (#489)
**Trigger**: amended MP102 + MP156 (Two-Tier Normativity) binding mechanism

## What moved

The ETL schema authoring source-of-truth has relocated from this `etl_schemas/` directory to the canonical authoring location under `01_db/`:

| File / sub-directory | New canonical path |
|---|---|
| `core_schemas.yaml` | `shared/global_scripts/01_db/raw_schema/_authoring/core_schemas.yaml` |
| `schema_registry.yaml` | `shared/global_scripts/01_db/raw_schema/_authoring/schema_registry.yaml` |
| `transformed_schemas.yaml` | `shared/global_scripts/01_db/raw_schema/_authoring/transformed_schemas.yaml` |
| `IMPLEMENTATION_GUIDE.md` | `shared/global_scripts/01_db/raw_schema/_authoring/IMPLEMENTATION_GUIDE.md` |
| `platform_extensions/{cbz,eby}_extensions.yaml` | `shared/global_scripts/01_db/raw_schema/_authoring/platform_extensions/` |
| `r_definitions/SCHEMA_*.R` + helpers | `shared/global_scripts/01_db/raw_schema/_authoring/r_definitions/` |
| `r_definitions/test_*.R` | `shared/global_scripts/98_test/etl/` (tests belong with other 98_test files) |

## Why moved

The schema authoring files previously lived under `00_principles/docs/.../etl_schemas/`. Per amended MP102 (after MP156 Two-Tier Normativity formalization), production code needs a natural import path for these spec files; `docs/` paths are for human-readable principle docs and do not get imported by `update_scripts/ETL/`. The new location `01_db/raw_schema/_authoring/` lives in the same chapter as `fn_generate_create_table_query.R` (the codegen tool) and is reachable from production code without `docs/` indirection.

See:

- Amended **MP102**: `shared/global_scripts/00_principles/docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP102_etl_output_standardization.qmd`
- New **MP156** (Two-Tier Normativity): `shared/global_scripts/00_principles/docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP156_two_tier_normativity.qmd`
- Spectra change: `openspec/changes/glue-layer-prerawdata-bridge/`

## Will this directory be removed?

The `etl_schemas/` directory may be removed in a future cleanup change once all internal references and external consumers (Quarto build, tools, scripts) have been verified to point exclusively to the new location. This `MOVED_NOTICE.md` will remain as long as the empty parent directory remains, to avoid silent broken references.

If you arrived here via a stale link or stale documentation, please update the source to reference `01_db/raw_schema/_authoring/`.
