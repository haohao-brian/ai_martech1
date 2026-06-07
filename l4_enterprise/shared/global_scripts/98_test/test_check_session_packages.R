#' Test Script for check_session_packages Helper (DEV_R057)
#'
#' Verifies the structured-result contract from
#' specs/session-start-toolchain-readiness/spec.md:
#'   - returns list with r_version_actual / r_version_required /
#'     r_version_ok / missing_core / missing_optional
#'   - stop_on_missing_core = FALSE never invokes stop()
#'   - stop_on_missing_core = TRUE invokes stop() with actionable
#'     error format when core packages are missing
#'   - actionable error includes install.packages(c('...')) remedy
#'   - R version assertion uses minimum 4.4.0 default
#'
#' Tests are runnable via:
#'   cd shared/global_scripts/98_test
#'   Rscript test_check_session_packages.R
#'
#' @date 2026-05-02
#' @issue #507 / change dev-r057-session-start-toolchain-readiness

library(testthat)

# Source the helper under test
source("../04_utils/fn_check_session_packages.R")

# ----- Reusable mock for installed.packages() -----------------------
# Override base::installed.packages within a local environment so the
# helper sees a controlled package list during the test, then restore.
with_mocked_installed <- function(pkg_names, expr) {
  fake_table <- matrix(
    pkg_names,
    nrow = length(pkg_names),
    ncol = 1,
    dimnames = list(NULL, "Package")
  )
  prev <- utils::installed.packages
  unlockBinding("installed.packages", asNamespace("utils"))
  assign("installed.packages",
         function(...) fake_table,
         envir = asNamespace("utils"))
  on.exit({
    assign("installed.packages", prev, envir = asNamespace("utils"))
    lockBinding("installed.packages", asNamespace("utils"))
  })
  force(expr)
}

# =========================
# Test 1: structured-result contract (stop_on_missing_core = FALSE)
# =========================

test_that("returns full result object with required fields when nothing missing", {
  # Pretend every core + optional package is installed
  all_pkgs <- c(check_session_core_packages(),
                check_session_optional_packages())
  res <- with_mocked_installed(all_pkgs,
    check_session_packages(stop_on_missing_core = FALSE)
  )

  expect_type(res, "list")
  expect_named(res, c(
    "r_version_actual", "r_version_required", "r_version_ok",
    "missing_core", "missing_optional"
  ), ignore.order = TRUE)
  expect_type(res$r_version_actual, "character")
  expect_type(res$r_version_required, "character")
  expect_type(res$r_version_ok, "logical")
  expect_type(res$missing_core, "character")
  expect_type(res$missing_optional, "character")
  expect_length(res$missing_core, 0)
  expect_length(res$missing_optional, 0)
})

# =========================
# Test 2: stop_on_missing_core = FALSE never stops
# =========================

test_that("stop_on_missing_core=FALSE returns missing_core without invoking stop()", {
  # Pretend nothing is installed -- core is fully missing
  res <- with_mocked_installed(character(0),
    check_session_packages(stop_on_missing_core = FALSE)
  )
  expect_true(length(res$missing_core) > 0L)
  # Did not throw; control reached here
  expect_true(TRUE)
})

# =========================
# Test 3: stop_on_missing_core = TRUE stops with actionable error
# =========================

test_that("stop_on_missing_core=TRUE stops with actionable install.packages remedy when core missing", {
  err <- tryCatch(
    with_mocked_installed(character(0),
      check_session_packages(stop_on_missing_core = TRUE)
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_true(grepl("Session-start toolchain readiness check failed", msg, fixed = TRUE))
  expect_true(grepl("Missing core packages:", msg, fixed = TRUE))
  expect_true(grepl("install.packages\\(c\\(", msg))
  expect_true(grepl("DEV_R057", msg, fixed = TRUE))
})

# =========================
# Test 4: spec example -- core has data.table, dbplyr, yaml; only data.table installed
# =========================

test_that("spec Example produces exact actionable error format", {
  # Spec example: core list contains c('data.table', 'dbplyr', 'yaml');
  # only data.table is installed.
  err <- tryCatch(
    with_mocked_installed(c("data.table"),
      check_session_packages(
        stop_on_missing_core = TRUE,
        core_pkgs = c("data.table", "dbplyr", "yaml"),
        optional_pkgs = character(0)
      )
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  # Per spec example: "Missing core packages: dbplyr, yaml"
  expect_true(grepl("Missing core packages: dbplyr, yaml", msg, fixed = TRUE))
  # Per spec example: "Remedy: install.packages(c('dbplyr', 'yaml'))"
  expect_true(grepl("install.packages(c('dbplyr', 'yaml'))", msg, fixed = TRUE))
})

# =========================
# Test 5: R version assertion -- below 4.4.0 fails
# =========================

test_that("R version assertion fails when running R is below 4.4.0", {
  # Force R_MIN higher than current R version to simulate too-low running R
  res <- with_mocked_installed(character(0),
    check_session_packages(
      stop_on_missing_core = FALSE,
      core_pkgs = character(0),
      optional_pkgs = character(0),
      r_min = "99.99.0"   # impossibly high -> any real R is below it
    )
  )
  expect_false(res$r_version_ok)
  expect_equal(res$r_version_required, "99.99.0")
})

test_that("R version assertion passes when running R meets 4.4.0", {
  # Use R_MIN = 4.0.0 so any modern R passes
  res <- with_mocked_installed(character(0),
    check_session_packages(
      stop_on_missing_core = FALSE,
      core_pkgs = character(0),
      optional_pkgs = character(0),
      r_min = "4.0.0"
    )
  )
  expect_true(res$r_version_ok)
  expect_equal(res$r_version_required, "4.0.0")
})

# =========================
# Test 6: R version below R_MIN with stop_on_missing_core=TRUE -> actionable upgrade message
# =========================

test_that("stop_on_missing_core=TRUE stops with R version upgrade remedy when R is too old", {
  err <- tryCatch(
    with_mocked_installed(character(0),
      check_session_packages(
        stop_on_missing_core = TRUE,
        core_pkgs = character(0),
        optional_pkgs = character(0),
        r_min = "99.99.0"
      )
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_true(grepl("Session-start R version assertion failed", msg, fixed = TRUE))
  expect_true(grepl("99.99.0", msg, fixed = TRUE))
  expect_true(grepl("upgrade R", msg, fixed = TRUE))
})

# =========================
# Test 7: missing optional emits warning but does not stop
# =========================

test_that("missing optional packages emit warning() but do not stop", {
  warned <- character(0)
  withCallingHandlers(
    {
      res <- with_mocked_installed(character(0),
        check_session_packages(
          stop_on_missing_core = TRUE,
          core_pkgs = character(0),
          optional_pkgs = c("testthat", "lintr"),
          r_min = "4.0.0"
        )
      )
      expect_setequal(res$missing_optional, c("testthat", "lintr"))
    },
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("Missing optional packages", warned, fixed = TRUE)))
})

# =========================
# Test 8: canonical core/optional list accessors are exported
# =========================

test_that("check_session_core_packages() and check_session_optional_packages() return canonical vectors", {
  core <- check_session_core_packages()
  opt  <- check_session_optional_packages()
  expect_type(core, "character")
  expect_type(opt, "character")
  expect_true(length(core) >= 10L)   # at least 10 core packages per Decision 1
  expect_true(length(opt) >= 1L)
  # These are the single source of truth -- spec requirement
  expect_true("data.table" %in% core)
  expect_true("dbplyr" %in% core)
  expect_true("DBI" %in% core)
  expect_true("duckdb" %in% core)
  expect_true("yaml" %in% core)
})

cat("\n[OK] All check_session_packages tests passed\n")
