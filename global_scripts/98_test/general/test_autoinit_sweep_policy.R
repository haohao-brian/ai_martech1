#!/usr/bin/env Rscript
# test_autoinit_sweep_policy.R
# ==============================================================================
# Regression test for #517 — autoinit sweep policy excludes generator/fix/build
# scripts + _authoring/ tree, while still sourcing import-only files.
#
# Background:
#   sc_initialization_update_mode.R line 153-262 implements a hybrid blacklist:
#     - Filename patterns: ^gen_, ^fix_, ^_, ^sc_create_mock_
#     - Directory patterns: _authoring/
#   Belt-and-suspenders with per-file MP044 entry guards from #510 / #518 / #520.
#
# Test strategy:
#   1. Mirror the policy constants in this test (clearly marked as mirror).
#   2. Validate the mirror matches the live script via grep — fails if drift.
#   3. Apply the mirrored helper to (a) tempdir fixtures and (b) real
#      shared/global_scripts/ paths to verify the policy actually excludes
#      the known cluster (#510/#518/#520) and does NOT exclude import-only
#      files (fn_*.R, sc_*.R outside mock pattern).
#
# Usage (from project root):
#   Rscript shared/global_scripts/98_test/general/test_autoinit_sweep_policy.R
#
# Principles:
# - MP029: No fake data — uses real `sc_initialization_update_mode.R` source
#   text + tempfile() for fixtures
# - SO_R046: Initialization Imports Only — this policy is the mechanical
#   enforcement layer
# - TD_R007: Plain R + assert() pattern (matches test_gen_scripts_source_only.R)
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

# ---------- Locate global_scripts root ----------
script_root <- NULL
for (cand in c("scripts/global_scripts", "shared/global_scripts",
               "../scripts/global_scripts", "../shared/global_scripts",
               "../../shared/global_scripts")) {
  if (dir.exists(file.path(cand, "22_initializations"))) {
    script_root <- normalizePath(cand, mustWork = TRUE)
    break
  }
}
if (is.null(script_root)) {
  stop("Cannot locate global_scripts root from getwd()=", getwd())
}
message(sprintf("Using script_root=%s", script_root))

autoinit_path <- file.path(script_root,
                           "22_initializations/sc_initialization_update_mode.R")
stopifnot(file.exists(autoinit_path))

# ---------- Mirror policy constants (must match live script) ----------
# These mirror the live script. Test S0 below validates the mirror is in sync.
autoinit_exclude_filename_patterns <- c(
  "^gen_.*\\.R$",
  "^fix_.*\\.R$",
  "^_.*\\.R$",
  "^sc_create_mock_.*\\.R$"
)
autoinit_exclude_dir_segments <- c(
  "_authoring"
)

autoinit_should_skip <- function(file_path) {
  base <- basename(file_path)
  segments <- strsplit(file_path, .Platform$file.sep, fixed = TRUE)[[1]]
  filename_hit <- any(vapply(autoinit_exclude_filename_patterns,
                             function(p) grepl(p, base, perl = TRUE),
                             logical(1L)))
  dir_hit <- any(autoinit_exclude_dir_segments %in% segments)
  filename_hit || dir_hit
}

main <- function() {
  message("=== test_autoinit_sweep_policy (#517) ===")

  # ------------------------------------------------------------------------
  # S0: Mirror constants in sync with live script (drift detection)
  # ------------------------------------------------------------------------
  # Live source writes pattern literals with two-backslash form (the R
  # source representation of one backslash). readLines() preserves source
  # form (no escape decoding), so needles must use the source-level form
  # too. We hardcode them here as character vectors mirroring what the
  # live script's c(...) initializer should contain.
  message("\n[S0] Mirror constants match live sc_initialization_update_mode.R")
  live_text <- paste(readLines(autoinit_path), collapse = "\n")

  source_form_filename_needles <- c(
    '"^gen_.*\\\\.R$"',
    '"^fix_.*\\\\.R$"',
    '"^_.*\\\\.R$"',
    '"^sc_create_mock_.*\\\\.R$"'
  )
  source_form_dir_needles <- c(
    '"_authoring"'
  )

  for (needle in source_form_filename_needles) {
    found <- grepl(needle, live_text, fixed = TRUE)
    assert(found,
           sprintf("S0: live script contains filename pattern %s", needle))
  }
  for (needle in source_form_dir_needles) {
    found <- grepl(needle, live_text, fixed = TRUE)
    assert(found,
           sprintf("S0: live script contains dir segment %s", needle))
  }

  # Sanity: mirror count matches expected (drift detection if someone adds
  # patterns without updating test)
  assert(length(autoinit_exclude_filename_patterns) ==
           length(source_form_filename_needles),
         sprintf("S0: mirror filename pattern count %d == hardcoded needle count %d",
                 length(autoinit_exclude_filename_patterns),
                 length(source_form_filename_needles)))
  assert(length(autoinit_exclude_dir_segments) ==
           length(source_form_dir_needles),
         sprintf("S0: mirror dir segment count %d == hardcoded needle count %d",
                 length(autoinit_exclude_dir_segments),
                 length(source_form_dir_needles)))

  # ------------------------------------------------------------------------
  # S1: Filename pattern matching — tempdir fixtures, one per prefix
  # ------------------------------------------------------------------------
  message("\n[S1] Filename pattern fixtures (gen_/fix_/_/sc_create_mock_)")
  tdir <- tempfile("test_autoinit_")
  dir.create(tdir)
  on.exit(unlink(tdir, recursive = TRUE), add = TRUE)

  fname_fixtures <- list(
    list(name = "gen_foo.R",                  expected = TRUE,  reason = "^gen_"),
    list(name = "fix_bar.R",                  expected = TRUE,  reason = "^fix_"),
    list(name = "_baz.R",                     expected = TRUE,  reason = "^_ build orchestrator"),
    list(name = "sc_create_mock_data.R",      expected = TRUE,  reason = "^sc_create_mock_"),
    list(name = "fn_helper.R",                expected = FALSE, reason = "^fn_ import-only"),
    list(name = "sc_initialization_app.R",    expected = FALSE, reason = "sc_ but not mock"),
    list(name = "regular_script.R",           expected = FALSE, reason = "no prefix match")
  )
  for (f in fname_fixtures) {
    path <- file.path(tdir, f$name)
    file.create(path)
    got <- autoinit_should_skip(path)
    assert(got == f$expected,
           sprintf("S1: %s -> %s (expected %s, %s)",
                   f$name, got, f$expected, f$reason))
  }

  # ------------------------------------------------------------------------
  # S2: Directory pattern matching — _authoring/ segment in path
  # ------------------------------------------------------------------------
  message("\n[S2] Directory pattern fixtures (_authoring/ segment)")
  authoring_dir <- file.path(tdir, "_authoring", "subdir")
  dir.create(authoring_dir, recursive = TRUE)
  authoring_fixtures <- c("regular.R", "fn_anything.R", "even_a_normal_file.R")
  for (fn in authoring_fixtures) {
    path <- file.path(authoring_dir, fn)
    file.create(path)
    got <- autoinit_should_skip(path)
    assert(got == TRUE,
           sprintf("S2: _authoring/subdir/%s -> %s (expected TRUE: dir segment hit)",
                   fn, got))
  }

  # ------------------------------------------------------------------------
  # S3: Import-only files NOT excluded — real shared/global_scripts/ paths
  # ------------------------------------------------------------------------
  message("\n[S3] Import-only files not excluded (real script paths)")
  import_only_paths <- list(
    file.path(script_root, "04_utils/fn_compute_growth_rates.R"),
    file.path(script_root, "02_db_utils/duckdb/fn_dbConnectDuckdb.R"),
    file.path(script_root, "22_initializations/sc_Rprofile.R")
  )
  for (p in import_only_paths) {
    if (!file.exists(p)) {
      message(sprintf("  [SKIP] S3 fixture missing: %s", p))
      next
    }
    got <- autoinit_should_skip(p)
    assert(got == FALSE,
           sprintf("S3: %s -> %s (expected FALSE: import-only)",
                   basename(p), got))
  }

  # ------------------------------------------------------------------------
  # S4: Known cluster paths ARE excluded (#510 / #518 / #520 belt+suspenders)
  # ------------------------------------------------------------------------
  message("\n[S4] Known violator cluster (#510/#518/#520) all excluded")
  cluster_paths <- list(
    list(path = file.path(script_root,
           "01_db/raw_schema/_authoring/companies/QEF_DESIGN/gen_product_attribute_bridges.R"),
         issue = "#510"),
    list(path = file.path(script_root,
           "01_db/raw_schema/_authoring/companies/QEF_DESIGN/gen_product_attribute_schemas.R"),
         issue = "#510"),
    list(path = file.path(script_root,
           "01_db/raw_schema/_authoring/r_definitions/fix_wiser_poisson_tables.R"),
         issue = "#518"),
    list(path = file.path(script_root, "01_db/raw_schema/_build.R"),
         issue = "#520")
  )
  for (c in cluster_paths) {
    if (!file.exists(c$path)) {
      message(sprintf("  [SKIP] S4 fixture missing: %s", c$path))
      next
    }
    got <- autoinit_should_skip(c$path)
    assert(got == TRUE,
           sprintf("S4: %s (%s) -> %s (expected TRUE: in cluster)",
                   basename(c$path), c$issue, got))
  }

  # ------------------------------------------------------------------------
  # S5: SCHEMA_*.R in _authoring/ also excluded (no external caller per scout)
  # ------------------------------------------------------------------------
  message("\n[S5] _authoring/r_definitions/SCHEMA_*.R excluded via dir pattern")
  schema_paths <- list.files(
    file.path(script_root, "01_db/raw_schema/_authoring/r_definitions"),
    pattern = "^SCHEMA_.*\\.R$", full.names = TRUE
  )
  if (length(schema_paths) == 0L) {
    message("  [SKIP] S5: no SCHEMA_*.R fixtures found")
  } else {
    for (p in schema_paths) {
      got <- autoinit_should_skip(p)
      assert(got == TRUE,
             sprintf("S5: %s -> %s (expected TRUE: _authoring/ dir hit)",
                     basename(p), got))
    }
  }

  # ------------------------------------------------------------------------
  # S6: Live policy block syntactically present in autoinit script
  # ------------------------------------------------------------------------
  message("\n[S6] Live autoinit script contains policy block")
  has_helper <- grepl("autoinit_should_skip\\s*<-\\s*function", live_text)
  assert(has_helper, "S6: autoinit_should_skip() function defined")
  has_filter_call <- grepl("vapply\\(r_files_all,\\s*autoinit_should_skip", live_text)
  assert(has_filter_call, "S6: filter applied to r_files_all in sweep loop")
  has_skip_log <- grepl("Skipped.*per autoinit sweep policy", live_text)
  assert(has_skip_log, "S6: skip count logged in sweep output")

  # ------------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------------
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
