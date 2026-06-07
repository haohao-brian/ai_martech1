#!/usr/bin/env Rscript
#####
# drv_output_shape_gate.R - MP165 v1.3 DRV-layer Step 2 propagation gate
#
# Issue #668 / spectra change mp165-drv-output-shape-gate
#
# Verifies that DRV pipeline produced non-trivial outputs by reading
# app_data.duckdb tables via DBI and checking three contract levels:
#   L1 table-exists (mandatory) - DBI::dbExistsTable
#   L2 row-count-min (mandatory) - COUNT(*) >= l2_row_count_min
#   L3 predictor-type-distribution (optional) - GROUP BY predictor_type
#
# MP163 sentinel boundary: sentinel-covered rows ('unclassified', 'UNKNOWN',
# domain markers) count toward L2 and L3 by default. Optional
# sentinel_ratio_max emits a warning (never hard-fail) when the ratio
# exceeds the configurable threshold.
#
# Mode resolution (in priority order):
#   1. Explicit CLI flag --warn-mode or --strict-mode
#   2. Per-company yaml `strict_mode: true` (pre-sunset opt-in)
#   3. Calendar sunset 2026-06-13: pre-sunset -> warn, on/after -> strict
#
# Exit codes:
#   0  all critical contracts pass OR mode=warn (warnings reported but exit 0)
#   1  at least one critical contract failed in strict-mode
#   2  schema / parse error in contract YAML
#   3  usage / configuration error
#####

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Calendar default sunset date for warn -> strict transition
DRV_GATE_SUNSET_DATE <- as.Date("2026-06-13")

# Canonical sentinel markers per MP163 Progressive Completeness
DRV_GATE_SENTINEL_MARKERS <- c("unclassified", "UNKNOWN")


# ---------- Argument parsing ----------

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    company = NULL,
    contracts_path = NULL,
    mode = "auto",  # auto | warn | strict
    db_path = NULL
  )
  i <- 1
  while (i <= length(args)) {
    a <- args[[i]]
    switch(a,
      "--company"        = { i <- i + 1; opts$company <- args[[i]] },
      "--contracts-path" = { i <- i + 1; opts$contracts_path <- args[[i]] },
      "--db-path"        = { i <- i + 1; opts$db_path <- args[[i]] },
      "--warn-mode"      = { opts$mode <- "warn" },
      "--strict-mode"    = { opts$mode <- "strict" },
      "--help"           = { cat("See header comment for usage\n"); quit(status = 0) },
      stop("Unknown argument: ", a)
    )
    i <- i + 1
  }
  opts
}


# ---------- Contract loading ----------

locate_contracts_path <- function(company) {
  # Refs #677: anchor on MAMBA_PROJECT_ROOT when available so the pipeline-end
  # target (verify_drv_output_shape, invoked from {targets} runtime CWD) finds
  # the same yaml as `make verify-drv` (which passes --contracts-path absolute).
  # Falls back to repo-relative path for invocations from repo root (e.g.
  # standalone tests, ad-hoc Rscript calls from /Users/che/.../l4_enterprise/).
  filename <- paste0(tolower(company), "_drv.yaml")
  project_root <- Sys.getenv("MAMBA_PROJECT_ROOT", "")
  if (nzchar(project_root) && dir.exists(project_root)) {
    # Per-company project layout: scripts/global_scripts is a symlink to
    # ../../shared/global_scripts (per MP122 Penta-Track architecture).
    project_path <- file.path(project_root, "scripts", "global_scripts",
                              "98_test", "e2e", "contracts", filename)
    if (file.exists(project_path)) {
      return(normalizePath(project_path, mustWork = FALSE))
    }
  }
  # Repo-root fallback (e.g. running from l4_enterprise/ via standalone test)
  file.path("shared", "global_scripts", "98_test", "e2e", "contracts", filename)
}

load_drv_contracts <- function(path) {
  if (!file.exists(path)) return(NULL)
  yaml::read_yaml(path)
}


# ---------- Mode resolution ----------

resolve_mode <- function(opts_mode, contracts, today = Sys.Date()) {
  # Priority 1: explicit CLI mode
  if (identical(opts_mode, "warn") || identical(opts_mode, "strict")) {
    return(opts_mode)
  }

  # Priority 2: per-company opt-in (only meaningful if contracts loaded)
  if (!is.null(contracts) && isTRUE(contracts$strict_mode)) {
    return("strict")
  }

  # Priority 3: calendar sunset
  if (today >= DRV_GATE_SUNSET_DATE) "strict" else "warn"
}


# ---------- Per-level contract checks ----------

check_l1_table_exists <- function(con, table_name) {
  exists <- tryCatch(DBI::dbExistsTable(con, table_name), error = function(e) FALSE)
  list(
    level = "L1",
    pass = exists,
    table = table_name,
    message = if (exists) {
      sprintf("PASS [L1]: %s exists", table_name)
    } else {
      sprintf("FAIL [L1]: %s does not exist", table_name)
    }
  )
}

check_l2_row_count <- function(con, table_name, min_rows) {
  observed <- tryCatch(
    dplyr::tbl(con, table_name) |>
      dplyr::summarise(n = dplyr::n()) |>
      dplyr::collect() |>
      dplyr::pull(n) |>
      as.integer(),
    error = function(e) NA_integer_
  )
  pass <- !is.na(observed) && observed >= min_rows
  list(
    level = "L2",
    pass = pass,
    table = table_name,
    observed = observed,
    expected_min = min_rows,
    message = if (pass) {
      sprintf("PASS [L2]: %s has %d rows (>= %d)", table_name, observed, min_rows)
    } else {
      sprintf("FAIL [L2]: %s has %s rows, expected >= %d",
              table_name,
              if (is.na(observed)) "?" else as.character(observed),
              min_rows)
    }
  )
}

check_l3_predictor_types <- function(con, table_name, required_types, min_count_per_type = 1L) {
  # Probe schema first - if predictor_type column absent, skip
  cols <- tryCatch(DBI::dbListFields(con, table_name), error = function(e) character(0))
  if (!"predictor_type" %in% cols) {
    return(list(
      level = "L3",
      pass = TRUE,
      table = table_name,
      skipped = TRUE,
      message = sprintf("SKIP [L3]: %s has no predictor_type column", table_name)
    ))
  }

  observed_df <- tryCatch(
    dplyr::tbl(con, table_name) |>
      dplyr::group_by(predictor_type) |>
      dplyr::summarise(n = dplyr::n()) |>
      dplyr::collect(),
    error = function(e) NULL
  )

  if (is.null(observed_df)) {
    return(list(
      level = "L3",
      pass = FALSE,
      table = table_name,
      message = sprintf("FAIL [L3]: %s could not group predictor_type", table_name)
    ))
  }

  observed_map <- setNames(as.integer(observed_df$n), observed_df$predictor_type)
  missing <- character(0)
  for (req in required_types) {
    if (!(req %in% names(observed_map)) || observed_map[[req]] < min_count_per_type) {
      missing <- c(missing, req)
    }
  }
  pass <- length(missing) == 0

  observed_summary <- paste(
    sprintf("%s=%d", names(observed_map), observed_map),
    collapse = ", "
  )
  if (!nzchar(observed_summary)) observed_summary <- "(none)"

  list(
    level = "L3",
    pass = pass,
    table = table_name,
    missing = missing,
    observed = observed_map,
    message = if (pass) {
      sprintf("PASS [L3]: %s predictor_types cover [%s]",
              table_name, paste(required_types, collapse = ", "))
    } else {
      sprintf("FAIL [L3]: %s missing predictor_type(s): %s (observed: %s)",
              table_name, paste(missing, collapse = ", "), observed_summary)
    }
  )
}

check_sentinel_ratio <- function(con, table_name, sentinel_max,
                                  sentinel_markers = DRV_GATE_SENTINEL_MARKERS) {
  cols <- tryCatch(DBI::dbListFields(con, table_name), error = function(e) character(0))
  if (!"predictor_type" %in% cols) {
    return(list(level = "SENTINEL", pass = TRUE, skipped = TRUE,
                table = table_name,
                message = sprintf("SKIP [SENTINEL]: %s no predictor_type", table_name)))
  }

  agg <- tryCatch(
    dplyr::tbl(con, table_name) |>
      dplyr::summarise(
        total = dplyr::n(),
        sentinel = sum(predictor_type %in% sentinel_markers, na.rm = TRUE)
      ) |>
      dplyr::collect(),
    error = function(e) NULL
  )
  if (is.null(agg) || nrow(agg) == 0) {
    return(list(level = "SENTINEL", pass = TRUE, skipped = TRUE,
                table = table_name,
                message = "SKIP [SENTINEL]: agg failed"))
  }
  total <- as.integer(agg$total)
  sent <- as.integer(agg$sentinel)
  ratio <- if (total > 0) sent / total else 0
  exceeded <- ratio > sentinel_max
  list(
    level = "SENTINEL",
    pass = TRUE,  # sentinel check NEVER hard-fails
    soft_warn = exceeded,
    table = table_name,
    ratio = ratio,
    threshold = sentinel_max,
    message = if (exceeded) {
      sprintf("WARNING [SENTINEL]: %s sentinel ratio %.2f exceeds threshold %.2f",
              table_name, ratio, sentinel_max)
    } else {
      sprintf("PASS [SENTINEL]: %s sentinel ratio %.2f within threshold %.2f",
              table_name, ratio, sentinel_max)
    }
  )
}


# ---------- Per-contract orchestration ----------

evaluate_contract <- function(con, table_name, contract) {
  severity <- contract$severity %||% "critical"
  results <- list()

  # L1
  r1 <- check_l1_table_exists(con, table_name)
  r1$severity <- severity
  results <- c(results, list(r1))
  if (!r1$pass) {
    # Short-circuit per spec scenario: L2 and L3 skipped on L1 fail
    return(results)
  }

  # L2
  l2_min <- contract$l2_row_count_min %||% 1L
  r2 <- check_l2_row_count(con, table_name, as.integer(l2_min))
  r2$severity <- severity
  results <- c(results, list(r2))

  # L3 (optional)
  if (!is.null(contract$l3_predictor_types)) {
    required <- contract$l3_predictor_types$required %||% character(0)
    min_per <- contract$l3_predictor_types$min_count_per_type %||% 1L
    r3 <- check_l3_predictor_types(con, table_name, required, as.integer(min_per))
    r3$severity <- severity
    results <- c(results, list(r3))
  }

  # Sentinel ratio (optional, never hard-fails)
  if (!is.null(contract$sentinel_ratio_max)) {
    rs <- check_sentinel_ratio(con, table_name,
                                as.numeric(contract$sentinel_ratio_max))
    rs$severity <- "warning"  # sentinel always soft
    results <- c(results, list(rs))
  }

  results
}


# ---------- Top-level gate ----------

run_drv_output_shape_gate <- function(company,
                                       contracts_path = NULL,
                                       mode = "auto",
                                       db_path = NULL,
                                       today = Sys.Date()) {
  messages <- character(0)
  result <- list(
    company = company,
    ok = TRUE,
    mode = NULL,
    messages = NULL,
    critical_failures = 0L,
    warnings = 0L
  )

  # Locate contracts path if not supplied
  if (is.null(contracts_path)) {
    contracts_path <- locate_contracts_path(company)
  }

  contracts <- load_drv_contracts(contracts_path)

  # Resolve mode
  resolved_mode <- resolve_mode(mode, contracts, today)
  result$mode <- resolved_mode

  # Missing contracts handling per spec
  if (is.null(contracts)) {
    if (resolved_mode == "strict") {
      msg <- sprintf("ERROR: <company>_drv.yaml is required after %s (path tried: %s)",
                     DRV_GATE_SUNSET_DATE, contracts_path)
      result$ok <- FALSE
      result$critical_failures <- 1L
      result$messages <- msg
    } else {
      msg <- sprintf("WARNING: no DRV contracts declared for %s; gate skipped (path tried: %s)",
                     company, contracts_path)
      result$warnings <- 1L
      result$messages <- msg
    }
    return(result)
  }

  # Open DB
  if (is.null(db_path)) {
    stop("db_path required (or load via db_paths.yaml in CLI mode)")
  }
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)

  # Walk drv_contracts: platform -> table -> contract
  drv_contracts <- contracts$drv_contracts %||% list()
  for (platform_name in names(drv_contracts)) {
    platform_contracts <- drv_contracts[[platform_name]]
    for (table_name in names(platform_contracts)) {
      contract <- platform_contracts[[table_name]]
      per_results <- evaluate_contract(con, table_name, contract)
      for (r in per_results) {
        messages <- c(messages, r$message)
        if (!isTRUE(r$pass)) {
          if (identical(r$severity, "critical")) {
            result$critical_failures <- result$critical_failures + 1L
          } else {
            result$warnings <- result$warnings + 1L
          }
        } else if (isTRUE(r$soft_warn)) {
          result$warnings <- result$warnings + 1L
        }
      }
    }
  }

  # Determine ok status
  if (resolved_mode == "strict" && result$critical_failures > 0L) {
    result$ok <- FALSE
  } else {
    result$ok <- TRUE  # warn-mode never hard-fails
  }

  result$messages <- messages
  result
}


# ---------- CLI entry ----------

main <- function() {
  opts <- parse_args()
  if (is.null(opts$company)) stop("--company <CODE> required")
  if (is.null(opts$db_path)) {
    # Try to read from db_paths.yaml if available; otherwise error.
    stop("--db-path <path> required (db_paths.yaml integration is a follow-up)")
  }

  contracts_path <- opts$contracts_path %||% locate_contracts_path(opts$company)

  result <- run_drv_output_shape_gate(
    company = opts$company,
    contracts_path = contracts_path,
    mode = opts$mode,
    db_path = opts$db_path
  )

  cat(paste(result$messages, collapse = "\n"), "\n", sep = "")
  cat(sprintf("\nMode: %s | Critical failures: %d | Warnings: %d\n",
              result$mode, result$critical_failures, result$warnings))

  if (result$ok) quit(status = 0) else quit(status = 1)
}

# Only run main() when invoked as script (not when sourced for tests/lib)
if (sys.nframe() == 0L &&
    !interactive() &&
    !isTRUE(getOption("drv_gate.library_mode", FALSE))) {
  main()
}
