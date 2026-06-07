# Change Log: Script Separation Clarification
**Date**: 2025-08-27  
**Author**: Claude  
**Type**: Principle Addition & Rule Update

## Summary

Added comprehensive documentation clarifying the distinction between `update_scripts/` and `global_scripts/` directories, establishing clear architectural boundaries and dependency rules.

## Changes Made

### 1. New Meta-Principle: MP093

**File**: `docs/en/part1_principles/CH00_fundamental_principles/02_structure_organization/MP093_script_separation_principle.qmd`

**Purpose**: Establishes the fundamental architectural principle of separating executable scripts from reusable components.

**Key Points**:
- `update_scripts/`: Contains all executable scripts (ETL, derivations, updates)
- `global_scripts/`: Contains reusable functions, modules, and documentation
- Dependencies flow only from update_scripts → global_scripts, never reverse
- Clear distinction between "what runs" and "what helps"

### 2. New Rule: DM_R035

**File**: `docs/en/part1_principles/CH02_data_management/rules/DM_R035_script_placement_rule.qmd`

**Purpose**: Specifies exact placement and naming conventions for ETL and Derivation scripts.

**Key Points**:
- ETL scripts: `update_scripts/platform_ETL##_phase.R`
- Derivation scripts: `update_scripts/platform_D##_description.R`
- System change scripts: `update_scripts/sc_*.R`
- All follow DEV_R032 four-part structure

### 3. Updated Rule: SO_R001

**File**: `docs/en/part1_principles/CH01_structure_organization/rules/SO_R001_directory_structure.qmd`

**Changes**:
- Added reference to MP093 in implements section
- Added new Section 2.1: Script Separation Architecture
- Added new Section 3: Update Scripts Organization
- Clarified examples showing platform-specific script names
- Updated cross-references to include new principles

## Rationale

### Problem Addressed
- Ambiguity about where different types of scripts should be placed
- Lack of clear documentation about the purpose of each directory
- Mixed concerns with executable logic appearing in library directories
- Unclear dependency rules between directories

### Solution Benefits
1. **Clear Boundaries**: Obvious distinction between executable and library code
2. **Maintainability**: Changes to functions don't affect script logic
3. **Discoverability**: Developers know exactly where to find different types of code
4. **Reusability**: Functions in global_scripts can be used by any executable
5. **Testability**: Components can be tested independently

## Impact Assessment

### Breaking Changes
None - This change documents existing best practices and clarifies ambiguities.

### Migration Required
Projects with scripts in incorrect locations should:
1. Move executable logic from global_scripts to update_scripts
2. Extract reusable functions from update_scripts to global_scripts
3. Update source() paths accordingly

### Affected Components
- All ETL pipelines (ETL01-ETL08)
- All derivation scripts (D01-D04)
- System change scripts
- Any misplaced executable code in global_scripts

## Implementation Guide

### For New Scripts
1. Determine if script is executable or reusable
2. Place in appropriate directory (update_scripts or global_scripts)
3. Follow naming conventions from DM_R035
4. Ensure dependencies follow MP093 rules

### For Existing Scripts
1. Audit current placement against MP093 and DM_R035
2. Create migration plan for misplaced scripts
3. Update incrementally when modifying scripts
4. Document any temporary exceptions

## Verification Checklist

- [x] Created MP093 documenting script separation principle
- [x] Created DM_R035 specifying placement rules
- [x] Updated SO_R001 with clarifications
- [x] All examples use correct directory structure
- [x] Dependency rules clearly stated
- [x] Migration path provided

## Related Principles

- **MP064**: ETL-Derivation Separation Principle
- **MP002**: Structural Blueprint  
- **DEV_R032**: Update Script Structure Rule
- **MP092**: Platform ID Standard

## Notes

This clarification formalizes the existing best practice of separating execution from library code, a fundamental architectural pattern that ensures clean, maintainable, and scalable systems. The principle follows standard software engineering practices of separation of concerns and single responsibility.