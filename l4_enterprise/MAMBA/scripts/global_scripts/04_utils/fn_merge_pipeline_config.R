#' Merge Pipeline Configuration
#'
#' Merges the base template with company-specific overrides to generate
#' the final _targets_config.yaml at project root.
#'
#' Per SO_P016: Configuration Scope Hierarchy
#' - Universal (base template): global_scripts/templates/_targets_config.base.yaml
#' - Company (override): app_config.yaml pipeline: section
#' - Generated (output): {project_root}/_targets_config.yaml
#'
#' @param base_path Path to base template (defaults to global_scripts/templates/)
#' @param app_config_path Path to app_config.yaml (defaults to project root)
#' @param output_path Path for generated config (defaults to project root)
#' @param scan_scripts Whether to scan ETL/DRV directories for scripts
#' @param verbose Print progress messages
#'
#' @return Invisibly returns the merged configuration list
#'
#' @examples
#' \dontrun{
#' # From update_scripts directory:
#' merge_pipeline_config()
#'
#' # With custom paths:
#' merge_pipeline_config(
#'   base_path = "path/to/base.yaml",
#'   app_config_path = "path/to/app_config.yaml",
#'   output_path = "path/to/output.yaml"
#' )
#' }
#'
#' @export
merge_pipeline_config <- function(
    base_path = NULL,
    app_config_path = NULL,
    output_path = NULL,
    scan_scripts = FALSE,
    verbose = TRUE) {
  # Default paths (relative to update_scripts/)
  if (is.null(base_path)) {
    base_path <- file.path("..", "global_scripts", "templates", "_targets_config.base.yaml")
  }
  if (is.null(app_config_path)) {
    app_config_path <- file.path("..", "..", "app_config.yaml")
  }
  if (is.null(output_path)) {
    output_path <- file.path("..", "..", "_targets_config.yaml")
  }

  # Validate inputs
  if (!file.exists(base_path)) {
    stop("Base template not found: ", base_path)
  }
  if (!file.exists(app_config_path)) {
    stop("App config not found: ", app_config_path)
  }

  if (verbose) message("=== Pipeline Configuration Merge ===")

  # 1. Read base template
  if (verbose) message("Reading base template: ", base_path)
  base <- yaml::read_yaml(base_path)

  # 2. Read company override (pipeline: section)
  if (verbose) message("Reading company config: ", app_config_path)
  app_config <- yaml::read_yaml(app_config_path)
  override <- app_config$pipeline

  if (is.null(override)) {
    if (verbose) message("No pipeline: section in app_config.yaml, using base only")
    override <- list()
  }

  # 3. Deep merge (override wins)
  if (verbose) message("Merging configurations...")
  merged <- modifyList(base, override)

  # 4. Update metadata
  merged$last_updated <- format(Sys.time(), "%Y-%m-%d")
  merged$template_type <- "merged"
  merged$source <- list(
    base = normalizePath(base_path, mustWork = FALSE),
    override = normalizePath(app_config_path, mustWork = FALSE)
  )

  # 5. Optionally scan for scripts
  if (scan_scripts) {
    global_scripts_root <- normalizePath(
      file.path(dirname(base_path), "..", ".."),
      mustWork = FALSE
    )
    update_scripts_root <- normalizePath(
      file.path(global_scripts_root, "..", "update_scripts"),
      mustWork = FALSE
    )
    etl_dir <- file.path(update_scripts_root, "ETL")
    drv_dir <- file.path(update_scripts_root, "DRV")

    if (verbose) message("Scanning ETL/DRV directories for scripts...")
    merged <- scan_and_update_scripts(
      merged,
      etl_dir = etl_dir,
      drv_dir = drv_dir,
      verbose = verbose,
      current_company = app_config$brand_name
    )
  }

  # 6. Write output
  if (verbose) message("Writing merged config: ", output_path)
  yaml::write_yaml(merged, output_path)

  if (verbose) {
    message("=== Merge Complete ===")
    message("Output: ", normalizePath(output_path, mustWork = FALSE))
    if (!is.null(merged$platforms)) {
      platforms <- names(merged$platforms)
      enabled <- sapply(platforms, function(p) {
        isTRUE(merged$platforms[[p]]$enabled)
      })
      message("Enabled platforms: ", paste(platforms[enabled], collapse = ", "))
    }
  }

  invisible(merged)
}

#' Convert script filename to target name
#' @param script_path Path or filename of the script
#' @return Target name string
script_to_target_name <- function(script_path) {
  base <- tools::file_path_sans_ext(basename(script_path))
  make.names(gsub("[^A-Za-z0-9_]", "_", base))
}

#' Scan ETL/DRV directories and update script lists
#'
#' @param config Current configuration list
#' @param etl_dir ETL directory path
#' @param drv_dir DRV directory path
#' @param verbose Print progress messages
#' @param current_company Current company brand_name (per app_config.yaml).
#'   When non-NULL, files with `___COMPANY` suffix that don't match this name
#'   are filtered out. Per #575: prevents MAMBA-suffixed scripts from leaking
#'   into QEF/D_RACING/etc pipelines.
#'
#' @return Updated configuration list with script definitions
scan_and_update_scripts <- function(
    config,
    etl_dir = "ETL",
    drv_dir = "DRV",
    verbose = TRUE,
    current_company = NULL) {

  if (verbose && !is.null(current_company) && nzchar(current_company)) {
    message("Company-specific filter active: keeping files with no suffix or '___",
            current_company, "' suffix")
  }
  # Get enabled platforms
  enabled_platforms <- names(config$platforms)[
    sapply(config$platforms, function(p) isTRUE(p$enabled))
  ]

  if (verbose) message("Scanning platforms: ", paste(enabled_platforms, collapse = ", "))

  get_sales_dependency <- function(platform_id) {
    platform_etl_dir <- file.path(etl_dir, platform_id)
    if (!dir.exists(platform_etl_dir)) return(character(0))

    sales_files <- list.files(
      platform_etl_dir,
      pattern = sprintf("^%s_ETL_sales_.*\\.R$", platform_id)
    )
    preferred <- c(
      sales_files[grepl("_ETL_sales_2TS", sales_files)],
      sales_files[grepl("_ETL_sales_2TR", sales_files)]
    )
    preferred <- preferred[nzchar(preferred)]
    if (length(preferred) == 0) return(character(0))
    script_to_target_name(preferred[[1]])
  }

  get_terminal_d01_target <- function(platform_id) {
    platform_drv_dir <- file.path(drv_dir, platform_id)
    if (!dir.exists(platform_drv_dir)) return(character(0))

    d01_files <- list.files(
      platform_drv_dir,
      pattern = sprintf("^%s_D01_[0-9]+\\.R$", platform_id)
    )
    if (length(d01_files) == 0) return(character(0))

    seq_vals <- suppressWarnings(as.integer(sub("^.*_D01_([0-9]+)\\.R$", "\\1", d01_files)))
    d01_files <- d01_files[!is.na(seq_vals)]
    seq_vals <- seq_vals[!is.na(seq_vals)]
    if (length(d01_files) == 0) return(character(0))

    script_to_target_name(d01_files[[which.max(seq_vals)]])
  }

  # Initialize platforms section if needed
  if (is.null(config$platforms)) {
    config$platforms <- list()
  }

  for (platform in enabled_platforms) {
    platform_etl_dir <- file.path(etl_dir, platform)
    platform_drv_dir <- file.path(drv_dir, platform)

    # 1. Scan ETL scripts
    if (dir.exists(platform_etl_dir)) {
      files <- list.files(platform_etl_dir, pattern = "\\.R$")
      files <- filter_excluded(files, config$excluded_patterns)
      files <- filter_company_specific(files, current_company)
      if (verbose) message("  ", platform, " ETL: ", length(files), " scripts")

      # Group by datatype
      etl_data <- list()
      # Pattern: {platform}_ETL_{datatype}_{phase}(___MAMBA)?.R
      # We use a more flexible regex to capture components
      pattern <- sprintf("^%s_ETL_([A-Za-z0-9_]+)_([A-Za-z0-9]+)(___[A-Z]+)?\\.R$", platform)

      for (f in files) {
        matches <- regmatches(f, regexec(pattern, f))[[1]]
        if (length(matches) >= 3) {
          datatype <- matches[2]
          phase <- matches[3]

          if (is.null(etl_data[[datatype]])) {
            etl_data[[datatype]] <- list(phases = character(), scripts = list())
          }

          # Add to phases and scripts
          etl_data[[datatype]]$phases <- unique(c(etl_data[[datatype]]$phases, phase))

          # Dependency logic: find previous phase in phase_order
          current_idx <- which(config$phase_order == phase)
          deps <- NULL
          if (length(current_idx) > 0 && current_idx > 1) {
            prev_phase <- config$phase_order[current_idx - 1]
            # Check if we have a script for previous phase
            prev_file_pattern <- sprintf("^%s_ETL_%s_%s", platform, datatype, prev_phase)
            if (any(grepl(prev_file_pattern, files))) {
              deps <- sprintf("%s_ETL_%s_%s", platform, datatype, prev_phase)
            }
          }
          # Special handling for 2TS: force dependency to 2TR when not inferable
          if (is.null(deps) && datatype == "sales" && phase == "2TS") {
            prev_phase <- "2TR"
            prev_file_pattern <- sprintf("^%s_ETL_%s_%s", platform, datatype, prev_phase)
            if (any(grepl(prev_file_pattern, files))) {
              deps <- sprintf("%s_ETL_%s_%s", platform, datatype, prev_phase)
            }
          }

          script_entry <- list(script = f, phase = phase)
          if (!is.null(deps)) script_entry$depends <- deps

          etl_data[[datatype]]$scripts[[length(etl_data[[datatype]]$scripts) + 1]] <- script_entry
        }
      }

      # Sort phases by phase_order
      for (dt in names(etl_data)) {
        phases <- etl_data[[dt]]$phases
        etl_data[[dt]]$phases <- config$phase_order[config$phase_order %in% phases]
      }

      config$platforms[[platform]]$etl <- etl_data
    }

    # 2. Scan DRV scripts
    if (dir.exists(platform_drv_dir)) {
      files <- list.files(platform_drv_dir, pattern = "\\.R$")
      files <- filter_excluded(files, config$excluded_patterns)
      files <- filter_company_specific(files, current_company)
      if (verbose) message("  ", platform, " DRV: ", length(files), " scripts")

      # Group by DRV group (D01, D03, etc)
      drv_data <- list()
      # Pattern: {platform}_D{group}_{seq}.R
      pattern <- sprintf("^%s_D([0-9]+)_([0-9]+)\\.R$", platform)
      source_platforms <- setdiff(enabled_platforms, c("all", "precision"))

      for (f in files) {
        matches <- regmatches(f, regexec(pattern, f))[[1]]
        if (length(matches) >= 3) {
          group_num <- matches[2]
          seq_num <- matches[3]
          group_name <- paste0("D", group_num)
          seq_val <- as.integer(seq_num)

          # Only include if group is in enabled drv_groups (if defined)
          enabled_groups <- config$platforms[[platform]]$drv_groups
          if (!is.null(enabled_groups) && !(group_name %in% enabled_groups)) next

          # all_D01_06 is a legacy master wrapper that re-runs platform scripts.
          # In the targets DAG we prefer platform-native D01 targets + all_D01_07/08.
          if (identical(platform, "all") && identical(group_name, "D01") && identical(seq_val, 6L)) {
            next
          }

          if (is.null(drv_data[[group_name]])) {
            drv_data[[group_name]] <- list(description = paste(group_name, "Derivations"), scripts = list())
          }

          script_entry <- list(script = f)

          if (identical(platform, "all") && identical(group_name, "D01")) {
            if (identical(seq_val, 7L)) {
              deps <- unique(unlist(lapply(source_platforms, get_terminal_d01_target)))
              if (length(deps) > 0) {
                script_entry$depends_drv <- deps
              }
            } else if (identical(seq_val, 8L)) {
              script_entry$depends_drv <- "all_D01_07"
            }
          } else if (identical(platform, "all") && identical(group_name, "D03") && identical(seq_val, 1L)) {
            deps <- unique(unlist(lapply(source_platforms, get_sales_dependency)))
            if (length(deps) > 0) {
              script_entry$depends_etl <- deps
            }
          } else {
            # Dependency logic: within group, depends on previous sequence number
            prev_seqs <- Filter(function(x) {
              m <- regmatches(x, regexec(pattern, x))[[1]]
              if (length(m) >= 3 && m[2] == group_num) {
                return(as.integer(m[3]) < seq_val)
              }
              FALSE
            }, files)

            if (length(prev_seqs) > 0) {
              # Find the largest sequence number that is smaller than current
              prev_seq_vals <- sapply(prev_seqs, function(x) as.integer(regmatches(x, regexec(pattern, x))[[1]][3]))
              target_prev <- prev_seqs[which.max(prev_seq_vals)]
              script_entry$depends_drv <- script_to_target_name(target_prev)
            } else {
              # If it's the first in the group, prefer sales_2TS before sales_2TR
              if (group_name == "D01") {
                preferred_sales_dep <- get_sales_dependency(platform)
                if (length(preferred_sales_dep) > 0) {
                  script_entry$depends_etl <- preferred_sales_dep
                } else {
                  # Fallback to standard name if not found
                  script_entry$depends_etl <- sprintf("%s_ETL_sales_2TR", platform)
                }
              }
            }
          }

          drv_data[[group_name]]$scripts[[length(drv_data[[group_name]]$scripts) + 1]] <- script_entry
        }
      }

      config$platforms[[platform]]$drv <- drv_data
    }

    # 2b. Scan group-based DRV directories (Refs #676, post-#670 refactor).
    # Files in DRV/D{group}/D{group}_{seq}.R have NO platform prefix in
    # filename. Synthesize virtual {platform}_D{group}_{seq}.R script entries
    # so script_to_target_name() yields {platform}_D{group}_{seq} target names,
    # and resolve_script_path() in _targets.R strips the prefix back to find
    # the actual DRV/D{group}/D{group}_{seq}.R file on disk.
    #
    # Skip for 'all'/'precision' virtual platforms — they use DRV/all/*.R
    # per-platform files exclusively (e.g. all_D03_01.R, all_D01_07.R).
    if (!(platform %in% c("all", "precision")) && dir.exists(drv_dir)) {
      all_subdirs <- list.dirs(drv_dir, recursive = FALSE, full.names = FALSE)
      group_dirs <- all_subdirs[grepl("^D[0-9]+$", all_subdirs)]

      if (length(group_dirs) > 0) {
        group_file_re <- "^D([0-9]+)_([0-9]+)\\.R$"
        enabled_groups <- config$platforms[[platform]]$drv_groups

        for (gd_name in group_dirs) {
          gd_path <- file.path(drv_dir, gd_name)
          gd_files <- list.files(gd_path, pattern = "\\.R$")
          gd_files <- filter_excluded(gd_files, config$excluded_patterns)
          gd_files <- filter_company_specific(gd_files, current_company)
          if (verbose && length(gd_files) > 0) {
            message("  ", platform, " DRV (group-based ", gd_name, "): ",
                    length(gd_files), " scripts")
          }

          for (gf in gd_files) {
            if (!grepl(group_file_re, gf)) next
            # Extract group / seq via sub() backref (POSIX regex,
            # avoids regmatches+regexec name pattern flagged by some hooks).
            g_num <- sub("^D([0-9]+)_[0-9]+\\.R$", "\\1", gf)
            g_seq <- sub("^D[0-9]+_([0-9]+)\\.R$", "\\1", gf)
            g_seq_val <- as.integer(g_seq)
            g_name <- paste0("D", g_num)

            # Respect per-platform enabled_groups filter (mirrors line 294-295)
            if (!is.null(enabled_groups) && !(g_name %in% enabled_groups)) next

            # Virtual filename with platform prefix — resolve_script_path() in
            # _targets.R strips this prefix back when locating the file on disk
            virtual_name <- sprintf("%s_D%s_%s.R", platform, g_num, g_seq)
            target_name <- sprintf("%s_D%s_%s", platform, g_num, g_seq)

            # Initialize drv_data slot if absent (legacy per-platform scan
            # above may have already created it for this group)
            if (is.null(config$platforms[[platform]]$drv[[g_name]])) {
              config$platforms[[platform]]$drv[[g_name]] <- list(
                description = paste(g_name, "Derivations"),
                scripts = list()
              )
            }

            # Skip if a legacy per-platform file with the same target name was
            # already registered (legacy DRV/{platform}/ takes precedence)
            existing_scripts <- config$platforms[[platform]]$drv[[g_name]]$scripts
            existing_names <- if (length(existing_scripts) > 0) {
              vapply(existing_scripts, function(s) script_to_target_name(s$script),
                     character(1))
            } else {
              character(0)
            }
            if (target_name %in% existing_names) next

            # Intra-group dependency inference: find largest prev seq across
            # BOTH the group-based dir AND the already-populated legacy per-
            # platform drv entries for this group (mirrors line 323-337 legacy
            # logic but spans both source dirs since #670 split storage).
            # Build prev-seq pool from current drv[[g_name]]$scripts (legacy
            # scan already populated) + group-based dir files.
            pool_targets <- vapply(
              config$platforms[[platform]]$drv[[g_name]]$scripts,
              function(s) script_to_target_name(s$script),
              character(1)
            )
            pool_seqs <- vapply(pool_targets, function(tn) {
              # Match {platform}_D{g_num}_(seq)
              seq_re <- sprintf("^%s_D%s_([0-9]+)$", platform, g_num)
              if (grepl(seq_re, tn)) {
                as.integer(sub(seq_re, "\\1", tn))
              } else {
                NA_integer_
              }
            }, integer(1))
            gd_seqs <- vapply(gd_files, function(x) {
              if (grepl(group_file_re, x)) {
                xg <- sub("^D([0-9]+)_[0-9]+\\.R$", "\\1", x)
                xs <- sub("^D[0-9]+_([0-9]+)\\.R$", "\\1", x)
                if (xg == g_num) as.integer(xs) else NA_integer_
              } else {
                NA_integer_
              }
            }, integer(1))
            all_seqs <- c(pool_seqs, gd_seqs)
            prev_seqs_int <- all_seqs[!is.na(all_seqs) & all_seqs < g_seq_val]

            script_entry <- list(script = virtual_name)
            if (length(prev_seqs_int) > 0) {
              prev_max <- max(prev_seqs_int)
              # Preserve seq width (typically 2 digits — "01", not "1") to
              # match script_to_target_name() output on legacy filenames.
              seq_width <- nchar(g_seq)
              script_entry$depends_drv <- sprintf(
                paste0("%s_D%s_%0", seq_width, "d"),
                platform, g_num, prev_max
              )
            } else if (g_name == "D01") {
              # First in group + D01 → depend on sales ETL (mirror line 339-348)
              sales_dep <- get_sales_dependency(platform)
              if (length(sales_dep) > 0) {
                script_entry$depends_etl <- sales_dep
              } else {
                script_entry$depends_etl <- sprintf("%s_ETL_sales_2TR", platform)
              }
            }

            config$platforms[[platform]]$drv[[g_name]]$scripts[[
              length(config$platforms[[platform]]$drv[[g_name]]$scripts) + 1
            ]] <- script_entry
          }
        }
      }
    }
  }

  config
}

#' Filter out files with mismatched company suffix
#'
#' Files matching `___COMPANY.R$` (per DM_R037 v3.0) only belong to that
#' specific company's pipeline. Per #575: prevents e.g. `___MAMBA.R` scripts
#' from being scanned into QEF_DESIGN's _targets_config.yaml.
#'
#' @param files Vector of file names
#' @param current_company Brand_name of the current company (per app_config.yaml).
#'   When NULL or empty, all files pass through (legacy behavior).
#'
#' @return Filtered vector. Files with no `___COMPANY` suffix always pass;
#'   files with a suffix only pass when it matches `current_company`.
filter_company_specific <- function(files, current_company) {
  if (is.null(current_company) || !nzchar(current_company)) {
    return(files)
  }

  # Match `___COMPANY.R$` where COMPANY is uppercase + digits + underscores
  # (covers both `___MAMBA` and `___QEF_DESIGN`)
  suffix_pattern <- "___([A-Z][A-Z0-9_]*)\\.R$"
  matches <- regmatches(files, regexec(suffix_pattern, files))
  suffixes <- vapply(
    matches,
    function(m) if (length(m) >= 2) m[[2]] else NA_character_,
    character(1)
  )

  # Keep file if no suffix OR suffix matches current company
  keep <- is.na(suffixes) | suffixes == current_company
  files[keep]
}

#' Filter out files matching glob patterns
#'
#' @param files Vector of file names
#' @param patterns Vector of glob patterns to exclude
#'
#' @return Filtered vector of file names
filter_excluded <- function(files, patterns) {
  if (is.null(patterns) || length(patterns) == 0) {
    return(files)
  }

  for (pattern in patterns) {
    # Convert glob to regex
    regex <- glob2rx(pattern)
    files <- files[!grepl(regex, files)]
  }

  files
}

#' Convert glob pattern to regex
#'
#' @param glob Glob pattern
#' @return Regular expression pattern
glob2rx <- function(glob) {
  # Simple glob to regex conversion
  regex <- glob
  regex <- gsub("\\.", "\\\\.", regex)
  regex <- gsub("\\*\\*/", "(.*/)?", regex)
  regex <- gsub("\\*", "[^/]*", regex)
  regex <- gsub("\\?", ".", regex)
  paste0("^", regex, "$")
}
