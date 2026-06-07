# UI_R019 Implementation Checklist

Quick reference for implementing UI_R019 notifications across components.

---

## Implementation Progress Tracker

### Week 1: Priority 1 (18 hours)

- [ ] **poissonFeatureAnalysis** (6 hours) ⚠️ PARTIAL → ✅ TARGET
  - [ ] Create PRECISION_MARKETING_STAGE_MESSAGES constant
  - [ ] Create PRODUCT_DEV_STAGE_MESSAGES constant
  - [ ] Replace withProgress with showNotification (precision marketing)
  - [ ] Replace withProgress with showNotification (product development)
  - [ ] Add error handling
  - [ ] Test with real AI calls

- [ ] **poissonCommentAnalysis** (4 hours) ⚠️ PARTIAL → ✅ TARGET
  - [ ] Create MARKET_TRACK_STAGE_MESSAGES constant
  - [ ] Replace withProgress with showNotification
  - [ ] Add error handling
  - [ ] Test with real AI calls

- [ ] **poissonTimeAnalysis** (4 hours) ⚠️ PARTIAL → ✅ TARGET
  - [ ] Create TIME_INSIGHTS_STAGE_MESSAGES constant
  - [ ] Replace withProgress with showNotification
  - [ ] Add error handling
  - [ ] Test with real AI calls

- [ ] **positionStrategy** (4 hours) ❌ NONE → ✅ TARGET
  - [ ] Create STRATEGY_STAGE_MESSAGES constant
  - [ ] Add initial notification on filter change
  - [ ] Add AI processing notification
  - [ ] Add completion notification
  - [ ] Add error handling
  - [ ] Test with real AI calls

### Week 2: Priority 2 (5 hours)

- [ ] **reportIntegration** (5 hours) ⚠️ PARTIAL → ✅ TARGET
  - [ ] Create REPORT_INTEGRATION_STAGE_MESSAGES (6 stages)
  - [ ] Replace withProgress with showNotification (stage 1: load vital signs)
  - [ ] Add notification for stage 2 (load customer DNA)
  - [ ] Add notification for stage 3 (load brand position)
  - [ ] Add notification for stage 4 (load market insights)
  - [ ] Add notification for stage 5 (AI integration)
  - [ ] Add completion notification
  - [ ] Add error handling
  - [ ] Test with real AI calls

### Week 3: Priority 3 (5 hours)

- [ ] **positionKFE** (2.5 hours) ❓ REVIEW
  - [ ] Code review to identify AI usage
  - [ ] If AI used: implement notification system
  - [ ] Test with real AI calls

- [ ] **positionDNAPlotly** (2.5 hours) ❓ REVIEW
  - [ ] Code review to identify AI usage
  - [ ] If AI used: implement notification system
  - [ ] Test with real AI calls

---

## Component Quick Status

| Component | Current | Target | Week | Hours | Status |
|-----------|---------|--------|------|-------|--------|
| positionMSPlotly | ✅ | ✅ | - | - | Reference |
| poissonFeatureAnalysis | ⚠️ | ✅ | 1 | 6 | Not Started |
| poissonCommentAnalysis | ⚠️ | ✅ | 1 | 4 | Not Started |
| poissonTimeAnalysis | ⚠️ | ✅ | 1 | 4 | Not Started |
| positionStrategy | ❌ | ✅ | 1 | 4 | Not Started |
| reportIntegration | ⚠️ | ✅ | 2 | 5 | Not Started |
| positionKFE | ❓ | ✅ | 3 | 2.5 | Not Started |
| positionDNAPlotly | ❓ | ✅ | 3 | 2.5 | Not Started |

**Total Estimated Time**: 28 hours across 3 weeks

---

## Standard Implementation Template

### Step 1: Create Stage Messages Constant

Add at top of component file (after helpers, around line 23):

```r
# UI_R019: AI Process Notification Rule - Stage Messages
{COMPONENT}_STAGE_MESSAGES <- list(
  stage1 = list(
    id = "{component}_stage1",
    ui = tagList(
      icon("filter"),  # or appropriate icon
      HTML("&nbsp;&nbsp;{Traditional Chinese message}...")
    )
  ),
  stage2 = list(
    id = "{component}_stage2",
    ui = tagList(
      icon("brain"),
      HTML("&nbsp;&nbsp;AI 正在{processing description}...")
    )
  ),
  stage3 = list(
    id = "{component}_stage3",
    ui = tagList(
      icon("check-circle"),
      HTML("&nbsp;&nbsp;{完成訊息}！")
    )
  ),
  error = list(
    id = "{component}_error",
    ui = tagList(
      icon("exclamation-triangle"),
      HTML("&nbsp;&nbsp;{錯誤訊息}")
    )
  )
)
```

### Step 2: Add Initial Notification

At start of observeEvent or reactive trigger:

```r
observeEvent(input$trigger_button, {
  # Validation checks...
  req(data)

  # UI_R019: Stage 1 - Initial notification
  showNotification(
    ui = {COMPONENT}_STAGE_MESSAGES$stage1$ui,
    id = {COMPONENT}_STAGE_MESSAGES$stage1$id,
    duration = NULL,
    closeButton = FALSE,
    type = "message"
  )

  # Data preparation...
})
```

### Step 3: Add AI Processing Notification

Before AI API call:

```r
# UI_R019: Stage 2 - AI processing
removeNotification({COMPONENT}_STAGE_MESSAGES$stage1$id)
showNotification(
  ui = {COMPONENT}_STAGE_MESSAGES$stage2$ui,
  id = {COMPONENT}_STAGE_MESSAGES$stage2$id,
  duration = NULL,
  closeButton = FALSE,
  type = "message"
)

# AI API call
txt <- chat_api(list(sys, usr), gpt_key, model = model)
```

### Step 4: Add Completion Notification

After AI response:

```r
# UI_R019: Stage 3 - Completion
removeNotification({COMPONENT}_STAGE_MESSAGES$stage2$id)
showNotification(
  ui = {COMPONENT}_STAGE_MESSAGES$stage3$ui,
  id = {COMPONENT}_STAGE_MESSAGES$stage3$id,
  duration = 3,  # Auto-dismiss after 3 seconds
  closeButton = TRUE,
  type = "message"
)

# Store result and update UI
result(txt)
```

### Step 5: Add Error Handling

In tryCatch error handler:

```r
tryCatch({
  # ... existing code
}, error = function(e) {
  # Remove all existing notifications
  removeNotification({COMPONENT}_STAGE_MESSAGES$stage1$id)
  removeNotification({COMPONENT}_STAGE_MESSAGES$stage2$id)

  # UI_R019: Error notification
  showNotification(
    ui = {COMPONENT}_STAGE_MESSAGES$error$ui,
    id = {COMPONENT}_STAGE_MESSAGES$error$id,
    duration = NULL,  # Stays until dismissed
    closeButton = TRUE,
    type = "error"
  )

  warning("Component error: ", e$message)
})
```

---

## Testing Checklist

For each component after implementation:

### Functional Testing
- [ ] Notification appears within 0.5s of trigger
- [ ] Stage progression is smooth (no flickering)
- [ ] Previous stages are removed before showing next
- [ ] Completion notification auto-dismisses after 3s
- [ ] Error notification stays until manually dismissed

### Content Quality
- [ ] All messages in Traditional Chinese
- [ ] No English text except technical terms
- [ ] Emojis are professional and appropriate
- [ ] Grammar is correct
- [ ] Messages are concise and clear

### Technical Testing
- [ ] No notification ID conflicts
- [ ] Works correctly on filter change
- [ ] Works correctly with multiple rapid clicks (no duplicate notifications)
- [ ] API errors handled gracefully
- [ ] API timeout handled gracefully
- [ ] Invalid data handled gracefully

### Performance Testing
- [ ] Notification overhead < 50ms
- [ ] No memory leaks from unreleased notifications
- [ ] Works with concurrent users
- [ ] No interference with other components

---

## Icon Reference Guide

Common icons for different stages:

| Stage Type | Icon | Example Usage |
|------------|------|---------------|
| Data preparation | `filter`, `database` | "正在篩選資料..." |
| AI processing | `brain`, `magic` | "AI 正在分析..." |
| Loading | `spinner`, `sync` | "正在載入..." |
| Completion | `check-circle`, `check` | "分析完成！" |
| Error | `exclamation-triangle`, `times-circle` | "發生錯誤" |
| Chart/Visualization | `chart-line`, `chart-bar` | "準備圖表資料..." |
| User | `users`, `user` | "載入顧客資料..." |
| Insights | `lightbulb`, `eye` | "生成洞察..." |

---

## Common Patterns

### Pattern 1: Simple AI Process (2-3 stages)

**Example**: Single AI analysis triggered by button

```
Stage 1: Prepare data → Stage 2: AI processing → Stage 3: Complete
```

**Time**: < 20 seconds

**Components**: poissonCommentAnalysis, poissonTimeAnalysis

### Pattern 2: Complex AI Process (3-4 stages)

**Example**: Data filtering + AI analysis + visualization

```
Stage 1: Filter data → Stage 2: Prepare analysis → Stage 3: AI call → Stage 4: Complete
```

**Time**: 20-40 seconds

**Components**: poissonFeatureAnalysis (2 processes), positionStrategy

### Pattern 3: Multi-Stage Integration (5+ stages)

**Example**: Multiple data sources + AI integration

```
Stage 1: Load source 1 → Stage 2: Load source 2 → Stage 3: Load source 3 →
Stage 4: Load source 4 → Stage 5: AI integration → Stage 6: Complete
```

**Time**: 30-60 seconds

**Components**: reportIntegration

---

## Daily Implementation Log Template

Copy this for each day of implementation:

```markdown
## Date: YYYY-MM-DD

### Components Worked On
- [ ] Component name (X hours)

### Completed Tasks
- Task 1
- Task 2

### Issues Encountered
- Issue 1: Description and resolution
- Issue 2: Description and resolution

### Time Variance
- Estimated: X hours
- Actual: Y hours
- Variance: ±Z hours
- Reason: ...

### Notes for Tomorrow
- ...
```

---

## Code Review Checklist

Before marking component as complete:

### Code Quality
- [ ] Follows positionMSPlotly reference pattern
- [ ] Stage messages constant at top of file
- [ ] Consistent naming convention used
- [ ] No hardcoded strings (all in stage messages)
- [ ] Proper indentation and formatting
- [ ] Comments reference UI_R019

### Compliance
- [ ] Meets all UI_R019 requirements
- [ ] Traditional Chinese throughout
- [ ] Appropriate emoji usage
- [ ] Proper notification IDs
- [ ] Proper notification removal
- [ ] Error handling implemented

### Documentation
- [ ] Code comments added
- [ ] Component docs updated
- [ ] Implementation notes recorded
- [ ] Testing results documented

---

## Completion Criteria

Component is considered **DONE** when:

1. ✅ All stage messages implemented
2. ✅ All notifications in Traditional Chinese
3. ✅ Appropriate emojis used
4. ✅ Tested with real AI calls
5. ✅ Error handling works correctly
6. ✅ No notification conflicts
7. ✅ Performance acceptable (< 50ms overhead)
8. ✅ Code review passed
9. ✅ Documentation updated
10. ✅ Checked into version control

---

## Final Audit

After all components complete:

### Component Coverage
- [ ] 8/8 components compliant with UI_R019
- [ ] All AI processes have notifications
- [ ] No English-only notifications remaining

### Quality Metrics
- [ ] All notifications appear within 0.5s
- [ ] All Traditional Chinese is grammatically correct
- [ ] All emojis are professional
- [ ] All error cases handled

### Documentation
- [ ] UI_R019 principle updated with examples
- [ ] Component inventory updated
- [ ] Implementation guide created
- [ ] Lessons learned documented

### User Experience
- [ ] User testing completed
- [ ] Feedback collected and addressed
- [ ] Support ticket reduction verified

---

**Document Version**: 1.0
**Last Updated**: 2025-11-02
**Owner**: Principle Product Manager
