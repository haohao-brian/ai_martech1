# MP123: AI Prompt Configuration Management

**Date Created**: 2025-10-06
**Author**: Claude
**Type**: Meta-Principle (MP)
**Category**: Data Management
**Status**: Active

## Summary

Created new meta-principle MP123: AI Prompt Configuration Management to establish standards for centralized AI prompt configuration loading and access patterns in the MAMBA framework.

## Problem Statement

The MAMBA dashboard uses OpenAI API for AI-generated insights. Previously, components were attempting to read AI prompt configurations directly from YAML files during runtime, which caused:

1. **File Path Resolution Errors**: Runtime file path resolution fails in deployment environments
2. **Performance Overhead**: Repeated YAML file parsing for each prompt access
3. **Principle Violations**:
   - MP045 (Universal Initialization) - configuration loaded repeatedly instead of once
   - MP031 (Separation of Concerns) - runtime logic mixed with file I/O
   - MP032 (DRY) - same YAML file read multiple times
4. **Error Propagation**: File reading errors occur deep in component logic rather than at initialization

## Solution

MP123 establishes that:

1. **Centralized Configuration**: All AI prompts defined in `list_openai_prompt.yaml`
2. **Initialization Loading**: Prompts loaded once at application startup into `app_configs$list_openai_prompt`
3. **Runtime Access**: Components access prompts from pre-loaded `app_configs`, never by re-reading files
4. **Validation**: Configuration validated at load time, not during runtime

## Key Patterns

### Initialization Pattern
```r
# Load during initialization (once)
load_ai_prompt_config <- function(config_path = NULL) {
  # Read YAML file
  prompt_config <- yaml::read_yaml(config_path)

  # Validate structure
  validate_prompt_config(prompt_config)

  # Store in app_configs
  app_configs$list_openai_prompt <- prompt_config
  assign("app_configs", app_configs, envir = .GlobalEnv)
}
```

### Runtime Access Pattern
```r
# CORRECT: Access pre-loaded configuration
get_ai_prompt <- function(category, prompt_name) {
  prompt_config <- app_configs$list_openai_prompt[[category]][[prompt_name]]
  return(prompt_config)
}

# INCORRECT: Re-reading YAML file
# DO NOT DO THIS!
load_openai_prompt <- function(prompt_path) {
  yaml::read_yaml(prompt_path)  # Violates MP123
}
```

## Files Created

1. **Principle Document**:
   - `docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP123_ai_prompt_configuration_management.qmd`

2. **Updated Documentation**:
   - `docs/en/part1_principles/CH00_fundamental_principles/index.qmd` - Added MP123 to Data Management section and navigation guide

3. **Changelog**:
   - `CHANGELOG/2025-10-06_mp123_ai_prompt_configuration.md` - This file

## Implementation Impact

### Components Affected
- All components using OpenAI API (e.g., position analysis, customer analysis)
- `fn_chat_api()` function - should accept `prompt_config` parameter
- Helper functions that previously read YAML files directly

### Migration Required
1. Update initialization scripts to call `load_ai_prompt_config()`
2. Update components to access `app_configs$list_openai_prompt` instead of reading files
3. Deprecate old `load_openai_prompt()` function that reads files
4. Update `fn_chat_api()` to accept `prompt_config` parameter

### Benefits
1. **Performance**: Zero file I/O overhead during runtime
2. **Reliability**: Configuration errors caught at startup, not during user interaction
3. **Testability**: Easy to mock prompt configurations
4. **Maintainability**: Single source of truth for all AI prompts
5. **Principle Compliance**: Follows MP045, MP031, MP032

## Related Principles

- **MP045: Universal Initialization** - Extends initialization pattern to AI prompts
- **MP031: Separation of Concerns** - Separates configuration from runtime logic
- **MP032: Don't Repeat Yourself** - Eliminates repeated file reading
- **MP065: Platform Configuration Management** - Parallel pattern for platform configs
- **R116: Enhanced Data Access** - Similar pre-loaded data access pattern

## Testing Considerations

Test configurations should mock `app_configs$list_openai_prompt`:

```r
setup_test_prompt_config <- function() {
  test_config <- list(
    test_category = list(
      test_prompt = list(
        system_role = "You are a test assistant",
        user_instruction = "Analyze: {data}",
        temperature = 0.5
      )
    )
  )

  app_configs$list_openai_prompt <- test_config
  assign("app_configs", app_configs, envir = .GlobalEnv)
}
```

## Deployment Notes

- Ensure `load_ai_prompt_config()` is called during application initialization
- Verify `list_openai_prompt.yaml` is accessible at the specified path
- Monitor initialization logs for configuration loading success/failure
- Document any prompt configuration changes in version control

## Future Enhancements

1. **Multi-language Support**: Extend to support prompts in multiple languages (en, zh_TW)
2. **Dynamic Templates**: Support template variables in prompt instructions
3. **Hot Reload**: Implement configuration refresh without restarting application
4. **Versioning**: Track prompt configuration versions for A/B testing
5. **Monitoring**: Log which prompts are used for analytics

## References

- Original Issue: MAMBA positioning analysis component throwing file path errors
- Related Discussion: Centralized configuration management patterns
- Implementation Guide: See MP123 document for complete implementation details

---

**Change Log**:
- 2025-10-06: Initial creation of MP123 and documentation
