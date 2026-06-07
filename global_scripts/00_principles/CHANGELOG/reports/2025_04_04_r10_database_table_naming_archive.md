---
date: "2025-04-04"
title: "Archiving of R10 Database Table Naming Rule"
type: "record"
author: "Claude"
related_to:
  - "R10": "Database Table Naming"
  - "R23": "Object Naming Convention"
  - "R27": "Object File Name Translation"
---

# Archiving of R10 Database Table Naming Rule

## Summary

The R10 (Database Table Naming) rule has been archived as its functionality has been incorporated into R23 (Object Naming Convention) and R27 (Object File Name Translation). This consolidation eliminates conflicts between naming patterns and creates a more cohesive, unified naming system across the codebase.

## Reason for Archiving

The original R10 rule specified a snake_case naming pattern for database tables:
- Pattern: `[entity]_[qualifier]_[type]` (e.g., `customer_active_dta`)
- Used underscores throughout

This conflicted with R23, which specifies dot notation:
- Pattern: `df.platform.purpose.by_id1.by_id2.by_id3.at_dimension1...`
- Uses dots to separate components

Having two competing naming conventions for related objects (database tables and data frames) created confusion and inconsistency.

## Changes Made

1. **Creation of R31 (Data Frame Creation Strategy Pattern)**:
   - Created a new rule dedicated to the Strategy Pattern for data frame creation
   - Expanded the Strategy Pattern implementation from R10 into a comprehensive design pattern
   - Added more examples and use cases for different data frame types
   - Focused purely on implementation patterns, separate from naming conventions
   
2. **Archived Original R10**:
   - Moved R10 to the global_scripts/99_archive directory
   - Marked as archived with appropriate metadata
   - Added references to R23 and R31 for the replacement functionality

2. **Alignment with R27**:
   - Ensured the table name translation follows the principles in R27
   - Added examples demonstrating the conversion

## Key Concepts Preserved

The following concepts from R10 were preserved in the new R31 rule:

1. **Strategy Pattern for Data Frame Creation**:
   - Registry of data frame creation strategies
   - Registration mechanism for new strategies
   - Dispatch function to execute the appropriate strategy

2. **Extended Implementation**:
   - Support for various data frame types (standard, indexed, time-series)
   - Helper functions for validation and configuration
   - Consistent interface for all data frame operations

## Implementation Example

The new R31 rule expands on the Strategy Pattern concept with comprehensive support for various data frame types:

```r
# Register custom strategies
register_df_creator("standard", standard_df_creator_function)
register_df_creator("indexed", indexed_df_creator_function)
register_df_creator("time_series", time_series_df_creator_function)

# Create different types of data frames
df.amazon.customer <- create_or_replace_df("df.amazon.customer", customer_data)
df.amazon.product <- create_or_replace_df("df.amazon.product", product_data, "indexed", 
                                         index_columns = c("product_id", "category"))
df.amazon.sales_daily <- create_or_replace_df("df.amazon.sales_daily", sales_data, 
                                             "time_series", time_column = "sale_date")
```

## Impact and Benefits

This reorganization:
1. Separates implementation patterns (R31) from naming conventions (R23)
2. Provides a more detailed and comprehensive approach to data frame management
3. Expands the Strategy Pattern to handle various data frame types and storage options
4. Creates a cleaner architectural separation of concerns
5. Makes it easier to extend data frame functionality in the future

## Conclusion

Archiving R10 and extracting its Strategy Pattern implementation into the new R31 rule creates a better separation of concerns while preserving the valuable design pattern. The naming aspects of databases are now handled by R23 and R27, while the implementation pattern for data frame creation has been expanded into its own dedicated rule.

This approach maintains the strengths of the original R10 rule while improving the organization of the rule system as a whole, adhering more closely to the Separation of Concerns principle (MP17).
