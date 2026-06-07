#' loadOpenAIPrompt  ----------------------------------------------------------
#' 載入集中式 OpenAI prompt 設定
#'
#' 從預先載入的 app_configs$ai_prompts 存取指定的 AI prompt 配置。
#' 支援 system_prompt 參照解析（例如：{system_prompts.product_strategist.content}）。
#' 支援巢狀路徑存取（例如："position_analysis.strategy_quadrant_analysis"）。
#'
#' **重要 (MP123: AI Prompt Configuration Management)**:
#' - 此函數從預先載入的 app_configs 讀取，不會重新讀取 YAML 檔案
#' - YAML 檔案在 initialization 階段已載入至 app_configs$ai_prompts
#' - 這確保配置只載入一次，提升效能並避免檔案路徑問題
#'
#' @param prompt_name Character. prompt 名稱，支援點分隔的巢狀路徑（如 "position_analysis.strategy_quadrant_analysis"）
#' @param locale Character. 選填的 locale 鍵（如 "zh_tw" / "en"）。當 system_prompt 或
#'   user_prompt_template 是 locale-mapped(plain list of locale → string)時用來挑選
#'   對應 locale 的字串。若值為純字串(legacy 格式)則 locale 參數會被忽略。預設 "zh_tw"
#'   per DEV_R053(本專案 zh_TW 為主要 UI 語言)。Verify finding F5 (#404 Codex P2,
#'   2026-05-04): 支援 locale-mapped fields 是 DEV_R053 spec 要求,本函數補上實作。
#'
#' @return List 含 model, system_prompt, user_prompt_template
#' @export
#' @examples
#' # 載入策略四象限分析的 prompt (MP123: 從預載配置讀取)
#' prompt_config <- load_openai_prompt("position_analysis.strategy_quadrant_analysis")
#'
#' # 載入 locale-aware prompt(per DEV_R053):
#' prompt_config <- load_openai_prompt("position_analysis.key_factor_ipa_insights",
#'                                     locale = "zh_tw")
#'
#' # 使用載入的 prompt 設定 (MP051: Explicit Parameter Specification)
#' messages <- list(
#'   list(role = "system", content = prompt_config$system_prompt),
#'   list(role = "user", content = gsub("{strategy_data}", strategy_txt,
#'                                     prompt_config$user_prompt_template))
#' )
load_openai_prompt <- function(prompt_name, locale = "zh_tw") {

  # ---- 從預載配置讀取 (MP123: AI Prompt Configuration Management) ----------
  # 檢查 app_configs 是否已載入 OpenAI prompts
  if (!exists("app_configs", envir = .GlobalEnv) ||
      is.null(app_configs$ai_prompts)) {
    stop(
      "app_configs$ai_prompts not initialized. ",
      "Please ensure initialization script has loaded the OpenAI prompt configuration. ",
      "See MP123: AI Prompt Configuration Management"
    )
  }

  prompts <- app_configs$ai_prompts

  # ---- 處理巢狀路徑存取 (MP051: Explicit Parameter Specification) ----------
  if (grepl("\\.", prompt_name)) {
    # 支援點分隔的巢狀路徑，例如："position_analysis.strategy_quadrant_analysis"
    path_parts <- strsplit(prompt_name, "\\.")[[1]]
    prompt_config <- prompts

    for (i in seq_along(path_parts)) {
      part <- path_parts[i]
      if (is.list(prompt_config) && part %in% names(prompt_config)) {
        prompt_config <- prompt_config[[part]]
      } else {
        # 提供清楚的錯誤訊息，顯示可用的選項
        if (i == 1) {
          available_options <- paste(names(prompts), collapse = ", ")
          stop("Top-level section '", part, "' not found. Available sections: ",
               available_options)
        } else {
          parent_path <- paste(path_parts[1:(i-1)], collapse = ".")
          available_options <- paste(names(prompt_config), collapse = ", ")
          stop("Key '", part, "' not found in '", parent_path,
               "'. Available options: ", available_options)
        }
      }
    }
  } else {
    # 簡單的頂層存取
    if (!prompt_name %in% names(prompts)) {
      available_prompts <- paste(names(prompts), collapse = ", ")
      stop("Prompt '", prompt_name, "' not found in YAML. Available prompts: ",
           available_prompts)
    }
    prompt_config <- prompts[[prompt_name]]
  }

  # ---- Locale-aware field resolution (DEV_R053, verify finding F5) ---------
  # If system_prompt / user_prompt_template is a list keyed by locale (e.g.
  # `system_prompt: {en: "...", zh_tw: "..."}`), select the matching locale.
  # Falls back to "en" if requested locale absent. Legacy scalar values
  # pass through untouched (backward compat).
  # Validate that the picked locale value is a scalar string (#552 fix).
  # If yaml schema evolves to nested list (e.g. `{en: {content: '...', priority: 1}}`)
  # or any non-character shape, fail loudly here instead of letting the
  # non-string flow through to the API call.
  ensure_scalar_string <- function(v, field_name, used_locale) {
    if (is.character(v) && length(v) == 1) {
      return(v)
    }
    warning(sprintf(
      "Prompt '%s' field '%s' locale '%s' is not a scalar string (class: %s, length: %d); coerced via as.character()[1]",
      prompt_name, field_name, used_locale, class(v)[1], length(v)))
    as.character(v)[1]
  }

  resolve_locale_field <- function(field, field_name) {
    if (is.null(field)) return(field)
    # Already a scalar string → legacy format, no locale resolution needed
    if (is.character(field) && length(field) == 1) return(field)
    # Locale-mapped: list with character entries
    if (is.list(field)) {
      if (!is.null(locale) && locale %in% names(field)) {
        return(ensure_scalar_string(field[[locale]], field_name, locale))
      }
      # Fallback to "en" if requested locale not present
      if ("en" %in% names(field)) {
        warning(sprintf("Prompt '%s' field '%s' missing locale '%s'; falling back to 'en'",
                        prompt_name, field_name, locale))
        return(ensure_scalar_string(field[["en"]], field_name, "en"))
      }
      # Last resort: take first available locale
      first_locale <- names(field)[1]
      warning(sprintf("Prompt '%s' field '%s' missing locale '%s' and 'en'; using '%s'",
                      prompt_name, field_name, locale, first_locale))
      return(ensure_scalar_string(field[[first_locale]], field_name, first_locale))
    }
    # Unknown shape (#553 fix) — warn instead of silent fall-through.
    # Caller's required_fields check passes if key exists; without this warning
    # the non-string value lands in API call and only blows up there.
    warning(sprintf(
      "Prompt '%s' field '%s' has unexpected shape (class: %s); returning as-is",
      prompt_name, field_name, class(field)[1]))
    field
  }

  prompt_config$system_prompt <- resolve_locale_field(
    prompt_config$system_prompt, "system_prompt")
  prompt_config$user_prompt_template <- resolve_locale_field(
    prompt_config$user_prompt_template, "user_prompt_template")

  # ---- 解析 system_prompt 參照 (MP032: DRY - reuse common prompts) --------
  # Operates on the (now-resolved) scalar system_prompt.
  if (!is.null(prompt_config$system_prompt) &&
      is.character(prompt_config$system_prompt) &&
      length(prompt_config$system_prompt) == 1 &&
      grepl("\\{.*\\}", prompt_config$system_prompt)) {

    # 解析參照格式：{system_prompts.product_strategist.content}
    ref_pattern <- "\\{(.+)\\}"
    ref_match <- regmatches(prompt_config$system_prompt,
                           regexpr(ref_pattern, prompt_config$system_prompt))

    if (length(ref_match) > 0) {
      ref_path <- gsub("[{}]", "", ref_match)
      path_parts <- strsplit(ref_path, "\\.")[[1]]

      # 遞迴解析參照路徑 (MP031: Separation of Concerns)
      resolved_value <- prompts
      for (part in path_parts) {
        if (is.list(resolved_value) && part %in% names(resolved_value)) {
          resolved_value <- resolved_value[[part]]
        } else {
          warning("Cannot resolve system_prompt reference: ", ref_path)
          resolved_value <- prompt_config$system_prompt  # 保持原值
          break
        }
      }
      prompt_config$system_prompt <- resolved_value
    }
  }

  # ---- 驗證必要欄位 (MP051: Explicit Parameter Specification) -------------
  required_fields <- c("model", "system_prompt", "user_prompt_template")
  missing_fields <- setdiff(required_fields, names(prompt_config))

  if (length(missing_fields) > 0) {
    stop("Missing required fields in prompt '", prompt_name, "': ",
         paste(missing_fields, collapse = ", "))
  }

  # Catch explicit YAML `null` / empty strings that pass key-existence check
  # above but break OpenAI API calls late. (#559)
  is_empty <- function(v) {
    is.null(v) || !is.character(v) || length(v) == 0L || nchar(v[[1]]) < 1L
  }
  empty_fields <- required_fields[
    vapply(prompt_config[required_fields], is_empty, logical(1))
  ]
  if (length(empty_fields) > 0) {
    stop("Required fields are NULL or empty in prompt '", prompt_name, "': ",
         paste(empty_fields, collapse = ", "))
  }

  return(prompt_config)
}