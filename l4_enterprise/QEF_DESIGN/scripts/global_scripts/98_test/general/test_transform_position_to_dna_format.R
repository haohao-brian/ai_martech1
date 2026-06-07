#!/usr/bin/env Rscript
# test_transform_position_to_dna_format.R
# ==============================================================================
# #788 — characterization test for transform_position_to_dna_format in
# positionDNAPlotly.R. Pins canonical row + factor-level order so the
# fix for the BrandEdge zig-zag bug (categoryorder + per-trace arrange) has a
# stable upstream-data invariant to rely on.
#
# Background:
#   The user-visible bug (#788) is that the plotly line trace draws zig-zag
#   across the categorical x-axis. Root cause has two parts (per diagnosis):
#     L1 — layout() has no explicit `xaxis$categoryorder` — plotly defaults to
#          first-appearance order across traces, which can disagree with the
#          factor-level order set by L62-69's arrange + as.factor pipeline.
#     L2 — per-product_id `add_trace` does not re-sort by attribute, so trace
#          row order may not match (the now-canonical) x-axis order.
#
#   The render-config fix lives in positionDNAPlotly.R itself (layout() + the
#   add_trace loop). This test guards the UPSTREAM data-prep invariant that
#   the fix relies on:
#     (a) levels(dna_data$attribute) == sort(unique(attribute_names)) [Unicode
#         collation = arrange order on a character column].
#     (b) For each product_id, the rows are ordered by attribute factor levels
#         (so per-trace `arrange(attribute)` is essentially a no-op confirmation
#         that the canonical order survives the per-pid filter).
#     (c) NA-score rows are dropped (`values_drop_na = TRUE`) so the factor
#         levels accurately reflect "attributes with at least one non-NA score".
#
# Refs #788
#
# Principles:
# - MP029 (real fn under test — extracted from positionDNAPlotly.R)
# - TD_R007 (plain R + assert pattern, 98_test/general/ convention)
# - SO_R007 (one-function-one-file violated here for legacy positionDNAPlotly
#            structure; future refactor split is sister #789 scope, not #788)
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

# ---------- Setup: load fn from positionDNAPlotly.R via temp source ----------
# transform_position_to_dna_format lives inside positionDNAPlotly.R, which has
# Shiny/plotly/bs4Dash dependencies we don't need for data-prep testing. We
# extract just the function definition into a temp file and source it so we
# don't pay the cost of loading the whole component's UI/server scaffolding.
# (Sourcing the whole file would require shiny + plotly + bs4Dash + base
# Shiny session context — way too heavy for an upstream data invariant test.)

component_candidates <- c(
  file.path("shared", "global_scripts", "10_rshinyapp_components", "position",
            "positionDNAPlotly", "positionDNAPlotly.R"),
  file.path("global_scripts", "10_rshinyapp_components", "position",
            "positionDNAPlotly", "positionDNAPlotly.R"),
  file.path("..", "..", "10_rshinyapp_components", "position",
            "positionDNAPlotly", "positionDNAPlotly.R"),
  file.path("10_rshinyapp_components", "position", "positionDNAPlotly",
            "positionDNAPlotly.R")
)
component_path <- component_candidates[file.exists(component_candidates)][1]
if (is.na(component_path)) {
  stop("positionDNAPlotly.R not found in candidate paths")
}
content <- readLines(component_path)

fn_start <- grep("^transform_position_to_dna_format <- function", content)
if (length(fn_start) != 1L) {
  stop("transform_position_to_dna_format definition not located uniquely")
}
# Walk forward until matching closing brace at column 1
fn_end <- NA_integer_
for (i in fn_start:length(content)) {
  if (identical(content[i], "}")) {
    fn_end <- i
    break
  }
}
if (is.na(fn_end)) {
  stop("transform_position_to_dna_format closing brace not located")
}

# Function-only deps; the component file's wider Shiny/plotly libs not needed
suppressMessages({
  library(dplyr)
  library(tidyr)
})

extracted_fn_path <- tempfile(fileext = ".R")
on.exit(unlink(extracted_fn_path), add = TRUE)
writeLines(content[fn_start:fn_end], extracted_fn_path)
source(extracted_fn_path)

stopifnot(exists("transform_position_to_dna_format", mode = "function"))
message(sprintf("Testing transform_position_to_dna_format from: %s",
                component_path))
message(sprintf("  (function lines %d-%d)\n", fn_start, fn_end))

# ---------- Case 1: basic 2 brands x 2 products x 3 attributes, all non-NA ----

input1 <- data.frame(
  product_id = c("p1", "p2", "p3", "p4"),
  brand      = c("BrandA", "BrandA", "BrandB", "BrandB"),
  品質       = c(4.5, 3.8, 4.2, 3.9),
  價格       = c(3.0, 4.1, 3.5, 4.0),
  配送       = c(4.0, 3.5, 4.5, 4.2),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

out1 <- transform_position_to_dna_format(input1)

assert(
  nrow(out1) == 12L,
  sprintf("Case 1 — 4 products x 3 attrs = 12 rows (got %d)", nrow(out1))
)

# Factor levels = unique attributes sorted (Unicode collation matches arrange)
expected_levels <- sort(c("品質", "價格", "配送"))
assert(
  identical(levels(out1$attribute), expected_levels),
  sprintf("Case 1 — factor levels in canonical sorted order (got %s)",
          paste(levels(out1$attribute), collapse = ", "))
)

# ---------- Case 2: per-product_id row order matches factor-level order ------
# CRITICAL for the #788 fix: even after filter(product_id == X), rows must come
# back ordered by attribute factor levels — otherwise the plotly line trace's
# row order disagrees with x-axis category order and zig-zags.

for (pid in unique(out1$product_id)) {
  pid_rows <- out1[out1$product_id == pid, , drop = FALSE]
  attr_seq <- as.character(pid_rows$attribute)
  expected_seq <- intersect(levels(out1$attribute), attr_seq)
  assert(
    identical(attr_seq, expected_seq),
    sprintf("Case 2 — product_id=%s row order matches factor levels (got %s)",
            pid, paste(attr_seq, collapse = ", "))
  )
}

# ---------- Case 3: NA-score rows are dropped (values_drop_na = TRUE) --------
# Attributes with ZERO non-NA scores across all products should disappear from
# factor levels entirely. This is the #693 fix invariant.

input3 <- data.frame(
  product_id = c("p1", "p2"),
  brand      = c("BrandA", "BrandB"),
  品質       = c(4.5, 3.8),
  價格       = c(NA_real_, 4.0),
  配送       = c(NA_real_, NA_real_),   # zero coverage — should disappear
  stringsAsFactors = FALSE,
  check.names = FALSE
)

out3 <- transform_position_to_dna_format(input3)

assert(
  !"配送" %in% levels(out3$attribute),
  "Case 3 — zero-coverage attribute (配送) dropped from factor levels"
)
assert(
  "價格" %in% levels(out3$attribute),
  "Case 3 — partial-coverage attribute (價格) survives factor levels"
)
assert(
  nrow(out3) == 3L,
  sprintf("Case 3 — 4 product-attr cells × non-NA = 3 rows (got %d)",
          nrow(out3))
)

# ---------- Case 4: exclude_vars parameter -----------------------------------

input4 <- data.frame(
  product_id = "p1",
  brand      = "BrandA",
  attr_a     = 4.0,
  attr_b     = 3.5,
  noise_col  = 99.0,
  stringsAsFactors = FALSE
)

out4 <- transform_position_to_dna_format(input4, exclude_vars = "noise_col")

assert(
  !"noise_col" %in% levels(out4$attribute),
  "Case 4 — exclude_vars removes column from factor levels"
)
assert(
  setequal(levels(out4$attribute), c("attr_a", "attr_b")),
  sprintf("Case 4 — non-excluded attrs survive (got %s)",
          paste(levels(out4$attribute), collapse = ", "))
)

# ---------- Case 5: single-product single-attribute degenerate ---------------

input5 <- data.frame(
  product_id = "p1",
  brand      = "BrandA",
  only_attr  = 4.0,
  stringsAsFactors = FALSE
)

out5 <- transform_position_to_dna_format(input5)

assert(
  nrow(out5) == 1L && identical(levels(out5$attribute), "only_attr"),
  "Case 5 — degenerate 1-row input produces single-level factor"
)

# ---------- Case 6: all-NA edge case — empty result --------------------------

input6 <- data.frame(
  product_id = c("p1", "p2"),
  brand      = c("A", "B"),
  attr_x     = c(NA_real_, NA_real_),
  stringsAsFactors = FALSE
)

out6 <- transform_position_to_dna_format(input6)

assert(
  nrow(out6) == 0L,
  sprintf("Case 6 — all-NA input drops all rows (got %d)", nrow(out6))
)
# Note: empty factor with no levels is the natural result; levels() may be
# character(0). The downstream fix (`categoryarray = levels(...)`) must handle
# this gracefully (see #788 diagnosis Risks).
assert(
  is.factor(out6$attribute) && length(levels(out6$attribute)) == 0L,
  "Case 6 — empty result still has factor type (length-0 levels)"
)

# ---------- Case 7: real BrandEdge fixture — 4 brands x 5 attrs --------------
# Reproduces a shape closer to actual df_position (QEF DNA attrs are Chinese).

input7 <- data.frame(
  product_id    = paste0("p", 1:8),
  brand         = rep(c("URUMQI", "KANASTAL", "DUCO", "HAOLOTA"), each = 2L),
  人體工學設計  = c(4.0, 3.8, 3.5, 3.2, 4.5, 4.2, 3.0, 2.8),
  視覺清晰      = c(3.9, 3.7, 4.0, 3.8, NA,  NA,  3.5, 3.4),  # DUCO sparse
  防眩          = c(4.4, 4.3, 3.8, 3.6, 4.0, 3.9, NA,  NA),   # HAOLOTA sparse
  耐用持久      = c(3.8, 3.7, 4.1, 4.0, 3.9, 3.8, 3.6, 3.5),
  配戴舒適      = c(4.3, 4.2, 4.0, 3.9, 4.4, 4.3, 4.1, 4.0),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

out7 <- transform_position_to_dna_format(input7)

# Factor levels exclude no attribute (all 5 have ≥1 non-NA somewhere)
assert(
  length(levels(out7$attribute)) == 5L,
  sprintf("Case 7 — all 5 attrs have ≥1 non-NA → 5 factor levels (got %d)",
          length(levels(out7$attribute)))
)

# Per-product_id ordering still holds even with sparse brand coverage —
# this is the invariant the #788 plotly fix relies on.
for (pid in unique(out7$product_id)) {
  pid_rows <- out7[out7$product_id == pid, , drop = FALSE]
  attr_seq <- as.character(pid_rows$attribute)
  expected_seq <- intersect(levels(out7$attribute), attr_seq)
  assert(
    identical(attr_seq, expected_seq),
    sprintf("Case 7 — product_id=%s row order respects factor levels (sparse OK)",
            pid)
  )
}

# ---------- Summary ----------

message("")
message(sprintf("=== Test results: %d passed, %d failed ===",
                pass_count, fail_count))

if (fail_count > 0L) {
  quit(status = 1L)
}
