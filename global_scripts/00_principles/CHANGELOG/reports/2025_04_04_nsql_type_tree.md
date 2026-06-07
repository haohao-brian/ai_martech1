---
date: "2025-04-04"
title: "NSQL Type Tree Structure"
type: "record"
author: "Claude"
related_to:
  - "MP24": "Natural SQL Language"
  - "MP01": "Primitive Terms and Definitions"
  - "R24": "Type Token Naming"
---

# NSQL Type Tree Structure

## Summary

This record proposes a comprehensive type tree structure for the NSQL language that formalizes type hierarchies and relationships. The type tree will serve as the foundation for the `typeof()` function and other type-related operations, providing a consistent, extensible representation of all types in the system.

## Type Tree Design

### Core Concept

The type tree is a hierarchical data structure that:
1. Represents all types and their relationships in NSQL
2. Forms a directed acyclic graph with multiple inheritance
3. Enables efficient type queries and traversals
4. Serves as the authoritative source for the `typeof()` function

### Structure Definition

The type tree is defined as:

```json
{
  "Type": {
    "description": "The root of all types",
    "subtypes": ["Value", "Path", "Function", "Collection", "Action", "Condition"],
    "attributes": {}
  },
  "Value": {
    "description": "A direct, immutable piece of data",
    "parent": "Type",
    "subtypes": ["Number", "String", "Boolean", "Date", "Null"],
    "attributes": {
      "immutable": true,
      "serializable": true
    }
  },
  "Number": {
    "description": "Numeric data",
    "parent": "Value",
    "subtypes": ["Integer", "Float", "Decimal"],
    "attributes": {
      "numeric": true,
      "comparable": true
    }
  },
  "Integer": {
    "description": "Whole number",
    "parent": "Number",
    "subtypes": [],
    "attributes": {
      "discrete": true,
      "exact": true
    }
  },
  "Path": {
    "description": "Reference to a resource location",
    "parent": "Type",
    "subtypes": ["AttributePath", "DataObjectPath", "FunctionPath", "FilePath"],
    "attributes": {
      "navigable": true,
      "resolvable": true
    }
  },
  "AttributePath": {
    "description": "Reference to an attribute of an object",
    "parent": "Path",
    "subtypes": [],
    "attributes": {
      "pattern": "object.attribute",
      "resolution": "property_access"
    }
  },
  "DataObjectPath": {
    "description": "Reference to a data object",
    "parent": "Path",
    "subtypes": ["DataFramePath", "ListPath", "RawDataPath"],
    "attributes": {
      "pattern": "namespace.object",
      "resolution": "object_lookup"
    }
  },
  "Function": {
    "description": "Callable operation",
    "parent": "Type",
    "subtypes": ["TypeFunction", "AggregateFunction", "TransformationFunction", 
                "AnalyticalFunction", "PathFunction", "SystemFunction"],
    "attributes": {
      "callable": true,
      "takes_arguments": true
    }
  },
  "TypeFunction": {
    "description": "Function that operates on types",
    "parent": "Function",
    "subtypes": [],
    "attributes": {
      "operates_on": "types"
    },
    "examples": ["typeof", "is_type", "cast"]
  }
  // Additional types would be defined similarly
}
```

### Multiple Inheritance

For types with multiple parents, the structure extends to:

```json
"DataFrame": {
  "description": "Tabular data structure",
  "parents": ["Collection", "Data"],
  "subtypes": ["FilteredDataFrame", "GroupedDataFrame"],
  "attributes": {
    "tabular": true,
    "rows_and_columns": true
  }
}
```

## Type Detection Algorithm

The type tree enables a sophisticated algorithm for `typeof()`:

1. **Instance Detection**: Identify the most specific type of an expression
2. **Ancestor Traversal**: Trace back through parents to the root
3. **Path Construction**: Build the path from root to specific type
4. **Output Formatting**: Format using the arrow notation

Pseudocode:

```
function detect_type(expression):
  # Pattern-based detection for specific types
  if is_number(expression) and is_whole(expression):
    return "Integer"
  else if is_number(expression):
    return "Float"
  else if is_text(expression):
    return "String"
  
  # Path pattern detection
  if matches_pattern(expression, "object.attribute"):
    return "AttributePath"
  if matches_pattern(expression, "namespace.object"):
    return "DataObjectPath"
  
  # Default
  return "Type"

function build_type_path(specific_type):
  path = []
  current = specific_type
  
  # Traverse up the tree
  while current != null:
    path.unshift(current) # Add to beginning
    current = tree[current].parent
  
  return path.join(" -> ")

function typeof(expression):
  specific = detect_type(expression)
  return build_type_path(specific)
```

## Type Tree Storage

The type tree can be stored in several formats, each with advantages:

### 1. JSON Configuration

```json
{
  "typeTree": {
    "Type": {
      "description": "Root of all types",
      "subtypes": ["Value", "Path", "Function"]
    },
    "Value": {
      "parent": "Type",
      "description": "Direct data value",
      "subtypes": ["Number", "String", "Boolean"]
    }
    // And so on
  }
}
```

**Advantages**:
- Human-readable and editable
- Easy to version control
- Simple to distribute

**Use Case**: Configuration and documentation

### 2. In-Memory Object Structure

```r
# R implementation
type_tree <- list(
  "Type" = list(
    description = "Root of all types",
    subtypes = c("Value", "Path", "Function"),
    attributes = list()
  ),
  "Value" = list(
    parent = "Type",
    description = "Direct data value",
    subtypes = c("Number", "String", "Boolean"),
    attributes = list(immutable = TRUE)
  )
  # And so on
)
```

**Advantages**:
- Fast runtime access
- Support for methods and behaviors
- Dynamic modification

**Use Case**: Runtime type operations

### 3. Database Structure

```sql
CREATE TABLE type_nodes (
  type_id VARCHAR(50) PRIMARY KEY,
  description TEXT,
  attributes JSON
);

CREATE TABLE type_relationships (
  parent_id VARCHAR(50),
  child_id VARCHAR(50),
  PRIMARY KEY (parent_id, child_id),
  FOREIGN KEY (parent_id) REFERENCES type_nodes(type_id),
  FOREIGN KEY (child_id) REFERENCES type_nodes(type_id)
);
```

**Advantages**:
- Supports complex queries
- Handles very large type systems
- Enables efficient relationship traversal

**Use Case**: Enterprise-scale NSQL implementations

### 4. Graph Database

```cypher
// Neo4j Cypher query language
CREATE (t:TypeNode {id: 'Type', description: 'Root of all types'})
CREATE (v:TypeNode {id: 'Value', description: 'Direct data value'})
CREATE (n:TypeNode {id: 'Number', description: 'Numeric data'})
CREATE (v)-[:SUBTYPE_OF]->(t)
CREATE (n)-[:SUBTYPE_OF]->(v)
```

**Advantages**:
- Native representation of tree structure
- Efficient traversal and pathfinding
- Support for complex relationships

**Use Case**: Advanced type systems with complex relationships

## Type Registration System

To make the type tree extensible, NSQL includes a type registration system:

```r
# Register a new type
register_type(
  id = "DecimalString",
  parent = "String",
  description = "String representing a decimal number",
  attributes = list(
    numeric_convertible = TRUE,
    pattern = "^-?\\d+\\.\\d+$"
  )
)

# Register a type with multiple parents
register_type(
  id = "NumericVector",
  parents = c("Vector", "NumericCollection"),
  description = "Ordered collection of numbers",
  attributes = list(
    homogeneous = TRUE,
    ordered = TRUE
  )
)
```

## Type Tree Usage Examples

### 1. Type Hierarchy Queries

```
# Get full type path
typeof(customer.name)  # "Type -> Path -> AttributePath"

# Check if type is a subtype of Path
is_type(customer.name, "Path -> *")  # TRUE

# Find all registered subtypes of Number
subtypes("Number")  # ["Integer", "Float", "Decimal"]

# Get direct parent
parent_type("Integer")  # "Number"
```

### 2. Type-Based Dispatching

```
# Apply function based on type
process_data = function(data) {
  case typeof(data)
    when "Type -> Path -> DataObjectPath" then process_data_object(data)
    when "Type -> Collection -> Array" then process_array(data)
    when "Type -> Value -> String" then process_string(data)
    else default_processor(data)
  end
}
```

### 3. Type Validation

```
# Validate function arguments
validate_arguments = function(func_name, args) {
  if (func_name == "sum") {
    for (arg in args) {
      if (!is_type(arg, "Type -> Value -> Number -> *")) {
        throw_error("sum requires numeric arguments")
      }
    }
  }
}
```

## Implementation in NSQL Dictionary

The type tree integrates with the NSQL dictionary:

```json
"typeof": {
  "word_class": "function",
  "category": "type_function",
  "parameters": [{"name": "expression", "type": "any"}],
  "return_type": "string",
  "description": "Returns the complete type hierarchy based on the type tree",
  "implementation": {
    "type_detection": "type_tree_based",
    "source": "global_type_tree"
  },
  "translation": {
    "R": "nsql_typeof(%expression%, type_tree)",
    "SQL": "TYPEOF_HIERARCHY(%expression%)",
    "Python": "nsql.typeof(%expression%, type_tree)"
  }
}
```

## Benefits of the Type Tree

1. **Consistency**: Single source of truth for type information
2. **Extensibility**: New types can be added without modifying code
3. **Efficiency**: Optimized structure for type lookups and traversals
4. **Documentation**: Self-documenting type relationships
5. **Validation**: Foundation for type checking and validation

## Relationship to Principles

This type tree structure relates directly to:

1. **MP01 (Primitive Terms and Definitions)**:
   - Formalizes the subtype relationships defined in MP01
   - Provides a concrete implementation of the type hierarchy

2. **R24 (Type Token Naming)**:
   - Establishes consistent naming for types in the hierarchy
   - Supports the type-token distinction

3. **MP24 (Natural SQL Language)**:
   - Provides the foundation for type operations in NSQL
   - Enables powerful type-based features in the language

## Conclusion

The NSQL type tree structure provides a comprehensive foundation for type operations in the language. By formalizing type relationships in a hierarchical structure, it enables sophisticated type detection, validation, and operations.

The type tree makes the `typeof()` function more powerful and precise by basing it on a complete model of type relationships rather than ad-hoc detection. This approach creates a more consistent, extensible, and maintainable type system that aligns with the broader principles framework.