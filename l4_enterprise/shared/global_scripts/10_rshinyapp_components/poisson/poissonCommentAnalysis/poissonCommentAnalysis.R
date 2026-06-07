#LOCK FILE
#
# poissonCommentAnalysis.R
# 產品賽道分析組件 - 專注於口碑評分效果
#
# Following principles:
# - MP56: Connected Component Principle
# - MP73: Interactive Visualization Preference 
# - R116: Enhanced Data Access with tbl2
# - R09: UI-Server-Defaults Triple
# -----------------------------------------------------------------------------

# Source covariate exclusion utility (configuration-driven approach)
# Following: Configuration-Driven Development, DRY Principle
source("scripts/global_scripts/04_utils/fn_should_exclude_covariate.R")
# #732: metadata-driven rating_type display-category classifier (replaces
# inline English-keyword case_when that mis-classified Chinese sentiment).
source("scripts/global_scripts/04_utils/fn_classify_rating_type.R")
# #777: sign-aware recommendation-phrasing helper (extracted from the
# rating_recommendation renderUI so the DA-H1 sign invariant is unit-testable).
source("scripts/global_scripts/04_utils/fn_rating_recommendation.R")

# Stage notification messages for market track analysis
# Following UI_R007: 標準化介面文字 (Traditional Chinese)
# Following UI_R019: AI Process Notification Rule
# Following MP088: Immediate Feedback Principle
COMMENT_ANALYSIS_STAGE_MESSAGES <- list(
  start = "🛣️ 正在準備市場賽道分析...",
  analyzing = "🤖 AI 正在分析市場競爭策略...",
  complete = "✅ 市場賽道分析完成！",
  error = "❌ AI 分析失敗"
)

# helper ----------------------------------------------------------------------
`%+%` <- function(x, y) paste0(x, y)
`%||%` <- function(x, y) if (is.null(x)) y else x

# Filter UI --------------------------
poissonCommentAnalysisFilterUI <- function(id, translate = identity) {
  ns <- NS(id)
  
  wellPanel(
    style = "padding:15px;",
    h4(translate("市場賽道分析")),
    p(translate("分析口碑評分對銷量的影響力")),
    
    hr(),
    
    # AI Analysis button at the bottom
    actionButton(
      inputId = ns("generate_market_track_insight"),
      label = translate("生成 AI 市場賽道策略"),
      class = "btn-primary btn-block",
      icon = icon("magic")
    )
  )
}

# Display UI -------------------------
poissonCommentAnalysisUI <- function(id, translate = identity) {
  ns <- NS(id)
  
  tagList(
    # Include shinyjs dependency
    shinyjs::useShinyjs(),

    # FIX BUG 2: Add CSS for overflow handling (UI_R024: Component-specific styling)
    tags$style(HTML("
      .info-box-content h4 {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 100%;
        cursor: help;
      }

      .info-box {
        min-height: 100px;
        display: flex;
        align-items: center;
      }

      .info-box-content {
        width: 100%;
        padding: 10px;
      }

      .info-box-content h4 {
        margin-top: 0;
        margin-bottom: 5px;
        font-size: 1.2rem;
      }

      .info-box-content p {
        margin-bottom: 0;
        font-size: 0.9rem;
      }
    ")),

    div(class = "component-header mb-3 text-center",
        h3(translate("⭐ 市場賽道分析")),
        p(translate("深入分析評分對銷量的影響，運用賽道倍數識別口碑管理的關鍵"))),

    # TYPE B METADATA BANNER (MP135 v2.0 + UI_R024)
    uiOutput(ns("metadata_banner")),

    # InsightForge 風格的摘要卡片
    fluidRow(
      column(3,
        div(class = "info-box bg-primary",
            div(class = "info-box-content",
                # FIX BUG 2: Add title attribute for full text tooltip (UI_R024)
                h4(textOutput(ns("rating_champion")),
                   class = "text-white",
                   title = textOutput(ns("rating_champion_full"))),
                p(translate("⭐ 評分冠軍"), class = "text-white")))),
      column(3,
        div(class = "info-box bg-primary",
            div(class = "info-box-content",
                h4(textOutput(ns("rating_multiplier_value")), class = "text-white"),
                p(translate("最大評分倍數"), class = "text-white")))),
      column(3,
        div(class = "info-box bg-info",
            div(class = "info-box-content",
                # FIX BUG 2: Add title attribute for full text tooltip (UI_R024)
                h4(textOutput(ns("review_champion")),
                   class = "text-white",
                   title = textOutput(ns("review_champion_full"))),
                p(translate("📝 評論冠軍"), class = "text-white")))),
      column(3,
        div(class = "info-box bg-info",
            div(class = "info-box-content",
                h4(textOutput(ns("review_effect_value")), class = "text-white"),
                p(translate("評論影響力"), class = "text-white"))))
    ),
    
    # 決策指南
    div(class = "alert alert-primary mb-3",
        h5("🎯 市場賽道決策指南"),
        tags$ul(
          tags$li("賽道倍數 > 3.0：核心競爭因素，決定市場地位"),
          tags$li("賽道倍數 2.0-3.0：重要影響指標，需重點優化"),
          tags$li("邊際效應 > 50%：每提升1分評分，銷量大幅增長"),
          tags$li("評分影響顯著：口碑管理是成功關鍵")
        )
    ),
    
    # 主要視覺化區域
    div(class = "component-output p-3",
        fluidRow(
          column(12,
            div(class = "card",
                div(class = "card-header",
                    h4("🏁 市場賽道倍數分析")),
                div(class = "card-body",
                    plotly::plotlyOutput(ns("rating_multiplier_plot"), height = "500px")))
          )
        ),
        br(),
        fluidRow(
          column(6,
            div(class = "card",
                div(class = "card-header",
                    h4("📈 評分維度影響力")),
                div(class = "card-body",
                    plotly::plotlyOutput(ns("rating_dimension_plot"), height = "400px")))
          ),
          column(6,
            div(class = "card",
                div(class = "card-header",
                    h4("💡 口碑策略建議")),
                div(class = "card-body",
                    htmlOutput(ns("rating_recommendation"))))
          )
        ),
        br(),
        # #731 D2: not_estimable counter — 使用者知道「N 個口碑維度因評論樣本
        # 不足無法估計,未列入下表」,避免「太少 / 沒串進來」的誤解。
        uiOutput(ns("not_estimable_summary")),
        fluidRow(
          column(12,
            div(class = "card",
                div(class = "card-header bg-light",
                    h4("📋 詳細分析結果", style = "margin: 0; padding: 10px 0;")),
                div(class = "card-body", style = "padding-top: 20px;",
                    # Following UI_R018: Table Download Button Placement Rule
                    # Following UI_R021: Dual Download Buttons for Statistical Data
                    # Control bar ABOVE table with dual download buttons
                    div(class = "table-control-bar",
                        style = "display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 15px;",

                        # Download full data (all results with significance markers)
                        downloadButton(ns("download_full"),
                                       "下載完整數據",
                                       class = "btn-primary btn-sm",
                                       icon = icon("download")),

                        # Download significant results only (p < 0.05)
                        downloadButton(ns("download_significant"),
                                       "下載顯著結果",
                                       class = "btn-success btn-sm",
                                       icon = icon("download"))),
                    # Table BELOW control bar
                    DT::DTOutput(ns("analysis_table"), width = "100%")))
          )
        ),
        br(),
        # AI Market Track Insights Section
        fluidRow(
          column(12,
            div(class = "card",
                id = ns("ai_market_insights_section"),
                style = "display: none;",  # Initially hidden
                div(class = "card-header bg-info text-white",
                    h4("🤖 AI 市場賽道策略報告", style = "margin: 0; padding: 10px 0;")),
                div(class = "card-body", style = "padding: 30px;",
                    if (requireNamespace("shinycssloaders", quietly = TRUE)) {
                      shinycssloaders::withSpinner(
                        htmlOutput(ns("market_track_insight_output")),
                        type = 6,
                        color = "#17a2b8"
                      )
                    } else {
                      htmlOutput(ns("market_track_insight_output"))
                    }
                )
            )
          )
        )
    )
  )
}

# Server ------------------------------
poissonCommentAnalysisServer <- function(id, app_data_connection = NULL, config = NULL,
                                       session = getDefaultReactiveDomain(),
                                       translate = identity) {
  moduleServer(id, function(input, output, session) {
    
    # 狀態追蹤
    component_status <- reactiveVal("idle")
    
    # 提取配置參數 — 解析 active platform (#655 fix)
    # 過去寫死 "cbz" 對 QEF (amz-only) 會去查不存在的 df_cbz_poisson_analysis_all,
    # 導致 analysis_data() 回 empty df、下游 comment_data filter coefficient 報錯
    platform_id <- reactive({
      if (is.function(config)) {
        cfg <- if (shiny::is.reactive(config)) config() else config
      } else {
        cfg <- config
      }
      chosen <- cfg$filters$platform_id %||% cfg$platform_id %||% NULL
      resolve_active_platform(chosen, cfg)
    })
    
    # 提取產品線參數
    product_line_id <- reactive({
      if (is.null(config)) return("all")
      
      if (is.function(config)) {
        cfg <- if (shiny::is.reactive(config)) config() else config
      } else {
        cfg <- config
      }
      
      cfg$filters$product_line_id_sliced %||% cfg$filters$product_line_id_chosen %||% "all"
    })
    
    # 載入並處理數據
    analysis_data <- reactive({
      component_status("loading")
      
      tryCatch({
        if (is.null(app_data_connection)) {
          component_status("error")
          return(data.frame())
        }
        
        # 載入 Poisson 分析結果 (#655 fix: 用解析過的 active platform 不寫死 cbz)
        platform <- platform_id()
        prod_line <- product_line_id()
        
        # App data prefers aggregated tables; filter by product_line_id when needed
        table_name <- paste0("df_", platform, "_poisson_analysis_all")
        
        # 載入數據並篩選口碑相關屬性
        # FIX: convergence is VARCHAR "converged", not BOOLEAN TRUE
        # Fetch data with basic filters (convergence, estimation status)
        data <- tbl2(app_data_connection, table_name) %>%
          filter(convergence == "converged" &
                 estimation_status == "estimated") %>%
          collect()

        if (prod_line != "all" && "product_line_id" %in% names(data)) {
          data <- data %>% filter(product_line_id == prod_line)
        }

        data <- data %>%
          # PHASE 4: Add display_name_safe with fallback to predictor
          # Following MP031: Defensive Programming
          # #758 Codex F1: also strip `_rating$` in the fallback path —
          # when display_name is NA (stale app_data row pre-#756 fn rerun),
          # coalesce was leaking raw `<name>_rating` back into the cleaned
          # column. Strip mirrors fn_generate_display_name.R Stage 0 logic.
          mutate(
            display_name_safe = dplyr::coalesce(
              display_name,
              sub("_rating$", "", predictor)
            )
          )

        # Apply YAML-based covariate exclusion (presentation layer filtering)
        # Following DM_R043: Predictor Data Classification
        data <- filter_excluded_covariates(
          data,
          predictor_col = "predictor",
          app_type = "poisson_regression"
        )

        # 篩選市場賽道屬性 - 使用 DRV 預先分類的 comment_attribute 類型
        # Following MP064: UI 層使用 DRV 預計算結果，不重複判斷變數名稱
        # #731 D1 (post-verify follow-up): removed `abs(coefficient) <= 5` cap.
        # The cap silently hid the keystone insight (評論星級 coef=-5.45 in
        # post-#755 fresh hsg data) — the single most actionable negative-
        # significant predictor. Numerical safety is preserved downstream by
        # the existing |coef|>5 / |coef|>10 clamps in `marginal_effect_pct`
        # and `track_multiplier` (L331-340) — those handle the display-side
        # extremes without hiding the row entirely.
        data <- data %>%
          filter(predictor_type == "comment_attribute" &
                 estimation_status == "estimated" &
                 !grepl("missing", predictor, ignore.case = TRUE)) %>%
          mutate(
            # #732: rating_type metadata-driven via classify_rating_type()
            # (04_utils/fn_classify_rating_type.R). Replaces inline English-
            # keyword case_when that mis-classified every Chinese sentiment as
            # `其他因素` → chart 退化單 bar + recommendation 永遠空。
            rating_type = classify_rating_type(predictor),
            # 限制邊際效應在合理範圍內
            marginal_effect_pct = round(ifelse(abs(coefficient) > 5,
                                              sign(coefficient) * 500,
                                              (exp(coefficient) - 1) * 100), 1),
            # 計算賽道倍數（對極大值進行更嚴格的限制）
            track_multiplier = round(
              ifelse(abs(coefficient) > 10,
                     100,  # 極大係數直接設為 100
                     ifelse(abs(coefficient) > 2,
                            exp(2) * (1 + (abs(coefficient) - 2) * 0.5),
                            exp(abs(coefficient)))), 1),
            # Following Phase 3 (ISSUE_244A_CRITICAL + ISSUE_244B_ENHANCED):
            # Integrate statistical significance + track multiplier (user preference)
            # User feedback: "應該用顯著搭配賽道，因為邊際的話不一定達得到"
            # Statistical significance (P-value) determines if we pay attention
            # Track multiplier determines the importance level
            # Track multiplier represents total opportunity size from min to max
            # Adjusted terminology for comment analysis context (口碑因素 instead of 競爭力)
            practical_meaning = case_when(
              # Priority 1: Check statistical significance
              p_value >= 0.05 ~ "影響不顯著，暫不關注",

              # Priority 2: Highly significant (P < 0.001) - classify by track multiplier
              p_value < 0.001 & track_multiplier >= 3.0 ~
                paste0(ifelse(coefficient > 0, "⭐ 極重要正向口碑因素", "⚠️ 極重要負面口碑因素"),
                       "，核心關注點 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.001 & track_multiplier >= 2.0 ~
                paste0(ifelse(coefficient > 0, "✓ 重要正向口碑因素", "✗ 重要負面口碑因素"),
                       "，需持續優化 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.001 & track_multiplier >= 1.2 ~
                paste0(ifelse(coefficient > 0, "有正向口碑影響", "有負向口碑影響"),
                       "，可考慮改善 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.001 ~
                paste0(ifelse(coefficient > 0, "有正向口碑影響", "有負向口碑影響"),
                       "，但機會較小 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              # Priority 3: Moderately significant (P < 0.01)
              p_value < 0.01 & track_multiplier >= 2.5 ~
                paste0(ifelse(coefficient > 0, "重要正向口碑因素", "重要負面口碑因素"),
                       "，需持續優化 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.01 & track_multiplier >= 1.5 ~
                paste0(ifelse(coefficient > 0, "有正向口碑影響", "有負向口碑影響"),
                       "，可考慮改善 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.01 ~
                paste0(ifelse(coefficient > 0, "有正向口碑影響", "有負向口碑影響"),
                       "，但機會較小 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              # Priority 4: Marginally significant (P < 0.05)
              p_value < 0.05 & track_multiplier >= 2.0 ~
                paste0(ifelse(coefficient > 0, "可能有正向口碑影響", "可能有負向口碑影響"),
                       "，建議進一步觀察 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              p_value < 0.05 ~
                paste0(ifelse(coefficient > 0, "可能有正向口碑影響", "可能有負向口碑影響"),
                       "，機會較小 (賽道倍數: ", round(track_multiplier, 1), "x)"),

              # Default
              TRUE ~ "影響較小或不確定"
            ),
            # 口碑解釋
            rating_explanation = paste0(rating_type, "從最低到最高，銷量可相差", track_multiplier, "倍")
          )
        
        component_status("ready")
        return(data)
        
      }, error = function(e) {
        warning("Error loading rating analysis data: ", e$message)
        component_status("error")
        data.frame()
      })
    })
    
    # #731 D1: 顯示所有口碑屬性（正向 + 負向）。原本 L441 的 `coefficient > 0`
    # 把 評論星級 (coef=-1.18, p=9.43e-89) 這種**最顯著的負面口碑 insight**
    # 一刀切掉,違反 InsightForge 的商業目的。practical_meaning case_when 早就
    # 支援負向文案 (L349-394 有 8 個負向分支),F4 是唯一擋住負向 row 抵達文案
    # 的 filter — 移除即可。重新命名 reactive (positive_data → comment_data)
    # 反映語意。#731 D4: 移除原 L443-468 的第二次 filter_covariates 呼叫 —
    # L305 的 filter_excluded_covariates 已做同樣工作,純 dead code 清理。
    comment_data <- reactive({
      data <- analysis_data()

      # #655 fix retained: guard against empty data / missing columns.
      # 當上游 analysis_data 因為公司無 comment_attribute 資料而回空 df 時,
      # 不可直接 filter NA — empty df 沒有 coefficient 欄位會報
      # "object 'coefficient' not found" 被 Shiny 印成紅字 [object Object]。
      # 回 0-row df 並保留 downstream 使用的欄位 shape,避免下游 pipe
      # (filter/group_by/slice_head 等) 也 NAMESPACE 錯誤。
      if (is.null(data) || nrow(data) == 0 || !"coefficient" %in% names(data)) {
        return(data.frame(
          coefficient = double(0),
          p_value = double(0),
          track_multiplier = double(0),
          marginal_effect_pct = double(0),
          predictor = character(0),
          display_name_safe = character(0),
          rating_type = character(0),
          practical_meaning = character(0),
          rating_explanation = character(0),
          stringsAsFactors = FALSE
        ))
      }

      cat("找到", nrow(data), "筆評分相關資料\n")

      # #731 D1: 只 filter 掉 NA coefficient / p_value (downstream 計算需要),
      # 不過濾正負向 — 負向顯著 insight (低星評壓銷量) 是商業價值核心。
      filtered_data <- data %>%
        filter(!is.na(coefficient) & !is.na(p_value))

      filtered_data %>%
        arrange(desc(track_multiplier))  # 按倍數從大到小排序
    })

    # #731 D2: not_estimable counter — counts comment_attribute predictors that
    # exist in the DRV output but were marked not_estimable (no AI rating samples,
    # constant_in_subset, glm aliased, etc.). Surfaces gap to user so the panel
    # explains "N 個維度因樣本不足無法估計,未列入下表" instead of silently hiding.
    not_estimable_count <- reactive({
      platform <- platform_id()
      prod_line <- product_line_id()
      table_name <- paste0("df_", platform, "_poisson_analysis_all")
      tryCatch({
        tbl <- tbl2(app_data_connection, table_name) %>%
          filter(predictor_type == "comment_attribute" &
                 estimation_status == "not_estimable")
        if (prod_line != "all") {
          tbl <- tbl %>% filter(product_line_id == prod_line)
        }
        tbl %>% summarise(n = dplyr::n()) %>% collect() %>% dplyr::pull(n)
      }, error = function(e) 0L)
    })

    output$not_estimable_summary <- renderUI({
      n <- not_estimable_count()
      # #731 D2 M5 (post-verify follow-up): length(n) == 0 guard. If the
      # `summarise + collect + pull` chain returns 0 rows (e.g. table doesn't
      # exist and tryCatch outer fallback didn't fire, or dbplyr backend quirk),
      # `n` is `integer(0)`. `n == 0` against integer(0) returns `logical(0)`,
      # which throws "argument is of length zero" in `if()`. Guard first.
      if (length(n) == 0L || is.null(n) || is.na(n) || n == 0) return(NULL)
      div(class = "alert alert-info mb-3",
          style = "padding: 10px 15px; font-size: 0.9rem;",
          icon("info-circle"),
          sprintf(" 另有 %d 個口碑維度因評論樣本不足,Poisson 模型無法估計,未列入下表(D04 已記錄為 not_estimable sentinel,可至 InsightForge → 詳細分析結果查看完整 DRV 輸出)。", n))
    })

    # TYPE B METADATA BANNER (MP135 v2.0 + UI_R024)
    # Display metadata for steady-state analytics using all historical data
    output$metadata_banner <- renderUI({
      # Get analysis data
      data <- analysis_data()

      # If no data, don't show banner
      if (is.null(data) || nrow(data) == 0) {
        return(NULL)
      }

      # Extract Type B metadata from first row (all rows have same metadata)
      computed_at <- data$computed_at[1]
      data_version <- data$data_version[1]

      # FIX BUG 1: Check for NULL first, then check NA
      # Following MP031: Defensive Programming
      # is.na(NULL) returns logical(0), not TRUE/FALSE, causing error
      if (is.null(computed_at) || is.null(data_version) ||
          is.na(computed_at) || is.na(data_version)) {
        return(NULL)
      }

      # Convert to proper date/time types (after NULL/NA check)
      computed_at <- as.POSIXct(computed_at)
      data_version <- as.Date(data_version)

      # Additional safety check after conversion
      if (is.na(computed_at) || is.na(data_version)) {
        return(NULL)
      }

      # Render metadata banner (per UI_R024)
      # SECURITY FIX: Removed "數據至" field (sensitive business data)
      # UX FIX: Changed text color to #495057 for proper contrast (WCAG AA compliant)
      div(
        class = "alert alert-info",
        style = "margin-bottom: 15px; padding: 10px 15px; background-color: #e8f4f8; border-left: 4px solid #1e88e5; color: #495057;",

        div(
          style = "display: flex; align-items: center; gap: 20px; flex-wrap: wrap;",

          # Data scope
          div(
            tags$i(class = "fas fa-database", style = "color: #1565c0;"),
            strong(" 基於全部歷史數據")
          ),

          # Computed timestamp (only non-sensitive temporal metadata shown)
          div(
            tags$i(class = "fas fa-clock", style = "color: #1565c0;"),
            sprintf(" 計算時間: %s", format(computed_at, "%Y-%m-%d %H:%M"))
          )
        )
      )
    })

    # 摘要統計 - 評分冠軍（影響力最大的）
    # FIX BUG 2: Consistent truncation logic with better length calculation
    # Following MP031: Defensive Programming + UI_R024: Metadata Display
    # PHASE 4: Use display_name_safe for user-friendly names
    output$rating_champion <- renderText({
      data <- comment_data()

      if (nrow(data) == 0) return("--")

      # 選擇影響力最大的（不論正負）- 直接使用第一筆（已按 track_multiplier 排序）
      top <- data[1, ]
      # Chinese characters take more space, use conservative limit
      max_display_chars <- 20  # Increased from 15 for better readability

      if (nchar(top$display_name_safe) > max_display_chars) {
        # Truncate at max_display_chars - 3 (for "...")
        paste0(substr(top$display_name_safe, 1, max_display_chars - 3), "...")
      } else {
        top$display_name_safe
      }
    })

    # FIX BUG 2: Add full text output for tooltip
    # PHASE 4: Use display_name_safe for tooltip
    output$rating_champion_full <- renderText({
      data <- comment_data()
      if (nrow(data) == 0) return("--")
      data$display_name_safe[1]  # Full text without truncation
    })

    output$rating_multiplier_value <- renderText({
      data <- comment_data()

      if (nrow(data) == 0) return("--")
      # 直接使用第一筆資料的賽道倍數（已按倍數排序）
      paste0(data$track_multiplier[1], " 倍")
    })

    # 評論冠軍（第二大影響力）
    # PHASE 4: Use display_name_safe for user-friendly names
    output$review_champion <- renderText({
      data <- comment_data()

      if (nrow(data) < 2) return("--")

      # 使用第二筆資料
      top <- data[2, ]
      # Consistent truncation logic
      max_display_chars <- 20

      if (nchar(top$display_name_safe) > max_display_chars) {
        paste0(substr(top$display_name_safe, 1, max_display_chars - 3), "...")
      } else {
        top$display_name_safe
      }
    })

    # FIX BUG 2: Add full text output for tooltip
    # PHASE 4: Use display_name_safe for tooltip
    output$review_champion_full <- renderText({
      data <- comment_data()
      if (nrow(data) < 2) return("--")
      data$display_name_safe[2]  # Full text without truncation
    })

    output$review_effect_value <- renderText({
      data <- comment_data()

      if (nrow(data) < 2) return("--")

      # 使用第二筆資料的邊際效應
      paste0(abs(data$marginal_effect_pct[2]), "%")
    })
    
    # 口碑賽道倍數圖
    output$rating_multiplier_plot <- plotly::renderPlotly({
      # 顯示所有評分資料，不限於正向
      data <- comment_data() %>% 
        filter(!is.na(track_multiplier)) %>%
        slice_head(n = 15)  # 顯示前15筆
      
      if (nrow(data) == 0) {
        plotly::plot_ly() %>%
          plotly::add_text(x = 0.5, y = 0.5, text = "無口碑相關資料",
                          textposition = "center", showlegend = FALSE)
      } else {
        # PHASE 4: Use display_name_safe for user-friendly visualization
        data <- data %>%
          mutate(
            hover_text = paste0(
              "口碑指標: ", display_name_safe, "<br>",
              "類型: ", rating_type, "<br>",
              "賽道倍數: ", track_multiplier, " 倍<br>",
              "邊際效應: ", marginal_effect_pct, "%<br>",
              "商業意義: ", practical_meaning
            ),
            predictor_short = ifelse(nchar(display_name_safe) > 25,
                                   paste0(substr(display_name_safe, 1, 22), "..."),
                                   display_name_safe)
          )
        
        plotly::plot_ly(data, 
                       x = ~track_multiplier,
                       y = ~reorder(predictor_short, track_multiplier),
                       type = "bar",
                       orientation = "h",
                       marker = list(color = ~track_multiplier,
                                   colorscale = list(c(0, "#E3F2FD"), c(0.5, "#2196F3"), c(1, "#0D47A1")),
                                   cmin = 1, cmax = max(data$track_multiplier)),
                       text = ~hover_text,
                       textposition = "none",
                       hoverinfo = "text") %>%
          plotly::layout(
            title = "",
            xaxis = list(title = "口碑賽道倍數（評分差異對銷量的影響倍數）"),
            yaxis = list(title = ""),
            shapes = list(
              list(type = "line", x0 = 3, x1 = 3, y0 = -0.5, y1 = length(unique(data$predictor)) - 0.5,
                   line = list(color = "darkblue", dash = "dash")),
              list(type = "line", x0 = 2, x1 = 2, y0 = -0.5, y1 = length(unique(data$predictor)) - 0.5,
                   line = list(color = "blue", dash = "dot"))
            )
          )
      }
    })
    
    # 評分維度影響力圖
    output$rating_dimension_plot <- plotly::renderPlotly({
      data <- comment_data() %>%
        group_by(rating_type) %>%
        summarise(
          avg_multiplier = mean(track_multiplier, na.rm = TRUE),
          avg_marginal = mean(abs(marginal_effect_pct), na.rm = TRUE),
          count = n()
        ) %>%
        arrange(desc(avg_multiplier))
      
      if (nrow(data) == 0) {
        plotly::plot_ly() %>%
          plotly::add_text(x = 0.5, y = 0.5, text = "無資料", showlegend = FALSE)
      } else {
        plotly::plot_ly(data,
                       x = ~rating_type,
                       y = ~avg_multiplier,
                       type = "bar",
                       marker = list(color = c("#0D47A1", "#1976D2", "#2196F3", "#64B5F6")),
                       text = ~paste0("平均倍數: ", round(avg_multiplier, 1), "倍<br>",
                                     "屬性數量: ", count),
                       textposition = "none",
                       hoverinfo = "text") %>%
          plotly::layout(
            title = "",
            xaxis = list(title = ""),
            yaxis = list(title = "平均賽道倍數"),
            showlegend = FALSE
          )
      }
    })
    
    # 口碑策略建議
    output$rating_recommendation <- renderUI({
      data <- comment_data()
      
      if (nrow(data) == 0) {
        return(p("暫無分析結果"))
      }
      
      # 找出最重要的口碑因素
      rating_top <- data %>% filter(rating_type == "整體評分") %>% slice(1)
      customer_top <- data %>% filter(rating_type == "客戶評分") %>% slice(1)

      # PHASE 4: Use display_name_safe in recommendations
      # #731 H2 / DA-H1: the 評分優化 line is sign-aware. After D1 lifted the
      # `coefficient > 0` filter AND the upstream `abs(coef) <= 5` cap,
      # negative-coef rows reach this recommendation. #777 extracted the
      # phrasing logic into `build_rating_recommendation_phrase()` so the
      # sign-direction invariant (r_dir is the sales-increasing move; the sales
      # verb 增加 is constant) is unit-tested — see fn_rating_recommendation.R
      # + 98_test/general/test_rating_recommendation.R. `coefficient` is dropped
      # from the table at L753 but preserved in `comment_data()` (L443 NA-guard).
      recommendation <- tags$div(
        h5("⭐ 基於分析結果的口碑管理建議："),
        tags$ul(
          if (nrow(rating_top) > 0) {
            tags$li(tags$strong("評分優化："),
                    build_rating_recommendation_phrase(
                      rating_top$coefficient,
                      rating_top$display_name_safe,
                      rating_top$marginal_effect_pct))
          },
          if (nrow(customer_top) > 0) {
            c_dir <- if (customer_top$coefficient < 0) "降低" else "優化"
            tags$li(tags$strong("客戶評分："),
                    paste0(c_dir, "「", customer_top$display_name_safe, "」，",
                          "從最低到最高可讓銷量相差", customer_top$track_multiplier, "倍"))
          },
          tags$li(tags$strong("資源配置："),
                  "優先改善賽道倍數>3的口碑指標，這些是決定市場地位的關鍵")
        ),
        br(),
        tags$div(class = "alert alert-primary",
          tags$strong("執行策略："),
          "建立「評分提升+評論增長」雙軌策略，持續監控口碑指標變化"
        )
      )
      
      return(recommendation)
    })
    
    # 詳細表格
    output$analysis_table <- DT::renderDT({
      # 使用 comment_data，只顯示正向影響的資料
      data <- comment_data()
      
      # 除錯訊息
      cat("分析表格資料筆數:", nrow(data), "\n")
      
      if (nrow(data) == 0) {
        return(data.frame(訊息 = "無口碑相關資料"))
      }
      
      # PHASE 4: Add display_name_safe as first column for user-friendly display
      table_data <- data %>%
        dplyr::select(
          display_name_safe,
          rating_type,
          track_multiplier,
          marginal_effect_pct,
          practical_meaning,
          coefficient,
          p_value,
          sample_size
        ) %>%
        mutate(
          coefficient = round(coefficient, 4),
          p_value = round(p_value, 4),
          significance = ifelse(p_value < 0.001, "***",
                              ifelse(p_value < 0.01, "**",
                                    ifelse(p_value < 0.05, "*", "")))
        )

      # PHASE 4: Include user-friendly names (Technical Name column removed per #758 —
      # raw `predictor` carried #733 `_rating` join-collision suffix that leaked to users)
      colnames(table_data) <- sapply(c("WOM Metric", "Variable Type", "Track Multiplier", "Marginal Effect%",
                               "Business Meaning", "Coefficient", "P-Value", "Sample Size", "Significance"), translate)

      # Following UI_R018: Removed embedded download button (now above table)
      DT::datatable(table_data,
                options = list(
                  pageLength = 10,
                  scrollX = TRUE,
                  dom = 'frtip',  # Removed 'B' (buttons) per UI_R018
                  order = list(list(2, 'desc'))  # 預設按賽道倍數排序
                ),
                # Removed extensions per UI_R018
                rownames = FALSE) %>%
        formatStyle(translate("Track Multiplier"),
                   backgroundColor = styleInterval(c(2.0, 3.0),
                                                 c("white", "#E3F2FD", "#BBDEFB")),
                   fontWeight = styleInterval(3.0, c("normal", "bold"))) %>%
        formatStyle(translate("Significance"),
                   color = styleEqual(c("*", "**", "***"),
                                    c("#2196F3", "#1976D2", "#0D47A1")))
    })

    # Following UI_R021: Dual Download Buttons for Statistical Data
    # Download 1: Full Data (all results with significance markers)
    # Following UI_R018: Separate download button above table
    # Following ISSUE_245: UTF-8 BOM for Excel compatibility
    # Following UI_R020: All downloads use CSV with UTF-8 BOM
    output$download_full <- downloadHandler(
      filename = function() {
        paste0("InsightForge_口碑影響力完整分析_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        data <- comment_data()
        if (nrow(data) == 0) {
          # Requires: source("scripts/global_scripts/04_utils/fn_write_utf8_csv.R")
          write_utf8_csv_with_bom(data.frame(訊息 = "無可用資料"), file)
        } else {
          # PHASE 4: Include display_name_safe in export data
          # #758: Technical Name column removed — raw `predictor` carried #733 `_rating` suffix
          table_data <- data %>%
            dplyr::select(
              display_name_safe,
              rating_type,
              track_multiplier,
              marginal_effect_pct,
              practical_meaning,
              coefficient,
              p_value,
              sample_size
            ) %>%
            mutate(
              coefficient = round(coefficient, 4),
              p_value = round(p_value, 4),
              # Add significance markers for all data
              significance = case_when(
                is.na(p_value) ~ "",
                p_value < 0.001 ~ "***",
                p_value < 0.01 ~ "**",
                p_value < 0.05 ~ "*",
                TRUE ~ ""
              )
            )

          colnames(table_data) <- sapply(c("WOM Metric", "Variable Type", "Track Multiplier", "Marginal Effect%",
                                   "Business Meaning", "Coefficient", "P-Value", "Sample Size", "Significance"), translate)

          # Requires: source("scripts/global_scripts/04_utils/fn_write_utf8_csv.R")
          write_utf8_csv_with_bom(table_data, file)
        }
      }
    )

    # Download 2: Significant Results Only (p < 0.05)
    # Following UI_R021: Dual Download Buttons for Statistical Data
    # Following ISSUE_245: UTF-8 BOM for Excel compatibility
    # Following UI_R020: All downloads use CSV with UTF-8 BOM
    output$download_significant <- downloadHandler(
      filename = function() {
        paste0("InsightForge_口碑影響力顯著結果_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        data <- comment_data()

        # Filter for significant results only
        significant_data <- data %>%
          filter(!is.na(p_value) & p_value < 0.05)

        if (nrow(significant_data) == 0) {
          # Requires: source("scripts/global_scripts/04_utils/fn_write_utf8_csv.R")
          write_utf8_csv_with_bom(data.frame(訊息 = "無顯著結果"), file)
        } else {
          # PHASE 4: Include display_name_safe in significant results export
          # #758: Technical Name column removed — raw `predictor` carried #733 `_rating` suffix
          table_data <- significant_data %>%
            dplyr::select(
              display_name_safe,
              rating_type,
              track_multiplier,
              marginal_effect_pct,
              practical_meaning,
              coefficient,
              p_value,
              sample_size
            ) %>%
            mutate(
              coefficient = round(coefficient, 4),
              p_value = round(p_value, 4),
              # All results here are significant
              significance = case_when(
                p_value < 0.001 ~ "***",
                p_value < 0.01 ~ "**",
                TRUE ~ "*"
              )
            )

          colnames(table_data) <- sapply(c("WOM Metric", "Variable Type", "Track Multiplier", "Marginal Effect%",
                                   "Business Meaning", "Coefficient", "P-Value", "Sample Size", "Significance"), translate)

          # Requires: source("scripts/global_scripts/04_utils/fn_write_utf8_csv.R")
          write_utf8_csv_with_bom(table_data, file)
        }
      }
    )

    # ------------ AI Market Track Insights Generation --------------------
    ai_insight_result <- reactiveVal(NULL)
    
    # Get OpenAI API key from environment
    gpt_key <- Sys.getenv("OPENAI_API_KEY", "")
    if (!nzchar(gpt_key)) {
      gpt_key <- NULL
    }
    
    observeEvent(input$generate_market_track_insight, {
      data <- comment_data()

      if (is.null(data) || nrow(data) == 0) {
        showNotification("無可用的市場賽道分析資料", type = "warning")
        return()
      }

      if (is.null(gpt_key)) {
        showNotification("OpenAI API 金鑰未設定。AI 分析功能已停用。", type = "error")
        return()
      }

      # Following UI_R019: AI Process Notification Rule
      # Following MP088: Immediate Feedback Principle
      # Show initial notification without auto-dismiss
      showNotification(
        COMMENT_ANALYSIS_STAGE_MESSAGES$start,
        id = "market_track_progress",
        type = "message",
        duration = NULL,  # Don't auto-dismiss
        closeButton = FALSE
      )

      # MP031: Defensive Programming - wrap in tryCatch
      tryCatch({

        # Prepare rating/review data for AI analysis
        rating_summary <- data %>%
          group_by(rating_type) %>%
          summarise(
            avg_track_multiplier = round(mean(track_multiplier, na.rm = TRUE), 2),
            max_track_multiplier = round(max(track_multiplier, na.rm = TRUE), 2),
            avg_marginal_effect = round(mean(abs(marginal_effect_pct), na.rm = TRUE), 1),
            count = n()
          ) %>%
          arrange(desc(avg_track_multiplier))

        # Get top individual factors
        # #758: use display_name_safe (post-#756 strip) to prevent AI from echoing `_rating` suffix
        top_factors <- data %>%
          slice_head(n = 8) %>%
          mutate(
            factor_summary = paste0(
              display_name_safe, " (", rating_type, "): ",
              "賽道倍數=", track_multiplier,
              ", 邊際效應=", abs(marginal_effect_pct), "%"
            )
          ) %>%
          pull(factor_summary)

        # OpenAI functions should already be loaded from union_production_test.R
        if (!exists("chat_api")) {
          stop("OpenAI functions not loaded. Please check union_production_test.R initialization.")
        }

        # Load centralized prompt configuration (MP123: AI Prompt Configuration Management)
        prompt_config <- load_openai_prompt("poisson_analysis.market_track_strategy")

        # Prepare data for prompt template
        rating_summary_json <- jsonlite::toJSON(rating_summary, dataframe = "rows", auto_unbox = TRUE)
        top_factors_text <- paste(top_factors, collapse = "\n")

        # Replace user template variables only (system_prompt already resolved by load_openai_prompt)
        user_content <- prompt_config$user_prompt_template
        user_content <- gsub("{rating_summary}", rating_summary_json, user_content, fixed = TRUE)
        user_content <- gsub("{top_factors}", top_factors_text, user_content, fixed = TRUE)

        # Create messages (system_prompt already resolved by load_openai_prompt, MP032: DRY)
        sys <- list(role = "system", content = prompt_config$system_prompt)
        usr <- list(role = "user", content = user_content)

        # Update notification for AI analysis stage
        # Following UI_R019: Multi-stage notifications for processes > 10s
        showNotification(
          COMMENT_ANALYSIS_STAGE_MESSAGES$analyzing,
          id = "market_track_progress",
          type = "message",
          duration = NULL,
          closeButton = FALSE
        )

        # Use model from centralized config (MP051: Explicit Parameter Specification)
        txt <- chat_api(list(sys, usr), gpt_key, model = prompt_config$model)

        ai_insight_result(txt)

        # Show AI insights section
        shinyjs::show("ai_market_insights_section")

        # Scroll to AI insights
        shinyjs::runjs(paste0("document.getElementById('", session$ns("ai_market_insights_section"), "').scrollIntoView({behavior: 'smooth'});"))

        # Remove progress notification and show completion
        # Following MP088: Immediate Feedback Principle
        removeNotification("market_track_progress")
        showNotification(
          COMMENT_ANALYSIS_STAGE_MESSAGES$complete,
          type = "message",
          duration = 3  # Auto-dismiss after 3 seconds
        )

      }, error = function(e) {
        # Following MP031: Defensive Programming
        # Remove progress notification and show error
        removeNotification("market_track_progress")
        showNotification(
          paste(COMMENT_ANALYSIS_STAGE_MESSAGES$error, "：", e$message),
          type = "error",
          duration = 5
        )
      })
    })
    
    # Render AI insights
    output$market_track_insight_output <- renderUI({
      txt <- ai_insight_result()
      
      if (is.null(txt)) {
        return(NULL)
      }
      
      # Clean and convert to HTML
      res <- strip_code_fence(txt)
      if (requireNamespace("markdown", quietly = TRUE)) {
        html <- markdown::markdownToHTML(text = res, fragment.only = TRUE)
        HTML(html)
      } else {
        # Fallback
        HTML(paste0("<pre>", res, "</pre>"))
      }
    })
    
    # 返回響應式值
    return(list(
      analysis_data = analysis_data,
      comment_data = comment_data,
      component_status = component_status,
      ai_insight_result = ai_insight_result
    ))
  })
}

# 組件包裝器 ------------------------------------------------------------------
poissonCommentAnalysisComponent <- function(id, app_data_connection = NULL, 
                                          config = NULL, translate = identity) {
  list(
    ui = list(
      filter = poissonCommentAnalysisFilterUI(id, translate),
      display = poissonCommentAnalysisUI(id, translate)
    ),
    server = function(input, output, session) {
      poissonCommentAnalysisServer(id, app_data_connection, config, session, translate = translate)
    }
  )
}
