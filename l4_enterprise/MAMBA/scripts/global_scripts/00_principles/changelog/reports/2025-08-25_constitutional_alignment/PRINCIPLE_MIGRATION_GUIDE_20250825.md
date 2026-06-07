# Principle Migration Guide - August 25, 2025

## Executive Summary

This guide provides a step-by-step plan for migrating the current principles system to align with the constitutional framework defined in MP000. The migration preserves all valuable content while properly classifying principles according to their true nature.

## Migration Phases

### Phase 1: Preparation (Week 1)
**Objective**: Set up infrastructure and backup current state

#### Tasks:
1. **Create Backup**
   ```bash
   # Create timestamped backup
   cp -r docs/en/part1_principles backup/principles_pre_migration_20250825
   ```

2. **Create New Structure**
   ```
   docs/en/
   ├── constitutional_law/          # True MPs only
   │   ├── CH00_foundations/
   │   │   ├── definitions/         # MP001, MP003, MP005, MP006, MP008
   │   │   ├── principles/         # MP017, MP018, MP047, MP060, MP082
   │   │   ├── architecture/       # MP000, MP002, MP016, MP044, MP046, MP052, MP056
   │   │   └── methodology/        # MP004, MP013, MP021, MP030
   ├── statutory_law/               # Principles (P)
   │   ├── CH01_development/
   │   ├── CH02_data_management/
   │   ├── CH03_ui_components/
   │   └── CH04_deployment/
   └── regulatory_law/              # Rules (R)
       ├── coding_standards/
       ├── naming_conventions/
       ├── documentation_requirements/
       └── tool_configurations/
   ```

3. **Create Migration Tracking**
   ```yaml
   # migration_tracker.yaml
   migrations:
     - from: MP011_sensible_defaults
       to: P011_sensible_defaults
       status: pending
       location: statutory_law/CH01_development/
   ```

---

### Phase 2: Reclassification (Week 2-3)
**Objective**: Move principles to their proper categories

#### Step 1: Migrate Constitutional MPs (Remain as MP)

**Action Items**:
1. Copy these MPs to `constitutional_law/CH00_foundations/`:
   - MP000, MP001, MP002, MP003, MP004, MP005, MP006, MP008
   - MP013, MP016, MP017, MP018, MP021, MP030, MP044, MP046
   - MP047, MP052, MP056, MP060, MP082

2. Update their frontmatter:
   ```yaml
   ---
   type: "constitutional-meta-principle"
   law: "Constitutional Law"
   constitutional_category: "definitions|principles|architecture|methodology"
   ---
   ```

#### Step 2: Reclassify to Principles (MP → P)

**Reclassification List** (34 items):

| Current | New ID | New Location | Category |
|---------|--------|--------------|----------|
| MP007 | P007 | statutory_law/CH01_development/ | Documentation Organization |
| MP009 | P009 | statutory_law/CH01_development/ | Discrepancy Handling |
| MP010 | P010 | statutory_law/CH02_data_management/ | Information Flow |
| MP011 | P011 | statutory_law/CH01_development/ | Sensible Defaults |
| MP012 | P012 | statutory_law/CH01_development/ | Company Centered Design |
| MP014 | P014 | statutory_law/CH01_development/ | Change Tracking |
| MP015 | P015 | statutory_law/CH01_development/ | Currency Principle |
| MP028 | P028 | statutory_law/CH01_development/ | Avoid Self Reference |
| MP029 | P029 | statutory_law/CH02_data_management/ | No Fake Data |
| MP031 | P031 | statutory_law/CH01_development/ | Initialization First |
| MP032 | P032 | statutory_law/CH01_development/ | Principle Guided Mods |
| MP033 | P033 | statutory_law/CH01_development/ | Deinitialization Final |
| MP038 | P038 | statutory_law/CH04_deployment/ | Incremental Release |
| MP039 | P039 | statutory_law/CH01_development/ | One Time at Start |
| MP040 | P040 | statutory_law/CH01_development/ | Deterministic Transforms |
| MP041 | P041 | statutory_law/CH03_ui_components/ | Config Driven UI |
| MP042 | P042 | statutory_law/CH01_development/ | Runnable First |
| MP045 | P045 | statutory_law/CH02_data_management/ | Auto Data Detection |
| MP048 | P048 | statutory_law/CH01_development/ | Universal Initialization |
| MP051 | P051 | statutory_law/CH01_development/ | Test Data Design |
| MP053 | P053 | statutory_law/CH01_development/ | Feedback Loop |
| MP054 | P054 | statutory_law/CH03_ui_components/ | UI Server Correspondence |
| MP055 | P055 | statutory_law/CH01_development/ | Computation Allocation |
| MP059 | P059 | statutory_law/CH03_ui_components/ | App Dynamics |
| MP061 | P061 | statutory_law/CH01_development/ | Root Cause Resolution |
| MP067 | P067 | statutory_law/CH03_ui_components/ | UI Separation |
| MP072 | P072 | statutory_law/CH03_ui_components/ | Cognitive Distinction |

**Update Process**:
1. Change file prefix from `MP` to `P`
2. Update frontmatter type to `"principle"`
3. Update law to `"Statutory Law"`
4. Move to appropriate chapter in `statutory_law/`

#### Step 3: Reclassify to Rules (MP → R)

**Reclassification List** (30 items):

| Current | New ID | New Location | Category |
|---------|--------|--------------|----------|
| MP019 | R119 | regulatory_law/coding_standards/ | Package Consistency |
| MP020 | R120 | regulatory_law/documentation_requirements/ | Language Versions |
| MP022 | R122 | regulatory_law/documentation_requirements/ | Pseudocode Conventions |
| MP023 | R123 | regulatory_law/tool_configurations/ | Language Preferences |
| MP034 | R134 | regulatory_law/coding_standards/ | All Category Treatment |
| MP035 | R135 | regulatory_law/coding_standards/ | Null Treatment |
| MP036 | R136 | regulatory_law/documentation_requirements/ | Concept Documents |
| MP037 | R137 | regulatory_law/coding_standards/ | Comment Only Temporary |
| MP043 | R143 | regulatory_law/documentation_requirements/ | Database Documentation |
| MP049 | R149 | regulatory_law/tool_configurations/ | Docker Deployment |
| MP050 | R150 | regulatory_law/coding_standards/ | Debug Code Tracing |
| MP057 | R157 | regulatory_law/documentation_requirements/ | Package Documentation |
| MP058 | R158 | regulatory_law/coding_standards/ | DB Table Creation |
| MP068 | R168 | regulatory_law/documentation_requirements/ | Language as Index |
| MP069 | R169 | regulatory_law/documentation_requirements/ | AI Friendly Formats |
| MP070-081 | R170-181 | regulatory_law/naming_conventions/ | Various Naming Rules |

---

### Phase 3: Content Revision (Week 3-4)
**Objective**: Reword constitutional MPs to use definitional language

#### Tasks:
1. **Apply Revision Proposals**
   - Implement rewording from PRINCIPLE_REVISION_PROPOSALS_20250825.md
   - Focus on existence verbs (IS, ARE, EXISTS)
   - Remove prescriptive language (should, must, shall)

2. **Update Cross-References**
   ```yaml
   # Before
   derives_from: ["MP011", "MP032"]
   
   # After  
   derives_from: ["P011", "P032"]
   ```

3. **Validate Consistency**
   - Check all cross-references are updated
   - Verify no broken links
   - Ensure numbering is sequential

---

### Phase 4: Special Content Migration (Week 4)
**Objective**: Handle domain-specific content

#### NSQL Language System
1. **Create Separate Specification**
   ```
   specifications/
   └── nsql/
       ├── README.md
       ├── core_language.md      # From MP024-027
       ├── extensions/
       │   ├── graph_theory.md   # From MP063
       │   ├── set_theory.md     # From MP064
       │   └── radical_trans.md  # From MP065
       └── examples/
   ```

2. **Update References**
   - Replace MP references with specification links
   - Add note in constitutional law about external specs

---

### Phase 5: Documentation Update (Week 5)
**Objective**: Update all supporting documentation

#### Tasks:
1. **Update INDEX.md**
   ```markdown
   # Principles System Index
   
   ## Constitutional Law (Meta-Principles)
   Foundation principles that define what the system IS...
   
   ## Statutory Law (Principles)  
   Implementation principles derived from constitutional law...
   
   ## Regulatory Law (Rules)
   Specific implementation rules and standards...
   ```

2. **Create Migration Log**
   ```markdown
   # Migration Log - August 2025
   
   ## Changes Made
   - MP011 → P011: Reclassified as principle (prescriptive)
   - MP070 → R170: Reclassified as rule (naming convention)
   ...
   ```

3. **Update README.md**
   - Explain new three-tier system
   - Provide navigation guide
   - Include constitutional criteria

---

### Phase 6: Validation (Week 5-6)
**Objective**: Ensure migration success

#### Validation Checklist:
- [ ] All 83 MPs accounted for in new structure
- [ ] No duplicate IDs
- [ ] All cross-references updated
- [ ] Navigation works correctly
- [ ] Search/indexing updated
- [ ] No broken links
- [ ] Version history preserved

#### Testing Script:
```r
# validate_migration.R
validate_principles <- function() {
  # Check all files exist
  # Verify cross-references
  # Validate frontmatter
  # Check for orphaned principles
}
```

---

## Implementation Timeline

| Week | Phase | Key Deliverables |
|------|-------|-----------------|
| 1 | Preparation | Backup complete, new structure created |
| 2-3 | Reclassification | All principles moved to proper categories |
| 3-4 | Content Revision | Constitutional MPs reworded |
| 4 | Special Migration | NSQL moved to specifications |
| 5 | Documentation | All docs updated, migration log complete |
| 5-6 | Validation | System fully tested and validated |

## Risk Mitigation

### Potential Risks and Mitigations:

1. **Risk**: Breaking existing code that references principles
   - **Mitigation**: Create redirect mapping from old to new IDs
   - **Implementation**: `redirects.yaml` with old→new mappings

2. **Risk**: Loss of version history
   - **Mitigation**: Preserve git history through moves not deletes
   - **Implementation**: Use `git mv` for all file moves

3. **Risk**: User confusion during transition
   - **Mitigation**: Maintain parallel structure for 30 days
   - **Implementation**: Symlinks from old to new locations

4. **Risk**: Incomplete migration
   - **Mitigation**: Automated validation scripts
   - **Implementation**: Daily validation runs during migration

## Success Criteria

The migration is successful when:

1. **Structure**: Three-tier hierarchy clearly established
2. **Classification**: All principles properly categorized
3. **Language**: Constitutional MPs use definitional language
4. **References**: All cross-references updated and working
5. **Documentation**: Complete migration documentation
6. **Validation**: All automated tests pass
7. **Usability**: System easier to navigate and understand

## Post-Migration Tasks

### Immediate (Week 7):
- Archive old structure
- Update training materials
- Notify all stakeholders
- Create quick reference guide

### Short-term (Month 2):
- Gather feedback on new structure
- Fine-tune classifications if needed
- Develop principle proposal templates
- Establish review process

### Long-term (Quarter 2):
- Regular audits to prevent drift
- Develop tooling for principle management
- Create principle dependency visualizations
- Establish principle governance board

## Rollback Plan

If critical issues arise:

1. **Restore from backup**
   ```bash
   mv docs/en/part1_principles docs/en/part1_principles_failed
   cp -r backup/principles_pre_migration_20250825 docs/en/part1_principles
   ```

2. **Document lessons learned**
3. **Revise migration plan**
4. **Retry with improvements**

## Conclusion

This migration plan transforms the principles system from an over-classified structure to a properly tiered constitutional framework. By following this guide, the system will achieve greater clarity, maintainability, and philosophical consistency while preserving all valuable content.

The key to success is careful execution of each phase, thorough validation, and clear communication throughout the process.