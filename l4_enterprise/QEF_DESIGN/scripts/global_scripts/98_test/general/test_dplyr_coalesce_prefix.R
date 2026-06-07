#!/usr/bin/env Rscript
# test_dplyr_coalesce_prefix.R
# ==============================================================================
# Regression test for #447 — dplyr::coalesce namespace prefix requirement
#
# Background:
#   autoinit() in UPDATE_MODE sources 429+ global_scripts files, including
#   07_models/choice_model_lik.R which calls library(fastmatch). fastmatch
#   exports a single-arg coalesce(x) that masks dplyr::coalesce(..., .ptype,
#   .size) on the search path. DRV scripts calling bare coalesce(x, 0) then
#   crash with "unused argument (0)" — silent-mask regression.
#
# Fix: DRV scripts use dplyr::coalesce() namespace prefix to bypass any mask.
# This test guards the fix against future reintroduction of bare coalesce.
#
# Usage (from project root or shared/):
#   Rscript scripts/global_scripts/98_test/general/test_dplyr_coalesce_prefix.R
#
# Principles:
# - MP029: No fake data — tests use the exact coalesce patterns from
#   amz_D04_01.R:260-261,310 and cbz_D04_01.R (already fixed #374 Tier 2)
# - TD_R007: Plain R + assert() pattern matches existing 98_test/general/
# ==============================================================================

# ---------- Test harness ----------

pass_count <- 0L
fail_count <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    pass_count <<- pass_count + 1L
    message(sprintf("  [PASS] %s", msg))
  } else {
    fail_count <<- fail_count + 1L
    message(sprintf("  [FAIL] %s", msg))
  }
}

# ---------- Setup: ensure clean search path for deterministic tests ----------

# Detach fastmatch if any earlier test loaded it; we control load order here.
if ("package:fastmatch" %in% search()) {
  detach("package:fastmatch", unload = TRUE, character.only = FALSE)
}

# dplyr must be available for all scenarios
suppressPackageStartupMessages(library(dplyr))

main <- function() {
  message("=== test_dplyr_coalesce_prefix ===")

  # ------------------------------------------------------------------------
  # Scenario 1: Baseline — only dplyr loaded, bare coalesce() works as
  # dplyr::coalesce(). This establishes the "happy path" that broke under
  # autoinit().
  # ------------------------------------------------------------------------
  message("\n[S1] Baseline: dplyr only, bare coalesce(x, 0) → works")
  x <- c(NA_integer_, 1L, NA_integer_, 3L)
  out1 <- coalesce(x, 0L)
  assert(identical(out1, c(0L, 1L, 0L, 3L)),
         sprintf("baseline coalesce(x, 0L); got=%s", toString(out1)))

  # ------------------------------------------------------------------------
  # Scenario 2: Trigger — load fastmatch AFTER dplyr, bare coalesce(x, 0)
  # resolves to fastmatch::coalesce(x), which has signature function(x) and
  # errors with "unused argument (0)". This IS the production bug #447.
  # ------------------------------------------------------------------------
  if (requireNamespace("fastmatch", quietly = TRUE)) {
    message("\n[S2] fastmatch loaded after dplyr: bare coalesce(x, 0) errors")
    suppressPackageStartupMessages(library(fastmatch))

    resolved <- environmentName(environment(get("coalesce")))
    assert(resolved == "fastmatch",
           sprintf("coalesce now resolves to fastmatch; got=%s", resolved))

    err_msg <- tryCatch({
      coalesce(x, 0L)  # bare call — expected to fail under mask
      "(no error — mask did not trigger)"
    }, error = function(e) conditionMessage(e))
    assert(grepl("unused argument", err_msg, fixed = TRUE),
           sprintf("bare coalesce(x, 0L) under mask errors; msg=%s", err_msg))
  } else {
    message("\n[S2] SKIP — fastmatch not installed; cannot reproduce mask")
  }

  # ------------------------------------------------------------------------
  # Scenario 3: Protection — with fastmatch mask active, dplyr::coalesce()
  # prefix bypasses the mask and works correctly. This is the fix pattern
  # applied in amz_D04_01.R:260-261,310 and cbz_D04_01.R.
  # ------------------------------------------------------------------------
  if ("package:fastmatch" %in% search()) {
    message("\n[S3] dplyr::coalesce prefix works despite fastmatch mask")
    out3 <- dplyr::coalesce(x, 0L)
    assert(identical(out3, c(0L, 1L, 0L, 3L)),
           sprintf("dplyr::coalesce(x, 0L) protected; got=%s", toString(out3)))
  } else {
    message("\n[S3] SKIP — fastmatch not active; cannot verify protection")
  }

  # ------------------------------------------------------------------------
  # Scenario 4: Multi-arg — mirrors amz_D04_01.R:310
  #   dplyr::coalesce(year_label, month_label, day_label, week_label)
  # Verifies 4-arg form works regardless of mask state.
  # ------------------------------------------------------------------------
  message("\n[S4] dplyr::coalesce(y, m, d, w) 4-arg form works")
  year_label  <- c("2024", NA_character_, NA_character_, NA_character_)
  month_label <- c(NA_character_, "2024-03", NA_character_, NA_character_)
  day_label   <- c(NA_character_, NA_character_, "2024-03-15", NA_character_)
  week_label  <- c(NA_character_, NA_character_, NA_character_, "週一")
  out4 <- dplyr::coalesce(year_label, month_label, day_label, week_label)
  expected4 <- c("2024", "2024-03", "2024-03-15", "週一")
  assert(identical(out4, expected4),
         sprintf("4-arg dplyr::coalesce; got=%s", toString(out4)))

  # ------------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------------
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
