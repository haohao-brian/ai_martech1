---
id: "REC-20250404-08"
title: "One Function, One File Rule"
type: "enhancement"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "R25": "One Function, One File Rule"
  - "MP17": "Separation of Concerns"
  - "MP18": "Don't Repeat Yourself"
---

# One Function, One File Rule

## Summary

This record documents the creation of R25 (One Function, One File Rule) to formalize the practice of having each function in its own dedicated file. The rule was implemented along with a reference implementation in the object identification utilities.

## Motivation

The creation of this rule was motivated by:

1. The need for better organization and maintainability in the codebase
2. A desire to reduce merge conflicts when multiple developers work on the system
3. The observation that functions in separate files are easier to reuse
4. The need for clearer documentation and testing of individual functions
5. Alignment with the separation of concerns principle (MP17)

## Changes Made

### 1. Created R25 (One Function, One File Rule)

- Established the requirement that each function should be in its own file
- Defined clear file naming conventions that match function names
- Provided guidance for structuring function files with comprehensive documentation
- Outlined how to handle collections of related functions
- Specified reasonable exceptions to the rule

### 2. Implemented Object Identification Utilities Following the Rule

- Created a directory structure at `04_utils/object_id/`
- Implemented a main module file `object_identification.R` that sources all functions
- Created a `functions` subdirectory containing individual function files:
  - `get_rigid_id.R`
  - `get_descriptors.R`
  - `load_latest.R`
  - `load_version.R`
  - `list_versions.R`
  - `find_data_file.R`
  - `list_data_files.R`
  - `save_version.R`
- Added comprehensive documentation to each function file

### 3. Detailed Documentation Requirements

- Provided templates for function files showing required documentation
- Added examples of properly structured function files
- Created guidelines for collection main files

## Impact Assessment

### Benefits

1. **Improved Maintainability**: Each function can be maintained independently
2. **Better Version Control**: Changes to functions are clearly tracked
3. **Easier Testing**: Functions can be tested in isolation
4. **Better Organization**: Project structure clearly reflects functionality
5. **Enhanced Reusability**: Single-purpose files are easier to reuse
6. **Reduced Merge Conflicts**: Developers are less likely to conflict when editing different functions
7. **Focused Code Reviews**: Reviews can focus on specific functionality

### Implications

1. **More Files**: The codebase will have more files, but better organization
2. **Refactoring Needed**: Existing code will need to be gradually refactored
3. **Initial Overhead**: Creating separate files requires more initial setup
4. **Directory Structure**: Need for thoughtful directory organization

## Relationship to Other Principles

This rule relates to:

1. **MP17 (Separation of Concerns)**: By isolating each function, concerns are naturally separated
2. **MP18 (Don't Repeat Yourself)**: Functions in individual files are easier to reuse without duplication
3. **P01 (Script Separation)**: Extends the concept of separation to the function level

## Implementation in Object Identification Utilities

The object identification utilities serve as a reference implementation for this rule:

1. The main file `object_identification.R` acts as an entry point and loader
2. Each function is in its own file with comprehensive documentation
3. The file structure reflects the logical organization of the functionality
4. The implementation follows all guidance provided in the rule

## Conclusion

The One Function, One File Rule (R25) formalizes a best practice that will significantly improve the organization, maintainability, and quality of the codebase. By providing clear guidelines and a reference implementation, this rule sets a standard that will benefit all future development in the precision marketing system.

The object identification utilities demonstrate the practical application of this rule and provide immediate value to the project through their functionality for managing the naming convention's optional descriptors with triple underscores.
