# Tests for fn_glue_bridge interpreter (#489 Phase 4 Task 4.8)
#
# Scenarios:
#   - Bridge function exists and accepts (company, platform, source) parameters
#   - Bridge applies cached yaml mapping (column rename + coercion + fallback)
#   - DDL enforcement on INSERT (mapped data passes engine CHECK constraints)
#   - Drift detection halts execution with actionable error message
#   - Reviewer guard rejects unsigned bridges
#
# Run via:
#   Rscript -e "testthat::test_file('shared/global_scripts/98_test/etl/test_fn_glue_bridge.R')"

suppressPackageStartupMessages({
  library(testthat)
  library(yaml)
  library(DBI)
  library(duckdb)
  library(digest)
})

# Resolve repo paths
this_file <- normalizePath(sys.frame(1)$ofile %||% "test_fn_glue_bridge.R",
                           mustWork = FALSE)
if (!file.exists(this_file)) {
  candidates <- c(
    "shared/global_scripts/98_test/etl/test_fn_glue_bridge.R",
    "98_test/etl/test_fn_glue_bridge.R"
  )
  this_file <- normalizePath(candidates[file.exists(candidates)][1],
                             mustWork = TRUE)
}
gs_root  <- normalizePath(file.path(dirname(this_file), "..", ".."))
glue_dir <- file.path(gs_root, "05_etl_utils", "glue")

source(file.path(glue_dir, "fn_hash_prerawdata_schema.R"))
source(file.path(glue_dir, "fn_apply_mapping.R"))
source(file.path(glue_dir, "fn_validate_against_schema.R"))
source(file.path(glue_dir, "fn_glue_bridge.R"))

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------- Helpers to build a self-contained test fixture ----------

create_test_workspace <- function() {
  td <- tempfile("glue_test_")
  dir.create(td, recursive = TRUE)
  bridges_dir <- file.path(td, "bridges", "TESTCO", "amz")
  dir.create(bridges_dir, recursive = TRUE)
  # Minimal canonical schema for sales (subset)
  schema <- list(
    sales = list(
      description = "Test sales schema",
      table_pattern = "df_{platform}_sales___raw",
      version = "test",
      required_fields = list(
        order_id = list(
          type = "VARCHAR", required = TRUE,
          aliases = list("order id", "Order ID"),
          fallback = list(rule = "sentinel", value = "UNKNOWN_ORDER"),
          constraints = list("NOT NULL", "LENGTH > 0")
        ),
        product_id = list(
          type = "VARCHAR", required = TRUE,
          aliases = list("ASIN", "asin"),
          pattern = "^B0[A-Z0-9]{8}$",
          fallback = list(rule = "sentinel", value = "UNKNOWN_PRODUCT"),
          constraints = list("NOT NULL", "LENGTH > 0")
        ),
        quantity = list(
          type = "INTEGER", required = TRUE,
          fallback = list(rule = "use_value", value = 1),
          constraints = list("NOT NULL", ">= 1")
        ),
        platform_id = list(
          type = "VARCHAR", required = TRUE,
          fallback = list(rule = "derive_from",
                          derive = "from canonical_target.platform"),
          constraints = list("NOT NULL")
        )
      )
    )
  )
  schema_path <- file.path(td, "core_schemas.yaml")
  yaml::write_yaml(schema, schema_path)

  list(
    workspace = td,
    bridges_root = file.path(td, "bridges"),
    bridges_dir = bridges_dir,
    schema_path = schema_path
  )
}

create_valid_bridge <- function(fix, fingerprint_value) {
  bridge <- list(
    prerawdata_source = list(
      company = "TESTCO", platform = "amz", source_type = "csv",
      schema_fingerprint = list(algorithm = "sha256",
                                value = fingerprint_value)
    ),
    canonical_target = list(
      datatype = "sales", platform = "amz",
      table = "df_amz_sales___raw",
      schema_yaml_path = fix$schema_path
    ),
    column_mapping = list(
      order_id = list(from_column = "Amazon Order ID"),
      product_id = list(from_column = "ASIN"),
      quantity = list(from_column = "qty"),
      platform_id = list(apply_fallback = TRUE)
    ),
    ignored_columns = list("buyer_email_redacted"),
    generated_at = "2026-04-27T15:00:00Z",
    generated_by = "test fixture",
    reviewed_by = "test_human (fixture)"
  )
  path <- file.path(fix$bridges_dir, "sales.bridge.yaml")
  yaml::write_yaml(bridge, path)
  path
}

# ---------- Tests ----------

test_that("4.2: fn_glue_bridge exists with the documented signature", {
  expect_true(exists("fn_glue_bridge"))
  args <- names(formals(fn_glue_bridge))
  expect_true(all(c("company", "platform", "source",
                    "prerawdata", "target_con") %in% args))
})

test_that("4.4: schema fingerprint is deterministic", {
  fp1 <- hash_prerawdata_schema(c("a", "b"), c("character", "integer"))
  fp2 <- hash_prerawdata_schema(c("b", "a"), c("integer", "character"))
  expect_equal(fp1$value, fp2$value,
               label = "Sorted, so order-invariant")
  expect_equal(fp1$algorithm, "sha256")
})

test_that("4.4: schema fingerprint changes on column add", {
  fp1 <- hash_prerawdata_schema(c("a"), c("character"))
  fp2 <- hash_prerawdata_schema(c("a", "b"), c("character", "integer"))
  expect_false(identical(fp1$value, fp2$value))
})

test_that("4.4: drift detection halts via actionable error message", {
  fix <- create_test_workspace()
  on.exit(unlink(fix$workspace, recursive = TRUE), add = TRUE)
  prerawdata <- data.frame(
    `Amazon Order ID` = c("123-1234567-1234567"),
    ASIN = c("B0ABCDEFGH"),
    qty = c(2L),
    buyer_email_redacted = c("anon@x"),
    check.names = FALSE
  )
  src_cols <- colnames(prerawdata)
  src_types <- vapply(prerawdata, function(x) class(x)[1], character(1))
  correct_fp <- hash_prerawdata_schema(src_cols, src_types)$value

  # Bridge with WRONG fingerprint (simulate drift)
  bridge_path <- create_valid_bridge(fix, fingerprint_value = "wrong_hash_xyz")

  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, paste(
    "CREATE TABLE df_amz_sales___raw (",
    "order_id VARCHAR NOT NULL,",
    "product_id VARCHAR NOT NULL,",
    "quantity INTEGER NOT NULL,",
    "platform_id VARCHAR NOT NULL)"))

  err <- tryCatch(
    fn_glue_bridge(company = "TESTCO", platform = "amz", source = "sales",
                   prerawdata = prerawdata, target_con = con,
                   bridges_root = fix$bridges_root),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "Schema drift detected", fixed = TRUE)
  expect_match(err, "wrong_hash_xyz", fixed = TRUE)
  expect_match(err, "regenerate the bridge yaml", fixed = TRUE,
               info = "Error message includes actionable next step")
})

test_that("4.2 + 4.3: bridge applies cached yaml mapping correctly", {
  fix <- create_test_workspace()
  on.exit(unlink(fix$workspace, recursive = TRUE), add = TRUE)
  prerawdata <- data.frame(
    `Amazon Order ID` = c("123-1234567-1234567", "456-1234567-1234567"),
    ASIN = c("B0ABCDEFGH", "B0XYZ12345"),
    qty = c(2L, 1L),
    buyer_email_redacted = c("anon1@x", "anon2@x"),
    check.names = FALSE
  )
  src_cols <- colnames(prerawdata)
  src_types <- vapply(prerawdata, function(x) class(x)[1], character(1))
  correct_fp <- hash_prerawdata_schema(src_cols, src_types)$value
  create_valid_bridge(fix, fingerprint_value = correct_fp)

  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, paste(
    "CREATE TABLE df_amz_sales___raw (",
    "order_id VARCHAR NOT NULL,",
    "product_id VARCHAR NOT NULL,",
    "quantity INTEGER NOT NULL,",
    "platform_id VARCHAR NOT NULL)"))

  result <- fn_glue_bridge(
    company = "TESTCO", platform = "amz", source = "sales",
    prerawdata = prerawdata, target_con = con,
    bridges_root = fix$bridges_root)

  expect_equal(result$n_input_rows, 2)
  expect_equal(result$n_output_rows, 2)
  expect_equal(result$n_errors, 0)

  written <- DBI::dbGetQuery(con,
    "SELECT * FROM df_amz_sales___raw ORDER BY order_id")
  expect_equal(nrow(written), 2)
  expect_equal(written$order_id,
               c("123-1234567-1234567", "456-1234567-1234567"))
  expect_equal(written$product_id, c("B0ABCDEFGH", "B0XYZ12345"))
  expect_equal(written$quantity, c(2L, 1L))
  expect_equal(unique(written$platform_id), "amz",
               info = "platform_id derived from canonical_target.platform")
})

test_that("Reviewer guard rejects unsigned bridges", {
  fix <- create_test_workspace()
  on.exit(unlink(fix$workspace, recursive = TRUE), add = TRUE)
  prerawdata <- data.frame(
    `Amazon Order ID` = c("123-1234567-1234567"),
    ASIN = c("B0ABCDEFGH"),
    qty = c(2L),
    buyer_email_redacted = c("anon@x"),
    check.names = FALSE
  )
  fp <- hash_prerawdata_schema(colnames(prerawdata),
                                vapply(prerawdata, function(x) class(x)[1],
                                       character(1)))$value
  # Build a bridge with reviewed_by = "REQUIRES_HUMAN_REVIEW"
  bridge <- list(
    prerawdata_source = list(
      company = "TESTCO", platform = "amz", source_type = "csv",
      schema_fingerprint = list(algorithm = "sha256", value = fp)),
    canonical_target = list(
      datatype = "sales", platform = "amz",
      table = "df_amz_sales___raw",
      schema_yaml_path = fix$schema_path),
    column_mapping = list(),
    generated_by = "test", generated_at = "2026-04-27T00:00:00Z",
    reviewed_by = "REQUIRES_HUMAN_REVIEW"
  )
  yaml::write_yaml(bridge,
                   file.path(fix$bridges_dir, "sales.bridge.yaml"))

  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  err <- tryCatch(
    fn_glue_bridge(company = "TESTCO", platform = "amz", source = "sales",
                   prerawdata = prerawdata, target_con = con,
                   bridges_root = fix$bridges_root),
    error = function(e) conditionMessage(e)
  )
  # MP102 v1.3 (per spectra change `glue-bridge-self-converging-review` / #500):
  # placeholder rejection still fires; wording updated to reference v1.3 + glue-bridge skill.
  expect_match(err, "reviewer identifier is required", fixed = TRUE)
  expect_match(err, "MP102 v1.3", fixed = TRUE)
})

test_that("Production runtime path contains no LLM calls (audit grep)", {
  # Read the runtime interpreter source and verify no LLM helper is sourced
  glue_files <- list.files(glue_dir, pattern = "\\.R$", full.names = TRUE)
  runtime_files <- glue_files[!grepl("fn_call_llm_for_mapping",
                                      glue_files)]
  for (f in runtime_files) {
    lines <- readLines(f, warn = FALSE)
    # Strip comments (everything from \ to end-of-line) before checking
    code_only <- sub("#.*$", "", lines)
    code_only <- code_only[nchar(trimws(code_only)) > 0]
    code <- paste(code_only, collapse = "\n")
    expect_false(grepl("fn_call_llm_for_mapping", code, fixed = TRUE),
                 label = sprintf("%s does not source LLM helper", basename(f)))
    expect_false(grepl("eval\\s*\\(\\s*parse", code),
                 label = sprintf("%s contains no eval(parse(...))", basename(f)))
  }
})

# ---------- Phase 5.4: drift-detection demo on real PoC bridge ----------

test_that("5.4: PoC bridge halts with actionable error on simulated drift", {
  skip_if_not(requireNamespace("readxl", quietly = TRUE),
              "readxl not available")
  qef_xlsx <- file.path(
    "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech",
    "l4_enterprise/QEF_DESIGN/data/local_data/rawdata_QEF_DESIGN",
    "amazon_sales/2024-1/2024-01.xlsx")
  skip_if_not(file.exists(qef_xlsx),
              "QEF amz sample xlsx not present in this environment")

  bridges_root <- file.path(gs_root, "01_db", "raw_schema", "_authoring",
                            "bridges")
  poc_bridge <- file.path(bridges_root, "QEF_DESIGN", "amz",
                          "sales.bridge.yaml")
  skip_if_not(file.exists(poc_bridge), "PoC bridge yaml not present")

  prerawdata <- readxl::read_excel(qef_xlsx)

  # Simulate drift: add a fake column that the bridge yaml doesn't know
  # about. The fingerprint is sensitive to column-set changes.
  prerawdata$drift_simulated_column <- "x"

  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ddl_file <- file.path(gs_root, "01_db", "raw_schema", "_generated",
                        "platforms", "amz", "sales.sql")
  ddl <- paste(readLines(ddl_file, warn = FALSE), collapse = "\n")
  DBI::dbExecute(con, ddl)

  err <- tryCatch(
    fn_glue_bridge(company = "QEF_DESIGN", platform = "amz",
                   source = "sales", prerawdata = prerawdata,
                   target_con = con, bridges_root = bridges_root),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "Schema drift detected", fixed = TRUE)
  expect_match(err, "regenerate the bridge yaml", fixed = TRUE)
})

# ---------- MP160 exhaustive-enumeration regression tests ----------
#
# These tests exercise the MP160 check inside validate_bridge_yaml.R
# (added in spectra change `mp160-ai-authoring-completeness`, #497).
#
# We invoke the validator via Rscript and inspect exit code + stdout
# rather than sourcing it (the validator has its own quit() flow).
#
# Three scenarios:
#   (a) Full-enumeration bridge          -> exit 0, no MP160 violation
#   (b) Bridge omitting one source col    -> exit 1, MP160 CRITICAL fires
#   (c) wip/ bridge missing source cols   -> exit 0, MP160 skipped via INFO

run_validator <- function(bridge_path) {
  validator <- file.path(gs_root, "00_principles", ".claude", "skills",
                         "glue-bridge", "scripts", "validate_bridge_yaml.R")
  out_file <- tempfile()
  rc <- suppressWarnings(system2(
    "Rscript",
    args = c(shQuote(validator), shQuote(bridge_path)),
    stdout = out_file, stderr = out_file
  ))
  out <- readLines(out_file, warn = FALSE)
  unlink(out_file)
  list(exit = rc, output = paste(out, collapse = "\n"))
}

test_that("MP160 (a): full-enumeration PoC bridge passes exhaustive check", {
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml not available")
  qef_xlsx <- file.path(
    "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech",
    "l4_enterprise/QEF_DESIGN/data/local_data/rawdata_QEF_DESIGN",
    "amazon_sales/2024-1/2024-01.xlsx")
  skip_if_not(file.exists(qef_xlsx),
              "QEF amz sample xlsx not present in this environment")

  poc_bridge <- file.path(gs_root, "01_db", "raw_schema", "_authoring",
                          "bridges", "QEF_DESIGN", "amz", "sales.bridge.yaml")
  skip_if_not(file.exists(poc_bridge), "PoC bridge yaml not present")

  res <- run_validator(poc_bridge)
  # Validator should exit 0 (PASSED). No CRITICAL "MP160 violation" line.
  expect_equal(res$exit, 0L,
               label = "PoC bridge with full ignored_columns passes validator")
  expect_false(grepl("MP160 violation", res$output, fixed = TRUE),
               label = "no MP160 violation in PoC bridge output")
})

test_that("MP160 (b): bridge omitting source col triggers CRITICAL", {
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml not available")
  qef_xlsx <- file.path(
    "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech",
    "l4_enterprise/QEF_DESIGN/data/local_data/rawdata_QEF_DESIGN",
    "amazon_sales/2024-1/2024-01.xlsx")
  skip_if_not(file.exists(qef_xlsx),
              "QEF amz sample xlsx not present in this environment")

  poc_bridge <- file.path(gs_root, "01_db", "raw_schema", "_authoring",
                          "bridges", "QEF_DESIGN", "amz", "sales.bridge.yaml")
  skip_if_not(file.exists(poc_bridge), "PoC bridge yaml not present")

  # Build a sabotaged copy: drop one entry from ignored_columns
  doc <- yaml::read_yaml(poc_bridge)
  expect_true(length(doc$ignored_columns) > 0L,
              info = "PoC bridge must have ignored_columns to sabotage")
  # Drop the first ignored entry; that source col is now neither mapped
  # nor ignored, so MP160 SHALL fire.
  dropped <- doc$ignored_columns[[1L]]
  doc$ignored_columns <- doc$ignored_columns[-1L]

  td <- tempfile("mp160_neg_")
  dir.create(td, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  sabotaged <- file.path(td, "sales.bridge.yaml")
  yaml::write_yaml(doc, sabotaged)

  res <- run_validator(sabotaged)
  # Expect failure (exit 1) and message naming the dropped column.
  expect_equal(res$exit, 1L,
               label = "sabotaged bridge fails validator with exit 1")
  expect_true(grepl("MP160 violation", res$output, fixed = TRUE),
              info = "MP160 CRITICAL line present in output")
  expect_true(grepl(dropped, res$output, fixed = TRUE),
              info = sprintf("dropped column '%s' named in violation", dropped))
})

test_that("MP160 (c): bridge in wip/ skips MP160 enforcement", {
  skip_if_not(requireNamespace("yaml", quietly = TRUE), "yaml not available")
  poc_bridge <- file.path(gs_root, "01_db", "raw_schema", "_authoring",
                          "bridges", "QEF_DESIGN", "amz", "sales.bridge.yaml")
  skip_if_not(file.exists(poc_bridge), "PoC bridge yaml not present")

  doc <- yaml::read_yaml(poc_bridge)
  # Sabotage exactly the same way as case (b)
  doc$ignored_columns <- doc$ignored_columns[-1L]

  # Place the sabotaged bridge under a /wip/ path segment.
  td <- tempfile("mp160_wip_")
  wip_dir <- file.path(td, "bridges", "QEF_DESIGN", "wip", "amz")
  dir.create(wip_dir, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  wip_bridge <- file.path(wip_dir, "sales.bridge.yaml")
  yaml::write_yaml(doc, wip_bridge)

  res <- run_validator(wip_bridge)
  # Validator's other top-level guards (reviewed_by, fingerprint) must
  # still hold, but MP160 SHALL emit INFO-level skip and not block.
  expect_false(grepl("MP160 violation", res$output, fixed = TRUE),
               label = "no MP160 violation in wip/ output")
  expect_true(grepl("wip/ bridge", res$output, fixed = TRUE),
              info = "MP160 INFO line names wip/ exemption")
})
