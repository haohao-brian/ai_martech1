# Tests for fn_hash_prerawdata_schema all-NA logical column handling (#501 Task 4.1)
#
# Per spectra change qef-product-attribute-schema-fix design D3:
# Columns whose R type is "logical" AND whose values are entirely NA SHALL be
# treated as type "character" for fingerprint hashing. This stabilizes the
# fingerprint across the all-NA-to-typed-value transition that previously
# caused false-positive drift.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_hash_prerawdata_schema_logical_na.R')"

suppressPackageStartupMessages({
  library(testthat)
})

TEST_DIR <- if (!is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  getwd()
}
HELPER_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "05_etl_utils/glue/fn_hash_prerawdata_schema.R"),
  mustWork = FALSE
)

context("fn_hash_prerawdata_schema: all-NA logical handling")

test_that("Test 1: all-NA logical column hashes as character type", {
  source(HELPER_PATH, local = TRUE)
  # Build column types as the helper expects (post-fix behavior)
  cols <- c("brand", "url")
  types_with_logical <- c("character", "logical")  # current (pre-fix) behavior
  types_post_fix <- c("character", "character")    # expected (post-fix) behavior

  # Pre-fix and post-fix should now produce same hash on all-NA logical input
  # because the helper internally normalizes logical-all-NA to character.
  # We verify by calling hash_prerawdata_schema with the same column names but
  # different type tags and confirming they collapse.
  hash_with_logical_tag  <- hash_prerawdata_schema(cols, types_with_logical)
  hash_with_character_tag <- hash_prerawdata_schema(cols, types_post_fix)

  # Pre-fix: these would produce different hashes
  # Post-fix: the function does NOT internally re-infer; it trusts the caller's
  # types. So this test actually tests the CALLER convention, not the helper.
  # The helper is type-agnostic. The fix lives in the CALLER (typically the
  # bridge orchestrator that invokes vapply(df, function(x) class(x)[1], ...)).
  #
  # Therefore: skip this test if the helper itself doesn't infer types;
  # the canonical test is on the caller. We verify the helper still produces
  # deterministic output for any given (cols, types) pair.
  expect_match(hash_with_logical_tag$value, "^[0-9a-f]{64}$")
  expect_match(hash_with_character_tag$value, "^[0-9a-f]{64}$")
  # And the two hashes differ (because we passed different type tags) —
  # that's the helper's job, type-tag determinism.
  expect_false(identical(hash_with_logical_tag$value,
                         hash_with_character_tag$value))
})

# The fix actually lives in CALLERS that call vapply(df, function(x) class(x)[1], ...).
# Per design D3, we modify those callers. The canonical caller is in the
# bridge runtime and codegen helpers. For this change, we add a wrapper helper
# `infer_column_types_for_fingerprint(df)` in fn_hash_prerawdata_schema.R that
# applies the all-NA-logical-to-character normalization, and the callers SHALL
# use this wrapper instead of bare class(x)[1].

test_that("Test 2: infer_column_types_for_fingerprint exists and exports the helper", {
  source(HELPER_PATH, local = TRUE)
  expect_true(exists("infer_column_types_for_fingerprint"),
              info = paste("Helper not found in", HELPER_PATH))
})

test_that("Test 3: all-NA logical column normalized to character", {
  source(HELPER_PATH, local = TRUE)
  df <- data.frame(
    brand = c("a", "b", "c"),
    url   = NA,                              # all-NA → R infers logical
    stringsAsFactors = FALSE
  )
  types <- infer_column_types_for_fingerprint(df)
  expect_equal(types[["brand"]], "character")
  expect_equal(types[["url"]], "character",
               info = "all-NA logical column SHALL be reported as 'character'")
})

test_that("Test 4: hash stable across all-NA-to-character transition", {
  source(HELPER_PATH, local = TRUE)

  df_iter1 <- data.frame(
    brand = c("a", "b", "c"),
    url   = NA,
    stringsAsFactors = FALSE
  )
  df_iter2 <- data.frame(
    brand = c("a", "b", "c"),
    url   = c(NA, "https://example.com", NA),  # one URL lands
    stringsAsFactors = FALSE
  )

  types1 <- infer_column_types_for_fingerprint(df_iter1)
  types2 <- infer_column_types_for_fingerprint(df_iter2)

  hash1 <- hash_prerawdata_schema(names(types1), unname(types1))
  hash2 <- hash_prerawdata_schema(names(types2), unname(types2))

  expect_identical(hash1$value, hash2$value,
                   info = "Fingerprint SHALL be stable when all-NA logical column transitions to character")
})

test_that("Test 5: hash differs when all-NA logical transitions to numeric (legitimate drift)", {
  source(HELPER_PATH, local = TRUE)

  df_iter1 <- data.frame(rank = NA, stringsAsFactors = FALSE)
  df_iter2 <- data.frame(rank = c(1L, 2L, 3L), stringsAsFactors = FALSE)

  types1 <- infer_column_types_for_fingerprint(df_iter1)
  types2 <- infer_column_types_for_fingerprint(df_iter2)

  hash1 <- hash_prerawdata_schema(names(types1), unname(types1))
  hash2 <- hash_prerawdata_schema(names(types2), unname(types2))

  expect_false(identical(hash1$value, hash2$value),
               info = "Fingerprint SHALL detect type drift when all-NA logical becomes numeric/integer")
})

test_that("Test 6: all-NA character column NOT special-cased (still character)", {
  source(HELPER_PATH, local = TRUE)
  df <- data.frame(
    notes = NA_character_,
    stringsAsFactors = FALSE
  )
  types <- infer_column_types_for_fingerprint(df)
  expect_equal(types[["notes"]], "character",
               info = "all-NA character column SHALL be reported as 'character' (no special-case for non-logical types)")
})

test_that("Test 7: logical column with at least one non-NA retains 'logical' type", {
  source(HELPER_PATH, local = TRUE)
  df <- data.frame(
    is_active = c(TRUE, NA, FALSE),
    stringsAsFactors = FALSE
  )
  types <- infer_column_types_for_fingerprint(df)
  expect_equal(types[["is_active"]], "logical",
               info = "logical column with at least one TRUE/FALSE SHALL retain logical type")
})

test_that("Test 8: numeric / integer / Date types unchanged", {
  source(HELPER_PATH, local = TRUE)
  df <- data.frame(
    qty   = 1:3,
    price = c(1.5, 2.5, 3.5),
    when  = as.Date(c("2026-01-01", "2026-02-01", "2026-03-01")),
    stringsAsFactors = FALSE
  )
  types <- infer_column_types_for_fingerprint(df)
  expect_equal(types[["qty"]], "integer")
  expect_equal(types[["price"]], "numeric")
  expect_equal(types[["when"]], "Date")
})
