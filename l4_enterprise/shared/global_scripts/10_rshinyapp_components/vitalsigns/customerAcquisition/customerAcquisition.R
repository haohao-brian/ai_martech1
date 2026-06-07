# =============================================================================
# customerAcquisition.R — Customer Acquisition Component (VitalSigns)
# CONSUMES: df_dna_by_customer (from D01)
# Following: UI_R001, UI_R011, MP064, MP029, DEV_R001
# =============================================================================

customerAcquisitionComponent <- function(id, app_connection, comp_config, translate) {
  ns <- NS(id)

  # ---- UI ----
  ui_filter <- tagList(
    ai_insight_button_ui(ns, translate)
  )

  ui_display <- tagList(
    # KPI Row
    fluidRow(
      column(3, uiOutput(ns("kpi_active"))),
      column(3, uiOutput(ns("kpi_total"))),
      column(3, uiOutput(ns("kpi_new_rate"))),
      column(3, uiOutput(ns("kpi_conversion_rate")))
    ),
    # Charts Row
    fluidRow(
      column(6, bs4Card(title = translate("Customer Structure"), status = "primary",
        width = 12, solidHeader = TRUE, plotly::plotlyOutput(ns("structure_pie"), height = "350px"))),
      column(6, bs4Card(title = translate("Acquisition Funnel"), status = "success",
        width = 12, solidHeader = TRUE, plotly::plotlyOutput(ns("funnel_chart"), height = "350px")))
    ),
    # #802 fix: 購買次數分布(distribution view,各次合計 = 100%)
    fluidRow(
      column(12, bs4Card(title = translate("Purchase Frequency Distribution"), status = "info",
        width = 12, solidHeader = TRUE,
        tags$small(style = "color: #888;",
                   translate("Distribution view: mutually exclusive buckets sum to 100%. Compare with the cumulative Acquisition Funnel above.")),
        plotly::plotlyOutput(ns("frequency_distribution_chart"), height = "300px")))
    ),
    # Customer Detail Table
    fluidRow(
      column(12, bs4Card(title = translate("Customer Acquisition Detail"), status = "primary",
        width = 12, solidHeader = TRUE,
        downloadButton(ns("download_csv"), translate("Download CSV"), class = "btn-sm btn-outline-primary mb-2"),
        DT::dataTableOutput(ns("detail_table"))))
    ),
    # AI Insight Result — bottom of display (GUIDE03)
    fluidRow(
      column(12, ai_insight_result_ui(ns, translate))
    )
  )

  # ---- Server ----
  server_fn <- function(input, output, session) {
    moduleServer(id, function(input, output, session) {

      dna_data <- reactive({
        cfg <- comp_config()
        req(cfg$filters$platform_id)
        # #376: Migrated from raw DBI::dbGetQuery() to tbl2() per DM_R023 v1.2
        tryCatch({
          plt <- cfg$filters$platform_id
          country <- cfg$filters$country
          pl_id <- cfg$filters$product_line_id_sliced
          if (is.null(pl_id) || pl_id == "all") pl_id <- "all"

          dna_lazy <- tbl2(app_connection, "df_dna_by_customer") %>%
            dplyr::filter(platform_id == !!plt,
                          product_line_id_filter == !!pl_id)

          if (!is.null(country) && country != "all") {
            country_map_lazy <- tbl2(app_connection, "df_customer_country_map") %>%
              dplyr::filter(platform_id == !!plt, ship_country == !!country) %>%
              dplyr::select(customer_id)
            dna_lazy <- dna_lazy %>%
              dplyr::semi_join(country_map_lazy, by = "customer_id")
          }

          df <- dna_lazy %>%
            dplyr::select(customer_id, nes_status, f_value, ni, m_value,
                          total_spent, r_value, clv, nrec_prob) %>%
            dplyr::collect()

          if (nrow(df) == 0) { message("[customerAcquisition] No data returned"); return(NULL) }

          # Preserve legacy column aliases used by downstream reactives
          df <- dplyr::rename(df,
                              ni_count = ni,
                              spent_total = total_spent,
                              clv_value = clv)

          message("[customerAcquisition] Loaded ", nrow(df), " records | cols: ", paste(names(df), collapse=", "))
          message("[customerAcquisition] UI targets: kpi_active, kpi_total, kpi_new_rate, kpi_conversion_rate, structure_pie, funnel_chart, detail_table")
          df
        }, error = function(e) {
          message("[customerAcquisition] Data load error: ", e$message)
          NULL
        })
      })

      # KPIs
      output$kpi_active <- renderUI({
        df <- dna_data()
        if (is.null(df)) return(bs4ValueBox(value = "-", subtitle = translate("Customer Total"),
                                            icon = icon("users"), color = "success", width = 12))
        n_active <- sum(df$nes_status %in% c("N", "E0"), na.rm = TRUE)
        bs4ValueBox(value = format(n_active, big.mark = ","), subtitle = translate("Customer Total"),
                    icon = icon("users"), color = "success", width = 12)
      })

      output$kpi_total <- renderUI({
        df <- dna_data()
        val <- if (is.null(df)) "-" else format(nrow(df), big.mark = ",")
        bs4ValueBox(value = val, subtitle = translate("Cumulative Customers"),
                    icon = icon("database"), color = "primary", width = 12)
      })

      output$kpi_new_rate <- renderUI({
        df <- dna_data()
        if (is.null(df)) return(bs4ValueBox(value = "-", subtitle = translate("Customer Growth Rate"),
                                            icon = icon("user-plus"), color = "info", width = 12))
        n_new <- sum(df$nes_status == "N", na.rm = TRUE)
        pct <- round(n_new / nrow(df) * 100, 1)
        bs4ValueBox(value = paste0(pct, "%"), subtitle = translate("Customer Growth Rate"),
                    icon = icon("user-plus"), color = "info", width = 12)
      })

      # Repurchase rate (#320 + #801 rename): repeat buyers (ni>=2) / total customers
      # 命名修正(#800/#801): 原為 "Conversion Rate" 跟「新客比率」加總恰 100% → 互補定義語意混淆
      #   - 「轉化率」業界標準 = funnel 階段間 conditional probability,非「重複購買率」
      #   - 此 KPI 實際 = (購買 ≥ 2 次)/總客戶 = 「回購率」(repurchase rate)
      #   - 改名後 + 跟「新客比率」不再 misleading 加總 = 100%
      # 元件 ID 維持 kpi_conversion_rate(避免 breaking change),subtitle / label 改 "Repurchase Rate"
      output$kpi_conversion_rate <- renderUI({
        df <- dna_data()
        if (is.null(df) || nrow(df) == 0) return(bs4ValueBox(value = "-", subtitle = translate("Repurchase Rate"),
                                            icon = icon("exchange-alt"), color = "purple", width = 12))
        n_repeat <- sum(df$ni_count >= 2, na.rm = TRUE)
        pct <- round(n_repeat / nrow(df) * 100, 1)
        bs4ValueBox(
          value = paste0(pct, "%"),
          subtitle = translate("Repurchase Rate"),
          # #801 公式透明:tooltip 顯示分子/分母定義
          footer = tags$small(style = "opacity: 0.85;",
                              translate("Formula: purchases >= 2 / total customers")),
          icon = icon("exchange-alt"), color = "purple", width = 12
        )
      })

      # Customer structure pie
      output$structure_pie <- renderPlotly({
        df <- dna_data()
        if (is.null(df)) return(plotly::plot_ly() %>% plotly::layout(title = translate("No Data")))

        tbl <- as.data.frame(table(df$nes_status), stringsAsFactors = FALSE)
        names(tbl) <- c("status", "count")
        labels <- c(N = translate("New"), E0 = translate("Core"),
                     S1 = translate("Drowsy"), S2 = translate("Half-Sleeping"), S3 = translate("Dormant"))
        tbl$label <- ifelse(tbl$status %in% names(labels), labels[tbl$status], tbl$status)
        colors <- c(N = "#17a2b8", E0 = "#28a745", S1 = "#ffc107", S2 = "#fd7e14", S3 = "#dc3545")

        plotly::plot_ly(tbl, labels = ~label, values = ~count, type = "pie",
                        marker = list(colors = colors[tbl$status]),
                        textinfo = "label+percent+value") %>%
          plotly::layout(showlegend = TRUE)
      })

      # Acquisition funnel (#800 fix: strict nested subsets)
      # Bug 原狀:n_core = sum(nes_status == "E0") 不嚴格 nested in n_multi —
      #   E0 (NES 主力客)定義為「近期活躍 + 多購」,可能含 purchase_count < 4 的活躍客戶 →
      #   階段間出現「回購 + 多次 + 核心 加總 > 100%」(per #800 客戶反映)
      # Fix:全部階段以 purchase_count(ni_count)為唯一 criterion,strict nested:
      #   Stage 1 (首購) ⊇ Stage 2 (回購 ≥ 2) ⊇ Stage 3 (多次 ≥ 4) ⊇ Stage 4 (重度 ≥ 7)
      # NES E0 仍可在其他 KPI / chart 使用,但 funnel 階段不混用 NES status。
      output$funnel_chart <- renderPlotly({
        df <- dna_data()
        if (is.null(df)) return(plotly::plot_ly() %>% plotly::layout(title = translate("No Data")))

        # 分母:dna_data() 含「有購買的客戶」— 與 KPI cards 一致 (#800 denominator consistency)
        total <- nrow(df)
        n_first  <- total
        n_repeat <- sum(df$ni_count >= 2, na.rm = TRUE)
        n_multi  <- sum(df$ni_count >= 4, na.rm = TRUE)
        # #800: Stage 4 改用 purchase_count >= 7 嚴格 nested in Stage 3
        n_heavy  <- sum(df$ni_count >= 7, na.rm = TRUE)

        # Assert nested (defensive check; should always hold given strict criterion)
        if (!(n_first >= n_repeat && n_repeat >= n_multi && n_multi >= n_heavy)) {
          message("[customerAcquisition] WARN funnel stages not strictly nested — investigate ni_count integrity")
        }

        funnel_df <- data.frame(
          stage = c(translate("First Purchase"), translate("Repeat Purchase"),
                    translate("Multi-Purchase (4+)"), translate("Heavy Buyer (7+)")),
          count = c(n_first, n_repeat, n_multi, n_heavy),
          stringsAsFactors = FALSE
        )
        funnel_df$stage <- factor(funnel_df$stage, levels = rev(funnel_df$stage))
        colors <- c("#007bff", "#17a2b8", "#28a745", "#dc3545")

        plotly::plot_ly(funnel_df, y = ~stage, x = ~count, type = "bar", orientation = "h",
                        marker = list(color = rev(colors)),
                        text = ~paste0(count, " (", round(count / total * 100, 1), "%)"),
                        textposition = "auto") %>%
          plotly::layout(
            xaxis = list(title = translate("Customer Count")),
            yaxis = list(title = ""),
            margin = list(l = 150),
            # #800: tooltip 揭露分母定義(per DEV_R053 spirit + #801 公式透明要求)
            annotations = list(
              list(x = 1, y = -0.15, xref = "paper", yref = "paper", xanchor = "right", yanchor = "top",
                   showarrow = FALSE,
                   text = paste0("<i>", translate("Denominator: customers with purchase N ="), " ",
                                 format(total, big.mark = ","), ". ",
                                 translate("Stages strictly nested by purchase count."), "</i>"),
                   font = list(size = 10, color = "#888"))
            )
          )
      })

      # #802 fix: Purchase frequency distribution (mutually exclusive buckets, sum = 100%)
      # 對照 funnel_chart (cumulative nested view) — distribution 是互斥 partition view
      output$frequency_distribution_chart <- renderPlotly({
        df <- dna_data()
        if (is.null(df) || nrow(df) == 0) return(plotly::plot_ly() %>% plotly::layout(title = translate("No Data")))

        total <- nrow(df)
        # Mutually exclusive purchase-count buckets
        n_1     <- sum(df$ni_count == 1, na.rm = TRUE)
        n_2_3   <- sum(df$ni_count >= 2 & df$ni_count <= 3, na.rm = TRUE)
        n_4_6   <- sum(df$ni_count >= 4 & df$ni_count <= 6, na.rm = TRUE)
        n_7_plus <- sum(df$ni_count >= 7, na.rm = TRUE)

        # Defensive assert: sum should equal total (mutually exclusive partition)
        if (n_1 + n_2_3 + n_4_6 + n_7_plus != total) {
          message("[customerAcquisition] WARN distribution sum != total — investigate ni_count NA / non-positive")
        }

        dist_df <- data.frame(
          bucket = c(translate("1 purchase"),
                     translate("2-3 purchases"),
                     translate("4-6 purchases"),
                     translate("7+ purchases (heavy)")),
          count = c(n_1, n_2_3, n_4_6, n_7_plus),
          stringsAsFactors = FALSE
        )
        dist_df$pct <- round(dist_df$count / total * 100, 1)

        plotly::plot_ly(dist_df, x = ~bucket, y = ~count, type = "bar",
                        marker = list(color = c("#007bff", "#17a2b8", "#28a745", "#dc3545")),
                        text = ~paste0(count, "<br>", pct, "%"),
                        textposition = "auto",
                        hovertemplate = ~paste0(bucket, ": ", count, " (", pct, "%)<extra></extra>")) %>%
          plotly::layout(
            xaxis = list(title = ""),
            yaxis = list(title = translate("Customer Count")),
            annotations = list(
              list(x = 1, y = -0.2, xref = "paper", yref = "paper", xanchor = "right", yanchor = "top",
                   showarrow = FALSE,
                   text = paste0("<i>",
                                 translate("Mutually exclusive partition: sum ="), " ",
                                 format(total, big.mark = ","), " (100%)</i>"),
                   font = list(size = 10, color = "#888"))
            )
          )
      })

      # Detail table
      output$detail_table <- DT::renderDataTable({
        df <- dna_data()
        if (is.null(df)) return(DT::datatable(data.frame(Message = translate("Please run ETL pipeline first"))))

        show_df <- data.frame(
          ID = df$customer_id,
          Status = sapply(as.character(df$nes_status), function(code) {
            key <- paste0("NES Status - ", code)
            translated <- translate(key)
            if (identical(translated, key)) code else translated
          }, USE.NAMES = FALSE),
          Purchases = df$ni_count,
          Frequency = df$f_value,
          Total_Spent = round(df$spent_total, 0),
          CLV = round(df$clv_value, 0),
          Recency = round(df$r_value, 0),
          stringsAsFactors = FALSE
        )
        show_df <- show_df[order(-show_df$Total_Spent), ]
        names(show_df) <- c("ID", translate("Status"), translate("Purchases"),
                            translate("Frequency"), translate("Total Spent"),
                            translate("CLV"), translate("Recency"))

        DT::datatable(show_df,
          filter = "top", rownames = FALSE,
          options = list(pageLength = 15, scrollX = TRUE, dom = "lftip",
                         language = list(url = "//cdn.datatables.net/plug-ins/1.13.7/i18n/zh-HANT.json")))
      })

      # AI Insight — non-blocking via ExtendedTask (GUIDE03, TD_P004 compliant)
      gpt_key <- Sys.getenv("OPENAI_API_KEY", "")
      ai_task <- create_ai_insight_task(gpt_key)

      setup_ai_insight_server(
        input, output, session, ns,
        task = ai_task,
        gpt_key = gpt_key,
        prompt_key = "vitalsigns_analysis.acquisition_insights",
        get_template_vars = function() {
          df <- dna_data()
          if (is.null(df) || nrow(df) == 0) return(NULL)

          n <- nrow(df)
          nes_tbl <- table(df$nes_status)
          nes_pcts <- round(prop.table(nes_tbl) * 100, 1)

          n_repeat <- sum(df$ni_count >= 2, na.rm = TRUE)
          n_multi <- sum(df$ni_count >= 4, na.rm = TRUE)
          n_core <- sum(df$nes_status == "E0", na.rm = TRUE)

          # Build filter context for AI (#324)
          cfg <- comp_config()
          pl <- cfg$filters$product_line_id_sliced
          cty <- cfg$filters$country
          filter_context_str <- paste0(
            "Analysis scope:\n",
            "- Platform: ", cfg$filters$platform_id, "\n",
            "- Product line: ", if (!is.null(pl) && pl != "all") pl else "All", "\n",
            "- Country: ", if (!is.null(cty) && cty != "all") cty else "All"
          )

          list(
            filter_context = filter_context_str,
            total_customers = as.character(n),
            nes_distribution = paste0(
              paste(names(nes_tbl), ": ", nes_tbl, " (", nes_pcts, "%)", sep = "", collapse = "\n")
            ),
            funnel_summary = paste0(
              "First purchase: ", n, " (100%)\n",
              "Repeat purchase (2+): ", n_repeat, " (", round(n_repeat / n * 100, 1), "%)\n",
              "Multi-purchase (4+): ", n_multi, " (", round(n_multi / n * 100, 1), "%)\n",
              "Core customer (E0): ", n_core, " (", round(n_core / n * 100, 1), "%)"
            ),
            spending_summary = paste0(
              "Avg order value: $", format(round(mean(df$m_value, na.rm = TRUE), 0), big.mark = ","), "\n",
              "Avg total spent: $", format(round(mean(df$spent_total, na.rm = TRUE), 0), big.mark = ","), "\n",
              "Avg CLV: $", format(round(mean(df$clv_value, na.rm = TRUE), 0), big.mark = ",")
            )
          )
        },
        component_label = "customerAcquisition",
        # #796 fix: wire scope label so UI shows current platform / product_line
        scope_provider = default_scope_provider(comp_config, translate)
      )

      output$download_csv <- downloadHandler(
        filename = function() paste0("customer_acquisition_", Sys.Date(), ".csv"),
        content = function(file) {
          df <- dna_data()
          if (!is.null(df)) {
            con <- file(file, "wb")
            writeBin(charToRaw("\xef\xbb\xbf"), con)
            close(con)
            # write.table (NOT write.csv) — write.csv ignores append=TRUE (DEV_R051)
            utils::write.table(df, file, row.names = FALSE, sep = ",",
                               quote = TRUE, append = TRUE, fileEncoding = "UTF-8")
          }
        }
      )

    })
  }

  list(ui = list(filter = ui_filter, display = ui_display), server = server_fn)
}
