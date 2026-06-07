# MAMBA Directory Structure - Post-Cleanup
## Updated: 2025-11-30

## Root Directory (Clean)
```
/MAMBA/
├── app.R                           ← Application entry point (ONLY .R in root)
├── app.R.bak
├── ROOT_CLEANUP_SUMMARY_20251130.md
├── DIRECTORY_STRUCTURE_20251130.md
├── data/
│   ├── app_data/                   ← Application data
│   └── temp/                       ← Temporary data (NEW)
│       ├── cache/                  ← Regenerable cache files
│       └── scratch/                ← Temporary workspace
├── logs/                           ← Log management (NEW)
│   ├── active/                     ← Current logs (<30 days)
│   │   ├── etl/
│   │   ├── api/
│   │   ├── app/
│   │   └── error/
│   └── archive/                    ← Historical logs (>30 days)
│       └── 20251130/               ← Archived logs from cleanup
└── scripts/
    ├── global_scripts/
    │   ├── 00_principles/
    │   │   ├── CHANGELOG/
    │   │   │   └── 2025-11-30_root_scripts_cleanup.md
    │   │   ├── ISSUE_TRACKER/
    │   │   │   └── archive/
    │   │   │       ├── debugging/
    │   │   │       │   └── root_debug_scripts_20251130/
    │   │   │       │       ├── debug_all_duplicates.R
    │   │   │       │       ├── debug_duplicate_columns.R
    │   │   │       │       └── debug_eby_tables.R
    │   │   │       └── test_scripts/
    │   │   │           └── root_execution_scripts_20251130/
    │   │   │               └── execute_display_name_implementation.R
    │   │   └── docs/en/part1_principles/CH03_development_methodology/rules/
    │   │       ├── SO_R033_test_script_location.qmd
    │   │       ├── SO_R034_debug_script_management.qmd
    │   │       └── SO_R035_temp_file_log_management.qmd
    │   └── 98_test/                ← Centralized test scripts (74 files)
    │       ├── check_packages.R
    │       ├── check_staged.R
    │       ├── test_*.R (70+ files)
    │       └── verify_eby_prerequisites.R
    └── update_scripts/
        ├── DRV/
        └── ETL/
```

## File Count Summary

| Location | Count | Type |
|----------|-------|------|
| Root directory | 1 | Application entry point only |
| `98_test/` | 74 | Active test scripts |
| `ISSUE_TRACKER/archive/debugging/` | 3 | Archived debug scripts |
| `ISSUE_TRACKER/archive/test_scripts/` | 1 | Archived execution scripts |
| `logs/archive/20251130/` | 6 | Archived log files |

## Script Organization Principles

### Test Scripts (SO_R033)
**System-wide tests**: `scripts/global_scripts/98_test/`
- 74 test scripts including:
  - Database connection tests
  - API integration tests
  - ETL pipeline tests
  - Component validation tests
  - Issue fix verification tests

**Component-specific tests**: `scripts/global_scripts/[component]/tests/`
- Database tests: `01_db/tests/`
- Platform API tests: `26_platform_apis/[platform]/tests/`

### Debug Scripts (SO_R034)
**Active debugging**: Created in workspace as needed
**Archive after use**: `ISSUE_TRACKER/archive/debugging/[YYYYMMDD]_[issue]/`
- 3 debug scripts archived from root cleanup
- Lifecycle: Create → Use → Archive

### Temporary Files (SO_R035)
**Logs**: `logs/active/[component]/` → `logs/archive/YYYY-MM/`
- Active logs: <30 days
- Archive: >30 days, keep 12 months
- 6 log files archived from root cleanup

**Temporary data**: `data/temp/cache/` or `data/temp/scratch/`
- Cache: Delete after 7 days
- Scratch: Delete after 1 day

## Cleanup Impact

### Before (2025-11-29)
```
Root directory:
  - 40+ scattered .R files
  - 5 .log files
  - 1 .rds file
  - Git status: 50+ untracked files
```

### After (2025-11-30)
```
Root directory:
  - 1 app.R (clean!)
  - Git status: No test/debug pollution
  - Organized structure with clear policies
```

## Maintenance Procedures

### Daily (Automated)
- Clean scratch workspace (>1 day old)

### Weekly (Automated)
- Clean cache files (>7 days old)
- Archive logs (>30 days old)

### Monthly (Manual Review)
- Audit debug script archives
- Review disk usage
- Update retention policies if needed

## Related Documentation

- **Cleanup Report**: `ROOT_CLEANUP_SUMMARY_20251130.md`
- **Detailed CHANGELOG**: `scripts/global_scripts/00_principles/CHANGELOG/2025-11-30_root_scripts_cleanup.md`
- **Principles**:
  - SO_R033: Test Script Location Standard
  - SO_R034: Debug Script Management
  - SO_R035: Temporary File and Log Management

---
**Last Updated**: 2025-11-30
**Status**: ✅ Cleanup Complete
**Principles**: SO_R033, SO_R034, SO_R035 (New)
