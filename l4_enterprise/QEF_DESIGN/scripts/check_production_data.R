# Production smoke test for deployed QEF_DESIGN dashboard (#595 Phase B Step 5)
#
# Purpose:
#   Detect when the deployed Posit Connect Cloud app is broken at startup
#   (e.g., #595 mode-misconfig, missing Supabase env, Shiny crash) WITHOUT
#   requiring login. HTTP-level checks against the landing page:
#     - HTTP 200 reachable
#     - Response contains expected Shiny / bs4Dash markers (app loaded)
#     - Response does NOT contain Connect's generic error page markers
#
# What this DOES NOT do:
#   - Login + click through to BrandEdge / TagPilot tabs (requires
#     browser automation; use safari-browser for that — see shared
#     CLAUDE.md rule 08-shiny-testing.md "Live Dashboard 驗證")
#   - Validate that data flows through to KPI cards (deeper smoke,
#     deferred to follow-up; that's #596 systematic framework scope)
#
# Usage:
#   # From QEF_DESIGN project root, after deploy completes:
#   Rscript scripts/check_production_data.R
#
#   # Override URL (e.g., to test a specific Connect deployment):
#   APP_URL=https://your-connect-deployment.share.connect.posit.cloud/ \
#     Rscript scripts/check_production_data.R
#
# Exit codes:
#   0 = all checks pass
#   1 = check failed (see stderr)
#   2 = configuration error (URL not resolved, network unreachable)
#
# Retry behavior:
#   Connect Cloud takes 30-60s to spin up after deploy. This script does
#   3 attempts with exponential backoff (10s / 30s / 60s) to avoid
#   false-positive failures when checking immediately post-deploy.

# Required packages
for (pkg in c("httr", "yaml")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Missing required package: ", pkg, ". Run install.packages('", pkg, "')")
  }
}

#' Run production smoke check against deployed Connect Cloud app.
#'
#' @param url Full URL of deployed app. If NULL, reads from APP_URL env or
#'   constructs from app_config.yaml.
#' @param max_attempts Number of HTTP retry attempts (default 3).
#' @param timeout_sec HTTP request timeout (default 30s; Connect cold start
#'   can take 30-60s).
#' @param verbose Print progress messages (default TRUE).
#' @return invisible(TRUE) on pass; stop() on failure.
#' @export
check_production_data <- function(url = NULL,
                                   max_attempts = 3L,
                                   timeout_sec = 30L,
                                   verbose = TRUE) {
  # 1. Resolve URL
  url <- url %||% Sys.getenv("APP_URL", "")
  if (!nzchar(url)) {
    # Try app_config.yaml deployment.app_url
    if (file.exists("app_config.yaml")) {
      cfg <- yaml::read_yaml("app_config.yaml")
      url <- cfg$deployment$app_url %||%
        cfg$deployment$url_published %||%
        cfg$deployment$deployed_url %||%
        ""
    }
  }
  if (!nzchar(url)) {
    stop("[smoke] FAIL: cannot resolve deployed URL.\n",
         "Set APP_URL env var or add deployment.app_url to app_config.yaml.\n",
         "Example: APP_URL=https://qef-design.share.connect.posit.cloud/ Rscript ...",
         call. = FALSE)
  }

  if (verbose) message("[smoke] Target URL: ", url)
  if (verbose) message("[smoke] Max attempts: ", max_attempts,
                       ", timeout: ", timeout_sec, "s, backoff: 10s/30s/60s")

  # 2. Try HTTP GET with retry + exponential backoff
  backoff_sec <- c(10, 30, 60)
  last_error <- NULL
  resp <- NULL
  for (attempt in seq_len(max_attempts)) {
    if (attempt > 1L && verbose) {
      wait <- backoff_sec[min(attempt - 1L, length(backoff_sec))]
      message("[smoke] Retry ", attempt, "/", max_attempts,
              " — waiting ", wait, "s before retry...")
      Sys.sleep(wait)
    }
    resp <- tryCatch(
      httr::GET(url, httr::timeout(timeout_sec)),
      error = function(e) {
        last_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(resp)) {
      status <- httr::status_code(resp)
      if (verbose) message("[smoke] Attempt ", attempt,
                           " — HTTP ", status)
      if (status == 200L) break
      last_error <- paste("HTTP", status)
    }
  }

  if (is.null(resp)) {
    stop("[smoke] FAIL: cannot reach URL after ", max_attempts,
         " attempts. Last error: ", last_error,
         "\nIs the app deployed? Is the URL correct?",
         call. = FALSE)
  }

  status <- httr::status_code(resp)
  if (status != 200L) {
    stop("[smoke] FAIL: HTTP ", status,
         " from ", url,
         "\nApp may have crashed at startup, or URL is wrong, or",
         " Connect Cloud auth is blocking the smoke (Connect Cloud sometimes",
         " requires login at the URL itself, in which case smoke needs",
         " a session cookie or browser automation — see safari-browser).",
         call. = FALSE)
  }

  body <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (verbose) message("[smoke] Response body: ", nchar(body), " chars")

  # 3. Positive check — response contains expected markers
  expected_markers <- c(
    # Shiny-rendered HTML signature
    "<title>",
    # bs4Dash / shiny dependencies
    "shiny"
  )
  for (marker in expected_markers) {
    if (!grepl(marker, body, ignore.case = TRUE, fixed = TRUE)) {
      stop("[smoke] FAIL: response missing expected marker '", marker,
           "'. The app may have crashed pre-render.\n",
           "First 500 chars of body:\n",
           substr(body, 1, 500),
           call. = FALSE)
    }
  }

  # 4. Negative check — response should NOT contain crash markers
  crash_markers <- c(
    "An error has occurred",       # Connect Cloud generic error
    "Application failed to start",  # Connect specific
    "uncaught exception",
    "ECONNREFUSED",
    "Error in ",                    # R-side error leaked to UI
    "Cannot find function"
  )
  for (marker in crash_markers) {
    if (grepl(marker, body, fixed = TRUE)) {
      stop("[smoke] FAIL: response contains crash marker '", marker, "'.\n",
           "App is reachable (HTTP 200) but rendered an error page.\n",
           "Check Connect Cloud logs for stack trace.\n",
           "Excerpt from body around the marker:\n",
           # Extract context around the marker (50 chars before + 200 after)
           {
             pos <- regexpr(marker, body, fixed = TRUE)
             from <- max(1L, pos - 50L)
             to <- min(nchar(body), pos + nchar(marker) + 200L)
             substr(body, from, to)
           },
           call. = FALSE)
    }
  }

  # 5. Soft check — empty data warning sometimes appears as user-facing text
  empty_markers <- c("無資料", "沒有資料",  # 無資料 / 沒有資料
                     "No data available")
  empty_hits <- empty_markers[vapply(empty_markers, function(m) grepl(m, body, fixed = TRUE), logical(1))]
  if (length(empty_hits) > 0) {
    if (verbose) {
      message("[smoke] WARN: response contains empty-data text(s): ",
              paste(empty_hits, collapse = ", "),
              ". This may be normal for the login screen but worth checking",
              " — could also indicate post-#595 deployment regression.")
    }
  }

  if (verbose) {
    message("[smoke] PASS: ", url, " is reachable, rendered correctly,",
            " no crash markers detected.")
  }
  invisible(TRUE)
}


# Null coalescing helper
`%||%` <- function(x, y) if (is.null(x) || (is.character(x) && !nzchar(x))) y else x


# When invoked as Rscript, exit 0/1 on pass/fail
if (!interactive() && length(commandArgs(trailingOnly = FALSE)) > 0) {
  args <- commandArgs(trailingOnly = FALSE)
  invoked_as_script <- any(grepl("--file=.*check_production_data\\.R$", args))
  if (invoked_as_script) {
    code <- tryCatch({
      check_production_data()
      0L
    }, error = function(e) {
      message(conditionMessage(e))
      # Distinguish config error from runtime fail
      if (grepl("cannot resolve deployed URL", conditionMessage(e))) 2L else 1L
    })
    quit(save = "no", status = code)
  }
}
