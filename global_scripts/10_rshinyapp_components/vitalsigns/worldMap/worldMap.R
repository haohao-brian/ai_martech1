# =============================================================================
# worldMap.R — World Market Map Component (VitalSigns)
# CONSUMES: df_geo_sales_by_country, df_geo_sales_by_state (from D03_01)
# Following: UI_R001, UI_R011, UI_R028, MP064, MP029, DEV_R050, 10-ui-layout
# =============================================================================

worldMapComponent <- function(id, app_connection, comp_config, translate) {
  ns <- NS(id)

  # ---- KPI choices (DEV_R050: display text from translate, not hardcoded) ----
  kpi_choices <- c(
    "revenue"   = "revenue",
    "orders"    = "orders",
    "customers" = "customers",
    "aov"       = "aov"
  )

  # ---- UI ----
  # #348: Filter only has KPI select + AI button.
  # Country select and view_mode radio removed — drill-down via map click.
  ui_filter <- tagList(
    selectInput(
      ns("kpi_select"),
      label = translate("Select KPI"),
      choices = stats::setNames(
        kpi_choices,
        c(translate("Revenue"), translate("Order Count"),
          translate("Customer Count"), translate("Avg Order Value"))
      ),
      selected = "revenue"
    ),
    ai_insight_button_ui(ns, translate)
  )

  ui_display <- tagList(
    # KPI Row
    fluidRow(
      column(3, uiOutput(ns("kpi_countries"))),
      column(3, uiOutput(ns("kpi_largest"))),
      column(3, uiOutput(ns("kpi_top3_share"))),
      column(3, uiOutput(ns("kpi_total_revenue")))
    ),
    # Map Row — #348: back button shown when drilled into states
    fluidRow(
      column(12, bs4Card(
        title = uiOutput(ns("map_title")),
        status = "primary",
        width = 12, solidHeader = TRUE,
        plotly::plotlyOutput(ns("geo_map"), height = "480px")
      ))
    ),
    # Detail Table
    fluidRow(
      column(12, bs4Card(
        title = uiOutput(ns("detail_title")), status = "primary",
        width = 12, solidHeader = TRUE,
        downloadButton(ns("download_csv"), translate("Download CSV"),
                       class = "btn-sm btn-outline-primary mb-2"),
        DT::dataTableOutput(ns("detail_table"))
      ))
    ),
    # AI Insight Result — bottom of display (10-ui-layout)
    fluidRow(
      column(12, ai_insight_result_ui(ns, translate))
    )
  )

  # ---- Server ----
  server_fn <- function(input, output, session) {
    moduleServer(id, function(input, output, session) {

      # #348: View mode controlled by reactiveVal, not radioButtons
      view_mode <- reactiveVal("world")

      # ---- Selected state for city drill-down (#418) ----
      selected_state <- reactiveVal(NULL)

      # ---- Map title: changes based on current view (#351, #418) ----
      output$map_title <- renderUI({
        v <- view_mode()
        if (v == "us_cities") {
          tagList(
            icon("city"),
            " ",
            sprintf("%s — %s", translate("US Cities Distribution"),
                    selected_state() %||% ""),
            tags$small(
              style = "color: #ffffffcc; margin-left: 12px; font-weight: normal;",
              translate("Click outside cities to return")
            )
          )
        } else if (v == "us_states") {
          # #351: click map background to return (UX_R001: single-click)
          tagList(
            icon("flag-usa"),
            " ",
            translate("US States Distribution"),
            tags$small(
              style = "color: #ffffffcc; margin-left: 12px; font-weight: normal;",
              translate("Click outside states to return")
            )
          )
        } else {
          translate("World Market Distribution")
        }
      })

      # ---- Detail card title (#565: view-aware) ----
      output$detail_title <- renderUI({
        v <- view_mode()
        if (v == "us_cities") translate("City Details")
        else if (v == "us_states") translate("State Details")
        else translate("Country Details")
      })

      # ---- Background-click navigation: gradient back-step (#351, #418) ----
      # state bg → world; city bg → state (NOT skip-2 to world, per Plan)
      observeEvent(input$state_bg_click, {
        view_mode("world")
        selected_state(NULL)
        message("[worldMap] Back to world view (state bg click)")
      })

      observeEvent(input$city_bg_click, {
        view_mode("us_states")
        message("[worldMap] Back to state view (city bg click)")
      })

      # ---- Plotly click: drill down through 3-level chain (#348, #418) ----

      # plotly source IDs must be namespaced in modules (uses root session input)
      world_source <- session$ns("worldmap")

      # World map: click US -> drill to states (#348)
      observe({
        click <- plotly::event_data("plotly_click", source = world_source, priority = "event")
        if (is.null(click)) return()
        loc <- click$customdata
        message("[worldMap] World map clicked: customdata=", loc)
        if (!is.null(loc) && loc %in% c("USA", "US")) {
          view_mode("us_states")
          message("[worldMap] Drilled into US states")
        }
      })

      # State map: click a state -> drill to city view (#418)
      observe({
        click <- plotly::event_data("plotly_click", source = session$ns("statemap"),
                                    priority = "event")
        if (is.null(click)) return()
        st <- click$location
        message("[worldMap] State map clicked: location=", st)
        if (!is.null(st) && nzchar(st)) {
          # Normalize to uppercase 2-letter ISO state code (#565 item 5).
          # Plotly returns USPS code as upper, but defensive toupper protects
          # against future click sources that might emit lowercase.
          selected_state(toupper(trimws(st)))
          view_mode("us_cities")
          message(sprintf("[worldMap] Drilled into city view for state=%s", st))
        }
      })

      # ---- Data: all countries (no country filter — #348) ----
      # #376: Migrated from raw DBI::dbGetQuery() to tbl2() per DM_R023 v1.2
      geo_data <- reactive({
        cfg <- comp_config()
        req(cfg$filters$platform_id)
        tryCatch({
          plt <- cfg$filters$platform_id
          pl_id <- cfg$filters$product_line_id_sliced
          if (is.null(pl_id) || pl_id == "all") pl_id <- "all"

          df <- tbl2(app_connection, "df_geo_sales_by_country") %>%
            dplyr::filter(platform_id == !!plt,
                          product_line_id_filter == !!pl_id) %>%
            dplyr::select(ship_country, total_revenue, order_count,
                          customer_count, avg_order_value, avg_quantity) %>%
            dplyr::collect()

          if (nrow(df) == 0) {
            message("[worldMap] No data returned")
            return(NULL)
          }
          message("[worldMap] Loaded ", nrow(df), " countries")
          df
        }, error = function(e) {
          message("[worldMap] Data load error: ", e$message)
          NULL
        })
      })

      # Helper: get column by selected KPI
      kpi_col <- reactive({
        req(input$kpi_select)
        switch(input$kpi_select,
               "revenue"   = "total_revenue",
               "orders"    = "order_count",
               "customers" = "customer_count",
               "aov"       = "avg_order_value",
               "total_revenue")
      })

      kpi_label <- reactive({
        req(input$kpi_select)
        switch(input$kpi_select,
               "revenue"   = translate("Revenue"),
               "orders"    = translate("Order Count"),
               "customers" = translate("Customer Count"),
               "aov"       = translate("Avg Order Value"),
               translate("Revenue"))
      })

      # ---- View-aware data + labels (#565: KPI/CSV/title relabel per view) ----
      # Returns list(df, name_col, level_label, total_label, largest_label,
      # top3_label) so KPIs/CSV/title can render the correct level (country/
      # state/city) without duplicating the switch logic.
      current_view <- reactive({
        v <- view_mode()
        if (v == "us_cities") {
          list(df = city_data(), name_col = "ship_city",
               total_label = translate("Total Cities"),
               largest_label = translate("Largest City"),
               top3_label = translate("Top 3 City Share"),
               name_fn = identity)
        } else if (v == "us_states") {
          list(df = state_data(), name_col = "ship_state",
               total_label = translate("Total States"),
               largest_label = translate("Largest State"),
               top3_label = translate("Top 3 State Share"),
               name_fn = identity)
        } else {
          list(df = geo_data(), name_col = "ship_country",
               total_label = translate("Total Countries"),
               largest_label = translate("Largest Market"),
               top3_label = translate("Top 3 Market Share"),
               name_fn = country_name_zh)
        }
      })

      # ---- KPIs (view-aware per #565) ----
      output$kpi_countries <- renderUI({
        cv <- current_view()
        val <- if (is.null(cv$df)) "-" else as.character(nrow(cv$df))
        bs4ValueBox(value = val, subtitle = cv$total_label,
                    icon = icon("globe"), color = "primary", width = 12)
      })

      output$kpi_largest <- renderUI({
        cv <- current_view()
        if (is.null(cv$df) || nrow(cv$df) == 0)
          return(bs4ValueBox(value = "-", subtitle = cv$largest_label,
                             icon = icon("trophy"), color = "success", width = 12))
        top <- cv$df[which.max(cv$df$total_revenue), ]
        bs4ValueBox(value = cv$name_fn(top[[cv$name_col]]),
                    subtitle = paste0(cv$largest_label, " ($",
                                      format(round(top$total_revenue, 0), big.mark = ","), ")"),
                    icon = icon("trophy"), color = "success", width = 12)
      })

      output$kpi_top3_share <- renderUI({
        cv <- current_view()
        if (is.null(cv$df) || nrow(cv$df) < 1) return(bs4ValueBox(
          value = "-", subtitle = cv$top3_label,
          icon = icon("chart-pie"), color = "info", width = 12))
        ordered <- cv$df[order(-cv$df$total_revenue), ]
        top3_rev <- sum(utils::head(ordered$total_revenue, 3))
        total_rev <- sum(ordered$total_revenue)
        pct <- round(top3_rev / total_rev * 100, 1)
        bs4ValueBox(value = paste0(pct, "%"), subtitle = cv$top3_label,
                    icon = icon("chart-pie"), color = "info", width = 12)
      })

      output$kpi_total_revenue <- renderUI({
        cv <- current_view()
        if (is.null(cv$df)) return(bs4ValueBox(value = "-", subtitle = translate("Revenue"),
                                            icon = icon("dollar-sign"), color = "warning", width = 12))
        total <- sum(cv$df$total_revenue, na.rm = TRUE)
        bs4ValueBox(value = paste0("$", format(round(total, 0), big.mark = ",")),
                    subtitle = translate("Revenue"),
                    icon = icon("dollar-sign"), color = "warning", width = 12)
      })

      # ---- State-level data ----
      # #376: Migrated from raw DBI::dbGetQuery() to tbl2() per DM_R023 v1.2
      state_data <- reactive({
        cfg <- comp_config()
        req(cfg$filters$platform_id)
        tryCatch({
          plt <- cfg$filters$platform_id
          pl_id <- cfg$filters$product_line_id_sliced
          if (is.null(pl_id) || pl_id == "all") pl_id <- "all"

          df <- tbl2(app_connection, "df_geo_sales_by_state") %>%
            dplyr::filter(platform_id == !!plt,
                          product_line_id_filter == !!pl_id) %>%
            dplyr::select(ship_state, total_revenue, order_count,
                          customer_count, avg_order_value, avg_quantity) %>%
            dplyr::collect()

          if (nrow(df) == 0) return(NULL)
          message("[worldMap] Loaded ", nrow(df), " US states")
          df
        }, error = function(e) {
          message("[worldMap] State data load error: ", e$message)
          NULL
        })
      })

      # ---- City-level data (#418, US-only, filtered by selected state) ----
      city_data <- reactive({
        cfg <- comp_config()
        req(cfg$filters$platform_id, selected_state())
        tryCatch({
          plt <- cfg$filters$platform_id
          pl_id <- cfg$filters$product_line_id_sliced
          if (is.null(pl_id) || pl_id == "all") pl_id <- "all"
          st <- selected_state()

          # Graceful: table may not exist if D03_01 hasn't yet derived it
          # (ETL ship_city propagation pending — see #418 graceful no-op)
          if (!DBI::dbExistsTable(app_connection, "df_geo_sales_by_city")) {
            message("[worldMap] df_geo_sales_by_city not in app_data (city derivation pending)")
            return(NULL)
          }

          # Case-insensitive ship_state match (#565 item 5): D03_01 may emit
          # mixed casing depending on upstream platform; normalize both sides.
          st_upper <- toupper(trimws(st))
          df <- tbl2(app_connection, "df_geo_sales_by_city") %>%
            dplyr::filter(platform_id == !!plt,
                          product_line_id_filter == !!pl_id,
                          toupper(ship_state) == !!st_upper) %>%
            dplyr::select(ship_city, total_revenue, order_count,
                          customer_count, avg_order_value, avg_quantity) %>%
            dplyr::collect()

          if (nrow(df) == 0) return(NULL)
          message(sprintf("[worldMap] Loaded %d cities for %s", nrow(df), st))
          df
        }, error = function(e) {
          message("[worldMap] City data load error: ", e$message)
          NULL
        })
      })

      # ---- Top-50 US city lat/lon lookup (#418 MVP) ----
      us_cities_geo <- reactive({
        yaml_path <- file.path(GLOBAL_DIR, "30_global_data", "parameters",
                                "scd_type1", "us_cities_geo.yaml")
        if (!file.exists(yaml_path)) return(NULL)
        tryCatch(yaml::read_yaml(yaml_path)$cities,
                 error = function(e) NULL)
      })

      # ---- ISO2 to ISO3 mapping (plotly requires ISO-3 alpha-3 codes) ----
      iso2to3 <- c(
        AD="AND",AE="ARE",AF="AFG",AG="ATG",AI="AIA",AL="ALB",AM="ARM",AO="AGO",
        AR="ARG",AS="ASM",AT="AUT",AU="AUS",AW="ABW",AZ="AZE",BA="BIH",BB="BRB",
        BD="BGD",BE="BEL",BF="BFA",BG="BGR",BH="BHR",BI="BDI",BJ="BEN",BM="BMU",
        BN="BRN",BO="BOL",BR="BRA",BS="BHS",BT="BTN",BW="BWA",BY="BLR",BZ="BLZ",
        CA="CAN",CD="COD",CF="CAF",CG="COG",CH="CHE",CI="CIV",CL="CHL",CM="CMR",
        CN="CHN",CO="COL",CR="CRI",CU="CUB",CV="CPV",CY="CYP",CZ="CZE",DE="DEU",
        DJ="DJI",DK="DNK",DM="DMA",DO="DOM",DZ="DZA",EC="ECU",EE="EST",EG="EGY",
        ER="ERI",ES="ESP",ET="ETH",FI="FIN",FJ="FJI",FK="FLK",FM="FSM",FO="FRO",
        FR="FRA",GA="GAB",GB="GBR",GD="GRD",GE="GEO",GF="GUF",GH="GHA",GI="GIB",
        GL="GRL",GM="GMB",GN="GIN",GP="GLP",GQ="GNQ",GR="GRC",GT="GTM",GU="GUM",
        GW="GNB",GY="GUY",HK="HKG",HN="HND",HR="HRV",HT="HTI",HU="HUN",ID="IDN",
        IE="IRL",IL="ISR",IN="IND",IQ="IRQ",IR="IRN",IS="ISL",IT="ITA",JM="JAM",
        JO="JOR",JP="JPN",KE="KEN",KG="KGZ",KH="KHM",KI="KIR",KM="COM",KN="KNA",
        KP="PRK",KR="KOR",KW="KWT",KY="CYM",KZ="KAZ",LA="LAO",LB="LBN",LC="LCA",
        LI="LIE",LK="LKA",LR="LBR",LS="LSO",LT="LTU",LU="LUX",LV="LVA",LY="LBY",
        MA="MAR",MC="MCO",MD="MDA",ME="MNE",MG="MDG",MH="MHL",MK="MKD",ML="MLI",
        MM="MMR",MN="MNG",MO="MAC",MP="MNP",MQ="MTQ",MR="MRT",MS="MSR",MT="MLT",
        MU="MUS",MV="MDV",MW="MWI",MX="MEX",MY="MYS",MZ="MOZ","NA"="NAM",NC="NCL",
        NE="NER",NF="NFK",NG="NGA",NI="NIC",NL="NLD",NO="NOR",NP="NPL",NR="NRU",
        NU="NIU",NZ="NZL",OM="OMN",PA="PAN",PE="PER",PF="PYF",PG="PNG",PH="PHL",
        PK="PAK",PL="POL",PM="SPM",PN="PCN",PR="PRI",PS="PSE",PT="PRT",PW="PLW",
        PY="PRY",QA="QAT",RE="REU",RO="ROU",RS="SRB",RU="RUS",RW="RWA",SA="SAU",
        SB="SLB",SC="SYC",SD="SDN",SE="SWE",SG="SGP",SH="SHN",SI="SVN",SK="SVK",
        SL="SLE",SM="SMR",SN="SEN",SO="SOM",SR="SUR",SS="SSD",ST="STP",SV="SLV",
        SX="SXM",SY="SYR",SZ="SWZ",TC="TCA",TD="TCD",TG="TGO",TH="THA",TJ="TJK",
        TL="TLS",TM="TKM",TN="TUN",TO="TON",TR="TUR",TT="TTO",TV="TUV",TW="TWN",
        TZ="TZA",UA="UKR",UG="UGA",US="USA",UY="URY",UZ="UZB",VA="VAT",VC="VCT",
        VE="VEN",VG="VGB",VI="VIR",VN="VNM",VU="VUT",WF="WLF",WS="WSM",XK="XKX",
        YE="YEM",YT="MYT",ZA="ZAF",ZM="ZMB",ZW="ZWE"
      )

      # ---- Null-coalesce helper (no rlang dep) ----
      `%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

      # ---- Map rendering (#348: drill-down via click; #418: 3-level chain) ----
      # #418 verify-2 P2#2 fix: hoist bg-click JS handlers up so empty-state
      # plotly placeholders can wire them too — otherwise user gets stuck in
      # state/city view with no escape when data is empty (which is QEF live
      # today while Layer 1+2 ETL propagation is pending #564).
      build_bg_click_js <- function(input_name) {
        sprintf("
          function(el) {
            var ns = '%s';
            var lastDataClick = 0;
            el.on('plotly_click', function() { lastDataClick = Date.now(); });
            el.querySelector('.main-svg').addEventListener('click', function() {
              setTimeout(function() {
                if (Date.now() - lastDataClick > 200) {
                  Shiny.setInputValue(ns + '%s', Date.now(), {priority: 'event'});
                }
              }, 250);
            });
          }", session$ns(""), input_name)
      }

      output$geo_map <- plotly::renderPlotly({
        view <- view_mode()
        col <- kpi_col()
        label <- kpi_label()
        # Pre-build both JS handlers so empty-state placeholders can wire them
        bg_click_js  <- build_bg_click_js("state_bg_click")
        city_bg_js   <- build_bg_click_js("city_bg_click")

        if (view == "us_cities") {
          # ---- US Cities View (#418) ----
          df <- city_data()
          geo <- us_cities_geo()
          if (is.null(df) || is.null(geo)) {
            return(plotly::plot_ly() %>%
                     plotly::layout(title = translate("No City Data Available")) %>%
                     htmlwidgets::onRender(city_bg_js))
          }

          # JOIN city revenue with lat/lon lookup; geo is list-of-lists
          geo_df <- do.call(rbind, lapply(geo, function(c) {
            data.frame(ship_state = c$state, ship_city = c$city,
                       lat = c$lat, lon = c$lon, stringsAsFactors = FALSE)
          }))
          # Match on city name (case-insensitive trim) + state for uniqueness
          df$key <- tolower(trimws(df$ship_city))
          geo_df$key <- tolower(trimws(geo_df$ship_city))
          # Filter geo to current state to avoid name collision (e.g. Springfield)
          # Case-insensitive (#565 item 5): yaml ships uppercase but defend
          # against future yaml edits that might use mixed case.
          geo_df <- geo_df[toupper(geo_df$ship_state) == toupper(selected_state()),
                           , drop = FALSE]
          merged <- merge(df, geo_df[, c("key","lat","lon")], by = "key", all.x = TRUE)
          merged <- merged[!is.na(merged$lat), , drop = FALSE]
          if (nrow(merged) == 0) {
            return(plotly::plot_ly() %>%
                     plotly::layout(title = translate("No City Data Available")) %>%
                     htmlwidgets::onRender(city_bg_js))
          }

          hover_text <- paste0(
            "<b>", merged$ship_city, "</b><br>",
            translate("Revenue"), ": $", format(round(merged$total_revenue, 0), big.mark = ","), "<br>",
            translate("Order Count"), ": ", format(merged$order_count, big.mark = ","), "<br>",
            translate("Customer Count"), ": ", format(merged$customer_count, big.mark = ","), "<br>",
            translate("Avg Order Value"), ": $", format(round(merged$avg_order_value, 0), big.mark = ",")
          )

          # Bubble size: log-scaled by selected KPI, opacity 0.6 to mitigate overlap
          raw_vals <- merged[[col]]
          log_vals <- log10(pmax(raw_vals, 1))
          size_min <- 8; size_max <- 40
          size_range <- max(log_vals, na.rm = TRUE) - min(log_vals, na.rm = TRUE)
          if (is.na(size_range) || size_range == 0) {
            sizes <- rep(size_min + (size_max - size_min) / 2, length(log_vals))
          } else {
            sizes <- size_min + (log_vals - min(log_vals, na.rm = TRUE)) /
                                   size_range * (size_max - size_min)
          }

          # bg-click handler hoisted above this branch (#418 verify-2 P2#2)
          plotly::plot_geo(merged, source = session$ns("citymap")) %>%
            plotly::add_trace(
              type = "scattergeo",
              lat = merged$lat, lon = merged$lon,
              text = hover_text, hoverinfo = "text",
              marker = list(size = sizes, opacity = 0.65,
                            color = log_vals, colorscale = "Blues",
                            showscale = TRUE,
                            colorbar = list(title = label),
                            line = list(color = "white", width = 0.6))
            ) %>%
            plotly::layout(
              geo = list(
                scope = "usa",
                showlakes = TRUE,
                lakecolor = plotly::toRGB("white")
              ),
              margin = list(l = 0, r = 0, t = 30, b = 0),
              dragmode = FALSE
            ) %>%
            plotly::config(scrollZoom = FALSE) %>%
            htmlwidgets::onRender(city_bg_js)

        } else if (view == "us_states") {
          # ---- US States View ----
          df <- state_data()
          if (is.null(df)) {
            return(plotly::plot_ly() %>%
                     plotly::layout(title = translate("No Geographic Data")) %>%
                     htmlwidgets::onRender(bg_click_js))
          }

          hover_text <- paste0(
            "<b>", df$ship_state, "</b><br>",
            translate("Revenue"), ": $", format(round(df$total_revenue, 0), big.mark = ","), "<br>",
            translate("Order Count"), ": ", format(df$order_count, big.mark = ","), "<br>",
            translate("Customer Count"), ": ", format(df$customer_count, big.mark = ","), "<br>",
            translate("Avg Order Value"), ": $", format(round(df$avg_order_value, 0), big.mark = ",")
          )

          raw_vals <- df[[col]]
          log_vals <- log10(pmax(raw_vals, 1))
          max_log <- ceiling(max(log_vals, na.rm = TRUE))
          tick_vals <- seq(0, max_log, by = 1)
          tick_text <- vapply(tick_vals, function(v) {
            val <- 10^v
            if (val >= 1e6) paste0(round(val / 1e6, 1), "M")
            else if (val >= 1e3) paste0(round(val / 1e3, 0), "K")
            else as.character(round(val, 0))
          }, character(1))

          # bg-click handler hoisted above this branch (#418 verify-2 P2#2)
          plotly::plot_geo(df, source = session$ns("statemap")) %>%
            plotly::add_trace(
              locations = df$ship_state,
              locationmode = "USA-states",
              z = log_vals,
              colorscale = "Blues",
              text = hover_text,
              hoverinfo = "text",
              colorbar = list(title = label, tickvals = tick_vals, ticktext = tick_text)
            ) %>%
            plotly::layout(
              geo = list(
                scope = "usa",
                showlakes = TRUE,
                lakecolor = plotly::toRGB("white")
              ),
              margin = list(l = 0, r = 0, t = 30, b = 0),
              dragmode = FALSE  # Disable pan in state view
            ) %>%
            plotly::config(scrollZoom = FALSE) %>%  # Disable scroll zoom in state view
            htmlwidgets::onRender(bg_click_js)

        } else {
          # ---- World View ----
          df <- geo_data()
          if (is.null(df)) {
            return(plotly::plot_ly() %>%
                     plotly::layout(title = translate("No Geographic Data")))
          }

          # Convert ISO2 to ISO3 for plotly
          iso3_codes <- iso2to3[df$ship_country]
          iso3_codes[is.na(iso3_codes)] <- df$ship_country[is.na(iso3_codes)]

          hover_text <- paste0(
            "<b>", country_name_zh(df$ship_country), "</b><br>",
            translate("Revenue"), ": $", format(round(df$total_revenue, 0), big.mark = ","), "<br>",
            translate("Order Count"), ": ", format(df$order_count, big.mark = ","), "<br>",
            translate("Customer Count"), ": ", format(df$customer_count, big.mark = ","), "<br>",
            translate("Avg Order Value"), ": $", format(round(df$avg_order_value, 0), big.mark = ",")
          )

          raw_vals <- df[[col]]
          log_vals <- log10(pmax(raw_vals, 1))
          max_log <- ceiling(max(log_vals, na.rm = TRUE))
          tick_vals <- seq(0, max_log, by = 1)
          tick_text <- vapply(tick_vals, function(v) {
            val <- 10^v
            if (val >= 1e6) paste0(round(val / 1e6, 1), "M")
            else if (val >= 1e3) paste0(round(val / 1e3, 0), "K")
            else as.character(round(val, 0))
          }, character(1))

          # source must be namespaced; customdata carries ISO3 codes for click detection
          plotly::plot_geo(df, source = world_source) %>%
            plotly::add_trace(
              locations = iso3_codes,
              locationmode = "ISO-3",
              z = log_vals,
              customdata = iso3_codes,
              colorscale = "Blues",
              text = hover_text,
              hoverinfo = "text",
              colorbar = list(title = label, tickvals = tick_vals, ticktext = tick_text)
            ) %>%
            plotly::layout(
              geo = list(
                projection = list(type = "natural earth"),
                showframe = FALSE,
                showcoastlines = TRUE,
                coastlinecolor = plotly::toRGB("grey80")
              ),
              margin = list(l = 0, r = 0, t = 30, b = 0)
            )
        }
      })

      # ---- Detail Table ----
      output$detail_table <- DT::renderDataTable({
        view <- view_mode()

        if (view == "us_cities") {
          df <- city_data()
          if (is.null(df)) return(DT::datatable(
            data.frame(Message = translate("No City Data Available"))))

          show_df <- data.frame(
            City          = df$ship_city,
            Revenue       = round(df$total_revenue, 0),
            Orders        = df$order_count,
            Customers     = df$customer_count,
            AOV           = round(df$avg_order_value, 0),
            Avg_Qty       = round(df$avg_quantity, 1),
            stringsAsFactors = FALSE
          )
          show_df <- show_df[order(-show_df$Revenue), ]
          names(show_df) <- c(translate("City"), translate("Revenue"),
                              translate("Order Count"), translate("Customer Count"),
                              translate("Avg Order Value"), translate("Avg Qty"))
        } else if (view == "us_states") {
          df <- state_data()
          if (is.null(df)) return(DT::datatable(
            data.frame(Message = translate("No Geographic Data"))))

          show_df <- data.frame(
            State         = df$ship_state,
            Revenue       = round(df$total_revenue, 0),
            Orders        = df$order_count,
            Customers     = df$customer_count,
            AOV           = round(df$avg_order_value, 0),
            Avg_Qty       = round(df$avg_quantity, 1),
            stringsAsFactors = FALSE
          )
          show_df <- show_df[order(-show_df$Revenue), ]
          names(show_df) <- c(translate("State"), translate("Revenue"),
                              translate("Order Count"), translate("Customer Count"),
                              translate("Avg Order Value"), translate("Avg Qty"))
        } else {
          df <- geo_data()
          if (is.null(df)) return(DT::datatable(
            data.frame(Message = translate("No Geographic Data"))))

          show_df <- data.frame(
            Country       = country_name_zh(df$ship_country, with_code = TRUE),
            Revenue       = round(df$total_revenue, 0),
            Orders        = df$order_count,
            Customers     = df$customer_count,
            AOV           = round(df$avg_order_value, 0),
            Avg_Qty       = round(df$avg_quantity, 1),
            stringsAsFactors = FALSE
          )
          show_df <- show_df[order(-show_df$Revenue), ]
          names(show_df) <- c(translate("Country"), translate("Revenue"),
                              translate("Order Count"), translate("Customer Count"),
                              translate("Avg Order Value"), translate("Avg Qty"))
        }

        DT::datatable(show_df,
                      filter = "top", rownames = FALSE,
                      options = list(pageLength = 15, scrollX = TRUE, dom = "lftip",
                                     language = list(url = "//cdn.datatables.net/plug-ins/1.13.7/i18n/zh-HANT.json")))
      })

      # ---- AI Insight (non-blocking, ExtendedTask) ----
      gpt_key <- Sys.getenv("OPENAI_API_KEY", "")
      ai_task <- create_ai_insight_task(gpt_key)

      setup_ai_insight_server(
        input, output, session, ns,
        task = ai_task,
        gpt_key = gpt_key,
        prompt_key = "vitalsigns_analysis.world_map_insights",
        get_template_vars = function() {
          df <- geo_data()
          if (is.null(df) || nrow(df) == 0) return(NULL)

          ordered <- df[order(-df$total_revenue), ]
          total_rev <- sum(ordered$total_revenue, na.rm = TRUE)

          # Country revenue summary (top 10)
          top_n <- utils::head(ordered, 10)
          country_lines <- vapply(seq_len(nrow(top_n)), function(i) {
            pct <- round(top_n$total_revenue[i] / total_rev * 100, 1)
            sprintf("%s: $%s (%s%%, %d orders, %d customers)",
                    country_name_zh(top_n$ship_country[i]),
                    format(round(top_n$total_revenue[i], 0), big.mark = ","),
                    pct, top_n$order_count[i], top_n$customer_count[i])
          }, character(1))

          # Concentration
          top1_pct <- round(ordered$total_revenue[1] / total_rev * 100, 1)
          top3_pct <- round(sum(utils::head(ordered$total_revenue, 3)) / total_rev * 100, 1)
          top5_pct <- round(sum(utils::head(ordered$total_revenue, 5)) / total_rev * 100, 1)

          # Build filter context for AI (#324)
          cfg <- comp_config()
          pl <- cfg$filters$product_line_id_sliced
          kpi_sel <- input$kpi_select
          kpi_label_map <- c(revenue = "Revenue", orders = "Order Count",
                             customers = "Customer Count", aov = "Avg Order Value")
          kpi_display <- if (!is.null(kpi_sel) && kpi_sel %in% names(kpi_label_map))
            kpi_label_map[[kpi_sel]] else "Revenue"
          filter_context_str <- paste0(
            "Analysis scope:\n",
            "- Platform: ", cfg$filters$platform_id, "\n",
            "- Product line: ", if (!is.null(pl) && pl != "all") pl else "All", "\n",
            "- Current view: ", view_mode(), "\n",
            "- Selected KPI: ", kpi_display
          )

          # P2b: Only include state data in AI context when drilled into US states
          state_summary_str <- if (view_mode() == "us_states") {
            sd <- state_data()
            if (!is.null(sd) && nrow(sd) > 0) {
              sd_ordered <- sd[order(-sd$total_revenue), ]
              top_states <- utils::head(sd_ordered, 5)
              state_lines <- vapply(seq_len(nrow(top_states)), function(i) {
                sprintf("%s: $%s (%d orders)",
                        top_states$ship_state[i],
                        format(round(top_states$total_revenue[i], 0), big.mark = ","),
                        top_states$order_count[i])
              }, character(1))
              paste0("US state breakdown (top 5):\n", paste(state_lines, collapse = "\n"))
            } else {
              "US state data: not available"
            }
          } else {
            ""  # World view: no state-level detail in AI context
          }

          list(
            filter_context = filter_context_str,
            state_summary = state_summary_str,
            total_countries = as.character(nrow(df)),
            largest_market = sprintf("%s ($%s, %.1f%%)",
                                    country_name_zh(ordered$ship_country[1]),
                                    format(round(ordered$total_revenue[1], 0), big.mark = ","),
                                    top1_pct),
            country_revenue_summary = paste(country_lines, collapse = "\n"),
            concentration_summary = sprintf(
              "Top 1: %.1f%%\nTop 3: %.1f%%\nTop 5: %.1f%%\nTotal countries: %d",
              top1_pct, top3_pct, top5_pct, nrow(df))
          )
        },
        component_label = "worldMap"
      )

      # ---- Download CSV (view-aware per #565) ----
      output$download_csv <- downloadHandler(
        filename = function() {
          v <- view_mode()
          prefix <- if (v == "us_cities") {
            sprintf("us_cities_%s", selected_state() %||% "unknown")
          } else if (v == "us_states") "us_states" else "world_market"
          paste0(prefix, "_", Sys.Date(), ".csv")
        },
        content = function(file) {
          df <- current_view()$df
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
