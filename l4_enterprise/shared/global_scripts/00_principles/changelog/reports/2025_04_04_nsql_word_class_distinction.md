---
date: "2025-04-04"
title: "NSQL Word Class Distinction Enhancement"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP01": "Primitive Terms and Definitions"
---

# NSQL Word Class Distinction Enhancement

## Summary

This record proposes enhancing the Natural SQL Language (NSQL) defined in MP24 by formally distinguishing between different word classes, particularly actions and conditions. This classification will improve the language's expressiveness, reduce ambiguity, and enable more precise translation of NSQL statements into implementation languages.

## Current Limitation

While MP24 establishes NSQL as a human-readable meta-language for data transformations, it does not currently provide a formal grammatical structure that distinguishes between different types of operations based on their grammatical role. This can lead to ambiguity in parsing and translating complex expressions.

## Proposed Enhancement

### Word Class System for NSQL

We propose formalizing a grammatical word class system for NSQL with two primary classes initially:

#### 1. Actions

**Definition**: Words or phrases that represent operations to be performed on data.

**Characteristics**:
- Express transformations, calculations, or manipulations
- Typically serve as the main verb of an NSQL statement
- Can be composed in sequences to form operation chains
- Often take parameters or qualifiers

**Examples**:
- `filter`
- `group`
- `calculate`
- `summarize`
- `transform`
- `join`
- `pivot`
- `select`
- `arrange`

#### 2. Conditions

**Definition**: Words or phrases that specify criteria, constraints, or qualifications.

**Characteristics**:
- Express rules for inclusion, exclusion, or modification
- Typically serve as qualifiers or constraints on actions
- Can be combined using logical operators
- Often contain comparative expressions

**Examples**:
- `where`
- `having`
- `if`
- `when`
- `unless`
- `greater than`
- `equals`
- `contains`
- `between`
- `matches`

### Grammatical Structure

The enhanced NSQL would formally define the relationship between these word classes:

```
<statement> ::= <action> [<condition>] [<action> [<condition>]]...

<action> ::= <action_word> <target> [<parameters>]

<condition> ::= <condition_word> <expression>

<expression> ::= <term> <operator> <term> | <term>

<operator> ::= "and" | "or" | "not" | ">" | "<" | "=" | "!=" | "in" | "contains"
```

### Implementation in NSQL Dictionary

The NSQL dictionary (governed by R21) would be enhanced to include word class for each term:

```json
{
  "filter": {
    "word_class": "action",
    "parameters": ["condition"],
    "translation": {
      "R": "filter(%condition%)",
      "SQL": "WHERE %condition%",
      "Python": "filter(lambda x: %condition%)"
    }
  },
  "where": {
    "word_class": "condition",
    "parameters": ["expression"],
    "translation": {
      "R": "%expression%",
      "SQL": "%expression%",
      "Python": "%expression%"
    }
  }
}
```

## Examples with Word Class Distinction

### Simple Example

**NSQL Statement**:
```
filter customers where spend > 1000
```

**With Word Class Identification**:
```
[ACTION:filter] customers [CONDITION:where] spend > 1000
```

### Complex Example

**NSQL Statement**:
```
customers -> filter where country = 'USA' -> group by state -> calculate average_spend = mean(spend) -> arrange by average_spend desc
```

**With Word Class Identification**:
```
customers -> [ACTION:filter] [CONDITION:where] country = 'USA' -> [ACTION:group] [CONDITION:by] state -> [ACTION:calculate] average_spend = mean(spend) -> [ACTION:arrange] [CONDITION:by] average_spend desc
```

## Benefits

1. **Reduced Ambiguity**: Clear distinction between operations and their qualifying conditions
2. **Improved Parsing**: More accurate interpretation of complex expressions
3. **Better Translation**: Clearer mapping to implementation languages
4. **Enhanced Expressiveness**: More nuanced expression of data operations
5. **Learning Assistance**: Clearer structure helps users learn the language more easily

## Further Extensions

While initially focusing on Actions and Conditions, the word class system can be expanded to include:

1. **Entities**: Words representing data sources or collections (e.g., `customers`, `orders`)
2. **Attributes**: Words representing properties of entities (e.g., `name`, `price`, `date`)
3. **Aggregators**: Words representing summary operations (e.g., `sum`, `average`, `count`)
4. **Modifiers**: Words that alter the behavior of actions (e.g., `distinctly`, `recursively`)

## Implementation Plan

1. **Update MP24**: Add word class distinction to the formal definition
2. **Enhance R21**: Modify NSQL Dictionary Rule to include word class
3. **Update Dictionary**: Add word class to all existing NSQL terms
4. **Refine Parser**: Update the NSQL parser to leverage word class information
5. **Update Documentation**: Create examples showing word class usage

## Relationship to MP01 (Primitive Terms and Definitions)

This enhancement relates to MP01 by introducing subtyping into the NSQL language specification. Just as MP01 now recognizes subtypes of temporary files, the NSQL grammar would recognize subtypes of words (word classes). This consistent application of the subtype concept across the system reinforces the hierarchical typing system established in MP01.

## Conclusion

Enhancing NSQL with formal word class distinctions will significantly improve its precision, expressiveness, and practical utility. By distinguishing between actions and conditions at a minimum, we can create a more robust language for expressing data transformations while maintaining the human readability that is central to NSQL's purpose.