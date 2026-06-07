# Implementation Guide: Type B Analytics (2-Day Plan)

**Target Audience**: Developers implementing steady-state analytics (Poisson, positioning, etc.)
**Estimated Time**: 2 days (vs 4 weeks for Type A)
**Complexity**: Low (simplified workflow)

---

## Prerequisites

Before starting:
- [ ] Read MP135: Analytics Temporal Classification Principle
- [ ] Confirm component is Type B using decision tree
- [ ] Have access to complete historical dataset
- [ ] Understand statistical model being implemented

---

## Day 1: DRV Script Implementation (8 hours)

### Hour 1-2: Setup and Data Loading

```r
# File: scripts/update_scripts/DRV/your_component/D01_component_analysis.R

# Standard header
# Following MP135: Type B (Steady-State) Analytics
# Purpose: Compute [component name] using all historical data
# Update Frequency: Weekly (every Sunday at 02:00)

# Load dependencies
library(dplyr)
library(DBI)
source("scripts/global_scripts/01_db/fn_initialize_app_database.R")
source("scripts/global_scripts/04_utils/fn_write_df_to_database.R")

# Initialize database connection
con <- fn_initialize_app_database()

# Load ALL historical data (no date filtering!)
raw_data <- tbl(con, "source_table_name") %>%
  collect()

# Validate data
stopifnot(nrow(raw_data) > 0)
cat(sprintf("Loaded %d rows of historical data\n", nrow(raw_data)))
```

**Key Point**: NO `filter(date >= ...)` - Type B uses ALL data!

### Hour 3-5: Analysis Computation

```r
# Perform your analysis
# Examples:
# - Poisson regression
# - Market positioning (MDS, PCA)
# - Cluster analysis (DNA segments)
# - Conjoint analysis (attribute importance)

# Example: Poisson Regression
results <- raw_data %>%
  # Prepare data
  mutate(
    log_sales = log(sales_amount + 1),
    # Add any transformations
  ) %>%
  # Fit model
  glm(sales_count ~ predictor1 + predictor2 + predictor3,
      family = poisson(link = "log"),
      data = .)

# Extract coefficients
coefficients_df <- broom::tidy(results) %>%
  mutate(
    # Add interpretable metrics
    track_multiplier = exp(estimate * attribute_range) - 1,
    effect_size = abs(estimate),
    # Add significance flags
    significant = p.value < 0.05,
    significance_level = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE ~ ""
    )
  ) %>%
  select(
    predictor = term,
    coefficient = estimate,
    std_error,
    p_value = p.value,
    track_multiplier,
    effect_size,
    significant,
    significance_level
  )

cat(sprintf("Computed %d coefficients\n", nrow(coefficients_df)))
```

### Hour 6-7: Add Type B Metadata (CRITICAL!)

```r
# REQUIRED: Add Type B metadata columns
coefficients_df <- coefficients_df %>%
  mutate(
    # Core metadata (REQUIRED)
    computed_at = Sys.time(),
    data_version = max(raw_data$date_column, na.rm = TRUE),
    sample_size = nrow(raw_data),

    # Optional metadata (RECOMMENDED)
    model_version = "v1.0.0",  # Your DRV script version
    computation_time = elapsed_time,  # Track how long analysis took
    data_quality_flag = "OK"  # Or "PARTIAL" if data issues
  )

# Validate metadata
stopifnot(!any(is.na(coefficients_df$computed_at)))
stopifnot(!any(is.na(coefficients_df$data_version)))
stopifnot(all(coefficients_df$sample_size > 0))

cat("Metadata added successfully\n")
print(coefficients_df %>% select(predictor, computed_at, data_version, sample_size) %>% head())
```

**Why Metadata Matters**: UI components use this to show users data freshness and reliability.

### Hour 8: Save to Database (Simple Overwrite)

```r
# Type B pattern: Simple overwrite (no period keys!)
table_name <- "df_component_results"  # Following R119: df_ prefix

# Write to database (overwrite existing)
fn_write_df_to_database(
  con = con,
  df = coefficients_df,
  table_name = table_name,
  overwrite = TRUE,  # Simple overwrite for Type B
  schema = "public"
)

cat(sprintf("Results written to %s\n", table_name))
cat(sprintf("Rows: %d\n", nrow(coefficients_df)))

# Verify write
verification <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM %s", table_name))
cat(sprintf("Verification: %d rows in database\n", verification$n))

# Close connection
dbDisconnect(con)
cat("DRV script completed successfully\n")
```

**Key Simplification**: No period loops, no period-based deletion, just overwrite!

### Day 1 Checklist

- [ ] Data loaded (all historical data, no filtering)
- [ ] Analysis computed (regression, positioning, clustering, etc.)
- [ ] Metadata added (computed_at, data_version, sample_size)
- [ ] Results saved to database (simple overwrite)
- [ ] Verification passed (row count correct)
- [ ] Script runs end-to-end without errors

---

## Day 2: UI Metadata Display (8 hours)

### Hour 1-2: Load Data in Component Server

```r
# File: scripts/global_scripts/10_rshinyapp_components/your_component/yourComponent.R

# In component server
yourComponentServer <- function(id, app_data_connection) {
  moduleServer(id, function(input, output, session) {

    # Load Type B data
    analysis_data <- reactive({
      # Use universal data accessor (R091 pattern)
      data <- universal_data_accessor(
        data_connection = app_data_connection,
        data_name = "df_component_results",  # Your table name
        log_level = 3
      )

      # Validate Type B metadata exists
      req(data)
      req(!is.null(data$computed_at))
      req(!is.null(data$data_version))
      req(!is.null(data$sample_size))

      return(data)
    })

    # Extract metadata (typically from first row or separate metadata table)
    metadata <- reactive({
      data <- analysis_data()
      req(data)

      list(
        computed_at = data$computed_at[1],
        data_version = data$data_version[1],
        sample_size = data$sample_size[1],
        model_version = data$model_version[1] %||% "Unknown"
      )
    })

    # ... rest of component logic
  })
}
```

### Hour 3-5: Create Metadata Banner UI

```r
# In component server (continued)

# Render Type B metadata banner (following UI_R024)
output$metadata_banner <- renderUI({
  meta <- metadata()
  req(meta)

  # Calculate staleness
  staleness_days <- as.numeric(difftime(Sys.time(), meta$data_version, units = "days"))
  show_warning <- staleness_days > 30  # Configurable threshold

  # Render metadata banner
  div(
    class = "metadata-banner steady-state-metadata",
    style = "padding: 10px 15px; background-color: #e8f4f8; border-left: 4px solid #17a2b8; border-radius: 4px; margin-bottom: 15px;",

    # Row 1: Data foundation
    div(
      style = "display: flex; align-items: center; margin-bottom: 5px;",
      icon("database", style = "margin-right: 8px; color: #17a2b8;"),
      span(style = "font-weight: 600;", "基於全部歷史數據"),
      span(
        style = "margin-left: 10px; color: #6c757d;",
        sprintf("(%s 筆觀察值)", format(meta$sample_size, big.mark = ","))
      )
    ),

    # Row 2: Temporal metadata
    div(
      style = "display: flex; align-items: center; font-size: 0.9em; color: #6c757d;",
      icon("clock", style = "margin-right: 8px;"),
      span(sprintf("計算時間: %s", format(meta$computed_at, "%Y-%m-%d %H:%M"))),
      span(style = "margin: 0 10px;", "|"),
      span(sprintf("數據截至: %s", format(meta$data_version, "%Y-%m-%d"))),

      # Staleness warning (conditional)
      if (show_warning) {
        span(
          style = "margin-left: 10px; color: #ffc107; font-weight: 600;",
          icon("exclamation-triangle"),
          sprintf(" 數據已 %d 天未更新", floor(staleness_days))
        )
      } else {
        NULL
      }
    )
  )
})
```

### Hour 6: Add Metadata to Component UI

```r
# In component UI
yourComponentUI <- function(id) {
  ns <- NS(id)

  div(
    # Component title
    h3("Your Component Name"),

    # REQUIRED: Metadata banner (Type B components MUST have this)
    uiOutput(ns("metadata_banner")),

    # Main content
    plotlyOutput(ns("main_plot")),
    DT::dataTableOutput(ns("data_table"))
  )
}
```

### Hour 7: Test Metadata Display

```r
# Test script: scripts/global_scripts/10_rshinyapp_components/your_component/test_metadata.R

library(shiny)
library(testthat)

# Mock data with metadata
test_data <- data.frame(
  predictor = c("fast_delivery", "product_quality"),
  coefficient = c(0.23, 0.18),
  computed_at = as.POSIXct("2025-11-13 08:30:00"),
  data_version = as.Date("2025-11-12"),
  sample_size = 10234
)

# Create test app
test_app <- function() {
  ui <- fluidPage(
    yourComponentUI("test")
  )

  server <- function(input, output, session) {
    # Mock connection returning test data
    mock_connection <- list(
      df_component_results = test_data
    )

    yourComponentServer("test", mock_connection)
  }

  shinyApp(ui, server)
}

# Run test app
runApp(test_app(), port = 8765)

# Visual checks:
# [ ] Metadata banner renders correctly
# [ ] "基於全部歷史數據 (10,234 筆觀察值)" displays
# [ ] Computed at timestamp displays
# [ ] Data version date displays
# [ ] No period selector present (Type B should NOT have one!)
```

### Hour 8: Documentation

```r
# Add to component file header

#' @title Your Component Name
#' @description Type B (Steady-State) Analytics Component
#'
#' @principle MP135: Analytics Temporal Classification - Type B
#' @principle UI_R024: Metadata Display for Steady-State Analytics
#'
#' @classification Type B (Steady-State)
#' @reasoning Coefficients/results represent stable population parameters
#'            requiring maximum sample size. Period-to-period variation
#'            would be sampling noise, not genuine temporal change.
#'
#' @update_frequency Weekly (every Sunday at 02:00)
#' @sample_size_target 10,000+ observations for reliable estimates
#'
#' @metadata_fields
#'   - computed_at: When analysis was last run
#'   - data_version: Latest data included in analysis (date)
#'   - sample_size: Number of observations used
#'   - model_version: DRV script version
#'
#' @notes
#'   - NO period selector (Type B components never have periods)
#'   - Uses ALL historical data (no date filtering)
#'   - Staleness warning if data > 30 days old
```

### Day 2 Checklist

- [ ] Metadata reactive created (extracts computed_at, data_version, sample_size)
- [ ] Metadata banner UI implemented (following UI_R024 pattern)
- [ ] Metadata banner added to component UI (above main content)
- [ ] Staleness calculation implemented (warning if > 30 days)
- [ ] Component tested (metadata displays correctly)
- [ ] NO period selector present (verified Type B compliance)
- [ ] Documentation updated (classification, reasoning, metadata fields)

---

## Comparison: Type A vs Type B Implementation

### Type A (Time-Varying) - 4 Weeks

**Week 1**: ETL enhancements for period filtering
- Modify ETL scripts to preserve date range metadata
- Add period calculation functions
- Test date range filtering logic

**Week 2**: DRV period loops
```r
for (period in c("all_time", "30d", "90d", "180d", "365d")) {
  data_filtered <- filter_data_by_period(data, period)
  results <- compute_analysis(data_filtered)
  results$period <- period
  save_with_period_key(results, period)
}
```
- Implement deduplication logic (delete old period data before insert)
- Test all period variants
- Validate period metadata

**Week 3**: Period selector UI
```r
selectInput("period", "Time Period:",
            choices = c("All Time" = "all_time",
                        "30 Days" = "30d",
                        "90 Days" = "90d",
                        "180 Days" = "180d",
                        "365 Days" = "365d"))

filtered_data <- reactive({
  req(input$period)
  data %>% filter(period == input$period)
})
```

**Week 4**: Testing and documentation
- Test all period variants
- Validate period selector behavior
- Performance testing (5× data volume)
- Documentation

**Total**: 160 hours (4 weeks × 40 hours)

### Type B (Steady-State) - 2 Days

**Day 1**: DRV simple pattern (8 hours)
```r
# No period loops!
all_data <- load_all_historical_data()
results <- compute_analysis(all_data)

# Add metadata
results$computed_at <- Sys.time()
results$data_version <- max(all_data$date_column)
results$sample_size <- nrow(all_data)

# Simple overwrite
dbWriteTable(conn, table_name, results, overwrite = TRUE)
```

**Day 2**: Metadata display (8 hours)
```r
# No period selector!
div(class = "metadata-banner",
    "基於全部歷史數據",
    sprintf("(%s 筆觀察值)", format(sample_size, big.mark = ",")),
    sprintf("計算時間: %s", computed_at))
```

**Total**: 16 hours (2 days × 8 hours)

**Time Savings**: 144 hours (90% reduction)

---

## Common Pitfalls and Solutions

### Pitfall 1: Accidentally Adding Period Logic

**Mistake**:
```r
# DON'T DO THIS for Type B!
for (period in c("all_time", "30d", "90d")) {
  # ...
}
```

**Correct**:
```r
# Type B: NO period loops
all_data <- load_all_historical_data()  # That's it!
results <- compute_analysis(all_data)
```

### Pitfall 2: Forgetting Metadata

**Mistake**:
```r
# Missing metadata!
results <- compute_analysis(all_data)
dbWriteTable(conn, table_name, results)
```

**Correct**:
```r
# ALWAYS add metadata for Type B
results$computed_at <- Sys.time()
results$data_version <- max(all_data$date_column)
results$sample_size <- nrow(all_data)
dbWriteTable(conn, table_name, results)
```

### Pitfall 3: Adding Period Selector to Type B

**Mistake**:
```r
# Type B should NOT have this!
selectInput(ns("period"), "Time Period:", ...)
```

**Correct**:
```r
# Type B: Metadata banner, NO period selector
uiOutput(ns("metadata_banner"))
```

### Pitfall 4: Not Validating Metadata in UI

**Mistake**:
```r
# Assuming metadata exists without validation
computed_at <- data$computed_at[1]  # Might be NULL!
```

**Correct**:
```r
# Validate metadata fields
analysis_data <- reactive({
  data <- load_data(...)
  req(data)
  req(!is.null(data$computed_at))
  req(!is.null(data$data_version))
  req(!is.null(data$sample_size))
  return(data)
})
```

---

## Testing Checklist

### Functional Tests

- [ ] DRV script runs without errors
- [ ] Results table created/updated successfully
- [ ] Metadata fields populated correctly (computed_at, data_version, sample_size)
- [ ] Sample size matches expected row count
- [ ] Data version matches latest date in source data

### UI Tests

- [ ] Component loads without errors
- [ ] Metadata banner displays correctly
- [ ] All metadata fields visible (computed_at, data_version, sample_size)
- [ ] Staleness warning appears when data > 30 days old
- [ ] NO period selector present
- [ ] Main content (plots, tables) render correctly

### Integration Tests

- [ ] Component works with real database connection
- [ ] Metadata updates when DRV re-runs
- [ ] Staleness warning updates dynamically
- [ ] Component handles missing metadata gracefully (doesn't crash)

### Performance Tests

- [ ] DRV completes in reasonable time (< 10 minutes for 100k rows)
- [ ] UI loads metadata quickly (< 1 second)
- [ ] No unnecessary data reloading

---

## Success Criteria

### Definition of Done

- [x] DRV script computes analysis using all historical data (no period filtering)
- [x] Metadata fields added to results (computed_at, data_version, sample_size)
- [x] Results saved to database with simple overwrite
- [x] UI component loads and displays metadata banner
- [x] NO period selector present in UI
- [x] Staleness warning functional (if data > threshold)
- [x] Documentation updated (classification reasoning, metadata fields)
- [x] All tests pass (functional, UI, integration)

### Quality Gates

- [ ] **Statistical Validity**: Sample size > 1,000 for reliable estimates
- [ ] **Code Quality**: Follows MAMBA coding standards (R091, MP047, etc.)
- [ ] **UI/UX**: Metadata banner follows UI_R024 standard pattern
- [ ] **Documentation**: Clear classification reasoning documented
- [ ] **Performance**: DRV runs < 10 minutes, UI loads < 2 seconds

---

## Deployment

### Scheduling DRV Script

```bash
# Add to cron (weekly updates for Type B)
# Every Sunday at 02:00 AM
0 2 * * 0 Rscript /path/to/your/D01_component_analysis.R >> /path/to/logs/component.log 2>&1
```

**Why Weekly?**: Type B results are stable, don't need daily updates. Weekly strikes balance between freshness and computational efficiency.

### Monitoring

```r
# Add to DRV script
# Log execution metrics
log_entry <- data.frame(
  script_name = "D01_component_analysis",
  execution_time = Sys.time(),
  rows_processed = nrow(raw_data),
  rows_output = nrow(results),
  duration_seconds = elapsed_time,
  status = "SUCCESS"
)

# Write to monitoring table
dbWriteTable(con, "drv_execution_log", log_entry, append = TRUE)
```

### Alerting

```r
# Alert if data becomes stale (> 45 days old for Type B)
if (staleness_days > 45) {
  send_alert(
    to = "data-team@company.com",
    subject = "Type B Analytics Data Stale",
    message = sprintf("Component %s has data %d days old. Last update: %s",
                      component_name, staleness_days, data_version)
  )
}
```

---

## Resources

### Documentation

- **MP135**: Analytics Temporal Classification Principle (full framework)
- **UI_R024**: Metadata Display for Steady-State Analytics (UI patterns)
- **ADR-003**: Architecture Decision Record (rationale and case studies)

### Code Examples

- **Reference Implementation**: `poissonFeatureAnalysis.R` (Type B exemplar)
- **DRV Template**: `scripts/update_scripts/DRV/TEMPLATE_type_b.R`
- **UI Template**: `scripts/global_scripts/10_rshinyapp_components/TEMPLATE_type_b.R`

### Support

- **Questions**: Check principle documents first, then ask in #mamba-dev channel
- **Code Review**: Ensure classification and metadata are reviewed
- **Issues**: Report in ISSUE_TRACKER with "Type B" label

---

## Summary

**Type B Implementation is SIMPLE**:

**Day 1**: Load all data, compute analysis, add metadata, overwrite table
**Day 2**: Display metadata banner, test, document

**Key Simplifications**:
- ❌ NO period loops
- ❌ NO period selector
- ❌ NO complex deduplication
- ✅ Simple all-time computation
- ✅ Simple overwrite
- ✅ Simple metadata display

**Time Savings**: 90% (4 weeks → 2 days)

**Quality Improvement**: Better statistical reliability (larger samples)

**UX Improvement**: Clearer, more trustworthy displays

---

*Follow this guide for all Type B (Steady-State) analytics implementations.*
