# Tests for detect_na_literals() and build_value_map_for_col() helpers in
# gen_product_attribute_bridges.R (#502 scope 2).
#
# Per spectra change qef-attribute-bridge-types-and-na-handling Tasks 2.1/2.2:
# Generator SHALL detect cell-level NA literals (`"NA"`, `"N/A"`, `"未填"`)
# and trimmed-empty-mixed columns, then emit appropriate value_map.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_detect_na_literals.R')"

suppressPackageStartupMessages({
  library(testthat)
})

GEN_PATH <- normalizePath(
  file.path(
    if (!is.null(sys.frame(1)$ofile)) {
      dirname(sys.frame(1)$ofile)
    } else {
      getwd()
    },
    "..", "..",
    "01_db/raw_schema/_authoring/companies/QEF_DESIGN/gen_product_attribute_bridges.R"
  ),
  mustWork = FALSE
)

# Source helpers only; gen file's main body relies on hash_fn_path and CSVs that
# may not exist in the test sandbox. We'll source it inside a wrapper that
# stops execution after definitions.

source_helpers_only <- function(gen_path) {
  if (!file.exists(gen_path)) stop("generator not found: ", gen_path)
  txt <- readLines(gen_path, warn = FALSE)
  # Read everything up to (but not including) the first non-helper top-level
  # statement. We rely on a sentinel comment in the generator: "# ----- end of
  # helpers -----". If absent, fall back to sourcing in a tryCatch.
  end_marker <- grep("^# -+ end of helpers -+", txt)
  if (length(end_marker) == 0) {
    # Fall back: source whole file inside tryCatch (errors after helpers don't
    # invalidate the helper definitions if defined globally before the error).
    tryCatch(source(gen_path, local = FALSE),
             error = function(e) NULL)
  } else {
    tmpf <- tempfile(fileext = ".R")
    writeLines(txt[seq_len(end_marker[1] - 1)], tmpf)
    source(tmpf, local = FALSE)
    file.remove(tmpf)
  }
}

context("detect_na_literals + build_value_map_for_col")

test_that("Test 1: detect_na_literals returns FALSE for pure non-NA values", {
  source_helpers_only(GEN_PATH)
  expect_true(exists("detect_na_literals"),
              info = paste("Helper not found in", GEN_PATH))
  expect_false(detect_na_literals(c("0", "1")),
               info = "binary 0/1 with no NA literal SHALL not trigger detection")
  expect_false(detect_na_literals(c("Silicone", "TPR", "TR90")),
               info = "non-NA categorical values SHALL not trigger detection")
})

test_that("Test 2: detect_na_literals returns TRUE for canonical NA literals", {
  source_helpers_only(GEN_PATH)
  expect_true(detect_na_literals(c("0", "1", "NA")),
              info = "value containing 'NA' SHALL trigger detection")
  expect_true(detect_na_literals(c("Silicone", "N/A", "TR90")),
              info = "value containing 'N/A' SHALL trigger detection")
  expect_true(detect_na_literals(c("有", "未填", "無")),
              info = "value containing '未填' SHALL trigger detection")
})

test_that("Test 3: detect_na_literals trimmed-empty exception", {
  source_helpers_only(GEN_PATH)
  # Trimmed empty MIXED with at least one non-empty non-NA literal → TRUE
  expect_true(detect_na_literals(c("0", "1", "")),
              info = "trimmed empty mixed with real values SHALL be treated as NA")
  # Fully empty column (every value is empty/NA) → FALSE (handled by ignored_columns)
  expect_false(detect_na_literals(c("", "", "")),
               info = "fully-empty column SHALL NOT trigger value_map detection (handled separately)")
})

test_that("Test 4: detect_na_literals case-sensitivity", {
  source_helpers_only(GEN_PATH)
  expect_false(detect_na_literals(c("0", "1", "na")),
               info = "lowercase 'na' SHALL NOT trigger detection (case-sensitive on canonical literals)")
  expect_false(detect_na_literals(c("0", "1", "n/a")),
               info = "lowercase 'n/a' SHALL NOT trigger detection")
})

test_that("Test 5: build_value_map_for_col returns NULL when no NA detected", {
  source_helpers_only(GEN_PATH)
  expect_true(exists("build_value_map_for_col"),
              info = paste("Helper not found in", GEN_PATH))
  expect_null(build_value_map_for_col(c("0", "1")),
              info = "no NA literal -> returns NULL (no value_map emit)")
  expect_null(build_value_map_for_col(c("Silicone", "TPR")),
              info = "categorical without NA -> NULL")
})

test_that("Test 6: build_value_map_for_col returns named list when NA present", {
  source_helpers_only(GEN_PATH)
  res1 <- build_value_map_for_col(c("0", "1", "NA"))
  expect_type(res1, "list")
  expect_true("NA" %in% names(res1), info = "result SHALL key on detected NA literal")
  expect_null(res1[["NA"]], info = "NA literal SHALL map to NULL (YAML null)")

  # Multiple NA variants - each appears as its own key
  res2 <- build_value_map_for_col(c("Silicone", "NA", "N/A"))
  expect_setequal(names(res2), c("NA", "N/A"))
  expect_null(res2[["NA"]])
  expect_null(res2[["N/A"]])
})

test_that("Test 7: build_value_map_for_col respects trimmed-empty exception", {
  source_helpers_only(GEN_PATH)
  # Mixed empty + real → emit value_map for empty literal
  res <- build_value_map_for_col(c("0", "1", ""))
  expect_type(res, "list")
  expect_true("" %in% names(res),
              info = "trimmed empty mixed with real values SHALL be in value_map")
  expect_null(res[[""]])

  # Fully empty → NULL (no value_map; handled by ignored_columns / apply_fallback)
  expect_null(build_value_map_for_col(c("", "", "")),
              info = "fully empty column -> NULL")
})

test_that("Test 8: helpers are pure (do not modify input)", {
  source_helpers_only(GEN_PATH)
  inp <- c("0", "1", "NA")
  inp_copy <- inp
  detect_na_literals(inp)
  build_value_map_for_col(inp)
  expect_identical(inp, inp_copy,
                   info = "helpers SHALL NOT mutate input vector")
})
