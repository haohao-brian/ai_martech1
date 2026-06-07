# Specialized Natural SQL Language (SNSQL) Meta-Principle Creation

## Overview

Created MP27: Specialized Natural SQL Language (SNSQL) Meta-Principle to formalize project-specific commands and idioms that extend the Natural SQL Language.

## Motivation

The project has developed numerous project-specific conventions, patterns, and workflows that would benefit from standardized language representation. While NSQL (MP24) provides a solid foundation for general data operations, there's a need to capture project-specific knowledge and operations in a structured, executable form.

Examples of these idioms include:
- Archiving files to specific locations with project-standard commit messages
- Consolidating redundant functionality with backward compatibility
- Adding locale support following project internationalization conventions
- Creating scripts with standardized naming conventions (like numbered prefixes "301g_")

MP27 addresses this need by defining Specialized NSQL (SNSQL) as an extension to NSQL that captures these project-specific idioms.

## Changes Made

1. Created new meta-principle `MP27_specialized_natural_sql_language.md` with:
   - Core principle definition
   - Conceptual framework for project-specific idioms
   - Examples of SNSQL commands and their implementations
   - Implementation guidelines for command structure
   - Integration approach with base NSQL
   - Benefits and limitations
   - Relationship to other principles

2. Established relationships with:
   - MP24: Natural SQL Language (derives_from)
   - MP25: AI Communication Meta-Language (derives_from)
   - R28: Archiving Standard (influences)
   - R10: Package Consistency Naming (influences)

## Implementation Details

MP27 defines SNSQL as a project-specific extension to NSQL with:

1. **Project Idioms**: Commands that encapsulate technical steps following project conventions
2. **Command Structure**: Consistent syntax for commands (`<action> <target> [<preposition> <parameter>]*`)
3. **Context Sensitivity**: Commands that are interpreted based on project scope and state
4. **Documentation Guidelines**: Approach for documenting project-specific commands

Example commands include:
- `archive file "/path/to/file.R" to "global_scripts/99_archive"`
- `consolidate function "readYamlConfig" into "load_app_config"`
- `create update script "process_transaction_history" for "global_scripts/01_db" following numbered prefix convention`
- `create module script "customer_profile_analysis" in "M15_customer_analytics" with UI, Server, and Defaults files`
- `add locale "fr_FR.UTF-8" to terminology dictionary`

## Expected Impact

MP27 will:
1. Improve knowledge sharing by formalizing project-specific operations
2. Enhance consistency in how common tasks are performed
3. Reduce learning curve for new team members by making project conventions explicit
4. Enable more efficient development workflows through standardized commands
5. Provide a framework for documenting and evolving project-specific idioms

## Next Steps

1. Define a core set of SNSQL commands for common project operations
2. Create implementation scripts for these commands
3. Document the commands following the SNSQL guidelines
4. Integrate SNSQL with existing NSQL implementations
5. Develop a testing approach for SNSQL commands