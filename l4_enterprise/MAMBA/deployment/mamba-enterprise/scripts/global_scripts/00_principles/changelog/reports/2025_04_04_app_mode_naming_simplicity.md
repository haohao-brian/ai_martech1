---
id: "REC-20250404-09"
title: "App Mode Naming Simplicity Rule"
type: "enhancement"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "R26": "App Mode Naming Simplicity Rule"
  - "R23": "Object Naming Convention"
  - "MP03": "Operating Modes"
---

# App Mode Naming Simplicity Rule

## Summary

This record documents the creation of R26 (App Mode Naming Simplicity Rule), which requires that all data objects in APP_MODE use only rigid identifiers without optional descriptors. This rule ensures consistency, predictability, and eliminates ambiguity in the application runtime environment.

## Motivation

The creation of this rule was motivated by:

1. The need for a clean, unambiguous data namespace in the application runtime environment
2. The desire to simplify code and improve reliability in APP_MODE
3. The recognition that multiple versions of data objects, while valuable in development, create unnecessary complexity in production
4. The importance of having a deterministic process for selecting canonical versions of data objects
5. The alignment with operating mode separation principles in MP03

## Changes Made

### 1. Created R26 (App Mode Naming Simplicity Rule)

- Established that in APP_MODE, all data objects must use only rigid identifiers without optional descriptors
- Defined requirements for canonical version selection when transitioning from UPDATE_MODE to APP_MODE
- Outlined two implementation approaches: pre-processing and aliasing
- Provided concrete examples of APP_MODE data preparation and access
- Explained the relationship to other principles, especially R23 and MP03

### 2. Defined Canonical Version Selection Process

- Established that the selection process must be deterministic
- Provided prioritization guidelines:
  - Prefer manually edited versions when available
  - Prefer fully processed versions when no manual version exists
  - Use latest versions when no clear qualitative distinction exists
- Required that the selection process be documented and consistent

### 3. Specified Implementation Mechanisms

- **Pre-processing Approach**: Creating canonical versions without descriptors before APP_MODE initialization
- **Aliasing Approach**: Creating aliases in APP_MODE environment that point to canonical versions
- Provided code examples for both approaches

## Impact Assessment

### Benefits

1. **Simplicity**: Simplifies data access patterns in APP_MODE
2. **Reliability**: Eliminates ambiguity about which version is used
3. **Performance**: Reduces lookup overhead in data loading functions
4. **Clarity**: Makes application code cleaner and more maintainable
5. **Error Prevention**: Prevents accidental use of non-canonical data versions
6. **Mode Distinction**: Strengthens the separation between development and production environments

### Implications

1. **Transition Process**: Requires a well-defined process for transitioning from UPDATE_MODE to APP_MODE
2. **Version Selection**: Necessitates clear criteria for selecting canonical versions
3. **Documentation**: Requires documentation of which version was selected as canonical
4. **Tooling**: May require additional tools for managing the transition process

## Relationship to Other Components

This rule relates to:

1. **R23 (Object Naming Convention)**: Restricts the full application of R23 in APP_MODE by prohibiting optional descriptors
2. **MP03 (Operating Modes)**: Defines specific data object handling for APP_MODE
3. **P04 (App Construction Principles)**: Ensures consistent and predictable data access patterns
4. **P12 (App R is Global)**: Standardizes naming in APP_MODE global namespace

## Conclusion

The App Mode Naming Simplicity Rule (R26) creates a clear distinction between the flexible, version-rich development environment (UPDATE_MODE) and the streamlined, deterministic production environment (APP_MODE). By removing optional descriptors in APP_MODE, this rule significantly improves code clarity, reliability, and maintainability.

This rule complements the Object Naming Convention (R23) by providing specific guidance for how the naming convention should be applied in different operating modes, strengthening the overall system architecture.
