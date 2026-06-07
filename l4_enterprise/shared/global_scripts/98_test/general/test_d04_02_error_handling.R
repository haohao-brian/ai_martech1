#!/usr/bin/env Rscript

# Regression tests for #724 — D04_02.R error handling fixes
#
# Covers 3 bugs identified in /idd-diagnose #724:
#   - Bug A: merged_table_name init-move out of tryCatch scope
#   - Bug B: withCallingHandlers captures user-frame stack before tryCatch unwinds
#   - Bug C: tibble data-mask shadowing — vapply must run OUTSIDE tibble() when
#            args reference variables that share names with tibble columns

suppressPackageStartupMessages({
  library(testthat)
})

# ---------------------------------------------------------------------------
# Bug C regression: reproduce the data-mask shadowing pattern in isolation
# ---------------------------------------------------------------------------

test_that("tibble data-mask shadows outer variable when column name matches (Bug C reproduction)", {
  suppressPackageStartupMessages(library(tibble))

  # Simulates the pattern from D04_02.R: a function that errors on vector input
  inner_fn <- function(term, platform) {
    if (length(platform) != 1L) {
      stop("platform must be length 1, got ", length(platform))
    }
    paste0(term, "@", platform)
  }

  platform <- "amz"  # outer scalar
  terms <- c("a", "b", "c")

  # ANTI-PATTERN: vapply inside tibble, platform in both column slot and arg
  # tibble exposes the `platform = platform` column (recycled to 3) and later
  # expressions see THAT, not the outer scalar.
  expect_error(
    tibble(
      platform = platform,
      predictor = terms,
      result = vapply(terms, inner_fn, character(1), platform = platform)
    ),
    regexp = "platform must be length 1|length = 3"
  )

  # GOOD-PATTERN: extract vapply BEFORE tibble so platform resolves to outer scope
  result_vec <- vapply(terms, inner_fn, character(1), platform = platform)
  output <- tibble(
    platform = platform,
    predictor = terms,
    result = result_vec
  )
  expect_equal(nrow(output), 3L)
  expect_equal(unname(output$result), c("a@amz", "b@amz", "c@amz"))
})

# ---------------------------------------------------------------------------
# Bug A regression: merged_table_name accessible in fail path
# ---------------------------------------------------------------------------

test_that("merged_table_name resolvable even when tryCatch body errors", {
  # Mimics D04_02.R structure: pre-compute merged_table_name OUTSIDE tryCatch
  platform <- "amz"
  merged_table_name <- sprintf("df_%s_poisson_analysis_all", platform)
  error_occurred <- FALSE

  tryCatch({
    stop("simulated Phase 1 failure")
  }, error = function(e) {
    error_occurred <<- TRUE
  })

  # After Phase 1 fail, PART 4 SUMMARIZE should still be able to reference
  # merged_table_name without `object 'merged_table_name' not found`
  expect_true(exists("merged_table_name"))
  expect_equal(merged_table_name, "df_amz_poisson_analysis_all")
  expect_true(error_occurred)
})

test_that("merged_table_name init INSIDE tryCatch causes scope failure (anti-pattern)", {
  # Demonstrates why init-move was the fix — this pattern is what #724 had
  platform <- "amz"
  rm(list = "merged_table_name", envir = environment(), inherits = FALSE)

  # Function returns whether merged_table_name was accessible
  fail_path <- function() {
    tryCatch({
      stop("Phase 1 fail before merged_table_name init")
      merged_table_name <- sprintf("df_%s_poisson_analysis_all", platform)
    }, error = function(e) {
      # error swallowed
    })

    # Try to access — fails because merged_table_name never defined
    tryCatch(exists("merged_table_name", inherits = FALSE), error = function(e) FALSE)
  }

  expect_false(fail_path())
})

# ---------------------------------------------------------------------------
# Bug B regression: withCallingHandlers captures user-frame stack
# ---------------------------------------------------------------------------

test_that("withCallingHandlers wrapping tryCatch captures sys.calls() with user frames intact", {
  captured_frames <- NULL

  outer_user_fn <- function() {
    inner_user_fn()
  }
  inner_user_fn <- function() {
    stop("simulated bug C")
  }

  tryCatch(
    withCallingHandlers({
      outer_user_fn()
    },
    error = function(e) {
      all_calls <- sys.calls()
      user_frames <- list()
      for (i in seq_len(length(all_calls))) {
        line <- paste(deparse(all_calls[[i]]), collapse = " ")
        is_internal <- grepl(
          "^(tryCatch|withCallingHandlers|doTryCatch|tryCatchList|tryCatchOne|h\\(simpleError)",
          line
        )
        if (!is_internal) user_frames[[length(user_frames) + 1L]] <- all_calls[[i]]
      }
      captured_frames <<- user_frames
    }
    ),
    error = function(e) {
      # outer tryCatch catches after withCallingHandlers populated frames
    }
  )

  expect_false(is.null(captured_frames))
  expect_gt(length(captured_frames), 0L)

  frame_strs <- vapply(captured_frames, function(f) {
    paste(deparse(f), collapse = " ")
  }, character(1))
  expect_true(any(grepl("outer_user_fn", frame_strs)))
  expect_true(any(grepl("inner_user_fn", frame_strs)))
})

cat("\n[#724] All D04_02 error handling regression tests PASSED.\n")
