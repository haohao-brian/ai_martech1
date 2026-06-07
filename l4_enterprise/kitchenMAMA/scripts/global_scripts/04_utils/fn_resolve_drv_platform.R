#' Resolve DRV platform identity from orchestrator env vars or CLI flag
#'
#' Implements DM_R066 (DRV Platform Agnosticism) resolution mechanism for
#' platform-agnostic DRV scripts (e.g., `shared/update_scripts/DRV/D04/D04_02.R`).
#' Platform identity flows from runtime via three fallback sources in priority:
#'
#'   1. `Sys.getenv("DRV_PLATFORM")`  — primary (new env var introduced by DM_R066)
#'   2. `Sys.getenv("MAMBA_PLATFORM")` — fallback (existing orchestrator env var,
#'                                       backward compat with _targets.R)
#'   3. `--platform <code>` CLI flag  — last resort (direct Rscript invocation)
#'
#' Empty resolution + invalid platform code both fail-fast via `stop()` with
#' structured error messages per DM_R066 contract.
#'
#' SIBLING: `fn_resolve_active_platform.R` (Shiny app context — resolves user
#' filter selection ("all" / specific platform) against config's active list).
#' This helper is for **orchestrator path** (env var / CLI input), NOT user
#' filter resolution. Both share the "validate against active platforms"
#' concern but differ in input shape.
#'
#' @param args Character vector. Command-line args (default
#'   `commandArgs(trailingOnly = TRUE)`). Allows test injection.
#' @param config List. App config (typically loaded by `autoinit()`). When
#'   `NULL`, the helper attempts to load via `get_platform_config()` if the
#'   function is available. Defaults to `NULL` (auto-detect).
#' @return Character scalar. Resolved + validated platform code.
#' @export
#'
#' @examples
#' \dontrun{
#'   # Orchestrator path (preferred)
#'   Sys.setenv(MAMBA_PLATFORM = "cbz")
#'   platform <- resolve_drv_platform()  # "cbz"
#'
#'   # Direct invocation with CLI flag
#'   # $ Rscript D04_02.R --platform eby
#'   platform <- resolve_drv_platform()  # "eby"
#'
#'   # DRV_PLATFORM takes precedence over MAMBA_PLATFORM
#'   Sys.setenv(DRV_PLATFORM = "amz", MAMBA_PLATFORM = "cbz")
#'   platform <- resolve_drv_platform()  # "amz"
#'
#'   # Fail-fast on missing platform
#'   Sys.unsetenv("DRV_PLATFORM"); Sys.unsetenv("MAMBA_PLATFORM")
#'   platform <- resolve_drv_platform(args = character(0))
#'   # Error: DM_R066 violation: platform unresolved
#' }
resolve_drv_platform <- function(args = commandArgs(trailingOnly = TRUE),
                                  config = NULL) {
  # Tier 1: DRV_PLATFORM env var (primary)
  platform <- Sys.getenv("DRV_PLATFORM", unset = "")

  # Tier 2: MAMBA_PLATFORM env var (fallback — orchestrator backward compat)
  if (!nzchar(platform)) {
    platform <- Sys.getenv("MAMBA_PLATFORM", unset = "")
  }

  # Tier 3: --platform <code> CLI flag (last resort)
  if (!nzchar(platform)) {
    idx <- which(args == "--platform")
    if (length(idx) == 1L && idx < length(args)) {
      platform <- args[[idx + 1L]]
    }
  }

  if (!nzchar(platform)) {
    stop(
      "DM_R066 violation: platform unresolved.\n",
      "  Resolution sources tried (in order):\n",
      "    1. Sys.getenv('DRV_PLATFORM')\n",
      "    2. Sys.getenv('MAMBA_PLATFORM')\n",
      "    3. --platform <code> CLI flag\n",
      "  Set one of them, or invoke via the orchestrator (make run LAYER=drv).",
      call. = FALSE
    )
  }

  # Pseudo-platform "all" is a Shiny-UI concept (user clicks "全部" radio),
  # NOT a valid DRV invocation target — DRV scripts run per concrete platform.
  if (identical(platform, "all")) {
    stop(
      "DM_R066 violation: platform='all' is invalid for DRV scripts.\n",
      "  DRV scripts operate per concrete platform. Resolve to a specific\n",
      "  platform code (cbz / eby / amz / etc.) before invoking.\n",
      "  If you want to run D04 across all platforms, use the orchestrator:\n",
      "    make run LAYER=drv TARGET=D04_02",
      call. = FALSE
    )
  }

  # Validate against active platforms in config (rejects typos)
  active_platforms <- character(0)
  if (is.null(config) && exists("get_platform_config", mode = "function")) {
    config <- tryCatch(get_platform_config(), error = function(e) NULL)
  }
  if (!is.null(config)) {
    # Format A (canonical): config$platforms = named list with $status per entry
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

  if (length(active_platforms) > 0 && !platform %in% active_platforms) {
    stop(
      "DM_R066 violation: platform '", platform, "' not in active config.\n",
      "  Valid platforms: ", paste(active_platforms, collapse = ", "), "\n",
      "  Check your env var or --platform CLI flag for typos.",
      call. = FALSE
    )
  }

  platform
}
