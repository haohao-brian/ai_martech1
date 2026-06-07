# CHANGELOG: SO_P016 Configuration Scope Hierarchy

**Date**: 2025-12-15
**Author**: Claude
**Category**: Architecture Refactoring (Phase 7)
**Principles**: SO_P016 (NEW), SO_P010, MP137, MP122

---

## Summary

Fixed critical architecture issue where **ProductLine vs Company** concepts were confused. Company-specific settings (`enabled`, `sheet_id`) were incorrectly placed in `global_scripts/03_config/metadata_sources.yaml`, which is distributed via git subrepo to ALL companies.

## Problem Statement

### Original Architecture (Incorrect)

```
global_scripts/03_config/metadata_sources.yaml
├── turbo:
│   ├── enabled: true       # Company-specific!
│   ├── sheet_id: "1DAD..." # Company-specific!
│   └── target_table: ...   # Schema (OK)
```

**Issue**: When `global_scripts/` is synchronized to other companies (WISER, kitchenMAMA, etc.) via git subrepo, these company-specific settings would override their configurations.

### Three-Tier Hierarchy

| Level | Scope | Location | Content Type |
|-------|-------|----------|--------------|
| Universal | All companies | `global_scripts/03_config/` | Schema definitions only |
| Company | Single company | `{company}/app_config.yaml` | enabled, sheet_id, credentials |
| Application | Single app | `{company}/{app}/app_config.yaml` | UI preferences, display settings |

## Solution Implemented

### 1. Refactored `metadata_sources.yaml` (Schema Only)

**Location**: `scripts/global_scripts/03_config/metadata_sources.yaml`

Now contains ONLY schema definitions:
- `target_scope` - where data goes (company vs universal)
- `target_database` - database name
- `target_db_file` - database filename
- `target_table` - table name
- `columns` - expected column list

**Removed**:
- `enabled` flags
- `sheet_id` values
- `sheet_name` values

### 2. Added Company Settings to `app_config.yaml`

**Location**: `app_config.yaml` (MAMBA root)

```yaml
metadata_sources:
  turbo:
    enabled: true
    sheet_id: "1DADOOtwUuWqB3azFPmTcFSDunyACx_RsNpKlGoL2ta4"
    sheet_name: "metadata_Turbo"
  cbz:
    enabled: false
    sheet_id: ""
    sheet_name: ""
  # ... other platforms
```

### 3. Updated ETL Script with Configuration Merging

**Location**: `scripts/update_scripts/ETL/all/all_ETL_metadata_0IM.R`

New logic:
1. Load company settings from `app_config.yaml`
2. Load schema definitions from `global_scripts/03_config/metadata_sources.yaml`
3. Merge using `modifyList(global_schema, company_settings)`
4. Process only `enabled: true` sources

### 4. Created New Principle SO_P016

**Location**: `scripts/global_scripts/00_principles/docs/en/part1_principles/CH01_structure_organization/principles/SO_P016_configuration_scope_hierarchy.qmd`

**Rule**: Content that varies between companies MUST NOT be placed in `global_scripts/`.

## Files Modified

| File | Action | Purpose |
|------|--------|---------|
| `global_scripts/03_config/metadata_sources.yaml` | REWRITTEN | Schema only, no company settings |
| `app_config.yaml` | EDITED | Added `metadata_sources:` section |
| `scripts/update_scripts/ETL/all/all_ETL_metadata_0IM.R` | REWRITTEN | Config merging pattern |
| `SO_P016_configuration_scope_hierarchy.qmd` | CREATED | New principle |
| `INDEX.md` | UPDATED | Added SO_P016 |
| `QUICK_REFERENCE.md` | UPDATED | Added SO_P016 |

## Verification

Expected behavior after changes:
- `turbo`: Processed (80 rows) - enabled in app_config.yaml
- `cbz`, `eby`, `amz`, `common`: SKIPPED - disabled in app_config.yaml

## Impact on Other Companies

When other companies receive updated `global_scripts/`:
1. They will get schema-only `metadata_sources.yaml`
2. They must add their own `metadata_sources:` section to `app_config.yaml`
3. Each company controls their own enabled flags independently

## Related Principles

| Principle | Relationship |
|-----------|-------------|
| **SO_P010** | Config-Driven Customization - parent principle |
| **SO_P015** | No Hardcoded Lookup Tables - sibling principle |
| **MP137** | No Hardcoded Project-Specific Content - umbrella principle |
| **MP122** | Dual-Track Subrepo Architecture - git subrepo pattern |
| **DM_R004** | Data Storage Organization - three-tier architecture |

---

## Migration Guide for Other Companies

If you receive this update via git subrepo, add the following to your `app_config.yaml`:

```yaml
# Metadata Sources - Company-specific settings (SO_P016)
metadata_sources:
  turbo:
    enabled: [true/false]
    sheet_id: "[your sheet ID]"
    sheet_name: "[your sheet name]"
  # Repeat for each platform you use
```

Then run:
```bash
Rscript scripts/update_scripts/ETL/all/all_ETL_metadata_0IM.R
```
