---
id: "NSQL_MULTIDIMENSIONAL_TYPE_SYSTEM"
title: "NSQL Multidimensional Type System"
type: "record"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "NSQL_EXTENSION_TYPES": "Extension Types in NSQL"
  - "NSQL_TYPEOF_FUNCTION": "NSQL typeof() Function"
  - "NSQL_PATH_TYPES": "Path Types in NSQL"
---

# NSQL Multidimensional Type System

## Overview

NSQL's multidimensional type system addresses the fundamental limitation of traditional hierarchical type systems: their inability to represent entities that belong to multiple classification schemes simultaneously. This system enables cross-classification, allowing for more precise type definitions and operations in complex data environments.

## Core Components

The multidimensional type system consists of four key components:

1. **Multi-dimensional Type Tags**
2. **Type Intersection Operators**
3. **Richer Type Metadata**
4. **Type Annotation Syntax**

Together, these components form a comprehensive solution to cross-classification challenges.

## 1. Multi-dimensional Type Tags

Traditional type systems often force entities into a single classification hierarchy. Multi-dimensional type tags allow entities to be classified across multiple independent dimensions.

### Syntax

To avoid ambiguity with R's native `typeof()` function, NSQL uses `typeof2()` for its enhanced type system:

```
typeof2(expression, dimension="dimension_name")
```

Default behavior:
- `typeof2(x)` returns a comprehensive type object with all dimensions
- `typeof2(x)$R` gives access to the native R type (via the R dimension)
- `typeof2(x, dimension="all")` also returns the complete type map across all dimensions
- `typeof2(x, dimension="format|role|etc")` returns type in a specific dimension

Note: This naming convention follows R's pattern for enhanced functions (like `paste0()`) while avoiding namespace conflicts with the original `typeof()`.

### Examples

```sql
-- Get the native R type using base R
typeof(customer_file)
--> "character"  

-- Get complete type information across all dimensions
typeof2(customer_file)
--> list(R = "character", 
        format = "Resource:File:DataFile:CSV",
        role = "Resource:File:DataDictionary",
        domain = "Resource:File:Domain:CustomerData")

-- Alternatively, explicitly ask for all dimensions
typeof2(customer_file, dimension="all")
--> Same comprehensive result as above

-- Get the format-dimension type of a file
typeof2(customer_file, dimension="format")
--> "Resource:File:DataFile:CSV"

-- Get the semantic-dimension type of the same file
typeof2(customer_file, dimension="role") 
--> "Resource:File:DataDictionary"

-- Direct access to R type via the R dimension
typeof2(customer_file)$R
--> "character"
```

### Standard Dimensions

| Dimension | Description | Example Values |
|-----------|-------------|----------------|
| format | Technical format | CSV, JSON, XLSX, Directory |
| role | Semantic purpose | DataDictionary, Config, Log, Source |
| domain | Business domain | Customer, Finance, Product, Sales |
| lifecycle | Data lifecycle stage | Raw, Validated, Transformed, Published |
| privacy | Privacy classification | Public, Internal, Confidential, PII |
| quality | Data quality level | Raw, Validated, Gold, Deprecated |

## 2. Type Intersection Operator

The type intersection operator enables combining types from different dimensions, creating composite types that must satisfy all constraints.

### Syntax

```
type1 & type2
```

### Examples

```sql
-- Check if file is both a CSV and a DataDictionary
IF (typeof2(file, "format") & "Resource:File:DataFile:CSV") AND 
   (typeof2(file, "role") & "Resource:File:DataDictionary") THEN
  -- Handle file as a CSV data dictionary
END IF

-- Leveraging R compatibility in NSQL
IF typeof(value) == "double" THEN
  -- Use R's native type system for numeric handling
  value <- as.integer(value)
END IF

-- Getting all type dimensions and using them conditionally 
LET types = typeof2(file)  -- Get all dimensions at once
IF types$format == "CSV" AND types$privacy == "PII" THEN
  -- Apply special handling for PII data in CSV format
END IF
```

### Intersection Rules

1. **Same Dimension**: Intersection fails unless types are identical or in subtype relationship
2. **Different Dimensions**: Intersection succeeds, creating a composite type with constraints from both dimensions
3. **Hierarchical Subtypes**: `A & B` succeeds if A is a subtype of B or vice versa

## 3. Richer Type Metadata

Beyond simple type strings, NSQL provides access to comprehensive type metadata through an enhanced API.

### Syntax

```
get_type_info(expression)
```

### Example

```sql
-- Get complete type information
LET type_info = get_type_info(customer_file);

-- Access specific aspects
LET format_info = type_info.format;
LET validation_rules = type_info.validation_rules;
```

### Type Metadata Properties

```json
{
  "base_type": "Resource:File:DataFile:CSV",
  "dimensions": {
    "format": "Resource:File:DataFile:CSV",
    "role": "Resource:File:DataDictionary",
    "domain": "CustomerData",
    "privacy": "Confidential",
    "lifecycle": "Validated"
  },
  "validation_rules": [
    {"type": "schema", "value": "customer_schema.json"},
    {"type": "required_fields", "value": ["customer_id", "name"]}
  ],
  "handlers": {
    "read": "read_csv",
    "write": "write_csv"
  },
  "metadata": {
    "creation_date": "2025-03-15",
    "owner": "data_team",
    "version": "1.2"
  }
}
```

## 4. Type Annotation Syntax

Type annotations provide a concise way to explicitly attach multiple type dimensions to expressions.

### Syntax

```
expression@{dimension1="type1", dimension2="type2", ...}
```

### Examples

```sql
-- Annotated file declaration
LET customer_data@{
  format="CSV", 
  role="DataDictionary", 
  domain="Customer", 
  privacy="Confidential"
} = FROM "/data/customer_dictionary.csv";

-- Annotation propagation in queries
SELECT 
  customer_id, 
  SUM(purchase_amount)@{role="KPI"} AS total_spend
FROM purchases@{domain="Sales"}
GROUP BY customer_id;
```

### Annotation Inheritance

1. **Direct Inheritance**: Child objects inherit annotations from parent objects
2. **Annotation Override**: Explicit annotations override inherited annotations
3. **Operation-Specific Rules**: Different operations may have specific annotation propagation rules

```sql
-- Source has annotations
LET source@{domain="Sales", privacy="Confidential"} = FROM "/data/sales.csv";

-- Results inherit domain and privacy annotations
LET results = SELECT * FROM source WHERE amount > 1000;

-- Override specific annotations
LET public_summary@{privacy="Public"} = 
  SELECT region, COUNT(*) AS count 
  FROM results 
  GROUP BY region;
```

## Type Compatibility Rules

Type compatibility in a multidimensional system follows these rules:

1. **Assignment Compatibility**: Type T1 is assignment-compatible with T2 if:
   - For each dimension in T2, T1 has a compatible type in that dimension
   - Additional dimensions in T1 do not affect compatibility

2. **Operation Compatibility**: Operation compatibility depends on specific dimension requirements
   - Format dimension determines read/write operations
   - Role dimension may determine processing operations
   - Privacy dimension may restrict allowed operations

3. **Explicit Type Narrowing**: Explicit conversion needed when moving to more specific types
   ```sql
   -- Explicit narrowing using annotation
   LET typed_data = raw_data@{format="CSV", validation="strict"};
   ```

## Implementation in RSQL

```r
# Define a type with multiple dimensions
nsql_define_type <- function(base_type, dimensions = list()) {
  structure(
    list(
      base_type = base_type,
      dimensions = dimensions,
      metadata = list()
    ),
    class = "nsql_type"
  )
}

# Enhanced type function (typeof2) that preserves R compatibility
nsql_typeof2 <- function(obj, dimension = NULL) {
  # Get native R type 
  r_type <- base::typeof(obj)
  
  # Get or create NSQL type information
  type_info <- attr(obj, "nsql_type", exact = TRUE)
  if (is.null(type_info)) {
    # Generate type info based on object characteristics
    type_info <- generate_type_info(obj)
  }
  
  # Add R type into dimensions
  if (is.null(type_info$dimensions$R)) {
    type_info$dimensions$R <- r_type
  }
  
  # Return based on requested dimension
  if (is.null(dimension)) {
    # Default behavior: return all dimensions
    return(type_info$dimensions)
  } else if (dimension == "all") {
    # Explicit request for all dimensions
    return(type_info$dimensions)
  } else if (dimension %in% names(type_info$dimensions)) {
    # Return specific dimension
    return(type_info$dimensions[[dimension]])
  } else {
    # Default for unknown dimensions
    return("Unknown")
  }
}

# Type intersection
nsql_type_intersection <- function(type1, type2) {
  # If same dimension, check subtype relationship
  if (!is.null(type1$dimension) && !is.null(type2$dimension) && 
      type1$dimension == type2$dimension) {
    if (is_subtype(type1$type, type2$type)) {
      return(type1)
    } else if (is_subtype(type2$type, type1$type)) {
      return(type2)
    } else {
      return(NULL)  # Incompatible
    }
  }
  
  # If different dimensions, combine constraints
  return(list(
    dimensions = c(type1$dimensions, type2$dimensions),
    base_type = if (is.null(type1$base_type)) type2$base_type else type1$base_type
  ))
}

# Annotation syntax implementation
`@` <- function(obj, annotations) {
  # Get existing type info or create new
  type_info <- attr(obj, "nsql_type", exact = TRUE) %||% list(
    base_type = infer_base_type(obj),
    dimensions = list(),
    metadata = list()
  )
  
  # Update dimensions
  for (dim_name in names(annotations)) {
    type_info$dimensions[[dim_name]] <- annotations[[dim_name]]
  }
  
  # Attach updated type info
  attr(obj, "nsql_type") <- type_info
  return(obj)
}
```

## Examples of Cross-Classification Use Cases

### 1. Data Lake File Management

```sql
-- Query files by multiple dimensions
SELECT file_path, size, modified_date 
FROM scan_directory("/data/lake/") 
WHERE typeof2(file_path, "format") == "Resource:File:DataFile:Parquet"
  AND typeof2(file_path, "domain") == "Customer"
  AND typeof2(file_path, "lifecycle") == "Validated";
```

### 2. Data Quality Assertions

```sql
-- Apply validation based on type dimensions
VALIDATE customer_data
  WHEN typeof2(customer_data, "role") == "MasterData" 
  THEN REQUIRE unique(customer_id)
  WHEN typeof2(customer_data, "privacy") == "PII"
  THEN REQUIRE !null(consent_date);
```

### 3. Contextual Processing

```sql
-- Different processing based on multiple dimensions
PROCESS data
  WHEN typeof2(data, "format") == "CSV" AND typeof2(data, "role") == "Transactional"
  THEN calculate_metrics(data)
  WHEN typeof2(data, "format") == "JSON" AND typeof2(data, "domain") == "API"
  THEN parse_api_response(data);

-- More concise version using the full type object
PROCESS data
  LET types = typeof2(data)
  WHEN types$format == "CSV" AND types$role == "Transactional"
  THEN calculate_metrics(data)
  WHEN types$format == "JSON" AND types$domain == "API"
  THEN parse_api_response(data);
```

## Function Design Principles

The design of the type system functions follows several key principles:

1. **Downward Consistency**: Enhanced functions must maintain compatibility with their predecessors
   - A newer function should accept the same parameters as the original
   - When given the same inputs, the enhanced function should produce results consistent with the original
   - Example: `typeof2(x)$R` should match `typeof(x)` for all valid inputs

2. **Suffix-Based Versioning**: Use suffixes to indicate enhanced versions
   - Numeric suffixes (e.g., `typeof2()`) indicate major enhancements
   - Descriptive suffixes (e.g., `typeof_multi()`) can be used for specialized variants
   - This pattern follows R convention (e.g., `paste()` vs `paste0()`)
   - This approach minimizes namespace conflicts while preserving conceptual continuity

3. **Default Behavior Enhancement**: Enhanced functions should offer more useful defaults
   - Default parameters should provide the most commonly needed functionality
   - For `typeof2()`, returning all dimensions by default provides maximum utility
   - Explicit dimension parameters allow specification when needed

4. **Cross-package Consistency**: Similar naming patterns should be maintained across packages
   - Functions with similar purposes should use similar naming patterns
   - Enhancement suffixes should be consistent within an ecosystem

## Type System Extension Mechanisms

The multidimensional type system is extensible through:

1. **Custom Dimensions**: Define application-specific type dimensions
   ```sql
   REGISTER DIMENSION "compliance" VALUES ("GDPR", "HIPAA", "SOX", "PCI");
   ```

2. **Custom Type Detectors**: Register functions to detect types
   ```r
   register_type_detector("format", "Parquet", function(obj) {
     # Detection logic for Parquet files
   })
   ```

3. **Annotation Processors**: Extend behavior based on annotations
   ```r
   register_annotation_processor("validation", function(obj, value) {
     # Apply validation rules based on annotation
   })
   ```

## Conclusion

NSQL's multidimensional type system provides a powerful solution to the cross-classification challenge in type systems. By supporting independent classification dimensions, intersection operators, rich metadata, and annotation syntax, it enables precise type-aware operations while maintaining the flexibility needed for complex data environments.

The system adheres to critical function design principles, particularly *downward consistency* and *suffix-based versioning*. By using `typeof2()`, the system clearly indicates its relationship to R's `typeof()` while avoiding namespace conflicts. This ensures backward compatibility with R's type system while extending functionality in a way that's immediately recognizable to R users.

This careful approach to function naming and behavior demonstrates how NSQL balances innovation with familiarity:

1. It maintains *downward consistency* by ensuring `typeof2(x)$R` matches `typeof(x)`
2. It follows *suffix-based versioning* conventions established in the R ecosystem
3. It enhances default behavior to provide more utility while preserving access to the original functionality
4. It maintains consistency with related functions across packages

This integration of R's type system with multidimensional capabilities supports the rich, multifaceted nature of real-world data resources, allowing developers to express type constraints across multiple dimensions simultaneously while minimizing the learning curve for R users.