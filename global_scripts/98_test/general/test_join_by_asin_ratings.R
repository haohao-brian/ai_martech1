#!/usr/bin/env Rscript
# test_join_by_asin_ratings.R
# ==============================================================================
# #733 PR #2 — Unit test for join_by_asin_ratings() helper
#
# Background:
#   PR #1 (#745, merged 2026-05-17) added Stage 2.5 _rating$ fast-path to
#   fn_classify_predictor_type.R. PR #2 introduces the <attr>_rating columns
#   via a new helper fn_join_by_asin_ratings.R, called from D04_02.R after
#   ts_data is loaded.
#
#   The helper:
#     1. Drops the by_asin `rating` column (collision with ts_data's existing
#        `rating` column — Plan sub-decision D-B avoids automatic .x/.y rename)
#     2. Renames non-key columns with `_rating` suffix so Stage 2.5
#        (from PR #1) classifies them as `comment_attribute` predictors
#     3. LEFT JOINs ts_data with the renamed by_asin frame
#     4. Returns ts_data unchanged when by_asin_data is NULL or 0-row
#        (MP163 Progressive Completeness — graceful no-op for absent inputs)
#
# Refs #733 (sub-decisions D-A, D-B, D-E)
# Refs #745 (PR #1 already merged)
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_join_by_asin_ratings.R
#
# Principles:
# - MP029: real fn under test, no fake mocks (uses in-memory data frames as
#          legitimate test inputs — not faked DB schemas)
# - MP163: graceful skip for missing by_asin (no stop())
# - TD_R007: Plain R + assert() pattern (matches PR #1 test convention in
#            98_test/general/)
# - IC_P002: shared fn — verified via in-memory inputs that cover all 5 cos'
#            expected call patterns
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

# ---------- Setup: source fn under test ----------

fn_candidates <- c(
  file.path("shared", "global_scripts", "04_utils", "fn_join_by_asin_ratings.R"),
  file.path("global_scripts", "04_utils", "fn_join_by_asin_ratings.R"),
  file.path("..", "..", "04_utils", "fn_join_by_asin_ratings.R"),
  file.path("04_utils", "fn_join_by_asin_ratings.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_join_by_asin_ratings.R not found in candidate paths")
}
source(fn_path)

suppressPackageStartupMessages(library(dplyr))

message(sprintf("Testing join_by_asin_ratings from: %s\n", fn_path))

# ---------- Tests ----------

# Build a minimal ts_data fixture (mimics df_amz_sales_complete_time_series_<pl>)
ts_data_amz <- data.frame(
  amz_asin = c("B001", "B002", "B003"),
  time     = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03")),
  sales    = c(10, 5, 7),
  rating   = c(4.5, 3.8, 4.2),  # ts_data's product listing-level rating
  stringsAsFactors = FALSE
)

# Build a minimal by_asin fixture (mimics df_comment_property_ratingonly_by_asin_<pl>)
# Per real QEF hsg: key=product_id, overall `rating`, + attribute cols (Chinese names)
by_asin_pid <- data.frame(
  product_id     = c("B001", "B002"),  # B003 absent — LEFT JOIN should NA-fill
  rating         = c(4.0, 3.5),         # overall avg — should be DROPPED (collision)
  `光學清晰`     = c(4.5, 3.2),         # attr — should become 光學清晰_rating
  `配戴舒適`     = c(3.8, NA_real_),    # attr — should become 配戴舒適_rating
  check.names    = FALSE,
  stringsAsFactors = FALSE
)

# Case 1: Happy path — JOIN adds suffixed attribute cols, drops by_asin rating
res1 <- join_by_asin_ratings(ts_data_amz, by_asin_pid, ts_key = "amz_asin", by_asin_key = "product_id")
assert(
  nrow(res1) == 3L && "光學清晰_rating" %in% names(res1) && "配戴舒適_rating" %in% names(res1),
  sprintf("Happy path: 3 rows preserved, _rating cols added (got %d rows, cols: %s)",
          nrow(res1), paste(setdiff(names(res1), names(ts_data_amz)), collapse = ","))
)
# Verify by_asin's `rating` was DROPPED (ts_data's `rating` should remain)
assert(
  identical(res1$rating, ts_data_amz$rating),
  sprintf("by_asin `rating` dropped; ts_data `rating` preserved (got: %s)",
          paste(res1$rating, collapse = ","))
)
# Verify B003 (absent from by_asin) gets NA for joined cols (LEFT JOIN behavior)
assert(
  is.na(res1$光學清晰_rating[res1$amz_asin == "B003"]),
  "B003 (absent from by_asin) gets NA for 光學清晰_rating"
)

# Case 2: `rating` collision — by_asin has rating, ts_data has rating; both should NOT collide
# (by_asin's rating dropped before JOIN; ts_data's rating preserved)
# Already covered above; assert no .x/.y suffix appeared (which would indicate collision)
assert(
  !any(grepl("\\.x$|\\.y$", names(res1))),
  sprintf("No .x/.y collision suffixes appeared (got cols: %s)", paste(names(res1), collapse = ","))
)

# Case 3: `asin` key fallback — by_asin keyed by `asin` instead of `product_id`
by_asin_asin <- by_asin_pid
names(by_asin_asin)[names(by_asin_asin) == "product_id"] <- "asin"
res3 <- join_by_asin_ratings(ts_data_amz, by_asin_asin, ts_key = "amz_asin", by_asin_key = "asin")
assert(
  nrow(res3) == 3L && "光學清晰_rating" %in% names(res3) && res3$光學清晰_rating[res3$amz_asin == "B001"] == 4.5,
  "asin key fallback: JOIN succeeds via asin→amz_asin"
)

# Case 4: NULL by_asin (table missing) → graceful no-op (MP163)
res4 <- join_by_asin_ratings(ts_data_amz, NULL, ts_key = "amz_asin", by_asin_key = "product_id")
assert(
  identical(res4, ts_data_amz),
  sprintf("NULL by_asin: returns ts_data unchanged (MP163 graceful; got %d cols, expected %d)",
          ncol(res4), ncol(ts_data_amz))
)

# Case 5: Empty by_asin (0 rows) → graceful no-op
by_asin_empty <- by_asin_pid[0, , drop = FALSE]
res5 <- join_by_asin_ratings(ts_data_amz, by_asin_empty, ts_key = "amz_asin", by_asin_key = "product_id")
assert(
  identical(res5, ts_data_amz),
  sprintf("Empty by_asin (0 rows): returns ts_data unchanged (got %d cols)", ncol(res5))
)

# Case 6: Duplicate by_asin_key → must stop, not silently expand rows
# Per /idd-verify #733 PR #750 finding HIGH-1 (empirically confirmed):
# dplyr::left_join silently expands ts_data rows when by_asin has duplicate
# keys, biasing downstream Poisson IRR. Helper must defensively reject.
by_asin_dup <- data.frame(
  product_id     = c("B001", "B001", "B002"),  # duplicate B001
  rating         = c(4.0, 3.5, 3.5),
  `光學清晰`     = c(4.5, 3.2, 3.8),
  check.names    = FALSE,
  stringsAsFactors = FALSE
)
res6 <- tryCatch(
  join_by_asin_ratings(ts_data_amz, by_asin_dup, ts_key = "amz_asin", by_asin_key = "product_id"),
  error = function(e) paste0("ERROR: ", e$message)
)
assert(
  is.character(res6) && grepl("duplicate value", res6, ignore.case = TRUE),
  sprintf("Duplicate by_asin_key: helper stops with informative error (got: %s)",
          if (is.character(res6)) substr(res6, 1, 100) else "no error (silent expansion!)")
)

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
