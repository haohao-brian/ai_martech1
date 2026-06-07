---
date: "2025-04-04"
title: "NSQL and RSQL as Unified Language Dialects"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP26": "R Statistical Query Language"
  - "P13": "Language Standard Adherence"
---

# NSQL and RSQL as Unified Language Dialects

## Summary

This record proposes establishing Natural SQL Language (NSQL) and R Statistical Query Language (RSQL) as dialects of a unified query language system. It outlines their shared foundation, implementation using data.tree in R, and the benefits of this unified approach.

## Current Situation

MP24 establishes Natural SQL Language (NSQL) and MP26 establishes R Statistical Query Language (RSQL) as separate languages, though they serve similar purposes:

- **NSQL**: A human-readable meta-language for expressing data transformation operations
- **RSQL**: A specialized language for statistical operations in R

While they have distinct focuses, they share underlying patterns, concepts, and objectives, suggesting they would benefit from formalization as dialects of a unified language system.

## Proposed Unified Language Framework

### Core Concept

NSQL and RSQL should be established as dialects of a unified language system called **Unified Query Language (UQL)** with:

1. **Shared Core**: Common syntax, grammar, and concepts
2. **Dialect-Specific Extensions**: Specialized features for each context
3. **Common Type System**: Shared type hierarchy and semantics
4. **Compatible Implementations**: Ability to translate between dialects

### Shared Foundation

The unified language framework would include:

1. **Common Grammar**: Core syntax shared by both dialects
2. **Shared Type System**: Unified type hierarchy implemented with data.tree
3. **Word Class System**: Actions, conditions, paths, and functions present in both
4. **Translation Layer**: Mechanisms to convert between dialects

### Implementation with data.tree

The unified type system would be implemented using data.tree in R:

```r
library(data.tree)

# Create base type tree
type_tree <- Node$new("Type")

# Add major branches
value <- type_tree$AddChild("Value")
path <- type_tree$AddChild("Path")
function_type <- type_tree$AddChild("Function")
collection <- type_tree$AddChild("Collection")
action <- type_tree$AddChild("Action")
condition <- type_tree$AddChild("Condition")

# Add Value subtypes
number <- value$AddChild("Number")
string <- value$AddChild("String")
boolean <- value$AddChild("Boolean")
date <- value$AddChild("Date")
null <- value$AddChild("Null")

# Add Number subtypes
integer <- number$AddChild("Integer")
float <- number$AddChild("Float")
decimal <- number$AddChild("Decimal")

# Add Path subtypes
attribute_path <- path$AddChild("AttributePath")
dataobject_path <- path$AddChild("DataObjectPath")
function_path <- path$AddChild("FunctionPath")
file_path <- path$AddChild("FilePath")

# Add Function subtypes
type_function <- function_type$AddChild("TypeFunction")
aggregate_function <- function_type$AddChild("AggregateFunction")
transformation_function <- function_type$AddChild("TransformationFunction")
analytical_function <- function_type$AddChild("AnalyticalFunction")

# Add metadata to nodes
number$attributes <- list(numeric = TRUE, comparable = TRUE)
integer$attributes <- list(discrete = TRUE, exact = TRUE)
attribute_path$attributes <- list(pattern = "object.attribute", resolution = "property_access")

# Define type detection for typeof()
typeof_impl <- function(expr, tree = type_tree) {
  # Type detection logic
  specific_type <- detect_specific_type(expr)
  
  # Build path from root to specific type
  path <- c()
  current <- specific_type
  
  while (!is.null(current)) {
    path <- c(current$name, path)
    current <- current$parent
  }
  
  return(paste(path, collapse = " -> "))
}

# Register a new type
register_type <- function(id, parent_id, description = "", attributes = list()) {
  # Find parent node
  parent_node <- type_tree$FindNode(parent_id)
  if (is.null(parent_node)) {
    stop("Parent type not found: ", parent_id)
  }
  
  # Add new type
  new_node <- parent_node$AddChild(id)
  new_node$description <- description
  new_node$attributes <- attributes
  
  return(new_node)
}

# Print the tree structure
print(type_tree, "name", "description")
```

### Dialect Comparison

| Aspect          | NSQL (Natural SQL Language)          | RSQL (R Statistical Query Language)   |
|-----------------|--------------------------------------|---------------------------------------|
| **Primary Focus** | Data transformation operations       | Statistical operations and analysis   |
| **Target Users** | Analysts and business users          | Data scientists and statisticians     |
| **Expression Style** | Human-readable, SQL-like syntax     | R-optimized, tidyverse-compatible     |
| **Implementation** | Language-agnostic, translatable     | Native R implementation              |
| **Specialization** | General data operations             | Statistical methods and modeling     |

### NSQL Example

```
customers -> 
  filter where status = 'active' -> 
  group by region -> 
  calculate 
    count = count(*),
    avg_spend = average(spend)
```

### RSQL Equivalent

```
customers %>% 
  filter(status == 'active') %>% 
  group_by(region) %>% 
  summarize(
    count = n(),
    avg_spend = mean(spend)
  )
```

## Unified Implementation Approach

### 1. Shared Type System

Both dialects would use the same type tree implementation:

```r
# Shared by both NSQL and RSQL
uql_type_tree <- initialize_type_tree()

# NSQL typeof implementation
nsql_typeof <- function(expr) {
  return(typeof_impl(expr, uql_type_tree))
}

# RSQL typeof implementation
rsql_typeof <- function(expr) {
  return(typeof_impl(expr, uql_type_tree))
}
```

### 2. Dialect Translation

A translation layer would convert between dialects:

```r
# Convert NSQL to RSQL
nsql_to_rsql <- function(nsql_query) {
  # Parse NSQL query into AST
  ast <- parse_nsql(nsql_query)
  
  # Transform to RSQL
  rsql_ast <- transform_to_rsql(ast)
  
  # Generate RSQL code
  return(generate_rsql(rsql_ast))
}

# Convert RSQL to NSQL
rsql_to_nsql <- function(rsql_query) {
  # Parse RSQL into AST
  ast <- parse_rsql(rsql_query)
  
  # Transform to NSQL
  nsql_ast <- transform_to_nsql(ast)
  
  # Generate NSQL query
  return(generate_nsql(nsql_ast))
}
```

### 3. Unified Dictionary

A common dictionary would provide shared definitions with dialect-specific translations:

```json
{
  "filter": {
    "word_class": "action",
    "category": "filtering_operation",
    "parameters": [{"name": "condition", "type": "condition"}],
    "nsql_translation": "filter where %condition%",
    "rsql_translation": "filter(%condition%)"
  },
  "group": {
    "word_class": "action",
    "category": "grouping_operation",
    "parameters": [{"name": "by_columns", "type": "column_list"}],
    "nsql_translation": "group by %by_columns%",
    "rsql_translation": "group_by(%by_columns%)"
  }
}
```

## Extensions for Each Dialect

While sharing a common foundation, each dialect would have specialized extensions:

### NSQL Extensions

```
# Interactive disambiguation
show top 10 sales by_?
  options:
    - by_product
    - by_region
    - by_customer
```

### RSQL Extensions

```
# Statistical modeling extensions
data %>%
  model(linear_model(y ~ x1 + x2)) %>%
  predict(newdata = test_data)
```

## Principle Enhancement Proposal

Based on this unified approach, we propose enhancing MP24 and MP26:

### MP24 (Natural SQL Language) Enhancement

- Establish NSQL as a dialect of the Unified Query Language (UQL)
- Reference the shared type system and word classes
- Define dialect-specific features and optimizations
- Document the relationship with RSQL

### MP26 (R Statistical Query Language) Enhancement

- Establish RSQL as a dialect of the Unified Query Language (UQL)
- Incorporate the shared type system implemented with data.tree
- Define statistical extensions to the core language
- Document the relationship with NSQL

### New P27 (Unified Query Language Principle)

A new principle (P27) should be created to:
- Define the shared foundation of UQL
- Establish dialect creation and validation rules
- Specify dialect translation requirements
- Guide the evolution of the unified language system

## Benefits of Unification

1. **Consistency**: Common foundation ensures conceptual cohesion
2. **Knowledge Transfer**: Skills transfer easily between dialects
3. **Implementation Efficiency**: Shared components reduce duplication
4. **Extensibility**: Easier to create additional specialized dialects
5. **Learnability**: Core concepts learned once apply broadly

## Implementation Plan

1. **Refactor MP24 and MP26**: Update to reflect dialect status
2. **Create P27**: Establish the Unified Query Language principle
3. **Implement Type Tree**: Build the data.tree implementation
4. **Develop Translation Layer**: Create dialect conversion tools
5. **Update Documentation**: Reflect the unified approach

## Conclusion

Establishing NSQL and RSQL as dialects of a unified language system creates a more cohesive, powerful query language framework. Using data.tree in R to implement the shared type system provides an elegant, efficient foundation for both dialects.

This unified approach preserves the specialized strengths of each dialect while promoting consistency, knowledge sharing, and implementation efficiency. The data.tree implementation in particular offers a robust, flexible foundation for the type system that aligns perfectly with R's capabilities.