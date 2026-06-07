# Table Naming Convention Migration Guide

## Overview

This guide provides step-by-step instructions for migrating from the old single underscore table naming convention to the new triple underscore convention in the MAMBA framework.

## Migration Summary

### Before (Incorrect)
```
df_cbz_sales_raw
df_cbz_customers_raw
df_cbz_orders_raw
df_eby_sales_raw
df_amz_sales_raw
df_amz_review_raw
```

### After (Correct)
```
df_cbz_sales___raw
df_cbz_customers___raw
df_cbz_orders___raw
df_eby_sales___raw
df_amz_sales___raw
df_amz_review___raw
```

## Migration Steps

### Step 1: Backup Existing Databases

Before starting any migration, create backups of your existing DuckDB files:

```bash
# Navigate to your data directory
cd /path/to/MAMBA/data/local_data

# Create backup directory
mkdir -p backups/pre_table_naming_migration_$(date +%Y%m%d_%H%M%S)

# Copy all database files
cp *.duckdb backups/pre_table_naming_migration_*/
```

### Step 2: Database Table Migration

#### Option A: Automatic Migration Script

Create a migration script to rename tables:

```r
# migration_script.R
library(DBI)
library(duckdb)

# Define database paths
db_paths <- list(
  raw_data = "data/local_data/raw_data.duckdb",
  staged_data = "data/local_data/staged_data.duckdb", 
  transformed_data = "data/local_data/transformed_data.duckdb"
)

# Define table mappings
table_mappings <- list(
  # Raw data tables
  "df_cbz_sales_raw" = "df_cbz_sales___raw",
  "df_cbz_customers_raw" = "df_cbz_customers___raw",
  "df_cbz_orders_raw" = "df_cbz_orders___raw",
  "df_eby_sales_raw" = "df_eby_sales___raw",
  "df_amz_sales_raw" = "df_amz_sales___raw",
  "df_amz_review_raw" = "df_amz_review___raw",
  
  # Staged data tables  
  "df_cbz_sales_staged" = "df_cbz_sales___staged",
  "df_eby_sales_staged" = "df_eby_sales___staged",
  
  # Transformed data tables
  "df_cbz_sales_standardized" = "df_cbz_sales___standardized",
  "df_cbz_sales_transformed" = "df_cbz_sales___transformed"
)

migrate_database <- function(db_path, mappings) {
  message("Migrating database: ", db_path)
  
  if (!file.exists(db_path)) {
    message("Database file does not exist: ", db_path)
    return()
  }
  
  con <- dbConnect(duckdb::duckdb(), db_path, read_only = FALSE)
  
  tryCatch({
    existing_tables <- dbListTables(con)
    
    for (old_name in names(mappings)) {
      new_name <- mappings[[old_name]]
      
      if (old_name %in% existing_tables) {
        message("  Renaming: ", old_name, " -> ", new_name)
        
        # Create new table with correct name
        dbExecute(con, sprintf("CREATE TABLE %s AS SELECT * FROM %s", new_name, old_name))
        
        # Verify migration
        old_count <- dbGetQuery(con, sprintf("SELECT COUNT(*) as count FROM %s", old_name))$count
        new_count <- dbGetQuery(con, sprintf("SELECT COUNT(*) as count FROM %s", new_name))$count
        
        if (old_count == new_count) {
          message("    Migration verified: ", old_count, " records")
          # Drop old table
          dbExecute(con, sprintf("DROP TABLE %s", old_name))
          message("    Old table dropped successfully")
        } else {
          stop("Migration verification failed for ", old_name)
        }
      }
    }
  }, finally = {
    dbDisconnect(con)
  })
}

# Migrate each database
for (db_name in names(db_paths)) {
  migrate_database(db_paths[[db_name]], table_mappings)
}

message("Migration completed successfully!")
```

#### Option B: Manual SQL Commands

If you prefer manual migration, connect to each database and run:

```sql
-- Example for raw_data.duckdb
-- Connect to database first

-- Rename sales tables
CREATE TABLE df_cbz_sales___raw AS SELECT * FROM df_cbz_sales_raw;
DROP TABLE df_cbz_sales_raw;

-- Rename customer tables  
CREATE TABLE df_cbz_customers___raw AS SELECT * FROM df_cbz_customers_raw;
DROP TABLE df_cbz_customers_raw;

-- Rename order tables
CREATE TABLE df_cbz_orders___raw AS SELECT * FROM df_cbz_orders_raw;  
DROP TABLE df_cbz_orders_raw;

-- Repeat for other platforms and databases
```

### Step 3: Update Configuration Files

#### Update app_config.yaml files

If your applications reference specific table names in configuration:

```yaml
# Before
tables:
  sales: "df_cbz_sales_raw"
  customers: "df_cbz_customers_raw"

# After  
tables:
  sales: "df_cbz_sales___raw"
  customers: "df_cbz_customers___raw"
```

### Step 4: Verify Migration

Run verification checks to ensure migration was successful:

```r
# verification_script.R
library(DBI)
library(duckdb)

verify_migration <- function(db_path, expected_tables) {
  con <- dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  
  tryCatch({
    actual_tables <- dbListTables(con)
    
    message("Database: ", basename(db_path))
    message("Expected tables: ", paste(expected_tables, collapse = ", "))
    message("Actual tables: ", paste(actual_tables, collapse = ", "))
    
    # Check for old naming pattern
    old_pattern_tables <- actual_tables[grepl("df_[a-z]+_[a-zA-Z_]+_(raw|staged|transformed)$", actual_tables)]
    old_pattern_tables <- old_pattern_tables[!grepl("___", old_pattern_tables)]
    
    if (length(old_pattern_tables) > 0) {
      warning("Old naming pattern still exists: ", paste(old_pattern_tables, collapse = ", "))
    } else {
      message("✅ No old naming patterns found")
    }
    
    # Check for new naming pattern
    new_pattern_tables <- actual_tables[grepl("___", actual_tables)]
    message("New pattern tables: ", paste(new_pattern_tables, collapse = ", "))
    
  }, finally = {
    dbDisconnect(con)
  })
}

# Verify each database
verify_migration("data/local_data/raw_data.duckdb", 
                c("df_cbz_sales___raw", "df_cbz_customers___raw", "df_cbz_orders___raw"))

verify_migration("data/local_data/staged_data.duckdb",
                c("df_cbz_sales___staged"))

verify_migration("data/local_data/transformed_data.duckdb", 
                c("df_cbz_sales___standardized"))
```

### Step 5: Test ETL Pipeline

After migration, test the entire ETL pipeline:

```bash
# Test the full pipeline
Rscript scripts/update_scripts/cbz_ETL01_0IM.R
Rscript scripts/update_scripts/cbz_ETL01_1ST.R  
Rscript scripts/update_scripts/cbz_ETL01_2TR.R

# Verify outputs
Rscript test_etl_minimal.R
```

## Rollback Procedure

If migration fails and you need to rollback:

```bash
# Stop all ETL processes
pkill -f "ETL"

# Restore from backup
cp backups/pre_table_naming_migration_*/raw_data.duckdb data/local_data/
cp backups/pre_table_naming_migration_*/staged_data.duckdb data/local_data/
cp backups/pre_table_naming_migration_*/transformed_data.duckdb data/local_data/

# Verify rollback
Rscript verification_script.R
```

## Post-Migration Checklist

- [ ] All ETL scripts use new table names
- [ ] Schema registry updated
- [ ] Principle documentation updated  
- [ ] Template scripts updated
- [ ] Test scripts updated
- [ ] Documentation files updated
- [ ] All databases migrated successfully
- [ ] ETL pipeline tested end-to-end
- [ ] No old naming patterns remain
- [ ] Backups created and verified

## Troubleshooting

### Common Issues

1. **Table not found errors**: Ensure all references use triple underscore naming
2. **Migration script failures**: Check database file permissions
3. **Incomplete migration**: Verify all databases were processed
4. **ETL script errors**: Update any hardcoded table names

### Validation Queries

```sql
-- Check for any remaining old pattern tables
SELECT name FROM sqlite_master 
WHERE type='table' 
  AND name LIKE 'df_%' 
  AND name NOT LIKE '%___%';

-- Verify new pattern tables exist  
SELECT name FROM sqlite_master 
WHERE type='table' 
  AND name LIKE '%___%';
```

## Implementation Timeline

1. **Phase 1** (Day 1): Code updates and testing
2. **Phase 2** (Day 2): Database migration on development environment  
3. **Phase 3** (Day 3): Production database migration
4. **Phase 4** (Day 4): Validation and monitoring

## Contact

For questions or issues during migration:
- Review principle MP102: ETL Output Standardization
- Check MAMBA framework documentation
- Validate against schema registry

## Version History

- **v1.0** (2025-08-28): Initial migration guide created
- Addresses: Triple underscore naming standard implementation
- Related: MP102, DM_R028, table naming conventions