# CHANGELOG: MP137 & SO_P015 - No Hardcoded Content Principles

**Date**: 2025-12-14
**Author**: Claude
**Type**: Principle Addition + Implementation

---

## Summary

Added new principles to prohibit hardcoded project-specific content, establishing
a formal architecture for configuration-driven development and database-backed
lookup tables.

---

## New Principles

### MP137: No Hardcoded Project-Specific Content

**Location**: `docs/en/part1_principles/CH00_fundamental_principles/03_development_methodology/MP137_no_hardcoded_project_specific_content.qmd`

**Core Statement**:
> Any content that varies between projects, companies, or product lines MUST be
> externalized to configuration files or databases. Hardcoding such content in
> source code is PROHIBITED.

**Scope**:
- Company branding and UI text
- Business logic parameters and thresholds
- Lookup tables and mappings
- Translation/localization data
- Feature flags and toggles
- API endpoints and credentials

**Philosophy**: Code should be **universal**. Data should be **specific**.

### SO_P015: No Hardcoded Lookup Tables

**Location**: `docs/en/part1_principles/CH01_structure_organization/principles/SO_P015_no_hardcoded_lookup_tables.qmd`

**Derives from**: MP137

**Core Statement**:
> All lookup tables, mapping tables, and translation dictionaries MUST be stored
> in databases (populated via ETL from external sources) or configuration files.
> Defining such mappings directly in source code is PROHIBITED.

**Prohibited Patterns**:
```r
# PROHIBITED
weekday_map <- list(
  monday = list(zh = "星期一", en = "Monday"),
  ...
)

# PROHIBITED
turbo_compressor_map <- list(
  high_flow = list(zh = "高流量設計", en = "High-flow"),
  ...
)
```

**Correct Pattern**:
```r
# CORRECT: Read from database
db_result <- tbl2(con, "df_metadata_turbo") %>%
  filter(predictor_pattern == !!predictor) %>%
  collect()
```

---

## Updates to Existing Principles

### SO_P010: Config-Driven Customization

**Change**: Added `derives_from: "CH00.MP137: No Hardcoded Project-Specific Content"`

This establishes SO_P010 as a child principle of MP137, focusing specifically
on company-specific content (branding, UI, business rules).

---

## Implementation Files

### New Configuration File

**File**: `global_scripts/03_config/metadata_sources.yaml`

Defines external sources for metadata lookup tables:
```yaml
metadata_turbo:
  sheet_id: "1DADOOtwUuWqB3azFPmTcFSDunyACx_RsNpKlGoL2ta4"
  sheet_name: "metadata_Turbo"
  target_table: "df_metadata_turbo"
```

### New ETL Script

**File**: `update_scripts/ETL/all/all_ETL_metadata_turbo_0IM.R`

Imports turbocharger product attribute metadata from Google Sheets to DuckDB.
- Reads configuration from `metadata_sources.yaml` (not hardcoded)
- Fetches data from Google Sheets
- Writes to `df_metadata_turbo` table

### Modified Function

**File**: `global_scripts/04_utils/fn_generate_display_name.R`

**Version**: 3.0 (2025-12-14)

**Changes**:
1. Added database-first lookup pattern at function start
2. Queries `df_metadata_turbo` before falling back to rule-based logic
3. Marked existing hardcoded mappings as DEPRECATED
4. Added migration notes referencing SO_P015

**Architecture** (MP137 Compliance):
1. Database lookup FIRST (df_metadata_turbo, df_metadata_common)
2. Rule-based fallback (DEPRECATED - to be migrated in Phase 2)
3. AI translation fallback (if enabled)
4. Technical name formatting

---

## Migration Plan

### Phase 1 (This Release)
- [x] Create MP137 principle
- [x] Create SO_P015 principle
- [x] Update SO_P010 to derive from MP137
- [x] Create metadata_sources.yaml configuration
- [x] Create ETL for metadata_Turbo
- [x] Add DB-first lookup to fn_generate_display_name.R

### Phase 2 (Future)
- [ ] Create `df_metadata_common` table for universal mappings (time, colors, etc.)
- [ ] Migrate existing hardcoded mappings to df_metadata_common
- [ ] Add ETL for metadata_common from Google Sheets

### Phase 3 (Future)
- [ ] Remove all hardcoded fallback mappings from fn_generate_display_name.R
- [ ] Function becomes pure database query + AI fallback
- [ ] Full MP137/SO_P015 compliance achieved

---

## Data Flow

```
config/metadata_sources.yaml (configuration source)
    │
    ▼
Google Sheets (metadata_Turbo worksheet)
    │
    ▼ [all_ETL_metadata_turbo_0IM.R]
df_metadata_turbo (DuckDB table)
    │
    ▼ [fn_generate_display_name.R - DB query]
Application (display_name_en, display_name_zh)
    │
    ▼
UI Display
```

---

## Principle Relationships

```
MP137: No Hardcoded Project-Specific Content (UMBRELLA)
├── SO_P010: Config-Driven Customization (company-specific)
├── SO_P015: No Hardcoded Lookup Tables (mapping tables)
├── MP098: Generality Over Specificity (related)
└── SEC_R001: No Hardcoded Credentials (related)
```

---

## Index Updates

- **QUICK_REFERENCE.md**: Updated counts, added MP137, SO_P015, new family section
- **INDEX.md**: Added recent changes section for new principles

---

## Testing

After running the ETL:

```r
# Connect to database
con <- dbConnectDuckdb(db_path_list$app_data)

# Test metadata_Turbo query
fn_generate_display_name("high_flow", locale = "zh_TW", cache_con = con)
# Expected: list(display_name = "高流量設計", translation_method = "database_metadata", ...)

fn_generate_display_name("blade_count", locale = "en", cache_con = con)
# Expected: list(display_name = "Blade Count", translation_method = "database_metadata", ...)
```

---

## Rationale

| Benefit | Explanation |
|---------|-------------|
| **Reusability** | Same codebase serves multiple projects/clients |
| **Maintainability** | Content changes don't require code deployment |
| **Testability** | Easy to test with different configurations |
| **Scalability** | New projects onboard without code changes |
| **Separation of Concerns** | Code handles logic; config/DB provides context |
| **Domain Expert Access** | Non-developers can modify mappings via Google Sheets |

---

## Phase 4 Update: 30_global_data vs app_data Architecture (2025-12-14)

### Problem Identified

The original implementation wrote `df_metadata_turbo` to `app_data/app_data.duckdb`, but:
- Metadata lookup tables are **cross-application shared resources**
- Per DM_R004, they should be in `global_scripts/30_global_data/`
- The existing DM_R004 only defined `app_data/` structure, not X_global_data/`

### Solution: DM_R004 Section 6

Added **Section 6: Global Data Storage** to DM_R004, defining:

| Type | Location | Purpose | Change Frequency |
|------|----------|---------|------------------|
| **Global Data** | `global_scripts/30_global_data/` | Cross-application shared data | Low (SCD Type 0/1) |
| **Application Data** | `{app}/data/app_data/` | Single application data | High (frequently updated) |

### Files Modified in Phase 4

| File | Change |
|------|--------|
| `DM_R004_data_storage_organization.qmd` | Added Section 6: Global Data Storage |
| `03_config/metadata_sources.yaml` | Added `target_database: "30_global_data"`, `target_db_file: "global_scd_type1.duckdb"` |
| `ETL/all/all_ETL_metadata_turbo_0IM.R` | Changed to write to X_global_data/global_scd_type1.duckdb` |
| `fn_generate_display_name.R` v3.1 | Added `global_con` parameter for dual connection pattern |

### Dual Connection Pattern (DM_R004 Section 6)

Functions that need both global and application data now accept two connection parameters:

```r
fn_generate_display_name <- function(
  predictor,
  locale = "zh_TW",
  use_ai = FALSE,
  global_con = NULL,   # 30_global_data connection (metadata lookup)
  cache_con = NULL     # app_data connection (AI caching)
) {
  # ...
}
```

### Updated Data Flow

```
config/metadata_sources.yaml
    │
    ▼
Google Sheets (metadata_Turbo)
    │
    ▼ [all_ETL_metadata_turbo_0IM.R]
global_scripts/30_global_data/global_scd_type1.duckdb
    │   └── df_metadata_turbo
    │
    ▼ [fn_generate_display_name.R v3.1]
    │   (uses global_con for metadata lookup)
    │
Application (display_name_en, display_name_zh)
    │
    ▼
UI Display
```

### Testing After Phase 4

```r
# 1. Connect to global database
global_con <- DBI::dbConnect(duckdb::duckdb(),
  file.path(g_global_scripts_path, "30_global_data", "global_scd_type1.duckdb"))

# 2. Verify metadata table exists
DBI::dbListTables(global_con)  # Should include "df_metadata_turbo"

# 3. Test fn_generate_display_name with global_con
result <- fn_generate_display_name(
  "high_flow",
  locale = "zh_TW",
  global_con = global_con
)
# Expected: list(display_name = "高流量設計", translation_method = "database_metadata", ...)

DBI::dbDisconnect(global_con)
```

---

## Phase 5 Update: Three-Tier Data Architecture Correction (2025-12-14)

### Problem Identified

User feedback revealed a critical architectural error in Phase 4:

> "應用共用資源是所有 company 共用的，但是 turbo 是 MAMBA 的，你可能要考慮怎麼修正"

**Translation**: "Shared resources are for ALL companies, but turbo is MAMBA's. You need to consider how to fix this."

**Core Issue**:
- `global_scripts/` is distributed via git subrepo to **ALL companies** (VitalSigns, BrandEdge, InsightForge, MAMBA, etc.)
- `global_scripts/30_global_data/` contains data shared by **ALL companies**
- `df_metadata_turbo` is **MAMBA-specific** (turbocharger product attributes)
- Placing MAMBA-specific data in X_global_data/` would **pollute other companies' environments**

### Solution: Three-Tier Data Architecture

Phase 4's two-tier model (30_global_data vs app_data) was **incorrect**. The correct architecture is **three-tier**:

| Tier | Location | Scope | Examples |
|------|----------|-------|----------|
| **Universal** | `global_scripts/30_global_data/` | ALL companies share | df_metadata_common (time, colors) |
| **Company** | `{company}/data/app_data/` | Single company (cross-app) | df_metadata_turbo (MAMBA only) |
| **Application** | `{company}/data/app_data/` | Single application | df_analysis_results |

### Files Modified in Phase 5

| File | Change |
|------|--------|
| `DM_R004_data_storage_organization.qmd` | **Rewrote Section 6** to three-tier architecture with decision tree |
| `MP137_no_hardcoded_project_specific_content.qmd` | Added three-tier data architecture section with critical warning |
| `03_config/metadata_sources.yaml` | Added `target_scope: "company"`, changed back to `target_database: "app_data"` |
| `ETL/all/all_ETL_metadata_turbo_0IM.R` | Changed to write to `{company}/data/app_data/app_data.duckdb` |
| `fn_generate_display_name.R` v3.2 | Reordered lookup: cache_con (company) FIRST, then global_con (universal) |

### Critical Rule Added

```
NEVER place company-specific data in `global_scripts/30_global_data/`.

global_scripts/ is distributed via git subrepo to ALL companies.
Placing MAMBA-specific data (like df_metadata_turbo) inX_global_data/ would:
1. Pollute other companies' environments
2. Create unnecessary dependencies
3. Violate separation of concerns
```

### Corrected Data Flow

```
config/metadata_sources.yaml
    │   (target_scope: "company")
    │
    ▼
Google Sheets (metadata_Turbo)
    │
    ▼ [all_ETL_metadata_turbo_0IM.R]
{company}/data/app_data/app_data.duckdb    ← COMPANY tier (MAMBA only)
    │   └── df_metadata_turbo
    │
    ▼ [fn_generate_display_name.R v3.2]
    │   (uses cache_con for company metadata lookup)
    │
Application (display_name_en, display_name_zh)
    │
    ▼
UI Display
```

### Connection Pattern Update

**Phase 4 (INCORRECT)**:
- `global_con` = 30_global_data connection (metadata lookup) - PRIMARY
- `cache_con` = app_data connection (AI caching only)

**Phase 5 (CORRECT)**:
- `cache_con` = app_data connection (company metadata + AI caching) - **PRIMARY**
- `global_con` = 30_global_data connection (universal metadata) - **OPTIONAL**

```r
fn_generate_display_name <- function(
  predictor,
  locale = "zh_TW",
  use_ai = FALSE,
  global_con = NULL,   # OPTIONAL: for df_metadata_common (universal)
  cache_con = NULL     # PRIMARY: for df_metadata_turbo (company) + AI cache
) {
  # PRIORITY 1: Company database lookup (cache_con -> df_metadata_turbo)
  # PRIORITY 2: Universal database lookup (global_con -> df_metadata_common)
  # PRIORITY 3-5: Rule-based fallback, AI translation, Technical name
}
```

### Testing After Phase 5

```r
# Connect to COMPANY database (app_data)
app_con <- DBI::dbConnect(duckdb::duckdb(),
  file.path(g_project_root, "data", "app_data", "app_data.duckdb"))

# Verify metadata table exists
DBI::dbListTables(app_con)  # Should include "df_metadata_turbo"

# Test fn_generate_display_name with cache_con
result <- fn_generate_display_name(
  "high_flow",
  locale = "zh_TW",
  cache_con = app_con  # PRIMARY connection for company metadata
)
# Expected: list(display_name = "高流量設計", translation_method = "database_metadata", ...)

DBI::dbDisconnect(app_con)
```

### Lessons Learned

1. **"Cross-application" ≠ "Cross-company"**: Phase 4 confused these concepts
2. **Git subrepo distribution**: Always consider what `global_scripts/` contains when distributed
3. **User feedback is critical**: Domain knowledge about deployment architecture caught the error
4. **Three-tier > Two-tier**: Universal/Company/Application provides clearer separation

---

## Phase 6 Update: Universal ETL Framework + future.mirai Fix (2025-12-14)

### Problem 1: autoinit() Compilation Failure

When running `all_ETL_metadata_turbo_0IM.R`, encountered `nanonext` compilation failure:

```
tls.c:164:63: error: use of undeclared identifier 'mbedtls_pk_type_t'
ERROR: compilation failed for package 'nanonext'
ERROR: dependency 'nanonext' is not available for package 'mirai'
ERROR: dependency 'mirai' is not available for package 'future.mirai'
```

**Root Cause**: `fn_initialize_packages.R` included `future.mirai` in `core_packages`, which depends on `mirai` → `nanonext`. The `nanonext` package is incompatible with mbedtls 4.x on macOS.

**Solution**: Removed `future.mirai` from `core_packages` in `fn_initialize_packages.R`:

```r
core_packages <- c(
  "stringr",
  "glue",
  "tools",
  "yaml",
  "future",
  # "future.mirai", # REMOVED 2025-12-14: nanonext incompatible with mbedtls 4.x
  "promises",
  "later",
  "dotenv"
)
```

### Problem 2: ETL Should Process ALL Productlines

User requirement:
> "all_ETL_metadata_turbo_0IM.R 這應該一次處理所有productline"

**Solution**: Created universal ETL framework:

1. **Restructured `metadata_sources.yaml`**:
   - Added `metadata:` section with `turbo`, `cbz`, `eby`, `amz` subsections
   - Added `metadata_universal:` section for cross-company data
   - Each source has `enabled` flag for selective processing
   - Maintained backwards compatibility with legacy `metadata_turbo:` format

2. **Created `all_ETL_metadata_0IM.R`**:
   - Universal ETL that loops through ALL enabled metadata sources
   - Processes company-specific and universal metadata separately
   - Writes to appropriate database based on `target_scope`
   - Provides summary of successes/failures

### Files Modified in Phase 6

| File | Change |
|------|--------|
| `fn_initialize_packages.R` | Removed `future.mirai` from core_packages |
| `metadata_sources.yaml` | Restructured to support multi-productline with `enabled` flags |
| `all_ETL_metadata_0IM.R` | NEW: Universal ETL framework |

### New YAML Structure

```yaml
metadata:
  turbo:
    enabled: true
    sheet_id: "..."
    # ... config
  cbz:
    enabled: false  # Enable when ready
    # ... config
  eby:
    enabled: false
    # ... config
  amz:
    enabled: false
    # ... config

metadata_universal:
  common:
    enabled: false
    target_scope: "universal"
    # ... config
```

### Usage

```bash
# Process all enabled metadata sources
cd /path/to/MAMBA
Rscript scripts/update_scripts/ETL/all/all_ETL_metadata_0IM.R

# Or use the original single-source script for backwards compatibility
Rscript scripts/update_scripts/ETL/all/all_ETL_metadata_turbo_0IM.R
```

### Testing After Phase 6

```r
# After running all_ETL_metadata_0IM.R:
app_con <- DBI::dbConnect(duckdb::duckdb(),
  file.path(g_project_root, "data", "app_data", "app_data.duckdb"))

# Check which tables exist
DBI::dbListTables(app_con)
# Should include "df_metadata_turbo" (and others if enabled)

DBI::dbDisconnect(app_con)
```

---

*This changelog follows SO_R030 (Operational Documentation Location Standard)*
