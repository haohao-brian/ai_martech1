---
issue: "ISSUE_001"
title: "產品屬性重要性分析，改名：市場區隔與目標市場分析"
severity: "low"
component: "ui_ux"
app: "mamba"
created: "2025-11-02"
status: "merged"
merged_date: "2025-11-03"
merged_to: "ISSUE_164"
resolved_by: "ISSUE_114"
original_source: "20250722/曼巴儀表板問題_20250722.md"
original_number: "14"
---

## Problem
產品屬性重要性分析，改名：市場區隔與目標市場分析

**Note**: Title originally contained image HTML attributes `{width="5.768055555555556in" height="2.7159722222222222in"}` due to auto-extraction from screenshot/document.

## Expected Behavior
- Component name: "市場區隔與目標市場分析" (Market Segmentation and Target Market Analysis)
- Replaces: "產品屬性重要性分析" (Product Attribute Importance Analysis)

## Actual Behavior (at time of issue creation - 2025-07-22)
- Component name: "產品屬性重要性分析"
- Name did not accurately reflect MDS-based market segmentation functionality

## Merge Resolution

### Status: OBSOLETE - Already Resolved

**Investigation Date**: 2025-11-03

**Finding**: The requested change was successfully implemented in **ISSUE_114** (resolved 2025-09-22).

**Current System State** (verified 2025-11-03):
- ✅ Component renamed to "市場區隔與目標市場分析"
- ✅ Positioned correctly in 3rd place in menu
- ✅ All UI locations updated consistently:
  - Sidebar menu item (Line 288)
  - Card title (Line 319)
  - Notification message (Line 657)

**Resolution File**: `/scripts/global_scripts/10_rshinyapp_components/unions/union_production_test.R`

### Duplicate Cluster

This issue is part of a duplicate cluster identified during investigation:

- **ISSUE_150** (2025-07-22) ← This issue
- **ISSUE_164** (2025-08-02) ← Parent cluster issue
  - Merged from ISSUE_177
  - Merged from ISSUE_190
- **ISSUE_202** (2025-08-07) - Most detailed version
- **ISSUE_114** (2025-09-08) ← **Actual resolution issue** ✅

**Merge Action**: ISSUE_150 merged to ISSUE_164 as part of duplicate consolidation.

**Resolution Reference**: See ISSUE_114 for complete implementation details.

## Priority
Low - UI naming clarity

## Related Issues
- Merged to: ISSUE_164 (parent duplicate cluster)
- Resolved by: ISSUE_114 (actual implementation)
- Related: ISSUE_177, ISSUE_190, ISSUE_202 (other duplicates)

## Investigation Report
Full investigation details: `/ISSUE_TRACKER/INVESTIGATION_REPORTS/ISSUE_150_investigation.md`

## Notes
- This issue was automatically extracted from historical document (20250722)
- Issue was already resolved when it was extracted (Nov 2025)
- Actual resolution occurred September 2025 (ISSUE_114)
- Time gap: ~3-4 months between resolution and extraction
- Component name change was appropriate: original name misleading for MDS functionality
