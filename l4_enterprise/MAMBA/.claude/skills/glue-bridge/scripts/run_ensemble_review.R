# run_ensemble_review.R — bookkeeping helper for the self-converging review loop
#
# Bound by spectra change: glue-bridge-self-converging-review (#500)
# Used by /glue-bridge skill Step 6b-6d.
#
# Architecture:
#   The parent agent (Claude Code session) is the conductor. It dispatches the
#   four reviewer agents (codex via shell, claude-correctness/security/devils-advocate
#   via Agent tool) and collects their findings markdown files. This R helper
#   then takes those findings paths, parses them into structured form, computes
#   the findings hash for plateau detection, classifies the iteration outcome
#   per the convergence protocol, and appends an entry to the review log.
#
# Public API (used by SKILL.md Step 6c-6d):
#   * parse_findings_markdown(path)   -> list of finding records
#   * classify_iteration_outcome(...) -> list with $verdict (CONVERGED|PLATEAUED|
#                                          DIMINISHING|INSTABILITY|CONTINUE)
#   * append_iteration_log(...)       -> NULL (writes review log entry)
#   * run_ensemble_review(...)        -> high-level wrapper for parent agent

# Resolve sibling helper paths relative to this file.
# Capture path AT SOURCE TIME (when script is loaded), not at function-call time —
# because by then the call stack has lost the original ofile.
.RUN_ENSEMBLE_REVIEW_R_PATH <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  marker <- "--file="
  hit <- grep(marker, args, fixed = TRUE)
  if (length(hit) > 0L) return(sub(marker, "", args[hit[1L]], fixed = TRUE))
  # Walk frames to find ofile of the source() that loaded us
  for (i in seq_len(sys.nframe())) {
    of <- sys.frame(i)$ofile
    if (!is.null(of) && nzchar(of) &&
        grepl("run_ensemble_review\\.R$", of)) {
      return(of)
    }
  }
  NA_character_
})()

.script_dir <- function() {
  if (!is.na(.RUN_ENSEMBLE_REVIEW_R_PATH)) {
    return(dirname(normalizePath(.RUN_ENSEMBLE_REVIEW_R_PATH, mustWork = FALSE)))
  }
  # Fallback: assume cwd is project root and use canonical path
  candidate <- "shared/global_scripts/00_principles/.claude/skills/glue-bridge/scripts"
  if (dir.exists(candidate)) return(normalizePath(candidate, mustWork = FALSE))
  getwd()
}

# Load findings_hash helper (sibling file)
.load_hash_helper <- function() {
  hp <- file.path(.script_dir(), "findings_hash.R")
  if (file.exists(hp)) source(hp, local = parent.frame()) else
    stop("findings_hash.R not found at: ", hp)
}

# ---- Severity normalization (shared with findings_hash) ----------------------
.normalize_severity <- function(s) {
  if (is.null(s) || length(s) == 0L || is.na(s)) return("UNKNOWN")
  toupper(trimws(as.character(s)))
}

.severity_rank <- function(s) {
  switch(.normalize_severity(s),
    CRITICAL = 5L,
    HIGH = 4L,
    MEDIUM = 3L,
    LOW = 2L,
    SUGGESTION = 1L,
    NONE = 0L,
    UNKNOWN = 0L,
    0L
  )
}

#' Parse a reviewer's findings markdown into a list of finding records.
#'
#' Reviewers (codex / correctness / security / devils-advocate) all emit
#' markdown reports in roughly the same shape. This helper extracts findings
#' by looking for severity tags (CRITICAL/HIGH/MEDIUM/LOW/SUGGESTION) and
#' associated context. Best-effort parser — the canonical contract is that
#' each reviewer numbers / labels findings clearly enough for the parser to
#' pick out (severity, rule_id, summary).
#'
#' @param path path to findings markdown file
#' @return list of findings, each a named list with severity / rule_id /
#'   summary / file (optional) / line (optional) / source (which reviewer)
parse_findings_markdown <- function(path) {
  if (!file.exists(path)) return(list())
  lines <- readLines(path, warn = FALSE)
  findings <- list()
  source_name <- tools::file_path_sans_ext(basename(path))
  source_name <- sub("_findings$", "", source_name)

  # Pattern 1: explicit severity tag at line start: "**CRITICAL**" / "[CRITICAL]" / "CRITICAL:" / "## Finding ... HIGH"
  sev_pattern <- "(CRITICAL|HIGH|MEDIUM|LOW|SUGGESTION|WARNING|INFO)"

  for (i in seq_along(lines)) {
    ln <- lines[i]
    m <- regmatches(ln, regexpr(sev_pattern, ln, ignore.case = TRUE))
    if (length(m) > 0L) {
      severity <- .normalize_severity(m)
      # WARNING is treated as HIGH severity (codex uses WARNING); INFO -> SUGGESTION
      if (severity == "WARNING") severity <- "HIGH"
      if (severity == "INFO") severity <- "SUGGESTION"

      # Try to extract rule_id (looks like MP123 / DM_R045 / SO_R038 / SEC_R / OWASP-Axx)
      rule_match <- regmatches(ln, regexpr(
        "(MP[0-9]{2,4}|DM_R[0-9]{3}|SO_R[0-9]{3}|DEV_R[0-9]{3}|SEC_R[0-9]{3}|UI_R[0-9]{3}|TD_R[0-9]{3}|IC_R[0-9]{3}|UX_R[0-9]{3}|DP_R[0-9]{3}|OWASP-[A-Z0-9]+|CWE-[0-9]+)",
        ln))
      rule_id <- if (length(rule_match) > 0L) rule_match else ""

      # Summary: take this line minus severity marker + leading symbols, trimmed
      summary <- trimws(gsub("[*\\[\\]:#-]+", " ", ln))
      summary <- gsub(sev_pattern, "", summary, ignore.case = TRUE)
      summary <- trimws(gsub("\\s+", " ", summary))
      if (nchar(summary) == 0L) summary <- ""

      findings[[length(findings) + 1L]] <- list(
        severity = severity,
        rule_id  = rule_id,
        summary  = substr(summary, 1L, 200L),
        file     = "",
        line     = NA_integer_,
        source   = source_name
      )
    }
  }
  findings
}

#' Classify an iteration's outcome per the convergence protocol.
#'
#' Order of checks (first match wins):
#'   1. INSTABILITY  if findings_count > prev_findings_count (regression)
#'   2. PLATEAUED    if findings_hash == prev_findings_hash AND have unresolved CRITICAL/HIGH
#'   3. CONVERGED    if 0 CRITICAL + 0 HIGH AND has_resolutions for remaining
#'   4. DIMINISHING  if only SUGGESTION-level findings AND prev had nothing higher than NONE
#'   5. CONTINUE     otherwise (loop continues)
#'
#' @param iteration_n integer iteration number (>= 1)
#' @param findings list of finding records (parsed via parse_findings_markdown)
#' @param findings_hash sha256 hex string of current findings
#' @param findings_count integer count of findings this iteration
#' @param prev_findings_hash NULL on iteration 1, else previous iteration's hash
#' @param prev_findings_count NULL on iteration 1, else previous iteration's count
#' @param prev_max_severity character (default NULL); used by DIMINISHING check
#' @param has_resolutions logical; TRUE if bridge yaml has findings_resolutions
#'   block covering all remaining MEDIUM/LOW findings
classify_iteration_outcome <- function(iteration_n,
                                        findings,
                                        findings_hash,
                                        findings_count,
                                        prev_findings_hash = NULL,
                                        prev_findings_count = NULL,
                                        prev_max_severity = NULL,
                                        has_resolutions = FALSE) {
  # Normalize inputs
  if (is.null(findings)) findings <- list()
  has_critical <- any(vapply(findings,
                              function(f) .normalize_severity(f$severity) == "CRITICAL",
                              logical(1)))
  has_high     <- any(vapply(findings,
                              function(f) .normalize_severity(f$severity) == "HIGH",
                              logical(1)))
  max_rank <- if (length(findings) == 0L) 0L
              else max(vapply(findings,
                              function(f) .severity_rank(f$severity),
                              integer(1)))

  # Check order: DIMINISHING -> CONVERGED -> INSTABILITY -> PLATEAUED -> CONTINUE
  # DIMINISHING is more specific than CONVERGED (current iteration adds only
  # SUGGESTIONs vs already-clean prev). Both terminate the loop with ship-ready,
  # but the verdict line in the review log differs (DIMINISHING vs CONVERGED at iteration N).

  # Check 1: DIMINISHING — current iteration has only SUGGESTION-level findings
  # AND previous iteration was already clean (no CRITICAL/HIGH/MEDIUM)
  if (!has_critical && !has_high &&
      max_rank <= 1L &&  # only SUGGESTION or NONE this iteration
      !is.null(prev_max_severity) &&
      .severity_rank(prev_max_severity) <= 1L &&  # prev was also clean
      has_resolutions) {
    return(list(verdict = "DIMINISHING",
                reason = sprintf("only SUGGESTION-level findings at iteration %d; prev_max_severity=%s",
                                  iteration_n, .normalize_severity(prev_max_severity))))
  }

  # Check 2: CONVERGED — clean slate at CRITICAL/HIGH + resolutions for remainder
  if (!has_critical && !has_high && has_resolutions) {
    return(list(verdict = "CONVERGED",
                reason = sprintf("0 CRITICAL + 0 HIGH at iteration %d; %d remaining findings have resolutions",
                                  iteration_n, findings_count)))
  }

  # Check 3: INSTABILITY — count grew AND new CRITICAL or HIGH appeared
  # (count growing alone is fine if the new findings are SUGGESTION-level refinements;
  # only flag instability when severity quality regresses)
  if (!is.null(prev_findings_count) &&
      findings_count > prev_findings_count &&
      (has_critical || has_high)) {
    return(list(verdict = "INSTABILITY",
                reason = sprintf("findings_count %d > prev %d with new CRITICAL/HIGH (codegen regression)",
                                  findings_count, prev_findings_count)))
  }

  # Check 4: PLATEAUED — same findings two iterations in a row, with unresolved blockers
  if (!is.null(prev_findings_hash) &&
      identical(findings_hash, prev_findings_hash) &&
      (has_critical || has_high)) {
    return(list(verdict = "PLATEAUED",
                reason = sprintf("findings_hash unchanged across iterations %d-%d with %d unresolved CRITICAL/HIGH",
                                  iteration_n - 1L, iteration_n,
                                  sum(has_critical, has_high))))
  }

  # Default: CONTINUE — codegen needs to address remaining findings
  list(verdict = "CONTINUE",
       reason = sprintf("iteration %d has %d findings (CRITICAL=%s, HIGH=%s); regenerate",
                         iteration_n, findings_count, has_critical, has_high))
}

#' Append an iteration entry to the review log markdown file.
#'
#' @param review_log_path path to {source}.bridge.review.md
#' @param iteration_n integer
#' @param reviewers character vector of reviewer model identifiers
#' @param findings list of finding records
#' @param findings_hash sha256 string
#' @param codegen_response_summary character (NULL on iteration that won't loop again)
#' @param resolved_count integer (count of findings resolved compared to previous)
append_iteration_log <- function(review_log_path,
                                 iteration_n,
                                 reviewers,
                                 findings,
                                 findings_hash,
                                 codegen_response_summary = NULL,
                                 resolved_count = NA_integer_) {
  if (!dir.exists(dirname(review_log_path))) {
    dir.create(dirname(review_log_path), recursive = TRUE, showWarnings = FALSE)
  }
  ts <- format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ")

  # Severity tally
  sev_tally <- vapply(c("CRITICAL", "HIGH", "MEDIUM", "LOW", "SUGGESTION"),
                      function(sev) {
                        sum(vapply(findings,
                                   function(f) .normalize_severity(f$severity) == sev,
                                   logical(1)))
                      }, integer(1))

  hdr <- sprintf("## Iteration %d - %s\n", iteration_n, ts)
  reviewers_line <- sprintf("**Reviewers**: %s\n",
                            paste(reviewers, collapse = ", "))
  count_line <- sprintf("**Findings**: %d (%d CRITICAL / %d HIGH / %d MEDIUM / %d LOW / %d SUGGESTION)\n",
                        length(findings), sev_tally[1], sev_tally[2],
                        sev_tally[3], sev_tally[4], sev_tally[5])
  hash_line <- sprintf("**Findings hash**: %s\n", findings_hash)

  # Findings table
  if (length(findings) > 0L) {
    table_header <- "| ID  | Severity   | Source              | Rule       | Summary                                |\n|-----|------------|---------------------|------------|----------------------------------------|"
    table_rows <- vapply(seq_along(findings), function(i) {
      f <- findings[[i]]
      sprintf("| %3d | %-10s | %-19s | %-10s | %-38s |",
              i,
              substr(.normalize_severity(f$severity), 1L, 10L),
              substr(f$source %||% "", 1L, 19L),
              substr(f$rule_id %||% "", 1L, 10L),
              substr(f$summary %||% "", 1L, 38L))
    }, character(1))
    table_block <- paste(c(table_header, table_rows), collapse = "\n")
  } else {
    table_block <- "_(no findings this iteration)_"
  }

  codegen_block <- if (!is.null(codegen_response_summary)) {
    sprintf("\n\n**Codegen response**: %s\n", codegen_response_summary)
  } else ""

  resolved_line <- if (!is.na(resolved_count)) {
    sprintf("\n\n**Result**: %d findings resolved vs previous iteration\n", resolved_count)
  } else ""

  entry <- paste0(
    "\n---\n\n",
    hdr,
    "\n", reviewers_line,
    "\n", count_line,
    "\n", hash_line,
    "\n", table_block,
    codegen_block,
    resolved_line
  )

  cat(entry, file = review_log_path, append = file.exists(review_log_path))
  invisible(NULL)
}

# small null-coalescing operator for safety
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

#' High-level wrapper invoked from /glue-bridge SKILL Step 6c-6d.
#'
#' Reads each reviewer's findings file, parses, computes hash, classifies
#' the iteration, and appends the log entry. Does NOT itself spawn the
#' reviewer agents — that is the parent agent's responsibility (skill).
#'
#' @param bridge_path path to .bridge.yaml under review
#' @param source_csv_path path to prerawdata source CSV (informational)
#' @param schema_yaml_paths named character vector with $canonical and $extension paths
#' @param review_log_path path to {source}.bridge.review.md
#' @param iteration_n integer iteration number (>= 1)
#' @param findings_files named character vector with paths to each reviewer's
#'   findings markdown: $codex / $correctness / $security / $devils_advocate
#' @param prev_state list with $findings_hash, $findings_count, $max_severity
#'   (NULL on iteration 1)
#' @param has_resolutions logical
#' @return list with $verdict, $findings_hash, $findings_count, $findings,
#'   $log_path
run_ensemble_review <- function(bridge_path,
                                 source_csv_path,
                                 schema_yaml_paths,
                                 review_log_path,
                                 iteration_n,
                                 findings_files,
                                 prev_state = NULL,
                                 has_resolutions = FALSE) {
  .load_hash_helper()  # exposes compute_findings_hash() via local source
  # Re-source into our scope explicitly
  source(file.path(.script_dir(), "findings_hash.R"), local = TRUE)

  # Parse findings from each reviewer
  reviewer_names <- names(findings_files)
  all_findings <- list()
  for (nm in reviewer_names) {
    path <- findings_files[[nm]]
    parsed <- parse_findings_markdown(path)
    all_findings <- c(all_findings, parsed)
  }

  # Compute hash + count
  findings_hash <- compute_findings_hash(all_findings)
  findings_count <- length(all_findings)
  max_sev <- if (findings_count == 0L) "NONE"
             else {
               ranks <- vapply(all_findings,
                               function(f) .severity_rank(f$severity),
                               integer(1))
               sevs <- c(CRITICAL = 5L, HIGH = 4L, MEDIUM = 3L,
                         LOW = 2L, SUGGESTION = 1L, NONE = 0L)
               names(sevs)[match(max(ranks), sevs)]
             }

  # Classify outcome
  outcome <- classify_iteration_outcome(
    iteration_n = iteration_n,
    findings = all_findings,
    findings_hash = findings_hash,
    findings_count = findings_count,
    prev_findings_hash = prev_state$findings_hash,
    prev_findings_count = prev_state$findings_count,
    prev_max_severity = prev_state$max_severity,
    has_resolutions = has_resolutions
  )

  # Append log entry
  append_iteration_log(
    review_log_path = review_log_path,
    iteration_n = iteration_n,
    reviewers = reviewer_names,
    findings = all_findings,
    findings_hash = findings_hash,
    codegen_response_summary = NULL,
    resolved_count = NA_integer_
  )

  list(
    verdict = outcome$verdict,
    reason = outcome$reason,
    findings_hash = findings_hash,
    findings_count = findings_count,
    max_severity = max_sev,
    findings = all_findings,
    log_path = review_log_path
  )
}
