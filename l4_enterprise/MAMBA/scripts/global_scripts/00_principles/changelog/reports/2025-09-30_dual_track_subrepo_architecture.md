# Changelog: MP122 - Dual-Track Subrepo Architecture Principle

## Date: 2025-09-30

## Author: Claude (Principle Revisor)

## Summary

Created MP122 to formally document and establish the dual-track subrepo architecture as a Meta-Principle. This principle formalizes the existing practice of separating `global_scripts` (framework layer) and `update_scripts` (application layer) as independent git subrepos.

## Changes Made

### New Files Created

1. **English Version**:
   - `/docs/en/part1_principles/CH00_fundamental_principles/02_structure_organization/MP122_dual_track_subrepo_architecture.qmd`

2. **Chinese Version**:
   - `/docs/zh/part1_principles/CH00_fundamental_principles/02_structure_organization/MP122_dual_track_subrepo_architecture.qmd`

### Files Modified

1. **Principle Index**:
   - `/docs/en/part1_principles/CH00_fundamental_principles/index.qmd`
   - Added MP122 to Structure & Organization section
   - Added MP122 to Navigation Guide

2. **Related Principles Updated**:
   - **MP093**: Added cross-reference to MP122
   - Added note about MP122 providing physical separation via subrepos

## Rationale

### Why MP122 Qualifies as a Meta-Principle

1. **System-Level Impact**: Affects the entire MAMBA system's code organization, dependency management, and version control strategy

2. **Universal Applicability**: The pattern of separating stable framework from volatile application code is applicable to any large software system

3. **Architectural Criticality**: Represents a fundamental architectural decision about how code is organized and managed

4. **Long-Term Stability**: Embodies a design philosophy that won't change frequently

### Key Innovations in MP122

1. **Git-Enforced Boundaries**: Unlike MP093's conceptual separation, MP122 uses git subrepos to physically enforce architectural boundaries

2. **Cross-Project Reusability**: The framework layer can be shared across multiple projects as a common subrepo

3. **Independent Evolution**: Each layer can evolve at its natural pace with independent versioning

4. **Team Scalability**: Different teams can own and manage different layers independently

## Relationship to Existing Principles

### Supporting Relationships

- **MP093 (Script Separation)**: Provides the conceptual separation that MP122 implements physically
- **MP044 (Functor-Module Correspondence)**: Organizes content within each track
- **MP097 (Principle-Implementation Separation)**: Principles in global_scripts, implementations in update_scripts

### Enhanced Capabilities

MP122 enhances the existing principle system by:
- Providing version-controlled boundaries between layers
- Enabling true cross-project code sharing
- Supporting independent deployment strategies
- Facilitating distributed team development

## Implementation Guidelines

### For New Projects

1. Initialize dual-track architecture from the start:
   ```bash
   git subrepo clone git@github.com:org/global_scripts.git scripts/global_scripts
   git subrepo clone git@github.com:org/update_scripts.git scripts/update_scripts
   ```

2. Follow the decision matrix for code placement (see MP122 Section 6)

### For Existing Projects

1. Analyze codebase for separation candidates
2. Extract reusable components to global_scripts
3. Convert directories to subrepos
4. Establish proper dependency flow

## Impact Assessment

### Benefits

1. **Separation of Concerns**: Clear boundary between framework and application
2. **Risk Isolation**: Application changes don't affect framework stability
3. **Team Productivity**: Different teams can work independently
4. **Code Reuse**: Framework improvements benefit all projects

### Considerations

1. **Learning Curve**: Developers need to understand git subrepo commands
2. **Initial Setup**: Requires thoughtful initial organization
3. **Dependency Management**: Must maintain unidirectional dependencies

## Next Steps

1. Update developer onboarding documentation to include MP122
2. Create migration scripts for existing projects
3. Establish CI/CD templates that respect the dual-track architecture
4. Document best practices for subrepo management

## Verification

To verify MP122 compliance:

```bash
# Check subrepo status
git subrepo status

# Verify no reverse dependencies
grep -r "source.*update_scripts" scripts/global_scripts/

# Confirm independent version control
cd scripts/global_scripts && git log --oneline -5
cd scripts/update_scripts && git log --oneline -5
```

---

*This changelog documents the establishment of MP122 as a foundational Meta-Principle for the MAMBA system architecture.*