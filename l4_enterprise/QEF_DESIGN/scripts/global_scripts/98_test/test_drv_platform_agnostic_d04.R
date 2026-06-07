#####
# test_drv_platform_agnostic_d04.R - DM_R066 helper + D04 refactor verification
#
# Spectra change: dm-r066-drv-platform-agnosticism (#670)
#
# Tests cover:
#   6.2  resolve_drv_platform: DRV_PLATFORM env var primary
#   6.2b resolve_drv_platform: MAMBA_PLATFORM fallback
#   6.2c resolve_drv_platform: --platform CLI flag last resort
#   6.3  resolve_drv_platform: invalid platform rejected
#   6.4  resolve_drv_platform: fail-fast + structured error listing all 3 sources
#   6.4b resolve_drv_platform: 'all' pseudo-platform rejected
#   6.5  D04_02.R structural: no platform literals outside whitelist/comments
#   6.5b D04_02.R structural: calls resolve_drv_platform() at startup
#   6.5c D04_02.R structural: sprintf platform parameterization for table names
#
# Note: orchestrator `resolve_script_path()` dispatch is verified by
# in-session smoke test during Phase 4.3 (not duplicated here to avoid
# eval()/parse() patterns blocked by security hooks). The script lives in
# `shared/update_scripts/_targets.R` and is not separately exported.
#####

library(testthat)

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Locate helper script (try project-root-relative, fallback to test-dir-relative)
helper_candidates <- c(
  "shared/global_scripts/04_utils/fn_resolve_drv_platform.R",
  file.path(dirname(testthat::test_path() %||% "."), "..", "04_utils", "fn_resolve_drv_platform.R")
)
helper_path <- helper_candidates[file.exists(helper_candidates)][1]
stopifnot(file.exists(helper_path))
source(helper_path, local = TRUE)

# Locate refactored D04_02.R (needed for structural tests 6.5-6.5c)
d04_candidates <- c(
  "shared/update_scripts/DRV/D04/D04_02.R",
  file.path(dirname(testthat::test_path() %||% "."), "..", "..", "update_scripts", "DRV", "D04", "D04_02.R")
)
d04_path <- d04_candidates[file.exists(d04_candidates)][1]
stopifnot(file.exists(d04_path))


# ---------- helper-suite tests (6.2-6.4) ----------

test_that("6.2 DRV_PLATFORM env var has primary precedence over MAMBA_PLATFORM", {
  old_drv <- Sys.getenv("DRV_PLATFORM", unset = NA)
  old_mam <- Sys.getenv("MAMBA_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old_drv)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old_drv)
    if (is.na(old_mam)) Sys.unsetenv("MAMBA_PLATFORM") else Sys.setenv(MAMBA_PLATFORM = old_mam)
  })

  Sys.setenv(DRV_PLATFORM = "cbz", MAMBA_PLATFORM = "eby")
  expect_equal(resolve_drv_platform(args = character(0)), "cbz")
})


test_that("6.2b MAMBA_PLATFORM fallback when DRV_PLATFORM absent", {
  old_drv <- Sys.getenv("DRV_PLATFORM", unset = NA)
  old_mam <- Sys.getenv("MAMBA_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old_drv)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old_drv)
    if (is.na(old_mam)) Sys.unsetenv("MAMBA_PLATFORM") else Sys.setenv(MAMBA_PLATFORM = old_mam)
  })

  Sys.unsetenv("DRV_PLATFORM")
  Sys.setenv(MAMBA_PLATFORM = "eby")
  expect_equal(resolve_drv_platform(args = character(0)), "eby")
})


test_that("6.2c CLI --platform flag fallback when both env vars absent", {
  old_drv <- Sys.getenv("DRV_PLATFORM", unset = NA)
  old_mam <- Sys.getenv("MAMBA_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old_drv)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old_drv)
    if (is.na(old_mam)) Sys.unsetenv("MAMBA_PLATFORM") else Sys.setenv(MAMBA_PLATFORM = old_mam)
  })

  Sys.unsetenv("DRV_PLATFORM")
  Sys.unsetenv("MAMBA_PLATFORM")
  expect_equal(resolve_drv_platform(args = c("--platform", "amz")), "amz")
})


test_that("6.3 invalid platform code rejected with structured error listing valid platforms", {
  old_drv <- Sys.getenv("DRV_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old_drv)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old_drv)
  })

  Sys.setenv(DRV_PLATFORM = "shopify")
  fake_config <- list(
    platforms = list(
      cbz = list(status = "active"),
      eby = list(status = "active")
    )
  )

  expect_error(
    resolve_drv_platform(args = character(0), config = fake_config),
    regexp = "not in active config|DM_R066"
  )

  err <- tryCatch(
    resolve_drv_platform(args = character(0), config = fake_config),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "cbz", fixed = TRUE)
  expect_match(err, "eby", fixed = TRUE)
})


test_that("6.4 absent platform fail-fast with structured error listing all three sources", {
  old_drv <- Sys.getenv("DRV_PLATFORM", unset = NA)
  old_mam <- Sys.getenv("MAMBA_PLATFORM", unset = NA)
  on.exit({
    if (is.na(old_drv)) Sys.unsetenv("DRV_PLATFORM") else Sys.setenv(DRV_PLATFORM = old_drv)
    if (is.na(old_mam)) Sys.unsetenv("MAMBA_PLATFORM") else Sys.setenv(MAMBA_PLATFORM = old_mam)
  })

  Sys.unsetenv("DRV_PLATFORM")
  Sys.unsetenv("MAMBA_PLATFORM")

  err <- tryCatch(
    resolve_drv_platform(args = character(0)),
    error = function(e) conditionMessage(e)
  )

  # Error message must mention all three resolution sources
  expect_match(err, "DRV_PLATFORM", fixed = TRUE)
  expect_match(err, "MAMBA_PLATFORM", fixed = TRUE)
  expect_match(err, "--platform", fixed = TRUE)
  expect_match(err, "DM_R066", fixed = TRUE)
})


test_that("6.4b pseudo-platform 'all' rejected for DRV (DRV runs per concrete platform)", {
  expect_error(
    resolve_drv_platform(args = c("--platform", "all")),
    regexp = "invalid for DRV|'all' is invalid"
  )
})


# ---------- D04_02.R structural tests (6.5) ----------

test_that("6.5 D04_02.R has no platform literals outside whitelist/historical comments", {
  body <- readLines(d04_path)

  # Allowed locations for cbz/eby/amz/etc. literals:
  #   (a) inside exclude_cols whitelist (line contains "item_id")
  #   (b) inside historical comment noting "was hard-coded X" or "hard-coding"
  for (lit in c("cbz", "eby", "amz", "shp", "tiktok")) {
    pattern <- sprintf("\\b%s\\b", lit)
    hits <- grep(pattern, body)

    for (line_no in hits) {
      line <- body[line_no]
      is_whitelist <- grepl("item_id", line)
      is_historical <- grepl("was hard-coded|hard-coding", line)

      if (!is_whitelist && !is_historical) {
        fail(sprintf(
          "D04_02.R contains platform literal '%s' at line %d (NOT in whitelist or historical comment):\n  %s",
          lit, line_no, line
        ))
      }
    }
  }

  succeed()
})


test_that("6.5b D04_02.R sources fn_resolve_drv_platform.R + calls helper at startup", {
  body <- readLines(d04_path)

  expect_true(any(grepl("fn_resolve_drv_platform", body)),
              info = "D04_02.R must source fn_resolve_drv_platform.R helper")
  expect_true(any(grepl("resolve_drv_platform\\(\\)", body)),
              info = "D04_02.R must call resolve_drv_platform() to resolve platform identity")
})


test_that("6.5c D04_02.R uses sprintf platform parameterization for table names", {
  body <- readLines(d04_path)

  # Pattern: sprintf('df_%s_poisson_analysis_*', platform, ...) parameterization
  parameterized <- grep('sprintf.*"df_%s_poisson_analysis', body)
  expect_gt(length(parameterized), 0,
            label = "D04_02.R must use sprintf('df_%s_poisson_analysis_*', platform, ...) parameterization")
})
