# Regression tests for dbConnectAppData fail-loud behavior (#595)
#
# Background:
# /idd-diagnose #595 originally hypothesized that DBI duckdb silently creates an
# empty db when opening a non-existent file path, leading to QEF_DESIGN's
# BrandEdge + TagPilot dashboards showing "no data" without R error in
# production. Plan tier Phase B Step 3 proposed adding fail-loud to
# dbConnect_universal.
#
# However, MP029 verify-before-acting in /idd-implement found that
# `dbConnectAppData()` (the actual function — `dbConnect_universal` is a
# legacy doc reference, not the active function) ALREADY throws stop() on
# mode="duckdb" + missing file (see fn_dbConnectAppData.R lines 91-103) and
# also throws in mode="auto" when both backends unavailable (lines 119-134).
#
# These tests:
# 1. Lock the current fail-loud contract so future refactors don't regress
#    silently
# 2. Document the explicit contract that callers can rely on (#595 audit
#    trail)
# 3. Provide RED→GREEN evidence the system already meets Phase B Step 3's
#    intent without code changes
#
# Run with:
#   Rscript -e "testthat::test_file('98_test/test_dbConnect_fail_loud.R')"

library(testthat)

# Source target under test. Resolve robustly:
# 1. Rscript: commandArgs(--file=) gives invocation path
# 2. testthat: sys.frames()[[1]]$ofile gives the file being sourced
# 3. Sourced from another script: ofile too
# Fallback: assume cwd is shared/global_scripts (run via 'cd shared && Rscript ...')
resolve_fn_path <- function() {
  # Try testthat / source frame first
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile) && nzchar(frame$ofile) && file.exists(frame$ofile)) {
      script_dir <- dirname(normalizePath(frame$ofile))
      candidate <- normalizePath(file.path(script_dir, "..", "02_db_utils", "fn_dbConnectAppData.R"),
                                 mustWork = FALSE)
      if (file.exists(candidate)) return(candidate)
    }
  }
  # Try Rscript --file=
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE)
    if (file.exists(script_path)) {
      candidate <- normalizePath(file.path(dirname(script_path), "..", "02_db_utils", "fn_dbConnectAppData.R"),
                                 mustWork = FALSE)
      if (file.exists(candidate)) return(candidate)
    }
  }
  # Fallback: cwd-relative
  for (rel in c("02_db_utils/fn_dbConnectAppData.R",
                "../02_db_utils/fn_dbConnectAppData.R")) {
    if (file.exists(rel)) return(normalizePath(rel))
  }
  stop("Cannot locate fn_dbConnectAppData.R from cwd ", getwd())
}

source(resolve_fn_path())

# Test fixture: temporary directory with controlled config
make_fixture <- function(mode = "duckdb",
                          duckdb_path = "data/app_data/app_data.duckdb",
                          tmpdir = tempfile("idd595_")) {
  dir.create(tmpdir, recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    database = list(
      mode = mode,
      duckdb = list(path = duckdb_path, read_only = TRUE)
    )
  )
  cfg_path <- file.path(tmpdir, "app_config.yaml")
  yaml::write_yaml(cfg, cfg_path)
  list(tmpdir = tmpdir, cfg_path = cfg_path)
}

# Save + clear Supabase env vars at test start so auto mode tests are deterministic.
# Restore on exit.
saved_env <- list(
  SUPABASE_DB_HOST = Sys.getenv("SUPABASE_DB_HOST", unset = NA),
  SUPABASE_DB_PASSWORD = Sys.getenv("SUPABASE_DB_PASSWORD", unset = NA)
)
restore_env <- function() {
  for (k in names(saved_env)) {
    if (is.na(saved_env[[k]])) Sys.unsetenv(k)
    else do.call(Sys.setenv, setNames(list(saved_env[[k]]), k))
  }
}
on.exit(restore_env(), add = TRUE)


# ---------------------------------------------------------------------------
# Test 1: mode="duckdb" + missing file → explicit stop() with helpful message
# ---------------------------------------------------------------------------
test_that("mode=duckdb with missing file throws clear error (not silent empty db)", {
  fx <- make_fixture(mode = "duckdb",
                     duckdb_path = "/nonexistent/path/app_data.duckdb")

  expect_error(
    dbConnectAppData(config_path = fx$cfg_path, verbose = FALSE),
    regexp = "DuckDB mode requested but file not available",
    info = "fn_dbConnectAppData.R lines 91-103 must throw with this message"
  )
})


# ---------------------------------------------------------------------------
# Test 2: mode="duckdb" + LFS pointer (file < 1KB) → explicit stop()
# ---------------------------------------------------------------------------
test_that("mode=duckdb with LFS pointer (tiny file) throws", {
  fx <- make_fixture(mode = "duckdb")
  duckdb_dir <- file.path(fx$tmpdir, "data", "app_data")
  dir.create(duckdb_dir, recursive = TRUE, showWarnings = FALSE)
  pointer_path <- file.path(duckdb_dir, "app_data.duckdb")
  # Simulate LFS pointer file (~130 bytes)
  writeLines(c("version https://git-lfs.github.com/spec/v1",
               "oid sha256:dummy",
               "size 12345"), pointer_path)

  old_wd <- setwd(fx$tmpdir)
  on.exit(setwd(old_wd), add = TRUE)

  expect_error(
    dbConnectAppData(config_path = "app_config.yaml", verbose = FALSE),
    regexp = "DuckDB mode requested but file not available",
    info = "Files under 1KB are treated as LFS pointers per fn_dbConnectAppData.R lines 76-83"
  )
})


# ---------------------------------------------------------------------------
# Test 3: mode="supabase" + missing env vars → explicit stop()
# ---------------------------------------------------------------------------
test_that("mode=supabase with missing env vars throws clear error", {
  fx <- make_fixture(mode = "supabase")
  Sys.unsetenv("SUPABASE_DB_HOST")
  Sys.unsetenv("SUPABASE_DB_PASSWORD")

  expect_error(
    dbConnectAppData(config_path = fx$cfg_path, verbose = FALSE),
    regexp = "Supabase mode requested but credentials not configured",
    info = "fn_dbConnectAppData.R lines 105-116 must throw with this message"
  )
})


# ---------------------------------------------------------------------------
# Test 4: mode="auto" + neither backend available → explicit stop()
# ---------------------------------------------------------------------------
test_that("mode=auto with no backend available throws clear error naming both", {
  fx <- make_fixture(mode = "auto",
                     duckdb_path = "/nonexistent/auto_test.duckdb")
  Sys.unsetenv("SUPABASE_DB_HOST")
  Sys.unsetenv("SUPABASE_DB_PASSWORD")

  expect_error(
    dbConnectAppData(config_path = fx$cfg_path, verbose = FALSE),
    regexp = "No database backend available",
    info = "fn_dbConnectAppData.R lines 119-134 must throw naming both backends"
  )
})


# ---------------------------------------------------------------------------
# Test 5: explicit db_path arg overrides config (regression on mode resolution)
# ---------------------------------------------------------------------------
test_that("missing config + missing db_path throws", {
  expect_error(
    dbConnectAppData(config_path = "/nonexistent/config.yaml", verbose = FALSE),
    regexp = "Required config file not found"
  )
})


# ---------------------------------------------------------------------------
# Test 6: missing config + provided db_path uses defaults (warns or no error
#         until the actual connect attempt)
# ---------------------------------------------------------------------------
test_that("missing config + provided db_path falls through to default mode='auto'", {
  # With db_path provided but file missing AND no Supabase env, auto mode
  # should still throw "No database backend available"
  Sys.unsetenv("SUPABASE_DB_HOST")
  Sys.unsetenv("SUPABASE_DB_PASSWORD")

  expect_error(
    dbConnectAppData(
      db_path = "/nonexistent/explicit_path.duckdb",
      config_path = "/nonexistent/config.yaml",
      verbose = FALSE
    ),
    regexp = "No database backend available"
  )
})
