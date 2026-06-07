# Root Directory Scripts Cleanup - 2025-11-30

## Executive Summary

Organized 35+ scattered test, debug, and execution scripts from project root directory into appropriate locations following MAMBA organizational principles.

## Problem Statement

Project root directory `/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/MAMBA` had accumulated numerous temporary scripts causing:
- Git status pollution with untracked files
- Unclear project structure
- Difficulty finding relevant test scripts
- No clear archival/retention policy for debug scripts

## Actions Taken

### 1. Created Archive Structure

```bash
scripts/global_scripts/00_principles/ISSUE_TRACKER/archive/
├── debugging/
│   └── root_debug_scripts_20251130/
└── test_scripts/
    └── root_execution_scripts_20251130/

logs/archive/
└── 20251130/
```

### 2. File Organization

#### Debug Scripts → Archive
Moved to `scripts/global_scripts/00_principles/ISSUE_TRACKER/archive/debugging/root_debug_scripts_20251130/`:
- `debug_all_duplicates.R`
- `debug_duplicate_columns.R`
- `debug_eby_tables.R`

**Rationale**: One-time debugging scripts used for specific issue investigation, not needed in active codebase but valuable for historical reference.

#### Test Scripts → 98_test/
Moved 30+ scripts to `scripts/global_scripts/98_test/`:
- `check_packages.R` - Package dependency validation
- `check_staged.R` - Git staging verification
- `test_*.R` (30 files) - Various system tests including:
  - Database connection tests
  - ETL pipeline tests
  - API integration tests
  - Report generation tests
  - Display name system tests

**Rationale**: Active test scripts that may be reused for validation and regression testing.

#### Execution Scripts → Archive
Moved to `scripts/global_scripts/00_principles/ISSUE_TRACKER/archive/test_scripts/root_execution_scripts_20251130/`:
- `execute_display_name_implementation.R` - One-time execution script for DM_R046 implementation

**Rationale**: Implementation execution scripts are project artifacts but not ongoing test utilities.

#### Logs and Temporary Data → logs/archive/
Moved to `logs/archive/20251130/`:
- `phase2_1ST_output.log`
- `rollback_20251113_055834.log`
- `rollback_20251113_055840.log`
- `rollback_20251113_055844.log`
- `database_verification_results.rds`

**Rationale**: Historical logs and temporary data files should be archived, not kept in root.

#### Backup Files → Removed
Deleted all `.backup_drv_*` files from root since they already exist in `archive/git_removal_*/` directories.

## Results

### Before
```
Root directory: 40+ scattered .R files, 5 .log files, 1 .rds file
Git status: 50+ untracked files
```

### After
```
Root directory: 1 app.R (application entry point)
Git status: Clean (no untracked test/debug files)
scripts/global_scripts/98_test/: 35 organized test scripts
Archive directories: Properly categorized historical scripts
```

## Principles Applied

### Existing Principles
- **MP029 (No Fake Data)**: Preserved all real debugging artifacts
- **MP100 (UTF-8 Encoding)**: All archived files maintain proper encoding
- **SO_R025 (Script Organization)**: Organized scripts by functional category

### Principle Gaps Identified

The cleanup revealed gaps in script management that should be addressed by new principles (see recommendations below).

## Recommendations

### 1. Create SO_R033: Test Script Location Standard

```yaml
---
rule_id: "SO_R033"
title: "Test Script Location Standard"
category: "Script Organization"
status: "proposed"
created: "2025-11-30"
---

# SO_R033: Test Script Location Standard

## Principle
All test and validation scripts MUST be stored in designated test directories, NEVER in project root.

## Implementation

### Test Script Locations
- **System tests**: `scripts/global_scripts/98_test/`
- **Component tests**: `scripts/global_scripts/[component]/tests/`
- **Module tests**: `scripts/global_scripts/13_modules/M70_testing/`
- **Platform API tests**: `scripts/global_scripts/26_platform_apis/[platform]/tests/`

### Naming Convention
- Prefix: `test_` for active test scripts
- Prefix: `validate_` for validation scripts
- Prefix: `verify_` for verification scripts
- Prefix: `check_` for dependency/status checks

### Root Directory Policy
**PROHIBITED**: Test scripts in project root directory.
**EXCEPTION**: None. All tests must be in appropriate test directories.

### Examples
```r
# CORRECT
scripts/global_scripts/98_test/test_database_connection.R
scripts/global_scripts/01_db/tests/test_connection_pooling.R

# INCORRECT (root directory)
./test_something.R
./validate_feature.R
```

## Enforcement
- Pre-commit hooks should warn if test_*.R detected in root
- Code review checklist includes test location verification
```

### 2. Create SO_R034: Debug Script Management

```yaml
---
rule_id: "SO_R034"
title: "Debug Script Management and Archival"
category: "Script Organization"
status: "proposed"
created: "2025-11-30"
---

# SO_R034: Debug Script Management and Archival

## Principle
Debug scripts are temporary investigation tools that MUST be archived after issue resolution, not kept in active codebase.

## Classification

### Temporary Debug Scripts
Scripts created for specific issue investigation:
- Prefix: `debug_`
- Purpose: One-time problem diagnosis
- Lifecycle: Create → Use → Archive
- Archive location: `scripts/global_scripts/00_principles/ISSUE_TRACKER/archive/debugging/[date]/`

### Persistent Debug Utilities
Reusable debugging functions:
- Location: `scripts/global_scripts/22_initializations/sc_debug_verbose_init.R`
- Purpose: Configurable debug tracing
- Lifecycle: Maintain in codebase

## Archival Process

When closing an issue that involved debug scripts:
1. Move debug_*.R to `ISSUE_TRACKER/archive/debugging/YYYYMMDD_issue_XXX/`
2. Include reference in issue closure documentation
3. Update CHANGELOG with debug script location

## Example Structure
```
ISSUE_TRACKER/archive/debugging/
├── 20251113_database_duplicates/
│   ├── debug_all_duplicates.R
│   └── debug_duplicate_columns.R
├── 20251116_eby_tables/
│   └── debug_eby_tables.R
└── 20251130_root_cleanup/
    └── README.md
```

## Enforcement
- Monthly cleanup: Move debug_*.R from root to archive
- Issue closure checklist: Archive associated debug scripts
```

### 3. Create SO_R035: Temporary File and Log Management

```yaml
---
rule_id: "SO_R035"
title: "Temporary File and Log Management"
category: "Script Organization"
status: "proposed"
created: "2025-11-30"
---

# SO_R035: Temporary File and Log Management

## Principle
Temporary files and logs MUST be stored in designated directories with clear retention policies.

## Directory Structure

### Logs
```
logs/
├── active/              # Current operational logs
│   ├── etl/
│   ├── api/
│   └── app/
└── archive/             # Historical logs (organized by date)
    ├── 2025-11/
    └── 2025-12/
```

### Temporary Data
```
data/temp/               # Temporary data files
├── cache/               # Cache files (can be regenerated)
└── scratch/             # Scratch workspace (safe to delete)
```

## File Types

### Log Files (.log)
- **Location**: `logs/active/[component]/`
- **Archival**: Move to `logs/archive/YYYY-MM/` after 30 days
- **Retention**: Keep archives for 12 months
- **Naming**: `[component]_[action]_YYYYMMDD_HHMMSS.log`

### Temporary Data (.rds, .tmp, .cache)
- **Location**: `data/temp/`
- **Retention**: Delete after 7 days or when no longer needed
- **Exception**: Verification results should be archived if documenting issue resolution

### Output Files
- **Location**: `output/` or component-specific output directory
- **Retention**: Archive significant results, delete routine outputs

## Root Directory Policy
**PROHIBITED**:
- Log files in root
- Temporary data files in root
- Cache files in root

**REQUIRED**:
- All logs in `logs/` hierarchy
- All temp data in `data/temp/`

## Cleanup Automation

Recommended cron job (weekly):
```bash
# Archive old logs
find logs/active -name "*.log" -mtime +30 -exec mv {} logs/archive/$(date +%Y-%m)/ \;

# Clean temp directory
find data/temp/scratch -mtime +7 -delete
```

## Enforcement
- Pre-commit hook: Warn on .log or .rds in root
- Monthly audit: Check for accumulated temporary files
```

### 4. Update SO_R025: Script Organization Hierarchy

Add clarification to existing SO_R025 about test and debug script placement:

```yaml
# Addition to SO_R025

## Script Type Directory Mapping

| Script Type | Location | Example |
|-------------|----------|---------|
| Application Entry | Root | `app.R` |
| ETL Scripts | `scripts/update_scripts/ETL/[platform]/` | `eby_ETL_sales.R` |
| Derivation Scripts | `scripts/update_scripts/DRV/[platform]/` | `cbz_DRV_customer_rfm.R` |
| Test Scripts | `scripts/global_scripts/98_test/` | `test_database.R` |
| Debug Scripts | Archive after use | `debug_issue_123.R` |
| Utility Functions | `scripts/global_scripts/04_utils/` | `fn_helper.R` |
| Component Tests | `[component]/tests/` | `01_db/tests/test_*.R` |

## Root Directory Restrictions

Only the following file types are permitted in project root:
- `app.R` - Application entry point
- `*.Rproj` - RStudio project file
- `README.md` - Project documentation
- `CHANGELOG.md` - Change history
- Configuration files: `.Rprofile`, `renv.lock`, etc.

**Prohibited in root**:
- Test scripts (`test_*.R`)
- Debug scripts (`debug_*.R`)
- Log files (`*.log`)
- Temporary data (`*.rds`, `*.tmp`)
- Backup files (`*.backup`)
```

## Migration Path

### Phase 1: Immediate (Completed 2025-11-30)
- ✅ Move all test scripts from root to `98_test/`
- ✅ Archive debug scripts to `ISSUE_TRACKER/archive/debugging/`
- ✅ Move logs to `logs/archive/`
- ✅ Remove duplicate backup files

### Phase 2: Documentation (Next)
- Create SO_R033, SO_R034, SO_R035 principle documents
- Update SO_R025 with clarifications
- Add to principle INDEX.md

### Phase 3: Enforcement (Future)
- Create pre-commit hook to prevent test/debug files in root
- Set up automated log archival
- Add cleanup checks to CI/CD

## Impact Assessment

### Positive Impacts
- **Developer Experience**: Cleaner project structure, easier navigation
- **Git Hygiene**: No more untracked test files polluting git status
- **Maintainability**: Clear separation of active vs. archived scripts
- **Discoverability**: Tests are now in expected locations

### Risks
- **Minimal**: All files preserved in archive, no data loss
- **Migration**: Paths in documentation may need updates (but most tests were not referenced in docs)

## Related Issues
- ISSUE_XXX: Project organization standards
- MP029: No Fake Data Principle (preservation requirement)
- SO_R025: Script Organization Hierarchy

## Verification

### Test Organization
```bash
# Count test scripts in proper location
find scripts/global_scripts/98_test -name "test_*.R" | wc -l
# Expected: 35+

# Verify no test scripts in root
find . -maxdepth 1 -name "test_*.R" | wc -l
# Expected: 0
```

### Archive Integrity
```bash
# Verify debug scripts archived
ls -la scripts/global_scripts/00_principles/ISSUE_TRACKER/archive/debugging/root_debug_scripts_20251130/
# Expected: 3 files

# Verify logs archived
ls -la logs/archive/20251130/
# Expected: 5 files
```

## Conclusion

This cleanup establishes clear organizational patterns for test, debug, and temporary files, preventing future accumulation of scattered scripts in the project root. The proposed principles (SO_R033-035) formalize these patterns for consistent application across the MAMBA framework.

---
**Author**: Claude Code (principle-product-manager agent)
**Date**: 2025-11-30
**Principles Applied**: MP029, MP100, SO_R025
**Principles Proposed**: SO_R033, SO_R034, SO_R035
