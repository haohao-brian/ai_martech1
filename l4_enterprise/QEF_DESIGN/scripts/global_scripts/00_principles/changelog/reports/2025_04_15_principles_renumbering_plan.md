# Principles Renumbering Plan - April 15, 2025

## Overview

This document outlines the plan for renumbering several Meta Principles to maintain better organization and clear numbering sequences. The renumbering will resolve duplicate numbers and ensure proper sequential numbering.

## Renumbering Targets

### 1. Large Numbers
- `MP100_app_dynamics.md` → `MP59_app_dynamics.md`
- `MP107_parsimony.md` → `MP60_parsimony.md`
- `MP107_root_cause_resolution.md` → `MP61_root_cause_resolution.md`

### 2. Duplicate Numbers (MP27)
- Keep: `MP27_specialized_natural_sql_language.md` (original)
- `MP27_specialized_natural_sql_language_v2.md` → `MP62_specialized_natural_sql_language_v2.md`

### 3. Duplicate Numbers (MP28)
- Keep: `MP28_avoid_self_reference.md` (original)
- `MP28_graph_theory_in_nsql.md` → `MP63_graph_theory_in_nsql.md`
- `MP28_nsql_set_theory_foundations.md` → `MP64_nsql_set_theory_foundations.md`

### 4. Duplicate Numbers (MP40)
- Keep: `MP40_deterministic_codebase_transformations.md` (original)
- `MP40_time_allocation_decomposition.md` → `MP65_time_allocation_decomposition.md`

### 5. Duplicate Numbers (MP41)
- Keep: `MP41_config_driven_ui_composition.md` (original)
- `MP41_type_dependent_operations.md` → `MP66_type_dependent_operations.md`

### 6. Recently Added Principles
- No change needed for `MP58_database_table_creation_strategy.md` (already in sequence)

### 7. Non-Standard Numbers
- `MP99_ui_separation.md` → `MP67_ui_separation.md`

## Implementation Strategy

1. Will use the M00_renumbering_principles module for safe execution
2. Batch operation to maintain atomicity
3. Complete in a single transaction with backup
4. Verify all references are updated correctly

## Mapping Table

Below is the mapping table to be used with the batch_renumber function:

```r
mapping_table <- data.frame(
  old_id = c(
    "MP100", "MP107", "MP107", 
    "MP27", 
    "MP28", "MP28", 
    "MP40", 
    "MP41", 
    "MP99"
  ),
  new_id = c(
    "MP59", "MP60", "MP61", 
    "MP62", 
    "MP63", "MP64", 
    "MP65", 
    "MP66", 
    "MP67"
  ),
  name = c(
    "app_dynamics", "parsimony", "root_cause_resolution", 
    "specialized_natural_sql_language_v2", 
    "graph_theory_in_nsql", "nsql_set_theory_foundations", 
    "time_allocation_decomposition", 
    "type_dependent_operations", 
    "ui_separation"
  ),
  stringsAsFactors = FALSE
)
```

## Post-Renumbering Verification

After renumbering, we will:
1. Verify all references are updated correctly
2. Run consistency check using the module's verify function
3. Document the changes in the revision history