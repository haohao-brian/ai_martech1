# SO_R033-035 Principle Formalization

## Date
2025-11-30

## Summary
Formalized three new Structure Organization rules (SO_R033, SO_R034, SO_R035) for test/debug script and temporary file management based on root directory cleanup recommendations from principle-product-manager.

## Background
During root directory cleanup, principle-product-manager identified the need for formal principles governing:
1. Test script locations to prevent root directory pollution
2. Debug script lifecycle and archival procedures
3. Temporary file and log retention policies

## New Principles Created

### SO_R033: Test Script Location Standard
- **Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R033_test_script_location.qmd`
- **Chinese Version**: `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R033_test_script_location.qmd`
- **Core Rules**:
  - System tests: `scripts/global_scripts/98_test/`
  - Component tests: `scripts/global_scripts/[component]/tests/`
  - PROHIBITION: No test scripts in project root
  - Naming prefixes: test_, validate_, verify_, check_

### SO_R034: Debug Script Management and Archival
- **Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R034_debug_script_management.qmd`
- **Chinese Version**: `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R034_debug_script_management.qmd`
- **Core Rules**:
  - Debug scripts are TEMPORARY investigation tools
  - Lifecycle: Create -> Use -> Archive (after issue resolution)
  - Archive location: `ISSUE_TRACKER/archive/debugging/[YYYYMMDD]_[issue]/`
  - Distinction: Temporary debug vs. Persistent debug utilities

### SO_R035: Temporary File and Log Management
- **Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R035_temp_file_log_management.qmd`
- **Chinese Version**: `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R035_temp_file_log_management.qmd`
- **Core Rules**:
  - Logs: `logs/active/[component]/` - 30 days, then archive
  - Cache: `data/temp/cache/` - 7 days retention
  - Scratch: `data/temp/scratch/` - 1 day retention
  - PROHIBITION: No temp files or logs in root directory
  - Log archives retained 12 months

## Correction Applied
- **Issue**: SO_R033-035 were initially created in `CH03_development_methodology/rules/`
- **Fix**: Moved to correct location `CH01_structure_organization/rules/` for consistency with SO_ prefix convention
- SO_R030-032 correctly placed in CH01; SO_R033-035 now aligned

## INDEX.md Updates
- Added SO_R033, SO_R034, SO_R035 to Recent Changes section
- Added principle links to Structure Organization (CH01) section

## Related Principles
- **SO_R025**: Script Organization Hierarchy (extended by SO_R033-035)
- **SO_R030**: Operational Documentation Location (complementary)
- **MP046**: Debug Code Tracing (defines persistent debug utilities)
- **MP100**: UTF-8 Encoding Standard (applies to all files)

## Files Modified
1. `INDEX.md` - Added new principles to recent changes and active rules sections

## Files Created
1. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R033_test_script_location.qmd`
2. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R034_debug_script_management.qmd`
3. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R035_temp_file_log_management.qmd`
4. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R033_test_script_location.qmd`
5. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R034_debug_script_management.qmd`
6. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R035_temp_file_log_management.qmd`
7. `CHANGELOG/2025-11-30_so_r033_035_formalization.md` (this file)

## Files Moved
1. `SO_R033_test_script_location.qmd`: CH03 -> CH01 (EN)
2. `SO_R034_debug_script_management.qmd`: CH03 -> CH01 (EN)
3. `SO_R035_temp_file_log_management.qmd`: CH03 -> CH01 (EN)

## Impact Assessment
- **Breaking Changes**: None
- **Migration Required**: Development teams should move existing test/debug scripts to proper locations
- **Training Required**: Team awareness of new archival procedures for debug scripts

## Verification Checklist
- [x] English versions created and complete
- [x] Chinese versions created and complete
- [x] INDEX.md updated with new principles
- [x] CHANGELOG entry created
- [x] Files in correct CH01 directory (not CH03)
- [x] Naming convention consistent with SO_R030-032

## Author
Principle Revisor (Claude)
