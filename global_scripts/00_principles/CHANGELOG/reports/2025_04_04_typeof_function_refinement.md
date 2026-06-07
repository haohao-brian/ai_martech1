---
date: "2025-04-04"
title: "NSQL typeof() Function Refinement"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP01": "Primitive Terms and Definitions"
  - "R24": "Type Token Naming"
---

# NSQL typeof() Function Refinement

## Summary

This record refines the `typeof()` function in NSQL to return the complete type hierarchy, reflecting the subtype relationships defined in MP01. This enhancement provides more precise type information that includes both the uppermost type and all subtypes in a path format.

## Current Limitation

The basic `typeof()` function currently returns only the immediate type of an object, which doesn't capture the rich hierarchical type relationships established in MP01. This limitation makes it difficult to perform precise type-based operations and validations.

## Refined typeof() Function

### Purpose

The refined `typeof()` function returns the complete type hierarchy as a path from the uppermost type to the lowest subtype.

### Syntax

```
typeof(expression)
```

### Return Value

A string representing the type hierarchy in path notation, with each level separated by the arrow operator (->):

```
TopType -> SubType -> SubSubType
```

For example:
- `typeof(42)` returns `"Value -> Number -> Integer"`
- `typeof("hello")` returns `"Value -> String"`
- `typeof(A.B)` returns `"Path -> AttributePath"`
- `typeof(df.amazon.sales)` returns `"Path -> DataObjectPath"`

### Examples

#### Example 1: Basic Types

```
typeof(42)                # "Value -> Number -> Integer"
typeof(3.14)              # "Value -> Number -> Float"
typeof("hello")           # "Value -> String"
typeof(TRUE)              # "Value -> Boolean"
typeof(NULL)              # "Value -> Null"
```

#### Example 2: Path Types

```
typeof(customer.name)     # "Path -> AttributePath"
typeof(df.amazon.sales)   # "Path -> DataObjectPath"
typeof(calc.revenue)      # "Path -> FunctionPath"
```

#### Example 3: Function Types

```
typeof(sum)               # "Function -> AggregateFunction"
typeof(format)            # "Function -> TransformationFunction"
typeof(typeof)            # "Function -> TypeFunction"
```

#### Example 4: Complex Data Structures

```
typeof([1, 2, 3])         # "Collection -> Array -> NumericArray"
typeof({"a": 1, "b": 2})  # "Collection -> Object -> Dictionary"
typeof(df.amazon.sales)   # "Data -> DataFrame -> PlatformData"
```

### Using typeof() in NSQL Expressions

The type hierarchy returned by `typeof()` can be used in NSQL expressions:

```
# Filter paths that are AttributePaths
paths -> filter where typeof(path) = "Path -> AttributePath"

# Apply different operations based on type
data -> transform as
  result = case
    when typeof(value) = "Value -> Number -> Integer" then value * 2
    when typeof(value) = "Value -> String" then length(value)
    else value
  end
```

### Type Matching Functions

The refined type system introduces additional functions for type matching:

#### 1. is_type(expression, pattern)

Tests if an expression's type matches a pattern, which can include wildcards:

```
is_type(42, "Value -> Number -> *")        # TRUE
is_type(customer.name, "Path -> *")        # TRUE
is_type("hello", "Value -> Number -> *")   # FALSE
```

#### 2. base_type(expression)

Returns just the base (top-level) type:

```
base_type(42)                # "Value"
base_type(customer.name)     # "Path"
base_type(sum)               # "Function"
```

#### 3. specific_type(expression)

Returns just the most specific (lowest-level) type:

```
specific_type(42)            # "Integer"
specific_type(customer.name) # "AttributePath"
specific_type(sum)           # "AggregateFunction"
```

## NSQL Dictionary Entry

The refined `typeof()` function would be documented in the NSQL dictionary:

```json
{
  "typeof": {
    "word_class": "function",
    "category": "type_function",
    "parameters": [{"name": "expression", "type": "any"}],
    "return_type": "string",
    "description": "Returns the complete type hierarchy of the given expression as a path from uppermost type to lowest subtype",
    "examples": [
      "typeof(42) returns \"Value -> Number -> Integer\"",
      "typeof(A.B) returns \"Path -> AttributePath\"",
      "typeof(sum) returns \"Function -> AggregateFunction\""
    ],
    "translation": {
      "R": "nsql_typeof(%expression%)",
      "SQL": "TYPEOF_HIERARCHY(%expression%)",
      "Python": "nsql.typeof(%expression%)"
    }
  },
  "is_type": {
    "word_class": "function",
    "category": "type_function",
    "parameters": [
      {"name": "expression", "type": "any"},
      {"name": "pattern", "type": "string"}
    ],
    "return_type": "boolean",
    "description": "Tests if an expression's type hierarchy matches the given pattern, which may include wildcards (*)",
    "translation": {
      "R": "nsql_is_type(%expression%, %pattern%)",
      "SQL": "IS_TYPE(%expression%, %pattern%)",
      "Python": "nsql.is_type(%expression%, %pattern%)"
    }
  }
}
```

## Type Hierarchy in MP01

This refinement directly connects to the type hierarchy established in MP01, where:

1. **Types** can have **Subtypes** (e.g., Number is a subtype of Value)
2. **Subtypes** can have further **Subtypes** (e.g., Integer is a subtype of Number)
3. **Tokens** are instances of the most specific type (e.g., 42 is a token of Integer)

The refined `typeof()` reveals this entire hierarchy, making the type system more transparent and useful.

## Implementation Guidelines

To implement the refined `typeof()`:

1. **Type Hierarchy Registry**: Maintain a registry of all type hierarchies
2. **Type Detection Logic**: Develop algorithms to detect specific types
3. **Path Construction**: Build the type path based on the registry
4. **Translation Layer**: Create implementation-specific translations
5. **Documentation**: Update documentation with examples

## Benefits

1. **Type Precision**: More precise type information for validation
2. **Hierarchical Awareness**: Reveals subtype relationships
3. **Consistent Notation**: Uses path notation similar to other NSQL constructs
4. **Enhanced Filtering**: Enables filtering based on type hierarchies
5. **Improved Debugging**: Makes type information more transparent

## Integration with R24 (Type Token Naming)

This refinement directly supports R24 (Type Token Naming) by:

1. Exposing the complete type hierarchy to NSQL expressions
2. Using consistent naming for types at each level
3. Reflecting the type-token distinction in type information
4. Supporting validation based on type hierarchies

## Conclusion

The refined `typeof()` function significantly enhances the type system in NSQL by revealing the complete type hierarchy. By returning types as paths from uppermost to lowest, it exposes the rich subtype relationships defined in MP01, enabling more precise type-based operations and validations.

This refinement creates a more powerful and expressive type system that maintains consistency with the broader principles framework, particularly MP01's subtype concept and R24's type-token naming convention.