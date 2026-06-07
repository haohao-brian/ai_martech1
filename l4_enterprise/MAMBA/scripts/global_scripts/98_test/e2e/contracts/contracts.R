#####
# contracts.R — MP165 dashboard-presence contract primitive helpers
#
# Issue #599 / spectra change dashboard-presence-verification
#
# Two layers:
#   1. Pure helpers (testable without Shiny):
#      exclude_placeholder_rows / compare_value / format_contract_failure
#      check_datatable_meaningful_rows / check_filter_dropdown_choices
#      check_plotly_has_data_points / check_chart_axis_non_empty
#      check_kpi_card_value / validate_contract_yaml
#
#   2. Shinytest2 wrappers (require AppDriver):
#      assert_kpi_card_value / assert_datatable_meaningful_rows
#      assert_plotly_has_data_points / assert_filter_dropdown_choices
#      assert_chart_axis_non_empty
#
# Hard fail discipline (MP165): no soft_warn_mode toggle. Severity is
# per-contract (critical | warning); Tier 2 deploy gate respects
# severity, Tier 1 DRV-end lite ignores severity (only checks NULL
# outputs).
#####

# Default placeholder brand / product names that are not real data points
# (used by exclude_placeholder_rows for DataTable row filtering)
.MP165_DEFAULT_PLACEHOLDERS <- c("Ideal", "Rating", "Revenue")

# Default forbidden error patterns indicating broken render visible to user
# (used by check_no_error_text + check_kpi_no_error_placeholder)
# Refs: issue #653 F1-F3 InsightForge `Error: [object Object]` defects
.MP165_DEFAULT_ERROR_PATTERNS <- c(
  "Error:",            # Shiny renders stop() as 'Error: ...'
  "[object Object]",   # JS object-as-string serialization leak
  "<NA>",              # R NA cast to character
  "NaN",               # Failed numeric computation displayed
  "undefined",         # JS undefined leak
  "null"               # JS null leak as text
)

# Default allowed English phrases in UI (DT controls, modal buttons) that
# should NOT trip hardcoded-English detection. Used by
# check_no_hardcoded_english as whitelist.
.MP165_DEFAULT_ALLOWED_ENGLISH <- c(
  "Show", "Search", "Previous", "Next",       # DT pagination controls
  "Page", "Loading", "Processing",             # DT state labels
  "Filter", "All", "None",                     # Common control labels
  "OK", "Cancel", "Close", "Apply", "Reset"    # Modal buttons
)


# =============================================================================
# Pure helpers (testable without Shiny)
# =============================================================================

#' Exclude placeholder rows from a data frame
#'
#' Removes rows whose `brand_col` value matches a placeholder (Ideal, Rating,
#' Revenue by default). Returns the filtered data frame unchanged when the
#' brand column is missing.
#'
#' @param data data.frame to filter
#' @param brand_col Column name that may contain placeholder labels
#' @param placeholders Character vector of placeholder values to exclude
#' @return Filtered data.frame
exclude_placeholder_rows <- function(data,
                                     brand_col = "brand",
                                     placeholders = .MP165_DEFAULT_PLACEHOLDERS) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) return(data)
  if (!brand_col %in% colnames(data)) return(data)
  keep <- !(data[[brand_col]] %in% placeholders)
  data[keep, , drop = FALSE]
}


#' Compare an observed value against a threshold using a string operator
#'
#' Supports `>=`, `>`, `==`, `<=`, `<`. NA observed value is treated as
#' failure (cannot satisfy any positive comparison).
compare_value <- function(observed, op, threshold) {
  if (is.null(observed) || (length(observed) == 1 && is.na(observed))) {
    return(FALSE)
  }
  switch(op,
    ">="  = observed >= threshold,
    ">"   = observed > threshold,
    "=="  = observed == threshold,
    "<="  = observed <= threshold,
    "<"   = observed < threshold,
    stop("Unsupported comparison operator: '", op, "'. Allowed: >=, >, ==, <=, <")
  )
}


#' Format a contract failure message with selector / expected / observed / severity
format_contract_failure <- function(selector, expected, observed, severity = "critical") {
  sprintf(
    "[MP165 %s] %s: expected %s; got %s",
    toupper(severity), selector, expected, observed
  )
}


#' Parse a KPI card value into numeric, handling formatted strings
#'
#' Accepts strings like "8,206,169" (commas), "$43" (currency prefix),
#' "77.3%" (percent suffix), and bare numerics. Returns NA for non-parseable
#' content like "-" or "loading...".
.parse_kpi_value <- function(value) {
  if (is.null(value)) return(NA_real_)
  if (length(value) != 1) return(NA_real_)
  if (is.numeric(value)) return(as.numeric(value))
  if (!is.character(value) && !is.factor(value)) return(NA_real_)

  s <- as.character(value)
  if (is.na(s) || !nzchar(s)) return(NA_real_)

  # Strip common formatting: commas, currency symbols, percent sign
  cleaned <- gsub("[,\\$£€¥%]", "", s, perl = TRUE)
  cleaned <- trimws(cleaned)

  # Reject obvious non-numeric placeholders
  if (cleaned %in% c("-", "--", "N/A", "NA", "loading...", "Loading...")) {
    return(NA_real_)
  }

  num <- suppressWarnings(as.numeric(cleaned))
  num
}


#' Check KPI card value passes comparison
check_kpi_card_value <- function(value, op, threshold) {
  parsed <- .parse_kpi_value(value)
  pass <- compare_value(parsed, op, threshold)
  list(
    pass = isTRUE(pass),
    observed = parsed,
    expected = paste("KPI", op, threshold),
    message = if (!isTRUE(pass)) {
      sprintf("KPI value '%s' (parsed as %s) does not satisfy %s %s",
              as.character(value)[1], parsed, op, threshold)
    } else NULL
  )
}


#' Check DataTable has meaningful rows after excluding placeholders
check_datatable_meaningful_rows <- function(data,
                                            min_rows,
                                            exclude_placeholders = TRUE,
                                            brand_col = "brand",
                                            placeholders = .MP165_DEFAULT_PLACEHOLDERS) {
  if (is.null(data) || !is.data.frame(data)) {
    return(list(
      pass = FALSE,
      observed = 0L,
      expected = paste0("rows >= ", min_rows),
      message = "DataTable is NULL or not a data.frame"
    ))
  }

  total_rows <- nrow(data)
  if (exclude_placeholders) {
    filtered <- exclude_placeholder_rows(data, brand_col = brand_col,
                                         placeholders = placeholders)
    meaningful <- nrow(filtered)
    excluded <- total_rows - meaningful
  } else {
    meaningful <- total_rows
    excluded <- 0L
  }

  pass <- meaningful >= min_rows
  list(
    pass = pass,
    observed = as.integer(meaningful),
    expected = paste0("rows >= ", min_rows,
                      if (exclude_placeholders) " (excluding placeholders)" else ""),
    message = if (!pass) {
      sprintf("DataTable has %d meaningful row(s) (%d placeholder(s) excluded from %d total) < threshold %d",
              meaningful, excluded, total_rows, min_rows)
    } else NULL
  )
}


#' Check filter dropdown has enough non-empty choices
check_filter_dropdown_choices <- function(choices, min_choices) {
  if (is.null(choices)) {
    return(list(
      pass = FALSE,
      observed = 0L,
      expected = paste0("choices >= ", min_choices),
      message = "Filter dropdown has NULL choices"
    ))
  }

  # Selectize choices may be c(label = "value") form or plain character vector.
  values <- unname(as.character(choices))
  non_empty <- values[nzchar(values) & !is.na(values)]

  pass <- length(non_empty) >= min_choices
  list(
    pass = pass,
    observed = length(non_empty),
    expected = paste0("choices >= ", min_choices),
    message = if (!pass) {
      sprintf("Filter dropdown has %d non-empty choice(s) < threshold %d",
              length(non_empty), min_choices)
    } else NULL
  )
}


#' Check Plotly chart has data points across at least min_traces traces
check_plotly_has_data_points <- function(traces, min_traces = 1) {
  if (is.null(traces) || !is.list(traces) || length(traces) == 0) {
    return(list(
      pass = FALSE,
      observed = 0L,
      expected = paste0("non-empty traces >= ", min_traces),
      message = "Plotly traces list is NULL or empty"
    ))
  }

  trace_has_data <- vapply(traces, function(tr) {
    if (is.null(tr) || !is.list(tr)) return(FALSE)
    x <- tr$x
    y <- tr$y
    if (is.null(x) || is.null(y)) return(FALSE)
    x_valid <- length(x) > 0 && !all(is.na(x))
    y_valid <- length(y) > 0 && !all(is.na(y))
    x_valid && y_valid
  }, logical(1))

  non_empty <- sum(trace_has_data)
  pass <- non_empty >= min_traces
  list(
    pass = pass,
    observed = as.integer(non_empty),
    expected = paste0("non-empty traces >= ", min_traces),
    message = if (!pass) {
      sprintf("Plotly chart has %d non-empty trace(s) < threshold %d",
              non_empty, min_traces)
    } else NULL
  )
}


#' Check chart axis has non-empty tick labels
check_chart_axis_non_empty <- function(tick_labels) {
  if (is.null(tick_labels)) {
    return(list(
      pass = FALSE,
      observed = 0L,
      expected = "axis ticks present",
      message = "Chart axis tick labels are NULL"
    ))
  }
  non_empty <- tick_labels[nzchar(tick_labels) & !is.na(tick_labels)]
  pass <- length(non_empty) > 0
  list(
    pass = pass,
    observed = length(non_empty),
    expected = "axis ticks present",
    message = if (!pass) {
      "Chart axis has no non-empty tick labels"
    } else NULL
  )
}


#' Check text for forbidden error patterns
#'
#' Detects user-visible error strings indicating broken render: 'Error:',
#' '[object Object]', '<NA>', 'NaN', 'undefined', 'null'. Returns
#' pass=FALSE when any pattern is matched (fixed-string, case-sensitive).
#'
#' Refs: issue #653 F1-F3 InsightForge `Error: [object Object]` evidence
#'
#' @param text Character vector or single string to scan
#' @param patterns Character vector of forbidden fixed-string patterns
#' @return list(pass, observed, expected, matched_patterns, message)
check_no_error_text <- function(text, patterns = .MP165_DEFAULT_ERROR_PATTERNS) {
  if (is.null(text)) {
    return(list(
      pass = TRUE, observed = "(no text)",
      expected = "no error patterns",
      matched_patterns = character(0), message = NULL
    ))
  }
  s <- as.character(text)
  s <- s[!is.na(s) & nzchar(s)]
  if (length(s) == 0) {
    return(list(
      pass = TRUE, observed = "(empty text)",
      expected = "no error patterns",
      matched_patterns = character(0), message = NULL
    ))
  }
  combined <- paste(s, collapse = " ")
  matched <- Filter(function(p) grepl(p, combined, fixed = TRUE), patterns)
  pass <- length(matched) == 0L
  list(
    pass = pass,
    observed = if (pass) "(no error patterns found)" else paste0("matched: ", paste(matched, collapse = ", ")),
    expected = paste0("no patterns matching: ", paste(patterns, collapse = " / ")),
    matched_patterns = matched,
    message = if (!pass) {
      sprintf("Text contains forbidden error pattern(s): %s", paste(matched, collapse = ", "))
    } else NULL
  )
}


#' Check text for hardcoded English where translate() expected
#'
#' Heuristic: extracts TitleCase or ALL-CAPS phrases of 4+ ASCII letter chars
#' (and multi-word phrases of same shape). Phrases NOT in `allowed_phrases`
#' whitelist are reported as i18n regressions. Conservative — lowercase
#' words, short labels (< 4 chars), and numerics are ignored to reduce false
#' positives on legitimate UI text.
#'
#' Refs: issue #653 F4-F5 BrandEdge KFE/IdealRate hardcoded English titles
#'
#' @param text Character vector or single string to scan
#' @param allowed_phrases Whitelist of OK English phrases (DT controls etc.)
#' @return list(pass, observed, expected, found_phrases, message)
check_no_hardcoded_english <- function(text,
                                       allowed_phrases = .MP165_DEFAULT_ALLOWED_ENGLISH) {
  if (is.null(text)) {
    return(list(
      pass = TRUE, observed = "(no text)",
      expected = "no hardcoded English",
      found_phrases = character(0), message = NULL
    ))
  }
  s <- as.character(text)
  s <- s[!is.na(s) & nzchar(s)]
  if (length(s) == 0) {
    return(list(
      pass = TRUE, observed = "(empty text)",
      expected = "no hardcoded English",
      found_phrases = character(0), message = NULL
    ))
  }
  combined <- paste(s, collapse = " ")

  # Match TitleCase phrases of 4+ ASCII letters, optionally followed by more
  # capitalized words separated by space or hyphen.
  pattern <- "\\b[A-Z][a-zA-Z]{3,}(?:[\\- ][A-Z][a-zA-Z]{2,})*\\b"
  matches <- regmatches(combined, gregexpr(pattern, combined, perl = TRUE))[[1]]

  # Also tokenize individual words from multi-word phrases to filter via whitelist
  expand_words <- function(phrase) unlist(strsplit(phrase, "[ \\-]", perl = TRUE))
  all_words <- unique(unlist(lapply(matches, expand_words)))

  # A phrase is flagged if NEITHER the full phrase NOR all its words are in whitelist
  flagged <- Filter(function(m) {
    full_in_list <- m %in% allowed_phrases
    words <- expand_words(m)
    all_words_in_list <- all(words %in% allowed_phrases)
    !(full_in_list || all_words_in_list)
  }, matches)
  flagged <- unique(flagged)

  pass <- length(flagged) == 0L
  list(
    pass = pass,
    observed = if (pass) "(no hardcoded English found)" else paste0("found ", length(flagged), " phrase(s)"),
    expected = "no English phrases outside allowed_phrases whitelist",
    found_phrases = flagged,
    message = if (!pass) {
      sprintf("Hardcoded English detected (use translate()): %s",
              paste(utils::head(flagged, 5), collapse = ", "))
    } else NULL
  )
}


#' Check KPI text is not an error placeholder
#'
#' Stricter than .parse_kpi_value (which only returns NA on '-'/'Error:').
#' Explicitly fails on error patterns regardless of numeric threshold. Use
#' when you only need "value is present and not an error" rather than
#' "value satisfies >= N".
#'
#' Refs: issue #653 F1-F3 InsightForge KPI cards showing `Error: ...` / `--`
#'
#' @param text Character or numeric value from KPI card
#' @return list(pass, observed, expected, message)
check_kpi_no_error_placeholder <- function(text) {
  if (is.null(text)) {
    return(list(
      pass = FALSE, observed = "NULL",
      expected = "non-error KPI value", message = "KPI value is NULL"
    ))
  }
  s <- as.character(text)[1]
  if (is.na(s) || !nzchar(s)) {
    return(list(
      pass = FALSE, observed = paste0("'", s, "'"),
      expected = "non-error KPI value",
      message = "KPI value is empty or NA"
    ))
  }

  trimmed <- trimws(s)

  # Exact-match short placeholders ('-' / '--' / 'N/A')
  exact_placeholders <- c("-", "--", "N/A")
  exact_match <- trimmed %in% exact_placeholders

  # Substring match against error patterns + loading states
  substring_patterns <- c(.MP165_DEFAULT_ERROR_PATTERNS, "loading...", "Loading...")
  substring_matches <- Filter(function(p) grepl(p, trimmed, fixed = TRUE),
                              substring_patterns)

  matched <- unique(c(
    if (exact_match) trimmed else character(0),
    substring_matches
  ))

  pass <- length(matched) == 0L
  list(
    pass = pass,
    observed = paste0("'", s, "'"),
    expected = "non-error KPI value (no Error:/[object Object]/--/loading)",
    message = if (!pass) {
      sprintf("KPI value '%s' matches forbidden pattern(s): %s",
              s, paste(matched, collapse = ", "))
    } else NULL
  )
}


#' Validate contract YAML schema
#'
#' @param cfg list parsed from per-company contract YAML
#' @return list(valid = logical, errors = character)
validate_contract_yaml <- function(cfg) {
  errors <- character(0)

  if (is.null(cfg) || !is.list(cfg)) {
    return(list(valid = FALSE, errors = "Contract YAML must be a list"))
  }

  if (is.null(cfg$company) || !is.character(cfg$company) || !nzchar(cfg$company)) {
    errors <- c(errors, "Top-level 'company' field is required and must be non-empty")
  }

  if (is.null(cfg$modules) || !is.list(cfg$modules)) {
    errors <- c(errors, "Top-level 'modules' field is required and must be a mapping")
  } else {
    for (mod_name in names(cfg$modules)) {
      mod <- cfg$modules[[mod_name]]
      if (!is.list(mod)) {
        errors <- c(errors, sprintf("Module '%s' must be a mapping", mod_name))
        next
      }
      if (is.null(mod$enabled) || !is.logical(mod$enabled)) {
        errors <- c(errors,
                    sprintf("Module '%s'.enabled must be true or false", mod_name))
      }
      if (isTRUE(mod$enabled)) {
        if (is.null(mod$sub_tabs) || !is.list(mod$sub_tabs)) {
          errors <- c(errors,
                      sprintf("Module '%s'.sub_tabs must be a mapping when enabled=true", mod_name))
        } else {
          for (tab_id in names(mod$sub_tabs)) {
            tab <- mod$sub_tabs[[tab_id]]
            if (!is.list(tab)) {
              errors <- c(errors,
                          sprintf("Tab '%s.%s' must be a mapping", mod_name, tab_id))
              next
            }
            apl <- tab$active_product_lines
            if (is.null(apl) || (!is.character(apl) && !is.list(apl))) {
              errors <- c(errors,
                          sprintf("Tab '%s.%s'.active_product_lines must be character vector",
                                  mod_name, tab_id))
            }
            if (is.null(tab$contracts) || !is.list(tab$contracts)) {
              errors <- c(errors,
                          sprintf("Tab '%s.%s'.contracts must be a list", mod_name, tab_id))
            } else {
              for (i in seq_along(tab$contracts)) {
                ct <- tab$contracts[[i]]
                if (!is.list(ct)) {
                  errors <- c(errors,
                              sprintf("Tab '%s.%s'.contracts[%d] must be a mapping",
                                      mod_name, tab_id, i))
                  next
                }
                for (req in c("selector", "assertion", "severity")) {
                  if (is.null(ct[[req]]) || !nzchar(as.character(ct[[req]]))) {
                    errors <- c(errors,
                                sprintf("Tab '%s.%s'.contracts[%d].%s is required",
                                        mod_name, tab_id, i, req))
                  }
                }
                if (!is.null(ct$severity) &&
                    !(ct$severity %in% c("critical", "warning"))) {
                  errors <- c(errors,
                              sprintf("Tab '%s.%s'.contracts[%d].severity must be 'critical' or 'warning' (got '%s')",
                                      mod_name, tab_id, i, ct$severity))
                }
              }
            }
          }
        }
      }
    }
  }

  list(valid = length(errors) == 0, errors = errors)
}


# =============================================================================
# Shinytest2 wrappers (require AppDriver)
#
# These wrappers fetch the rendered output from a live shinytest2 AppDriver
# session, then delegate the assertion logic to the pure helpers above.
# Failed contracts call testthat::fail() / testthat::expect() with a
# structured message; severity is captured for the deploy-gate caller to
# decide whether to halt.
# =============================================================================

#' Assert KPI card value passes per MP165 contract
#'
#' @param app shinytest2 AppDriver
#' @param kpi_id Output ID without ns; pass the namespaced full id when needed
#' @param op Comparison operator: >=, >, ==, <=, <
#' @param threshold Numeric threshold
#' @param severity "critical" or "warning"
assert_kpi_card_value <- function(app, kpi_id, op, threshold, severity = "critical") {
  value <- tryCatch(app$get_value(output = kpi_id), error = function(e) NA)
  res <- check_kpi_card_value(value, op, threshold)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = kpi_id,
      expected = res$expected,
      observed = paste0("'", as.character(value)[1], "' (parsed=", res$observed, ")"),
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = kpi_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = kpi_id)
  }
}


#' Assert DataTable has meaningful rows excluding placeholders
assert_datatable_meaningful_rows <- function(app,
                                             table_id,
                                             min_rows,
                                             exclude_placeholders = TRUE,
                                             brand_col = "brand",
                                             severity = "critical") {
  data <- tryCatch(app$get_value(output = table_id), error = function(e) NULL)
  res <- check_datatable_meaningful_rows(
    data = data,
    min_rows = min_rows,
    exclude_placeholders = exclude_placeholders,
    brand_col = brand_col
  )
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = table_id,
      expected = res$expected,
      observed = paste0("rows = ", res$observed),
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = table_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = table_id)
  }
}


#' Assert Plotly chart has data points
assert_plotly_has_data_points <- function(app, plot_id, min_traces = 1, severity = "critical") {
  plot_data <- tryCatch(app$get_value(output = plot_id), error = function(e) NULL)
  traces <- if (is.list(plot_data) && !is.null(plot_data$x$data)) plot_data$x$data else plot_data
  res <- check_plotly_has_data_points(traces = traces, min_traces = min_traces)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = plot_id,
      expected = res$expected,
      observed = paste0("non-empty traces = ", res$observed),
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = plot_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = plot_id)
  }
}


#' Assert filter dropdown has enough valid choices
assert_filter_dropdown_choices <- function(app, filter_id, min_choices, severity = "critical") {
  choices <- tryCatch(app$get_value(input = filter_id), error = function(e) NULL)
  res <- check_filter_dropdown_choices(choices = choices, min_choices = min_choices)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = filter_id,
      expected = res$expected,
      observed = paste0("choices = ", res$observed),
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = filter_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = filter_id)
  }
}


#' Assert text output has no forbidden error patterns
#'
#' Fetches the rendered text/HTML from the AppDriver and scans for error
#' patterns. Use on output elements that should never display
#' `Error:` / `[object Object]` / `<NA>` / `NaN` to user.
#'
#' Refs: issue #653 F1-F3 InsightForge `Error: [object Object]` defects
#'
#' @param app shinytest2 AppDriver
#' @param selector Output ID (namespaced full id when needed)
#' @param patterns Character vector of forbidden fixed-string patterns
#' @param severity "critical" or "warning"
assert_no_error_text <- function(app, selector,
                                 patterns = .MP165_DEFAULT_ERROR_PATTERNS,
                                 severity = "critical") {
  value <- tryCatch(app$get_value(output = selector), error = function(e) NA)
  res <- check_no_error_text(value, patterns = patterns)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = selector,
      expected = res$expected,
      observed = res$observed,
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = selector),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = selector)
  }
}


#' Assert no hardcoded English in text output
#'
#' Use on titles / subtitles / labels that should be translated via
#' `translate()` but might be left hardcoded English. `allowed_phrases`
#' whitelists DT controls or similar legitimate English (e.g., `Show`,
#' `Search`).
#'
#' Refs: issue #653 F4-F5 BrandEdge KFE / IdealRate hardcoded English titles
#'
#' @param app shinytest2 AppDriver
#' @param selector Output ID (namespaced full id when needed)
#' @param allowed_phrases Whitelist of OK English phrases
#' @param severity "critical" or "warning" (default "warning")
assert_no_hardcoded_english <- function(app, selector,
                                        allowed_phrases = .MP165_DEFAULT_ALLOWED_ENGLISH,
                                        severity = "warning") {
  value <- tryCatch(app$get_value(output = selector), error = function(e) NA)
  res <- check_no_hardcoded_english(value, allowed_phrases = allowed_phrases)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = selector,
      expected = res$expected,
      observed = res$observed,
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = selector),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = selector)
  }
}


#' Assert KPI card text is not an error placeholder
#'
#' Stricter than `assert_kpi_card_value` when you only need "value is
#' present and not an error placeholder" — no numeric threshold required.
#' Catches `Error: ...`、`[object Object]`、`--`、`-`、`N/A`、`loading...`
#' regardless of numeric parse semantics.
#'
#' Refs: issue #653 F1-F3 InsightForge KPI cards showing error text or `--`
#'
#' @param app shinytest2 AppDriver
#' @param kpi_id Output ID (namespaced full id when needed)
#' @param severity "critical" or "warning" (default "critical")
assert_kpi_no_error_placeholder <- function(app, kpi_id, severity = "critical") {
  value <- tryCatch(app$get_value(output = kpi_id), error = function(e) NA)
  res <- check_kpi_no_error_placeholder(value)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = kpi_id,
      expected = res$expected,
      observed = res$observed,
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = kpi_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = kpi_id)
  }
}


#' Assert chart axis has non-empty tick labels
assert_chart_axis_non_empty <- function(app, plot_id, axis = "x", severity = "critical") {
  plot_data <- tryCatch(app$get_value(output = plot_id), error = function(e) NULL)
  layout <- if (is.list(plot_data) && !is.null(plot_data$x$layout)) plot_data$x$layout else NULL
  axis_key <- paste0(axis, "axis")
  ticks <- if (!is.null(layout) && !is.null(layout[[axis_key]]$ticktext)) {
    layout[[axis_key]]$ticktext
  } else if (!is.null(layout) && !is.null(layout[[axis_key]]$categoryarray)) {
    layout[[axis_key]]$categoryarray
  } else {
    character(0)
  }
  res <- check_chart_axis_non_empty(tick_labels = ticks)
  if (!res$pass) {
    msg <- format_contract_failure(
      selector = paste0(plot_id, "[", axis, "]"),
      expected = res$expected,
      observed = paste0("non-empty ticks = ", res$observed),
      severity = severity
    )
    structure(list(pass = FALSE, severity = severity, message = msg, selector = plot_id),
              class = "mp165_failure")
  } else {
    list(pass = TRUE, severity = severity, selector = plot_id)
  }
}
