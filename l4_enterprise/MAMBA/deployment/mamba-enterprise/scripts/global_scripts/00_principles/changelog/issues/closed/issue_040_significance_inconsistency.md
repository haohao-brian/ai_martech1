---
issue: "ISSUE_040"
title: "顯著性判斷不一致"
severity: "high"
component: "brand_positioning"
app: "mamba"
created: "2025-09-08"
status: "merged"
merged_to: "ISSUE_108"
merged_date: "2025-11-02"
merge_reason: "Root cause identical - both issues stem from lack of statistical transparency (missing std_error, CI, sample size display). ISSUE_108 Phase 2.1 solution addresses both problems."
resolution_approach: "Will be resolved through ISSUE_108 Phase 2.1 implementation"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
為什麼耐用性佳1.6倍顯著，但性能卓越也是1.6倍卻不顯著？

## Expected Behavior
- 相同倍數應有一致的顯著性判斷
- 清楚的顯著性標準
- 統計檢定結果透明

## Actual Behavior
- 相同的1.6倍有不同顯著性結果
- 顯著性判斷邏輯不明

## Proposed Resolution
1. 檢查顯著性檢定邏輯
2. 確保p-value計算正確
3. 統一顯著性判斷標準
4. 顯示信賴區間或p-value

## Priority
High - 統計邏輯問題

## Related Issues
- ISSUE_108, ISSUE_123

## Merge Decision (2025-11-02)

After investigation, this issue has been merged into ISSUE_108 for the following reasons:

### Root Cause Analysis
Both ISSUE_154 and ISSUE_108 share the same root cause: **lack of statistical transparency in UI**.

**ISSUE_154 specific problem**: Users confused why same effect size (1.6x) has different significance
**Actual reason**: Significance depends on p-value, which is affected by:
- Effect size (coefficient)
- Data stability (std_error) ← Missing in UI
- Sample size ← Missing in UI

**ISSUE_108 specific problem**: Coefficient interpretation unclear, extreme multipliers
**Actual reason**: Missing context information (std_error, CI, sample size)

### Why Merge Makes Sense
1. **Same solution**: ISSUE_108 Phase 2.1 already includes displaying std_error, CI, and sample size
2. **Avoid duplication**: Implementing separately would duplicate 80% of the work
3. **Better UX**: Single comprehensive solution is better than piecemeal fixes
4. **Resource efficiency**: Saves 3-5 days of development time

### Implementation Plan
ISSUE_108 Phase 2.1 will:
- Display standard error (std_error)
- Display confidence intervals (95% CI)
- Display sample size (N)
- Add interactive tooltips explaining significance judgment
- This automatically resolves ISSUE_154's confusion

### Related Files
- ISSUE_108: `/scripts/global_scripts/00_principles/ISSUE_TRACKER/ACTIVE/working/ISSUE_108_coefficient_interpretation.md`
- Implementation: `/scripts/global_scripts/10_rshinyapp_components/poisson/poissonFeatureAnalysis/poissonFeatureAnalysis.R`