# Platform ID to Code Migration

**Date**: 2025-08-27  
**Type**: Data Model Migration  
**Implements**: MP092 (Platform ID Standard), DM_R022 (Platform ID Convention), DM_R008 (Platform ID Reference Rule)  
**Author**: Claude  
**Status**: Required Migration  

## Overview

This change migrates all platform identifiers from numeric IDs (1, 2, 6, 7, etc.) to three-letter codes (amz, web, eby, cbz, etc.) as mandated by MP092. This standardization improves code readability, reduces errors, and aligns with industry best practices.

## Rationale

- **Problem**: Numeric platform IDs are cryptic and error-prone
- **Solution**: Three-letter mnemonic codes that are self-documenting
- **Benefits**: Improved readability, fewer errors, better maintainability
- **Requirement**: MP092 mandates this change for all platform references

## Platform Mapping

| Numeric ID | Three-Letter Code | Platform Name | Notes |
|------------|------------------|---------------|-------|
| 1 | amz | Amazon | Amazon marketplace |
| 2 | web | Official Website | Company website |
| 3 | ret | Retail Store | Physical stores |
| 4 | dst | Distributor | Distributor channels |
| 5 | soc | Social Media | Social platforms |
| 6 | eby | eBay | eBay marketplace |
| 7 | cbz | Cyberbiz | Cyberbiz platform |
| 9 | all | All Platforms | Multi-platform |

## Claude Code Instructions

### Phase 1: Assessment

Ask Claude Code to:

1. **Find numeric platform IDs in code**:
   ```
   "Please search for patterns that indicate numeric platform IDs:
   - platform_id == [number]
   - platform_id = '[number]'
   - WHEN [number] THEN (in SQL)
   - Numeric keys in YAML platform sections"
   ```

2. **Create comprehensive inventory**:
   ```
   "Create an inventory of all files using numeric platform IDs, 
   grouped by file type (.R, .sql, .yaml, etc.)"
   ```

3. **Identify edge cases**:
   ```
   "Look for any unusual platform ID usage patterns that might need special handling"
   ```

### Phase 2: Configuration Files

Have Claude Code:

1. **Update YAML configurations**:
   ```
   "In each app_config.yaml file:
   - Show me the current platforms section
   - Replace numeric keys (1, 6, 7) with codes (amz, eby, cbz)
   - Add description field for each platform
   - Verify the structure after each change"
   ```

   Example transformation:
   ```
   "Transform this:
   platforms:
     1: {name: 'Amazon', id: 1}
   
   To this:
   platforms:
     amz: {name: 'Amazon', description: 'Amazon marketplace', active: true}"
   ```

2. **Update environment configurations**:
   ```
   "Check .env files for any PLATFORM_ID variables and update to PLATFORM_ID"
   ```

### Phase 3: Database Schema

Guide Claude Code to:

1. **Add new column** (DO NOT run automated SQL):
   ```
   "Help me add platform_id column to these tables:
   - First show me the current schema for sales table
   - Create ALTER TABLE statement to add platform_id VARCHAR(3)
   - Let me review before executing
   - Repeat for customers and products tables"
   ```

2. **Populate new column**:
   ```
   "Help me populate platform_id based on platform_id_numeric:
   - Create UPDATE statement using CASE for mapping
   - Run for a small batch first (LIMIT 10)
   - Show me sample results
   - If correct, proceed with remaining records"
   ```

3. **Verify data integrity**:
   ```
   "Create and run a query to verify the mapping:
   SELECT platform_id, COUNT(*) 
   GROUP BY platform_id"
   ```

### Phase 4: Application Code

Request Claude Code to:

1. **Update R scripts**:
   ```
   "For each R file with legacy numeric platform_id references:
   - Show me the context around platform_id usage
   - Suggest the replacement with platform_id
   - Let me approve each change
   - Use Edit tool to make the change
   - Common patterns to update:
     * if (platform_id == 7) → if (platform_id == 'cbz')
     * filter(platform_id %in% c(1,6,7)) → filter(platform_id %in% c('amz','eby','cbz'))"
   ```

2. **Update UI components**:
   ```
   "Find all selectInput/selectizeInput using numeric platform values:
   - Show me current implementation
   - Update choices to use three-letter codes
   - Update server-side handling to expect strings not numbers"
   ```

3. **Update SQL queries**:
   ```
   "Find SQL queries referencing platform_id:
   - Update to use platform_id with proper quoting
   - Change from: WHERE platform_id = 1
   - Change to: WHERE platform_id = 'amz'"
   ```

### Phase 5: Testing and Validation

Have Claude Code:

1. **Create validation function**:
   ```
   "Create a validation function that:
   - Searches for remaining numeric platform patterns
   - Checks configuration files for numeric keys
   - Reports any files still using old pattern
   - But do NOT auto-fix anything found"
   ```

2. **Run comprehensive tests**:
   ```
   "Help me test the migration:
   - Run existing app tests
   - Check data filtering with new codes
   - Verify UI components work correctly
   - Test database queries"
   ```

3. **Performance verification**:
   ```
   "Compare query performance:
   - Run sample queries with platform_id
   - Check if indexes are needed
   - Verify no performance degradation"
   ```

### Phase 6: Cleanup

Guide Claude Code to:

1. **Remove old columns** (after verification period):
   ```
   "After system has run successfully for a week:
   - Help me rename platform_id_numeric to platform_id_numeric_backup
   - Do NOT drop the column yet
   - Keep backup for 30 days"
   ```

2. **Update documentation**:
   ```
   "Update all documentation:
   - Change references from platform_id_numeric to platform_id
   - Update data dictionaries
   - Update API documentation"
   ```

## Migration Helper Functions

Ask Claude Code to create these TEMPORARY helper functions:

```r
# Only for migration period - remove after completion
"Create a temporary helper function migrate_platform_id() that:
- Takes a numeric ID
- Returns the three-letter code
- Logs a warning for unknown IDs
- This is ONLY for the migration period"

"Create migrate_platform_column() for data frames:
- Adds platform_id column based on platform_id_numeric
- Optionally removes old column
- Shows summary of changes"
```

## Success Criteria

- [ ] No numeric platform IDs remain in code
- [ ] All platform references use three-letter codes  
- [ ] Configuration files updated to new format
- [ ] Database schema includes platform_id column
- [ ] All tests pass with new code system
- [ ] UI components use string codes
- [ ] No performance degradation observed
- [ ] Documentation fully updated

## Validation Checklist

Ask Claude Code to verify:

1. **Code search**:
   ```
   "Search for any remaining patterns:
   - platform_id (should find only backups)
   - Numeric comparisons with 1,2,6,7 in platform context"
   ```

2. **Configuration check**:
   ```
   "Verify all app_config.yaml files use letter codes in platforms section"
   ```

3. **Database verification**:
   ```
   "Run query to ensure platform_id is populated for all records with platform_id_numeric"
   ```

4. **Test execution**:
   ```
   "Run the app test suite and report any failures"
   ```

## Rollback Plan

If critical issues arise:

1. **Dual-column period**:
   ```
   "We maintain both platform_id and platform_id_numeric during transition
   Applications can check both if needed"
   ```

2. **Gradual migration**:
   ```
   "Migrate one application at a time rather than all at once"
   ```

3. **Quick revert**:
   ```
   "Since we keep platform_id_backup, we can rename it back if absolutely necessary"
   ```

## Timeline

| Week | Tasks | Validation |
|------|-------|------------|
| Week 1 | Assessment and inventory | All occurrences documented |
| Week 2 | Configuration files update | YAML files migrated |
| Week 3 | Database schema changes | New column populated |
| Week 4 | Application code migration | R scripts updated |
| Week 5 | Testing and validation | All tests passing |
| Week 6 | Documentation and cleanup | Migration complete |

## Important Notes

- **NO AUTOMATION**: Do not create migration scripts that run unsupervised
- **MANUAL REVIEW**: Every change must be reviewed before applying
- **INCREMENTAL**: Migrate one component at a time
- **VERIFICATION**: Test after each significant change
- **BACKUP**: Keep old columns/values during transition

## Related Documentation

- MP092: Platform ID Standard (the principle requiring this change)
- DM_R022: Platform ID Convention (naming rules)
- DM_R008: Platform ID Reference Rule (usage patterns)

---

*Remember: This migration must be done interactively through Claude Code with human oversight at each step. Never create automated scripts for bulk changes.*
