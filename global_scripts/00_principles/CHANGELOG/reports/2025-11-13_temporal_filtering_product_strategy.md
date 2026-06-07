# TEMPORAL FILTERING PRODUCT STRATEGY & PRINCIPLE DESIGN

**Document Type**: Product Strategy & Architecture Decision Record
**Created**: 2025-11-13
**Owner**: Principle Product Manager
**Status**: EXECUTIVE RECOMMENDATION
**Related Issues**: Systemic Date Range Filtering Gap

---

## EXECUTIVE SUMMARY

### Critical Finding
All three Poisson analysis components (Feature, Comment, Time Analysis) load **ALL historical data** without date range filtering, preventing users from selecting analysis periods. This is a **systemic architectural gap**, not a component-specific bug.

### Strategic Recommendation
**IMPLEMENT GLOBAL DATE RANGE FILTERING (Option A - Centralized)**

**Decision Rationale**:
- Analytical consistency: Users expect same time period across all analyses
- Reduced cognitive load: Set once, apply everywhere
- Aligned with MAMBA principle MP052 (Unidirectional Data Flow)
- Faster implementation: Single filter point, simpler state management

**Impact**:
- **User Impact**: HIGH - Currently cannot control analysis period
- **Development Effort**: MEDIUM (2-3 weeks for complete implementation)
- **Technical Debt**: HIGH if not addressed
- **Risk**: MEDIUM (requires ETL validation, testing across all components)

---

## 1. PRODUCT DECISION FRAMEWORK

### 1.1 Core Question: Should ALL Components Have Date Range Filtering?

**Answer: YES, with clear categorization**

#### MUST Have Date Range Filtering (Priority 1)
**Criteria**: Components analyzing time-varying data (events, transactions, behavior patterns)

**Affected Components**:
- ✅ **Poisson Analysis Suite** (Feature, Comment, Time) - PRIMARY TARGET
  - Analyzes sales events over time
  - Currently loads ALL historical data
  - Users need period selection for trend analysis

- ✅ **macroTrend**
  - Already has basic date range filter (lines 98-105 in macroTrend.R)
  - ✓ COMPLIANT (lines 98-105 show dateRangeInput exists)

- ⚠️ **microCustomer** (needs verification)
  - Likely analyzes customer behavior over time
  - STATUS: Requires audit

- ⚠️ **microDNADistribution** (needs verification)
  - If customer DNA changes over time
  - STATUS: Requires audit

#### SHOULD Have Date Range Filtering (Priority 2)
**Criteria**: Components where temporal scope enhances analysis but isn't critical

**Potentially Affected**:
- **reportIntegration** - Generated reports may benefit from period selection
- **positionStrategy** - Competitive positioning may vary by period

#### MAY NOT Need Date Range Filtering (Priority 3)
**Criteria**: Static/reference data, metadata, configuration views

**Examples**:
- **positionTable** - Current snapshot positioning (no date column observed)
- Static reference data tables
- Product attribute catalogs

---

### 1.2 Architecture Decision: Component-Level vs Global?

**RECOMMENDATION: GLOBAL DATE RANGE (Option A)**

#### Option A: Global Date Range (SELECTED)

```yaml
Architecture:
  Filter Location: Union-level (top navigation)
  State Management: comp_config passes date_range to all components
  Component Behavior: Components extract and apply filter from config

Pros:
  - Consistent analysis period across all tabs (user expectation)
  - Single source of truth (follows MP052 Unidirectional Data Flow)
  - Simpler state management (one reactive date_range)
  - Faster development (modify union + component data access)
  - Better user experience (set once, applies everywhere)

Cons:
  - Less flexible (cannot analyze different periods per component)
  - Requires component audit to ensure all respect date_range

Implementation Complexity: MEDIUM
Time Estimate: 2-3 weeks
User Experience: EXCELLENT (familiar pattern from macroTrend)
```

#### Option B: Component-Level Date Range (NOT RECOMMENDED)

```yaml
Architecture:
  Filter Location: Each component's filter panel
  State Management: Independent reactive values per component
  Component Behavior: Each manages own date range

Pros:
  - Maximum flexibility (different periods per tab)
  - Component independence

Cons:
  - User confusion (which period am I seeing?)
  - State synchronization nightmare
  - Inconsistent cross-component insights
  - 3-5x more development effort
  - Violates MP052 (multiple data flow sources)

Implementation Complexity: HIGH
Time Estimate: 5-7 weeks
User Experience: POOR (cognitive overload)
```

#### Option C: Hybrid (FUTURE CONSIDERATION)

```yaml
Architecture:
  Filter Location: Global default + component override
  State Management: Global reactive + component-specific override flag

Pros:
  - Best of both worlds

Cons:
  - Much higher complexity
  - Requires clear UI/UX for override indication
  - Phase 2 feature (implement after Option A proves successful)

Recommendation: Consider for v2.0 after Option A is stable
```

---

### 1.3 Default Date Range Behavior

**RECOMMENDATION: Last 90 Days (with "All Time" option)**

```yaml
Default Behavior:
  Initial Load: Last 90 days from today
  Rationale:
    - Balances recency (last quarter) with sufficient data
    - Matches macroTrend default (line 102: Sys.Date() - 90)
    - Fast query performance (<10k rows typically)
    - Covers seasonal patterns (one quarter)

Options Provided:
  - Last 30 Days (quick recent snapshot)
  - Last 90 Days (DEFAULT - quarterly view)
  - Last 180 Days (half-year trends)
  - Last 365 Days (annual comparison)
  - All Time (complete history - performance warning)
  - Custom Range (user-specified start/end)

Warning System:
  - Show data volume warning if date range > 365 days
  - Estimate query time for "All Time" option
  - Provide option to sample data for large ranges
```

**MP029 Compliance**: All default ranges MUST be calculated from actual data, NEVER hardcoded dates.

---

## 2. TECHNICAL INVESTIGATION FINDINGS

### 2.1 Component Audit Results

#### Poisson Components (3 components - NON-COMPLIANT)

**poissonFeatureAnalysis.R**:
- **Line 308**: `tbl2(app_data_connection, table_name) %>% dplyr::filter(predictor_type == "product_feature")`
- **NO date filtering** - loads entire `df_cbz_poisson_analysis_all` table
- **Issue**: Users see cumulative results across ALL time periods
- **Impact**: Cannot analyze feature importance trends by period

**poissonCommentAnalysis.R**:
- **Similar pattern** - no date filtering observed in data access
- **Impact**: Comment sentiment analysis cannot be period-specific

**poissonTimeAnalysis.R**:
- **Line 308**: `tbl2(app_data_connection, table_name) %>% dplyr::filter(predictor_type == "time_feature")`
- **Ironic**: Component analyzes TIME effects but has NO date range filter
- **Impact**: Cannot analyze how time patterns change over periods

#### macroTrend.R (COMPLIANT)

- **Lines 98-105**: dateRangeInput with default `start = Sys.Date() - 90`
- **Lines 424-429**: Filter application in `filtered_data()` reactive
- **✓ GOLD STANDARD**: This component implements correct pattern
- **Serves as reference implementation**

#### positionTable.R (LIKELY N/A)

- **No date filtering** - analyzes current positioning snapshot
- **Column analysis**: No `order_date` or time columns in data structure
- **Verdict**: Date filtering NOT APPLICABLE (static positioning data)
- **Status**: ✓ APPROPRIATE BEHAVIOR

### 2.2 Data Structure Analysis

#### ETL Output Schema (from cbz_DRV_product_line_poisson.R)

```sql
-- df_cbz_poisson_analysis_{product_line} schema
-- INPUT: df_cbz_sales_complete_time_series_{product_line}

Columns:
  - product_line_id         (filter key)
  - platform                (filter key)
  - predictor               (feature name)
  - predictor_type          (product_feature | comment_feature | time_feature)
  - coefficient             (Poisson regression result)
  - incidence_rate_ratio    (IRR)
  - p_value                 (significance)
  - analysis_date           (TIMESTAMP - when analysis was run)
  - analysis_version        (metadata)

CRITICAL FINDING:
  - NO order_date or transaction_date column in OUTPUT table
  - Analysis runs on AGGREGATED time series data
  - Time window is IMPLICIT in input data (df_cbz_sales_complete_time_series_{pl})
```

**Architectural Insight**: Poisson analysis tables store **pre-computed regression results**, not raw transactions. Date filtering must occur at **ETL input stage**, not component query stage.

---

## 3. IMMEDIATE ACTION PLAN

### Phase 1: Investigation Complete ✅ (Week 1, Day 1-2)

**Deliverables**:
- ✅ Component audit complete (macroTrend compliant, Poisson non-compliant)
- ✅ ETL data structure analyzed (no date column in Poisson output)
- ✅ Architecture gap identified (date filtering needed at ETL input)

### Phase 2: Quick Fix (Week 1, Day 3-5)

**Objective**: Unblock users with temporary workaround

**Actions**:
1. **Add UI Date Range Filter** (1 day)
   - Add dateRangeInput to union-level filter panel
   - Wire to comp_config reactive
   - Default: Last 90 days

2. **Update Component Data Access** (1 day)
   - Modify Poisson components to extract date_range from config
   - NO backend changes yet (just UI indication)
   - Add notice: "Date filtering coming soon - currently showing all data"

3. **Documentation** (0.5 days)
   - Update user guide with current limitation
   - Communicate timeline for full implementation

**Limitations**:
- Date filter visible but NOT FUNCTIONAL for Poisson components
- Transparent to users about limitation
- Prevents user confusion about missing filter

### Phase 3: Proper Implementation (Week 2-3)

**Objective**: Implement end-to-end date filtering

#### 3.1 ETL Layer Updates (Week 2)

**File**: `cbz_DRV_product_line_poisson.R` (lines 88-96)

**Change**: Parameterize input data date range

```r
# CURRENT (Line 96):
ts_data <- dbReadTable(con_app, table_name)

# PROPOSED:
ts_data <- dbReadTable(con_app, table_name) %>%
  dplyr::filter(
    order_date >= as.Date(config$date_range_start),
    order_date <= as.Date(config$date_range_end)
  )

# Add to script header:
# PARAMETERS (passed from app or config):
#   - date_range_start: Filter start date (default: Sys.Date() - 90)
#   - date_range_end: Filter end date (default: Sys.Date())
```

**Impact Analysis**:
- Requires ETL re-run when date range changes
- Consider caching strategy (pre-compute common ranges: 30d, 90d, 365d, all)
- Balance between real-time flexibility and performance

#### 3.2 Component Layer Updates (Week 2)

**Files**: `poissonFeatureAnalysis.R`, `poissonCommentAnalysis.R`, `poissonTimeAnalysis.R`

**Change 1: Extract date_range from config**

```r
# Add after line 287 (product_line_id reactive):
date_range <- reactive({
  tryCatch({
    if (is.null(config)) return(list(start = Sys.Date() - 90, end = Sys.Date()))

    cfg <- if (is.function(config)) config() else config

    if (!is.null(cfg$filters$date_range)) {
      return(cfg$filters$date_range)
    }

    # Default: last 90 days
    list(start = Sys.Date() - 90, end = Sys.Date())
  }, error = function(e) {
    warning("Error extracting date_range: ", e$message)
    list(start = Sys.Date() - 90, end = Sys.Date())
  })
})
```

**Change 2: Apply filter to data access (if date column exists)**

```r
# Modify poisson_data reactive (around line 304):
poisson_data <- reactive({
  component_status("loading")

  result <- tryCatch({
    # ... existing connection check ...

    tbl <- tbl2(app_data_connection, table_name)

    # Apply predictor_type filter
    time_data <- tbl %>%
      dplyr::filter(predictor_type == "time_feature")

    # NEW: Apply date filter if column exists
    if ("analysis_date" %in% colnames(time_data)) {
      date_filter <- date_range()
      time_data <- time_data %>%
        dplyr::filter(
          analysis_date >= date_filter$start,
          analysis_date <= date_filter$end
        )
    }

    time_data <- time_data %>% collect()

    # ... rest of function ...
  })
})
```

#### 3.3 Union Layer Updates (Week 3)

**File**: `union_production_test.R` or equivalent union component

**Add Global Date Range Filter**:

```r
# In UI section (filter sidebar):
dateRangeInput(
  inputId = "global_date_range",
  label = "Analysis Period",
  start = Sys.Date() - 90,
  end = Sys.Date(),
  min = as.Date("2020-01-01"),  # Use actual data min date
  max = Sys.Date(),
  format = "yyyy-mm-dd",
  separator = " to "
)

# Add quick selection buttons
actionButton("date_30d", "Last 30 Days", class = "btn-sm"),
actionButton("date_90d", "Last 90 Days", class = "btn-sm"),
actionButton("date_365d", "Last Year", class = "btn-sm"),
actionButton("date_all", "All Time", class = "btn-sm")

# In comp_config reactive:
comp_config <- reactive({
  list(
    platform = input$platform,
    product_line_id = input$product_line,
    filters = list(
      platform_id = input$platform,
      product_line_id = input$product_line,
      date_range = list(
        start = input$global_date_range[1],
        end = input$global_date_range[2]
      )
    )
  )
})
```

---

## 4. NEW MAMBA PRINCIPLES

### 4.1 MP### - Data Temporal Scope Principle

```yaml
Principle ID: MP135
Title: Data Temporal Scope Principle
Category: Data Management / UI Components
Priority: MUST
Created: 2025-11-13
Status: PROPOSED

Problem Statement:
  Analytical components loading unbounded historical data without user control
  leads to:
    - Inability to perform period-specific analysis
    - Performance degradation with large datasets
    - User confusion about "what period am I seeing?"
    - Inconsistent insights across components

Core Requirement:
  All components analyzing time-varying data MUST provide temporal scope control
  through date range filtering.

Implementation Rules:

  1. MUST Provide Date Range Filter:
     - Components analyzing events, transactions, or time-series data
     - Default range: Last 90 days (or appropriate for data cadence)
     - Must include "All Time" option with performance warning

  2. SHOULD Provide Date Range Filter:
     - Components where temporal context enhances analysis
     - Example: Customer segments that may change over time

  3. MAY OMIT Date Range Filter:
     - Static reference data
     - Metadata and configuration views
     - Current snapshot positioning (no historical dimension)

Default Behavior:
  When date_range is NULL or not specified:
    - MUST default to last 90 days from current date
    - MUST calculate from actual data boundaries (MP029 compliance)
    - MUST NOT use hardcoded dates
    - MUST document default in component header

Filter Integration:
  - Use global date range from comp_config$filters$date_range
  - Extract with defensive programming (default to 90 days on error)
  - Pass to data access layer for early filtering
  - Log applied date range for debugging

Performance Considerations:
  - Warn users if date range > 365 days
  - Consider data sampling for very large ranges
  - Pre-compute common ranges (30d, 90d, 365d) at ETL stage

Code Pattern:
  ```r
  date_range <- reactive({
    tryCatch({
      cfg <- if (is.function(config)) config() else config
      cfg$filters$date_range %||% list(start = Sys.Date() - 90, end = Sys.Date())
    }, error = function(e) {
      list(start = Sys.Date() - 90, end = Sys.Date())
    })
  })

  filtered_data <- data %>%
    dplyr::filter(
      date_column >= date_range()$start,
      date_column <= date_range()$end
    )
  ```

Exceptions:
  - ETL-generated pre-aggregated tables without date columns
  - In such cases, date filtering MUST occur at ETL input stage
  - Document ETL date parameterization requirements

Validation:
  - Component initialization MUST log applied date range
  - Unit tests MUST verify date filtering logic
  - Integration tests MUST verify comp_config date_range flow

Related Principles:
  - MP052: Unidirectional Data Flow (date range flows from union to components)
  - MP029: No Fake Data (default dates calculated from real data)
  - MP088: Immediate Feedback (date changes apply instantly)
  - R116: Enhanced Data Access with tbl2 (data access layer)
```

---

### 4.2 UI_R022 - Component Temporal Filter Contract

```yaml
Principle ID: UI_R022
Title: Component Temporal Filter Contract
Category: UI Components / Architecture
Priority: MUST
Created: 2025-11-13
Status: PROPOSED

Problem Statement:
  Inconsistent temporal filtering across components causes:
    - User confusion about which filters apply where
    - Difficulty comparing insights across components
    - Unpredictable behavior when switching tabs

Core Requirement:
  All analytical components MUST document and honor a standard temporal
  filter contract.

Standard Filter Interface:

  config$filters structure:
    ```r
    filters = list(
      platform_id = "cbz",           # REQUIRED
      product_line_id = "tur",       # REQUIRED
      date_range = list(             # REQUIRED for time-varying components
        start = as.Date("2024-08-01"),
        end = as.Date("2024-10-31")
      ),
      brand = NULL,                  # OPTIONAL (component-specific)
      product_id = NULL              # OPTIONAL (component-specific)
    )
    ```

Mandatory Filters (ALL components MUST respect):
  - platform_id: Character, data source identifier
  - product_line_id: Character, product category filter
  - date_range: List with $start and $end Date objects (if applicable)

Optional Filters (component-specific):
  - brand: Character vector, brand filter
  - product_id: Character vector, product identifier filter
  - custom filters as needed

Filter Precedence:
  1. Global filters (platform, product_line, date_range) - HIGHEST
  2. Component-specific filters (brand, product_id) - MEDIUM
  3. UI interaction filters (search, sort) - LOWEST

Implementation Pattern:
  ```r
  # Extract global filters
  platform_id <- reactive({
    cfg <- if (is.function(config)) config() else config
    as.character(cfg$filters$platform_id %||% "cbz")
  })

  date_range <- reactive({
    cfg <- if (is.function(config)) config() else config
    cfg$filters$date_range %||% list(start = Sys.Date() - 90, end = Sys.Date())
  })

  # Apply in data access
  filtered_data <- data %>%
    dplyr::filter(
      platform == platform_id(),
      date >= date_range()$start,
      date <= date_range()$end
    )
  ```

Component Documentation Requirements:
  Each component MUST document in header comments:
    - Which mandatory filters are respected
    - Which optional filters are supported
    - Default behavior when filters are NULL/missing
    - Any filter-specific constraints or behaviors

Error Handling:
  - Invalid date range: Default to last 90 days, log warning
  - Missing platform_id: Use "cbz" default, log warning
  - NULL filters object: Use all defaults, log warning

Testing Requirements:
  - Unit test: NULL config → defaults applied
  - Unit test: Partial config → defaults fill gaps
  - Unit test: Full config → all filters respected
  - Integration test: Filter changes propagate to all components

Related Principles:
  - MP135: Data Temporal Scope Principle (temporal filtering requirement)
  - MP052: Unidirectional Data Flow (filter flow direction)
  - MP081: Explicit Parameter Specification (clear filter contracts)
```

---

### 4.3 UI_R023 - Filter State Documentation Principle

```yaml
Principle ID: UI_R023
Title: Filter State Documentation Principle
Category: UI Components / User Experience
Priority: SHOULD
Created: 2025-11-13
Status: PROPOSED

Problem Statement:
  Users cannot easily determine:
    - What filters are currently applied
    - Why they're seeing specific results
    - What happens if filters are changed

Core Requirement:
  Components SHOULD visually communicate active filter state and
  data boundaries to users.

Visual Communication Patterns:

  1. Component Header Status (SHOULD implement):
     ```r
     output$component_status <- renderText({
       dr <- date_range()
       paste0("Showing data from ", dr$start, " to ", dr$end,
              " (", nrow(filtered_data()), " records)")
     })
     ```

  2. Filter Summary Card (RECOMMENDED):
     - Display: Platform, Product Line, Date Range
     - Location: Top of component display area
     - Update: Real-time as filters change

  3. Data Availability Warning (MUST implement if applicable):
     ```r
     if (nrow(filtered_data()) == 0) {
       showNotification(
         "No data available for selected period. Try expanding date range.",
         type = "warning"
       )
     }
     ```

Default Behavior Communication:
  - When using defaults, show: "Using default period: Last 90 days"
  - Provide link to change: "Click here to adjust date range"
  - Log to console (MP106): "Applied default date range: [start] to [end]"

Performance Indicators:
  - Show loading status during filter application
  - Estimate query time for large date ranges
  - Warn before loading > 365 days of data

Code Pattern:
  ```r
  # Filter status output
  output$filter_status <- renderUI({
    dr <- date_range()
    pl <- product_line_id()

    div(class = "filter-status-bar",
      icon("filter"), " Active Filters: ",
      tags$strong(format(dr$start, "%Y-%m-%d")), " to ",
      tags$strong(format(dr$end, "%Y-%m-%d")), " | ",
      tags$strong(toupper(pl)), " | ",
      span(class = "badge", nrow(filtered_data()), "records")
    )
  })
  ```

Related Principles:
  - MP088: Immediate Feedback (instant filter status updates)
  - MP106: Console Output Transparency (log filter applications)
  - UI_R007: Standardized Interface Text (consistent filter labels)
```

---

## 5. COMPONENT CATEGORIZATION AUDIT

### Priority 1: CRITICAL (Must Have Date Filtering)

| Component | Current Status | Date Column Available | Action Required |
|-----------|---------------|----------------------|----------------|
| **poissonFeatureAnalysis** | ❌ NON-COMPLIANT | ⚠️ analysis_date only | IMPLEMENT (HIGH) |
| **poissonCommentAnalysis** | ❌ NON-COMPLIANT | ⚠️ analysis_date only | IMPLEMENT (HIGH) |
| **poissonTimeAnalysis** | ❌ NON-COMPLIANT | ⚠️ analysis_date only | IMPLEMENT (HIGH) |
| **macroTrend** | ✅ COMPLIANT | ✅ order_date | REFERENCE IMPL |

**Estimated Effort**: 2 weeks (ETL + Component updates)

### Priority 2: VERIFY (Likely Need Date Filtering)

| Component | Current Status | Investigation Required |
|-----------|---------------|----------------------|
| **microCustomer** | ⚠️ UNKNOWN | Check if customer metrics are time-varying |
| **microDNADistribution** | ⚠️ UNKNOWN | Check if DNA distribution changes over time |
| **reportIntegration** | ⚠️ UNKNOWN | Check if reports are period-specific |

**Estimated Effort**: 0.5 weeks (audit) + 1 week per component (if needed)

### Priority 3: NO ACTION (Date Filtering Not Applicable)

| Component | Reason | Status |
|-----------|--------|--------|
| **positionTable** | Static positioning snapshot | ✅ APPROPRIATE |
| **positionStrategy** | Current strategic positioning | ✅ APPROPRIATE |
| **positionDNAPlotly** | Current DNA visualization | ✅ APPROPRIATE |
| **positionMSPlotly** | Current market share | ✅ APPROPRIATE |

**Estimated Effort**: 0 weeks (no changes)

---

## 6. IMPLEMENTATION ROADMAP

### Week 1: Foundation & Quick Fix

**Days 1-2: Investigation Complete** ✅
- [x] Component audit
- [x] Data structure analysis
- [x] Architecture decision documentation

**Days 3-5: Quick Fix Deployment**
- [ ] Add UI date range filter (non-functional)
- [ ] Update user documentation with limitation notice
- [ ] Deploy to staging for user feedback

**Deliverable**: Date filter UI visible, users aware of upcoming functionality

### Week 2: ETL Layer Implementation

**Days 1-3: ETL Parameterization**
- [ ] Modify `cbz_DRV_product_line_poisson.R` for date range params
- [ ] Update ETL orchestration to pass date ranges
- [ ] Test ETL with various date ranges
- [ ] Validate output data integrity

**Days 4-5: ETL Optimization**
- [ ] Implement caching for common date ranges (30d, 90d, 365d)
- [ ] Performance testing with large date ranges
- [ ] Document ETL date filtering behavior

**Deliverable**: ETL can generate Poisson analysis for any date range

### Week 3: Component Integration

**Days 1-2: Poisson Components Update**
- [ ] Implement date_range extraction in all 3 Poisson components
- [ ] Wire to comp_config reactive
- [ ] Add filter status display
- [ ] Local testing with mocked date ranges

**Days 3-4: Union Integration**
- [ ] Add global date range selector to union UI
- [ ] Implement quick date buttons (30d, 90d, etc.)
- [ ] Wire date_range to comp_config
- [ ] Integration testing across all components

**Day 5: Validation & Documentation**
- [ ] End-to-end testing
- [ ] Update user guide
- [ ] Create principle documents (MP135, UI_R022, UI_R023)
- [ ] Prepare deployment package

**Deliverable**: Fully functional date range filtering across Poisson components

### Week 4: Priority 2 Audit & Rollout

**Days 1-2: Priority 2 Component Audit**
- [ ] Audit microCustomer for temporal requirements
- [ ] Audit microDNADistribution for temporal requirements
- [ ] Audit reportIntegration for temporal requirements
- [ ] Document findings and effort estimates

**Days 3-5: Production Deployment**
- [ ] Deploy to staging environment
- [ ] User acceptance testing
- [ ] Production deployment
- [ ] Monitor performance and user feedback

**Deliverable**: Date filtering live in production

---

## 7. RISK ASSESSMENT & MITIGATION

### Technical Risks

**Risk 1: ETL Re-Run Performance Impact**
- **Severity**: MEDIUM
- **Probability**: HIGH
- **Impact**: Users must wait for ETL re-run when changing date ranges
- **Mitigation**:
  - Implement caching for common date ranges (30d, 90d, 365d, all)
  - Pre-compute these ranges nightly
  - Show loading indicator with time estimate
  - Consider incremental ETL updates

**Risk 2: Data Integrity During Transition**
- **Severity**: HIGH
- **Probability**: LOW
- **Impact**: Incorrect results if filtering logic is flawed
- **Mitigation**:
  - Comprehensive unit tests for date filtering
  - Side-by-side comparison of old vs new results
  - Staged rollout with canary testing
  - Rollback plan ready

**Risk 3: Backward Compatibility**
- **Severity**: MEDIUM
- **Probability**: MEDIUM
- **Impact**: Existing dashboards/reports break if they expect all-time data
- **Mitigation**:
  - Default to last 90 days (reasonable for most use cases)
  - Provide "All Time" option for legacy behavior
  - Version ETL scripts for rollback capability
  - Communication plan for stakeholders

### User Experience Risks

**Risk 4: Cognitive Load Increase**
- **Severity**: LOW
- **Probability**: MEDIUM
- **Impact**: Users confused by new filter requirement
- **Mitigation**:
  - Smart defaults (90 days) minimize decisions
  - Quick buttons reduce interaction friction
  - Clear visual feedback on applied filters
  - Onboarding tooltips and documentation

**Risk 5: User Expectation Mismatch**
- **Severity**: MEDIUM
- **Probability**: MEDIUM
- **Impact**: Users expect instant filter changes but ETL may take time
- **Mitigation**:
  - Transparent communication about processing time
  - Progress indicators during ETL execution
  - Cache common date ranges for instant access
  - Set realistic expectations in UI

### Operational Risks

**Risk 6: Increased ETL Execution Frequency**
- **Severity**: MEDIUM
- **Probability**: HIGH
- **Impact**: More frequent ETL runs increase infrastructure costs
- **Mitigation**:
  - Intelligent caching strategy
  - Rate limiting on ETL triggers
  - Cost monitoring and optimization
  - Consider incremental processing

---

## 8. SUCCESS METRICS

### User-Facing Metrics

**Primary KPIs**:
1. **Date Range Filter Usage Rate**
   - Target: >70% of sessions use date range filter
   - Measurement: Track filter interactions in analytics

2. **User Satisfaction (NPS)**
   - Target: +20 points increase on "Can I analyze specific time periods?"
   - Measurement: Post-deployment survey

3. **Support Ticket Reduction**
   - Target: -50% tickets related to "How do I filter by date?"
   - Measurement: Support system categorization

**Secondary KPIs**:
4. **Median Date Range Selected**
   - Hypothesis: 90 days (validates default choice)
   - Measurement: Aggregate filter selections

5. **"All Time" Usage Frequency**
   - Target: <15% (most users prefer focused periods)
   - Measurement: Filter selection tracking

### Technical Metrics

**Performance KPIs**:
6. **Query Response Time**
   - Target: <3 seconds for 90-day range
   - Target: <10 seconds for 365-day range
   - Measurement: Server-side logging

7. **ETL Cache Hit Rate**
   - Target: >80% of requests served from cache
   - Measurement: ETL execution logs

8. **Component Rendering Time**
   - Target: <2 seconds after data arrives
   - Measurement: Client-side performance monitoring

**Code Quality KPIs**:
9. **Principle Compliance Rate**
   - Target: 100% of components comply with MP135
   - Measurement: Code review checklist

10. **Test Coverage**
    - Target: >90% coverage of date filtering logic
    - Measurement: Test suite execution reports

---

## 9. COMMUNICATION PLAN

### For Users

**Pre-Implementation Announcement**:
```
Subject: Coming Soon - Date Range Filtering for Poisson Analysis

We've heard your feedback! Starting [DATE], you'll be able to:
✅ Select specific time periods for analysis
✅ Compare different date ranges side-by-side
✅ Focus on recent trends or view historical patterns

Current Limitation:
All analyses show complete historical data. After this update,
you'll see the last 90 days by default, with options to adjust.

Questions? Contact [SUPPORT EMAIL]
```

**Launch Announcement**:
```
Subject: NEW FEATURE - Date Range Filtering Now Available

🎉 Date range filtering is now live across all Poisson analysis components!

Quick Start:
1. Look for the new "Analysis Period" filter at the top
2. Choose from quick options (30d, 90d, 1yr) or select custom range
3. All analysis tabs will update automatically

Default: Last 90 days (you can change to "All Time" if needed)

Learn More: [LINK TO USER GUIDE]
Feedback: [SURVEY LINK]
```

### For Developers

**Technical Documentation Update**:
- Update README with new date filtering architecture
- Add code examples to component development guide
- Document ETL date parameterization requirements
- Update principle INDEX.md with new principles

**Code Review Checklist Addition**:
```markdown
## Date Filtering Compliance Checklist

- [ ] Component extracts date_range from config (if applicable)
- [ ] Defensive programming for NULL/missing date_range
- [ ] Default to last 90 days on error
- [ ] Applies filter to data access layer (not UI layer)
- [ ] Logs applied date range for debugging
- [ ] Unit tests cover date filtering logic
- [ ] Integration tests verify comp_config flow
- [ ] Header comments document temporal filtering behavior
```

---

## 10. DELIVERABLES CHECKLIST

### Executive Deliverables

- ✅ **Executive Decision**: GO - Implement Option A (Global Date Range)
- ✅ **Architecture Choice**: Option A - Centralized filtering with MP052 compliance
- ✅ **Principle Documents**: MP135, UI_R022, UI_R023 drafted
- ✅ **Action Plan**: Week-by-week roadmap with owners and timelines
- ✅ **Communication Templates**: User and developer messaging prepared

### Technical Deliverables

- ✅ **Component Audit Report**: 3 Poisson components non-compliant, macroTrend reference
- ✅ **Data Structure Analysis**: ETL outputs identified, date column limitations documented
- ✅ **Risk Assessment**: 6 risks identified with mitigation strategies
- ✅ **Success Metrics**: 10 KPIs defined for user and technical success
- ✅ **Implementation Roadmap**: 4-week plan with 2-week critical path

---

## 11. NEXT STEPS & DECISION POINTS

### Immediate Actions (This Week)

**Stakeholder Approval Required**:
1. **Product Owner**: Approve Option A (Global Date Range) architecture
2. **Engineering Lead**: Confirm 2-3 week implementation estimate
3. **UX Designer**: Review filter placement and interaction design
4. **Data Team**: Validate ETL parameterization approach

**Technical Preparation**:
1. Create feature branch: `feature/global-date-range-filtering`
2. Set up integration testing environment
3. Prepare ETL staging environment for testing
4. Schedule code review sessions

### Decision Points

**Decision Point 1: ETL Caching Strategy (Week 2, Day 1)**
- **Question**: Pre-compute common ranges or on-demand generation?
- **Options**:
  - A) Pre-compute 30d/90d/365d/all nightly (faster, more storage)
  - B) On-demand with 1-hour cache TTL (flexible, slower first load)
- **Recommendation**: Option A for better UX

**Decision Point 2: Priority 2 Component Scope (Week 4, Day 1)**
- **Question**: Include microCustomer/microDNA in initial rollout?
- **Options**:
  - A) Poisson only first, others in Phase 2
  - B) All time-varying components in single release
- **Recommendation**: Option A to reduce risk

**Decision Point 3: "All Time" Performance Limit (Week 3, Day 3)**
- **Question**: Hard limit or soft warning for large date ranges?
- **Options**:
  - A) Block > 2 years with "Contact support for historical analysis"
  - B) Show warning but allow (with data sampling option)
- **Recommendation**: Option B with 10-second timeout

---

## 12. APPENDIX: PRINCIPLE INTEGRATION STRATEGY

### Existing Principles to Update

**MP052: Unidirectional Data Flow**
- **Current**: Documents data flow from union to components
- **Update**: Add date_range as mandatory filter in comp_config example
- **Section**: Add "Temporal Filter Flow" subsection
- **Location**: `00_principles/docs/en/part1_principles/CH00_fundamental_principles/MP052_unidirectional_data_flow.qmd`

**R116: Enhanced Data Access with tbl2**
- **Current**: Documents universal data access pattern
- **Update**: Add date filtering examples at data access layer
- **Section**: Add "Temporal Filtering with tbl2" code example
- **Location**: `00_principles/docs/en/part1_principles/CH02_data_management/R116_enhanced_data_access.qmd`

**MP029: No Fake Data Principle**
- **Current**: Prohibits fake/mock data in production
- **Update**: Add requirement for date range defaults calculated from real data
- **Section**: Add "Temporal Scope Defaults" compliance rule
- **Location**: `00_principles/docs/en/part1_principles/CH00_fundamental_principles/MP029_no_fake_data.qmd`

### New Principle Files to Create

**File 1**: `MP135_data_temporal_scope.qmd`
- **Location**: `00_principles/docs/en/part1_principles/CH00_fundamental_principles/04_data_management/`
- **Content**: Full MP135 specification from Section 4.1

**File 2**: `UI_R022_component_temporal_filter_contract.qmd`
- **Location**: `00_principles/docs/en/part1_principles/CH03_ui_ux_principles/rules/`
- **Content**: Full UI_R022 specification from Section 4.2

**File 3**: `UI_R023_filter_state_documentation.qmd`
- **Location**: `00_principles/docs/en/part1_principles/CH03_ui_ux_principles/rules/`
- **Content**: Full UI_R023 specification from Section 4.3

### INDEX.md Updates

**Update**: `00_principles/INDEX.md`

Add to Meta-Principles section:
```markdown
### Data Management
- **MP135**: Data Temporal Scope Principle - All time-varying components must provide date range filtering
```

Add to UI/UX Rules section:
```markdown
### Component Architecture
- **UI_R022**: Component Temporal Filter Contract - Standard filter interface for all components
- **UI_R023**: Filter State Documentation Principle - Visual communication of active filters
```

---

## 13. CONCLUSION & RECOMMENDATION SUMMARY

### Executive Summary

**Critical Gap Identified**: All Poisson analysis components lack date range filtering, preventing period-specific analysis.

**Strategic Recommendation**: **IMPLEMENT GLOBAL DATE RANGE FILTERING (Option A)**

**Key Reasons**:
1. Aligns with existing macroTrend pattern (proven UX)
2. Follows MAMBA MP052 (Unidirectional Data Flow) principle
3. Faster implementation (2-3 weeks vs 5-7 weeks)
4. Better user experience (single filter, consistent period)

**Implementation Approach**:
- Week 1: Quick fix (UI only, transparency about limitation)
- Week 2: ETL parameterization (enable date-filtered analysis)
- Week 3: Component integration (wire up end-to-end)
- Week 4: Validation and Priority 2 audit

**Expected Outcomes**:
- Users can select analysis periods (30d, 90d, 365d, custom, all time)
- Consistent temporal scope across all analytical components
- 3 new MAMBA principles prevent future similar issues
- Foundation for advanced temporal features (period comparison, trending)

**Risk Level**: MEDIUM (mitigated through caching, staged rollout)

**Go/No-Go**: **STRONG GO** - High user impact, manageable technical complexity

---

**Document Prepared By**: Principle Product Manager
**Review Required**: Product Owner, Engineering Lead, Data Team Lead
**Approval Required For**: Implementation start, principle adoption
**Next Review Date**: After Week 1 Quick Fix deployment

---

*This document serves as both strategic product decision and architectural design record for the MAMBA temporal filtering initiative.*
