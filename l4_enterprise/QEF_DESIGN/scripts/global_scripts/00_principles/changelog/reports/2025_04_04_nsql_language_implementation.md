---
id: "REC-20250404-04"
title: "NSQL Language Implementation"
type: "enhancement"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "MP24": "Natural SQL Language"
  - "MP26": "R Statistical Query Language"
---

# NSQL Language Implementation

## Summary

This record documents the creation of the 16_NSQL_Language directory in global_scripts, which provides a comprehensive implementation of the Natural SQL Language (NSQL) as defined in MP24. The implementation includes the language dictionary, grammar, parsing and translation tools, disambiguation systems, and principles for effective language usage.

## Motivation

The implementation was motivated by the need to:

1. Establish a concrete, structured implementation of the NSQL language
2. Provide tools for parsing, validating, and translating NSQL statements
3. Define clear rules for disambiguation and reference resolution
4. Create guidelines for natural language usage in user interactions
5. Enable the language to evolve through a structured extension process

## Changes Made

### 1. Created Core Language Components

- **dictionary.yaml**: Comprehensive dictionary of NSQL terms, functions, and translations
- **grammar.ebnf**: Formal grammar in Extended Backus-Naur Form
- **nsql.R**: Main interface for NSQL implementation with parsing and translation functions

### 2. Established Disambiguation and Reference Resolution

- **reference_resolution_rule.md**: Rule requiring unambiguous references
- **question_sets.yaml**: Standardized questions for disambiguation
- **natural_language_rule.md**: Rule for using accessible language in user questions
- **language_usage_principle.md**: Principle for context-based terminology selection

### 3. Defined Default Behaviors

- **default_rules.md**: Rules for standard interpretation of common patterns
- Added working context commands (`setwd`, `use schema`)
- Defined standard time ranges, metric definitions, and import behaviors

### 4. Added Implementation Components

- **parsers/**: Framework for NSQL parsing implementations
- **translators/**: Framework for translation to SQL, dplyr, pandas
- **validators/**: Framework for NSQL statement validation
- **extensions/**: Framework for domain-specific extensions

### 5. Added Enhancement Capabilities

- **Hierarchical Table References**: Added dot notation (A.B.C) for nested schemas
- **Role Detection**: Added user role detection for language adaptation
- **Arrow Operator**: Added pipeline-style syntax as alternative to transform-to pattern

### 6. Created Example Collections

- **transform_pattern.nsql**: Examples of transform-to pattern
- **arrow_pattern.nsql**: Examples of arrow operator pattern
- **natural_language_pattern.nsql**: Examples of natural language patterns
- **hierarchical_tables.nsql**: Examples of hierarchical table references
- **working_context.nsql**: Examples of working directory and schema context

## Key Features and Principles

### 1. Reference Resolution Rule

All references in NSQL must be unambiguous. If any ambiguity exists in a reference, the system must query the user for clarification until all ambiguity is resolved. No automatic resolution or assumptions are permitted.

### 2. Natural Language Rule

When asking questions or seeking clarification from users, NSQL implementations must employ familiar, accessible terminology rather than technical jargon. For example, use "dataset" instead of "schema" and "Excel file" instead of ".xlsx".

### 3. Language Usage Principle

The language used in NSQL interactions must adapt to the context, user role, and purpose of the communication. Technical terms are appropriate when explaining implementations, while natural language is preferred for disambiguation.

### 4. Role Detection

Both explicit (direct questions) and implicit (language pattern analysis) methods are used to detect user roles and adjust communication accordingly.

### 5. Working Context Commands

`setwd` and `use schema` commands establish the current working context for file operations and table resolution, respectively.

## Relationship to Other Components

This implementation relates to:

1. **MP24 (Natural SQL Language)**: Provides the concrete implementation of the meta-principle
2. **MP26 (R Statistical Query Language)**: Complements NSQL with statistical operation capabilities
3. **MP25 (AI Communication Meta-Language)**: Leverages meta-language patterns for disambiguation

## Benefits

1. **Complete Implementation**: Provides a comprehensive, structured implementation of NSQL
2. **Clear Rules**: Establishes unambiguous rules for reference resolution and disambiguation
3. **Natural Interactions**: Creates natural, accessible user interactions through language adaptation
4. **Extensibility**: Supports extension to new domains and use cases
5. **Syntax Flexibility**: Offers multiple syntax patterns (transform-to, arrow operator, natural language)

## Next Steps

Future work on the NSQL implementation could include:

1. Complete implementation of parser and translator components
2. Development of testing and validation tools
3. Creation of domain-specific extensions for marketing, finance, etc.
4. Integration with visualization systems for results presentation
5. Development of learning capabilities to improve disambiguation over time

## Conclusion

The 15_NSQL_Language implementation provides a comprehensive framework for the Natural SQL Language, enabling natural, accessible data interactions while maintaining precision and unambiguity. The combination of formal grammar, disambiguation rules, and natural language principles creates a robust system that can evolve to meet emerging needs while preserving core language integrity.
