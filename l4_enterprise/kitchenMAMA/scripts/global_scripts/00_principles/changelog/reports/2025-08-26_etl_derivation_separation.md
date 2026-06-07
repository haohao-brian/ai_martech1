# Change Log: ETL-Derivation Separation Implementation
Date: 2025-08-26
Author: Claude

## Summary
Implemented MP064 (ETL-Derivation Separation Principle) and restructured ETL01 and D01 to follow clear separation of concerns between data preparation (ETL) and business logic (Derivation).

## Changes Made

### 1. Created New Principle: MP064
**File**: `docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP064_etl_derivation_separation.qmd`

**Purpose**: Establishes clear boundaries between ETL pipelines and Derivation functions
- ETL: Pure data preparation (0IM→1ST→2TR pattern)
- Derivation: Business logic and analytics
- No mixing of concerns

### 2. Restructured ETL01
**Old File**: `ETL01_extract.qmd` (deleted)
**New File**: `ETL01_sales_data_preparation.qmd`

**Changes**:
- Renamed to clearly indicate data preparation purpose
- Removed all customer aggregation logic
- Removed RFM calculations
- Removed DNA analysis
- Focused on three phases: 0IM (Import) → 1ST (Staging) → 2TR (Transform)
- Output: Transaction-level standardized sales data

### 3. Updated D01
**File**: `D01_dna_analysis_flow.qmd`

**Changes**:
- Updated to consume ETL01 output instead of raw data
- Removed all data import/cleansing/transformation sections
- Focused purely on business logic:
  - Customer aggregation
  - RFM calculation
  - DNA analysis
  - Segmentation
- Added clear integration pattern with ETL01

## Benefits

1. **Clear Responsibilities**: Each component has single, well-defined purpose
2. **Reusability**: ETL outputs can feed multiple derivations
3. **Maintainability**: Changes to business logic don't affect data prep
4. **Testability**: ETL and Derivations can be tested independently
5. **Scalability**: ETL can be optimized separately from business logic

## Migration Pattern

### Before (Mixed Concerns)
```r
process_sales <- function() {
  data <- import_csv("sales.csv")        # ETL concern
  data <- clean_data(data)               # ETL concern
  customer_rfm <- calculate_rfm(data)    # Business logic
  segments <- segment_customers(rfm)     # Business logic
  return(segments)
}
```

### After (Separated)
```r
# ETL01: Data preparation only
etl01_sales_preparation <- function() {
  raw <- import_csv("sales.csv")
  staged <- standardize_format(raw)
  transformed <- apply_schema(staged)
  return(transformed)  # Just clean data
}

# D01: Business logic only
d01_customer_analysis <- function() {
  sales_data <- read_from_etl("transformed_sales")
  customer_rfm <- calculate_rfm(sales_data)
  segments <- segment_customers(customer_rfm)
  return(segments)
}
```

## Implementation Guidelines

1. All new ETL pipelines must follow the three-phase pattern
2. All business logic must be implemented as Derivations
3. No mixing of data preparation and business logic
4. Clear naming: ETL prefix for data prep, D prefix for derivations
5. Each pipeline must specify inputs and outputs

## Files Affected

- Created: `MP064_etl_derivation_separation.qmd`
- Created: `ETL01_sales_data_preparation.qmd`
- Modified: `D01_dna_analysis_flow.qmd`
- Deleted: `ETL01_extract.qmd`

## Next Steps

1. Update other ETL pipelines to follow the three-phase pattern
2. Update other Derivations to consume ETL outputs
3. Document the pattern in developer guidelines
4. Create test suites for ETL and Derivations separately