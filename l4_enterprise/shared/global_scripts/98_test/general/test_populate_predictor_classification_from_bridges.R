#!/usr/bin/env Rscript

# Test: populate_predictor_classification_from_bridges() bridge-yaml-driven populate
#
# Spec coverage:
#   - predictor-type-metadata-table > "Producer ETL enforces schema at table
#     creation" (populate phase)
#   - predictor-type-source-emit > "Source provenance SHALL be the sole driver
#     of predictor_type assignment" (bridge yaml prefix encoding IS provenance)
#   - "predictor classification emit SHALL be idempotent"
#
# TDD: Written before implementation. Initial run should FAIL (RED).
#
# Refs #716, design.md Refinement 1+2

suppressPackageStartupMessages({
  library(testthat)
  library(DBI)
  library(duckdb)
  library(yaml)
  library(dplyr)
  library(dbplyr)
})

# DM_R023-compliant helpers: use tbl2-style instead of raw dbGetQuery
get_type_by_name <- function(con, name) {
  res <- tbl(con, "df_predictor_classification") %>%
    filter(column_name == !!name) %>%
    select(predictor_type) %>%
    collect()
  if (nrow(res) == 0) NA_character_ else res$predictor_type[1]
}
count_rows <- function(con) {
  tbl(con, "df_predictor_classification") %>%
    summarise(n = n()) %>% collect() %>% pull(n)
}
distinct_sources <- function(con) {
  tbl(con, "df_predictor_classification") %>%
    select(source) %>% distinct() %>% collect() %>% pull(source)
}
dup_rows <- function(con) {
  tbl(con, "df_predictor_classification") %>%
    group_by(platform, column_name) %>%
    summarise(cnt = n(), .groups = "drop") %>%
    filter(cnt > 1) %>% collect()
}
count_skipped <- function(con, target_name) {
  tbl(con, "df_predictor_classification") %>%
    filter(column_name == !!target_name) %>%
    summarise(n = n()) %>% collect() %>% pull(n)
}

# ---------------------------------------------------------------------------
# Locate fn_populate_predictor_classification_from_bridges.R
# ---------------------------------------------------------------------------

get_script_path <- function() {
  cargs <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cargs, value = TRUE)
  if (length(file_arg) > 0) return(sub("^--file=", "", file_arg[1]))
  if (!is.null(sys.frames()[[1]]$ofile)) return(sys.frames()[[1]]$ofile)
  NA_character_
}

this_file <- tryCatch(
  normalizePath(get_script_path(), mustWork = FALSE),
  error = function(e) NA_character_
)

if (!is.na(this_file) && file.exists(this_file)) {
  utils_dir <- normalizePath(
    file.path(dirname(this_file), "..", "..", "04_utils"),
    mustWork = FALSE
  )
} else {
  utils_dir <- "shared/global_scripts/04_utils"
}

helper_path <- file.path(utils_dir, "fn_populate_predictor_classification_from_bridges.R")
schema_path <- normalizePath(
  file.path(utils_dir, "..", "01_db/raw_schema/_authoring/r_definitions/SCHEMA_006_predictor_classification.R"),
  mustWork = FALSE
)

if (!file.exists(helper_path)) {
  cat("\n[RED] fn_populate_predictor_classification_from_bridges.R does not exist yet.\n")
  cat("       Expected path: ", helper_path, "\n", sep = "")
  cat("       Run again after implementation.\n")
  quit(status = 1)
}
source(helper_path)

if (!is.function(populate_predictor_classification_from_bridges)) {
  cat("\n[RED] populate_predictor_classification_from_bridges not exported.\n")
  quit(status = 1)
}
if (!is.function(derive_predictor_type_from_canonical_name)) {
  cat("\n[RED] derive_predictor_type_from_canonical_name helper not exported.\n")
  quit(status = 1)
}

# ---------------------------------------------------------------------------
# Test: derive_predictor_type_from_canonical_name prefix rules
# ---------------------------------------------------------------------------

test_that("derive: rating_* prefix -> comment_attribute", {
  expect_equal(derive_predictor_type_from_canonical_name("rating_no_distortion"), "comment_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("rating_comfortable_wear"), "comment_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("rating_durability"), "comment_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("rating_clear_vision"), "comment_attribute")
})

test_that("derive: review_rating + review_count -> comment_attribute", {
  expect_equal(derive_predictor_type_from_canonical_name("review_rating"), "comment_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("review_count"), "comment_attribute")
})

test_that("derive: factual product spec prefixes -> product_attribute", {
  expect_equal(derive_predictor_type_from_canonical_name("feature_polarized"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("protection_uv"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("dimension_frame_width"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("color_lens"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("material_frame"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("accessory_lens_cloth"), "product_attribute")
})

test_that("derive: use-case prefixes -> product_attribute (conservative per Refinement 3)", {
  expect_equal(derive_predictor_type_from_canonical_name("activity_legal_enforcement"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("scene_outdoor_running"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("demographic_kids_8_10"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("user_designer"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("cleaning_methods"), "product_attribute")
})

test_that("derive: structural identifiers -> structural", {
  expect_equal(derive_predictor_type_from_canonical_name("brand"), "structural")
  expect_equal(derive_predictor_type_from_canonical_name("sku"), "structural")
  expect_equal(derive_predictor_type_from_canonical_name("asin"), "structural")
  expect_equal(derive_predictor_type_from_canonical_name("url"), "structural")
  expect_equal(derive_predictor_type_from_canonical_name("product_name"), "structural")
})

test_that("derive: unknown canonical name -> product_attribute default", {
  expect_equal(derive_predictor_type_from_canonical_name("some_unknown_canonical"), "product_attribute")
  expect_equal(derive_predictor_type_from_canonical_name("randomthing"), "product_attribute")
})

# ---------------------------------------------------------------------------
# Test: populate_predictor_classification_from_bridges() integration
# ---------------------------------------------------------------------------

# Fixture: minimal bridge yaml structure
make_fixture_bridges <- function(root) {
  comp_dir <- file.path(root, "TESTCO", "amz")
  dir.create(comp_dir, recursive = TRUE, showWarnings = FALSE)

  # Bridge yaml 1: hsg PL with sentiment + spec mix
  hsg_yaml <- list(
    prerawdata_source = list(datatype = "product_attributes_hsg"),
    canonical_target = list(table = "df_amz_product_attributes_hsg___raw",
                            platform = "amz"),
    field_extractors = list(
      brand                    = list(type = "column", name = "品牌"),
      sku                      = list(type = "column", name = "SKU"),
      asin                     = list(type = "column", name = "ASIN"),
      rating_no_distortion     = list(type = "column", name = "無失真"),
      rating_comfortable_wear  = list(type = "column", name = "穿戴舒適"),
      rating_durability        = list(type = "column", name = "耐用性"),
      review_count             = list(type = "column", name = "評論則數"),
      review_rating            = list(type = "column", name = "評論星級"),
      feature_polarized        = list(type = "column", name = "偏光功能"),
      protection_uv            = list(type = "column", name = "紫外線防護"),
      dimension_frame_width    = list(type = "column", name = "鏡框寬度"),
      color_lens               = list(type = "column", name = "鏡片顏色"),
      material_frame           = list(type = "column", name = "鏡框材質"),
      activity_legal           = list(type = "column", name = "執法"),
      scene_outdoor            = list(type = "column", name = "戶外場景"),
      demographic_kids         = list(type = "column", name = "兒童")
    )
  )
  yaml::write_yaml(hsg_yaml, file.path(comp_dir, "product_attributes_hsg.bridge.yaml"))

  # Bridge yaml 2: bys PL with different sentiment set
  bys_yaml <- list(
    canonical_target = list(table = "df_amz_product_attributes_bys___raw",
                            platform = "amz"),
    field_extractors = list(
      brand                  = list(type = "column", name = "品牌"),
      rating_lightweight     = list(type = "column", name = "輕量感"),
      dimension_lens_width   = list(type = "column", name = "鏡片寬度")
    )
  )
  yaml::write_yaml(bys_yaml, file.path(comp_dir, "product_attributes_bys.bridge.yaml"))

  # wip/ subdirectory should be SKIPPED
  wip_dir <- file.path(comp_dir, "wip")
  dir.create(wip_dir, showWarnings = FALSE)
  wip_yaml <- list(field_extractors = list(SKIP_ME = list(type = "column", name = "勿讀")))
  yaml::write_yaml(wip_yaml, file.path(wip_dir, "wip.bridge.yaml"))

  root
}

# Helper: in-memory DuckDB with SCHEMA_006 table
make_meta_con <- function() {
  con <- dbConnect(duckdb(), dbdir = ":memory:")
  if (file.exists(schema_path)) source(schema_path, local = TRUE)
  dbExecute(con, "
    CREATE TABLE df_predictor_classification (
      platform       VARCHAR NOT NULL,
      column_name    VARCHAR NOT NULL,
      predictor_type VARCHAR NOT NULL CHECK (predictor_type IN ('time_feature','product_attribute','comment_attribute','structural')),
      source         VARCHAR NOT NULL,
      added_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (platform, column_name)
    )
  ")
  con
}

test_that("populate: writes rows for hsg + bys bridge yamls, skips wip/", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  n_rows <- populate_predictor_classification_from_bridges(
    company = "TESTCO", meta_con = con, bridge_root = tmproot
  )
  expect_gt(n_rows, 0L)

  total <- count_rows(con)
  # hsg yaml has 16 entries, bys has 3; brand(品牌) shared so dedup -> 18
  expect_equal(total, 18L)

  # wip yaml skipped
  expect_equal(count_skipped(con, "勿讀"), 0L)
})

test_that("populate: 6 sentiment names correctly classified as comment_attribute", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)

  expect_equal(get_type_by_name(con, "無失真"), "comment_attribute")
  expect_equal(get_type_by_name(con, "穿戴舒適"), "comment_attribute")
  expect_equal(get_type_by_name(con, "耐用性"), "comment_attribute")
  expect_equal(get_type_by_name(con, "評論則數"), "comment_attribute")
  expect_equal(get_type_by_name(con, "評論星級"), "comment_attribute")
  expect_equal(get_type_by_name(con, "輕量感"), "comment_attribute")
})

test_that("populate: product spec names classified as product_attribute", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)

  expect_equal(get_type_by_name(con, "鏡框寬度"), "product_attribute")
  expect_equal(get_type_by_name(con, "偏光功能"), "product_attribute")
  expect_equal(get_type_by_name(con, "紫外線防護"), "product_attribute")
  # use-case conservative: activity_/scene_/demographic_ → product_attribute
  expect_equal(get_type_by_name(con, "執法"), "product_attribute")
  expect_equal(get_type_by_name(con, "兒童"), "product_attribute")
})

test_that("populate: structural names classified as structural", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)

  expect_equal(get_type_by_name(con, "品牌"), "structural")
  expect_equal(get_type_by_name(con, "SKU"), "structural")
  expect_equal(get_type_by_name(con, "ASIN"), "structural")
})

test_that("populate: source field = 'bridge_yaml'", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)

  expect_equal(distinct_sources(con), "bridge_yaml")
})

test_that("populate: idempotent — re-running yields no duplicates", {
  tmproot <- tempfile("bridges-")
  dir.create(tmproot)
  on.exit(unlink(tmproot, recursive = TRUE))
  make_fixture_bridges(tmproot)

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)
  n1 <- count_rows(con)

  # Run again
  populate_predictor_classification_from_bridges("TESTCO", con, tmproot)
  n2 <- count_rows(con)

  expect_equal(n1, n2)
  expect_equal(nrow(dup_rows(con)), 0L)
})

test_that("populate: empty bridge_root returns 0 rows, no error", {
  tmproot <- tempfile("bridges-empty-")
  dir.create(file.path(tmproot, "EMPTYCO", "amz"), recursive = TRUE)
  on.exit(unlink(tmproot, recursive = TRUE))

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  n_rows <- populate_predictor_classification_from_bridges("EMPTYCO", con, tmproot)
  expect_equal(n_rows, 0L)
})

test_that("populate: corrupt yaml raises actionable error", {
  tmproot <- tempfile("bridges-corrupt-")
  comp_dir <- file.path(tmproot, "BADCO", "amz")
  dir.create(comp_dir, recursive = TRUE)
  on.exit(unlink(tmproot, recursive = TRUE))

  # Write a syntactically broken yaml
  writeLines("this is: not: valid: yaml: ::", file.path(comp_dir, "product_attributes_x.bridge.yaml"))

  con <- make_meta_con()
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_error(
    populate_predictor_classification_from_bridges("BADCO", con, tmproot),
    regexp = "yaml|parse|product_attributes_x"
  )
})

cat("\n[#716] All populate_predictor_classification_from_bridges tests PASSED.\n")
