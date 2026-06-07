# ETL Data Flow Separation Architecture - 2025-08-28

## Change Summary

**Redesigned ETL architecture to separate different data flows into individual pipelines**, addressing the critical issue where single ETL pipelines tried to handle multiple data types (customers, orders, sales), causing data orphaning and violating separation of concerns.

## Problem Analysis

### Current Architecture Issues

The existing `cbz_ETL01` series demonstrated a fundamental architectural flaw:

```yaml
current_problems:
  data_orphaning:
    - "cbz_ETL01_0IM.R imports ALL data types (customers, orders, sales)"
    - "cbz_ETL01_1ST.R only processes sales data"  
    - "cbz_ETL01_2TR.R only processes sales data"
    - "Result: Customers and orders remain unprocessed in raw_data"
  
  architectural_violations:
    - "Violates MP064: ETL-Derivation Separation becomes unclear"
    - "Violates MP017: Separation of Concerns"
    - "Creates maintenance complexity"
    - "Makes debugging specific data flows difficult"
```

## Solution Architecture

### 1. New Multi-Pipeline ETL Structure

**Implemented Data Type Separation**:

```
┌─ cbz_ETL_sales_[0IM|1ST|2TR].R      # Sales transaction pipeline
├─ cbz_ETL_customers_[0IM|1ST|2TR].R   # Customer profile pipeline  
├─ cbz_ETL_orders_[0IM|1ST|2TR].R      # Order header pipeline
└─ cbz_ETL_products_[0IM|1ST|2TR].R    # Product catalog pipeline
```

### 2. Naming Convention Standard

**Format**: `{platform}_ETL_{datatype}_{phase}.R`

Examples:
- `cbz_ETL_sales_0IM.R` (Cyberbiz sales import)
- `eby_ETL_customers_1ST.R` (eBay customer staging)
- `amz_ETL_orders_2TR.R` (Amazon order transform)

### 3. API Efficiency Strategy

**Shared Import Pattern**: Single API call with data distribution:

```r
# cbz_ETL_shared_0IM.R - Single API import, multiple outputs
cbz_api_import <- function() {
  api_response <- fetch_cyberbiz_data()  # Single API call
  
  # Extract and route data by type
  sales_data <- extract_sales_data(api_response)
  customers_data <- extract_customer_data(api_response) 
  orders_data <- extract_orders_data(api_response)
  
  # Write to respective raw data tables
  write_raw_data("cbz_sales", sales_data)
  write_raw_data("cbz_customers", customers_data)
  write_raw_data("cbz_orders", orders_data)
}
```

## New Principles and Rules Created

### 1. MP104: ETL Data Flow Separation Principle

**Location**: `docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP104_etl_data_flow_separation.qmd`

**Core Statement**: "Each data type must have its own dedicated ETL pipeline series"

**Key Requirements**:
- Sales, customers, orders, products must flow through separate ETL pipelines
- Each data type gets complete 0IM→1ST→2TR pipeline
- API efficiency through shared import or independent calls
- Clear orchestration and error handling patterns

### 2. DM_R028: ETL Data Type Separation Rule

**Location**: `docs/en/part1_principles/CH02_data_management/rules/DM_R028_etl_data_type_separation.qmd`

**Rule Statement**: "ETL pipelines MUST be organized by data type with dedicated scripts for each data type and phase"

**Mandatory Requirements**:
- Script naming: `{platform}_ETL_{datatype}_{phase}.R`
- Single responsibility: No mixed data types per script
- Complete pipelines: All three phases required
- Validation framework for compliance checking

## Migration Strategy

### Step 1: Legacy to New Mapping

```yaml
migration_plan:
  "cbz_ETL01_0IM.R":
    splits_into:
      - "cbz_ETL_sales_0IM.R"
      - "cbz_ETL_customers_0IM.R" 
      - "cbz_ETL_orders_0IM.R"
  
  "cbz_ETL01_1ST.R":
    becomes: "cbz_ETL_sales_1ST.R"
    needs_new:
      - "cbz_ETL_customers_1ST.R"
      - "cbz_ETL_orders_1ST.R"
  
  "cbz_ETL01_2TR.R":
    becomes: "cbz_ETL_sales_2TR.R"
    needs_new:
      - "cbz_ETL_customers_2TR.R"
      - "cbz_ETL_orders_2TR.R"
```

### Step 2: Implementation Plan

1. **Audit Current Mixed ETLs**
   - Identify all mixed-type ETL scripts
   - Analyze data types handled by each

2. **Create Data Type Extraction**
   - Extract sales logic from existing scripts
   - Extract customer logic from existing scripts
   - Extract order logic from existing scripts

3. **Generate New Separated Pipelines**
   - Create specialized ETL scripts following naming convention
   - Implement single responsibility per script
   - Add proper validation and error handling

4. **Update Derivations**
   - Modify D01, D02 derivations to consume separated outputs
   - Update cross-data-type joins and dependencies

## Database Organization

### Table Naming Pattern

Following MP102 standardization:

```yaml
table_structure:
  raw_data: ["df_cbz_sales_raw", "df_cbz_customers_raw", "df_cbz_orders_raw"]
  staged_data: ["df_cbz_sales_staged", "df_cbz_customers_staged", "df_cbz_orders_staged"]
  transformed_data: ["df_cbz_sales_transformed", "df_cbz_customers_transformed", "df_cbz_orders_transformed"]
```

### Cross-Pipeline Dependencies

```r
# D01_customer_analysis.R - Consuming multiple ETL outputs
d01_customer_analysis <- function() {
  sales_data <- tbl2(transformed_data, "df_cbz_sales_transformed") %>% collect()
  customers_data <- tbl2(transformed_data, "df_cbz_customers_transformed") %>% collect()
  orders_data <- tbl2(transformed_data, "df_cbz_orders_transformed") %>% collect()
  
  # Cross-data-type analysis with proper joins
  customer_analysis <- sales_data %>%
    left_join(customers_data, by = "customer_id") %>%
    left_join(orders_data, by = "order_id")
}
```

## Pipeline Orchestration

### Sequential Execution Pattern

```r
execute_cbz_etl_complete <- function() {
  # Phase 1: Import (parallel execution possible)
  execute_parallel(cbz_ETL_sales_0IM, cbz_ETL_customers_0IM, cbz_ETL_orders_0IM)
  
  # Phase 2: Staging (parallel execution possible)
  execute_parallel(cbz_ETL_sales_1ST, cbz_ETL_customers_1ST, cbz_ETL_orders_1ST)
  
  # Phase 3: Transform (parallel execution possible)
  execute_parallel(cbz_ETL_sales_2TR, cbz_ETL_customers_2TR, cbz_ETL_orders_2TR)
}
```

### Error Isolation

```r
execute_etl_with_isolation <- function(pipeline_name, pipeline_function) {
  tryCatch({
    result <- pipeline_function()
    log_success(pipeline_name, result)
  }, error = function(e) {
    log_error(pipeline_name, e$message)
    # Other pipelines continue executing independently
  })
}
```

## Benefits Achieved

1. **Clear Responsibilities**: Each pipeline handles exactly one data type
2. **Independent Debugging**: Issues in customer ETL don't affect sales ETL
3. **Parallel Processing**: Data types can be processed concurrently
4. **Error Isolation**: Failures don't cascade across data types
5. **Maintenance Simplicity**: Changes isolated to relevant data type
6. **Resource Optimization**: Different memory/CPU requirements per data type
7. **API Efficiency**: Optimized through shared or independent patterns

## Validation Framework

### Compliance Checking Functions

```r
# Validate naming convention
validate_etl_naming_convention(script_path)

# Check pipeline completeness  
validate_pipeline_completeness(script_directory)

# Verify single responsibility
validate_single_responsibility(script_path)
```

### Compliance Checklist

- [ ] All ETL scripts follow `{platform}_ETL_{datatype}_{phase}.R` naming
- [ ] No script handles multiple data types
- [ ] Each data type has complete 0IM→1ST→2TR pipeline
- [ ] Output tables follow standardized pattern
- [ ] API calls are optimized for efficiency
- [ ] Legacy mixed-type ETLs migrated

## Template Scripts

Templates will be provided for:
- Sales ETL Pipeline Template
- Customer ETL Pipeline Template
- Order ETL Pipeline Template
- Product ETL Pipeline Template
- Shared API Import Template

## Relationships to Existing Principles

- **Implements MP064**: ETL-Derivation Separation Principle
- **Extends MP102**: ETL Output Standardization Principle
- **Enforces MP017**: Separation of Concerns
- **Utilizes MP092**: Platform ID Standard
- **Supports MP059**: Unidirectional Data Flow

## Migration Timeline

1. **Week 1**: Complete principle documentation and validation framework
2. **Week 2**: Audit existing ETL scripts and create migration plans
3. **Week 3**: Implement separated ETL scripts for priority platforms
4. **Week 4**: Update derivation functions and test complete flows
5. **Week 5**: Validate and deploy new architecture

## Conclusion

This ETL Data Flow Separation architecture resolves the critical issue of mixed-type ETL pipelines by implementing proper data type isolation. The new architecture maintains API efficiency while providing clear separation of concerns, enabling parallel processing, and improving maintainability.

The solution preserves the existing three-phase ETL pattern (0IM→1ST→2TR) while extending it to handle multiple data types through dedicated pipelines, resulting in a more scalable and maintainable data processing system.

---

**Author**: Claude  
**Date**: 2025-08-28  
**Status**: Implemented  
**Review**: Pending validation of existing codebase migration