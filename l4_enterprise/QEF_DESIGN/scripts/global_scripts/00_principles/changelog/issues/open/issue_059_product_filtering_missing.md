---
issue: "ISSUE_059"
title: "無法篩選個別產品ID查看影響效果"
severity: "medium"
component: "precision_marketing_model"
app: "mamba"
created: "2025-09-08"
status: "open"
original_source: "曼巴儀表板問題_20250807"
---

## Problem
目前精準行銷還無法篩選個別產品id來看影響效果，需要像KM一樣，可以挑選特定ASIN看影響因素。

## Expected Behavior
- 可以篩選個別產品ID（如ASIN）
- 查看特定產品的影響因素
- 支援多產品比較
- 用於布置網頁行銷重點

## Actual Behavior
- 無法篩選個別產品
- 只能看整體影響
- 缺乏產品層級的分析

## Proposed Resolution
1. 新增產品ID篩選功能
2. 實作個別產品影響因素分析
3. 參考KM系統的篩選機制
4. 增加產品比較功能

## Priority
Medium - 功能增強需求

## Related Issues
- ISSUE_121 (merged into this issue on 2025-11-02)

## Merge History
- **2025-11-02**: Merged ISSUE_121 into ISSUE_109
  - Reason: Duplicate issue describing the same problem
  - Both issues request individual product (ASIN) filtering functionality similar to KM system
  - ISSUE_121 closed and moved to CLOSED/merged/

## Audit Report (2025-11-02)
**Audited By**: principle-product-manager

### Current Status:
✅ **positionTable** (品牌屬性評價) - Product filtering EXISTS
   - File: `positionTable/positionTable.R` line 174
   - Has `product_id` selectizeInput with multi-select capability

❌ **positionKFE** (關鍵因素分析) - Product filtering MISSING
   - File: `positionKFE/positionKFE.R`
   - FilterUI only has display options, no product selector
   - This is the component for "影響因素" (key factors) mentioned in the issue

❌ **microCustomer** (顧客分析) - Product filtering NOT APPLICABLE
   - This component is customer-focused, not product-focused

### Recommendation:
**Valid issue - KEEP OPEN**

The issue is legitimate. While positionTable has product filtering, the **positionKFE** component (which analyzes "影響因素" / key factors) lacks this feature.

**Suggested Implementation**:
1. Add product_id selectizeInput to `positionKFEFilterUI()`
2. Follow the pattern used in positionTable (lines 173-179)
3. Update server logic to filter analysis by selected products
4. Maintain multi-select capability for product comparison

**Estimated Effort**: 2-4 hours (medium complexity)
**Priority**: Keep as Medium - useful feature enhancement