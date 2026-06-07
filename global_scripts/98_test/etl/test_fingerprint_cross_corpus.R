# Tests for fn_hash_prerawdata_schema cross-corpus fingerprint stability (#614)
#
# Per #614 issue body: bridge yaml fingerprints against ONE representative file,
# but caller contract instructs Sys.glob(N files) + dplyr::bind_rows. No test
# verified that single-file fingerprint represents the bind_rows-combined schema
# correctly.
#
# This test covers items 1 + 3 from #614:
#
#   F1: bind_rows of fixtures with consistent col_types → deterministic combined schema
#   F2: Single-file fingerprint matches combined fingerprint when caller uses stable col_types
#   F3: Without explicit col_types, sparse-column-flip across files produces DIFFERENT
#       fingerprints (catches broken-caller case)
#   F4: Empty corpus (0 files) edge case
#   F5: Single-file corpus = direct fingerprint
#   F6: Same prerawdata in different column order produces SAME fingerprint
#       (because hash_prerawdata_schema sorts pairs internally)
#   F7: Type variation (character vs logical) produces DIFFERENT fingerprints
#       (sparse-column-flip detection)
#
# Item 2 (per-bridge integration test loading all 14 existing bridges) is deferred —
# requires reading actual production bridge files + their source xlsx data, broader
# scope than this test file.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_fingerprint_cross_corpus.R')"

suppressPackageStartupMessages({
  library(testthat)
})

TEST_DIR <- if (!is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE))
} else {
  getwd()
}
HASH_PATH <- normalizePath(
  file.path(TEST_DIR, "..", "..",
            "05_etl_utils/glue/fn_hash_prerawdata_schema.R"),
  mustWork = FALSE
)

if (!file.exists(HASH_PATH)) {
  skip(paste("Cannot locate fn_hash_prerawdata_schema.R at", HASH_PATH))
}

source(HASH_PATH)

# Helper: synthesize prerawdata fingerprint inputs from data.frame
fp_of <- function(df) {
  hash_prerawdata_schema(
    column_names = colnames(df),
    column_types = vapply(df, function(x) class(x)[1], character(1))
  )
}

# Stable col_types reference (the caller-contract Gotcha #1 mitigation)
stable_types <- c(asin = "character", quantity = "numeric",
                  has_variant = "character")

# ---------------------------------------------------------------------------
# F1: bind_rows of consistent-typed fixtures → deterministic combined schema
# ---------------------------------------------------------------------------

test_that("F1: bind_rows of stable-typed fixtures preserves schema", {
  skip_if_not_installed("digest")

  file_a <- data.frame(
    asin = c("B001", "B002"),
    quantity = c(10, 20),
    has_variant = c("Y", "N"),
    stringsAsFactors = FALSE
  )
  file_b <- data.frame(
    asin = c("B003"),
    quantity = c(30),
    has_variant = c("Y"),
    stringsAsFactors = FALSE
  )

  # Per caller contract: rbind / bind_rows the corpus
  combined <- rbind(file_a, file_b)
  expect_equal(nrow(combined), 3L)
  expect_equal(colnames(combined), c("asin", "quantity", "has_variant"))

  fp_combined <- fp_of(combined)
  expect_match(fp_combined$value, "^[a-f0-9]{64}$")
})

# ---------------------------------------------------------------------------
# F2: Single-file fingerprint matches combined when col_types stable
# ---------------------------------------------------------------------------

test_that("F2: single-file FP matches combined FP under stable types", {
  skip_if_not_installed("digest")

  file_a <- data.frame(
    asin = c("B001", "B002"),
    quantity = c(10, 20),
    has_variant = c("Y", "N"),
    stringsAsFactors = FALSE
  )
  file_b <- data.frame(
    asin = c("B003"),
    quantity = c(30),
    has_variant = c("Y"),
    stringsAsFactors = FALSE
  )

  fp_single_a <- fp_of(file_a)
  fp_combined <- fp_of(rbind(file_a, file_b))

  # Both files have IDENTICAL schema (same names + same types) → fingerprints match
  expect_identical(fp_single_a$value, fp_combined$value)
})

# ---------------------------------------------------------------------------
# F3: Sparse-column-flip catches broken-caller case (no col_types)
# ---------------------------------------------------------------------------

test_that("F3: sparse-column-flip across files → different fingerprints", {
  skip_if_not_installed("digest")

  # File A: has_variant has values "Y"/"N" → readxl infers "character"
  file_a <- data.frame(
    asin = c("B001", "B002"),
    has_variant = c("Y", "N"),
    stringsAsFactors = FALSE
  )

  # File B: has_variant ALL NA → readxl heuristic infers "logical"
  # This is the canonical Gotcha #1 — sparse columns flip between files
  file_b <- data.frame(
    asin = c("B003"),
    has_variant = NA,    # logical type
    stringsAsFactors = FALSE
  )

  fp_a <- fp_of(file_a)
  fp_b <- fp_of(file_b)

  # Fingerprints DIFFER because has_variant types differ
  expect_false(identical(fp_a$value, fp_b$value),
               info = "Type variation should produce different fingerprints (sparse-column-flip detection)")

  # This is the SIGNAL for caller to use stable col_types
})

# ---------------------------------------------------------------------------
# F4: Empty corpus edge case
# ---------------------------------------------------------------------------

test_that("F4: 0-row data.frame still has schema, FP works", {
  skip_if_not_installed("digest")

  empty_with_schema <- data.frame(
    asin = character(0),
    quantity = numeric(0),
    has_variant = character(0),
    stringsAsFactors = FALSE
  )
  fp <- fp_of(empty_with_schema)
  expect_match(fp$value, "^[a-f0-9]{64}$")
})

test_that("F4b: data.frame with 0 columns errors per fn_hash contract", {
  expect_error(
    hash_prerawdata_schema(character(0), character(0)),
    "Empty schema"
  )
})

# ---------------------------------------------------------------------------
# F5: Single-file corpus = direct fingerprint (no bind_rows needed)
# ---------------------------------------------------------------------------

test_that("F5: single-file 'corpus' (1 file) = direct fingerprint", {
  skip_if_not_installed("digest")

  single <- data.frame(
    asin = c("B001"),
    quantity = c(10),
    stringsAsFactors = FALSE
  )
  fp_direct <- fp_of(single)
  fp_rbind <- fp_of(rbind(single))   # rbind of single is itself

  expect_identical(fp_direct$value, fp_rbind$value)
})

# ---------------------------------------------------------------------------
# F6: Column order independence (algorithm sorts internally)
# ---------------------------------------------------------------------------

test_that("F6: column order does not affect fingerprint (algorithm sorts)", {
  skip_if_not_installed("digest")

  # Same 3 columns, different orders
  fp_abc <- hash_prerawdata_schema(
    c("asin", "brand", "category"),
    c("character", "character", "character")
  )
  fp_cab <- hash_prerawdata_schema(
    c("category", "asin", "brand"),
    c("character", "character", "character")
  )
  fp_bca <- hash_prerawdata_schema(
    c("brand", "category", "asin"),
    c("character", "character", "character")
  )

  expect_identical(fp_abc$value, fp_cab$value)
  expect_identical(fp_abc$value, fp_bca$value)
})

# ---------------------------------------------------------------------------
# F7: Type variation produces different fingerprints (sparse-flip core)
# ---------------------------------------------------------------------------

test_that("F7: same column name + different type → different FP", {
  skip_if_not_installed("digest")

  fp_chr <- hash_prerawdata_schema(
    c("flag"), c("character")
  )
  fp_lgl <- hash_prerawdata_schema(
    c("flag"), c("logical")
  )
  fp_num <- hash_prerawdata_schema(
    c("flag"), c("numeric")
  )

  expect_false(identical(fp_chr$value, fp_lgl$value))
  expect_false(identical(fp_chr$value, fp_num$value))
  expect_false(identical(fp_lgl$value, fp_num$value))
})

# ---------------------------------------------------------------------------
# Caller contract documentation reinforcement (item 3 of #614)
# ---------------------------------------------------------------------------

test_that("CALLER_CONTRACT_DOC: stable col_types is mandatory not advisory", {
  # This test serves as executable documentation for the caller contract.
  # When implementing a glue-bridge caller, the col_types reference dict
  # MUST be set explicitly OR the corpus fingerprint will drift.
  #
  # Reference: /glue-bridge skill SKILL.md Gotcha #1 (fingerprint instability
  # from partial reads / sparse-column-flip).
  #
  # The test below documents the failure mode: same actual data, different
  # type inference → different fingerprints → drift detected.

  # Simulating "broken caller" — type inferred from data without explicit hint
  broken_a <- data.frame(flag = c("Y", "N"), stringsAsFactors = FALSE)  # character
  broken_b <- data.frame(flag = NA, stringsAsFactors = FALSE)            # logical

  fp_a <- fp_of(broken_a)
  fp_b <- fp_of(broken_b)
  expect_false(identical(fp_a$value, fp_b$value))

  # Simulating "good caller" — explicit char coercion before fingerprint
  good_a <- broken_a
  good_b <- transform(broken_b, flag = as.character(flag))  # forces character

  fp_good_a <- fp_of(good_a)
  fp_good_b <- fp_of(good_b)
  expect_identical(fp_good_a$value, fp_good_b$value,
                   info = "Stable col_types (caller-coerced to character) yields stable FP")
})
