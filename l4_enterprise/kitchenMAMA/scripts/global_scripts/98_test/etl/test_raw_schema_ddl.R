# Tests for raw_schema codegen output (#489 Phase 3, Tasks 3.4 + 3.5 + 3.6)
#
# Three scenarios verified:
#   3.4: Generated DDL is engine-enforceable
#        — `CREATE TABLE FROM` against fresh DuckDB succeeds for all generated
#          .sql files, no syntax errors, NOT NULL + CHECK constraints present.
#   3.5: Build is reproducible
#        — Running _build.R twice against unchanged _authoring/ produces
#          byte-identical output (no diff).
#   3.6: ASIN field DDL has pattern check
#        — _generated/platforms/amz/products.sql contains the canonical ASIN
#          regex CHECK constraint.
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_raw_schema_ddl.R')"
# or via the project Makefile target.

suppressPackageStartupMessages({
  library(testthat)
  library(yaml)
  library(DBI)
  library(duckdb)
})

# Resolve repo paths regardless of cwd
this_file <- normalizePath(sys.frame(1)$ofile %||% "test_raw_schema_ddl.R",
                           mustWork = FALSE)
if (!file.exists(this_file)) {
  candidates <- c(
    "shared/global_scripts/98_test/etl/test_raw_schema_ddl.R",
    "98_test/etl/test_raw_schema_ddl.R",
    file.path(getwd(), "test_raw_schema_ddl.R")
  )
  this_file <- normalizePath(candidates[file.exists(candidates)][1],
                             mustWork = TRUE)
}
test_dir   <- dirname(this_file)
gs_root    <- normalizePath(file.path(test_dir, "..", ".."))
schema_dir <- file.path(gs_root, "01_db", "raw_schema")
gen_dir    <- file.path(schema_dir, "_generated")
build_R    <- file.path(schema_dir, "_build.R")

test_that("3.4: every generated .sql parses + creates table in fresh DuckDB", {
  sql_files <- list.files(gen_dir, pattern = "\\.sql$",
                          recursive = TRUE, full.names = TRUE)
  expect_gt(length(sql_files), 0,
            label = "_generated/ contains .sql files")

  for (path in sql_files) {
    con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
    sql <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_silent({
      DBI::dbSendStatement(con, sql) |> DBI::dbClearResult()
    })
    DBI::dbDisconnect(con, shutdown = TRUE)
  }
})

test_that("3.4: every generated .sql contains at least one NOT NULL + one CHECK", {
  sql_files <- list.files(gen_dir, pattern = "\\.sql$",
                          recursive = TRUE, full.names = TRUE)
  for (path in sql_files) {
    sql <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_match(sql, "NOT NULL", fixed = TRUE,
                 info = sprintf("File: %s", basename(path)))
    expect_match(sql, "CHECK", fixed = TRUE,
                 info = sprintf("File: %s", basename(path)))
  }
})

test_that("3.5: _build.R is reproducible (running twice yields no diff)", {
  skip_if_not(file.exists(build_R), "_build.R missing")
  # Snapshot all .sql contents
  sql_files <- list.files(gen_dir, pattern = "\\.sql$",
                          recursive = TRUE, full.names = TRUE)
  before <- vapply(sql_files,
                   function(p) digest::digest(readLines(p, warn = FALSE)),
                   character(1), USE.NAMES = TRUE)
  # Re-run the build
  result <- system2("Rscript", args = c(build_R),
                    stdout = TRUE, stderr = TRUE)
  expect_equal(attr(result, "status") %||% 0L, 0L,
               label = "_build.R re-run exit code")
  sql_files2 <- list.files(gen_dir, pattern = "\\.sql$",
                           recursive = TRUE, full.names = TRUE)
  after <- vapply(sql_files2,
                  function(p) digest::digest(readLines(p, warn = FALSE)),
                  character(1), USE.NAMES = TRUE)
  expect_equal(sort(names(before)), sort(names(after)),
               label = "same set of files")
  expect_equal(before[sort(names(before))], after[sort(names(after))],
               label = "byte-identical content per file")
})

test_that("3.6: amz products DDL contains the ASIN regex CHECK", {
  amz_products <- file.path(gen_dir, "platforms", "amz", "products.sql")
  skip_if_not(file.exists(amz_products),
              sprintf("Expected %s to exist after _build.R", amz_products))
  sql <- paste(readLines(amz_products, warn = FALSE), collapse = "\n")
  # Required: amz_asin column has the canonical ASIN pattern
  expect_match(sql, "amz_asin", fixed = TRUE)
  expect_match(sql, "B0\\[A-Z0-9\\]\\{8\\}",
               info = "ASIN regex pattern present in amz_asin CHECK")
})

test_that("3.6: core sales DDL constrains product_id with regex", {
  core_sales <- file.path(gen_dir, "core", "sales.sql")
  skip_if_not(file.exists(core_sales))
  sql <- paste(readLines(core_sales, warn = FALSE), collapse = "\n")
  expect_match(sql, "product_id ~ '\\^\\[A-Za-z0-9", fixed = FALSE,
               info = "product_id has alphanumeric pattern check")
})

test_that("3.6: official_website is allowed by platform_id CHECK", {
  ow_sales <- file.path(gen_dir, "platforms", "official_website", "sales.sql")
  skip_if_not(file.exists(ow_sales))
  sql <- paste(readLines(ow_sales, warn = FALSE), collapse = "\n")
  expect_match(sql, "official_website", fixed = TRUE,
               info = "official_website appears in platform_id CHECK")
})

`%||%` <- function(a, b) if (is.null(a)) b else a
