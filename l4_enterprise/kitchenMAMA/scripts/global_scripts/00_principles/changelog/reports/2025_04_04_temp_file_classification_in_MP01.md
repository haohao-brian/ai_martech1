---
date: "2025-04-04"
title: "Temporary File Classification Enhancement for MP01"
type: "record"
author: "Claude"
related_to:
  - "MP01": "Primitive Terms and Definitions"
  - "R05": "Temporary File Handling"
  - "R28": "Archiving Standard"
---

# Temporary File Classification Enhancement for MP01

## Summary

This record proposes enhancements to MP01 (Primitive Terms and Definitions) to formalize temporary file classifications and introduce the concept of subtypes. It defines two primary resolution actions (archive and delete) and categorizes temporary files into four subtypes, each with a prescribed resolution action.

## Motivation

The current definitions in MP01 lack sufficient granularity to distinguish between different types of temporary files that require different handling approaches. Furthermore, the concept of "subtype" is needed to express hierarchical type relationships more precisely than the current type-token distinction allows.

## Proposed Additions to MP01

### New Primitive Concepts

#### 1. Subtype

**Definition**: A subtype is a specialization of a type that inherits all characteristics of the parent type while adding specific differentiating attributes. Subtypes form a hierarchical relationship with their parent type.

**Characteristics**:
- Inherits all properties of the parent type
- Adds specific distinguishing attributes or behaviors
- Has an "is-a" relationship with the parent type
- May have specialized handling or processing requirements

**Distinction from Type-Token**:
- Type-Token distinguishes between a category and its instances
- Subtype-Type distinguishes between a general category and its specialized subcategories

**Example**:
- "Mammal" is a subtype of "Animal"
- "Integer" is a subtype of "Number"
- "Temporary File" is a type, with various subtypes

#### 2. Resolution Actions

**Definition**: Standard operations performed on temporary resources to determine their final disposition. The two primary resolution actions are:

##### Archive
**Definition**: The process of preserving a resource in the designated archive location (99_archive) for historical reference while removing it from active use.

**Characteristics**:
- Resource is moved to the archival location
- Resource is renamed with appropriate suffix (_archived)
- Metadata is added to indicate archival status and reason
- Resource remains accessible for historical reference
- A record is created documenting the archiving decision

##### Delete
**Definition**: The process of completely removing a resource after documenting its existence when appropriate.

**Characteristics**:
- Resource's existence is documented if historically relevant
- Resource is completely removed from the system
- No copy is preserved in the archive
- Reference to the resource may be maintained in operation records

### Temporary File Type Hierarchy

#### Temporary File (Type)
**Definition**: A file intended to exist for a limited time period rather than as a permanent part of the system.

**Subtypes**:

##### 1. Over-Versioned Files
**Definition**: Files representing valid historical versions that exceed needed retention.
**Characteristics**: Contain potentially valuable historical information but create unnecessary versioning complexity.
**Examples**: Multiple `.bak` files of the same resource, accumulated historical exports.
**Resolution Action**: ARCHIVE
**Rationale**: These files contain valid historical information that may be valuable for future reference or understanding system evolution.

##### 2. Unnecessary Files
**Definition**: Files that no longer serve any purpose in the current system.
**Characteristics**: Content is entirely superseded with no historical or reference value.
**Examples**: Intermediate calculation files, temporary extracts used for one-time processing.
**Resolution Action**: DELETE
**Rationale**: These files provide no ongoing value and would only create clutter in the archive.

##### 3. Transitional Files
**Definition**: Files intended to exist temporarily during a specific operation.
**Characteristics**: Created for a specific process, expected to be transformed or removed afterward.
**Examples**: Import staging files, compiler intermediate files, temporary directories created during operations.
**Resolution Action**: DELETE
**Rationale**: These files are purely operational artifacts with no inherent informational value beyond the operation itself.

##### 4. Draft/Working Files
**Definition**: Incomplete versions of resources still under active development.
**Characteristics**: Intentionally unfinished, expected to evolve into permanent resources.
**Examples**: Draft documentation, experimental code branches, work-in-progress designs.
**Resolution Action**: ARCHIVE
**Rationale**: These files represent developmental thinking and may provide valuable context for understanding design decisions.

## Implementation in Type System

The enhanced type system in MP01 will now reflect these hierarchical relationships:

```
Type
├── File
│   ├── Permanent File
│   └── Temporary File
│       ├── Over-Versioned File (→ ARCHIVE)
│       ├── Unnecessary File (→ DELETE)
│       ├── Transitional File (→ DELETE)
│       └── Draft/Working File (→ ARCHIVE)
```

## Impact on R05 and R28

This enhancement to MP01 will provide the foundational vocabulary for updating:

1. **R05 (Temporary File Handling)**:
   - Will reference these subtypes explicitly
   - Will prescribe specific handling procedures for each subtype
   - Will link each subtype to its appropriate resolution action

2. **R28 (Archiving Standard)**:
   - Will clarify that only certain subtypes of temporary files (Over-Versioned, Draft/Working) should be archived
   - Will establish specific archiving procedures for each archivable subtype
   - Will specify metadata requirements for archived temporary files

## Examples in Code Documentation

```r
# Example documentation for file types

# Over-Versioned File - ARCHIVE
# backup_2025_04_01.md.bak - Previous version from significant system update
# Resolution: Archive to 99_archive with filename and changelog

# Unnecessary File - DELETE
# temp_calculations_for_report.csv - Generated during report production
# Resolution: Document generation in operation record, delete file

# Transitional File - DELETE
# import_staging/ - Temporary directory for data import
# Resolution: Document in operation log, delete after import completion

# Draft/Working File - ARCHIVE
# draft_data_contract.md - Preliminary data contract document
# Resolution: Archive with draft status clearly marked, link to final version
```

## Conclusion

Enhancing MP01 with the concept of subtypes and specific temporary file classifications creates a more precise vocabulary for discussing and handling different kinds of temporary files. This enhancement enables more accurate implementation guidance in rules like R05 and R28, leading to better system organization and appropriate preservation of historically valuable information.