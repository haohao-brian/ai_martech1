#!/usr/bin/env Rscript
#
# Session-Start Toolchain Readiness CLI (DEV_R057)
#
# Thin wrapper that sources the canonical helper and runs the readiness
# check with stop_on_missing_core = TRUE. Verifies R version + core +
# optional package state.
#
# Usage from a project root:
#   Rscript shared/global_scripts/98_test/check_packages.R
#
# Exit codes:
#   0 — R version OK + all core packages installed
#       (warnings emitted for missing optional packages)
#   non-zero — R too old OR core package missing
#
# The canonical core / optional list lives in:
#   shared/global_scripts/04_utils/fn_check_session_packages.R
# This wrapper SHALL NOT duplicate the lists.

# Resolve helper path relative to this script's directory so the wrapper
# works regardless of caller's working directory.
.this_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg) == 1L && nzchar(file_arg)) {
    dirname(normalizePath(file_arg))
  } else if (requireNamespace("here", quietly = TRUE)) {
    file.path(here::here(), "shared", "global_scripts", "98_test")
  } else {
    "."
  }
}, error = function(e) ".")

source(file.path(.this_dir, "..", "04_utils", "fn_check_session_packages.R"))

# Run the canonical check. stop_on_missing_core = TRUE means missing
# core packages or insufficient R version will cause stop() with an
# actionable error (Rscript exits non-zero); otherwise this prints
# nothing extra and exits 0.
check_session_packages(stop_on_missing_core = TRUE)

cat("[OK] R", paste(R.version$major, R.version$minor, sep = "."),
    "+ core packages ready (DEV_R057)\n")
