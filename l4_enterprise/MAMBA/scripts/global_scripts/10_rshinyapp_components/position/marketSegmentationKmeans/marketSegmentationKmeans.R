# =============================================================================
# marketSegmentationKmeans.R
#
# QEF_DESIGN 客戶 #804 — K-means 4 步驟新分析 + 卡方檢定 baseline
# Spectra change: qef-market-segmentation-redesign Phase A.4
#
# Architecture: in-UI reactive(per user decision 2026-05-21,retiring D06
# derivation)。K-means + chi-square inline in server reactive;cached via
# shiny::bindCache for cross-session reuse。
#
# Reads (raw layer only, no derivation):
#   df_qef_attribute_metadata     (variable_id × variable_name_zh × category ×
#                                  scale_type × direction) — from
#                                  all_ETL_attribute_metadata_0IM.R(GSheet sync)
#   df_qef_customer_attributes    (customer_id × variable_id × score) — upstream
#                                  review scoring pipeline。empty / missing →
#                                  empty-state callout(MP163 progressive completeness)
#
# UI 結構（per UI_R001 + UI_R026 + UI_R028）:
#   ui_filter:
#     - Cluster select dropdown(觸發 radar / 缺點表 重繪)
#     - K override slider(optional manual k)
#     - ai_insight_button_ui(最底部 per UI_R026 layer 3)
#   ui_display:
#     - 上:Cluster overview table(cluster_label + size + distinguishing var)
#     - 中:Plotly polar radar(significant positive attributes)
#     - 中:缺點 chi-square table(direction=negative & significant)
#     - 底:ai_insight_result_ui(per UI_R026 layer 3)
#
# Why no derivation:
#   1. Algorithm < 1 second on QEF scale(<2000 customers × ~30 variables)
#   2. User wants to adjust k slider live → 必須 reactive,derivation 死預算
#   3. set.seed(42) 保 deterministic(same input → same output)
#   4. D06 group registry collision(#815)— 砍 derivation 自然解決
#
# Spec: qef-market-segmentation-redesign Phase A.4 (option A retire)
# Issue: #804(K-means analysis)+ #815(D06 collision triggered retire)
# =============================================================================

# ─── Algorithm helpers (ported verbatim from former fn_D06_01_market_segmentation_kmeans_core.R) ──

#' K-means + cluster-by-cluster verification stop criterion
#'
#' @param X numeric matrix (customers × 5-point variables)
#' @param attr_cols variable IDs corresponding to columns of X
#' @param k_min,k_max scan range (default 3..7 per #804 spec)
#' @param k_override optional user-picked k (skip scan)
#' @return list(km, chosen_k, cluster_top_var, chosen_k_log)
run_kmeans_with_chisq_stop <- function(X, attr_cols, k_min = 3L, k_max = 7L,
                                       k_override = NULL) {
  if (!is.null(k_override) && is.numeric(k_override) && k_override >= 2L) {
    set.seed(42)
    km <- stats::kmeans(X, centers = as.integer(k_override),
                        nstart = 25, iter.max = 100)
    return(list(
      km = km,
      chosen_k = as.integer(k_override),
      cluster_top_var = compute_cluster_top_var(km, X, attr_cols),
      chosen_k_log = sprintf("k=%d (user override)", k_override)
    ))
  }

  for (k in k_min:k_max) {
    set.seed(42)
    km <- tryCatch(
      stats::kmeans(X, centers = k, nstart = 25, iter.max = 100),
      error = function(e) NULL
    )
    if (is.null(km)) next

    cluster_top_var <- compute_cluster_top_var(km, X, attr_cols)
    cluster_pass <- !is.na(cluster_top_var)
    if (all(cluster_pass)) {
      return(list(
        km = km, chosen_k = k, cluster_top_var = cluster_top_var,
        chosen_k_log = sprintf("k=%d (all clusters have distinguishing variables)", k)
      ))
    }
  }

  # Fallback per spec: k = k_max
  set.seed(42)
  km <- stats::kmeans(X, centers = k_max, nstart = 25, iter.max = 100)
  list(
    km = km, chosen_k = k_max,
    cluster_top_var = compute_cluster_top_var(km, X, attr_cols),
    chosen_k_log = sprintf("k=%d (fallback, no convergence)", k_max)
  )
}

#' Per-cluster top distinguishing variable via chi-square (5-point → low/mid/high)
compute_cluster_top_var <- function(km, X, attr_cols) {
  k <- length(unique(km$cluster))
  cluster_top_var <- character(k)
  for (c in seq_len(k)) {
    members <- which(km$cluster == c)
    if (length(members) < 5L) {
      cluster_top_var[c] <- NA_character_
      next
    }
    pvals <- vapply(attr_cols, function(v) {
      col_vec <- X[, v]
      cluster_dist <- table(cut(col_vec[members],
                                breaks = c(0, 2.5, 3.5, 5),
                                labels = c("low", "mid", "high")))
      grand_dist <- table(cut(col_vec,
                              breaks = c(0, 2.5, 3.5, 5),
                              labels = c("low", "mid", "high")))
      rest_dist <- grand_dist - cluster_dist
      if (any(c(cluster_dist, rest_dist) < 5L)) return(1.0)
      tbl <- rbind(cluster_dist, rest_dist)
      tryCatch({
        chi <- suppressWarnings(stats::chisq.test(tbl))
        chi$p.value
      }, error = function(e) 1.0)
    }, numeric(1), USE.NAMES = TRUE)

    sig_vars <- names(pvals)[pvals < 0.05]
    cluster_top_var[c] <- if (length(sig_vars) >= 1L) {
      sig_vars[which.min(pvals[sig_vars])]
    } else {
      NA_character_
    }
  }
  cluster_top_var
}

#' Profile chi-square for 2-point profile variables (情感 / 人 / 場 / 文化 / 美學 / 身份認同)
#' Returns long-format data.frame(cluster_id × variable_id × statistic × p_value × is_significant)
compute_profile_chisq_table <- function(clusters_df, customer_attrs_long, metadata) {
  PROFILE_CATEGORIES <- c("情感", "人", "場", "文化", "美學", "身份認同")
  profile_vars <- metadata$variable_id[
    metadata$scale_type == "2_point" & metadata$category %in% PROFILE_CATEGORIES
  ]
  if (length(profile_vars) == 0L) {
    return(data.frame(
      cluster_id = integer(0), variable_id = character(0),
      chi_square_statistic = numeric(0), chi_square_p_value = numeric(0),
      is_significant = logical(0)
    ))
  }
  responses_2pt <- customer_attrs_long[customer_attrs_long$variable_id %in% profile_vars, ]
  merged <- merge(clusters_df, responses_2pt, by = "customer_id", all.x = FALSE)

  results <- list()
  idx <- 0L
  for (c in unique(clusters_df$cluster_id)) {
    cluster_member_ids <- clusters_df$customer_id[clusters_df$cluster_id == c]
    for (v in profile_vars) {
      v_data <- merged[merged$variable_id == v, ]
      cluster_v <- v_data[v_data$customer_id %in% cluster_member_ids, "score"]
      rest_v <- v_data[!v_data$customer_id %in% cluster_member_ids, "score"]
      idx <- idx + 1L
      if (length(cluster_v) < 5L || length(rest_v) < 5L) {
        results[[idx]] <- data.frame(
          cluster_id = c, variable_id = v,
          chi_square_statistic = NA_real_, chi_square_p_value = NA_real_,
          is_significant = FALSE
        )
        next
      }
      cluster_tbl <- table(factor(cluster_v, levels = c(0, 1)))
      rest_tbl <- table(factor(rest_v, levels = c(0, 1)))
      tbl <- rbind(cluster_tbl, rest_tbl)
      chi <- tryCatch(suppressWarnings(stats::chisq.test(tbl)),
                      error = function(e) list(statistic = NA, p.value = NA))
      results[[idx]] <- data.frame(
        cluster_id = c, variable_id = v,
        chi_square_statistic = as.numeric(chi$statistic),
        chi_square_p_value = as.numeric(chi$p.value),
        is_significant = !is.na(chi$p.value) && chi$p.value < 0.05
      )
    }
  }
  do.call(rbind, results)
}

# ─── Component ──

marketSegmentationKmeansComponent <- function(id, app_connection, comp_config, translate = identity) {
  ns <- shiny::NS(id)

  # ---- UI ----
  ui_filter <- shiny::tagList(
    shiny::selectInput(
      ns("selected_cluster"),
      label = translate("Cluster"),
      choices = c("(load data first)" = ""),
      selected = NULL
    ),
    shiny::sliderInput(
      ns("k_override"),
      label = translate("k (0 = auto-find)"),
      min = 0, max = 7, value = 0, step = 1
    ),
    shiny::helpText(translate("k=0 uses cluster-by-cluster verification stop (3..7). Set 2-7 to override.")),
    ai_insight_button_ui(ns, translate)
  )

  ui_display <- shiny::tagList(
    shiny::uiOutput(ns("empty_state_card")),
    shiny::fluidRow(shiny::column(12, bs4Dash::bs4Card(
      title = translate("Segment Overview"),
      status = "primary", width = 12, solidHeader = TRUE, elevation = 3,
      DT::DTOutput(ns("cluster_overview_table"))
    ))),
    shiny::fluidRow(shiny::column(12, bs4Dash::bs4Card(
      title = translate("Cluster Profile Radar (significant positive attributes)"),
      status = "info", width = 12, solidHeader = TRUE, elevation = 3,
      plotly::plotlyOutput(ns("profile_radar"), height = "500px")
    ))),
    shiny::fluidRow(shiny::column(12, bs4Dash::bs4Card(
      title = translate("Negative Attributes (chi-square significant)"),
      status = "warning", width = 12, solidHeader = TRUE, elevation = 3,
      DT::DTOutput(ns("negative_attribute_table"))
    ))),
    shiny::fluidRow(shiny::column(12, ai_insight_result_ui(ns, translate)))
  )

  # ---- Server ----
  server_fn <- function(input, output, session) {
    shiny::moduleServer(id, function(input, output, session) {

      # Raw layer data loaders
      attribute_metadata <- shiny::reactive({
        if (is.null(app_connection) || !DBI::dbIsValid(app_connection)) return(NULL)
        tryCatch({
          if (!DBI::dbExistsTable(app_connection, "df_qef_attribute_metadata")) return(NULL)
          tbl2(app_connection, "df_qef_attribute_metadata") %>% dplyr::collect()
        }, error = function(e) {
          message("[marketSegmentationKmeans] metadata load failed: ", e$message)
          NULL
        })
      })

      customer_attrs <- shiny::reactive({
        if (is.null(app_connection) || !DBI::dbIsValid(app_connection)) return(NULL)
        tryCatch({
          if (!DBI::dbExistsTable(app_connection, "df_qef_customer_attributes")) return(NULL)
          tbl2(app_connection, "df_qef_customer_attributes") %>% dplyr::collect()
        }, error = function(e) {
          message("[marketSegmentationKmeans] customer_attrs load failed: ", e$message)
          NULL
        })
      })

      # Data-ready gate
      data_ready <- shiny::reactive({
        m <- attribute_metadata(); ca <- customer_attrs()
        !is.null(m) && !is.null(ca) && nrow(m) > 0L && nrow(ca) > 0L
      })

      # K-means + chisq pipeline (cached on metadata + customer_attrs + k_override)
      segmentation_result <- shiny::reactive({
        if (!data_ready()) return(NULL)
        m <- attribute_metadata()
        ca <- customer_attrs()

        # Filter to 5-point variables for clustering
        m_5pt <- m[m$scale_type == "5_point", , drop = FALSE]
        if (nrow(m_5pt) == 0L) {
          warning("[marketSegmentationKmeans] no 5_point variables in metadata")
          return(NULL)
        }
        variable_ids_5pt <- m_5pt$variable_id

        # Pivot to wide
        attr_wide <- tidyr::pivot_wider(
          ca[ca$variable_id %in% variable_ids_5pt, ],
          id_cols = customer_id, names_from = variable_id,
          values_from = score, values_fill = NA_real_
        )
        customer_ids <- attr_wide$customer_id
        attr_cols <- intersect(colnames(attr_wide), variable_ids_5pt)
        X <- as.matrix(attr_wide[, attr_cols, drop = FALSE])

        # Impute NA with column mean
        for (j in seq_len(ncol(X))) {
          na_mask <- is.na(X[, j])
          if (any(na_mask)) {
            col_mean <- mean(X[, j], na.rm = TRUE)
            X[na_mask, j] <- if (is.finite(col_mean)) col_mean else 3
          }
        }

        # Run K-means (with optional user override)
        k_override_val <- if (is.numeric(input$k_override) && input$k_override >= 2L) {
          as.integer(input$k_override)
        } else NULL
        res <- run_kmeans_with_chisq_stop(X, attr_cols, k_override = k_override_val)

        # Cluster label (category:variable_name_zh)
        var_name_map <- stats::setNames(m_5pt$variable_name_zh, m_5pt$variable_id)
        var_cat_map  <- stats::setNames(m_5pt$category, m_5pt$variable_id)
        cluster_labels <- ifelse(
          is.na(res$cluster_top_var),
          sprintf("Cluster %d", seq_along(res$cluster_top_var)),
          paste0(var_cat_map[res$cluster_top_var], ":", var_name_map[res$cluster_top_var])
        )

        clusters_df <- data.frame(
          customer_id = customer_ids,
          cluster_id = res$km$cluster,
          cluster_label = cluster_labels[res$km$cluster],
          chosen_k = res$chosen_k,
          distinguishing_variable = res$cluster_top_var[res$km$cluster],
          stringsAsFactors = FALSE
        )

        # Profile chi-square table
        profiles_df <- compute_profile_chisq_table(clusters_df, ca, m)

        list(
          clusters = clusters_df,
          profiles = profiles_df,
          metadata = m,
          chosen_k = res$chosen_k,
          chosen_k_log = res$chosen_k_log
        )
      }) |> shiny::bindCache(attribute_metadata(), customer_attrs(), input$k_override) |>
        shiny::bindEvent(attribute_metadata(), customer_attrs(), input$k_override, ignoreNULL = TRUE)

      # Empty-state callout
      output$empty_state_card <- shiny::renderUI({
        if (data_ready()) return(NULL)
        shiny::fluidRow(shiny::column(12, shiny::tags$div(
          class = "callout callout-info",
          shiny::tags$h5(shiny::icon("info-circle"), translate("Market Segmentation data not yet available")),
          shiny::tags$p(translate("Required tables: df_qef_attribute_metadata + df_qef_customer_attributes")),
          shiny::tags$p(translate("Source: GSheet attribute survey (synced via all_ETL_attribute_metadata_0IM.R)"))
        )))
      })

      # Cluster select choices
      shiny::observe({
        result <- segmentation_result()
        if (is.null(result)) {
          shiny::updateSelectInput(session, "selected_cluster",
                                   choices = c("(load data first)" = ""))
          return()
        }
        cluster_options <- result$clusters %>%
          dplyr::distinct(cluster_id, cluster_label) %>%
          dplyr::arrange(cluster_id)
        choices <- stats::setNames(
          as.character(cluster_options$cluster_id),
          cluster_options$cluster_label
        )
        shiny::updateSelectInput(session, "selected_cluster",
                                 choices = choices, selected = choices[1])
      })

      # Cluster overview table
      output$cluster_overview_table <- DT::renderDT({
        result <- segmentation_result()
        if (is.null(result)) return(NULL)
        cd <- result$clusters
        size_tbl <- cd %>%
          dplyr::group_by(cluster_id, cluster_label) %>%
          dplyr::summarise(
            n_customers = dplyr::n(),
            chosen_k = dplyr::first(chosen_k),
            distinguishing_variable = dplyr::first(distinguishing_variable),
            .groups = "drop"
          )
        DT::datatable(
          size_tbl, rownames = FALSE,
          colnames = c(
            translate("Cluster"), translate("Label"), translate("Customers"),
            translate("k"), translate("Distinguishing Variable")
          ),
          options = list(pageLength = 7, dom = "t")
        )
      })

      # Radar chart (significant positive attributes)
      output$profile_radar <- plotly::renderPlotly({
        result <- segmentation_result()
        if (is.null(result)) return(NULL)
        sel <- input$selected_cluster
        if (is.null(sel) || sel == "") return(NULL)
        cluster_id_sel <- as.integer(sel)

        pd <- result$profiles
        m <- result$metadata
        radar_df <- pd[pd$cluster_id == cluster_id_sel & pd$is_significant, , drop = FALSE]
        radar_df <- merge(
          radar_df,
          m[, c("variable_id", "variable_name_zh", "direction"), drop = FALSE],
          by = "variable_id", all.x = TRUE
        )
        radar_df <- radar_df[is.na(radar_df$direction) | radar_df$direction != "negative", ]
        if (nrow(radar_df) == 0L) {
          return(plotly::plot_ly() %>%
                   plotly::layout(title = translate("No significant positive attributes")))
        }
        max_stat <- max(radar_df$chi_square_statistic, na.rm = TRUE)
        if (!is.finite(max_stat) || max_stat == 0) max_stat <- 1
        radar_df$normalized <- radar_df$chi_square_statistic / max_stat
        labels <- ifelse(is.na(radar_df$variable_name_zh),
                         radar_df$variable_id, radar_df$variable_name_zh)
        plotly::plot_ly(
          type = "scatterpolar",
          r = c(radar_df$normalized, radar_df$normalized[1]),
          theta = c(labels, labels[1]),
          fill = "toself",
          name = paste(translate("Cluster"), cluster_id_sel)
        ) %>%
          plotly::layout(
            polar = list(radialaxis = list(visible = TRUE, range = c(0, 1))),
            showlegend = FALSE
          )
      })

      # Negative-attribute table
      output$negative_attribute_table <- DT::renderDT({
        result <- segmentation_result()
        if (is.null(result)) return(NULL)
        sel <- input$selected_cluster
        if (is.null(sel) || sel == "") return(NULL)
        cluster_id_sel <- as.integer(sel)
        pd <- result$profiles
        m <- result$metadata
        neg_df <- pd[pd$cluster_id == cluster_id_sel & pd$is_significant, , drop = FALSE]
        neg_df <- merge(
          neg_df,
          m[, c("variable_id", "variable_name_zh", "direction"), drop = FALSE],
          by = "variable_id", all.x = TRUE
        )
        neg_df <- neg_df[!is.na(neg_df$direction) & neg_df$direction == "negative", ]
        if (nrow(neg_df) == 0L) return(NULL)
        show_df <- neg_df[, c("variable_name_zh", "chi_square_statistic", "chi_square_p_value")]
        DT::datatable(
          show_df, rownames = FALSE,
          colnames = c(
            translate("Attribute"),
            translate("Chi-square statistic"),
            translate("p-value")
          ),
          options = list(pageLength = 10, dom = "tp")
        ) %>%
          DT::formatRound(c("chi_square_statistic", "chi_square_p_value"), digits = 4)
      })

      # AI insight wire (unchanged)
      gpt_key <- Sys.getenv("OPENAI_API_KEY", "")
      ai_task <- create_ai_insight_task(gpt_key)
      setup_ai_insight_server(
        input, output, session, ns,
        task = ai_task,
        gpt_key = gpt_key,
        prompt_key = "brandedge_market_segmentation_summary",
        get_template_vars = function() {
          result <- segmentation_result()
          if (is.null(result)) return(NULL)
          sel <- input$selected_cluster
          if (is.null(sel) || sel == "") return(NULL)
          cluster_id_sel <- as.integer(sel)
          cd <- result$clusters
          cd_one <- cd[cd$cluster_id == cluster_id_sel, ]
          pd <- result$profiles
          pd_sig <- pd[pd$cluster_id == cluster_id_sel & pd$is_significant, ]
          list(
            cluster_label = if (nrow(cd_one) > 0) cd_one$cluster_label[1] else "(unknown)",
            n_customers = nrow(cd_one),
            significant_attributes_count = nrow(pd_sig),
            chosen_k = result$chosen_k,
            distinguishing_variables = if (nrow(cd_one) > 0) {
              paste(unique(cd_one$distinguishing_variable), collapse = ", ")
            } else ""
          )
        },
        component_label = "marketSegmentationKmeans",
        scope_provider = default_scope_provider(comp_config, translate)
      )
    })
  }

  list(ui = list(filter = ui_filter, display = ui_display), server = server_fn)
}
