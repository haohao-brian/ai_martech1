---
id: "REC-20250403-01"
title: "Language Standard Adherence Restructuring"
type: "record"
date_created: "2025-04-03"
date_modified: "2025-04-03"
author: "Claude"
relates_to:
  - "P13": "Language Standard Adherence Principle"
  - "R20": "Pseudocode Standard Adherence Rule"
  - "MP22": "Pseudocode Conventions"
  - "MP20": "Principle Language Versions"
  - "MP23": "Documentation Language Preferences"
---

# Language Standard Adherence Restructuring

## Summary

This record documents the restructuring of the language standard adherence guidance in the principles system. The restructuring involved:

1. Converting the general R20 (Language Standard Adherence Rule) to P13 (Language Standard Adherence Principle)
2. Creating a new, more specific R20 (Pseudocode Standard Adherence Rule) focused on requiring pseudocode to follow the conventions in MP22

## Motivation

The restructuring was motivated by the observation that "pseudocode should be written in the language in MP22" should be its own specific rule, while the general requirement for language standard adherence is more appropriate as a principle that can spawn multiple specific rules.

## Changes Made

### 1. Created P13 (Language Standard Adherence Principle)

- Established a principle-level requirement that all formal language expressions must adhere to their respective standards
- Defined conceptual framework for language standard adherence
- Provided implementation guidelines for standard recognition, adherence requirements, validation, and handling non-standard expressions
- Included examples of adherent and non-adherent expressions for different formal languages
- Addressed common challenges and their solutions
- Established relationship to other principles (MP20, MP23, P10)
- Noted that specific rules would derive from this principle

### 2. Created R20 (Pseudocode Standard Adherence Rule)

- Established a specific rule-level requirement that all pseudocode must strictly adhere to MP22
- Defined detailed implementation requirements for syntax, control structures, documentation, and domain-specific extensions
- Provided verification methods for ensuring adherence
- Included examples of adherent and non-adherent pseudocode
- Addressed common errors and their solutions
- Established relationship to relevant principles (P13, MP22, MP23)

## Impact Assessment

### Benefits

1. **Improved Hierarchical Structure**: The restructuring better aligns with the MP/P/R framework, with principles providing general guidance and rules giving specific directives
2. **Clearer Requirements**: The separation makes it clearer that pseudocode must follow MP22 while creating a framework for other language standards
3. **Extensibility**: The structure allows for additional rules for other formal languages to be added in the future
4. **Consistent Terminology**: The restructuring ensures consistent use of terminology across the principle system

### Implications

1. **Documentation Updates**: Any references to R20 as a general language standard rule will need to be updated to reference P13
2. **Training**: Contributors will need to be aware of the distinction between the general principle (P13) and specific rules (R20)
3. **Future Rules**: New rules for other formal languages should follow the pattern established by R20

## Conclusion

The restructuring of language standard adherence guidance into a principle (P13) and a specific rule (R20) has created a more robust framework for ensuring consistent use of formal languages in the precision marketing system. This structure better supports the enforcement of standards while allowing for extensibility as new language standards emerge.
