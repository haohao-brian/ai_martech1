---
date: "2025-04-04"
title: "NSQL Path Type Refinement"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "P14": "Dot Notation Property Access"
  - "R19": "Object Naming Convention" 
---

# NSQL Path Type Refinement

## Summary

This record refines the path classification in the NSQL word class system by explicitly defining three critical path subtypes: AttributePath, DataObjectPath, and FunctionPath. This refinement creates more precise semantics for dot notation expressions in NSQL and ensures better alignment with the dot notation property access principle (P14).

## Path Type Refinement

The general "path" word class in NSQL represents expressions that identify the location of data objects, files, or resources. Within this class, we define these essential subtypes:

### 1. AttributePath

**Definition**: A path that references an attribute or property of an object using dot notation.

**Pattern**: `object.attribute`

**Characteristics**:
- Left side (object) is an entity or data object
- Right side (attribute) is a property or field
- Resolves to the value of the attribute within the object
- Often used in conditions, projections, and calculations

**Examples**:
- `customers.name` (the name attribute of customers)
- `product.price` (the price attribute of product)
- `transaction.date` (the date attribute of transaction)
- `order.customer.address` (nested attribute access)

**Translation**:
```
# R
object$attribute  

# SQL
object.attribute

# Python
object.attribute  
```

### 2. DataObjectPath

**Definition**: A path that references a data object within a namespace or hierarchy using dot notation.

**Pattern**: `namespace.object[.subnested]`

**Characteristics**:
- Conforms to R19 object naming convention
- Left side is typically a namespace or type prefix
- Represents a complete data object rather than a property
- Often used as sources or targets in transformations

**Examples**:
- `df.amazon.sales` (the sales data frame in the amazon namespace)
- `df.platform.purpose.by_id.at_dimension` (full conformance to R19)
- `raw.website.comments` (raw data object)
- `lst.products.bestseller` (list object)

**Translation**:
```
# R
df_amazon_sales

# SQL  
amazon_sales

# Python
df_amazon_sales
```

### 3. FunctionPath

**Definition**: A path that references a function within a module or function namespace using dot notation.

**Pattern**: `module.function`

**Characteristics**:
- Left side is a module or function type prefix
- Right side is a specific function name
- Resolves to a callable function
- Often used in actions and operations

**Examples**:
- `calc.revenue` (the revenue function in the calc module)
- `dt.transform_date` (the transform_date function in the dt module)
- `util.clean_text` (the clean_text function in the util module)
- `mod.customer_analytics.segment` (nested module function)

**Translation**:
```
# R
calc_revenue

# SQL
revenue()

# Python
calc.revenue
```

## Path Resolution Process

The NSQL parser would distinguish between these path types using these rules:

1. **Context-Based Resolution**:
   - If the path appears in a source or target position: DataObjectPath
   - If the path appears in a field selector or condition: AttributePath
   - If the path appears in a function position: FunctionPath

2. **Prefix-Based Resolution**:
   - Prefixes defined in R19 (df., raw., calc., etc.) provide hints about path type
   - df.* and raw.* typically indicate DataObjectPath
   - calc.*, dt.*, util.* typically indicate FunctionPath

3. **Disambiguation Rules**:
   - When ambiguous, prefer the most specific valid interpretation
   - Interactive systems may prompt for clarification
   - Context clues help resolve ambiguity

## Examples with Path Type Clarification

### Example 1: Mixed Path Types

**NSQL Statement**:
```
df.amazon.sales -> filter where product.category = 'Electronics' -> calculate revenue = calc.total_price(product.price, quantity)
```

**With Path Type Identification**:
```
[DATAOBJECTPATH:df.amazon.sales] -> filter where [ATTRIBUTEPATH:product.category] = 'Electronics' -> calculate revenue = [FUNCTIONPATH:calc.total_price]([ATTRIBUTEPATH:product.price], quantity)
```

### Example 2: Nested Paths

**NSQL Statement**:
```
transform df.customer.orders to df.customer.order_summary as
  group by customer.region
  calculate total_spend = sum(order.amount)
  where customer.status = 'active'
```

**With Path Type Identification**:
```
transform [DATAOBJECTPATH:df.customer.orders] to [DATAOBJECTPATH:df.customer.order_summary] as
  group by [ATTRIBUTEPATH:customer.region]
  calculate total_spend = sum([ATTRIBUTEPATH:order.amount])
  where [ATTRIBUTEPATH:customer.status] = 'active'
```

## Implementation in NSQL Dictionary

The NSQL dictionary would be enhanced to include path subtypes:

```json
{
  "customer.name": {
    "word_class": "path",
    "path_type": "attribute_path",
    "object": "customer",
    "attribute": "name",
    "translation": {
      "R": "customer$name",
      "SQL": "customer.name",
      "Python": "customer.name"
    }
  },
  "df.amazon.sales": {
    "word_class": "path",
    "path_type": "dataobject_path",
    "namespace": "df.amazon",
    "object": "sales",
    "translation": {
      "R": "df_amazon_sales",
      "SQL": "amazon_sales",
      "Python": "df_amazon_sales"
    }
  },
  "calc.revenue": {
    "word_class": "path",
    "path_type": "function_path",
    "module": "calc",
    "function": "revenue",
    "translation": {
      "R": "calc_revenue",
      "SQL": "revenue()",
      "Python": "calc.revenue"
    }
  }
}
```

## Relationship to Other Principles

This path type refinement creates stronger alignment with:

1. **P14 (Dot Notation Property Access)**: 
   - Implements dot notation as the standard for property access in NSQL
   - Formalizes the semantics of dot notation consistently with P14

2. **R19 (Object Naming Convention)**:
   - Ensures NSQL paths follow the same conventions as object names in the codebase
   - Creates a direct mapping between NSQL DataObjectPaths and R19 naming patterns

3. **MP01 (Primitive Terms and Definitions)**:
   - Applies the subtype concept to create more precise path classifications
   - Creates a foundation for formal type checking and validation of paths

## Benefits of Path Type Refinement

1. **Precision**: More accurate classification of dot notation expressions
2. **Clarity**: Clearer distinction between different uses of dot notation
3. **Validation**: Enables type-specific validation of paths
4. **Translation**: More accurate mapping to implementation languages
5. **Consistency**: Better alignment with naming conventions across the system

## Implementation Plan

1. **Update MP24**: Add refined path types to the NSQL specification
2. **Enhance Parser**: Update the NSQL parser to distinguish between path types
3. **Extend Dictionary**: Add path type information to the NSQL dictionary
4. **Update Translation**: Refine translation rules based on path types
5. **Create Validation Rules**: Develop validation rules for each path type

## Conclusion

Refining the NSQL path word class with explicit AttributePath, DataObjectPath, and FunctionPath subtypes significantly enhances the precision and expressiveness of the language. This refinement creates stronger alignment with the broader system's principles and conventions, particularly P14 (Dot Notation Property Access) and R19 (Object Naming Convention).

By formalizing the semantics of different dot notation expressions, this enhancement improves both the usability of NSQL for humans and its processability for automated translation and validation systems.