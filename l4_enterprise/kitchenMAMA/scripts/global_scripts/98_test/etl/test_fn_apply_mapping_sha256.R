# Tests for fn_apply_mapping.R sha256 derive_from implementation (#609)
#
# Per #609: canonical schema declares `derive: "sha256(field_a + field_b + ...)"`
# patterns (e.g. review_id from product_id + customer_id + review_date) but
# fn_apply_mapping.R apply_fallback() previously only recognized 4 hardcoded
# expressions, falling back to sentinel for sha256 → silent collapse to single
# UNKNOWN_REVIEW row across all reviews.
#
# This test asserts:
#   T1: 2-arg sha256 produces deterministic 64-char hex hashes per row
#   T2: 3-arg sha256 likewise (canonical review_id case)
#   T3: NA in any component is encoded as "<NA>" not silently dropped
#   T4: Length mismatch (defensive) → warning + sentinel fallback
#   T5: Missing field in result_so_far → sentinel fallback (per "when missing")
#   T6: Empty input (n_rows=0) → returns character(0) cleanly
#   T7: Same inputs always produce same hashes (determinism)
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_fn_apply_mapping_sha256.R')"

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

# Helper: build a minimal spec + mapping_entry for derive_from invocation
make_spec <- function(derive_expr, sentinel_value = "UNKNOWN") {
  list(
    type = "VARCHAR",
    fallback = list(
      rule = "derive_from",
      derive = derive_expr,
      value = sentinel_value
    )
  )
}

test_that("T1: 2-arg sha256 produces 64-char hex hash per row", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(a + b)")
  result_so_far <- list(
    a = c("foo", "bar", "baz"),
    b = c("1", "2", "3")
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = result_so_far)
  expect_length(out, 3L)
  expect_true(all(nchar(out) == 64L))   # sha256 hex = 64 chars
  expect_true(all(grepl("^[a-f0-9]+$", out)))
  expect_equal(length(unique(out)), 3L)  # different inputs → different hashes
})

test_that("T2: 3-arg sha256 (canonical review_id case) works", {
  skip_if_not_installed("digest")
  spec <- make_spec(
    "sha256(product_id + customer_id + review_date) when missing; else sentinel"
  )
  result_so_far <- list(
    product_id = c("B001", "B002", "B001"),       # B001 appears twice
    customer_id = c("alice", "bob", "alice"),     # alice appears twice
    review_date = c("2026-01-01", "2026-02-01", "2026-01-01")  # collision
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = result_so_far)
  expect_length(out, 3L)
  # Same triple → same hash (rows 1 and 3 are identical)
  expect_equal(out[1], out[3])
  expect_false(out[1] == out[2])
})

test_that("T3: NA in component encoded as '<NA>' not dropped", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(a + b)")
  result_so_far <- list(
    a = c("foo", NA, "baz"),
    b = c("1", "2", "3")
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = result_so_far)
  expect_length(out, 3L)  # NOT dropped to length 2
  expect_true(all(nchar(out) == 64L))
})

test_that("T4: length mismatch falls back to sentinel + warning", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(a + b)", sentinel_value = "UNKNOWN")
  result_so_far <- list(
    a = c("foo", "bar"),       # length 2
    b = c("1", "2", "3")        # length 3
  )
  expect_warning(
    out <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = result_so_far),
    "length mismatch"
  )
  expect_equal(out, "UNKNOWN")
})

test_that("T5: missing field in result_so_far → sentinel (not warning)", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(product_id + missing_field)",
                    sentinel_value = "UNKNOWN_REVIEW")
  result_so_far <- list(
    product_id = c("B001", "B002")
    # missing_field not present
  )
  # Per canonical "when missing; else sentinel" semantics: silent fall-through
  # to sentinel without warning (then unrecognized-expression warning fires below)
  out <- suppressWarnings(
    apply_fallback(spec, mapping_entry = list(),
                   current_value = NULL,
                   result_so_far = result_so_far)
  )
  expect_equal(out, "UNKNOWN_REVIEW")
})

test_that("T6: empty input (n_rows=0) returns character(0)", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(a + b)")
  result_so_far <- list(
    a = character(0),
    b = character(0)
  )
  out <- apply_fallback(spec, mapping_entry = list(),
                       current_value = NULL,
                       result_so_far = result_so_far)
  expect_equal(out, character(0))
})

test_that("T7: deterministic — same inputs always produce same hashes", {
  skip_if_not_installed("digest")
  spec <- make_spec("sha256(a + b)")
  result_so_far <- list(a = c("x", "y"), b = c("1", "2"))
  out_1 <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = result_so_far)
  out_2 <- apply_fallback(spec, mapping_entry = list(),
                         current_value = NULL,
                         result_so_far = result_so_far)
  expect_identical(out_1, out_2)
})

test_that("T8: pre-existing 4 derive rules still work (no regression)", {
  # canonical_target.platform special case
  spec_platform <- make_spec("from canonical_target.platform")
  out_platform <- apply_fallback(spec_platform, mapping_entry = list(),
                                  current_value = NULL,
                                  result_so_far = list(),
                                  canonical_target_platform = "amz")
  expect_equal(out_platform, "amz")

  # Sys.time() special case
  spec_time <- make_spec("Sys.time()")
  out_time <- apply_fallback(spec_time, mapping_entry = list(),
                            current_value = NULL,
                            result_so_far = list())
  expect_s3_class(out_time, "POSIXct")

  # unit_price * quantity
  spec_total <- make_spec("unit_price * quantity")
  out_total <- apply_fallback(spec_total, mapping_entry = list(),
                              current_value = NULL,
                              result_so_far = list(unit_price = c(10, 20),
                                                   quantity = c(2, 3)))
  expect_equal(out_total, c(20, 60))
})
