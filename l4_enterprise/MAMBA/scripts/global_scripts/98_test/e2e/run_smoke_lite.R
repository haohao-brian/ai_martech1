#####
# run_smoke_lite.R - MP165 Tier 1 DRV-end lite check
#
# Issue #599 / spectra change dashboard-presence-verification (task 6.1)
# v2 rewrite (#605): switched backbone from shinytest2 to
#                    nohup Rscript + agent-browser (proven in #595 reproduce).
#
# Why not shinytest2: see #604 / #605. Plotly heavy renders abort
# wait_for_idle's stability detector; shinytest2's chromote subprocess
# writes to a temp dir not the canonical .shiny-debug/shiny.log path.
# Both issues vanish when we drive the regular Rscript app.R session
# (which writes to .shiny-debug/shiny.log per DEV_R054) using
# agent-browser (proven reliable across #595 / #603 verifies).
#
# Designed to be invoked from update_scripts/DRV/_targets.R as the
# final target dashboard_smoke_lite. Runtime budget: target ~5-10s,
# hard ceiling 30s per company.
#
# Returns invisible NULL on success; stop()s on NULL detection or timeout.
#####

`%||%` <- function(a, b) if (!is.null(a)) a else b


# ---------- Internal helpers ----------

.smoke_log <- function(verbose, ...) {
  if (isTRUE(verbose)) message(sprintf("[smoke-lite] %s", paste0(...)))
}


.smoke_wait_for_listening <- function(log_path, timeout_seconds, verbose) {
  start <- Sys.time()
  url <- NULL
  while (is.null(url)) {
    if (as.numeric(Sys.time() - start, units = "secs") > timeout_seconds) {
      stop(sprintf(
        "[smoke-lite] Shiny did not print 'Listening on' within %ds. log=%s",
        timeout_seconds, log_path
      ))
    }
    Sys.sleep(1)
    if (file.exists(log_path)) {
      lines <- readLines(log_path, warn = FALSE)
      m <- regmatches(lines, regexpr("http://127\\.0\\.0\\.1:[0-9]+", lines))
      if (length(m) > 0) url <- m[[1]]
    }
    # Detect early R-level fatal error
    if (file.exists(log_path)) {
      lines <- readLines(log_path, warn = FALSE)
      err <- grep("^Error:|^Execution halted|fatal error", lines, value = TRUE)
      if (length(err) > 0) {
        stop(sprintf(
          "[smoke-lite] Shiny app crashed during startup. First error: %s\nFull log: %s",
          err[[1]], log_path
        ))
      }
    }
  }
  url
}


.smoke_kill_pid_on_port <- function(port) {
  pids <- tryCatch(
    suppressWarnings(system(sprintf("lsof -ti:%s", port), intern = TRUE)),
    error = function(e) character(0)
  )
  for (pid in pids) {
    pid_int <- suppressWarnings(as.integer(pid))
    if (!is.na(pid_int)) {
      tryCatch(tools::pskill(pid_int), error = function(e) NULL)
    }
  }
}


.agent_browser_run <- function(args, timeout_seconds = 10) {
  out <- suppressWarnings(system2(
    "agent-browser", args,
    stdout = TRUE, stderr = TRUE,
    timeout = timeout_seconds
  ))
  paste(out, collapse = "\n")
}


.smoke_extract_ref <- function(snap, line_pattern) {
  # agent-browser snapshot -i emits one line per element in this format:
  #   - <type> "<label>" [ref=eN]
  # e.g.  - link "gauge-high icon 總覽儀表板" [ref=e8]
  #       - button "進入系統" [ref=e2]
  #
  # `line_pattern` is matched against full lines; extract the `eN` from
  # the `[ref=eN]` segment and prepend `@` for agent-browser's click/fill
  # CLI which expects `@eN` form.
  lines <- strsplit(snap, "\n", fixed = TRUE)[[1]]
  hit <- lines[grepl(line_pattern, lines, perl = TRUE)]
  if (length(hit) == 0L) return(NULL)
  m <- regmatches(hit[[1]], regexpr("\\[ref=(e[0-9]+)\\]", hit[[1]], perl = TRUE))
  if (length(m) == 0L) return(NULL)
  ref_id <- sub("\\[ref=(e[0-9]+)\\]", "\\1", m[[1]])
  paste0("@", ref_id)
}


#' Extract sub-tab refs between two top-level nav anchors
#'
#' Phase 2 walker recursion (refs spectra change adaptive-dashboard-test-loop):
#' bs4Dash menu items with sub-menus only expand the sidebar accordion on
#' top-level click — main panel content stays on prior tab. To actually render
#' each sub-tab, the walker must click EACH leaf sub-tab link individually.
#'
#' Heuristic: after clicking a top-level item, sub-tabs appear in the snapshot
#' as `link "..." [ref=eN]` lines between the clicked top-level item and the
#' NEXT top-level item (or end of nav). Filters out:
#'   - global filter items (產品線 / 平台), which carry accordion `[expanded]`
#'     flag and aren't navigation targets
#'   - radio/checkbox/button elements (sub-tabs are always `link` type)
#'
#' Returns character vector of `@eN` refs (empty vector if no sub-tabs found),
#' so caller can iterate via `for (ref in subs)`. Backward-compatible: when no
#' sub-tabs detected, returns character(0) and walker falls through to top-only.
#'
#' @param snap Output from `.agent_browser_run(c("snapshot", "-i"))`
#' @param this_top_label Top-level tab label just clicked (e.g., "TagPilot")
#' @param next_top_labels Character vector of remaining top-level labels;
#'   anchor for "where do this tab's sub-tabs end". Use `character(0)` for
#'   the LAST top-level (sub-tabs extend to end of nav).
#' @return Character vector of `@eN` refs for leaf sub-tabs
.smoke_extract_sub_tab_refs <- function(snap, this_top_label, next_top_labels) {
  lines <- strsplit(snap, "\n", fixed = TRUE)[[1]]

  # Find the line index containing the clicked top-level tab.
  # Pattern matches `link "...this_top_label..." [ref=eN]` (the label may
  # have an icon prefix and trailing space).
  this_pat <- sprintf("link\\s+\"[^\"]*%s[^\"]*\"\\s+\\[ref=e[0-9]+\\]",
                      this_top_label)
  this_idx <- which(grepl(this_pat, lines, perl = TRUE))
  if (length(this_idx) == 0L) return(character(0))
  start_line <- this_idx[[1]] + 1L  # sub-tabs are AFTER the top-level line

  # Find the line index of the next top-level tab (anchor for end of this
  # tab's sub-tab range). If no next top-level appears in the snapshot, the
  # sub-tabs extend to the end of the nav.
  end_line <- length(lines) + 1L  # sentinel = end
  for (next_label in next_top_labels) {
    next_pat <- sprintf("link\\s+\"[^\"]*%s[^\"]*\"\\s+\\[ref=e[0-9]+\\]",
                        next_label)
    next_idx <- which(grepl(next_pat, lines, perl = TRUE))
    next_idx_after <- next_idx[next_idx > this_idx[[1]]]
    if (length(next_idx_after) > 0L) {
      end_line <- min(end_line, next_idx_after[[1]])
      break  # first next-top-level after current = stop
    }
  }

  if (start_line >= end_line) return(character(0))

  candidate_lines <- lines[start_line:(end_line - 1L)]

  # Extract refs from `link "..." [ref=eN]` patterns, filtering out:
  # - accordion expanders (產品線 / 平台 / `[expanded]` flags)
  # - radio/checkbox/button (sub-tabs are always `link` type)
  # - main-panel links without icon prefix (sub-tabs in sidebar all have a
  #   FontAwesome icon prefix like `chart-pie icon ...` per L4 enterprise
  #   convention; main-panel content links typically don't)
  link_pat <- "^\\s*-\\s+link\\s+\"[^\"]*\"\\s+\\[ref=(e[0-9]+)\\]"
  icon_pat <- "link\\s+\"[^\"]*\\bicon\\s+[^\"]+\""  # require ` icon ` substring
  filter_terms <- c("產品線", "平台", "[expanded]")

  refs <- character(0)
  for (ln in candidate_lines) {
    if (!grepl(link_pat, ln, perl = TRUE)) next
    # Must have FontAwesome icon prefix (sidebar nav convention)
    if (!grepl(icon_pat, ln, perl = TRUE)) next
    if (any(vapply(filter_terms, function(t) grepl(t, ln, fixed = TRUE),
                   logical(1)))) next
    m <- regmatches(ln, regexpr("\\[ref=(e[0-9]+)\\]", ln, perl = TRUE))
    if (length(m) > 0L) {
      ref_id <- sub("\\[ref=(e[0-9]+)\\]", "\\1", m[[1]])
      refs <- c(refs, paste0("@", ref_id))
    }
  }
  refs
}


.smoke_login <- function(url, password = "VIBE", verbose = TRUE) {
  .smoke_log(verbose, "opening ", url)
  .agent_browser_run(c("open", url))
  Sys.sleep(2)

  snap <- .agent_browser_run(c("snapshot", "-i"))
  # QEF / D_RACING / MAMBA password screen patterns
  pwd_ref <- .smoke_extract_ref(snap, "textbox\\s+\".*(密碼|password|Password)")
  sub_ref <- .smoke_extract_ref(snap,
    "button\\s+\"(進入系統|登入|Login|Submit|Sign in)\"")

  if (is.null(pwd_ref)) pwd_ref <- "@e1"  # typical first interactive on auth
  if (is.null(sub_ref)) sub_ref <- "@e2"  # typical second

  .smoke_log(verbose, "login: fill ", pwd_ref, " click ", sub_ref)
  .agent_browser_run(c("fill", pwd_ref, password))
  .agent_browser_run(c("click", sub_ref))
  Sys.sleep(3)
}


.smoke_walk_top_nav <- function(verbose = TRUE, recurse_sub_tabs = TRUE) {
  # Take a fresh snapshot post-login
  snap <- .agent_browser_run(c("snapshot", "-i"))
  # Top-level nav items in standard L4 enterprise layout.
  # We click each of the ones that are observable via snapshot listing.
  default_tabs <- c(
    "總覽儀表板",
    "TagPilot",
    "Marketing Vital-Signs",
    "BrandEdge",
    "InsightForge 360",
    "報告中心"
  )

  total_subs_walked <- 0L

  for (i in seq_along(default_tabs)) {
    tab_label <- default_tabs[[i]]

    # agent-browser snapshot lines look like:
    #   - link "gauge-high icon 總覽儀表板" [ref=e8]
    # Pattern: link followed by a quoted string CONTAINING the tab_label
    # (label may have an icon prefix), then [ref=eN].
    line_pat <- sprintf("link\\s+\"[^\"]*%s[^\"]*\"\\s+\\[ref=", tab_label)
    ref <- .smoke_extract_ref(snap, line_pat)
    if (is.null(ref)) {
      .smoke_log(verbose, "(skip - no nav ref for ", tab_label, ")")
      next
    }
    .smoke_log(verbose, "click ", ref, " (", tab_label, ")")
    .agent_browser_run(c("click", ref))
    # bs4Dash accordion expansion is animated (~300-600ms); some tops need
    # longer settle than top-level navigation. Use 2.5s baseline for robust
    # sub-menu detection (was 1.5s in v2 top-only walker).
    Sys.sleep(2.5)
    # Re-snapshot — sub-tabs may now be exposed in accordion
    snap <- .agent_browser_run(c("snapshot", "-i"))

    # Phase 2 walker recursion (refs spectra change adaptive-dashboard-test-loop)
    # bs4Dash top-level click only toggles sidebar accordion; main panel
    # content stays on the prior tab. Click each leaf sub-tab to actually
    # render its content (otherwise NULL detection misses sub-tab defects
    # like the InsightForge `coefficient` bug observed in #653).
    if (isTRUE(recurse_sub_tabs)) {
      remaining_tops <- if (i < length(default_tabs)) {
        default_tabs[(i + 1L):length(default_tabs)]
      } else {
        character(0)
      }
      sub_refs <- .smoke_extract_sub_tab_refs(snap, tab_label, remaining_tops)
      if (length(sub_refs) == 0L && nzchar(Sys.getenv("MP165_WALKER_DEBUG"))) {
        # Diagnostic dump for top-levels expected to have sub-tabs but where
        # detector returned empty (e.g., timing race during accordion animation)
        dump_path <- sprintf("/tmp/smoke_lite_no_subs_%s.txt",
                              gsub("[^A-Za-z0-9]", "_", tab_label))
        writeLines(snap, dump_path)
        .smoke_log(verbose, "  DEBUG: dumped snapshot to ", dump_path)
      }
      if (length(sub_refs) > 0L) {
        .smoke_log(verbose, "  found ", length(sub_refs),
                   " sub-tab(s) under ", tab_label)
        for (sub_ref in sub_refs) {
          .smoke_log(verbose, "  click ", sub_ref, " (sub-tab of ", tab_label, ")")
          .agent_browser_run(c("click", sub_ref))
          Sys.sleep(1.0)  # render settle for sub-tab main panel
          total_subs_walked <- total_subs_walked + 1L
        }
        # Re-snapshot after walking sub-tabs (sub-tab refs may shift on next
        # iteration's top-level snapshot diff)
        snap <- .agent_browser_run(c("snapshot", "-i"))
      } else {
        .smoke_log(verbose, "  (no sub-tabs under ", tab_label,
                   " — top-only walk; backward compat)")
      }
    }
  }

  .smoke_log(verbose, "walker visited ", length(default_tabs),
             " top-level tab(s) + ", total_subs_walked, " sub-tab(s)")
  invisible(list(top_level = length(default_tabs), sub_tabs = total_subs_walked))
}


# ---------- Main entry point ----------

#' Tier 1 Lite NULL Output Detection
#'
#' Launches the company's Shiny app via nohup Rscript app.R, waits for
#' "Listening on" marker, walks top-level sidebar nav via agent-browser,
#' and SCANS .shiny-debug/shiny.log for [DEBUG_MODE_NULL_OUTPUT] markers
#' emitted by debug_log_output() (DEV_R054).
#'
#' Severity-agnostic (only NULL detection); per-element contracts run
#' in Tier 2 deploy gate (dashboard_presence_gate.R), not here.
#'
#' @param company Character company code (QEF_DESIGN / D_RACING / ...)
#' @param app_dir Path to the company's app directory (default getwd())
#' @param timeout_seconds Hard ceiling for entire run; stop() if exceeded.
#'   Phase 2 walker recursion (refs adaptive-dashboard-test-loop) increases
#'   walk time to ~30-60s per company (was ~18s top-only) — default raised
#'   from 30s to 90s to accommodate sub-tab traversal.
#' @param wait_per_step_ms (kept for v1 API compat; v2 uses fixed 1.5s settle)
#' @param verbose Logical
#' @param login_password Password for auth-only mode (default: VIBE)
#' @param recurse_sub_tabs Logical. When TRUE (default, Phase 2 behavior),
#'   walker recursively clicks each leaf sub-tab under each top-level menu
#'   to actually render sub-tab content. When FALSE, walks top-level only
#'   (v2 behavior, backward compat for fast smoke runs).
#' @return invisible(NULL) on success; stop()s on NULL detection / timeout
run_dashboard_smoke_lite_check <- function(company,
                                            app_dir = getwd(),
                                            timeout_seconds = 90,
                                            wait_per_step_ms = 800,  # v1 API compat (unused)
                                            verbose = TRUE,
                                            login_password = "VIBE",
                                            recurse_sub_tabs = TRUE) {
  if (!nzchar(company)) stop("company required")
  if (!dir.exists(app_dir)) stop("app_dir does not exist: ", app_dir)

  start_time <- Sys.time()

  # Ensure agent-browser exists
  ab_check <- suppressWarnings(system2("which", "agent-browser",
                                        stdout = TRUE, stderr = TRUE))
  if (length(ab_check) == 0 || !nzchar(ab_check[1])) {
    stop("[smoke-lite] agent-browser CLI not found. Install per shared CLAUDE.md (`agent-browser` skill).")
  }

  # Use absolute paths to avoid relative-path interpretation drift after `cd`
  app_dir_abs <- normalizePath(app_dir, mustWork = TRUE)
  debug_dir <- file.path(app_dir_abs, ".shiny-debug")
  if (!dir.exists(debug_dir)) dir.create(debug_dir, recursive = TRUE)
  log_path <- file.path(debug_dir, "shiny.log")
  if (file.exists(log_path)) file.remove(log_path)

  .smoke_log(verbose, "starting for ", company, " at ", app_dir_abs)

  # Launch Shiny app via nohup (proven path from #595 reproduce)
  app_r <- file.path(app_dir_abs, "app.R")
  if (!file.exists(app_r)) stop("[smoke-lite] app.R not found at ", app_r)

  # NOTE: system(wait = FALSE) appends ' &' to the command itself; do NOT
  # add a trailing '&' here (would produce `... & &` bash syntax error).
  # Absolute log_path avoids cd-induced relative-path drift.
  cmd <- sprintf("cd %s && SHINY_DEBUG_MODE=TRUE nohup Rscript app.R > %s 2>&1",
                 shQuote(app_dir_abs), shQuote(log_path))
  system(cmd, wait = FALSE)

  # Will need to capture port for later cleanup
  port <- NULL

  cleanup_done <- FALSE
  do_cleanup <- function() {
    if (cleanup_done) return(invisible(NULL))
    cleanup_done <<- TRUE
    if (!is.null(port)) {
      .smoke_log(verbose, "cleanup: killing PID on port ", port)
      .smoke_kill_pid_on_port(port)
    }
  }
  on.exit(do_cleanup(), add = TRUE)

  # Wait for "Listening on http://127.0.0.1:NNNNN"
  url <- .smoke_wait_for_listening(log_path,
                                   timeout_seconds = min(timeout_seconds, 30),
                                   verbose = verbose)
  port <- sub(".*:", "", url)
  .smoke_log(verbose, "app listening at ", url)

  if (as.numeric(Sys.time() - start_time, units = "secs") > timeout_seconds) {
    stop(sprintf("[smoke-lite] timeout: app start took longer than %ds",
                 timeout_seconds))
  }

  # Drive via agent-browser (proven path)
  tryCatch({
    .smoke_login(url, password = login_password, verbose = verbose)
    .smoke_walk_top_nav(verbose = verbose, recurse_sub_tabs = recurse_sub_tabs)
  }, error = function(e) {
    do_cleanup()
    stop(sprintf("[smoke-lite] agent-browser drive FAILED: %s", e$message))
  })

  # Scan log for NULL output markers
  log_lines <- if (file.exists(log_path)) readLines(log_path, warn = FALSE) else character(0)
  null_markers <- grep("\\[DEBUG_MODE_NULL_OUTPUT\\]", log_lines, value = TRUE)

  elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
  .smoke_log(verbose, sprintf("%s walk complete in %.1fs (%d NULL markers)",
                              company, elapsed, length(null_markers)))

  if (elapsed > timeout_seconds) {
    do_cleanup()
    stop(sprintf("[smoke-lite] timeout: walk took %.1fs > ceiling %ds",
                 elapsed, timeout_seconds))
  }

  if (length(null_markers) > 0) {
    do_cleanup()
    detail <- paste(head(null_markers, 10), collapse = "\n  ")
    stop(sprintf(
      "[smoke-lite] FAIL: %d NULL render output(s) detected for %s.\nFirst 10 markers:\n  %s\nFull log: %s",
      length(null_markers), company, detail, log_path
    ))
  }

  do_cleanup()
  invisible(NULL)
}


# CLI entry: Rscript run_smoke_lite.R <company> [app_dir] [timeout]
if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    cat("Usage: Rscript run_smoke_lite.R <COMPANY> [APP_DIR] [TIMEOUT_SECONDS]\n")
    quit(status = 3)
  }
  co <- args[[1]]
  ad <- if (length(args) >= 2) args[[2]] else getwd()
  to <- if (length(args) >= 3) as.numeric(args[[3]]) else 30
  run_dashboard_smoke_lite_check(co, app_dir = ad, timeout_seconds = to)
  cat("[smoke-lite] PASS\n")
}
