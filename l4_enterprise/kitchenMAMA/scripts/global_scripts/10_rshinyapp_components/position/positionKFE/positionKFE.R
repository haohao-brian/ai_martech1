#LOCK FILE
#
# positionKFE.R
#
# Following principles:
# - MP56: Connected Component Principle (component structure)
# - MP81: Explicit Parameter Specification (function arguments)
# - R116: Enhanced Data Access with tbl2 (data access)
# - R09: UI-Server-Defaults Triple (component organization)
# - MP88: Immediate Feedback (real-time filtering without Apply button)
# - MP47: Functional Programming (data transformation functions)
#

#
# Features:
#   • Key Factor Evaluation (KFE) analysis
#   • Automatic identification of critical success factors
#   • Benchmark analysis for each key factor
#   • Ideal point analysis and scoring
#   • Interactive display of key factors and recommendations
# -----------------------------------------------------------------------------

# helper ----------------------------------------------------------------------
#' Paste operator for string concatenation
#' @param x Character string. First string to concatenate.
#' @param y Character string. Second string to concatenate.
#' @return Character string. The concatenated result of x and y.
`%+%` <- function(x, y) paste0(x, y)

#' NULL coalescing operator
#' @param x Any value. The value to use if not NULL.
#' @param y Any value. The fallback value to use if x is NULL.
#' @return Either x or y. Returns x if it's not NULL, otherwise returns y.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Data transformation functions (MP47) ----------------------------------------
#' Perform key factor evaluation analysis
#' @param data data.frame. Position data with numerical attributes
#' @param exclude_vars character vector. Variables to exclude from analysis
#' @param threshold_multiplier numeric. Multiplier for the threshold (default: 1.0)
#' @return list. Contains key factors, indicators, and benchmarks
perform_kfe_analysis <- function(data, exclude_vars = NULL, threshold_multiplier = 1.0) {
  # Helper-level threshold_multiplier validation (#554).
  # Server reactive at line ~583 already clamps [0.5, 2.0], but ad-hoc test /
  # AI insight prep / external R callers bypass that. Negative or zero values
  # invert quadrant classification (med_growth = median * threshold_multiplier
  # goes negative → all factors "Leading"). Apply same clamp here so all
  # callers behave identically.
  if (!is.numeric(threshold_multiplier) || !is.finite(threshold_multiplier) ||
      threshold_multiplier < 0.5 || threshold_multiplier > 2.0) {
    warning(sprintf("KFE: invalid threshold_multiplier=%s, clamping to 1.0",
                    format(threshold_multiplier)))
    threshold_multiplier <- 1.0
  }

  # Check if product_id column exists, if not look for platform-specific columns
  if (!"product_id" %in% names(data)) {
    # Try common platform-specific columns
    if ("asin" %in% names(data)) {
      data <- data %>% dplyr::rename(product_id = asin)
    } else if ("ebay_item_number" %in% names(data)) {
      data <- data %>% dplyr::rename(product_id = ebay_item_number)
    } else {
      warning("No product identifier column found in KFE analysis data")
      return(list(
        key_factors = character(0),
        indicators = data.frame(),
        benchmarks = list(),
        ideal_analysis = data.frame()
      ))
    }
  }
  
  # Capture per-product `rating` column BEFORE applying exclude_vars, so the
  # importance hybrid (D1 in spectra design.md) can use it even when the caller
  # passes "rating" in exclude_vars. Verify finding F1 (Codex P1, 2026-05-04):
  # server passes rating in exclude_vars → cor path silently never executed.
  per_product_rating_full <- if ("product_id" %in% names(data) &&
                                  "rating" %in% names(data) &&
                                  is.numeric(data$rating)) {
    data %>%
      dplyr::filter(!product_id %in% c("Ideal", "Rating", "Revenue", "Importance")) %>%
      dplyr::pull(rating)
  } else {
    NULL
  }

  # Remove excluded variables and special rows. Importance row is excluded
  # from product-row processing (verify finding F2, Codex P1) so it does NOT
  # contaminate mean/sd/max/min/growth_potential or benchmarks.
  df_analysis <- data %>%
    dplyr::filter(!product_id %in% c("Rating", "Revenue", "Importance")) %>%
    dplyr::select(-dplyr::any_of(exclude_vars))
  
  # Extract Ideal row if it exists
  ideal_row <- df_analysis %>% dplyr::filter(product_id == "Ideal")
  
  if (nrow(ideal_row) == 0) {
    warning("No Ideal row found for KFE analysis")
    return(list(
      key_factors = character(0),
      indicators = data.frame(),
      benchmarks = list(),
      ideal_analysis = data.frame()
    ))
  }
  
  # Get numeric columns for analysis
  # Exclude both identity columns and per-product covariate columns. The
  # rating / sales / revenue columns are per-product overall metrics (matching
  # positionStrategy.R covariate exclude list) — they MUST NOT be treated as
  # attribute factors. The `rating` column is consumed separately by the
  # importance derivation (D1 B-revised hybrid in qef-brandedge-key-factor-ipa-redesign).
  key_cols <- c("product_id", "brand", "product_line_id", "platform_id",
                "rating", "sales", "revenue")
  numeric_cols <- df_analysis %>%
    dplyr::select(-dplyr::any_of(key_cols)) %>%
    dplyr::select_if(is.numeric) %>%
    names()
  
  if (length(numeric_cols) == 0) {
    warning("No numeric columns found for KFE analysis")
    return(list(
      key_factors = character(0),
      indicators = data.frame(),
      benchmarks = list(),
      ideal_analysis = data.frame()
    ))
  }
  
  # Create indicators matrix
  df_no_ideal <- df_analysis %>% dplyr::filter(product_id != "Ideal")

  # Zero-product boundary guard (#551). When data has only Ideal row and no
  # product rows (extreme but ETL gap can produce this), downstream cor() /
  # quadrant classification / dplyr::select(all_of(key_factors)) all break
  # before fallback warnings fire. Mirror the existing early-return pattern
  # used for "No Ideal row" (line ~85) and "No numeric columns" (line ~108).
  if (nrow(df_no_ideal) == 0) {
    pl_label <- if ("product_line_id" %in% names(data)) {
      pls <- unique(data$product_line_id)
      if (length(pls) == 1) as.character(pls[1]) else paste0(length(pls), " PLs")
    } else "(unknown PL)"
    warning(sprintf("KFE: PL '%s' has no product rows — returning empty result", pl_label))
    return(list(
      key_factors = character(0),
      indicators = data.frame(),
      benchmarks = list(),
      ideal_analysis = data.frame(),
      factor_stats = data.frame(),
      gate_threshold = NA_real_
    ))
  }

  # Calculate ideal comparison for each numeric column
  indicators <- data.frame(matrix(0, nrow = nrow(df_no_ideal), ncol = length(numeric_cols)))
  colnames(indicators) <- numeric_cols
  
  for (col in numeric_cols) {
    ideal_val <- ideal_row[[col]][1]
    if (!is.na(ideal_val) && is.numeric(ideal_val) && is.finite(ideal_val)) {
      # Compare each value to ideal, handling NA values explicitly
      col_values <- df_no_ideal[[col]]
      # Only include non-NA values in comparison, set NA values to 0
      comparison_result <- ifelse(is.na(col_values), 0, ifelse(col_values >= ideal_val, 1, 0))
      indicators[[col]] <- comparison_result
    } else {
      # If ideal value is NA or invalid, set all indicators to 0
      indicators[[col]] <- rep(0, nrow(df_no_ideal))
    }
  }
  
  # Calculate gate (threshold) for key factor identification
  gate <- rowSums(indicators, na.rm = TRUE) / ncol(indicators) * threshold_multiplier
  
  # Identify key factors (columns where ideal comparison > gate)
  col_sums <- colSums(indicators, na.rm = TRUE)
  key_factors <- names(col_sums[col_sums > mean(gate, na.rm = TRUE)])
  
  # Create benchmarks for each key factor
  benchmarks <- list()
  for (factor in key_factors) {
    if (factor %in% colnames(indicators)) {
      # Get indices where the factor equals 1
      factor_indices <- which(indicators[[factor]] == 1)
      
      if (length(factor_indices) > 0) {
        # Get Product IDs for those indices, filtering out NA values
        benchmark_item_ids <- df_no_ideal$product_id[factor_indices]
        benchmark_item_ids <- benchmark_item_ids[!is.na(benchmark_item_ids)]
        benchmark_item_ids <- unique(benchmark_item_ids)
        
        # Only include if we have valid Product IDs
        if (length(benchmark_item_ids) > 0) {
          benchmarks[[factor]] <- benchmark_item_ids
        }
      }
    }
  }
  
  # Create ideal analysis (scoring based on key factors)
  if (length(key_factors) > 0) {
    ideal_analysis <- df_no_ideal %>%
      dplyr::select(product_id, brand, dplyr::all_of(key_factors)) %>%
      dplyr::mutate(
        Score = rowSums(dplyr::select(., dplyr::all_of(key_factors)), na.rm = TRUE)
      ) %>%
      dplyr::arrange(dplyr::desc(Score))
  } else {
    ideal_analysis <- data.frame()
  }

  # ---- factor_stats computation (qef-brandedge-key-factor-ipa-redesign #404) ----
  # Per-attribute statistics powering the new IPA quadrant + 7-column DT table:
  #   factor / mean / sd / max / min / importance / growth_potential / rank / quadrant
  # Decisions per design.md (spectra change archive):
  #   D1 — importance = B-revised (cor with rating col) + D-override (Importance row)
  #   D2 — Low-N fallback to ranking when n_products < 5 OR rating column absent
  #   D3 — IPA quadrant = median split * threshold_multiplier
  #   D5 — quadrant labels in English keys (Leading / Mature / Niche / Low-Priority);
  #        UI translates via translate() per DEV_R052
  # Importance row read from raw `data` (BEFORE exclude/filter) so that callers
  # who pass it in survive the dplyr::filter at line 75.
  importance_row <- data %>% dplyr::filter(product_id == "Importance")
  # Per-product rating: prefer the pre-exclude capture (per_product_rating_full
  # populated at line 60-69), falling back to df_no_ideal$rating if it survived.
  # Length must match nrow(df_no_ideal) for cor() to work.
  per_product_rating <- if (!is.null(per_product_rating_full) &&
                              length(per_product_rating_full) == nrow(df_no_ideal)) {
    per_product_rating_full
  } else if ("rating" %in% names(df_no_ideal) && is.numeric(df_no_ideal$rating)) {
    df_no_ideal$rating
  } else {
    NULL
  }
  has_rating_col <- !is.null(per_product_rating)
  n_products <- nrow(df_no_ideal)
  use_low_n_fallback <- n_products < 5 ||
                          !has_rating_col ||
                          (has_rating_col && sum(!is.na(per_product_rating)) < 3)
  if (use_low_n_fallback) {
    # Codex F7 (Follow-up → in-scope fix while we're here): include product_line_id
    # context in the warning so business team can identify which PL fell back.
    pl_label <- if ("product_line_id" %in% names(df_no_ideal)) {
      pls <- unique(df_no_ideal$product_line_id)
      if (length(pls) == 1) as.character(pls[1]) else paste0(length(pls), " PLs")
    } else "(unknown PL)"
    warning(sprintf(
      "KFE: importance fallback to ranking for PL '%s' (n_products = %d, has_rating = %s)",
      pl_label, n_products, has_rating_col))
  }

  factor_stats_rows <- lapply(numeric_cols, function(col) {
    col_values <- df_no_ideal[[col]]
    ideal_val <- ideal_row[[col]][1]

    m <- mean(col_values, na.rm = TRUE)
    s <- sd(col_values, na.rm = TRUE)
    mx <- if (all(is.na(col_values))) NA_real_ else max(col_values, na.rm = TRUE)
    mn <- if (all(is.na(col_values))) NA_real_ else min(col_values, na.rm = TRUE)

    if (is.na(ideal_val) || !is.finite(ideal_val) || ideal_val == 0) {
      warning(sprintf("KFE: growth_potential NA for '%s' (ideal value is 0/NA)", col))
      gp <- NA_real_
    } else {
      gp <- round((ideal_val - m) / ideal_val * 100, 2)
    }

    # D-override layer first
    imp_override <- NA_real_
    if (nrow(importance_row) > 0 && col %in% names(importance_row)) {
      v <- suppressWarnings(as.numeric(importance_row[[col]][1]))
      if (!is.na(v) && is.finite(v)) imp_override <- v
    }

    data.frame(
      factor = col,
      mean = round(m, 4),
      sd = round(s, 4),
      max = mx,
      min = mn,
      importance_override = imp_override,
      growth_potential = gp,
      stringsAsFactors = FALSE
    )
  })
  factor_stats <- do.call(rbind, factor_stats_rows)

  # B-revised default (cor) OR Low-N fallback (ranking) — only fills cells where
  # D-override didn't apply.
  if (use_low_n_fallback) {
    # Rank by mean descending (high mean → high rank → high importance);
    # map [1, total] → [5, 5/total] so that rank 1 gets ~5 and last rank gets ~5/total.
    ranks_vec <- rank(-factor_stats$mean, ties.method = "average", na.last = "keep")
    total <- sum(!is.na(ranks_vec))
    importance_derived <- if (total > 0) {
      round(5 * (total - ranks_vec + 1) / total, 2)
    } else {
      rep(NA_real_, nrow(factor_stats))
    }
  } else {
    importance_derived <- vapply(numeric_cols, function(col) {
      attr_vals <- df_no_ideal[[col]]
      pair_n <- sum(!is.na(attr_vals) & !is.na(per_product_rating))
      if (pair_n < 3) return(NA_real_)
      r <- suppressWarnings(stats::cor(attr_vals, per_product_rating,
                                       use = "pairwise.complete.obs"))
      if (is.na(r) || !is.finite(r)) return(NA_real_)
      round(5 * (r + 1) / 2, 2)
    }, numeric(1))
  }

  factor_stats$importance <- ifelse(
    !is.na(factor_stats$importance_override),
    factor_stats$importance_override,
    importance_derived
  )
  factor_stats$importance_override <- NULL

  # rank by importance descending (high importance → rank 1)
  factor_stats$rank <- rank(-factor_stats$importance,
                             ties.method = "min",
                             na.last = "keep")

  # IPA quadrant classification (median split * threshold_multiplier)
  med_growth <- median(factor_stats$growth_potential, na.rm = TRUE) * threshold_multiplier
  med_importance <- median(factor_stats$importance, na.rm = TRUE) * threshold_multiplier

  factor_stats$quadrant <- mapply(function(g, i) {
    if (is.na(g) || is.na(i)) return(NA_character_)
    hi_g <- g > med_growth
    hi_i <- i > med_importance
    if (hi_g && hi_i) "Leading"
    else if (!hi_g && hi_i) "Mature"
    else if (hi_g && !hi_i) "Niche"
    else "Low-Priority"
  }, factor_stats$growth_potential, factor_stats$importance,
     SIMPLIFY = TRUE, USE.NAMES = FALSE)

  # Re-order rows by rank ascending (rank 1 first)
  factor_stats <- factor_stats[order(factor_stats$rank,
                                      factor_stats$factor,
                                      na.last = TRUE), ]
  rownames(factor_stats) <- NULL

  return(list(
    key_factors = key_factors,
    indicators = indicators,
    benchmarks = benchmarks,
    ideal_analysis = ideal_analysis,
    gate_threshold = mean(gate, na.rm = TRUE),
    factor_stats = factor_stats
  ))
}

#' Format key factors for display
#' @param factors character vector. List of key factors
#' @return character. Formatted string of key factors
format_key_factors <- function(factors) {
  if (length(factors) == 0) {
    return("No key factors identified")
  }
  
  # Clean up factor names for display
  clean_factors <- factors %>%
    stringr::str_replace_all("_", " ") %>%
    stringr::str_to_title()
  
  # Use bullet points for better readability and wrapping
  paste(paste("•", clean_factors), collapse = "\n")
}

# Filter UI -------------------------------------------------------------------
#' positionKFEFilterUI
#' @param id Character string. The module ID used for namespacing inputs and outputs.
#' @param translate Function. Translation function for UI text elements (defaults to identity function).
#'        Should accept a string and return a translated string.
#' @return shiny.tag. A Shiny UI component containing the filter controls for the KFE component.
positionKFEFilterUI <- function(id, translate = identity) {
  ns <- NS(id)

  # AI insight button is appended at the bottom of ui_filter per UI_R026 layer (3)
  # convention. ai_insight_button_ui() is sourced from 08_ai/fn_ai_insight_async.R
  # via app autoinit; gracefully degrade if not loaded (Shiny will simply not
  # render the button — no error).
  ai_button <- if (exists("ai_insight_button_ui", mode = "function")) {
    ai_insight_button_ui(ns, translate)
  } else {
    NULL
  }

  wellPanel(
    style = "padding:15px;",
    h4(translate("Key Factor Analysis Settings")),

    # Display options
    hr(),
    h4(translate("Display Options")),

    # Show benchmark products
    checkboxInput(
      inputId = ns("show_benchmarks"),
      label = translate("Show Benchmark Products by Factor"),
      value = TRUE
    ),

    # IPA quadrant cross-hair sensitivity (Decision 3)
    sliderInput(
      inputId = ns("threshold_multiplier"),
      label = translate("Quadrant Sensitivity"),
      min = 0.5, max = 2.0, value = 1.0, step = 0.1
    ),

    # Reset button
    actionButton(
      inputId = ns("reset_filters"),
      label = translate("Reset Settings"),
      class = "btn-outline-secondary btn-block mt-3"
    ),

    hr(),
    textOutput(ns("component_status")),

    hr(),
    ai_button
  )
}

# Display UI ------------------------------------------------------------------
#' positionKFEDisplayUI
#' @param id Character string. The module ID used for namespacing inputs and outputs.
#' @param translate Function. Translation function for UI text elements (defaults to identity function).
#' @param mode Character string. Display mode - "compact" for summary view, "full" for detailed view (default: "full").
#' @return shiny.tag. A Shiny UI component containing the display elements for the KFE component.
positionKFEDisplayUI <- function(id, translate = identity, mode = "full") {
  ns <- NS(id)
  
  if (mode == "compact") {
    # Compact mode for use alongside other components
    tagList(
      div(class = "component-output p-2",
          div(class = "kfe-main-output",
              h5(translate("Key Factors:")),
              div(class = "kfe-factors-display",
                  style = "white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word;",
                  verbatimTextOutput(ns("key_factors_text")))
          )
      )
    )
  } else {
    # Full mode for dedicated view
    # AI insight result section is appended at the bottom of ui_display per
    # UI_R026 layer (3) convention. ai_insight_result_ui() sourced via app
    # autoinit from 08_ai/fn_ai_insight_async.R; gracefully degrade if missing.
    ai_result <- if (exists("ai_insight_result_ui", mode = "function")) {
      ai_insight_result_ui(ns, translate)
    } else {
      NULL
    }

    tagList(
      div(class = "component-header mb-3 text-center",
          h3(translate("Key Factor Evaluation")),
          p(translate("Automatic identification and analysis of critical success factors"))),
      div(class = "component-output p-3",
          # New 7-column factor stats DT table (replaces verbatimText
          # Key Factors list per Requirement: KFE table UI rendering)
          div(class = "kfe-factor-stats-table",
              h4(translate("Key Factor Importance Analysis")),
              DT::dataTableOutput(ns("factor_stats_table"))),
          # IPA plotly quadrant chart (Requirement: IPA quadrant plotly chart)
          div(class = "kfe-ipa-chart mt-4",
              h4(translate("Importance-Performance Quadrant")),
              plotly::plotlyOutput(ns("ipa_quadrant_chart"), height = "500px")),
          # Quadrant explanation panel (Requirement: Quadrant explanation
          # yaml externalization — content from kfe_quadrant_explanations.yaml)
          div(class = "kfe-quadrant-explanations mt-4",
              uiOutput(ns("quadrant_explanations"))),
          # Existing benchmark output preserved (key_factors / benchmarks
          # behaviour unchanged per design Migration Plan)
          conditionalPanel(
            condition = paste0("input['", ns("show_benchmarks"), "']"),
            div(class = "kfe-benchmarks mt-4",
                h4(translate("Benchmark Products by Factor")),
                div(style = "white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word; max-width: 100%;",
                    verbatimTextOutput(ns("benchmark_details")))
            )
          ),
          # AI insight at very bottom of ui_display per UI_R026
          div(class = "kfe-ai-insight mt-4", ai_result)
      )
    )
  }
}

# Server ----------------------------------------------------------------------
#' positionKFEServer
#' @param id Character string. The module ID used for namespacing inputs and outputs.
#' @param app_data_connection Database connection object or list. Any connection type supported by tbl2.
#'        Can be a DBI connection, a list with getter functions, a file path, or NULL if no database access is needed.
#' @param config List or reactive expression. Optional configuration settings that can customize behavior.
#'        If reactive, will be re-evaluated when dependencies change.
#' @param session Shiny session object. The current Shiny session (defaults to getDefaultReactiveDomain()).
#' @param display_mode Character string. Display mode - "compact" or "full" (default: "full").
#' @return list. A list of reactive values providing access to component state and data.
positionKFEServer <- function(id, app_data_connection = NULL, config = NULL,
                              session = getDefaultReactiveDomain(), display_mode = "full") {
  moduleServer(id, function(input, output, session) {
    
    # ------------ Status tracking ----------------------------------
    component_status <- reactiveVal("idle")
    
    # ------------ Extract configuration parameters -----------------
    platform_id <- reactive({
      tryCatch({
        if (is.null(config)) return(NULL)
        
        cfg <- if (is.function(config)) config() else config
        
        if (!is.null(cfg[["platform_id"]])) {
          return(as.character(cfg[["platform_id"]]))
        }
        if (!is.null(cfg[["filters"]]) && !is.null(cfg[["filters"]][["platform_id"]])) {
          return(as.character(cfg[["filters"]][["platform_id"]]))
        }
        
        NULL
      }, error = function(e) {
        warning("Error extracting platform_id from config: ", e$message)
        NULL
      })
    })
    
    product_line_id <- reactive({
      tryCatch({
        if (is.null(config)) return("all")
        
        cfg <- if (is.function(config)) config() else config
        
        if (!is.null(cfg[["filters"]]) && !is.null(cfg[["filters"]][["product_line_id_chosen"]])) {
          return(as.character(cfg[["filters"]][["product_line_id_chosen"]]))
        }
        
        "all"
      }, error = function(e) {
        warning("Error extracting product_line_id: ", e$message)
        "all"
      })
    })
    
    # ------------ Data access (R116) -----------------------------------
    position_data <- reactive({
      if (product_line_id() == "all") {
        component_status("idle")
        return(data.frame())
      }
      
      component_status("loading")
      
      prod_line <- product_line_id()
      
      result <- tryCatch({
        if (is.null(app_data_connection)) {
          warning("No valid database connection available")
          return(data.frame())
        }
        
        # Use complete case function to get position data with type filtering (KFE needs Ideal row)
        filtered_data <- fn_get_position_complete_case(
          app_data_connection = app_data_connection,
          product_line_id = prod_line,
          include_special_rows = TRUE,  # KFE analysis needs Ideal row
          apply_type_filter = TRUE
        )
        
        # Check if product_id column exists, if not try to find platform-specific column
        if (!"product_id" %in% names(filtered_data) && nrow(filtered_data) > 0) {
          platform <- platform_id()

          # Ensure platform is a scalar value for switch statement
          if (is.null(platform) || length(platform) == 0) {
            platform <- "default"
          } else if (length(platform) > 1) {
            warning("platform_id() returned multiple values, using first: ", paste(platform, collapse=", "))
            platform <- as.character(platform[1])
          } else {
            platform <- as.character(platform)
          }

          item_col <- switch(platform,
            "amz" = "asin",  # Amazon
            "eby" = "ebay_item_number",  # eBay
            "product_id"  # Default fallback
          )
          
          if (item_col %in% names(filtered_data)) {
            message("DEBUG: Renaming '", item_col, "' to 'product_id' in positionKFE")
            filtered_data <- filtered_data %>% dplyr::rename(product_id = !!sym(item_col))
          } else {
            warning("No product identifier column found in KFE position data. Available columns: ", paste(names(filtered_data), collapse = ", "))
          }
        }
        
        component_status("ready")
        return(filtered_data)
      }, error = function(e) {
        warning("Error fetching position data: ", e$message)
        component_status("error")
        data.frame()
      })
      
      return(result)
    })
    
    # ------------ Threshold multiplier reactive (Decision 3) ----------
    # Slider input only exists in full mode; compact mode keeps default 1.0.
    threshold_mult_reactive <- reactive({
      v <- if (display_mode == "full") input$threshold_multiplier %||% 1.0 else 1.0
      if (!is.numeric(v) || !is.finite(v) || v < 0.5 || v > 2.0) 1.0 else v
    })

    # ------------ KFE Analysis -----------------------------------
    kfe_result <- reactive({
      data <- position_data()
      if (is.null(data) || nrow(data) == 0) return(NULL)

      component_status("computing")

      # Define variables to exclude from KFE analysis
      exclude_vars <- c("product_line_id", "platform_id", "rating", "sales", "revenue")

      result <- perform_kfe_analysis(
        data = data,
        exclude_vars = exclude_vars,
        threshold_multiplier = threshold_mult_reactive()
      )

      if (length(result$key_factors) > 0) {
        component_status("ready")
      } else {
        component_status("idle")
      }

      return(result)
    })

    # ------------ Quadrant explanations (yaml externalization, D4) -----
    quadrant_explanations_yaml <- reactive({
      yaml_path <- file.path("scripts", "global_scripts", "30_global_data",
                              "parameters", "scd_type1",
                              "kfe_quadrant_explanations.yaml")
      candidate_paths <- c(
        yaml_path,
        file.path("..", "..", "30_global_data", "parameters", "scd_type1",
                  "kfe_quadrant_explanations.yaml"),
        file.path("..", "..", "..", "30_global_data", "parameters", "scd_type1",
                  "kfe_quadrant_explanations.yaml")
      )
      hit <- candidate_paths[file.exists(candidate_paths)][1]
      if (is.na(hit)) return(NULL)
      tryCatch(yaml::read_yaml(hit),
               error = function(e) {
                 warning("Failed to read kfe_quadrant_explanations.yaml: ", e$message)
                 NULL
               })
    })

    # ------------ Reset filters ------------------------------------
    # Only set up reset observer in full mode
    if (display_mode == "full") {
      observeEvent(input$reset_filters, {
        updateCheckboxInput(session, "show_benchmarks", value = TRUE)
        updateSliderInput(session, "threshold_multiplier", value = 1.0)

        message("KFE settings reset")
      })
    }
    
    # ------------ Compact-mode legacy output (verify finding F4 / M1 regression) ----
    # The compact-mode UI (display_mode == "compact") still renders
    # `verbatimTextOutput(ns("key_factors_text"))`. The full-mode UI rewrite
    # removed the original output handler — restore it so compact-mode callers
    # (e.g. dashboards embedding KFE alongside other components) keep working.
    output$key_factors_text <- renderText({
      result <- kfe_result()
      if (is.null(result) || length(result$key_factors) == 0) {
        return("No key factors identified.")
      }
      format_key_factors(result$key_factors)
    })

    # ------------ NEW: factor_stats DT table (Requirement: KFE table UI rendering) ----
    output$factor_stats_table <- DT::renderDataTable({
      result <- kfe_result()
      if (is.null(result) || is.null(result$factor_stats) ||
          nrow(result$factor_stats) == 0) {
        return(DT::datatable(data.frame(), options = list(dom = 't')))
      }

      fs <- result$factor_stats

      # KFE module's purpose is to show "key" factors that passed the gate
      # (perform_kfe_analysis line 178: names(col_sums[col_sums > mean(gate)])),
      # not all attribute candidates. Filter display to key_factors subset;
      # fall back to full set only if key_factors is empty (data too thin to
      # compute meaningful gate — better to show all than an empty table). (#700)
      if (length(result$key_factors) > 0) {
        fs <- fs[fs$factor %in% result$key_factors, , drop = FALSE]
      }

      # Translate-aware column names; fall back to English if translate not in scope
      tr <- function(x) if (is.function(get0("translate", envir = globalenv()))) {
        translate(x)
      } else x
      display_df <- data.frame(
        attribute = fs$factor,
        mean = fs$mean,
        sd = fs$sd,
        max = fs$max,
        min = fs$min,
        importance = fs$importance,
        rank = fs$rank,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      colnames(display_df) <- c(
        tr("Attribute"), tr("Mean Score"), tr("Standard Deviation"),
        tr("Max Value"), tr("Min Value"), tr("Importance Index"), tr("Rank")
      )
      # Sort by Rank ascending (rank 1 first); per-column escape per #408 fix-#16
      # canonical pattern. All columns escaped (XSS-safe), no HTML markup.
      DT::datatable(
        display_df,
        escape = TRUE,
        options = list(
          pageLength = -1, paging = FALSE, searching = FALSE,
          info = FALSE, scrollX = TRUE,
          order = list(list(ncol(display_df) - 1L, "asc"))
        ),
        rownames = FALSE
      ) %>%
        DT::formatRound(columns = c(2L, 3L, 4L, 5L, 6L), digits = 2L)
    }, server = TRUE)

    # ------------ NEW: IPA plotly quadrant chart (Requirement: IPA quadrant plotly chart) ----
    output$ipa_quadrant_chart <- plotly::renderPlotly({
      result <- kfe_result()
      if (is.null(result) || is.null(result$factor_stats) ||
          nrow(result$factor_stats) == 0) {
        return(plotly::plot_ly() %>%
                 plotly::layout(annotations = list(
                   list(text = "No data", showarrow = FALSE,
                        x = 0.5, y = 0.5, xref = "paper", yref = "paper"))))
      }

      fs <- result$factor_stats

      # Same key_factors filter as factor_stats_table render (#700) — keep
      # the IPA quadrant chart in sync with the table; showing different
      # subsets would confuse users about what "key" means in this module.
      if (length(result$key_factors) > 0) {
        fs <- fs[fs$factor %in% result$key_factors, , drop = FALSE]
      }

      tm <- threshold_mult_reactive()
      med_g <- median(fs$growth_potential, na.rm = TRUE) * tm
      med_i <- median(fs$importance, na.rm = TRUE) * tm
      tr <- function(x) if (is.function(get0("translate", envir = globalenv()))) {
        translate(x)
      } else x

      # Quadrant labels at corners of plot range
      x_range <- range(fs$growth_potential, na.rm = TRUE)
      y_range <- range(fs$importance, na.rm = TRUE)
      if (any(!is.finite(x_range))) x_range <- c(0, 100)
      if (any(!is.finite(y_range))) y_range <- c(0, 5)
      x_pad <- diff(x_range) * 0.05
      y_pad <- diff(y_range) * 0.05

      hover_text <- sprintf(
        "%s: %s\n%s: %.2f\n%s: %.2f%%\n%s: %.2f\n%s: %s",
        tr("Attribute"), fs$factor,
        tr("Mean Score"), fs$mean,
        tr("Growth Potential"), fs$growth_potential,
        tr("Importance Index"), fs$importance,
        tr("Quadrant"), vapply(fs$quadrant, function(q) {
          if (is.na(q)) "" else tr(paste0(q, " Track"))
        }, character(1))
      )

      p <- plotly::plot_ly(
        data = fs,
        x = ~growth_potential, y = ~importance, text = ~factor,
        type = "scatter", mode = "markers+text",
        textposition = "top center",
        marker = list(size = 12, color = "rgb(31,119,180)"),
        hoverinfo = "text", hovertext = hover_text
      ) %>%
        plotly::layout(
          xaxis = list(title = tr("Growth Potential") %+% " (%)",
                       range = c(x_range[1] - x_pad, x_range[2] + x_pad)),
          yaxis = list(title = tr("Importance Index"),
                       range = c(y_range[1] - y_pad, y_range[2] + y_pad)),
          shapes = list(
            list(type = "line", x0 = med_g, x1 = med_g,
                 y0 = y_range[1] - y_pad, y1 = y_range[2] + y_pad,
                 line = list(color = "gray", dash = "dash", width = 1)),
            list(type = "line", y0 = med_i, y1 = med_i,
                 x0 = x_range[1] - x_pad, x1 = x_range[2] + x_pad,
                 line = list(color = "gray", dash = "dash", width = 1))
          ),
          annotations = list(
            list(x = x_range[2] + x_pad, y = y_range[2] + y_pad,
                 text = tr("Leading Track"), showarrow = FALSE,
                 xanchor = "right", yanchor = "top",
                 font = list(color = "darkgreen", size = 14)),
            list(x = x_range[1] - x_pad, y = y_range[2] + y_pad,
                 text = tr("Mature Track"), showarrow = FALSE,
                 xanchor = "left", yanchor = "top",
                 font = list(color = "blue", size = 14)),
            list(x = x_range[2] + x_pad, y = y_range[1] - y_pad,
                 text = tr("Niche Track"), showarrow = FALSE,
                 xanchor = "right", yanchor = "bottom",
                 font = list(color = "orange", size = 14)),
            list(x = x_range[1] - x_pad, y = y_range[1] - y_pad,
                 text = tr("Low-Priority Track"), showarrow = FALSE,
                 xanchor = "left", yanchor = "bottom",
                 font = list(color = "gray", size = 14))
          )
        ) %>%
        plotly::config(displaylogo = FALSE, scrollZoom = FALSE,
                        doubleClick = FALSE)
      p
    })

    # ------------ NEW: Quadrant explanations renderUI (D4 yaml externalization) ----
    output$quadrant_explanations <- renderUI({
      yml <- quadrant_explanations_yaml()
      if (is.null(yml)) {
        return(div(class = "text-muted",
                   tags$em("Quadrant explanations not loaded.")))
      }
      # Pick locale: if a `translate` global function is in scope and returns
      # zh_TW for "Importance Index", we're in zh_TW UI; else en.
      # Per UI_R027, items without a standard English abbreviation use pure
      # Chinese (no `中文（English）` parenthesized format), so a single
      # identical() check suffices. (#560 — was duplicate || identical())
      is_zh <- tryCatch({
        f <- get0("translate", envir = globalenv())
        if (is.null(f) || !is.function(f)) FALSE
        else identical(f("Importance Index"), "重要性指數")
      }, error = function(e) FALSE)
      loc <- if (is_zh) "zh_tw" else "en"

      gp <- yml$growth_potential[[loc]]
      mi <- yml$market_importance[[loc]]
      qd <- yml$quadrants[[loc]]

      gp_bands <- if (!is.null(gp$bands)) {
        tags$ul(lapply(gp$bands, function(b) tags$li(strong(b$range), ": ", b$interpretation)))
      } else NULL
      mi_bands <- if (!is.null(mi$bands)) {
        tags$ul(lapply(mi$bands, function(b) tags$li(strong(b$range), ": ", b$interpretation)))
      } else NULL
      qd_items <- if (!is.null(qd$items)) {
        tags$ul(lapply(qd$items, function(it) tags$li(
          strong(it$label), if (!is.null(it$position)) paste0(" (", it$position, ")"),
          ": ", it$criteria, " — ", it$recommendation)))
      } else NULL

      div(class = "card mt-3",
          div(class = "card-header bg-info text-white",
              h5(if (!is.null(qd$title)) qd$title else "Quadrant Interpretation")),
          div(class = "card-body",
              h5(gp$title), p(gp$summary), gp_bands,
              hr(),
              h5(mi$title), p(mi$summary), mi_bands,
              hr(),
              h5(qd$title), p(qd$summary), qd_items))
    })

    # ------------ NEW: AI Insight wire-up (D5) ----
    # Only set up AI insight observer in full mode (#555).
    # Compact-mode UI has no `generate_ai_insight` button so the observer is
    # an orphan — never fires, but adds reactive scheduler overhead. Match the
    # existing reset-button guard pattern (line 636).
    if (display_mode == "full" &&
        exists("create_ai_insight_task", mode = "function") &&
        exists("setup_ai_insight_server", mode = "function")) {
      gpt_key <- Sys.getenv("OPENAI_API_KEY", "")
      ai_task <- create_ai_insight_task(gpt_key)
      setup_ai_insight_server(
        input, output, session, ns,
        task = ai_task,
        gpt_key = gpt_key,
        prompt_key = "position_analysis.key_factor_ipa_insights",
        get_template_vars = function() {
          result <- kfe_result()
          if (is.null(result) || is.null(result$factor_stats) ||
              nrow(result$factor_stats) == 0) return(NULL)
          fs <- result$factor_stats
          # Build markdown table (factor_stats_table template var).
          # #550 Bug 2: replaced apply(fs, 1, ...) with vapply over indices.
          # apply on a data.frame coerces every column to character via the
          # widest type, which silently turns NA quadrant into literal "NA"
          # string in the GPT prompt -> GPT treats "NA" as a valid quadrant
          # name and writes nonsense like "NA quadrant marketing strategy...".
          # Per DEV_R001 (apply over loops anti-pattern on data.frames) and
          # MP154 (sentinel for missing values, not literal "NA"), iterate by
          # row index so each column keeps its native type.
          rows <- vapply(seq_len(nrow(fs)), function(i) {
            quadrant_val <- fs$quadrant[i]
            quadrant_str <- if (is.na(quadrant_val) || !nzchar(trimws(as.character(quadrant_val))))
              "Unclassified" else as.character(quadrant_val)
            sprintf("| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %s | %s |",
                    fs$factor[i],
                    suppressWarnings(as.numeric(fs$mean[i])),
                    suppressWarnings(as.numeric(fs$sd[i])),
                    suppressWarnings(as.numeric(fs$max[i])),
                    suppressWarnings(as.numeric(fs$min[i])),
                    suppressWarnings(as.numeric(fs$importance[i])),
                    suppressWarnings(as.numeric(fs$growth_potential[i])),
                    quadrant_str)
          }, character(1))
          stats_md <- paste0(
            "| Attribute | Mean | SD | Max | Min | Importance | Growth% | Quadrant |\n",
            "|-----------|------|----|----|----|------------|---------|----------|\n",
            paste(rows, collapse = "\n")
          )
          # Build quadrant assignments summary
          assignments <- paste(
            sapply(unique(fs$quadrant), function(q) {
              if (is.na(q)) return("")
              factors_in_q <- fs$factor[fs$quadrant == q & !is.na(fs$quadrant)]
              sprintf("- **%s**: %s", q, paste(factors_in_q, collapse = ", "))
            }),
            collapse = "\n"
          )
          list(
            factor_stats_table = stats_md,
            quadrant_assignments = assignments
          )
        },
        component_label = "positionKFE",
        # #796 fix: wire scope label per default helper
        scope_provider = default_scope_provider(comp_config, translate)
      )
    }

    output$benchmark_details <- renderText({
      result <- kfe_result()
      
      if (is.null(result) || length(result$benchmarks) == 0) {
        return("")
      }
      
      benchmark_text <- ""
      factors_with_benchmarks <- 0
      
      for (factor in names(result$benchmarks)) {
        products <- result$benchmarks[[factor]]
        
        # Only process factors that have valid benchmark products
        if (!is.null(products) && length(products) > 0 && !all(is.na(products))) {
          # Filter out any NA values that might have slipped through
          valid_products <- products[!is.na(products) & nchar(products) > 0]
          
          if (length(valid_products) > 0) {
            clean_factor <- stringr::str_replace_all(factor, "_", " ") %>% 
                           stringr::str_to_title()
            # Show all products without limitation
            benchmark_text <- paste0(
              benchmark_text,
              clean_factor, ": ", 
              paste(valid_products, collapse = ", "),
              "\n"
            )
            factors_with_benchmarks <- factors_with_benchmarks + 1
          }
        }
      }
      
      if (factors_with_benchmarks == 0) {
        return("")
      }
      
      return(benchmark_text)
    })
    
    # Display component status
    output$component_status <- renderText({
      # MP031: Defensive programming - check for NULL/empty values before switch
      # R113: Error handling for reactive expressions
      status_val <- tryCatch({
        component_status()
      }, error = function(e) {
        warning("Error getting component status: ", e$message)
        "idle"
      })

      # MP099: Defensive check for NULL or empty status
      if (is.null(status_val) || length(status_val) == 0 || status_val == "") {
        return("Ready for position analysis")
      }

      # Ensure status_val is character and length 1 for switch
      status_val <- as.character(status_val)[1]

      switch(status_val,
             idle = "Ready for position analysis",
             loading = "Loading position data...",
             ready = paste0("Position data loaded: ", nrow(position_data()), " records"),
             computing = "Computing position metrics...",
             error = "Error loading position data",
             status_val)  # Default: return the status value itself
    })
    
    # Return reactive values for external use
    return(list(
      position_data = position_data,
      kfe_result = kfe_result,
      component_status = component_status
    ))
  })
}

# Component wrapper -----------------------------------------------------------
#' positionKFEComponent
#' 
#' Implements a key factor evaluation component for position analysis
#' following the Connected Component principle.
#' 
#' @param id Character string. The module ID used for namespacing inputs and outputs.
#' @param app_data_connection Database connection object or list. The data connection supporting Enhanced Data Access pattern (R116).
#'        Can be a DBI connection, a list with getter functions, a file path, or NULL if no database access is needed.
#' @param config List or reactive expression. Configuration parameters for customizing component behavior (optional).
#'        If reactive, will be re-evaluated when dependencies change.
#' @param translate Function. Translation function for UI text elements (defaults to identity function).
#'        Should accept a string and return a translated string.
#' @param display_mode Character string. Display mode - "compact" for summary view, "full" for detailed view (default: "full").
#' @return A list containing UI and server functions structured according to the Connected Component Principle (MP56).
#'         The UI element contains 'filter' and 'display' components, and the server function initializes component functionality.
#' @examples
#' # Basic usage with default settings
#' kfeComp <- positionKFEComponent("kfe_analysis")
#' 
#' # Usage with database connection
#' kfeComp <- positionKFEComponent(
#'   id = "kfe_analysis",
#'   app_data_connection = app_conn, 
#'   config = list(platform_id = "amz")
#' )
#'
#' # Usage with reactive configuration
#' kfeComp <- positionKFEComponent(
#'   id = "kfe_analysis",
#'   app_data_connection = app_conn,
#'   config = reactive({ list(filters = list(platform_id = input$platform)) })
#' )
#' @export
positionKFEComponent <- function(id, app_data_connection = NULL, config = NULL, translate = identity, display_mode = "full") {
  list(
    ui = list(filter = if (display_mode == "full") positionKFEFilterUI(id, translate) else NULL,
              display = positionKFEDisplayUI(id, translate, mode = display_mode)),
    server = function(input, output, session) {
      positionKFEServer(id, app_data_connection, config, session, display_mode = display_mode)
    }
  )
}
