# Platform API Architecture Migration

**Date**: 2025-08-27  
**Type**: Architecture Migration  
**Implements**: MP094 (Platform API Architecture), MP092 (Platform ID Standard), MP065 (Platform Configuration Management)  
**Author**: Claude  
**Status**: Active Implementation  

## Overview

This change migrates existing platform API code from archive directories to the standardized `26_platform_apis` structure defined in MP094. All platform-specific API implementations must follow the new architecture for consistency, maintainability, and proper integration across data sources.

## Rationale

- **Problem**: Platform APIs scattered across archive directories with inconsistent patterns
- **Solution**: Centralized `26_platform_apis` structure with standardized patterns
- **Benefits**: Improved maintainability, consistent authentication, rate limiting, and configuration management
- **Principles**: Implements MP094 for API architecture and MP092 for platform_ids

## Claude Code Instructions

### Phase 1: Assessment and Planning

Ask Claude Code to:

1. **Identify existing API code**:
   ```
   "Please search for all API-related files in the archive directory. 
   Look for patterns like *api*, *query*, *connect* in archive/ and update_scripts/"
   ```

2. **Create inventory**:
   ```
   "Create an inventory of existing API implementations, documenting:
   - File locations
   - Authentication methods
   - Data formats used
   - Platform associations"
   ```

3. **Document findings**:
   ```
   "Please create a summary of all platform APIs found, grouped by platform_id (cbz, eby, amz, etc.)"
   ```

### Phase 2: Create Platform Structure

Have Claude Code:

1. **Create API configuration templates**:
   ```
   "For each platform (cbz, eby, amz), create an api_config.yaml file in 
   26_platform_apis/[platform_id]/ with:
   - Platform metadata (code, name, version)
   - API endpoints configuration
   - Authentication settings
   - Rate limiting parameters
   - Data mapping rules"
   ```

2. **Create common utilities**:
   ```
   "In 26_platform_apis/common/, create:
   - fn_api_rate_limiter.R for rate limiting
   - fn_api_auth.R for authentication
   - fn_api_error_handler.R for error handling"
   ```

3. **Review each configuration**:
   ```
   "Show me the api_config.yaml for [platform] before saving"
   ```

### Phase 3: Migrate Platform APIs

Guide Claude Code to:

1. **Refactor Cyberbiz API**:
   ```
   "Transform the existing Cyberbiz API code to follow the new pattern:
   - Create fn_cbz_connect.R with standardized connection
   - Create fn_cbz_get_customers.R for customer retrieval
   - Create fn_cbz_get_orders.R for order retrieval
   - Use configuration from api_config.yaml
   - Implement rate limiting
   - Add proper error handling"
   ```

2. **Refactor eBay API**:
   ```
   "Similarly transform eBay API following the same pattern as Cyberbiz"
   ```

3. **Update ETL scripts**:
   ```
   "Update ETL scripts (cbz_ETL01_0IM.R, eby_ETL01_0IM.R) to:
   - Source from 26_platform_apis/ instead of archive/
   - Use the new standardized functions
   - Remove any hardcoded credentials
   - Use environment variables for authentication"
   ```

### Phase 4: Testing and Validation

Request Claude Code to:

1. **Create test files**:
   ```
   "Create test files in 26_platform_apis/[platform]/tests/ to verify:
   - Connection establishment
   - Authentication handling
   - Rate limiting behavior
   - Data retrieval functions"
   ```

2. **Run validation**:
   ```
   "Please create and run a validation script that checks:
   - All required files exist for each platform
   - Configuration files are valid YAML
   - Platform IDs match directory names
   - No hardcoded credentials remain"
   ```

3. **Test with sample data**:
   ```
   "Test each API connection with a small request to verify functionality"
   ```

### Phase 5: Documentation and Cleanup

Have Claude Code:

1. **Update API registry**:
   ```
   "Create/update 26_platform_apis/api_registry.yaml with:
   - List of all platforms
   - Migration status for each
   - Available functions
   - Test coverage percentage
   - Maintainer information"
   ```

2. **Archive old code**:
   ```
   "Move old API code from update_scripts/archive/MAMBA/ to 
   scripts/99_archive/api_migration_[timestamp]/ with a MIGRATION_RECORD.md 
   documenting what was moved and changed"
   ```

3. **Update documentation**:
   ```
   "Update any references to old API locations in documentation or comments"
   ```

## Success Criteria

- [ ] All platform APIs follow MP094 architecture
- [ ] No hardcoded credentials in code  
- [ ] Rate limiting implemented for all APIs
- [ ] Configuration-driven approach for all platforms
- [ ] Test coverage > 80% for API functions
- [ ] All ETL scripts updated to use new structure
- [ ] Documentation complete and accessible
- [ ] Old code properly archived
- [ ] Performance metrics maintained or improved

## Validation Steps

Ask Claude Code to verify:

1. Directory structure matches specification:
   ```
   "Verify 26_platform_apis/ structure matches MP094 requirements"
   ```

2. No remaining old references:
   ```
   "Search for any remaining references to archive/MAMBA/*api paths"
   ```

3. Configuration completeness:
   ```
   "Check that each platform has complete api_config.yaml"
   ```

4. Function standardization:
   ```
   "Verify all platform APIs follow fn_[platform]_[action] naming"
   ```

## Rollback Plan

If issues arise:

1. **Immediate rollback**:
   ```
   "The old code is preserved in scripts/99_archive/api_migration_[timestamp]/
   If needed, we can reference it but should not restore it directly"
   ```

2. **Partial rollback**:
   ```
   "We can run both old and new APIs in parallel temporarily by:
   - Keeping archive code accessible
   - Using feature flags in ETL scripts
   - Gradually migrating one platform at a time"
   ```

3. **Fix forward**:
   ```
   "Preferred approach: fix issues in new structure rather than reverting"
   ```

## Timeline

| Week | Phase | Claude Code Actions | Validation |
|------|-------|-------------------|------------|
| Week 1 | Assessment | Search and inventory APIs | Inventory complete |
| Week 2 | Structure | Create directories and configs | Structure validated |
| Week 3 | Migration | Transform API code | API tests passing |
| Week 4 | Testing | Run integration tests | All tests green |
| Week 5 | Documentation | Update references | Documentation complete |
| Week 6 | Deployment | Monitor production | System stable |

## Related Changes

- **MP092**: Platform IDs (amz, cbz, eby) replace numeric IDs
- **MP065**: Platform configuration management via YAML
- **DM_R022**: Platform numbering convention

## Notes

- This migration must be done interactively through Claude Code
- Each step requires human review before proceeding
- No automated scripts should be created or run
- Focus on one platform at a time for safer migration
- Maintain backward compatibility during transition period