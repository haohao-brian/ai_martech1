---
date: "2025-04-04"
title: "Complete NSQL Word Class System"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP01": "Primitive Terms and Definitions"
  - "R19": "Object Naming Convention"
---

# Complete NSQL Word Class System

## Summary

This record proposes a comprehensive word class system for the Natural SQL Language (NSQL) defined in MP24. Building on the initial distinction between actions and conditions, this enhancement adds the critical "path" word class and provides a complete grammatical framework for NSQL.

## Extended Word Class System

### 1. Actions

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

### 2. Conditions

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

### 3. Paths

**Definition**: Words or expressions that identify the location of data objects, files, or resources.

**Characteristics**:
- Reference specific data objects, files, or directories
- Can be absolute or relative
- May use dot notation for hierarchical access
- May include access modifiers or specifiers

**Examples**:
- `df.amazon.sales.by_product` (data frame path)
- `/data/exports/` (directory path)
- `customer.name` (attribute access path)
- `transactions[3].amount` (indexed path)
- `'../reference/lookup.csv'` (relative file path)

**Subclasses of Paths**:

1. **DataObjectPath**: Paths to data objects using dot notation (e.g., `df.amazon.sales`)
2. **FilePath**: Paths to physical files (e.g., `'/data/exports/report.csv'`)
3. **AttributePath**: Paths to attributes within objects (e.g., `customer.name`)
4. **IndexedPath**: Paths including array/list indexing (e.g., `products[2]`)
5. **RelativePath**: Paths specified relative to current context (e.g., `'../data'`)

### Additional Word Classes

#### 4. Entities

**Definition**: Words representing data sources, collections, or tables.

**Examples**: `customers`, `orders`, `products`, `transactions`

#### 5. Attributes

**Definition**: Words representing properties or fields of entities.

**Examples**: `name`, `price`, `date_created`, `status`

#### 6. Aggregators

**Definition**: Words representing summary or grouping operations.

**Examples**: `sum`, `average`, `count`, `median`, `max`

#### 7. Modifiers

**Definition**: Words that alter the behavior of actions.

**Examples**: `distinctly`, `recursively`, `conditionally`, `temporarily`

#### 8. Connectors

**Definition**: Words that join operations or conditions.

**Examples**: `and`, `or`, `then`, `otherwise`, `->` (arrow operator)

## Grammatical Structure

The enhanced NSQL would formally define the relationship between these word classes:

```
<statement> ::= <source_expression> [<operation_chain>]

<source_expression> ::= <path> | <entity> | <subquery>

<operation_chain> ::= <operation> [<operation_chain>]

<operation> ::= <connector> <action> [<condition>] [<parameters>]

<parameters> ::= <parameter> [, <parameters>]

<parameter> ::= <attribute> | <value> | <path> | <expression>

<condition> ::= <condition_word> <expression>

<expression> ::= <term> <operator> <term> | <term>

<term> ::= <attribute> | <value> | <path> | <aggregator>(<attribute>)

<path> ::= <dataobject_path> | <file_path> | <attribute_path> | <indexed_path>

<dataobject_path> ::= <identifier>[.<identifier>]...

<attribute_path> ::= <entity>.<attribute>

<indexed_path> ::= <path>[<index>]

<operator> ::= "and" | "or" | "not" | ">" | "<" | "=" | "!=" | "in" | "contains"
```

## Integration with R19 (Object Naming Convention)

The Path word class integrates directly with R19's object naming convention:

1. **Data Frame Paths**: Align with the data frame naming pattern in R19:
   ```
   df.platform.purpose.by_id1.by_id2.by_id3.at_dimension1.at_dimension2.at_dimension3
   ```

2. **Function Paths**: Align with function naming in R19:
   ```
   dt.purpose
   calc.purpose
   util.purpose
   ```

3. **Module Paths**: Align with module naming conventions:
   ```
   mod.role.domain.capability
   ```

This alignment ensures that NSQL paths are consistent with the broader naming conventions established in R19, creating a cohesive system across all aspects of the codebase.

## Examples with Complete Word Class Identification

### Example 1: Data Frame Transformation

**NSQL Statement**:
```
df.amazon.sales -> filter where date >= '2025-01-01' -> group by product_id -> calculate total_sales = sum(amount)
```

**With Word Class Identification**:
```
[PATH:df.amazon.sales] [CONNECTOR:->] [ACTION:filter] [CONDITION:where] [ATTRIBUTE:date] >= [VALUE:'2025-01-01'] [CONNECTOR:->] [ACTION:group] [CONDITION:by] [ATTRIBUTE:product_id] [CONNECTOR:->] [ACTION:calculate] [ATTRIBUTE:total_sales] = [AGGREGATOR:sum]([ATTRIBUTE:amount])
```

### Example 2: File Processing

**NSQL Statement**:
```
transform '/data/exports/sales.csv' to df.processed.sales as
  select product_id, customer_id, amount, date
  where date between '2025-01-01' and '2025-03-31'
  calculate revenue = price * quantity
```

**With Word Class Identification**:
```
[ACTION:transform] [PATH:'/data/exports/sales.csv'] [CONNECTOR:to] [PATH:df.processed.sales] [CONNECTOR:as]
  [ACTION:select] [ATTRIBUTE:product_id], [ATTRIBUTE:customer_id], [ATTRIBUTE:amount], [ATTRIBUTE:date]
  [CONDITION:where] [ATTRIBUTE:date] [OPERATOR:between] [VALUE:'2025-01-01'] [CONNECTOR:and] [VALUE:'2025-03-31']
  [ACTION:calculate] [ATTRIBUTE:revenue] = [ATTRIBUTE:price] * [ATTRIBUTE:quantity]
```

## Implementation in NSQL Dictionary

The NSQL dictionary would include word class for each term:

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
  },
  "df.amazon.sales": {
    "word_class": "path",
    "subclass": "dataobject_path",
    "references": "Data frame containing Amazon sales data",
    "translation": {
      "R": "df_amazon_sales",
      "SQL": "amazon_sales",
      "Python": "df_amazon_sales"
    }
  }
}
```

## Path Resolution Process

A key feature of the enhanced NSQL would be formalized path resolution:

1. **Path Identification**: Identify path expressions in NSQL statements
2. **Path Classification**: Determine the subclass of path (DataObject, File, Attribute, etc.)
3. **Path Validation**: Verify the path refers to a valid resource
4. **Path Translation**: Convert the path to the appropriate syntax in the target language
5. **Path Access**: Generate code to access the resource specified by the path

## Benefits of Path Word Class

1. **Consistent Reference**: Standardized way to reference data objects, files, and attributes
2. **Type Safety**: Ability to validate paths against known resources
3. **Readability**: Clear distinction between data references and operations
4. **Integration**: Direct alignment with R19 object naming conventions
5. **Implementation Flexibility**: Paths can be translated to appropriate syntax in different languages

## Implementation Plan

1. **Update MP24**: Add complete word class system including paths
2. **Enhance R21**: Modify NSQL Dictionary Rule to include all word classes
3. **Develop Path Resolver**: Create a component to validate and resolve paths
4. **Update Parsers**: Enhance NSQL parsers to identify and process different word classes
5. **Create Integration Guidelines**: Document how NSQL paths integrate with R19 naming conventions

## Relationship to MP01 (Primitive Terms and Definitions)

This enhancement applies the subtype concept from MP01 to create a hierarchical word class system for NSQL. Just as MP01 recognizes subtypes of temporary files, the NSQL grammar recognizes both general word classes and their specific subtypes (particularly for paths).

## Conclusion

The addition of the path word class and a comprehensive grammatical framework significantly enhances NSQL's ability to express and process data operations. By providing clear distinctions between different types of words and integrating with the existing naming conventions, this enhancement creates a more cohesive, expressive, and precise language for data transformation operations.

This comprehensive word class system will make NSQL more powerful and easier to use, while ensuring consistency with the broader principles of the system.