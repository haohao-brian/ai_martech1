# CHANGELOG: R118 .env File Loading Pattern

**Date**: 2025-10-03
**Type**: New Principle
**Severity**: HIGH
**Status**: Active
**Related**: ISSUE-118

## Summary

Created new security rule R118 documenting the standardized .env file loading pattern across all MAMBA projects. This principle establishes a unified approach to loading environment variables with fallback mechanisms and mandatory verification.

## Changes Made

### 1. New Principle Files Created

**English Version**:
- Path: `docs/en/part1_principles/CH07_security/rules/R118_env_file_loading_pattern.qmd`
- Status: Created
- Language: English

**Chinese Version**:
- Path: `docs/zh/part1_principles/CH07_security/rules/R118_env_file_loading_pattern.qmd`
- Status: Created
- Language: 中文

### 2. Chapter Index Updated

**File**: `docs/en/part1_principles/CH07_security/index.qmd`
- Added R118 to "Critical Rules (Immediate Enforcement)" section
- Updated `date-modified` to 2025-10-03

### 3. Implementation Reference

**Function**: `global_scripts/04_utils/fn_load_env_file.R`
- Standardized utility function for loading .env files
- Implements dotenv-first with readRenviron fallback
- Includes verification of required variables

## Problem Addressed

### Before R118

Projects had inconsistent approaches to loading .env files:
- Direct `dotenv::load_dot_env()` calls without fallback
- No verification of critical environment variables
- Unclear .env file locations
- Silent failures during loading
- No standardized error handling

### After R118

All projects now use standardized pattern:
- **Utility function**: `load_env_file()` in `global_scripts/04_utils/`
- **Fallback mechanism**: Try dotenv first, fall back to readRenviron
- **Mandatory verification**: Check all required variables after loading
- **Consistent location**: .env files in project root directory
- **Clear messaging**: Informative success/warning messages
- **Security compliance**: .env in .gitignore

## Key Requirements Established

1. ✅ **Fallback Mechanism**: Must try dotenv first, fall back to readRenviron
2. ✅ **File Location**: .env must be in project root directory
3. ✅ **Variable Verification**: Must verify critical environment variables
4. ✅ **Clear Messages**: Must provide informative status messages
5. ✅ **Security**: .env must never be committed to version control

## Usage Pattern

```r
# Standard usage in all projects
source("global_scripts/04_utils/fn_load_env_file.R")
load_env_file(
  required_vars = c("OPENAI_API_KEY", "PGHOST", "PGPASSWORD")
)
```

## Related Principles

- **MP110**: Security Credentials Management (parent principle)
- **SEC_R001**: No Hardcoded Credentials
- **SEC_R002**: Environment Variable Standards
- **R092**: Universal DBI Approach
- **MP011**: Discrepancy Principle
- **MP020**: DRY (Don't Repeat Yourself)

## Integration Points

### Database Connections (R092)
R118 provides environment variables for R092's database connections:
```r
load_env_file(required_vars = c("PGHOST", "PGUSER", "PGPASSWORD"))
con <- dbConnect(RPostgres::Postgres(),
  host = Sys.getenv("PGHOST"), ...)
```

### Security Compliance (SEC_R001, SEC_R002)
R118 is the standard mechanism for loading credentials without hardcoding:
```r
load_env_file(required_vars = c("API_KEY"))
api_key <- Sys.getenv("API_KEY")  # Not hardcoded
```

### Code Reusability (MP020)
R118 promotes DRY by providing reusable function instead of repeated patterns:
```r
# Use function (DRY) instead of repeating pattern everywhere
load_env_file()
```

## Impact Assessment

### Affected Areas

1. **All Application Initializations**: Every app.R must adopt this pattern
2. **Database Connections**: All scripts using R092 must load .env via R118
3. **API Integrations**: All scripts accessing external APIs must use R118
4. **Test Scripts**: All test files must load test .env files via R118
5. **Background Jobs**: All scheduled tasks must use R118 for credentials

### Migration Required

**Existing Projects Must**:
1. Add `fn_load_env_file.R` sourcing to initialization
2. Replace direct dotenv/readRenviron calls with `load_env_file()`
3. Move .env to project root if in different location
4. Add .env to .gitignore if not present
5. Create .env.example template for repository

**Timeline**:
- Immediate: Update to use `load_env_file()` function
- 24 hours: Verify all required variables checked
- 1 week: Add comprehensive tests for .env loading

## Enforcement

**Enforcement Level**: REQUIRED (HIGH severity)

**Mechanisms**:
1. Code review - All PRs must use standardized pattern
2. CI/CD checks - Automated verification of .env handling
3. Security audits - Regular scans for non-compliant code
4. Principle compliance - Tracked in adherence metrics

**Non-compliance Consequences**:
1. PR rejection until compliant
2. Security team escalation if credentials exposed
3. Required remediation within specified timeline

## Documentation

### Files Modified/Created

1. ✅ `R118_env_file_loading_pattern.qmd` (EN) - Created
2. ✅ `R118_env_file_loading_pattern.qmd` (ZH) - Created
3. ✅ `CH07_security/index.qmd` (EN) - Updated
4. ✅ `CHANGELOG/2025-10-03_R118_env_file_loading_pattern.md` - Created

### Documentation Coverage

- [x] Principle statement and rationale
- [x] Problem solved (before/after)
- [x] Standard implementation
- [x] Usage patterns (4 common scenarios)
- [x] Key requirements (5 critical items)
- [x] File structure standards
- [x] Integration with other principles
- [x] Error handling guide
- [x] Testing patterns
- [x] Compliance checklist
- [x] Migration guide
- [x] Related documentation references

## Testing Requirements

### Unit Tests Required

```r
test_that("load_env_file works correctly", {
  # Test basic loading
  # Test fallback mechanism
  # Test variable verification
  # Test error handling
})
```

### Integration Tests Required

```r
test_that("initialization loads .env correctly", {
  # Test full initialization flow
  # Verify all required variables present
})
```

## Future Work

### Planned Enhancements

1. **Automated validation**: CI/CD checks for R118 compliance
2. **Migration toolkit**: Scripts to help migrate existing projects
3. **Template updates**: Update all app templates with R118 pattern
4. **Training materials**: Create developer training on R118

### Tracking

- **Next Review**: 2025-11-03
- **Version**: 1.0
- **Status**: Active

## References

- **Source Issue**: ISSUE-118
- **Implementation PR**: (To be added when PR created)
- **Discussion**: (To be added if applicable)

## Notes

This principle completes ISSUE-118's standardization effort by:
1. Creating function: `fn_load_env_file.R`
2. Documenting pattern: R118 principle
3. Establishing standard: All projects must use this pattern
4. Providing guidance: Migration and usage documentation

The principle integrates seamlessly with existing security principles (MP110, SEC_R001, SEC_R002) and development patterns (R092, MP011, MP020).

---

**Author**: Claude Code (principle-revisor)
**Created**: 2025-10-03
**Version**: 1.0
**Status**: ACTIVE
