---
id: "NSQL_TYPEOF_FUNCTION"
title: "NSQL typeof() Function Specification"
type: "record"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "NSQL_EXTENSION_TYPES": "Extension Types in NSQL"
  - "NSQL_PATH_TYPES": "Path Types in NSQL"
  - "NSQL_WORD_CLASSES": "Word Classes in NSQL"
---

# NSQL typeof() Function Specification

## Overview

The `typeof()` function is a fundamental operation in NSQL that identifies and returns the type of any given resource, expression, or value. This function is essential for type-based operations, validations, and conditional processing in NSQL queries and scripts.

## Syntax

```
typeof(expression) -> TypeIdentifier
```

Where:
- `expression` is any valid NSQL expression, path, resource reference, or literal value
- `TypeIdentifier` is a string representing the identified type

## Return Value Structure

The `typeof()` function returns a structured type identifier with the following format:

```
PrimaryType:SubType:SpecificType
```

For example:
- `Resource:File:DataFile:CSV`
- `Resource:Directory`
- `Value:Numeric:Integer`
- `Path:DataObjectPath`

## Type Categories

### Resource Types

When called on resources (files or directories):

| Input Example | Return Value |
|---------------|--------------|
| typeof("/path/to/directory/") | "Resource:Directory" |
| typeof("/path/to/file.csv") | "Resource:File:DataFile:CSV" |
| typeof("/path/to/script.R") | "Resource:File:CodeFile:R" |
| typeof("/path/to/config.yaml") | "Resource:File:ConfigurationFile:YAML" |

### Path Types

When called on path expressions:

| Input Example | Return Value |
|---------------|--------------|
| typeof(data.customer.id) | "Path:AttributePath" |
| typeof(customers_df) | "Path:DataObjectPath" |
| typeof(calculate_total()) | "Path:FunctionPath" |

### Value Types

When called on literal values or expressions:

| Input Example | Return Value |
|---------------|--------------|
| typeof(42) | "Value:Numeric:Integer" |
| typeof(3.14) | "Value:Numeric:Float" |
| typeof("hello") | "Value:Text:String" |
| typeof(TRUE) | "Value:Logical:Boolean" |
| typeof(NULL) | "Value:Special:Null" |
| typeof(c(1,2,3)) | "Value:Collection:Vector:Numeric" |
| typeof(list(a=1, b="x")) | "Value:Collection:List:Mixed" |

## Implementation Details

### Type Resolution Process

The `typeof()` function follows this resolution process:

1. **Check if expression is a direct value** - If so, determine its primitive type
2. **Check if expression is a path** - If so, analyze its structure to determine path type
3. **Check if expression refers to a resource** - If so, examine the resource:
   a. If it's a folder, return "Resource:Folder"
   b. If it's a file, determine its type based on extension and/or content

### Extension-Based Type Resolution

For files, `typeof()` employs the following strategy:

1. Extract file extension from path
2. Look up the extension in the extension type registry
3. If found, return the corresponding type
4. If not found, examine file content for type detection
5. If content examination is inconclusive, return "Resource:File:Unknown"

## Usage in NSQL Queries

### Type Checking

```sql
SELECT * FROM data
WHERE typeof(data.column) == "Value:Numeric:Integer"
```

### Conditional Processing

```sql
SELECT 
  CASE 
    WHEN typeof(file) == "Resource:File:DataFile:CSV" THEN read_csv(file)
    WHEN typeof(file) == "Resource:File:DataFile:XLSX" THEN read_excel(file)
    ELSE NULL
  END AS data
FROM file_list
```

### Type Filtering

```sql
SELECT file_path 
FROM scan_directory("/data/")
WHERE typeof(file_path) LIKE "Resource:File:DataFile:%"
```

## RSQL Implementation

```r
nsql_typeof <- function(expression) {
  # Handle direct R values
  if (is.numeric(expression)) {
    if (identical(expression, as.integer(expression))) {
      return("Value:Numeric:Integer")
    } else {
      return("Value:Numeric:Float")
    }
  } else if (is.character(expression)) {
    return("Value:Text:String")
  } else if (is.logical(expression)) {
    return("Value:Logical:Boolean")
  } else if (is.null(expression)) {
    return("Value:Special:Null")
  } else if (is.vector(expression) && length(expression) > 1) {
    base_type <- if(is.numeric(expression)) "Numeric" else
                 if(is.character(expression)) "Text" else
                 if(is.logical(expression)) "Logical" else "Mixed"
    return(paste0("Value:Collection:Vector:", base_type))
  } else if (is.list(expression)) {
    types <- unique(sapply(expression, function(x) {
      if (is.numeric(x)) return("Numeric")
      if (is.character(x)) return("Text")
      if (is.logical(x)) return("Logical")
      return("Other")
    }))
    list_type <- if(length(types) == 1) types[1] else "Mixed"
    return(paste0("Value:Collection:List:", list_type))
  }
  
  # Handle file paths
  if (is.character(expression) && file.exists(expression)) {
    if (dir.exists(expression)) {
      return("Resource:Directory")
    } else {
      # Determine file type based on extension
      ext <- tolower(tools::file_ext(expression))
      
      # Map extension to type
      if (ext %in% c("csv", "tsv", "txt")) {
        return("Resource:File:DataFile:CSV")
      } else if (ext %in% c("xlsx", "xls")) {
        return("Resource:File:DataFile:EXCEL")
      } else if (ext == "rds") {
        return("Resource:File:DataFile:RDS")
      } else if (ext == "feather") {
        return("Resource:File:DataFile:FEATHER")
      } else if (ext %in% c("r", "R")) {
        return("Resource:File:CodeFile:R")
      } else if (ext == "py") {
        return("Resource:File:CodeFile:PYTHON")
      } else if (ext %in% c("yaml", "yml")) {
        return("Resource:File:ConfigurationFile:YAML")
      } else if (ext == "md") {
        return("Resource:File:DocumentationFile:MARKDOWN")
      } else {
        # Try content-based detection if extension not recognized
        # [Content detection logic would go here]
        
        return("Resource:File:Unknown")
      }
    }
  }
  
  # Handle NSQL path expressions
  # This is simplified and would need to be expanded in a real implementation
  if (is.character(expression) && grepl("\\.", expression)) {
    parts <- strsplit(expression, "\\.")[[1]]
    if (length(parts) >= 2 && parts[length(parts)] %in% c("id", "name", "value", "date")) {
      return("Path:AttributePath")
    } else if (length(parts) == 1) {
      return("Path:DataObjectPath")
    } else if (grepl("\\(\\)$", expression)) {
      return("Path:FunctionPath")
    }
  }
  
  # Default case
  return("Unknown")
}
```

## Type Recognition Rules

### File Type Recognition

1. **Extension-Based**: Primary method using file extension
2. **Content-Based**: Secondary method examining file content
3. **Context-Based**: Tertiary method using context clues from queries

### Path Type Recognition

1. **Dot Notation**: Paths with dots may be attribute paths
2. **Function Call**: Expressions ending with () are function paths
3. **Data Object**: Single identifiers are likely data object paths

### Value Type Recognition

1. **Primitive Type Check**: Direct check for primitive R/SQL types
2. **Collection Type Check**: Examine elements for vectors/lists
3. **Type Conversion Check**: Test if value can be converted cleanly

## typeof() vs is() Function

The `typeof()` function returns a type identifier, while the related `is()` function performs boolean type checking:

```sql
-- typeof() returns a type string
SELECT typeof(column) FROM data

-- is() returns TRUE/FALSE
SELECT * FROM data WHERE is(column, "Numeric:Integer")
```

## Extension Mechanisms

The typeof() function is extensible through:

1. **Type Registry**: Register custom types with their detection rules
2. **Type Resolution Hooks**: Custom handlers for special type detection
3. **Type Aliases**: Define type aliases for commonly used complex types

Example of registering a custom type:

```r
register_nsql_type(
  name = "Resource:File:DataFile:PARQUET",
  extensions = c("parquet"),
  mime_type = "application/x-parquet",
  detection_function = function(content) {
    # Custom detection logic for Parquet format
    return(is_valid_parquet(content))
  }
)
```

## Conclusion

The `typeof()` function provides NSQL with robust type identification capabilities, supporting better type safety, more precise operations, and clearer error messaging. By identifying the specific types of resources, paths, and values, `typeof()` enables NSQL to apply the appropriate operations and optimizations for each type.