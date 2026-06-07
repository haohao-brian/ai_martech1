---
id: "REC-20250403-03"
title: "NSQL Dictionary Rule Creation"
type: "record"
date_created: "2025-04-03"
date_modified: "2025-04-03"
author: "Claude"
relates_to:
  - "MP24": "Natural SQL Language"
  - "R21": "NSQL Dictionary Rule"
---

# NSQL Dictionary Rule Creation

## Summary

This record documents the creation of R21 (NSQL Dictionary Rule) as a companion to MP24 (Natural SQL Language). The rule establishes an extensible dictionary as the authoritative reference for NSQL syntax, semantics, and implementation translations.

## Motivation

While MP24 defines the overall structure and purpose of the Natural SQL Language, a specific rule was needed to:

1. Establish a concrete, standardized dictionary of NSQL terms and functions
2. Define a structured process for extending and maintaining this dictionary
3. Provide clear examples of translations to implementation languages
4. Ensure consistent application and evolution of NSQL across the system

## Changes Made

### Created R21 (NSQL Dictionary Rule)

1. **Core Structure and Content Requirements**:
   - Defined the required categories of dictionary entries (structural keywords, aggregate functions, etc.)
   - Specified the required attributes for each entry (definition, translations, examples, etc.)

2. **Dictionary Update Process**:
   - Established a formal four-phase process: Proposal, Review, Implementation, Notification
   - Provided specific requirements for each phase
   - Included versioning guidelines following semantic versioning principles

3. **Initial Dictionary Contents**:
   - Defined initial set of structural keywords (transform, to, as, etc.)
   - Defined initial set of aggregate functions (sum, count, average, etc.)
   - Defined initial set of logical operators (and, or, not, etc.)

4. **Extension Example and Translations**:
   - Provided a detailed example of adding a new function (median)
   - Included comprehensive examples showing NSQL statements and their translations to SQL and dplyr

5. **Maintenance Requirements**:
   - Established requirements for regular review
   - Defined backward compatibility policies
   - Specified documentation requirements

## Impact Assessment

### Benefits

1. **Standardization**: Establishes a clear standard for NSQL expressions
2. **Extensibility**: Provides a structured process for extending NSQL in a controlled way
3. **Implementation Guidance**: Offers clear guidance on translating NSQL to implementation languages
4. **Quality Control**: Creates a reference for validating NSQL expressions
5. **Consistency**: Ensures consistent application of NSQL across the system

### Implications

1. **Maintenance Commitment**: Requires ongoing maintenance of the dictionary
2. **Tool Development**: Suggests need for tools to validate against the dictionary
3. **Training Requirements**: Creates need for training on dictionary use and extension
4. **Implementation Work**: Implies development work to implement translation capabilities

## Conclusion

The creation of R21 (NSQL Dictionary Rule) complements MP24 (Natural SQL Language) by establishing concrete standards and processes for the NSQL dictionary. This rule ensures that NSQL has a solid foundation of well-defined terms and functions, along with a clear process for evolution and translation to implementation languages.

By maintaining a living, extensible dictionary as specified in this rule, the precision marketing system will be able to leverage NSQL effectively as a bridge between natural language and technical implementations, improving communication and implementation of data operations across the organization.
