---
id: "REC-20250403-04"
title: "NSQL Interactive Update Rule Creation"
type: "record"
date_created: "2025-04-03"
date_modified: "2025-04-03"
author: "Claude"
relates_to:
  - "MP24": "Natural SQL Language"
  - "R21": "NSQL Dictionary Rule"
  - "R22": "NSQL Interactive Update Rule"
---

# NSQL Interactive Update Rule Creation

## Summary

This record documents the creation of R22 (NSQL Interactive Update Rule), which establishes a process for analyzing user-identified statements as potential NSQL, disambiguating them when necessary, and adding new patterns to the NSQL dictionary when appropriate. This rule complements R21 (NSQL Dictionary Rule) by enabling NSQL to evolve based on actual usage patterns.

## Motivation

The creation of R22 was motivated by the recognition that:

1. Users naturally express data queries in various formats, some of which could be valid NSQL but don't match the initially defined patterns
2. The boundary between natural language and formal query languages is fluid
3. A mechanism was needed to identify, disambiguate, and standardize these natural expressions
4. The NSQL dictionary should evolve based on actual usage patterns rather than only through formal proposals

The specific insight that prompted this rule was that a statement like "show me sales by region for last quarter" could be considered valid NSQL despite not following the transform-to-as pattern, provided it can be unambiguously interpreted and translated.

## Changes Made

### Created R22 (NSQL Interactive Update Rule)

1. **User Interaction Process**:
   - Defined how users can identify potential NSQL statements
   - Established a workflow for interaction when disambiguating statements
   - Created a feedback loop for refining interpretations

2. **Ambiguity Analysis Framework**:
   - Provided a structured approach to identifying ambiguities
   - Defined a process for resolving ambiguities through user interaction
   - Included examples of ambiguous and unambiguous statements

3. **Dictionary Update Process**:
   - Established criteria for when a pattern should be added to the dictionary
   - Defined how patterns are extracted from specific statements
   - Integrated with the formal dictionary update process from R21

4. **Natural Expression Patterns**:
   - Identified categories of natural query expressions (imperative, time-based, comparative, analysis)
   - Provided examples of patterns in each category
   - Created a framework for translating these patterns to formal NSQL

## Impact Assessment

### Benefits

1. **User-Centered Evolution**: Allows NSQL to evolve based on how users naturally express queries
2. **Increased Accessibility**: Makes NSQL more accessible to non-technical users
3. **Pattern Discovery**: Provides a mechanism for discovering useful natural expression patterns
4. **Ambiguity Management**: Establishes a structured approach to managing ambiguity
5. **Learning System**: Creates a foundation for NSQL to improve through use

### Implications

1. **AI Dependency**: Creates a dependency on AI systems for disambiguation and pattern extraction
2. **Dictionary Complexity**: Increases the complexity of the NSQL dictionary as it incorporates more patterns
3. **Governance Challenges**: Requires careful governance to maintain consistency as the language evolves
4. **Implementation Work**: Necessitates development of disambiguation and translation systems

## Relationship to Other Changes

R22 complements the previously created:

1. **MP24 (Natural SQL Language)**: Extends the language by incorporating more natural expression patterns
2. **R21 (NSQL Dictionary Rule)**: Provides an alternative, interactive path to dictionary updates

Together, these three documents establish a comprehensive framework for defining, using, and evolving NSQL:
- MP24 defines the core language and purpose
- R21 establishes the dictionary and formal update process
- R22 enables interactive disambiguation and evolution

## Conclusion

The creation of R22 (NSQL Interactive Update Rule) enhances the NSQL framework by recognizing the fluid boundary between natural language and formal query languages. By establishing a process for analyzing, disambiguating, and incorporating natural expression patterns, this rule ensures that NSQL can evolve to better match user preferences while maintaining its precision and translatability.

This approach represents a shift from a purely top-down language definition to a hybrid model that combines formal definition with bottom-up evolution based on actual usage. This balance will help make NSQL both powerful and accessible, optimizing for both human readability and machine interpretability.
