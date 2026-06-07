# Principle Conflict Resolution Guide

## Priority Hierarchy

### Level 1: Core Principles (Never Violate)
1. **Security** - Never expose API keys or credentials
2. **Data Integrity** - Maintain data consistency and accuracy
3. **System Stability** - Ensure system remains operational

### Level 2: Standard Principles (Default Follow)
1. **DRY (Don't Repeat Yourself)** - Avoid code duplication
2. **Separation of Concerns** - Keep different aspects separate
3. **One Function One File** - Organize code clearly

### Level 3: Guidance Principles (Recommended)
1. **Documentation Standards** - Keep docs updated
2. **Naming Conventions** - Use consistent naming
3. **Code Style** - Follow style guides

## Conflict Resolution Matrix

| Conflicting Principles | Resolution | Context |
|------------------------|------------|---------|
| R021 (One Function/File) vs DEV_P005 (Debug Efficiency) | DEV_P005 wins during debugging | @context: debugging |
| MP018 (DRY) vs DEV_R016 (Evolution) | Evolution wins for production stability | @context: production |
| MP037 (Comment Restrictions) vs P010 (Documentation) | P010 wins - document complex logic | @context: all |
| MP017 (Separation) vs Performance | Performance wins if measured improvement >20% | @context: production |

## Context-Based Application

### Development Context
- Flexibility allowed for rapid iteration
- Debug efficiency takes precedence
- Documentation can be deferred (but tracked)

### Production Context
- Strict adherence to security principles
- Performance optimization allowed
- Evolution over replacement for stability

### Prototype Context
- Maximum flexibility
- Minimal documentation requirements
- Focus on functionality over form

## Exception Handling Rules

1. **Document All Exceptions**
   - When violating a principle, add comment: `# EXCEPTION: [principle] - [reason]`
   
2. **Temporary Exceptions**
   - Mark with: `# TODO: Restore [principle] after [condition]`
   - Set expiration date or condition

3. **Performance Exceptions**
   - Require benchmark proof
   - Document performance gain
   - Review quarterly

## Practical Guidelines

### When Principles Conflict:

1. **Check Priority Level**
   - Higher level always wins
   - Same level: check context

2. **Consider Impact**
   - Security impact → Level 1 wins
   - Performance impact → Measure and decide
   - Maintainability → Balance with urgency

3. **Document Decision**
   ```r
   # PRINCIPLE_OVERRIDE: Using DEV_P005 over R021
   # REASON: Debugging interconnected functions
   # EXPIRES: 2025-08-01 or when bug fixed
   ```

### Common Resolutions:

**DRY vs Evolution:**
- Keep both versions during transition
- Mark old version with deprecation date
- Remove after stability confirmed

**Comments vs Documentation:**
- Complex logic always gets comments
- Temporary code gets TODO comments
- Uncertain code gets WARNING comments

**Separation vs Efficiency:**
- Measure performance difference
- If <20% improvement: maintain separation
- If >20% improvement: combine with documentation

## Review Schedule

- **Quarterly**: Review all active exceptions
- **Monthly**: Check expired TODO items
- **Weekly**: Validate context switches

## Migration Path

For existing code violating resolved conflicts:

1. **Phase 1**: Document current violations
2. **Phase 2**: Prioritize by impact
3. **Phase 3**: Gradual migration
4. **Phase 4**: Validate compliance

---

*Last Updated: 2025-08-24*
*Next Review: 2025-09-24*