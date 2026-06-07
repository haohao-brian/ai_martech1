# Principle Consolidation Plan

## Redundant Principles to Merge

### 1. Documentation Principles
**Merge These:**
- MP007_documentation_organization
- P010_documentation_update  
- MP043_database_documentation
- MP057_package_documentation
- R002_principle_documentation

**Into:** `MP007_unified_documentation`

### 2. Naming Convention Principles
**Merge These:**
- R001_file_naming_convention
- R006_module_naming_convention
- R019_object_naming_convention
- R042_module_naming
- R051_lowercase_variable_naming
- R069_function_file_naming

**Into:** `R001_unified_naming_conventions`

### 3. Data Access Principles
**Merge These:**
- R091_universal_data_access
- R092_universal_dbi_approach
- R100_database_access_tbl_rule
- R101_unified_tbl_data_access
- R111_tbl_pattern_rationale
- R116_tbl2_enhanced_data_access

**Into:** `R091_universal_data_access_pattern`

### 4. Function Organization Principles
**Merge These:**
- R021_one_function_one_file
- R043_check_existing_functions
- R067_functional_encapsulation
- R093_function_location_rule
- R095_import_requirements_rule

**Into:** `R021_function_organization_standards`

### 5. Shiny/UI Principles
**Merge These:**
- R088_shiny_module_id_handling
- R102_shiny_reactive_observation_rule
- R106_selectize_input_usage
- R110_explicit_namespace_in_shiny

**Into:** `R088_shiny_development_standards`

## Principles to Deprecate

### Remove Due to Obsolescence:
- Old version-specific rules that no longer apply
- Platform-specific rules superseded by universal approaches
- Temporary rules that have served their purpose

### Archive But Keep Reference:
- Historical principles that show evolution
- Context-specific rules that may return

## New Consolidated Structure

```
00_principles/
├── active/                 # Currently enforced
│   ├── L1_core/           # Never violate
│   ├── L2_standard/       # Default follow
│   └── L3_guidance/       # Recommended
├── archived/              # Historical reference
├── context/               # Context-specific
│   ├── development/
│   ├── production/
│   └── debugging/
└── meta/                  # About the system
    ├── CONFLICT_RESOLUTION.md
    ├── CONSOLIDATION_PLAN.md
    └── HIERARCHY.md
```

## Migration Timeline

### Week 1: Preparation
- Backup current structure
- Create new directory structure
- Document all consolidations

### Week 2: Consolidation
- Merge redundant principles
- Update cross-references
- Test impact on existing code

### Week 3: Migration
- Move principles to new structure
- Update import paths
- Update documentation

### Week 4: Validation
- Verify no broken references
- Ensure all apps still function
- Final review and adjustment

## Impact Analysis

### High Impact (Update Required):
- Apps directly referencing specific principles
- Documentation mentioning principle numbers
- Test suites checking principle compliance

### Low Impact (No Change Needed):
- Code following principles implicitly
- General development practices
- External documentation

## Rollback Plan

If consolidation causes issues:
1. Restore from `archived/` directory
2. Maintain parallel structures temporarily
3. Gradual migration over longer period

---

*Created: 2025-08-24*
*Target Completion: 2025-09-21*