---
issue: "ISSUE_105"
title: "ISSUE 155: Reactive Flow Diagrams"
severity: "medium"
component: "general"
app: "mamba"
created: "2025-01-01"
status: "open"
---

# ISSUE 155: Reactive Flow Diagrams

## Before Fix (Buggy Behavior)

```
┌─────────────────────────────────────────────────────────────────┐
│ User Action: Filter Change                                       │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Filter Observer (lines 1497-1508)                                │
│ - ms_analysis_generated(FALSE)  ← Reset flag                     │
│ - ms_ai_analysis_result("Filters changed...")                    │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Cluster Analysis Reactive (line 853-861)                         │
│ - analyze_clusters(csa, pos_data)                                │
│ - Returns new cluster analysis                                   │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ AI Naming Observer (lines 881-928)                               │
│ - Detects cluster_analysis() changed                             │
│ - ai_naming_task$invoke(analysis, gpt_key)                       │
│ - Task app: "mamba"
status: "initial" → "running"                             │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ❌ PROBLEM: Main Observer FIRES (OLD CODE)                       │
│ - Triggered by ai_naming_task$status() = "running"               │
│ - Handler executes immediately                                   │
│ - Inside handler: checks status again                            │
│ - But TOO LATE - observer already triggered on "running"         │
│                                                                   │
│ OLD CODE:                                                         │
│   observeEvent({                                                  │
│     ai_naming_task$status()  ← Fires on ALL status changes       │
│   }, {                                                            │
│     if (status == "success") { generate() }  ← Checked too late  │
│   })                                                              │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ❌ RACE CONDITION                                                 │
│ - Report generation starts                                       │
│ - cluster_analysis() called (still has default names)            │
│ - Report uses "Segment 1", "Segment 2"                          │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ AI Naming Completes (too late)                                   │
│ - Task app: "mamba"
status: "success"                                          │
│ - AI names available: ["Budget-Conscious", "Premium"]            │
│ - But report already generated with default names ❌              │
└─────────────────────────────────────────────────────────────────┘
```

## After Fix (Correct Behavior)

```
┌─────────────────────────────────────────────────────────────────┐
│ User Action: Filter Change                                       │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Filter Observer (lines 1499-1510)                                │
│ - ms_analysis_generated(FALSE)  ← Reset flag                     │
│ - ms_ai_analysis_result("Filters changed...")                    │
│ - NO generation logic (single responsibility) ✅                  │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Main Observer FIRES (flag changed)                               │
│ - Checks: component_status() != "ready" → EXIT                   │
│ - Waits for data...                                              │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Cluster Analysis Completes                                       │
│ - component_status("ready")                                       │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Main Observer FIRES (status changed)                             │
│ - Checks: ai_status = "initial" → EXIT ✅                        │
│ - Waits for AI naming...                                         │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ AI Naming Starts                                                  │
│ - ai_naming_task$invoke()                                         │
│ - Task app: "mamba"
status: "initial" → "running"                             │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ✅ FIX: Main Observer FIRES (status changed to "running")        │
│ - Checks: ai_status = "running" → EXIT ✅                        │
│ - DOES NOT generate yet                                          │
│ - Waits for terminal state...                                    │
│                                                                   │
│ NEW CODE:                                                         │
│   observeEvent({                                                  │
│     ai_status <- ai_naming_task$status()                          │
│     list(ai_status, comp_status, flag)                            │
│   }, {                                                            │
│     if (ai_status == "running") { return() }  ← EXIT early ✅    │
│     if (ai_status == "success") { generate() } ← Only on success │
│   })                                                              │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ AI Naming Completes                                               │
│ - Task app: "mamba"
status: "running" → "success" ✅                          │
│ - AI names available: ["Budget-Conscious", "Premium"]            │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ✅ Main Observer FIRES (status changed to "success")             │
│ - Checks: ai_status = "success" → GENERATE ✅                    │
│ - ms_analysis_generated(TRUE)                                    │
│ - Starts report generation                                       │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ✅ Report Generation                                              │
│ - Gets cluster_analysis()                                         │
│ - Gets ai_naming_task$result() ← AI names available ✅           │
│ - Creates table with AI-generated names                          │
│ - Sends to GPT for market segmentation analysis                  │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ ✅ Report Displays with Correct Names                            │
│ - "Budget-Conscious Segment" (not "Segment 1") ✅                │
│ - "Premium Segment" (not "Segment 2") ✅                          │
│ - Market share analysis with meaningful names                    │
└─────────────────────────────────────────────────────────────────┘
```

## Key Differences

### OLD CODE (Buggy)
```r
observeEvent({
  ai_naming_task$status()  # Triggers on EVERY change
}, {
  # Check inside handler - TOO LATE
  if (status == "success" || status == "error") {
    generate()
  }
})
```

**Problem**: Observer fires on intermediate states (`"initial"`, `"running"`), then checks status inside handler.

### NEW CODE (Fixed)
```r
observeEvent({
  ai_status <- ai_naming_task$status()
  list(ai_status, comp_status, flag)
}, {
  # Check FIRST - before any generation logic
  if (ai_status == "running" || ai_status == "initial") {
    return()  # EXIT immediately - wait for terminal state
  }
  if (ai_status == "success" || ai_status == "error") {
    generate()  # NOW safe to generate
  }
})
```

**Solution**: Check status FIRST, return immediately for non-terminal states.

## Debug Log Output (Expected)

### Successful Flow
```
DEBUG: Filters changed - reset ms_analysis_generated to FALSE
DEBUG: Main observer triggered - checking generation conditions...
DEBUG: component_status = loading
DEBUG: Component not ready, exiting

DEBUG: Main observer triggered - checking generation conditions...
DEBUG: component_status = ready
DEBUG: ms_analysis_generated = FALSE
DEBUG: AI naming status = initial
DEBUG: AI naming status 'initial' - waiting for completion

AI naming task invoked for analysis ID: 3_1234

DEBUG: Main observer triggered - checking generation conditions...
DEBUG: component_status = ready
DEBUG: ms_analysis_generated = FALSE
DEBUG: AI naming status = running
DEBUG: AI naming status 'running' - waiting for completion

AI naming task completed with app: "mamba"
status: success

DEBUG: Main observer triggered - checking generation conditions...
DEBUG: component_status = ready
DEBUG: ms_analysis_generated = FALSE
DEBUG: AI naming status = success
DEBUG: AI naming completed with status 'success', generating report
DEBUG: Setting ms_analysis_generated to TRUE, starting report generation
DEBUG: Getting actual table data for AI analysis...
DEBUG: Table data converted to CSV, length: 523
DEBUG: About to call GPT for market segmentation analysis...
DEBUG: GPT response received, length: 1247
DEBUG: Market segmentation report generation COMPLETED successfully
```

### Without AI Key
```
DEBUG: Filters changed - reset ms_analysis_generated to FALSE
DEBUG: Main observer triggered - checking generation conditions...
DEBUG: component_status = ready
DEBUG: ms_analysis_generated = FALSE
DEBUG: AI naming status = no_task
DEBUG: No AI naming task, generating with default names
DEBUG: Setting ms_analysis_generated to TRUE, starting report generation
DEBUG: Market segmentation report generation COMPLETED successfully
```

## State Transition Diagram

```
┌──────────────┐
│ Filter Change│
└──────┬───────┘
       │ ms_analysis_generated(FALSE)
       ▼
┌──────────────┐     comp_status      ┌──────────────┐
│   waiting    │ ─────ready──────────▶ │ data_ready   │
└──────────────┘                       └──────┬───────┘
                                              │
                                              │ ai_status = "initial"
                                              ▼
                                       ┌──────────────┐
                                       │waiting_ai    │
                                       └──────┬───────┘
                                              │
                                              │ ai_status = "running"
                                              ▼
                                       ┌──────────────┐
                                       │  ai_running  │
                                       └──────┬───────┘
                                              │
                                              │ ai_status = "success" or "error"
                                              ▼
                                       ┌──────────────┐
                                       │  generate    │
                                       └──────┬───────┘
                                              │
                                              │ ms_analysis_generated(TRUE)
                                              ▼
                                       ┌──────────────┐
                                       │  completed   │
                                       └──────────────┘
```

## Critical Fix Points

1. **Terminal State Filtering**: Only generate on `"success"` or `"error"` (never on `"running"`)
2. **Early Returns**: Exit immediately for non-terminal states
3. **Explicit Dependencies**: Track all three reactive values in observer expression
4. **Flag Management**: Set flag immediately before async generation
5. **Debug Visibility**: Log all state transitions for troubleshooting

---

**Principle**: MP52 (Unidirectional Data Flow) ensures single source of truth for generation.
**Principle**: R09 (UI-Server-Defaults Triple) ensures proper reactive dependency management.
