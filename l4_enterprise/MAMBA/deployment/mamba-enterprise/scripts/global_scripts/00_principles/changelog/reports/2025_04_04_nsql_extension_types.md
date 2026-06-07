---
id: "NSQL_EXTENSION_TYPES"
title: "NSQL Extension Types System"
type: "record"
date_created: "2025-04-04"
date_modified: "2025-04-04"
author: "Claude"
relates_to:
  - "NSQL_PATH_TYPES": "Path Types in NSQL"
  - "NSQL_WORD_CLASSES": "Word Classes in NSQL"
  - "MP01": "Primitive Terms and Definitions"
---

# NSQL Extension Types System

## Overview

NSQL requires a structured type system for handling different kinds of file extensions and resource types. This system defines the taxonomy of extension types in NSQL, allowing for more precise manipulation of resources in data pipelines and scripts.

## Type Categories

### 1. Resource Types

Top-level categorization of resources:

```
ResourceType
├── Directory
└── File
    ├── DataFile
    │   ├── StructuredDataFile
    │   └── UnstructuredDataFile
    ├── CodeFile
    ├── ConfigurationFile
    └── DocumentationFile
```

### 2. File Extension Types

Specific file formats based on extensions:

```
FileExtensionType
├── Data
│   ├── Tabular
│   │   ├── CSV (.csv)
│   │   ├── Excel (.xlsx, .xls)
│   │   ├── Feather (.feather)
│   │   ├── Parquet (.parquet)
│   │   └── RDS (.rds)
│   ├── Hierarchical
│   │   ├── JSON (.json)
│   │   ├── XML (.xml)
│   │   └── YAML (.yaml, .yml)
│   └── Binary
│       ├── Database (.db, .sqlite)
│       └── Binary (.bin)
├── Code
│   ├── R (.R, .r)
│   ├── Python (.py)
│   ├── SQL (.sql)
│   └── Shell (.sh)
├── Configuration
│   ├── INI (.ini)
│   ├── ENV (.env)
│   └── CONF (.conf)
└── Documentation
    ├── Markdown (.md)
    ├── Text (.txt)
    ├── HTML (.html)
    └── PDF (.pdf)
```

## Extension Properties

Each extension type has the following properties:

1. **MIME Type**: Standard MIME type for the extension
2. **Default Encoding**: Default character encoding (UTF-8, binary, etc.)
3. **Handling Functions**: Associated NSQL functions for reading/writing
4. **Validation Rules**: Required structure or content validation

## NSQL Syntax for Extension Types

### Type Assertion

```
x.as[TYPE] - Convert to specified type
file.as[CSV] - Treat file as CSV
path.as[FOLDER] - Treat path as folder
```

### Type Checking

```
x.is[TYPE] - Check if x is of specified type
file.is[EXCEL] - Check if file is Excel format
```

### Extension Operations

```
path.extension - Get file extension
path.withExtension("csv") - Change file extension
```

## Implementation in RSQL

In RSQL implementation, extension types are represented as:

```r
nsql_extension_types <- list(
  "directory" = list(
    mime_type = "application/x-directory",
    default_encoding = NULL,
    handling_functions = list(
      read = "dir_ls",
      write = "dir_create",
      exists = "dir_exists"
    )
  ),
  "csv" = list(
    mime_type = "text/csv",
    default_encoding = "UTF-8",
    handling_functions = list(
      read = "read_csv",
      write = "write_csv",
      exists = "file_exists"
    ),
    validation = function(content) {
      # Validation logic for CSV
      return(TRUE)
    }
  ),
  "xlsx" = list(
    mime_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    default_encoding = "binary",
    handling_functions = list(
      read = "read_excel",
      write = "write_xlsx",
      exists = "file_exists"
    )
  ),
  "rds" = list(
    mime_type = "application/x-r-rds",
    default_encoding = "binary",
    handling_functions = list(
      read = "readRDS",
      write = "saveRDS",
      exists = "file_exists"
    )
  ),
  "feather" = list(
    mime_type = "application/x-feather",
    default_encoding = "binary",
    handling_functions = list(
      read = "read_feather",
      write = "write_feather",
      exists = "file_exists"
    )
  )
)
```

## Auto-Detection Rules

NSQL can automatically detect extension types using these rules:

1. **Extension Matching**: Check file extension against known types
2. **Content Sniffing**: Examine file header/content for type-specific patterns
3. **Context Hints**: Use context from surrounding code or query

Example in RSQL:

```r
detect_file_type <- function(file_path) {
  # Get extension
  ext <- tolower(tools::file_ext(file_path))
  
  # Check against known extensions
  if (ext %in% names(nsql_extension_types)) {
    return(ext)
  }
  
  # Content sniffing for headerless files
  if (file.exists(file_path)) {
    header <- readBin(file_path, "raw", 50)
    
    # CSV detection
    if (all(header[1:5] %in% c(44, 48:57, 65:90, 97:122, 9, 10, 13, 32))) {
      return("csv")
    }
    
    # Other type detection logic...
  }
  
  # Default to text if cannot determine
  return("txt")
}
```

## Extension Type Coercion

Rules for converting between extension types:

| From | To | Coercion Method |
|------|-------|----------------|
| CSV | XLSX | read_csv() followed by write_xlsx() |
| RDS | CSV | readRDS() followed by data formatting and write_csv() |
| XLSX | FEATHER | read_excel() followed by write_feather() |
| Any | TEXT | Content extraction and write_text() |

## Integration with Path Types

Extension types work together with NSQL path types:

* **AttributePath** - Not typically associated with extensions
* **DataObjectPath** - Often points to tabular data extensions (.csv, .xlsx, .rds)
* **FunctionPath** - Typically points to code extensions (.R, .py, .sql)

## Type Error Handling

When extension type errors occur:

1. Error types: IncompatibleExtensionError, UnknownExtensionError, ValidationError
2. Error resolution: Default to best-effort handling or explicit error
3. User feedback: Informative messages suggesting proper extension handling

## Conclusion

The NSQL Extension Types system provides a comprehensive framework for handling different file and directory resources within NSQL. This enhances the language's ability to manage diverse data sources and ensures appropriate handling based on the resource type.