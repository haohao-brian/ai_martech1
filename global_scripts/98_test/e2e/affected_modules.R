#####
# affected_modules.R - MP165 Tier 3 CI selective: diff-driven module
# selection
#
# Issue #599 / spectra change dashboard-presence-verification
#
# Reads `git diff --name-only <base>..<head>` and maps changed paths to
# dashboard module identifiers, returning the set of modules whose
# contracts CI should evaluate. Shared utilities consumed by all
# modules expand the affected set to the full module list.
#
# Used by .github/workflows/dashboard-contracts.yml (task 8.2).
#####

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Module identifiers. Match the "modules" keys in per-company contract YAMLs.
.MP165_ALL_MODULES <- c(
  "brandedge",
  "tagpilot",
  "vitalsigns",
  "dashboard_overview"
)

# Path-prefix map: changed path -> module identifier
# Keys are character regex patterns matching component or contract paths.
# When a path matches no module-specific pattern but matches the shared-
# utility list below, the full module set is returned.
.MP165_MODULE_PATTERNS <- list(
  brandedge          = c("position/", "10_rshinyapp_components/position/",
                          "98_test/e2e/contracts/.*\\.yaml$",
                          "98_test/e2e/test-brandedge\\.R"),
  tagpilot           = c("tagpilot/", "10_rshinyapp_components/tagpilot/",
                          "98_test/e2e/test-tagpilot\\.R"),
  vitalsigns         = c("vitalsigns/", "10_rshinyapp_components/vitalsigns/",
                          "98_test/e2e/test-vitalsigns\\.R"),
  dashboard_overview = c("dashboardOverview/",
                          "10_rshinyapp_components/dashboardOverview/")
)

# Shared utilities consumed by all dashboard modules. Touching any of
# these expands affected set to all modules (selectivity by reverse-
# dependency, not by file alone).
.MP165_SHARED_UTILITIES <- c(
  "04_utils/fn_translation\\.R",
  "04_utils/fn_debug_mode\\.R",
  "04_utils/fn_check_db_locks\\.R",
  "11_rshinyapp_utils/translation/",
  "30_global_data/parameters/scd_type2/ui_terminology\\.csv",
  "98_test/e2e/contracts/contracts\\.R",
  "98_test/e2e/setup\\.R",
  "98_test/e2e/helpers/",
  "00_principles/.*\\.qmd",
  "00_principles/.*\\.yaml",
  "23_deployment/dashboard_presence_gate\\.R"
)


#' Map changed file paths to MP165 dashboard modules
#'
#' @param paths character vector of changed file paths (typically from
#'   `git diff --name-only`)
#' @param all_modules optional override of the full module list (defaults
#'   to .MP165_ALL_MODULES)
#' @return character vector of affected module identifiers, or all
#'   modules if a shared utility was touched
affected_modules_from_paths <- function(paths,
                                        all_modules = .MP165_ALL_MODULES) {
  if (is.null(paths) || length(paths) == 0) return(character(0))

  # Shared utility -> full module set
  any_shared <- any(vapply(paths, function(p) {
    any(vapply(.MP165_SHARED_UTILITIES,
               function(pat) grepl(pat, p, perl = TRUE),
               logical(1)))
  }, logical(1)))
  if (any_shared) return(all_modules)

  # Module-specific patterns
  affected <- character(0)
  for (mod in names(.MP165_MODULE_PATTERNS)) {
    patterns <- .MP165_MODULE_PATTERNS[[mod]]
    if (any(vapply(paths, function(p) {
      any(vapply(patterns, function(pat) grepl(pat, p, perl = TRUE), logical(1)))
    }, logical(1)))) {
      affected <- c(affected, mod)
    }
  }
  unique(affected)
}


#' Read git diff and return affected modules
#'
#' Convenience wrapper: invokes git in the current working directory.
#' Errors propagate (CI consumer is expected to fail-loud when git fails).
affected_modules_from_git_diff <- function(base = "origin/main", head = "HEAD") {
  # Use system2 with explicit args (no shell) — safe from injection
  args <- c("diff", "--name-only", paste0(base, "..", head))
  out <- system2("git", args, stdout = TRUE, stderr = TRUE)
  paths <- out[nzchar(out)]
  affected_modules_from_paths(paths)
}


# CLI entry: print affected modules to stdout, one per line.
# Usage: Rscript affected_modules.R [base] [head]
if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  base <- if (length(args) >= 1) args[[1]] else "origin/main"
  head <- if (length(args) >= 2) args[[2]] else "HEAD"
  affected <- affected_modules_from_git_diff(base, head)
  if (length(affected) == 0) {
    cat("(no affected modules)\n", file = stderr())
  } else {
    cat(paste(affected, collapse = "\n"), "\n", sep = "")
  }
}
