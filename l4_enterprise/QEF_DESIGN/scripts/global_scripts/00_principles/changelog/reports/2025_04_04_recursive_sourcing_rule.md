---
date: "2025-04-04"
title: "Recursive Sourcing Rule"
type: "record"
author: "Claude"
related_to:
  - "R13": "Initialization Sourcing"
  - "P03": "Debug Principles"
---

# Recursive Sourcing Rule Proposal

## Summary

This record proposes a new rule (R33_recursive_sourcing) that requires all initialization scripts to source R files recursively from subdirectories. This rule addresses a critical issue in APP_MODE initialization where components in nested directories aren't properly loaded.

## Current Issue

The current initialization process in APP_MODE fails to properly source R files in nested subdirectories, particularly:

1. UI components in `update_scripts/global_scripts/10_rshinyapp_components/sidebars/sidebarHybrid`
2. Other components organized in subdirectories according to their functional grouping

This causes the app to fail because it can't find essential components, even though they exist in the codebase.

## Proposed Rule

### R33: Recursive Sourcing Rule

All initialization scripts must recursively source R files from subdirectories, following these guidelines:

1. **Comprehensive Scanning**: Scripts must scan all subdirectories of specified parent directories
2. **Depth-First Sourcing**: Files in deeper directories should be sourced before their parent directories
3. **File Filtering**: Sourcing should follow consistent patterns for inclusion and exclusion
4. **Error Handling**: Failed source operations must be tracked and reported
5. **Consistent Pattern Matching**: File pattern matching must be consistent across all operating modes

## Implementation Example

The initialization script should implement recursive sourcing with proper error handling:

```r
# Enhanced get_r_files_recursive function with better filtering and sorting
get_r_files_recursive <- function(dir_path, 
                                 include_pattern = "\\.R$", 
                                 exclude_pattern = NULL,
                                 max_depth = Inf) {
  
  # Check if directory exists
  if (!dir.exists(dir_path)) {
    warning("Directory does not exist: ", dir_path)
    return(character(0))
  }
  
  # Get all files and directories
  all_contents <- list.files(dir_path, full.names = TRUE, recursive = FALSE, 
                             include.dirs = TRUE, all.files = FALSE)
  
  # Split into files and directories
  is_dir <- dir.exists(all_contents)
  files <- all_contents[!is_dir]
  subdirs <- all_contents[is_dir]
  
  # Filter files based on include pattern
  if (!is.null(include_pattern)) {
    files <- files[grepl(include_pattern, basename(files))]
  }
  
  # Filter files based on exclude pattern
  if (!is.null(exclude_pattern)) {
    files <- files[!grepl(exclude_pattern, basename(files))]
  }
  
  # Recursively process subdirectories if not at max depth
  if (length(subdirs) > 0 && max_depth > 1) {
    subdir_files <- lapply(subdirs, function(subdir) {
      get_r_files_recursive(subdir, 
                          include_pattern = include_pattern,
                          exclude_pattern = exclude_pattern,
                          max_depth = max_depth - 1)
    })
    
    # Combine all files
    files <- c(files, unlist(subdir_files))
  }
  
  return(files)
}

# Enhanced source_all_files function with better error handling
source_all_files <- function(dir_path, 
                           include_pattern = "^(fn_|ui_|server_|defaults_).*\\.R$",
                           exclude_pattern = "(initialization|deinitialization)",
                           verbose = VERBOSE_INITIALIZATION) {
  
  # Get all R files recursively
  r_files <- get_r_files_recursive(dir_path, 
                                 include_pattern = include_pattern,
                                 exclude_pattern = exclude_pattern)
  
  # Sort files to ensure deterministic loading order
  r_files <- sort(r_files)
  
  # Track results
  loaded_files <- character(0)
  failed_files <- character(0)
  
  # Source each file
  if (length(r_files) > 0) {
    for (file in r_files) {
      if (verbose) {
        message("Sourcing: ", file)
      }
      
      result <- tryCatch({
        source(file)
        if (verbose) message("Successfully loaded: ", file)
        TRUE
      }, error = function(e) {
        message("Error loading ", file, ": ", e$message)
        FALSE
      })
      
      if (result) {
        loaded_files <- c(loaded_files, file)
      } else {
        failed_files <- c(failed_files, file)
      }
    }
  }
  
  return(list(
    loaded = loaded_files,
    failed = failed_files
  ))
}
```

## Application to Initialization Scripts

This rule will require modifications to all initialization scripts, particularly:

1. **sc_initialization_app_mode.R**: Ensure it recursively sources all UI and server components
2. **sc_initialization_global_mode.R**: Apply the same recursive sourcing pattern
3. **sc_initialization_update_mode.R**: Apply the same recursive sourcing pattern

## Benefits

Implementing this rule will:

1. Ensure all components are properly loaded regardless of directory depth
2. Provide consistent behavior across operating modes
3. Make debugging easier by properly tracking and reporting sourcing failures
4. Allow more logical organization of components into subdirectories without breaking initialization

## Relationship to Existing Principles

This rule extends and supports:

1. **R13 (Initialization Sourcing)**: Adds the requirement for recursive sourcing
2. **P03 (Debug Principles)**: Improves error reporting for easier debugging
3. **MP16 (Modularity)**: Enables better organization of components by functional grouping

## Implementation Plan

1. Create the new rule document R33_recursive_sourcing.md
2. Update the initialization scripts to use the enhanced recursive sourcing function
3. Add appropriate documentation and examples
4. Update the README.md to reference the new rule

## Conclusion

The Recursive Sourcing Rule addresses a critical issue in the initialization process and provides a more robust approach to loading components. By ensuring all files are properly sourced regardless of their directory depth, this rule will improve system reliability and support better code organization.