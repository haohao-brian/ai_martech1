# Company-Specific ETL Naming Rule Addition

**Date**: 2025-08-28
**Author**: Claude
**Type**: New Rule Addition

## Summary

Added DM_R037 (Company-Specific ETL Naming Rule) to address the need for distinguishing between generic platform ETLs and company-specific implementations, particularly for MAMBA's custom eBay SQL Server setup.

## Changes Made

### 1. New Rule: DM_R037

- **Location**: `docs/en/part1_principles/CH02_data_management/rules/DM_R037_company_specific_etl_naming.qmd`
- **Purpose**: Define naming pattern for company-specific ETL implementations
- **Pattern**: `{platform}_ETL_{datatype}_{phase}___{company}.R`
- **Key Feature**: Triple underscore (`___`) separator for company codes

### 2. Updated MP104 (ETL Data Flow Separation Principle)

- Added reference to DM_R037
- Added section on "Company-Specific Implementations"
- Included examples of MAMBA's eBay SQL Server setup
- Clarified when to use company identifiers vs. standard naming

### 3. Updated DM_R028 (ETL Data Type Separation Rule)

- Added company-specific pattern as valid extension
- Updated validation functions to recognize company suffixes
- Added examples of compliant company-specific ETLs

### 4. New Implementation Guide

- **Location**: `docs/en/part2_implementations/CH09_etl_pipelines/ETL_company_specific_implementation.qmd`
- **Contents**: Complete implementation examples for MAMBA's eBay pipeline
- **Includes**: Configuration files, helper functions, migration strategies

## Rationale

MAMBA has their own eBay infrastructure that differs significantly from standard eBay APIs:

1. **Custom Database**: SQL Server at 125.227.84.85 (not eBay's servers)
2. **SSH Tunnel Access**: Via 220.128.138.146
3. **Custom Business Logic**: MAMBA-specific SKU mappings, commission rates, territory filters
4. **Proprietary Data Fields**: Custom columns not available in standard eBay API

Without clear naming distinction, it would be unclear whether an ETL script connects to:
- Standard eBay Marketplace API (generic implementation)
- MAMBA's own eBay SQL Server (company-specific implementation)

## Impact

### Positive Impacts

1. **Clarity**: Immediately identifies company-specific implementations
2. **Maintainability**: Easier to manage custom vs. generic ETLs
3. **Scalability**: Multiple companies can have their own implementations
4. **Debugging**: Clear separation helps isolate issues
5. **Portability**: Generic ETLs remain reusable across companies

### Migration Required

Existing MAMBA ETL scripts should be renamed:
- `eby_ETL_sales_0IM.R` → `eby_ETL_sales_0IM___MAMBA.R`
- `eby_ETL_sales_1ST.R` → `eby_ETL_sales_1ST___MAMBA.R`
- `eby_ETL_sales_2TR.R` → `eby_ETL_sales_2TR___MAMBA.R`

## Implementation Details

### Naming Pattern

```
{platform}_ETL_{datatype}_{phase}___{company}.R
    ^          ^          ^         ^
    |          |          |         |
    |          |          |         Company code (UPPERCASE, 3-10 chars)
    |          |          |
    |          |          ETL phase (0IM, 1ST, 2TR)
    |          |
    |          Data type (sales, customers, orders, products)
    |
    Platform ID (3 letters)
```

### Triple Underscore Rationale

The triple underscore (`___`) was chosen because:
1. **Visual Distinction**: Clearly separates company code from rest of filename
2. **No Conflicts**: Doesn't conflict with existing single/double underscore patterns
3. **Grep-Friendly**: Easy to search for company-specific files with `*___*.R`
4. **Sort Order**: Groups company-specific files together in directory listings

### Company Code Standards

- **Format**: UPPERCASE letters only
- **Length**: 3-10 characters
- **Examples**: MAMBA, ACME, WIDGET, ABC
- **No**: Special characters, numbers, lowercase

## Example Implementation

### MAMBA's eBay Sales Pipeline

```r
# eby_ETL_sales_0IM___MAMBA.R
mamba_eby_sales_import <- function() {
  # Establish SSH tunnel to MAMBA's infrastructure
  ssh_tunnel <- establish_ssh_tunnel(
    ssh_host = "220.128.138.146",
    ssh_port = 22,
    local_port = 1433,
    remote_host = "125.227.84.85",
    remote_port = 1433
  )
  
  # Connect to MAMBA's SQL Server
  con <- dbConnect(
    odbc::odbc(),
    Driver = "ODBC Driver 17 for SQL Server",
    Server = "localhost,1433",
    Database = "ebay_mamba_db",
    UID = Sys.getenv("MAMBA_DB_USER"),
    PWD = Sys.getenv("MAMBA_DB_PASSWORD")
  )
  
  # MAMBA-specific processing...
}
```

## Validation Functions

Added validation functions to check compliance:

```r
validate_company_specific_etl_naming <- function(script_path) {
  filename <- basename(script_path)
  pattern <- "^([a-z]{3})_ETL_([a-z_]+)_(0IM|1ST|2TR)___([A-Z]{3,10})\\.R$"
  
  if (grepl(pattern, filename)) {
    matches <- regmatches(filename, regexec(pattern, filename))[[1]]
    return(list(
      platform = matches[2],
      datatype = matches[3],
      phase = matches[4],
      company = matches[5],
      type = "company_specific"
    ))
  }
  # ... additional validation
}
```

## Next Steps

1. **Immediate**: Rename existing MAMBA ETL scripts to include `___MAMBA` suffix
2. **Short-term**: Update derivation scripts to reference new table names
3. **Long-term**: Consider implementing parallel pipelines (generic + company-specific)

## Related Principles

- MP104: ETL Data Flow Separation Principle
- MP092: Platform ID Standard
- MP064: ETL-Derivation Separation Principle
- DM_R028: ETL Data Type Separation Rule
- DM_R022: Platform Numbering Convention Rule

## Notes

This addition maintains backward compatibility while providing clear forward path for company-specific implementations. The pattern can be extended to other areas beyond ETL if needed (e.g., company-specific derivations could use `D##_{description}___{company}.R`).