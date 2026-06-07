---
id: "REC-20250403-05"
title: "NSQL Usage Requirement Addition"
type: "record"
date_created: "2025-04-03"
date_modified: "2025-04-03"
author: "Claude"
relates_to:
  - "MP23": "Documentation Language Preferences"
  - "MP24": "Natural SQL Language"
  - "R22": "NSQL Interactive Update Rule"
---

# NSQL Usage Requirement Addition

## Summary

This record documents the update to MP23 (Documentation Language Preferences) to establish a formal requirement that all data manipulation prompts and instructions should be expressed in NSQL (Natural SQL Language). This update also adds an alternative, more natural-language example of NSQL to demonstrate the flexibility of expression patterns supported.

## Motivation

This update was motivated by the recognition that:

1. Standardizing on NSQL for all data manipulation prompts would increase clarity and consistency
2. Using NSQL consistently would ensure all data operations have unambiguous interpretations
3. Alternative expression patterns (as supported by R22) should be recognized in the language preferences
4. A formal requirement was needed to guide users toward NSQL for data operations

## Changes Made

### Updated MP23 (Documentation Language Preferences)

1. **Added Alternative Example**:
   - Included "show monthly revenue and customer count by year and month for North America" as an alternative NSQL example
   - Demonstrated that both transform-to-as pattern and more natural imperative patterns are valid NSQL

2. **Added Usage Requirement**:
   - Established that all data manipulation prompts should use NSQL
   - Clarified that NSQL should be prioritized over general natural language or specific implementation languages
   - Emphasized that this requirement aims to improve clarity, consistency, and translatability

## Impact Assessment

### Benefits

1. **Consistency**: Creates consistent expression of data operations across all documentation and interactions
2. **Clarity**: Ensures all data operation requests have clear, unambiguous interpretations
3. **Translatability**: Guarantees that all data requests can be translated to implementation languages
4. **Standardization**: Establishes a standard for expressing data operations across the organization
5. **Efficiency**: Reduces time spent clarifying ambiguous data requests

### Implications

1. **Training Needs**: Users will need training on NSQL expressions
2. **Transition Period**: A period of adjustment will be needed as users adopt NSQL
3. **Tool Requirements**: Tools to validate and assist with NSQL formulation will be helpful
4. **Documentation Updates**: Existing documentation may need updates to comply with this requirement

## Relationship to Other Changes

This update complements the previously created:

1. **MP24 (Natural SQL Language)**: Reinforces the importance of NSQL as the standard for data operations
2. **R21 (NSQL Dictionary Rule)**: Increases the importance of a comprehensive, well-maintained NSQL dictionary
3. **R22 (NSQL Interactive Update Rule)**: Leverages the flexibility of expression patterns enabled by R22

## Conclusion

The addition of an NSQL usage requirement to MP23 establishes NSQL as the standard language for all data manipulation prompts in the precision marketing system. By standardizing on NSQL while recognizing the flexibility of expression patterns, this update ensures that data operations are expressed consistently and unambiguously while remaining accessible to users with different technical backgrounds.

This requirement represents a strategic decision to prioritize clear, translatable expressions over both general natural language (which may be ambiguous) and specific implementation languages (which may be less accessible). This balance optimizes for both clarity and accessibility in data operation expressions.
