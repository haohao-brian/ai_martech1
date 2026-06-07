# Pre-deploy sanity check — refuses inconsistent config combinations (#595)
#
# Purpose:
#   Detect the #595 production-affecting bug class (config and deploy rules
#   contradict each other) BEFORE the deploy bundle ships to Posit Connect
#   Cloud. Specifically, refuse when:
#     - app_config.yaml says database.mode='duckdb', AND
#     - .rsconnectignore excludes *.duckdb (which is the canonical setup
#       per DM_R063 deploy bundle purity)
#   ...because production would then read a non-existent file.
#
# Also refuse when:
#     - mode='supabase' but SUPABASE_DB_HOST env var is not set
#     - mode='auto' AND duckdb file missing AND SUPABASE_DB_HOST not set
#
# Usage (from any company project root):
#   Rscript scripts/global_scripts/23_deployment/preflight_deploy_check.R
#   # exit 0 = pass, exit 1 = fail with stderr message
#
# Or sourced + called as a function:
#   source("scripts/global_scripts/23_deployment/preflight_deploy_check.R")
#   preflight_deploy_check()  # throws stop() on failure
#
# Escape hatch (emergency override only):
#   IDD_DEPLOY_FORCE=1 Rscript scripts/global_scripts/23_deployment/preflight_deploy_check.R
#
# Hook into Makefile:
#   deploy-sync: preflight
#   preflight:
#       @Rscript scripts/global_scripts/23_deployment/preflight_deploy_check.R
#
# Related:
#   - #595 root cause (mode='duckdb' + .rsconnectignore exclusion)
#   - DM_R063 (Deploy Bundle Purity — *.duckdb excluded by design)
#   - Phase B Step 4 of approved Plan #595

#' Run pre-deploy sanity checks. Throws stop() with actionable error on
#' inconsistency. Silent return on pass.
#'
#' @param config_path Path to app_config.yaml (default: cwd-relative)
#' @param rsconnectignore_path Path to .rsconnectignore (default: cwd-relative)
#' @param verbose Print pass message on success
#' @return invisible(TRUE) on pass; stop() on fail
#' @export
preflight_deploy_check <- function(config_path = "app_config.yaml",
                                    rsconnectignore_path = ".rsconnectignore",
                                    verbose = TRUE) {
  # Escape hatch (emergency only — should never normally be set)
  if (identical(Sys.getenv("IDD_DEPLOY_FORCE"), "1")) {
    if (verbose) {
      message("[preflight] IDD_DEPLOY_FORCE=1 — skipping checks (emergency override)")
    }
    return(invisible(TRUE))
  }

  # 1. Read app_config.yaml
  if (!file.exists(config_path)) {
    stop("[preflight] FAIL: app_config.yaml not found at '", config_path,
         "'. Run from project root (where app_config.yaml lives).")
  }
  cfg <- tryCatch(
    yaml::read_yaml(config_path),
    error = function(e) {
      stop("[preflight] FAIL: cannot parse '", config_path, "': ", e$message)
    }
  )
  if (is.null(cfg$database)) {
    stop("[preflight] FAIL: app_config.yaml has no 'database:' section. ",
         "Add it explicitly with mode='auto' (or 'duckdb'/'supabase').")
  }
  mode <- cfg$database$mode
  if (is.null(mode) || !nzchar(mode)) {
    stop("[preflight] FAIL: app_config.yaml database.mode is empty. ",
         "Set explicitly to 'auto' (recommended), 'duckdb', or 'supabase'.")
  }
  if (!mode %in% c("auto", "duckdb", "supabase")) {
    stop("[preflight] FAIL: invalid database.mode='", mode, "'. ",
         "Must be one of: auto, duckdb, supabase.")
  }

  # 2. Mode-specific consistency checks
  if (mode == "duckdb") {
    duckdb_path <- if (!is.null(cfg$database$duckdb$path)) {
      cfg$database$duckdb$path
    } else {
      "data/app_data/app_data.duckdb"
    }

    if (!file.exists(duckdb_path)) {
      stop("[preflight] FAIL: mode='duckdb' but file missing at '", duckdb_path, "'. ",
           "Either:\n",
           "  1. Run ETL pipeline to create the file, OR\n",
           "  2. Change mode to 'auto' or 'supabase' in app_config.yaml")
    }

    # CRITICAL: catch the #595 bug — mode=duckdb but .rsconnectignore excludes it.
    # Production would receive deploy bundle without duckdb file → app fails.
    if (file.exists(rsconnectignore_path)) {
      ignore_lines <- readLines(rsconnectignore_path, warn = FALSE)
      ignore_pattern <- "^[[:space:]]*\\*\\.duckdb[[:space:]]*$"
      if (any(grepl(ignore_pattern, ignore_lines))) {
        stop("[preflight] FAIL: #595 production-affecting config combo detected!\n\n",
             "  app_config.yaml:    database.mode='duckdb'\n",
             "  .rsconnectignore:   excludes '*.duckdb'\n\n",
             "Production deploy bundle would NOT include the .duckdb file, but the\n",
             "deployed app would try to read it (mode='duckdb' is strict). The result\n",
             "is broken dashboards on Connect Cloud.\n\n",
             "Fix:\n",
             "  Change app_config.yaml database.mode to 'auto'.\n",
             "  'auto' uses local duckdb when present (dev) and falls back to Supabase\n",
             "  in production (where the file is intentionally excluded per DM_R063).")
      }
    }

  } else if (mode == "supabase") {
    if (!nzchar(Sys.getenv("SUPABASE_DB_HOST", ""))) {
      stop("[preflight] FAIL: mode='supabase' but SUPABASE_DB_HOST env var not set. ",
           "Either:\n",
           "  1. Set SUPABASE_DB_HOST + SUPABASE_DB_PASSWORD in .env, OR\n",
           "  2. Change mode to 'auto' or 'duckdb' in app_config.yaml")
    }
    if (!nzchar(Sys.getenv("SUPABASE_DB_PASSWORD", ""))) {
      stop("[preflight] FAIL: mode='supabase' but SUPABASE_DB_PASSWORD env var not set.")
    }

  } else if (mode == "auto") {
    # auto mode is the most flexible; just warn if neither backend is reachable
    duckdb_path <- if (!is.null(cfg$database$duckdb$path)) {
      cfg$database$duckdb$path
    } else {
      "data/app_data/app_data.duckdb"
    }
    duckdb_ok <- file.exists(duckdb_path) &&
      (!is.na(file.info(duckdb_path)$size) && file.info(duckdb_path)$size > 1000)
    supabase_ok <- nzchar(Sys.getenv("SUPABASE_DB_HOST", "")) &&
      nzchar(Sys.getenv("SUPABASE_DB_PASSWORD", ""))

    if (!duckdb_ok && !supabase_ok) {
      stop("[preflight] FAIL: mode='auto' but neither backend available.\n",
           "  DuckDB at '", duckdb_path, "': ",
           if (!file.exists(duckdb_path)) "not found"
           else if (file.info(duckdb_path)$size <= 1000) "too small (LFS pointer?)"
           else "OK", "\n",
           "  Supabase env: ",
           if (nzchar(Sys.getenv("SUPABASE_DB_HOST", ""))) "host set"
           else "SUPABASE_DB_HOST not set", "\n\n",
           "Fix at least one:\n",
           "  1. Run ETL to populate local duckdb, OR\n",
           "  2. Set SUPABASE_DB_HOST + SUPABASE_DB_PASSWORD in .env")
    }
  }

  if (verbose) {
    message("[preflight] PASS: app_config.yaml mode='", mode, "' is consistent ",
            "with deploy environment.")
  }
  invisible(TRUE)
}


# When run directly (Rscript), exit 0/1 on pass/fail
if (!interactive() && length(commandArgs(trailingOnly = FALSE)) > 0) {
  args <- commandArgs(trailingOnly = FALSE)
  invoked_as_script <- any(grepl("--file=.*preflight_deploy_check\\.R$", args))
  if (invoked_as_script) {
    result <- tryCatch({
      preflight_deploy_check()
      0L
    }, error = function(e) {
      message(conditionMessage(e))
      1L
    })
    quit(save = "no", status = result)
  }
}
