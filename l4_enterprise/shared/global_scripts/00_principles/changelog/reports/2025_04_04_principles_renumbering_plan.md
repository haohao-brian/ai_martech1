---
date: "2025-04-04"
title: "Principles Renumbering Plan"
type: "record"
author: "Claude"
related_to:
  - "M00": "Renumbering Principles Module"
  - "MP05": "Instance vs. Principle"
  - "P05": "Naming Principles"
---

# Principles Renumbering Plan

## Summary

This record outlines the plan for renumbering rules (R) and modules (M) to maintain sequential numbering without gaps, improving organization and discoverability. The plan addresses two specific issues:

1. Missing R10 (archived) and gaps in the R16-R22 sequence
2. Module numbering starting at M05 instead of M00

## Current State Analysis

### Rules (R) Current State

The R series currently has the following issues:
- R05 has been archived (converted to M05)
- R10 has been archived (functionality split between R23 and R31)
- R16 is missing
- R21-R22 are missing
- Numbering goes up to R32

### Modules (M) Current State

The M series currently:
- Starts at M05 (M00_renumbering_principles)
- No other modules currently exist

## Renumbering Strategy

### Rules (R) Renumbering

We'll use the following approach for renumbering rules:
1. Compact the numbering to remove gaps
2. Maintain relative ordering of existing rules
3. Preserve grouping of related rules
4. Update all internal references to maintain consistency

#### Rules (R) Mapping Table

| Current ID | New ID | Name |
|------------|--------|------|
| R00 | R00 | directory_structure |
| R01 | R01 | file_naming_convention |
| R02 | R02 | principle_documentation |
| R03 | R03 | platform_neutral_code |
| R04 | R04 | app_yaml_configuration |
| R06 | R05 | temporary_file_handling |
| R07 | R06 | module_naming_convention |
| R08 | R07 | update_script_naming |
| R09 | R08 | global_scripts_synchronization |
| R11 | R09 | ui_server_defaults_triple |
| R12 | R10 | package_consistency_naming |
| R13 | R11 | hybrid_sidebar_pattern |
| R14 | R12 | minimal_modification |
| R15 | R13 | initialization_sourcing |
| R17 | R14 | ui_hierarchy |
| R18 | R15 | defaults_from_triple |
| R19 | R16 | yaml_parameter_configuration |
| R20_language | R17 | language_standard_adherence |
| R20_pseudocode | R18 | pseudocode_standard_adherence |
| R23 | R19 | object_naming_convention |
| R24 | R20 | logic_document_creation |
| R25 | R21 | one_function_one_file |
| R26 | R22 | app_mode_naming_simplicity |
| R27 | R23 | object_file_name_translation |
| R28 | R24 | type_token_naming |
| R29 | R25 | terminology_synonym_mapping |
| R30 | R26 | type_token_distinction_application |
| R31 | R27 | data_frame_creation_strategy |
| R32 | R28 | archiving_standard |

### Modules (M) Renumbering

We'll renumber the M05 module to M00 to start the module sequence from zero:

| Current ID | New ID | Name |
|------------|--------|------|
| M05 | M00 | renumbering_principles |

## Implementation Plan

We'll use the M05 (soon to be M00) renumbering_principles module to execute this plan:

1. **Preparation**:
   - Create a backup of all files
   - Generate a mapping table in the format required by the module

2. **Rules Renumbering**:
   - For each rule in the mapping table:
     - Rename the file
     - Update the internal ID
     - Update references to the rule in other files

3. **Module Renumbering**:
   - Rename the module directory
   - Update all file paths within the module
   - Update references to the module in other files

4. **Verification**:
   - Check for any inconsistencies
   - Ensure all references are updated
   - Verify the README lists all rules correctly

## Execution Script

```r
# Load the renumbering module
source("00_principles/M00_renumbering_principles/M05_fn_renumber_principles.R")

# Mapping table for rules
rules_mapping <- data.frame(
  old_id = c("R06", "R07", "R08", "R09", "R11", "R12", "R13", "R14", "R15", 
              "R17", "R18", "R19", "R20", "R20", "R23", "R24", "R25", "R26", 
              "R27", "R28", "R29", "R30", "R31", "R32"),
  new_id = c("R05", "R06", "R07", "R08", "R09", "R10", "R11", "R12", "R13", 
              "R14", "R15", "R16", "R17", "R18", "R19", "R20", "R21", "R22", 
              "R23", "R24", "R25", "R26", "R27", "R28"),
  name = c("temporary_file_handling", "module_naming_convention", "update_script_naming", 
           "global_scripts_synchronization", "ui_server_defaults_triple", 
           "package_consistency_naming", "hybrid_sidebar_pattern", "minimal_modification", 
           "initialization_sourcing", "ui_hierarchy", "defaults_from_triple", 
           "yaml_parameter_configuration", "language_standard_adherence", 
           "pseudocode_standard_adherence", "object_naming_convention", 
           "logic_document_creation", "one_function_one_file", "app_mode_naming_simplicity", 
           "object_file_name_translation", "type_token_naming", "terminology_synonym_mapping", 
           "type_token_distinction_application", "data_frame_creation_strategy", 
           "archiving_standard"),
  stringsAsFactors = FALSE
)

# Execute rule renumbering
rule_results <- M00_renumbering_principles$batch_renumber(rules_mapping)

# Module renumbering (will need to be done manually)
# As the renumbering module can't rename itself while running

# Verify system consistency
issues <- M00_renumbering_principles$verify()
if (is.null(issues)) {
  cat("System is consistent\n")
} else {
  print(issues)
}
```

## Expected Outcome

After executing this plan:

1. Rules will be numbered sequentially from R00 to R28
2. The module will be renumbered from M05 to M00
3. All references will be updated consistently
4. The system will maintain its functionality while being better organized

## Risks and Mitigations

1. **Risk**: File renaming errors
   **Mitigation**: Create backups before executing, use atomic operations

2. **Risk**: Missed references
   **Mitigation**: Run comprehensive verification after renumbering

3. **Risk**: Module self-renaming issues
   **Mitigation**: Handle module renumbering as a separate manual step

## Conclusion

This renumbering plan will significantly improve the organization of the principles system by:
1. Eliminating gaps in numbering
2. Starting the module sequence from M00
3. Making the structure more intuitive
4. Facilitating easier maintenance and extension

The M00_renumbering_principles module will be instrumental in executing this plan, demonstrating its practical utility for the very task it was designed to perform.
