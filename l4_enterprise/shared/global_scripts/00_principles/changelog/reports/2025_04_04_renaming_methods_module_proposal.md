---
date: "2025-04-04"
title: "Proposal: Convert R05 Renaming Methods to Module"
type: "record"
author: "Claude"
related_to:
  - "R05": "Renaming Methods"
  - "MP02": "Structural Blueprint"
  - "MP16": "Modularity"
  - "P05": "Naming Principles"
---

# Proposal: Convert R05 Renaming Methods to Module

## Summary

This record proposes converting the current R05 (Renaming Methods Rule) into a proper module (M05_renaming) that provides a complete implementation of the renaming and renumbering capabilities described in the rule.

## Rationale

The current R05 rule describes comprehensive procedures, functions, and verification steps for renaming and renumbering operations. It includes:

1. Detailed processes for verification before renaming
2. Methods for atomically executing renaming operations
3. Procedures for resolving naming conflicts
4. Scripts for renumbering sequenced resources (principles, rules)
5. Recursive verification methods to ensure consistency after renaming

This level of detail and functionality exceeds what's typically included in a rule and more closely resembles a module - a collection of related components that work together to provide a cohesive set of functionality.

## Module Design

### Module Structure

The proposed M05_renaming module would have this structure:

```
M05_renaming/
├── README.md               # Module documentation
├── M05_fn_rename.R         # Main module function
├── functions/              # Individual function implementations
│   ├── verify_unique.R     # Verify name uniqueness
│   ├── scan_references.R   # Scan for references to resources
│   ├── dependency_check.R  # Check dependencies
│   ├── rename_resource.R   # Perform actual renaming
│   ├── update_references.R # Update references after renaming
│   ├── resolve_conflicts.R # Resolve naming conflicts
│   ├── renumber_resource.R # Specifically for sequenced resources
│   └── verify_consistency.R # Verify naming consistency
└── tests/                  # Tests for renaming functions
    ├── test_verify.R       # Test verification functions
    ├── test_rename.R       # Test renaming functions
    └── test_renumber.R     # Test renumbering functions
```

### Main Functions

The module would include these key functions:

1. **verify_unique(new_name)**: Check if a proposed name is already in use
2. **scan_references(resource_name)**: Find all references to a resource
3. **rename_resource(old_name, new_name)**: Perform a safe, atomic rename
4. **renumber_resource(old_id, new_id)**: Specific function for renumbering sequenced resources
5. **update_references(old_name, new_name)**: Update all references after a rename
6. **verify_consistency()**: Verify naming consistency across the system

### Usage Examples

```r
# Simple rename
M05_renaming::rename_resource("old_filename.md", "new_filename.md")

# Renumbering a principle
M05_renaming::renumber_resource("P16", "P07", "app_bottom_up_construction")

# Verify consistency after renaming operations
M05_renaming::verify_consistency()

# Automated batch renumbering from a mapping table
principle_mapping <- tibble(
  old_id = c("P16", "P04", "P08"),
  new_id = c("P07", "P12", "P05"),
  name = c("app_bottom_up_construction", "app_construction", "naming_principles")
)

M05_renaming::batch_renumber(principle_mapping)
```

## Implementation Plan

1. **Create Module Structure**: Set up the directory structure for M05_renaming
2. **Extract Functions**: Extract all procedures from R05 into proper functions
3. **Implement Testing**: Create comprehensive tests for all functions
4. **Update R05**: Convert R05 to a simpler rule that references the module
5. **Create Documentation**: Provide full documentation for the module

## Benefits

1. **Reusability**: The module can be used programmatically instead of just followed manually
2. **Testability**: Functions can be properly tested to ensure reliability
3. **Maintainability**: Modular design makes it easier to update specific components
4. **Automation**: Enables automated renaming operations rather than manual steps
5. **Separation of Concerns**: Separates the rule (what should be done) from the implementation (how to do it)

## Relationship to Existing Principles

This proposal aligns with:

1. **MP16 (Modularity Principle)**: Creates a cohesive module with a well-defined purpose
2. **MP02 (Structural Blueprint)**: Follows the prescribed module structure
3. **MP17 (Separation of Concerns)**: Separates rules from their implementation
4. **P05 (Naming Principles)**: Implements the naming principles in a consistent way

## Conclusion

Converting R05 (Renaming Methods Rule) to a proper module would improve the implementation of renaming operations, provide better reusability, and align more closely with the structural principles of the system. The module would enable programmatic usage of the renaming capabilities while maintaining the original intent of the rule.
