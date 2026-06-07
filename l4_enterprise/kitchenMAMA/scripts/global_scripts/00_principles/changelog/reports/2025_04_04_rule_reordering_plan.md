---
date: "2025-04-04"
title: "Rule Reordering Plan"
type: "record"
author: "Claude"
related_to:
  - "P05": "Naming Principles"
---

# Rule Reordering Plan

## Current State

Our rule numbering system currently has several gaps:
- R04-R07: Some rules exist, some don't
- R09-R10: R09 exists, R10 archived
- R14-R25: Some rules exist, some don't
- R16: Missing
- R21-R22: Missing
- R31: Recently added

This inconsistent numbering makes it difficult to understand the rule hierarchy and relationships.

## Proposed Reordering Plan

I propose reordering the rules to eliminate gaps while maintaining logical groupings:

### Group 1: System Organization (R00-R09)
| New ID | Current ID | Title |
|--------|------------|-------|
| R00 | R00 | Directory Structure |
| R01 | R01 | File Naming Convention |
| R02 | R02 | Principle Documentation |
| R03 | R03 | Platform Neutral Code |
| R04 | R04 | App YAML Configuration |
| R05 | R05 | Renaming Methods |
| R06 | R06 | Temporary File Handling |
| R07 | R07 | Module Naming Convention |
| R08 | R08 | Update Script Naming |
| R09 | R09 | Global Scripts Synchronization |

### Group 2: UI and Component Structure (R10-R19)
| New ID | Current ID | Title |
|--------|------------|-------|
| R10 | R11 | UI Server Defaults Triple |
| R11 | R12 | Package Consistency Naming |
| R12 | R13 | Hybrid Sidebar Pattern |
| R13 | R14 | Minimal Modification |
| R14 | R15 | Initialization Sourcing |
| R15 | R17 | UI Hierarchy |
| R16 | R18 | Defaults from Triple |
| R17 | R19 | YAML Parameter Configuration |
| R18 | R20 | Language Standard Adherence |
| R19 | R20 | Pseudocode Standard Adherence |

### Group 3: Object Naming and Structure (R20-R29)
| New ID | Current ID | Title |
|--------|------------|-------|
| R20 | R23 | Object Naming Convention |
| R21 | R24 | Logic Document Creation |
| R22 | R25 | One Function One File |
| R23 | R26 | App Mode Naming Simplicity |
| R24 | R27 | Object File Name Translation |
| R25 | R28 | Type-Token Naming |
| R26 | R29 | Terminology Synonym Mapping |
| R27 | R30 | Type-Token Distinction Application |
| R28 | R31 | Data Frame Creation Strategy |

## Implementation Process

The file renaming should be done in these steps:

1. Create git branch for renaming
2. Copy all files to their new names
3. Update internal references (may require automated search and replace)
4. Update frontmatter in each file
5. Update any external references
6. Remove old files
7. Commit changes with clear explanatory commit message

## Impact Assessment

Benefits:
- Sequential numbering eliminates confusion
- Logical grouping improves discoverability
- Better reveals relationships between rules

Challenges:
- Will require updating references in code and documentation
- Temporary confusion during transition
- Risk of broken links or references

## Recommendation

I recommend proceeding with this reordering to create a more logical and maintainable rule system. The short-term disruption is worth the long-term benefits of a well-organized rule hierarchy.

## Fallback Plan

If the reordering proves too disruptive, we can:
1. Keep current numbering
2. Fill gaps with new rules as they are created
3. Create a master index document that logically groups rules regardless of their numbering
