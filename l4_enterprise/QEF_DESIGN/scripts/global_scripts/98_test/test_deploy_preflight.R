# Tests for preflight_deploy_check() — pre-deploy sanity gate (#595)
#
# Verifies that the preflight refuses inconsistent config combinations
# BEFORE deploy ships. The most critical case is #595's root cause:
#
#   app_config.yaml: database.mode='duckdb'
#   .rsconnectignore: excludes '*.duckdb'  ← contradiction
#
# Production deploy with this combo → app reads non-existent file → bug.
#
# Run with:
#   Rscript -e "testthat::test_file('98_test/test_deploy_preflight.R')"

library(testthat)

# Resolve the script under test
resolve_preflight_path <- function() {
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile) && nzchar(frame$ofile) && file.exists(frame$ofile)) {
      script_dir <- dirname(normalizePath(frame$ofile))
      candidate <- normalizePath(
        file.path(script_dir, "..", "23_deployment", "preflight_deploy_check.R"),
        mustWork = FALSE
      )
      if (file.exists(candidate)) return(candidate)
    }
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    sp <- normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE)
    if (file.exists(sp)) {
      candidate <- normalizePath(
        file.path(dirname(sp), "..", "23_deployment", "preflight_deploy_check.R"),
        mustWork = FALSE
      )
      if (file.exists(candidate)) return(candidate)
    }
  }
  for (rel in c("23_deployment/preflight_deploy_check.R",
                "../23_deployment/preflight_deploy_check.R")) {
    if (file.exists(rel)) return(normalizePath(rel))
  }
  stop("Cannot locate preflight_deploy_check.R from cwd ", getwd())
}

source(resolve_preflight_path())

# Save + clear Supabase env vars at test start; restore on exit
saved_env <- list(
  SUPABASE_DB_HOST = Sys.getenv("SUPABASE_DB_HOST", unset = NA),
  SUPABASE_DB_PASSWORD = Sys.getenv("SUPABASE_DB_PASSWORD", unset = NA),
  IDD_DEPLOY_FORCE = Sys.getenv("IDD_DEPLOY_FORCE", unset = NA)
)
restore_env <- function() {
  for (k in names(saved_env)) {
    if (is.na(saved_env[[k]])) Sys.unsetenv(k)
    else do.call(Sys.setenv, setNames(list(saved_env[[k]]), k))
  }
}
on.exit(restore_env(), add = TRUE)

# Helper: build a temp dir with a config + optional rsconnectignore
make_fixture <- function(mode, has_duckdb_file = TRUE,
                          rsconnectignore_excludes_duckdb = TRUE,
                          tmpdir = tempfile("idd595_pre_")) {
  dir.create(tmpdir, recursive = TRUE, showWarnings = FALSE)

  # Minimal config
  cfg <- list(
    database = list(
      mode = mode,
      duckdb = list(path = "data/app_data/app_data.duckdb", read_only = TRUE)
    )
  )
  yaml::write_yaml(cfg, file.path(tmpdir, "app_config.yaml"))

  # Optionally create a duckdb file (>1KB so it passes "valid" check)
  if (has_duckdb_file) {
    dir.create(file.path(tmpdir, "data", "app_data"), recursive = TRUE,
               showWarnings = FALSE)
    big <- paste(rep("x", 2000), collapse = "")
    writeLines(big, file.path(tmpdir, "data", "app_data", "app_data.duckdb"))
  }

  # .rsconnectignore
  if (rsconnectignore_excludes_duckdb) {
    writeLines(c("# Test fixture", "*.duckdb", "*.wal"),
               file.path(tmpdir, ".rsconnectignore"))
  } else {
    writeLines(c("# Test fixture", "*.wal"),
               file.path(tmpdir, ".rsconnectignore"))
  }

  tmpdir
}


# ---------------------------------------------------------------------------
# Test 1 (CRITICAL — #595 root cause): mode=duckdb + .rsconnectignore excludes
# *.duckdb → REFUSE deploy
# ---------------------------------------------------------------------------
test_that("PR-mode duckdb + .rsconnectignore excluding *.duckdb is refused (#595)", {
  fx <- make_fixture(mode = "duckdb",
                     has_duckdb_file = TRUE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "#595 production-affecting config combo",
    info = "This is the canonical #595 bug class — must be caught"
  )
})


# ---------------------------------------------------------------------------
# Test 2: mode=duckdb + no .rsconnectignore exclusion + file exists → PASS
# ---------------------------------------------------------------------------
test_that("mode=duckdb with file present and no exclusion passes", {
  fx <- make_fixture(mode = "duckdb",
                     has_duckdb_file = TRUE,
                     rsconnectignore_excludes_duckdb = FALSE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  expect_invisible(preflight_deploy_check(verbose = FALSE))
})


# ---------------------------------------------------------------------------
# Test 3: mode=duckdb + missing file → REFUSE (independent of rsconnectignore)
# ---------------------------------------------------------------------------
test_that("mode=duckdb with missing file is refused", {
  fx <- make_fixture(mode = "duckdb",
                     has_duckdb_file = FALSE,
                     rsconnectignore_excludes_duckdb = FALSE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "mode='duckdb' but file missing"
  )
})


# ---------------------------------------------------------------------------
# Test 4: mode=supabase + SUPABASE_DB_HOST not set → REFUSE
# ---------------------------------------------------------------------------
test_that("mode=supabase without SUPABASE_DB_HOST is refused", {
  fx <- make_fixture(mode = "supabase",
                     has_duckdb_file = FALSE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)
  Sys.unsetenv("SUPABASE_DB_HOST")
  Sys.unsetenv("SUPABASE_DB_PASSWORD")

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "SUPABASE_DB_HOST env var not set"
  )
})


# ---------------------------------------------------------------------------
# Test 5: mode=auto + duckdb present → PASS (typical local dev)
# ---------------------------------------------------------------------------
test_that("mode=auto with local duckdb present passes", {
  fx <- make_fixture(mode = "auto",
                     has_duckdb_file = TRUE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  expect_invisible(preflight_deploy_check(verbose = FALSE))
})


# ---------------------------------------------------------------------------
# Test 6: mode=auto + no duckdb + no Supabase → REFUSE
# ---------------------------------------------------------------------------
test_that("mode=auto with no duckdb and no Supabase is refused", {
  fx <- make_fixture(mode = "auto",
                     has_duckdb_file = FALSE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)
  Sys.unsetenv("SUPABASE_DB_HOST")
  Sys.unsetenv("SUPABASE_DB_PASSWORD")

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "neither backend available"
  )
})


# ---------------------------------------------------------------------------
# Test 7: mode=auto + Supabase env set → PASS (production deploy fallback)
# ---------------------------------------------------------------------------
test_that("mode=auto with Supabase env set passes (no local duckdb needed)", {
  fx <- make_fixture(mode = "auto",
                     has_duckdb_file = FALSE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)
  Sys.setenv(SUPABASE_DB_HOST = "fake-host.example.com",
             SUPABASE_DB_PASSWORD = "fake-password")

  expect_invisible(preflight_deploy_check(verbose = FALSE))
})


# ---------------------------------------------------------------------------
# Test 8: invalid mode → REFUSE
# ---------------------------------------------------------------------------
test_that("invalid mode value is refused", {
  fx <- make_fixture(mode = "postgres-old",
                     has_duckdb_file = TRUE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "invalid database.mode"
  )
})


# ---------------------------------------------------------------------------
# Test 9: missing app_config.yaml → REFUSE
# ---------------------------------------------------------------------------
test_that("missing app_config.yaml is refused with actionable message", {
  tmpdir <- tempfile("idd595_pre_no_cfg_")
  dir.create(tmpdir, recursive = TRUE)
  old_wd <- setwd(tmpdir); on.exit(setwd(old_wd), add = TRUE)

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "app_config.yaml not found"
  )
})


# ---------------------------------------------------------------------------
# Test 10: missing database section → REFUSE
# ---------------------------------------------------------------------------
test_that("app_config.yaml missing 'database:' section is refused", {
  tmpdir <- tempfile("idd595_pre_no_db_")
  dir.create(tmpdir, recursive = TRUE)
  old_wd <- setwd(tmpdir); on.exit(setwd(old_wd), add = TRUE)

  cfg <- list(app = list(name = "test"))  # no database section
  yaml::write_yaml(cfg, "app_config.yaml")

  expect_error(
    preflight_deploy_check(verbose = FALSE),
    regexp = "no 'database:' section"
  )
})


# ---------------------------------------------------------------------------
# Test 11: IDD_DEPLOY_FORCE=1 escape hatch bypasses checks (emergency only)
# ---------------------------------------------------------------------------
test_that("IDD_DEPLOY_FORCE=1 bypasses checks (escape hatch)", {
  fx <- make_fixture(mode = "duckdb",
                     has_duckdb_file = TRUE,
                     rsconnectignore_excludes_duckdb = TRUE)
  old_wd <- setwd(fx); on.exit(setwd(old_wd), add = TRUE)

  Sys.setenv(IDD_DEPLOY_FORCE = "1")
  on.exit(Sys.unsetenv("IDD_DEPLOY_FORCE"), add = TRUE)

  # Even though this is the canonical #595 bug combo, force=1 should pass
  expect_invisible(preflight_deploy_check(verbose = FALSE))
})
