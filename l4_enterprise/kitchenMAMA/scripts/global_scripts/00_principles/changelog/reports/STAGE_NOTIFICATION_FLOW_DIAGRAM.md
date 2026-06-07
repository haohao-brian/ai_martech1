# Stage Notification Flow Diagram

## Complete Flow with AI Naming

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER ACTION                                     │
│                    Changes Filter (platform/product)                    │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         STAGE 1: DATA                                   │
│  observeEvent(platform_id(), product_line_id())                        │
│  Lines: 1511-1532                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  • ms_ai_analysis_result("")          ← Clear previous report          │
│  • ms_analysis_generated(FALSE)       ← Reset generation flag          │
│  • showNotification(STAGE_MESSAGES$data)  ← Show Stage 1               │
│    - "📊 正在提取資料..."                                                │
│    - id: "ms_analysis_progress"                                         │
│    - duration: NULL (persist)                                           │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼ (2 seconds - data extraction)
┌─────────────────────────────────────────────────────────────────────────┐
│                    STAGE 2: CLUSTER ANALYSIS                            │
│  csa_result() reactive                                                  │
│  Lines: 807-872                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  • perform_csa_analysis()             ← MDS clustering                  │
│  • component_status("ready")          ← Mark as ready                   │
│  • Check: if (!is.null(gpt_key) && exists("ai_naming_task"))           │
│    TRUE:                                                                │
│      • removeNotification("ms_analysis_progress")  ← Clear Stage 1      │
│      • showNotification(STAGE_MESSAGES$naming)     ← Show Stage 3       │
│        - "🏷️ 正在產生分群名稱..."                                        │
│    FALSE (no AI):                                                       │
│      • removeNotification("ms_analysis_progress")  ← Clear Stage 1      │
│      • showNotification(STAGE_MESSAGES$report)     ← Skip to Stage 4    │
│        - "📝 正在生成 AI 報告..."                                         │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
         (AI Available)              (No AI - Skip Stage 3)
                   │                           │
                   ▼                           │
┌─────────────────────────────────────────────┐│
│        STAGE 3: AI NAMING                   ││
│  ai_naming_task ExtendedTask                ││
│  Lines: 866-928                             ││
├─────────────────────────────────────────────┤│
│  • Triggered by cluster_analysis() change   ││
│  • generate_cluster_names()                 ││
│  • Runs asynchronously via future           ││
│  • Task status: "running" → "success"       ││
│  Note: This stage uses separate notification││
│  "🤖 AI naming started..." / "✅ completed"  ││
└────────────────────┬────────────────────────┘│
                     │                         │
                     ▼ (5-10 seconds)          │
                     │◄────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                  STAGE 4: AI REPORT GENERATION                          │
│  Main observeEvent for report generation                                │
│  Lines: 1537-1815                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  • Check: component_status() == "ready"     ← Data ready                │
│  • Check: !ms_analysis_generated()          ← Not generated yet         │
│  • Check: AI naming complete or no AI task  ← Wait for AI naming        │
│  • ms_analysis_generated(TRUE)              ← Set flag IMMEDIATELY      │
│  • removeNotification("ms_analysis_progress") ← Clear previous          │
│  • showNotification(STAGE_MESSAGES$report)    ← Show Stage 4            │
│    - "📝 正在生成 AI 報告..."                                             │
│  • later::later() {                         ← Async execution           │
│      • Get cluster analysis data                                        │
│      • Convert to CSV format                                            │
│      • Call chat_api() with GPT                                         │
│      • Process response                                                 │
│      • ms_ai_analysis_result(txt)         ← Store result                │
│    }                                                                    │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
              (Success)                    (Error)
                   │                           │
                   ▼                           ▼
┌─────────────────────────────────┐ ┌─────────────────────────────────┐
│  COMPLETION NOTIFICATION        │ │  ERROR NOTIFICATION              │
│  Lines: 1791-1798               │ │  Lines: 1805-1812                │
├─────────────────────────────────┤ ├─────────────────────────────────┤
│  • removeNotification()         │ │  • removeNotification()          │
│  • showNotification()           │ │  • showNotification()            │
│    - "✅ AI 報告已更新！"        │ │    - "❌ AI 報告生成失敗：{err}" │
│    - type: "message"            │ │    - type: "error"               │
│    - duration: 3 seconds        │ │    - duration: 5 seconds         │
│  • Auto-dismiss after 3s        │ │  • Auto-dismiss after 5s         │
│  • Report displays in UI        │ │  • Error message displays        │
└─────────────────────────────────┘ └─────────────────────────────────┘
```

## Simplified Flow (No AI Naming)

```
User Changes Filter
        ↓
┌─────────────────────┐
│  📊 正在提取資料...   │  Stage 1 (immediate)
└──────────┬──────────┘
           ↓ (2 seconds)
┌─────────────────────┐
│ 📝 正在生成AI報告... │  Stage 4 (skip Stage 3)
└──────────┬──────────┘
           ↓ (15 seconds)
┌─────────────────────┐
│ ✅ AI 報告已更新！    │  Completion (auto-dismiss 3s)
└─────────────────────┘
```

## Error Flow

```
User Changes Filter
        ↓
┌─────────────────────┐
│  📊 正在提取資料...   │  Stage 1
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ 🏷️ 正在產生分群名稱...│  Stage 3
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ 📝 正在生成AI報告... │  Stage 4
└──────────┬──────────┘
           ↓ (Error occurs)
┌─────────────────────┐
│ ❌ AI報告生成失敗... │  Error (auto-dismiss 5s)
└─────────────────────┘
```

## Notification ID Management

```
┌──────────────────────────────────────────────────────────┐
│  Notification ID: "ms_analysis_progress"                 │
│  Purpose: Track and replace progress notifications        │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Stage 1: showNotification(id = "ms_analysis_progress")  │
│            ↓                                              │
│  Stage 3: removeNotification("ms_analysis_progress")     │
│            showNotification(id = "ms_analysis_progress")  │
│            ↓                                              │
│  Stage 4: removeNotification("ms_analysis_progress")     │
│            showNotification(id = "ms_analysis_progress")  │
│            ↓                                              │
│  Complete: removeNotification("ms_analysis_progress")    │
│            showNotification(no id - temporary)            │
│                                                           │
└──────────────────────────────────────────────────────────┘

Why this works:
• Same ID allows replacing notifications
• removeNotification() before showNotification() prevents stacking
• Completion/error use temporary notifications (auto-dismiss)
```

## Reactive Dependency Chain

```
platform_id() / product_line_id() change
        ↓
observeEvent FIRES (Lines 1511-1532)
        ↓
• Clear report
• Reset flag
• Show Stage 1 notification
        ↓
position_data() reactive updates
        ↓
csa_result() reactive updates
        ↓
• Perform CSA analysis
• Show Stage 3 notification (if AI) or Stage 4 (no AI)
        ↓
cluster_analysis() reactive updates
        ↓
ai_naming_task triggered (if available)
        ↓
Main observeEvent FIRES (Lines 1537-1815)
        ↓
• Check all conditions
• Show Stage 4 notification
• Start later::later() async execution
        ↓
later::later() callback executes
        ↓
• Generate report
• Show completion/error notification
```

## Timing Breakdown

```
┌───────────────┬──────────────┬─────────────────────────────┐
│ Stage         │ Expected Time│ Operation                   │
├───────────────┼──────────────┼─────────────────────────────┤
│ Stage 1       │ < 0.1s       │ Show notification only      │
│ Data Extract  │ 1-2s         │ Database query + filtering  │
│ Stage 2       │ N/A          │ Internal (no notification)  │
│ Cluster Calc  │ 0.5-1s       │ MDS + hierarchical cluster  │
│ Stage 3       │ < 0.1s       │ Show notification only      │
│ AI Naming     │ 5-10s        │ OpenAI API call             │
│ Stage 4       │ < 0.1s       │ Show notification only      │
│ AI Report     │ 10-20s       │ OpenAI API call (longer)    │
│ Completion    │ 3s           │ Auto-dismiss timer          │
├───────────────┼──────────────┼─────────────────────────────┤
│ TOTAL         │ 15-30s       │ Complete analysis cycle     │
└───────────────┴──────────────┴─────────────────────────────┘

User Experience Timeline:
0s:    User changes filter
0.1s:  Stage 1 notification appears
2s:    Stage 3 notification appears (with AI)
10s:   Stage 4 notification appears
25s:   Completion notification appears
28s:   Completion notification auto-dismisses
```

## Code Location Map

```
positionMSPlotly.R Structure:

Lines 1-91:    Helper functions and operators
Lines 92-101:  ★ STAGE_MESSAGES definition
Lines 102-413: Data transformation functions
Lines 514-595: Filter UI
Lines 596-644: Display UI
Lines 645-1748: ★ Server logic

Server Logic Breakdown:
Lines 658-685:  Setup (API key, namespaces)
Lines 686-738:  Configuration extraction
Lines 739-804:  position_data reactive
Lines 807-872:  ★ csa_result reactive (Stage 2/3 notification)
Lines 873-850:  csa_data reactive
Lines 853-861:  cluster_analysis reactive
Lines 866-928:  ai_naming_task ExtendedTask
Lines 1511-1532: ★ Filter change observer (Stage 1 notification)
Lines 1537-1815: ★ Main report observer (Stage 4 notification + completion/error)
```

## Notification State Machine

```
┌─────────┐  Filter Change   ┌─────────┐
│  IDLE   │ ───────────────> │ STAGE_1 │ "📊 正在提取資料..."
└─────────┘                  └────┬────┘
                                  │
                        Data Ready│
                                  ↓
                             ┌─────────┐
                             │ STAGE_3 │ "🏷️ 正在產生分群名稱..."
                             │ (if AI) │ (or skip to STAGE_4)
                             └────┬────┘
                                  │
                      AI Naming Done│
                                  ↓
                             ┌─────────┐
                             │ STAGE_4 │ "📝 正在生成 AI 報告..."
                             └────┬────┘
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
            Report Done                     Error Occurred
                  │                               │
                  ↓                               ↓
            ┌──────────┐                   ┌──────────┐
            │ COMPLETE │                   │  ERROR   │
            └──────────┘                   └──────────┘
            "✅ AI 報告已更新！"             "❌ AI 報告生成失敗..."
                  │                               │
            Auto-dismiss (3s)              Auto-dismiss (5s)
                  │                               │
                  └───────────────┬───────────────┘
                                  ↓
                             ┌─────────┐
                             │  IDLE   │
                             └─────────┘
```

## Error Handling Flow

```
At Any Stage:
        ↓
    Error Occurs
        ↓
    ┌───────────────────────────────┐
    │ Catch in tryCatch             │
    │ Lines: 1800-1813              │
    ├───────────────────────────────┤
    │ • Store error message         │
    │ • removeNotification()        │
    │ • showNotification(error)     │
    │   - "❌ AI 報告生成失敗：{err}"│
    │   - type: "error"             │
    │   - duration: 5               │
    └───────────────────────────────┘
        ↓
    Error notification displays
    User sees specific error message
    Auto-dismisses after 5 seconds
        ↓
    User can try again or check logs
```

## Concurrency Handling

```
Scenario: User changes filter rapidly

Change 1                Change 2                Change 3
   ↓                       ↓                       ↓
Stage 1 shown          Stage 1 REPLACED        Stage 1 REPLACED
   ↓                       ↓                       ↓
Processing starts      Flag reset              Flag reset
   ↓                   Processing starts       Processing starts
ABANDONED              ABANDONED               CONTINUES
                                              to completion

Key Mechanism:
• ms_analysis_generated(FALSE) resets flag
• Only latest analysis proceeds to Stage 4
• removeNotification() prevents stacking
• Same notification ID ensures replacement
```

## Principle Alignment Diagram

```
┌─────────────────────────────────────────────────────────┐
│              MAMBA Principles Applied                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  MP088: Immediate Feedback Principle                   │
│  ═══════════════════════════════                       │
│         ↓                                               │
│  Stage 1: < 100ms from filter change                   │
│  Stage transitions: Real-time updates                  │
│  Completion: Immediate confirmation                    │
│                                                         │
│  UI_R007: 標準化介面文字 (Standardized UI Text)         │
│  ════════════════════════════════════════              │
│         ↓                                               │
│  All messages in Traditional Chinese                   │
│  Consistent emoji usage                                │
│  User-friendly stage descriptions                      │
│                                                         │
│  MP052: Unidirectional Data Flow                       │
│  ════════════════════════════                          │
│         ↓                                               │
│  Filter change → Data → Cluster → Report               │
│  Single source of truth for generation                 │
│  Clear progression through stages                      │
│                                                         │
│  R009: UI-Server-Defaults Triple                       │
│  ════════════════════════════                          │
│         ↓                                               │
│  Notifications integrated into server logic            │
│  Consistent with existing patterns                     │
│  Proper reactive dependency management                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Reference: Notification Code Snippets

### Stage 1 (Filter Change)
```r
showNotification(
  STAGE_MESSAGES$data,
  id = "ms_analysis_progress",
  type = "message",
  duration = NULL,
  closeButton = FALSE
)
```

### Stage 3 (AI Naming)
```r
removeNotification("ms_analysis_progress")
showNotification(
  STAGE_MESSAGES$naming,
  id = "ms_analysis_progress",
  type = "message",
  duration = NULL,
  closeButton = FALSE
)
```

### Stage 4 (AI Report)
```r
removeNotification("ms_analysis_progress")
showNotification(
  STAGE_MESSAGES$report,
  id = "ms_analysis_progress",
  type = "message",
  duration = NULL,
  closeButton = FALSE
)
```

### Completion
```r
removeNotification("ms_analysis_progress")
showNotification(
  STAGE_MESSAGES$complete,
  type = "message",
  duration = 3
)
```

### Error
```r
removeNotification("ms_analysis_progress")
showNotification(
  paste("❌ AI 報告生成失敗：", e$message),
  type = "error",
  duration = 5
)
```

---

**Implementation Complete**: 2025-11-02
**Component**: positionMSPlotly
**Total Code Changes**: ~70 lines
**MAMBA Principles**: MP088, UI_R007, MP052, R009
**Status**: ✅ Production Ready
