# DEV_R036 Integration Report
**Date**: 2025-09-28
**Author**: Claude
**Rule Added**: DEV_R036 - ShinyJS Module Namespace Handling Rule

## Summary

Added DEV_R036 to address a specific gap in Shiny module namespace handling when using shinyjs functions. This rule prevents the common "could not find function 'ns'" error that occurs when developers incorrectly attempt to use `ns()` within `moduleServer` context.

## Integration with Existing Principles

### Primary Relationships

1. **UI_R002: Shiny Module ID Handling Rule**
   - UI_R002 covers general Shiny module namespacing
   - DEV_R036 extends this specifically for shinyjs functions
   - Both rules work together to ensure proper namespace handling across all module contexts

2. **DEV_R030: Explicit Namespace in Shiny Applications Rule**
   - DEV_R030 requires explicit package namespacing (e.g., `shinyjs::show()`)
   - DEV_R036 complements this by specifying how to namespace element IDs when using these functions
   - Together they ensure both function calls and element IDs are properly namespaced

3. **DEV_R022: Module Data Connection Rule**
   - DEV_R022 establishes module self-containment patterns
   - DEV_R036 supports this by ensuring UI manipulation within modules is properly scoped
   - Both contribute to creating truly independent, reusable modules

### Supporting Relationships

4. **MP017: Separation of Concerns**
   - DEV_R036 maintains clear separation between UI context (`ns()`) and server context (`session$ns()`)
   - Reinforces the principle that different contexts have different available resources

5. **MP058: Namespace Conflict Avoidance**
   - DEV_R036 directly prevents namespace conflicts in nested or multiple module instances
   - Ensures each module instance maintains its own isolated namespace

## Problem Solved

### Error Pattern Addressed
```r
# INCORRECT - Previously caused error
moduleServer(id, function(input, output, session) {
  observeEvent(input$button, {
    shinyjs::show(id = ns("panel"))  # ❌ Error: could not find function "ns"
  })
})
```

### Solution Provided
```r
# CORRECT - Using DEV_R036 guidance
moduleServer(id, function(input, output, session) {
  observeEvent(input$button, {
    shinyjs::show(id = session$ns("panel"))  # ✅ Works correctly
  })
})
```

## Key Contributions

1. **Error Prevention**: Eliminates a common source of runtime errors in Shiny modules
2. **Clear Guidance**: Provides explicit patterns for shinyjs integration with modules
3. **Comprehensive Examples**: Includes working code examples for all common shinyjs functions
4. **Debugging Support**: Offers debugging techniques for namespace-related issues

## Compatibility

- **No Breaking Changes**: DEV_R036 introduces no conflicts with existing principles
- **Enhances Existing Rules**: Complements and extends UI_R002 and DEV_R030
- **Framework Agnostic**: Works with both bs4Dash and bslib UI frameworks

## Implementation Checklist

When implementing modules with shinyjs, developers should now:

1. ✅ Review UI_R002 for general module namespace patterns
2. ✅ Review DEV_R030 for explicit package namespace requirements
3. ✅ Review DEV_R036 for shinyjs-specific namespace handling
4. ✅ Use `ns()` in UI functions
5. ✅ Use `session$ns()` in server functions with shinyjs
6. ✅ Never create `NS()` inside `moduleServer`

## Files Created

- `/docs/en/part1_principles/CH03_development_methodology/rules/DEV_R036_shinyjs_module_namespace.qmd`
- `/docs/zh/part1_principles/CH03_development_methodology/rules/DEV_R036_shinyjs_module_namespace.qmd`

## Conclusion

DEV_R036 successfully fills a gap in the existing principles system by providing specific guidance for shinyjs namespace handling in Shiny modules. It integrates seamlessly with existing principles while providing clear, actionable guidance to prevent common errors.

The rule strengthens the overall module system by ensuring that UI manipulation functions work correctly regardless of module nesting or multiple instantiation, supporting the broader goals of modularity and reusability in the MAMBA framework.