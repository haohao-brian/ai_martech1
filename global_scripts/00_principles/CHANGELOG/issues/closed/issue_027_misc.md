---
issue: "ISSUE_027"
title: "Issue Numbering Conflicts - Resolution Log"
severity: "medium"
component: "general"
app: "mamba"
created: "2025-01-01"
status: "closed"
---

# Issue Numbering Conflicts - Resolution Log

**Date**: 2025-10-03
**Resolution Method**: Renumbering with metadata tracking

---

## Summary

During the reorganization of the issues directory, we discovered that several "duplicate" issues were actually **different issues with the same number** (numbering conflicts). This document details how each conflict was identified and resolved.

---

## Conflict #1: ISSUE-118

### Issue Discovery

Found **3 files** claiming to be ISSUE-118:
1. `COMPLETED/ISSUE_118_env_file_loading_standardization.md`
2. `COMPLETED/ISSUE_118_env_loading_standardization.md`
3. `IN_PROGRESS/ISSUE_118_period_comparison_missing.md`

### Analysis

**Files 1 & 2**: Exact duplicates (same content, different filename length)
- Content: .env File Loading Standardization
- Status: Completed 2025-10-03
- **Decision**: Keep file #1 (longer, more descriptive name), delete file #2

**File 3**: DIFFERENT issue entirely
- Content: Period comparison feature for Marketing Vital Signs
- Status: In Progress
- Topic: Completely unrelated to .env loading
- **Decision**: This is a numbering conflict, needs renumbering

### Resolution

✅ **ISSUE-118 (Original - KEPT)**
- Title: .env File Loading Standardization
- Status: Completed 2025-10-03
- Location: `CLOSED/2025-10/ISSUE_118_env_file_loading_standardization.md`
- Action: Preserved as authoritative ISSUE-118

✅ **ISSUE-155 (Renumbered from ISSUE-118)**
- Title: 缺少上期相比功能 (Period Comparison Missing)
- Status: In Progress
- Location: `ACTIVE/working/ISSUE_155_period_comparison_missing.md`
- Metadata Added:
  ```yaml
  renamed_from: "ISSUE_118"
  renamed_date: "2025-10-03"
  renamed_reason: "Numbering conflict with env loading issue (ISSUE_118)"
  ```

---

## Conflict #2: ISSUE-119

### Issue Discovery

Found **2 files** claiming to be ISSUE-119:
1. `COMPLETED/ISSUE_119_posit_connect_variable_timing_fix.md`
2. `OPEN/ISSUE_119_ai_module_prompts.md`

### Analysis

**File 1**: Posit Connect Variable Order Dependency
- Content: Fix for variable loading timing in Posit Connect
- Status: Resolved 2025-10-03
- Created: 2025-10-03
- **Evidence**: Comprehensive technical analysis, resolution details

**File 2**: AI Module Prompts Integration
- Content: Four modules need AI prompts for report generation
- Status: Open
- Created: 2025-09-08
- **Evidence**: Implementation plan, feature request

**Conclusion**: Two completely different issues created at different times with same number

### Resolution

✅ **ISSUE-119 (Original - KEPT)**
- Title: Posit Connect Variable Order Dependency
- Status: Resolved 2025-10-03
- Location: `CLOSED/2025-10/ISSUE_119_posit_connect_variable_timing_fix.md`
- Rationale: Created later, has completion status, technical priority

✅ **ISSUE-156 (Renumbered from ISSUE-119)**
- Title: 四大模組AI報告Prompt整合 (AI Module Prompts)
- Status: Open
- Location: `ACTIVE/backlog/ISSUE_156_ai_module_prompts.md`
- Metadata Added:
  ```yaml
  renamed_from: "ISSUE_119"
  renamed_date: "2025-10-03"
  renamed_reason: "Numbering conflict with Posit Connect variable timing fix (ISSUE_119)"
  ```

---

## Conflict #3: ISSUE-137

### Issue Discovery

Found **2 files** claiming to be ISSUE-137:
1. `RESOLVED/ISSUE_137_strategy_plot_text_cutoff.md`
2. `OPEN/ISSUE_137_kpi_tracking_missing.md`

### Analysis

**File 1**: Strategy Plot Text Cutoff
- Content: UI bug - text cut off in four-quadrant plot
- Status: Resolved 2025-09-28
- Created: 2025-09-28
- **Evidence**: Complete resolution details, test results

**File 2**: KPI Tracking Missing
- Content: Feature request for trackable KPI system
- Status: Open
- Created: 2025-09-08
- **Evidence**: Still in planning, no implementation

**Conclusion**: Different issues, earlier issue still open while later one already resolved

### Resolution

✅ **ISSUE-137 (Original - KEPT)**
- Title: Strategy Plot Text Cutoff
- Status: Resolved 2025-09-28
- Location: `CLOSED/2025-09/ISSUE_137_strategy_plot_text_cutoff.md`
- Rationale: Has resolution status, technical implementation completed

✅ **ISSUE-157 (Renumbered from ISSUE-137)**
- Title: 建議增加可追蹤的KPI (KPI Tracking Missing)
- Status: Open
- Location: `ACTIVE/backlog/ISSUE_157_kpi_tracking_missing.md`
- Metadata Added:
  ```yaml
  renamed_from: "ISSUE_137"
  renamed_date: "2025-10-03"
  renamed_reason: "Numbering conflict with strategy plot text cutoff fix (ISSUE_137)"
  ```

---

## Root Cause Analysis

### Why Did This Happen?

1. **No Central Registry**: No single source of truth for issue numbers
2. **Manual Assignment**: Issue numbers assigned manually without checking
3. **Distributed Creation**: Issues created in different directories at different times
4. **No Validation**: No automated check for duplicate numbers

### How to Prevent Future Conflicts

1. ✅ **Next Issue Number Documented**: ISSUE-158 (clearly specified in REORGANIZATION_SUMMARY.md)
2. 📝 **Consider**: Create an issue number registry or automated assignment
3. 🔍 **Validation**: Add pre-commit hook to check for duplicate issue numbers
4. 📋 **Tracking**: Maintain issue number in centralized index

---

## Renumbering Decision Criteria

When deciding which issue to keep original number vs renumber:

### Keep Original Number If:
- ✅ Issue has **completion/resolution status** (higher priority)
- ✅ Issue was **created earlier** (chronological precedence)
- ✅ Issue has **more complete documentation** (authoritative)
- ✅ Issue is **referenced by other issues** (dependency)

### Renumber If:
- Issue is still **open/in progress** (more flexible)
- Issue was **created later** (likely the duplicate)
- Issue has **less documentation** (easier to update)
- Issue has **no external references** (no breaking changes)

---

## External References to Update

Any code, documentation, or references to the renumbered issues should be updated:

### ISSUE-118 → ISSUE-155
- Check for references in:
  - Related issues (ISSUE_120)
  - Implementation code
  - Documentation

### ISSUE-119 → ISSUE-156
- Check for references in:
  - Related issues (ISSUE_134, ISSUE_135, ISSUE_138, ISSUE_139)
  - AI module documentation

### ISSUE-137 → ISSUE-157
- Check for references in:
  - Related issues (ISSUE_120)
  - KPI documentation

---

## Verification

### Duplicate Check Results

```bash
# Check for duplicate issue numbers (should return nothing)
find issues -name "ISSUE_*.md" | sed 's/.*ISSUE_//' | sed 's/_.*//' | sort | uniq -d
# Result: (empty) ✅

# Verify renumbered issues exist
ls issues/ACTIVE/working/ISSUE_155_*.md    # ✅ exists
ls issues/ACTIVE/backlog/ISSUE_156_*.md    # ✅ exists
ls issues/ACTIVE/backlog/ISSUE_157_*.md    # ✅ exists

# Verify original issues preserved
ls issues/CLOSED/2025-10/ISSUE_118_*.md    # ✅ exists
ls issues/CLOSED/2025-10/ISSUE_119_*.md    # ✅ exists
ls issues/CLOSED/2025-09/ISSUE_137_*.md    # ✅ exists
```

All checks passed ✅

---

## Lessons Learned

1. **Semantic duplication** (RESOLVED vs COMPLETED) masked the real problem
2. **Directory structure** spread issues across locations, hiding conflicts
3. **Manual numbering** without central coordination causes conflicts
4. **Metadata is crucial** for tracking changes and maintaining history

---

## Future Improvements

1. **Automated Numbering**: Script to assign next available number
2. **Central Registry**: Single file tracking all issue numbers
3. **Validation Hooks**: Pre-commit checks for duplicates
4. **Issue Templates**: Standardize issue creation process

---

**Resolution Complete**: 2025-10-03
**Conflicts Resolved**: 3
**Issues Renumbered**: 3 (ISSUE-118→155, ISSUE-119→156, ISSUE-137→157)
**Data Loss**: None ✅
