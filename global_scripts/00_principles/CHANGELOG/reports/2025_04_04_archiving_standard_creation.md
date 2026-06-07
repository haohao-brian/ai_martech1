---
date: "2025-04-04"
title: "Creation of Archiving Standard Rule"
type: "record"
author: "Claude"
related_to:
  - "R32": "Archiving Standard"
  - "MP05": "Instance vs. Principle"
  - "M00": "Renaming Module"
---

# Creation of Archiving Standard Rule

## Summary

This record documents the creation of R32 (Archiving Standard), which establishes formal guidelines for archiving deprecated or superseded resources in the precision marketing system. The rule standardizes the archive location, metadata requirements, content structure, and implementation processes for all archived content.

## Motivation

The creation of this rule was motivated by:

1. The need to establish a consistent approach to archiving across the system
2. Recent archiving of R05 (renamed to M05) and R10 (split into R23 and R31)
3. The lack of formal guidelines for handling deprecated resources
4. Inconsistent archiving practices observed in the system

## Key Provisions

### 1. Standard Archive Location

The rule establishes `/update_scripts/global_scripts/99_archive/` as the standard location for all archived content. This ensures that whenever the term "archive" is used in documentation or discussions, it refers specifically to this location.

### 2. Metadata and Content Structure

The rule defines specific requirements for:
- Metadata additions (archived status, date, reason)
- Content structure with clear archiving notices
- Preservation of original content for historical reference

### 3. Archive Types and Naming

The rule provides naming conventions for different types of archived resources:
- Rules: `R[number]_[name]_archived.md`
- Principles: `P[number]_[name]_archived.md`
- Meta-Principles: `MP[number]_[name]_archived.md`
- Modules: `M[number]_[name]_archived/`

### 4. Implementation Process

The rule describes how to:
- Use the M05_renaming module for archiving
- Update references to archived resources
- Document the archiving process

## Implementation Status

As part of creating this rule:

1. Updated MP05 (Instance vs. Principle) to include archive location
2. Applied the archiving standard to R05 and R10
3. Created proper archive notices in the archived files
4. Ensured archived files have correct metadata

## Benefits

The R32 rule provides several benefits:

1. **Consistency**: Ensures a uniform approach to archiving
2. **Clarity**: Makes it immediately clear what "archive" means
3. **Traceability**: Maintains links between archived and current resources
4. **Preservation**: Ensures historical information is not lost
5. **Organization**: Keeps the active principles directory clean

## Relationship to Other Components

This rule:
1. Implements MP05 (Instance vs. Principle) by providing a clear separation between active and archived content
2. Supports M05 (Renaming Module) by defining standards for the module to follow when archiving resources
3. Complements the overall documentation organization strategy

## Conclusion

The creation of the Archiving Standard rule fills an important gap in the system's documentation management. By providing clear guidelines for handling deprecated resources, it ensures that the system remains well-organized while preserving historical information for reference.
