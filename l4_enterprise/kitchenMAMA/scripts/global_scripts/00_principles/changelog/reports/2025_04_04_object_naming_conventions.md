---
id: "REC-20250404-06"
title: "Object Naming Conventions"
type: "enhancement"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "P14": "Dot Notation Property Access Principle"
  - "R23": "Object Naming Convention"
  - "MP01": "Primitive Terms and Definitions"
---

# Object Naming Conventions

## Summary

This record documents the creation of a consistent object naming system for the precision marketing system. The changes include:

1. Creating P14 (Dot Notation Property Access Principle) to establish dot notation as the standard for hierarchical references
2. Creating R23 (Object Naming Convention) to define specific naming patterns for different object types
3. Establishing type-specific ordering patterns that reflect each object type's purpose
4. Defining standard components and their values for data frames and other objects
5. Adding references to MP01 (Primitive Terms and Definitions) to ensure terminology alignment
6. Updating R23 to fully align with the primitive terms defined in MP01

## Motivation

These changes were motivated by the need to:

1. Address ambiguity in existing naming conventions that used underscores both for major component separation and within component values
2. Create a more consistent and intuitive naming system across the codebase
3. Align object naming with the hierarchical reference pattern used in NSQL
4. Establish clear type-specific naming patterns that reflect each object type's unique characteristics
5. Formalize existing ad-hoc naming practices into a cohesive system
6. Ensure alignment with primitive terms defined in MP01
7. Properly distinguish between variables and constants in accordance with type theory principles

## Changes Made

### 1. Created P14 (Dot Notation Property Access Principle)

- Established dot notation as the standard for hierarchical references
- Defined consistent pattern from general to specific
- Created alignment with NSQL hierarchical references
- Applied the pattern across naming, access, and queries
- Added reference to MP01 for terminological alignment

### 2. Created R23 (Object Naming Convention)

- Defined specific naming patterns for different object types:
  - Data frames: `df.platform.purpose.by_id1.by_id2.by_id3.at_dimension1.at_dimension2.at_dimension3[___identifier]` (identifier optional with triple underscore separator)
  - Functions: `fn.action.subject.qualifier`
  - Models: `mdl.algorithm.target.features`
  - Lists: `lst.category.content.purpose`
  - Vectors: `vec.entity.attribute.filter`
  - Parameters and Default Values: `par.scope.category.name[.default]`
  - Constants: `SCOPE.CATEGORY_NAME` (all uppercase with underscores for word separation)
  - Interfaces: `iface.component.capability`
  - Components: `comp.role.domain.capability`

- Provided detailed component definitions for data frames:
  - platform: amazon, officialwebsite, etc.
  - purpose: sales, product_property, etc.
  - group: by_product_index, by_customer, etc.
  - sliced: at_ALL, at_NY, at_CT, etc.
  - end_time: now, m1year, m1quarter, etc.
  - productlineid: 000, 001, 002, etc.
  - identifier: raw, clean, manual, filtered, joined, dictionary, etc.

- Defined standard type prefixes aligned with MP01:
  - df.: Data frames (Processed Data in MP01)
  - raw.: Raw data
  - fn.: Functions
  - mdl.: Models
  - comp.: Components
  - iface.: Interfaces
  - impl.: Implementations
  - par.: Parameters
  - def.: Default Values
  - const.: Constants
  - mod.: Modules
  - seq.: Sequences
  - deriv.: Derivations

### 3. Added Company-Specific Implementation Support

- Added guidance for company-specific implementations while maintaining common naming patterns
- Demonstrated how module implementations can vary by company while sharing naming conventions
- Applied insights from type theory regarding constants (which remain fixed across companies) and variables (which may vary)

### 4. Updated Examples to Reflect MP01 Terminology

- Rewrote examples using proper MP01 terminology
- Added new examples demonstrating interface/implementation patterns
- Created a data processing pipeline example showing raw data, processed data, parameters, and default values

### 5. Added MP01 Relations Section

- Added detailed explanation of how R23 implements MP01 terminology
- Highlighted categorical distinctions from MP01 (e.g., parameter vs. default value)
- Emphasized the variable/constant distinction in line with type theory

## Impact Assessment

### Benefits

1. **Clarity**: Names clearly convey object purpose and content
2. **Consistency**: Creates a unified naming system across the project
3. **Alignment**: Aligns with NSQL hierarchical references
4. **Disambiguation**: Resolves ambiguity in component separation
5. **Type Clarity**: Makes object types immediately identifiable
6. **Self-Documentation**: Names serve as micro-documentation
7. **Natural Grouping**: Creates logical grouping when sorted alphabetically
8. **Terminology Consistency**: Ensures alignment with primitive terms in MP01
9. **Type Safety**: Promotes type awareness through consistent prefixing
10. **Company Adaptability**: Supports company-specific implementations

### Implications

1. **Codebase Updates**: Existing objects will need to be renamed
2. **Documentation Updates**: Documentation will need to reference the new convention
3. **Validation Implementation**: Validation tools will need to be created
4. **Training**: Developers will need training on the new conventions

## Relationship to Other Components

These changes relate to:

1. **NSQL (MP24)**: Aligns with the hierarchical reference pattern in Natural SQL Language
2. **Separation of Concerns (MP17)**: Supports separation through clear type boundaries
3. **Modularity (MP16)**: Enhances modularity through clear component identification
4. **Primitive Terms (MP01)**: Establishes terminology consistent with foundational definitions

## Conclusion

The creation of P14 (Dot Notation Property Access Principle) and R23 (Object Naming Convention) establishes a comprehensive, consistent naming system for the precision marketing system. By using dot notation for hierarchical references and defining type-specific naming patterns that align with MP01 terminology, these changes create a more intuitive, less ambiguous naming system.

The most recent updates to R23 include:
1. Ensuring full alignment with MP01 primitive terms
2. Properly distinguishing between categories like parameters and default values
3. Differentiating between variables (which can vary by company) and constants (which remain fixed)
4. Adding the "sliced" component to data frame naming to represent geographic or dimensional slices
5. Renaming the "product" component to "identifier" to better reflect its purpose
6. Removing redundant identifiers like "dta" (since objects are already identified as data frames)
7. Adding more descriptive identifiers like "filtered", "joined", and "manual"
8. Supporting combined modifiers with underscore separators (e.g., clean_manual)
9. Making the identifier component optional for streamlined data pipeline naming
10. Introducing triple underscore (___) notation to visually distinguish optional identifiers
11. Providing clear guidance on when to use or omit identifiers
12. Using special UPPERCASE.WITH_UNDERSCORES format for constants to distinguish them clearly
13. Consolidating parameters and default values using a .default suffix instead of a separate prefix
14. Establishing consistent use of dots (.) for component separation and underscores (_) for word separation
15. Reorganizing data frame components into by_id and at_dimension patterns for clearer, more intuitive naming
16. Reorganizing component numbering to accommodate the new components

These updates strengthen the naming convention's theoretical foundation while enhancing its practical utility. The reorganization of data frame components into `by_id` and `at_dimension` patterns creates a more intuitive and flexible structure that clearly separates entities (what we're grouping by) from dimensions (what we're slicing at). This approach makes it easier to understand complex data frame names at a glance.

The consistent distinction between dots for component separation and underscores for word separation creates a clear visual pattern across all naming contexts. Making the identifier component optional provides flexibility for multi-step data processing pipelines, while the distinctive triple underscore separator (___) creates a clear visual distinction for optional components.

The triple underscore approach has a critical functional property: only the part before the triple underscore is used for object identification in loading or processing operations. This means the same base data frame can have multiple versions with different descriptive identifiers (e.g., `df.name___manual`, `df.name___agg`) while still being recognized as the same base object when needed. This approach allows for streamlined naming in most cases while still enabling detailed identification when needed for manually edited data or special processing steps.

The result is a naming convention that enhances code clarity, maintainability, and internal consistency while respecting the foundational terminology established in MP01 and the theoretical insights from type theory.
