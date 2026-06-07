#!/usr/bin/env Rscript
# test_make_skip_sentinel.R
# ==============================================================================
# #715 — MP163 sentinel for skipped product lines in D04 poisson output
#
# Background:
#   D04_02.R has 6 skip paths that historically wrote an empty schema to
#   processed_data and `next`d. None of them added the product line to
#   `all_results`, so the PL silently vanished from the merged
#   `df_<platform>_poisson_analysis_all` table. UI dropdowns list the PL
#   (df_position has it) → empty query → #713 empty-df crash + user confusion.
#
#   make_skip_sentinel() (04_utils/fn_make_skip_sentinel.R) builds a 1-row
#   sentinel that is schema-identical to the regular per-predictor output, so
#   bind_rows() into `_all` preserves the PL with an explicit
#   estimation_status='not_estimable' + convergence='skipped' marker.
#
# Refs #715
#
# Principles:
# - MP029 (sentinel is an explicit gap marker, NOT fabricated data)
# - MP163 (progressive completeness — visible-gap sentinel, never silently drop)
# - TD_R007 (plain R + assert pattern, 98_test/general/ convention)
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
  file.path("shared", "global_scripts", "04_utils", "fn_make_skip_sentinel.R"),
  file.path("global_scripts", "04_utils", "fn_make_skip_sentinel.R"),
  file.path("..", "..", "04_utils", "fn_make_skip_sentinel.R"),
  file.path("04_utils", "fn_make_skip_sentinel.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_make_skip_sentinel.R not found in candidate paths")
}
source(fn_path)
suppressMessages(library(dplyr))
suppressMessages(library(tibble))

message(sprintf("Testing make_skip_sentinel from: %s\n", fn_path))

# ---------- Fixture: realistic D04_02 empty_output_table schema ----------
# Mirrors the D04_02.R empty_output_table definition (33 columns, mixed types).

schema_template <- tibble(
  product_line_id      = character(),
  platform             = character(),
  predictor            = character(),
  predictor_type       = character(),
  data_type            = character(),
  source_variable      = character(),
  estimation_status    = character(),
  coefficient          = numeric(),
  incidence_rate_ratio = numeric(),
  std_error            = numeric(),
  z_value              = numeric(),
  p_value              = numeric(),
  conf_low             = numeric(),
  conf_high            = numeric(),
  irr_conf_low         = numeric(),
  irr_conf_high        = numeric(),
  predictor_min        = numeric(),
  predictor_max        = numeric(),
  predictor_range      = numeric(),
  predictor_is_binary  = logical(),
  track_multiplier     = numeric(),
  deviance             = numeric(),
  aic                  = numeric(),
  sample_size          = integer(),
  convergence          = character(),
  analysis_date        = as.Date(character()),
  analysis_version     = character(),
  computed_at          = as.POSIXct(character()),
  data_version         = as.Date(character()),
  display_name         = character(),
  display_name_en      = character(),
  display_name_zh      = character(),
  display_category     = character(),
  display_description  = character()
)

# ---------- Tests ----------

sentinel <- tryCatch(
  make_skip_sentinel("sfg", "amz", "Input time series table is empty",
                     schema_template, "v6.0_TypeB_DMR066"),
  error = function(e) structure(list(), class = "mss_error",
                                msg = conditionMessage(e))
)

assert(
  !inherits(sentinel, "mss_error"),
  sprintf("make_skip_sentinel runs without error (%s)",
          if (inherits(sentinel, "mss_error")) attr(sentinel, "msg") else "ok")
)

if (!inherits(sentinel, "mss_error")) {

  # Case 1: exactly 1 row
  assert(
    nrow(sentinel) == 1L,
    sprintf("returns exactly 1 row (got %d)", nrow(sentinel))
  )

  # Case 2: schema-identical to template — same columns in same order
  assert(
    identical(names(sentinel), names(schema_template)),
    "column names match schema_template exactly"
  )

  # Case 3: schema-identical types
  template_types <- sapply(schema_template, function(x) class(x)[1L])
  sentinel_types <- sapply(sentinel,        function(x) class(x)[1L])
  assert(
    identical(unname(template_types), unname(sentinel_types)),
    sprintf("column types match schema_template (mismatches: %s)",
            paste(names(template_types)[template_types != sentinel_types],
                  collapse = ", "))
  )

  # Case 4: MP163 markers correctly populated
  assert(
    identical(sentinel$product_line_id[1L], "sfg"),
    sprintf("product_line_id = 'sfg' (got '%s')", sentinel$product_line_id[1L])
  )
  assert(
    identical(sentinel$platform[1L], "amz"),
    sprintf("platform = 'amz' (got '%s')", sentinel$platform[1L])
  )
  assert(
    identical(sentinel$estimation_status[1L], "not_estimable"),
    sprintf("estimation_status = 'not_estimable' (got '%s')",
            sentinel$estimation_status[1L])
  )
  assert(
    identical(sentinel$convergence[1L], "skipped"),
    sprintf("convergence = 'skipped' (got '%s')", sentinel$convergence[1L])
  )
  assert(
    identical(sentinel$predictor[1L], "__no_input_data__"),
    sprintf("predictor sentinel marker present (got '%s')",
            sentinel$predictor[1L])
  )
  assert(
    identical(sentinel$sample_size[1L], 0L),
    sprintf("sample_size = 0L (got %s)", as.character(sentinel$sample_size[1L]))
  )

  # Case 5: reason propagates into human-readable display fields
  assert(
    grepl("Input time series table is empty", sentinel$display_name[1L]),
    sprintf("display_name carries the skip reason (got '%s')",
            sentinel$display_name[1L])
  )

  # Case 6: NUMERIC stat columns are NA (MP029 — sentinel is a GAP MARKER,
  # not fabricated zero coefficients).
  assert(
    is.na(sentinel$coefficient[1L]),
    sprintf("coefficient is NA (not 0 — explicit gap marker, got %s)",
            as.character(sentinel$coefficient[1L]))
  )
  assert(
    is.na(sentinel$p_value[1L]),
    "p_value is NA (sentinel must not fabricate statistics)"
  )

  # Case 7: bind_rows-able with the template + a fake estimated row.
  # This is the actual use case in D04_02.R's merge step.
  fake_estimated <- schema_template
  fake_estimated[1L, ] <- NA
  fake_estimated$product_line_id[1L]   <- "its"
  fake_estimated$platform[1L]          <- "amz"
  fake_estimated$predictor[1L]         <- "evaluated_attribute"
  fake_estimated$estimation_status[1L] <- "estimated"
  fake_estimated$sample_size[1L]       <- 50L
  fake_estimated$coefficient[1L]       <- 0.5
  fake_estimated$convergence[1L]       <- "converged"

  merged <- tryCatch(
    dplyr::bind_rows(fake_estimated, sentinel),
    error = function(e) structure(list(), class = "bind_error",
                                  msg = conditionMessage(e))
  )
  assert(
    !inherits(merged, "bind_error") && nrow(merged) == 2L,
    sprintf("sentinel bind_rows()-es cleanly into a mixed table (rows=%s, err=%s)",
            if (is.data.frame(merged)) nrow(merged) else "N/A",
            if (inherits(merged, "bind_error")) attr(merged, "msg") else "ok")
  )

  # Case 8: in the merged table, the sentinel row is reachable by PL filter —
  # this is the user-visible regression test for #715 (skipped PL appears in
  # the _all merge).
  if (is.data.frame(merged) && nrow(merged) == 2L) {
    sfg_rows <- merged[merged$product_line_id == "sfg", , drop = FALSE]
    assert(
      nrow(sfg_rows) == 1L &&
        identical(sfg_rows$estimation_status, "not_estimable"),
      "merged `_all` contains the skipped PL with explicit not_estimable marker"
    )
  }
}

# ---------- Summary ----------

cat("\n========================================\n")
cat(sprintf("Test results: %d passed, %d failed\n", pass_count, fail_count))
cat("========================================\n")

if (fail_count > 0L) {
  quit(status = 1L)
}
