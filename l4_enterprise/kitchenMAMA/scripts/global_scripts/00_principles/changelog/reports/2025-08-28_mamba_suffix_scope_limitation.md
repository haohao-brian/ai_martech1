# 2025-08-28: MAMBA Suffix Scope Limitation

## Change Summary

**CRITICAL FIX**: Corrected the scope of company suffix usage (e.g., `___MAMBA`) to apply ONLY to script filenames, NOT to data artifacts (tables, databases, files).

## Problem Identified

The existing principles incorrectly showed company suffixes being applied to both:
- ✅ Script names (correct usage): `eby_ETL_sales_0IM___MAMBA.R`
- ❌ Table names (incorrect usage): `df_eby_sales___raw___MAMBA`

This created several issues:
- **Data Incompatibility**: Different companies couldn't share data artifacts
- **Integration Problems**: Downstream systems expected standard table names
- **Maintenance Overhead**: Multiple table versions for the same data
- **Portability Issues**: Data artifacts tied to specific company frameworks

## Changes Made

### 1. Updated DM_R037 (Company-Specific ETL Naming Rule)

**Modified Sections:**
- Fixed table naming examples to remove company suffixes from data artifacts
- Updated compliance checklist to emphasize framework-agnostic data output
- Corrected implementation examples to show proper separation
- Enhanced conclusion to clarify script vs. data distinction

**Key Changes:**
```yaml
before:
  output_tables:
    raw: "df_eby_sales___raw___MAMBA"
    staged: "df_eby_sales___staged___MAMBA"
    transformed: "df_eby_sales___transformed___MAMBA"

after:
  output_tables:
    raw: "df_eby_sales___raw"
    staged: "df_eby_sales___staged"
    transformed: "df_eby_sales___transformed"
```

### 2. Created DM_R038 (Company Suffix Scope Limitation Rule)

**New Rule Establishes:**
- Clear boundaries for company suffix usage
- Comprehensive validation functions
- Migration strategy for existing violations
- Detailed examples of correct vs. incorrect usage

**Core Principle:**
- **Scripts**: Company-specific implementation logic (suffix allowed)
- **Data**: Framework-agnostic standardized content (suffix prohibited)

### 3. Verified DM_R028 (ETL Data Type Separation Rule)

**Status**: Already compliant - no changes needed
- Table naming examples were already framework-agnostic
- No company suffixes found in data artifact examples

## Implementation Impact

### Scripts (Company Suffix Allowed)
```bash
# Company-specific processing logic
eby_ETL_sales_0IM___MAMBA.R      # ✅ Contains MAMBA's connection logic
cbz_ETL_customers_1ST___ACME.R   # ✅ Contains ACME's business rules
amz_ETL_products_2TR___WIDGET.R  # ✅ Contains WIDGET's transformations
```

### Data Artifacts (Framework-Agnostic)
```bash
# Standardized data output (no company suffix)
df_eby_sales___raw               # ✅ Works for all companies
df_cbz_customers___staged        # ✅ Portable across frameworks
df_amz_products___transformed    # ✅ Standard schema
raw_data.duckdb                  # ✅ Framework-independent
sales_export.csv                 # ✅ Universal format
```

## Rationale

### Data Compatibility
- **Before**: `df_sales___raw___MAMBA` unusable by ACME systems
- **After**: `df_sales___raw` works for all company implementations

### System Integration
- **Before**: Hardcoded table names break when company suffixes change
- **After**: Standard table names ensure consistent integration

### Maintenance Efficiency
- **Before**: Multiple table versions (`___MAMBA`, `___ACME`, `___WIDGET`)
- **After**: Single standardized tables reduce maintenance overhead

### Cross-Company Portability
- **Before**: Data tied to specific company frameworks
- **After**: Framework-agnostic data enables sharing and collaboration

## Migration Requirements

### Immediate Actions Required

1. **Audit Existing Data Artifacts**:
   ```r
   # Use new validation function
   audit_company_suffix_compliance("/path/to/data/directory")
   ```

2. **Rename Violating Tables**:
   ```sql
   -- Example migrations needed
   ALTER TABLE df_eby_sales___raw___MAMBA RENAME TO df_eby_sales___raw;
   ALTER TABLE df_cbz_customers___staged___ACME RENAME TO df_cbz_customers___staged;
   ```

3. **Update Configuration Files**:
   ```yaml
   # Change from company-specific to framework-agnostic
   data_sources:
     ebay_sales:
       raw_table: "df_eby_sales___raw"  # Remove ___MAMBA suffix
   ```

4. **Validate All Scripts**:
   ```r
   # Ensure scripts comply with new rule
   validate_company_suffix_scope("eby_ETL_sales_0IM___MAMBA.R")  # Should pass
   validate_data_artifact_naming("df_eby_sales___raw")           # Should pass
   ```

### Testing Strategy

1. **Script Validation**: All company-specific ETL scripts should pass naming validation
2. **Data Compatibility**: Verify all applications can access standardized table names
3. **Integration Testing**: Confirm downstream systems work with framework-agnostic data
4. **Cross-Company Testing**: Validate data portability across different implementations

## Breaking Changes

### ⚠️ BREAKING CHANGES

1. **Table Names**: Any existing tables with company suffixes must be renamed
2. **Application Code**: Hardcoded references to company-suffixed tables must be updated  
3. **Configuration Files**: Company-specific table references must be changed to standard names
4. **Documentation**: Any references to company-suffixed data artifacts must be corrected

### Migration Support

- **Validation Tools**: DM_R038 provides comprehensive validation functions
- **Migration Scripts**: Automated tools to identify and fix violations
- **Rollback Plan**: Document current state before applying changes
- **Testing Framework**: Verify compatibility after migration

## Compliance Verification

### ✅ Compliance Checklist

- [ ] All ETL scripts use company suffixes only in filenames
- [ ] No database tables contain company suffixes
- [ ] No export files contain company suffixes
- [ ] Configuration files reference standard table names
- [ ] Applications use framework-agnostic data references
- [ ] Validation functions pass for all artifacts
- [ ] Migration plan addresses existing violations
- [ ] Documentation reflects corrected scope

## Conclusion

This critical fix establishes the correct boundary between company-specific implementation logic (scripts) and framework-agnostic data content (artifacts). The change ensures:

- **Immediate Impact**: Resolves existing data compatibility issues
- **Long-term Benefits**: Enables cross-company data sharing and system integration
- **Architectural Integrity**: Maintains separation between processing logic and data content
- **Scalability**: Supports multiple company implementations with shared data formats

The `___MAMBA` suffix now serves its intended purpose: identifying company-specific processing scripts while keeping all data output universally compatible.

---

**Change Classification**: Critical Bug Fix
**Affected Principles**: DM_R037, DM_R038 (new)  
**Migration Required**: Yes - Immediate action needed
**Testing Required**: Yes - Comprehensive validation needed
**Documentation Impact**: High - Multiple references corrected