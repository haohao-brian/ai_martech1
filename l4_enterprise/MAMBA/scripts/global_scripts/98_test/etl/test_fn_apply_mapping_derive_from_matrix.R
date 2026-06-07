# Tests for fn_apply_mapping.R derive_from full matrix coverage (#612)
#
# Per #612 issue body: bridge interpreter test matrix gap. Pre-existing tests
# (test_fn_apply_mapping_sha256.R) cover the new sha256 path (#609). This file
# fills the broader coverage gap:
#
#   M1: Each of 4 supported derive_from expressions in apply_fallback()
#   M2: Unsupported derive expression class → warning + sentinel
#   M3: Boundary cases — NULL fallback, missing fb$value, type fallback paths
#
# Cross-bridge integration (loading all 14 existing bridges + asserting their
# derive_from rules execute as expected) is deferred — broader scope than
# #612 v1; would benefit from #608.2 spectra change scope.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_fn_apply_mapping_derive_from_matrix.R')"

suppressPackageStartupMessages({
  library(testthat)
})

TEST_DIR <- if (!is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  getwd()
}
APPLY_MAPPING_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "05_etl_utils/glue/fn_apply_mapping.R"),
  mustWork = FALSE
)

if (!file.exists(APPLY_MAPPING_PATH)) {
  skip(paste("Cannot locate fn_apply_mapping.R at", APPLY_MAPPING_PATH))
}

source(APPLY_MAPPING_PATH)

make_spec <- function(derive_expr,
                      type = "VARCHAR",
                      sentinel_value = "UNKNOWN") {
  list(
    type = type,
    fallback = list(
      rule = "derive_from",
      derive = derive_expr,
      value = sentinel_value
    )
  )
}

# ============================================================================
# M1: Each of 4 supported derive_from expressions
# ============================================================================

test_that("M1.1: canonical_target.platform → returns platform_id", {
  spec <- make_spec("from canonical_target.platform")
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list(),
                       canonical_target_platform = "amz")
  expect_equal(out, "amz")

  # Different platform
  out_cbz <- apply_fallback(spec, mapping_entry = list(),
                           current_value = NULL,
                           result_so_far = list(),
                           canonical_target_platform = "cbz")
  expect_equal(out_cbz, "cbz")
})

test_that("M1.2: Sys.time() → returns POSIXct", {
  spec <- make_spec("Sys.time()")
  before <- Sys.time()
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list())
  after <- Sys.time()
  expect_s3_class(out, "POSIXct")
  expect_true(out >= before && out <= after)
})

test_that("M1.3: unit_price * quantity → product", {
  spec <- make_spec("unit_price * quantity")
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list(unit_price = c(10, 20, 5),
                                            quantity = c(2, 3, 4)))
  expect_equal(out, c(20, 60, 20))
})

test_that("M1.4: total_amount / quantity → quotient", {
  spec <- make_spec("total_amount / quantity")
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list(total_amount = c(100, 200, 50),
                                            quantity = c(2, 5, 10)))
  expect_equal(out, c(50, 40, 5))
})

# ============================================================================
# M2: Unsupported derive expression → warning + sentinel
# ============================================================================

test_that("M2.1: random unrecognized expression → warning + sentinel", {
  spec <- make_spec("md5(some_field)", sentinel_value = "UNKNOWN_THING")
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list(some_field = c("a", "b"))),
    "is not implemented"
  )
  expect_equal(out, "UNKNOWN_THING")
})

test_that("M2.2: regex extraction expression → warning + sentinel", {
  spec <- make_spec(
    "extract_regex(评论链接, '/R[A-Z0-9]+$')",
    sentinel_value = "UNKNOWN_REVIEW"
  )
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list()),
    "is not implemented"
  )
  expect_equal(out, "UNKNOWN_REVIEW")
})

test_that("M2.3: custom function call → warning + sentinel", {
  spec <- make_spec("my_custom_helper(field_a)",
                    sentinel_value = "UNKNOWN")
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list(field_a = c(1, 2))),
    "is not implemented"
  )
  expect_equal(out, "UNKNOWN")
})

# ============================================================================
# M3: Boundary cases
# ============================================================================

test_that("M3.1: spec$fallback is NULL → empty string for VARCHAR", {
  spec <- list(type = "VARCHAR", fallback = NULL)
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list())
  expect_equal(out, "")
})

test_that("M3.2: spec$fallback is NULL → NA for non-VARCHAR/TEXT", {
  spec <- list(type = "INTEGER", fallback = NULL)
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list())
  expect_true(is.na(out))
})

test_that("M3.3: rule = 'use_value' returns fb$value", {
  spec <- list(
    type = "VARCHAR",
    fallback = list(rule = "use_value", value = "constant_value")
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list())
  expect_equal(out, "constant_value")
})

test_that("M3.4: rule = 'sentinel' returns fb$value", {
  spec <- list(
    type = "VARCHAR",
    fallback = list(rule = "sentinel", value = "UNKNOWN_X")
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = list())
  expect_equal(out, "UNKNOWN_X")
})

test_that("M3.5: unknown rule type → warning + empty string", {
  spec <- list(
    type = "VARCHAR",
    fallback = list(rule = "totally_made_up_rule")
  )
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list()),
    "Unknown fallback rule"
  )
  expect_equal(out, "")
})

test_that("M3.6: unit_price * quantity with length mismatch → silent fallthrough", {
  # When lengths mismatch, current implementation falls through without warning
  # to the unrecognized-expression warning. This is a subtle behavior — the
  # mismatch is detected but message is generic, NOT specific to length.
  spec <- make_spec("unit_price * quantity", sentinel_value = "MISMATCH")
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list(unit_price = c(10, 20),
                                              quantity = c(2, 3, 4))),
    "is not implemented"
  )
  expect_equal(out, "MISMATCH")
})

test_that("M3.7: total_amount / quantity with zero quantity → fallthrough", {
  # all(qty > 0) condition fails when any qty is 0
  spec <- make_spec("total_amount / quantity", sentinel_value = "DIVZERO")
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list(total_amount = c(100, 50),
                                              quantity = c(0, 2))),
    "is not implemented"
  )
  expect_equal(out, "DIVZERO")
})

test_that("M3.8: empty derive expression → fallthrough warning", {
  spec <- make_spec("", sentinel_value = "EMPTY")
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list()),
    "is not implemented"
  )
  expect_equal(out, "EMPTY")
})

test_that("M3.9: TEXT type with no fb$value → empty string", {
  spec <- list(
    type = "TEXT",
    fallback = list(rule = "derive_from", derive = "made_up_thing()")
  )  # no value field
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list()),
    "is not implemented"
  )
  expect_equal(out, "")
})

test_that("M3.10: NUMERIC type with no fb$value → NA", {
  spec <- list(
    type = "NUMERIC",
    fallback = list(rule = "derive_from", derive = "made_up_thing()")
  )
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = list()),
    "is not implemented"
  )
  expect_true(is.na(out))
})
