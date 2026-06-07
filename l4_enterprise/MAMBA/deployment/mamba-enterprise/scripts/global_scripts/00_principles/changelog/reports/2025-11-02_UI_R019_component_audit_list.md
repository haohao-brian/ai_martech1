# UI_R019 Component Audit List

**Date**: 2025-11-02
**Purpose**: Identify all components requiring UI_R019 compliance implementation
**Principle**: UI_R019 - AI Process Notification Rule
**Auditor**: Claude (Principle Revisor)

## Audit Methodology

This audit identifies components that:
1. Make OpenAI API calls
2. Perform long-running operations (> 2 seconds)
3. Use async processing with `later::later()`
4. Have filter change handlers that trigger AI regeneration
5. Perform multi-stage data processing

## Search Commands Used

```bash
# Find OpenAI API usage
grep -r "openai\|OPENAI_API_KEY\|gpt-4\|gpt-3.5" \
  scripts/global_scripts/10_rshinyapp_components/ \
  --include="*.R" -l

# Find later::later() usage (async processing)
grep -r "later::later\|later(" \
  scripts/global_scripts/10_rshinyapp_components/ \
  --include="*.R" -l

# Find long sleep/wait operations
grep -r "Sys.sleep.*[5-9]\|Sys.sleep.*[1-9][0-9]" \
  scripts/global_scripts/10_rshinyapp_components/ \
  --include="*.R" -l

# Find filter change handlers
grep -r "observeEvent.*filter" \
  scripts/global_scripts/10_rshinyapp_components/ \
  --include="*.R" -l
```

## Priority 1: Components with Known AI Processing

### 1. Market Segmentation Analysis

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/marketSegmentAnalysis/`

**Files to Audit**:
- `marketSegmentAnalysisServer.R`
- `marketSegmentAnalysisUI.R`

**Expected AI Operations**:
1. Cluster analysis (5-8 seconds)
2. AI cluster naming via OpenAI (8-12 seconds)
3. AI segment report generation (10-15 seconds)
4. Total duration: 23-35 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  data = "📊 正在提取資料...",
  cluster = "🎯 正在執行分群 (K=X)...",
  naming = "🏷️ 正在產生分群名稱...",
  report = "📝 正在產生AI報告...",
  complete = "✅ 分析完成！"
)
```

**Audit Checklist**:
- [ ] Filter change handlers notify users before regeneration
- [ ] Progressive notifications for each stage
- [ ] All notifications in Traditional Chinese (UI_R007)
- [ ] Appropriate emoji usage
- [ ] Error handling with notifications
- [ ] Notification ID management (remove + show pattern)

---

### 2. Competitive Analysis

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/competitiveAnalysis/`

**Files to Audit**:
- `competitiveAnalysisServer.R`
- `competitiveAnalysisUI.R`

**Expected AI Operations**:
1. Multi-brand data extraction (3-5 seconds)
2. Competitive positioning analysis (5-8 seconds)
3. AI strategic insights generation (10-15 seconds)
4. Total duration: 18-28 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  data = "📊 正在提取競爭品牌資料...",
  analysis = "🔍 正在執行競爭分析...",
  insights = "📝 正在產生AI策略洞察...",
  complete = "✅ 分析完成！"
)
```

**Audit Checklist**:
- [ ] Filter change handlers for brand selection
- [ ] Progressive notifications for multi-brand comparison
- [ ] Language compliance (Traditional Chinese)
- [ ] Proper error handling

---

### 3. Customer DNA

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/customerDNA/`

**Files to Audit**:
- `customerDNAServer.R`
- `customerDNAUI.R`

**Expected AI Operations**:
1. Customer segment data extraction (2-4 seconds)
2. AI persona generation (12-18 seconds)
3. Persona report creation (5-8 seconds)
4. Total duration: 19-30 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  data = "📊 正在提取顧客區隔資料...",
  persona = "🏷️ 正在產生AI角色...",
  report = "📝 正在產生角色報告...",
  complete = "✅ 完成！"
)
```

**Audit Checklist**:
- [ ] Segment selection change notifications
- [ ] AI persona generation progressive feedback
- [ ] Traditional Chinese notifications
- [ ] Error handling for failed persona generation

---

### 4. Product Positioning

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/productPositioning/`

**Files to Audit**:
- `productPositioningServer.R`
- `productPositioningUI.R`

**Expected AI Operations**:
1. Product attribute data extraction (2-3 seconds)
2. Positioning calculation (4-6 seconds)
3. AI positioning recommendations (8-12 seconds)
4. Total duration: 14-21 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  data = "📊 正在提取產品屬性資料...",
  calculation = "🔍 正在計算定位...",
  recommendations = "📝 正在產生AI建議...",
  complete = "✅ 分析完成！"
)
```

**Audit Checklist**:
- [ ] Product filter change notifications
- [ ] Positioning calculation progress
- [ ] AI recommendation generation feedback
- [ ] Language compliance

---

### 5. Trend Analysis

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/trendAnalysis/`

**Files to Audit**:
- `trendAnalysisServer.R`
- `trendAnalysisUI.R`

**Expected AI Operations**:
1. Time series data extraction (3-5 seconds)
2. Trend detection analysis (5-8 seconds)
3. AI trend interpretation (10-15 seconds)
4. Total duration: 18-28 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  data = "📊 正在提取時間序列資料...",
  detection = "🔍 正在偵測趨勢...",
  interpretation = "📝 正在產生AI趨勢詮釋...",
  complete = "✅ 分析完成！"
)
```

**Audit Checklist**:
- [ ] Date range change notifications
- [ ] Trend detection progress
- [ ] AI interpretation feedback
- [ ] ETA estimates for long time series

---

### 6. Brand Health

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/brandHealth/`

**Files to Audit**:
- `brandHealthServer.R`
- `brandHealthUI.R`

**Expected AI Operations**:
1. Health metrics calculation (4-6 seconds)
2. Health score analysis (3-5 seconds)
3. AI diagnostic report (10-15 seconds)
4. Total duration: 17-26 seconds

**Current Notification Status**: ❓ NEEDS AUDIT

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  metrics = "📊 正在計算健康度指標...",
  analysis = "🔍 正在分析健康度分數...",
  diagnosis = "📝 正在產生AI診斷報告...",
  complete = "✅ 分析完成！"
)
```

**Audit Checklist**:
- [ ] Metric selection change notifications
- [ ] Health calculation progress
- [ ] AI diagnosis generation feedback
- [ ] Error handling for calculation failures

---

## Priority 2: Components with Potential AI Usage

### 7. Insight Forge Module

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/insightForge/`

**Expected Operations**: AI-powered insight generation
**Audit Status**: ❓ NEEDS INVESTIGATION
**Notes**: Check if this module uses OpenAI API for insights

---

### 8. Strategy Recommendation Module

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/strategyRecommendation/`

**Expected Operations**: AI-driven strategy suggestions
**Audit Status**: ❓ NEEDS INVESTIGATION
**Notes**: Verify if strategy generation uses AI

---

### 9. Report Generation Module

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/reportGeneration/`

**Expected Operations**: Automated report creation
**Audit Status**: ❓ NEEDS INVESTIGATION
**Notes**: Check for AI-generated content in reports

---

## Priority 3: Components with Long Data Processing

### 10. Data Import/Upload Components

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/dataImport/`

**Expected Operations**: Large file uploads and processing
**Audit Status**: ❓ NEEDS AUDIT
**Notes**: File processing > 2 seconds requires notification

**Required Notifications**:
```r
STAGE_MESSAGES <- list(
  upload = "📤 正在上傳檔案...",
  validation = "🔍 正在驗證資料...",
  processing = "📊 正在處理資料...",
  complete = "✅ 上傳完成！"
)
```

---

### 11. Database Query Components

**Component Path**: `scripts/global_scripts/10_rshinyapp_components/databaseQuery/`

**Expected Operations**: Complex database queries
**Audit Status**: ❓ NEEDS AUDIT
**Notes**: Queries > 2 seconds need progress indication

---

## Automated Compliance Check

### Create Compliance Checker Script

```r
# File: scripts/global_scripts/00_principles/compliance_checkers/check_ui_r019.R

#' UI_R019 Compliance Checker
#'
#' Checks components for UI_R019 compliance
check_ui_r019_compliance <- function(component_path) {

  message("Checking UI_R019 compliance for: ", component_path)

  # Find all R files in component
  r_files <- list.files(component_path, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)

  results <- list()

  for (file in r_files) {
    file_content <- readLines(file, warn = FALSE)

    # Check 1: OpenAI usage
    has_openai <- any(grepl("openai|OPENAI_API_KEY|gpt-", file_content, ignore.case = TRUE))

    # Check 2: Notifications present
    has_notifications <- any(grepl("showNotification", file_content))

    # Check 3: Progressive notifications (remove + show pattern)
    has_progressive <- any(grepl("removeNotification", file_content)) && has_notifications

    # Check 4: Later/async usage
    has_async <- any(grepl("later::later|later\\(", file_content))

    # Check 5: Long sleep operations
    has_long_sleep <- any(grepl("Sys\\.sleep\\([5-9]|Sys\\.sleep\\([1-9][0-9]", file_content))

    # Check 6: Filter change handlers
    has_filter_handler <- any(grepl("observeEvent.*filter", file_content))

    # Compliance assessment
    needs_notifications <- has_openai || has_async || has_long_sleep

    compliant <- if (needs_notifications) {
      has_notifications && has_progressive
    } else {
      TRUE  # Not applicable
    }

    results[[basename(file)]] <- list(
      file = file,
      needs_notifications = needs_notifications,
      has_notifications = has_notifications,
      has_progressive = has_progressive,
      has_openai = has_openai,
      has_async = has_async,
      has_long_sleep = has_long_sleep,
      has_filter_handler = has_filter_handler,
      compliant = compliant
    )
  }

  # Summary
  total_files <- length(results)
  needs_notifications <- sum(sapply(results, function(x) x$needs_notifications))
  compliant <- sum(sapply(results, function(x) x$compliant))
  non_compliant <- needs_notifications - sum(sapply(results, function(x) x$compliant && x$needs_notifications))

  message("Summary:")
  message("  Total files: ", total_files)
  message("  Files needing notifications: ", needs_notifications)
  message("  Compliant files: ", compliant)
  message("  Non-compliant files: ", non_compliant)

  if (non_compliant > 0) {
    message("\nNon-compliant files:")
    for (result in results) {
      if (result$needs_notifications && !result$compliant) {
        message("  - ", basename(result$file))
        message("    Reasons:")
        if (result$has_openai) message("      - Uses OpenAI API")
        if (result$has_async) message("      - Uses async processing")
        if (result$has_long_sleep) message("      - Has long sleep operations")
        if (!result$has_notifications) message("      - Missing notifications")
        if (!result$has_progressive) message("      - Missing progressive notifications")
      }
    }
  }

  return(results)
}

# Run compliance check on all components
component_dirs <- list.dirs(
  "scripts/global_scripts/10_rshinyapp_components",
  recursive = FALSE,
  full.names = TRUE
)

for (component_dir in component_dirs) {
  cat("\n", strrep("=", 80), "\n")
  check_ui_r019_compliance(component_dir)
}
```

## Testing Plan

### Manual Testing Procedure

For each component marked as NEEDS AUDIT:

1. **Identify AI Operations**
   - List all OpenAI API calls
   - Note expected duration of each operation
   - Identify multi-stage processes

2. **Verify Current Notifications**
   - Trigger AI operations
   - Observe notification behavior
   - Time notification appearance and updates
   - Check language consistency

3. **Test Filter Changes**
   - Change filters that trigger AI regeneration
   - Verify regeneration notification appears
   - Confirm progressive updates during regeneration

4. **Test Error Handling**
   - Trigger error conditions (invalid API key, network failure)
   - Verify error notifications appear
   - Confirm progress notifications are removed

5. **Document Findings**
   - Record current notification status
   - List violations of UI_R019
   - Estimate implementation effort

### Automated Testing

```r
# Test template for each component
test_that("UI_R019: [Component] has progressive AI notifications", {

  testServer([ComponentServer], {

    # Trigger AI process
    session$setInputs(trigger_ai = TRUE)

    # Test 1: Initial notification
    expect_true(
      notification_exists("ai_progress"),
      "[Component] should show initial notification"
    )

    # Test 2: Language compliance
    expect_match(
      get_notification_text("ai_progress"),
      "正在.*\\.\\.\\.",  # Traditional Chinese pattern
      "[Component] notification should be in Traditional Chinese"
    )

    # Test 3: Stage progression
    Sys.sleep(2)
    current_text <- get_notification_text("ai_progress")
    Sys.sleep(5)
    next_text <- get_notification_text("ai_progress")

    expect_false(
      current_text == next_text,
      "[Component] notification should update to next stage"
    )

    # Test 4: Completion
    session$flushReact()
    Sys.sleep(10)
    expect_match(
      get_notification_text(),
      "完成|✅",
      "[Component] should show completion notification"
    )
  })
})
```

## Implementation Timeline

### Week 1 (2025-11-04 to 2025-11-08)
- [ ] Audit Priority 1 components (1-6)
- [ ] Implement Market Segmentation Analysis
- [ ] Implement Competitive Analysis

### Week 2 (2025-11-11 to 2025-11-15)
- [ ] Implement Customer DNA
- [ ] Implement Product Positioning
- [ ] Audit Priority 2 components (7-9)

### Week 3 (2025-11-18 to 2025-11-22)
- [ ] Implement Trend Analysis
- [ ] Implement Brand Health
- [ ] Implement any Priority 2 components needing compliance

### Week 4 (2025-11-25 to 2025-11-29)
- [ ] Audit Priority 3 components (10-11)
- [ ] Implement remaining non-compliant components
- [ ] Run automated compliance checker
- [ ] Final verification and documentation

## Success Criteria

### Component-Level Success
- [ ] All OpenAI API calls have notifications
- [ ] All operations > 2s have initial notifications
- [ ] All operations > 10s have progressive notifications
- [ ] All notifications in Traditional Chinese (UI_R007)
- [ ] Appropriate emoji usage for all notifications
- [ ] Error handling with proper notifications
- [ ] Notification ID management (no stacking)

### System-Level Success
- [ ] 100% of Priority 1 components compliant
- [ ] 95%+ of all AI components compliant
- [ ] No user complaints about "frozen system" during AI processing
- [ ] Positive user feedback on process transparency
- [ ] Improved perceived performance (40% reduction in perceived wait time)

## Appendix: Common Violations Found

### Violation 1: No Notifications
**Pattern**: Long AI operation with no user feedback
```r
# ❌ VIOLATION
result <- call_openai_api(prompt)  # Takes 15s, no notification
```

### Violation 2: Static Notification Only
**Pattern**: Single notification for multi-stage process
```r
# ❌ VIOLATION
showNotification("Processing...", duration = NULL)
# ... 30 seconds of processing ...
removeNotification()
```

### Violation 3: English in Chinese UI
**Pattern**: Language mixing (violates UI_R007)
```r
# ❌ VIOLATION (Chinese UI)
showNotification("Generating report...", duration = NULL)
```

### Violation 4: No Notification ID
**Pattern**: Cannot remove/replace notifications
```r
# ❌ VIOLATION
showNotification("Stage 1...", duration = NULL)  # No ID!
showNotification("Stage 2...", duration = NULL)  # Stacks on top
```

### Violation 5: Filter Changes Without Notification
**Pattern**: Silent regeneration after filter change
```r
# ❌ VIOLATION
observeEvent(input$filter, {
  # No notification that regeneration will occur
  regenerate_ai_analysis()
})
```

---

**Audit Report Created**: 2025-11-02
**Next Review**: After Week 1 implementation (2025-11-08)
**Responsible**: Development Team + Principle Revisor
**Priority**: HIGH - Critical for user experience
