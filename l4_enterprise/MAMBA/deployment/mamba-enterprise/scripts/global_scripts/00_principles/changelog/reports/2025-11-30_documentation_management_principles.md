# Documentation Management Principles Addition

## Date
2025-11-30

## Author
Claude (Principle Revisor)

## Summary

Added three new Structure Organization rules to formalize documentation management practices and prevent scattered files in the project root directory. These rules were created based on the root directory cleanup analysis that identified 100+ misplaced operational documents.

## New Principles Created

### SO_R030: Operational Documentation Location Standard

**Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R030_operational_documentation_location.qmd`

**Purpose**: Mandates that all operational documentation must be placed in the CHANGELOG directory with proper date-prefixed, lowercase naming.

**Key Requirements**:
- All implementation reports, debug reports, fix reports, test reports, and strategy documents must be in `CHANGELOG/`
- Naming pattern: `YYYY-MM-DD_descriptive_name.md`
- Style: lowercase with underscores (snake_case)
- PROHIBITED in project root: Any `*_REPORT*.md`, `*_FIX*.md`, `*_DEBUG*.md` files

### SO_R031: Backup File Management Rule

**Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R031_backup_file_management.qmd`

**Purpose**: Establishes standards for backup file retention, naming, and automatic archiving.

**Key Requirements**:
- Retention: Maximum 7 days in original location
- Archive location: `CHANGELOG/archive/backups_YYYYMM/`
- Naming: `original_filename.backup_YYYYMMDD_HHMMSS`
- Compression: Files > 30 days old compressed to .tar.gz
- Includes cleanup scripts for automation

### SO_R032: Documentation Template System Rule

**Location**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R032_documentation_template_system.qmd`

**Purpose**: Provides standardized templates for operational documentation with embedded guidance.

**Template Types Defined**:
1. Implementation Report Template
2. Debug Report Template
3. Fix Report Template
4. Test Report Template
5. Strategy Document Template

**Key Features**:
- Embedded file path guidance in each template
- Pre-filled filename patterns with date prefix
- Required metadata sections
- Standard structure for each document type

## Modified Principles

### MP012: Change Tracking Principle

**Location**: `docs/en/part1_principles/CH00_fundamental_principles/02_structure_organization/MP012_change_tracking.qmd`

**Changes**:
1. Added section "2.3 Operational Documentation" with:
   - Location and naming requirements table
   - Naming convention rules
   - Prohibited patterns examples
   - References to new SO_R030, SO_R031, SO_R032 rules

2. Updated "Related Principles" section to include:
   - SO_R029 (CHANGELOG Organization)
   - SO_R030 (Operational Documentation Location)
   - SO_R031 (Backup File Management)
   - SO_R032 (Documentation Template System)

3. Updated "Implementation Checklist" with:
   - No operational documents in project root
   - Operational documents use date-prefixed naming
   - Backup files follow SO_R031 convention
   - Documentation templates available and used

## Updated Index

### INDEX.md

**Changes**:
1. Updated date to 2025-11-30
2. Added 4 new entries to Recent Changes section
3. Added new "Structure Organization (CH01)" section under Active Rules
4. Listed SO_R030, SO_R031, SO_R032 with descriptions and links

## Impact

### Affected Components
- All future operational documentation must follow new standards
- Existing misplaced documents should be migrated to CHANGELOG/
- Backup cleanup processes should be implemented

### Migration Required
Projects with scattered documentation should:
1. Run detection scripts from SO_R030 to identify misplaced files
2. Move files to CHANGELOG/ with proper date-prefixed naming
3. Implement backup cleanup scripts from SO_R031
4. Make templates from SO_R032 available to team

### Breaking Changes
None - these are new rules that establish standards for future work.

## Files Created

### English Versions
1. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R030_operational_documentation_location.qmd`
2. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R031_backup_file_management.qmd`
3. `docs/en/part1_principles/CH01_structure_organization/rules/SO_R032_documentation_template_system.qmd`

### Chinese Versions
1. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R030_operational_documentation_location.qmd`
2. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R031_backup_file_management.qmd`
3. `docs/zh/part1_principles/CH01_structure_organization/rules/SO_R032_documentation_template_system.qmd`

## Files Modified

1. `docs/en/part1_principles/CH00_fundamental_principles/02_structure_organization/MP012_change_tracking.qmd`
2. `docs/zh/part1_principles/CH00_fundamental_principles/02_structure_organization/MP012_change_tracking.qmd`
3. `INDEX.md`

## Related Issues

This change addresses the root directory clutter problem identified during project cleanup, where 100+ operational documents were found scattered in the project root instead of properly organized in CHANGELOG/.

## Status

COMPLETED
