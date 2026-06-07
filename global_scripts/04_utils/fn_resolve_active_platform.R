#' Resolve a chosen platform_id to a concrete active platform code
#'
#' Sidebar 全域 filter 提供「所有平台 (all) + 各 active platform」radio buttons.
#' 某些下游 data tables (e.g. `df_{platform}_poisson_analysis_all`) 是 per-platform,
#' 沒有 cross-platform aggregated 版本。當 user 選 "all" 或 helper 取到 NULL/未知
#' platform 時,需 fallback 到 config 的第一個 active platform。
#'
#' For QEF_DESIGN (active platforms = c("amz")):
#'   resolve_active_platform("all", cfg)  -> "amz"
#'   resolve_active_platform("amz", cfg)  -> "amz"
#'
#' For MAMBA (active platforms = c("cbz", "eby")):
#'   resolve_active_platform("all", cfg)  -> "cbz"
#'   resolve_active_platform("eby", cfg)  -> "eby"
#'
#' @param platform_id Character. The chosen platform id (may be "all", NULL,
#'   or a specific platform code).
#' @param config List. App config containing `platforms` named list with
#'   per-platform `status` field. May also be NULL.
#' @param fallback Character. Last-resort fallback when config has no active
#'   platforms. Default `NULL` (causes `stop()`).
#' @return Character scalar. Resolved platform code.
#' @export
resolve_active_platform <- function(platform_id = NULL,
                                    config = NULL,
                                    fallback = NULL) {
  active_platforms <- character(0)
  if (!is.null(config)) {
    # Format A (canonical): config$platforms = named list with per-platform $status
    if (!is.null(config$platforms) &&
        is.list(config$platforms) &&
        !is.null(names(config$platforms))) {
      active_platforms <- vapply(names(config$platforms), function(pid) {
        entry <- config$platforms[[pid]]
        is_active <- is.list(entry) && identical(entry$status, "active")
        if (is_active) pid else NA_character_
      }, character(1))
      active_platforms <- active_platforms[!is.na(active_platforms)]
    }
    # Format B (legacy WISER/kitchenMAMA): config$platform = character vector
    if (length(active_platforms) == 0 &&
        !is.null(config$platform) &&
        is.character(config$platform) &&
        length(config$platform) > 0) {
      active_platforms <- as.character(config$platform)
    }
  }

  if (!is.null(platform_id) &&
      length(platform_id) == 1 &&
      !is.na(platform_id) &&
      nzchar(platform_id) &&
      platform_id != "all" &&
      (length(active_platforms) == 0 || platform_id %in% active_platforms)) {
    return(as.character(platform_id))
  }

  if (length(active_platforms) > 0) {
    return(active_platforms[[1]])
  }

  if (!is.null(fallback) && length(fallback) == 1 && nzchar(fallback)) {
    return(as.character(fallback))
  }

  stop("resolve_active_platform: no active platform found in config; ",
       "platform_id='", paste(platform_id, collapse = ","),
       "' and config$platforms has no entry with status='active'")
}
