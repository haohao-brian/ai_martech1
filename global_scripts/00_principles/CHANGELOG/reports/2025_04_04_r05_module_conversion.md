---
date: "2025-04-04"
title: "Conversion of R05 Renaming Methods to M05 Renumbering Principles Module"
type: "record"
author: "Claude"
related_to:
  - "R05": "Renaming Methods"
  - "M00": "Renumbering Principles Module"
  - "MP16": "Modularity"
  - "MP17": "Separation of Concerns"
---

# Conversion of R05 Renaming Methods to M05 Renumbering Principles Module

## Summary

This record documents the conversion of the R05 (Renaming Methods) rule into the M00_renumbering_principles module. The conversion improved implementation, added programmatic functionality, and created a better separation between rules (what should be done) and modules (how to do it).

## Motivation

The original R05 rule contained detailed procedures, scripts, and verification methods for renaming resources. This level of detail and implementation focus exceeded what would typically be included in a rule and more closely resembled a module - a collection of related components providing cohesive functionality.

## Changes Made

### 1. Created M00_renumbering_principles Module Structure

Created the proper module structure following MP16 (Modularity):
- `M00_renumbering_principles/`
  - `README.md`: Module documentation
  - `M05_fn_renumber_principles.R`: Main module function
  - `functions/`: Individual function implementations
    - `verify_unique.R`
    - `renumber_resource.R`
    - `verify_consistency.R`
    - `batch_renumber_resources.R`
    - (Additional function files to be implemented)
  - `tests/`: Test files for the module

### 2. Implemented Core Functions

The module implements these key functions:
- `verify_unique()`: Check if a proposed name is already in use
- `renumber_resource()`: Renumber sequenced resources (MP, P, R)
- `verify_consistency()`: Ensure naming consistency across the system
- `batch_renumber_resources()`: Perform batch renaming operations

### 3. Archived Original R05

The original R05 rule was:
- Archived to the global_scripts/99_archive directory
- Marked as archived with appropriate metadata
- Referenced from the new module

## Benefits of the Conversion

1. **Better Separation of Concerns**: Separates the rule (what to do) from the implementation (how to do it)
2. **Programmatic Usage**: Makes the renaming functionality available programmatically
3. **Testability**: Creates a structure allowing proper testing of renaming functions
4. **Reusability**: Easier to reuse the functionality in different contexts
5. **Maintainability**: More structured organization of the code
6. **Implementation Completeness**: Provides a complete implementation rather than just documentation

## Relationship to Principles

This conversion aligns with:
1. **MP16 (Modularity)**: Creates a cohesive module with a well-defined purpose
2. **MP17 (Separation of Concerns)**: Separates the rule from its implementation
3. **MP18 (Don't Repeat Yourself)**: Centralizes renaming functionality in one place
4. **P05 (Naming Principles)**: Provides tools to implement the naming principles effectively

## Implementation Status

The initial implementation includes:
- Basic module structure
- Core function implementations
- Documentation

Future enhancements will include:
- Additional helper functions
- Comprehensive test suite
- Integration with version control systems
- Enhanced error handling and logging

## Example Usage

```r
# Load the module
source("00_principles/M00_renumbering_principles/M05_fn_renumber_principles.R")

# Renumber a principle
M00_renumbering_principles$renumber("P16", "P07", "app_bottom_up_construction")

# Batch renumbering with a mapping table
mapping <- tibble(
  old_id = c("P08", "P04"),
  new_id = c("P05", "P12"),
  name = c("naming_principles", "app_construction")
)
M00_renumbering_principles$batch_renumber(mapping)

# Verify system consistency
issues <- M00_renumbering_principles$verify()
if (is.null(issues)) {
  cat("System is consistent\n")
} else {
  print(issues)
}
```

## Conclusion

Converting R05 to the M00_renumbering_principles module significantly improves the implementation of renumbering functionality in the system. It adheres to the principle of separating rules from their implementation while providing robust, reusable tools for managing the naming and numbering of resources.

The conversion maintains the original intent and requirements of R05 while enhancing usability, testability, and maintainability through a proper module structure.
