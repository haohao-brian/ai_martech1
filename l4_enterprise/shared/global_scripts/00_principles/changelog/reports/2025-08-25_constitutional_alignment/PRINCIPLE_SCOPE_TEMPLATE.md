# Principle Scope Template

## Standard Principle Format

```markdown
# [PRINCIPLE_ID]_[PRINCIPLE_NAME]

## Metadata
- **Level**: [1|2|3] (Core|Standard|Guidance)
- **Context**: [all|development|production|debugging|prototype]
- **Scope**: [global|app|module|function]
- **Created**: YYYY-MM-DD
- **Last Modified**: YYYY-MM-DD
- **Review Date**: YYYY-MM-DD

## Principle Statement
[Clear, concise statement of the principle]

## Rationale
[Why this principle exists and what problem it solves]

## Scope and Boundaries

### Applies To:
- [Specific situations where this principle applies]
- [Types of code/files/modules covered]
- [Development phases where relevant]

### Does NOT Apply To:
- [Explicit exclusions]
- [Situations where principle should not be enforced]
- [Valid exceptions]

## Implementation

### Correct Example:
```r
# Code showing proper implementation
```

### Incorrect Example:
```r
# Code showing what to avoid
```

## Exceptions

### Allowed Exceptions:
1. **[Exception Name]**
   - Condition: [When exception applies]
   - Documentation: [How to document]
   - Expiration: [When to review/remove]

### Conflict Resolution:
- Conflicts with: [List of potentially conflicting principles]
- Resolution: [How to resolve each conflict]
- Priority: [Which takes precedence when]

## Dependencies
- Requires: [Principles that must be followed first]
- Enables: [Principles that this makes possible]
- Related: [Other relevant principles]

## Validation
- How to check: [Method to verify compliance]
- Tools: [Automated tools if available]
- Frequency: [How often to validate]

## Migration
- From: [What this replaces or updates]
- Path: [How to migrate existing code]
- Timeline: [Expected completion]
```

## Example Application

```markdown
# R021_function_organization_standards

## Metadata
- **Level**: 2 (Standard)
- **Context**: all
- **Scope**: module
- **Created**: 2024-01-15
- **Last Modified**: 2025-08-24
- **Review Date**: 2025-11-24

## Principle Statement
Each main function should be defined in its own dedicated file with matching name.

## Rationale
Improves code organization, makes functions easier to find, and simplifies testing.

## Scope and Boundaries

### Applies To:
- All main functions (>10 lines)
- Public API functions
- Functions exported from modules
- Shared utility functions

### Does NOT Apply To:
- Helper functions (<10 lines)
- Anonymous functions
- Inline function definitions
- Development/debugging phase

## Implementation

### Correct Example:
```r
# File: fn_calculate_metrics.R
calculate_metrics <- function(data) {
  # Main function implementation
}
```

### Incorrect Example:
```r
# File: utils.R
calculate_metrics <- function(data) { ... }
process_data <- function(data) { ... }
generate_report <- function(data) { ... }
```

## Exceptions

### Allowed Exceptions:
1. **Debug Efficiency (DEV_P005)**
   - Condition: Active debugging of interconnected functions
   - Documentation: Add comment `# DEBUG: Multiple functions for testing`
   - Expiration: End of debugging session

2. **Performance Critical**
   - Condition: Measured performance improvement >20%
   - Documentation: Include benchmark results in comments
   - Expiration: Quarterly review

3. **Tightly Coupled Helpers**
   - Condition: Helper functions <10 lines used only by main function
   - Documentation: Mark as `# HELPER: for function_name only`
   - Expiration: When helper grows >10 lines

### Conflict Resolution:
- Conflicts with: DEV_P005 (Debug Efficiency)
- Resolution: DEV_P005 wins during @context:debugging
- Priority: This principle applies in @context:production

## Dependencies
- Requires: R001_file_naming_convention
- Enables: R043_check_existing_functions
- Related: R067_functional_encapsulation

## Validation
- How to check: Script to verify one main function per file
- Tools: `validate_function_files.R`
- Frequency: Pre-commit hook

## Migration
- From: Multiple functions per file
- Path: Gradually split files during refactoring
- Timeline: As files are modified
```

## Benefits of Scope Boundaries

1. **Clear Application**: Developers know exactly when a principle applies
2. **Explicit Exceptions**: No guessing about valid exceptions
3. **Conflict Resolution**: Built-in guidance for contradictions
4. **Context Awareness**: Different rules for different situations
5. **Migration Path**: Clear steps to achieve compliance
6. **Validation Method**: Objective way to check compliance

## Implementation Priority

### Phase 1: High-Impact Principles
- Security-related principles
- Data access patterns
- Core architecture principles

### Phase 2: Development Standards
- Naming conventions
- Function organization
- Documentation requirements

### Phase 3: Style Guidelines
- Code formatting
- Comment standards
- Optional patterns

---

*Template Created: 2025-08-24*
*Use this template when updating existing principles or creating new ones*