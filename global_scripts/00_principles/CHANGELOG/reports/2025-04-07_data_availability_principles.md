---
id: "R-DA-PRINCIPLES"
title: "Data Availability Principles Creation"
type: "record"
date_created: "2025-04-07"
date_modified: "2025-04-07"
author: "Claude"
related_to:
  - "MP45": "Automatic Data Availability Detection"
  - "P70": "Complete Input Display"
---

# Data Availability Principles Creation

## Summary

This record documents the creation of two complementary principles related to data availability in user interfaces:

1. MP45: Automatic Data Availability Detection Metaprinciple
2. P70: Complete Input Display Principle

These principles address a core issue in data-driven applications: how to handle and communicate data availability to users in a transparent and consistent way.

## Background

During the implementation of the MAMBA application, an issue arose regarding the display of marketing channels in the sidebar filter when data for certain channels was unavailable. The traditional approach would be to manually configure which channels are available in the configuration file, but this creates a disconnect between the actual data state and the UI display.

Additionally, removing unavailable options from selection controls creates a disorienting experience for users as options appear and disappear based on data state.

## Rationale

The principles were created to address these fundamental issues:

1. **Truth in Presentation**: Ensuring the UI accurately reflects the actual data state
2. **Consistent Experience**: Providing a stable mental model for users
3. **Manual Configuration Elimination**: Removing the need to manually specify data availability
4. **Transparent Limitations**: Clearly communicating system constraints

## Principles Created

### MP45: Automatic Data Availability Detection

This metaprinciple establishes that data availability should be automatically detected at runtime rather than manually configured. Key components include:

1. **Runtime Inspection**: Systems must inspect data to determine availability
2. **Centralized Registry**: A central availability registry tracks data state
3. **Reactive Updates**: Changes in data state automatically propagate to UI
4. **Self-Discovery**: Components determine their own data dependencies

This creates a system that "knows what it knows" and can adapt dynamically to changes in data availability.

### P70: Complete Input Display

This principle establishes that input controls should display all possible options regardless of data availability. Key components include:

1. **Display All Options**: Show the complete set of possible options
2. **Visual Indicators**: Use styling to communicate availability state
3. **Disabled State**: Prevent selection of unavailable options while keeping them visible
4. **Automatic Selection Adjustment**: Select available options when current selection becomes unavailable

This creates a consistent UI that doesn't change structure based on data state, instead using visual cues to communicate availability.

## Implementation Aspects

### Centralized Availability Detection

The implementation includes central functions to detect data availability:

```r
detectMarketingChannelAvailability <- function() {
  # Define all potential marketing channels
  channels <- c("amazon", "officialwebsite", "retail", "wholesale")
  availability <- list()
  
  # Check each channel for data availability by querying the database
  for (channel in channels) {
    tryCatch({
      query <- paste0("SELECT COUNT(*) as count FROM sales WHERE channel = '", channel, "'")
      result <- DBI::dbGetQuery(app_data_conn, query)
      availability[[channel]] <- result$count[1] > 0
    }, error = function(e) {
      availability[[channel]] <- FALSE
    })
  }
  
  return(availability)
}
```

### Reactive UI Controls

The UI implementation uses reactive controls that adapt to availability:

```r
renderAdaptiveControl <- function(input_id, label, domain, values, registry) {
  renderUI({
    # Check availability of each value
    available_values <- list()
    disabled_states <- list()
    
    for (name in names(values)) {
      value <- values[[name]]
      is_available <- isAvailable(registry, domain, value)
      available_values[[name]] <- value
      disabled_states[[value]] <- !is_available
    }
    
    # Render with availability indicators
    radioButtons(
      input_id,
      label,
      choices = available_values,
      selected = getFirstAvailable(available_values, disabled_states),
      choiceNames = lapply(names(available_values), function(name) {
        value <- available_values[[name]]
        if (disabled_states[[value]]) {
          div(
            style = "color: #aaa; cursor: not-allowed;",
            paste0(name, " (No Data)")
          )
        } else {
          name
        }
      }),
      choiceValues = unname(available_values)
    )
  })
}
```

## Benefits and Impact

The adoption of these principles is expected to bring significant benefits:

1. **Reduced Configuration**: Eliminates manual configuration of data availability
2. **System Resilience**: Application adapts automatically to data state changes
3. **Consistent UX**: Users experience a stable interface structure
4. **Transparent Operation**: System clearly communicates its own data limitations
5. **Self-Healing**: Application recovers automatically when data becomes available

## Conclusion

The creation of MP45 (Automatic Data Availability Detection) and P70 (Complete Input Display) establishes a comprehensive approach to handling data availability in user interfaces. Together, these principles ensure that applications automatically adapt to the actual state of their data while maintaining a consistent and transparent experience for users.

This approach aligns with the broader principle framework by implementing MP12 (Company-Centered Design), MP17 (Separation of Concerns), and P22 (CSS Over Conditional Controls), creating a more robust and user-friendly approach to data-driven interfaces.