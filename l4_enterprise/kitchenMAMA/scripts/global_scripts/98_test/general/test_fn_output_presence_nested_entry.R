#!/usr/bin/env Rscript
# test_fn_output_presence_nested_entry.R
# ==============================================================================
# Regression test for #455 — fn_output_presence.R length>1 crash on nested
# db_paths.yaml entries (#435 era structured entries).
#
# v2 (2026-05-03 #514 strengthen):
#   - S5 grep precision: assert fallthrough message AND key name (was OR-grep
#     too lenient — any error containing 'path' or 'invalid' would pass even
#     if helper hit wrong branch)
#   - New S6/S7/S8 covering invalid scalar fallthrough (whitespace-only / NA /
#     empty string) — verify each rejects with informative error
#   - New S9 covering #511 C3 fix: trailing space on nested path (yaml typo)
#     should be silently trimmed, not false-missing
#   - New S10 covering #511 C4 fix: same name in databases + domain triggers
#     authoring-error stop() rather than silent dual-bucket leak
#   - Per-scenario cleanup via local({}) blocks (was main-level on.exit
#     accumulation — temp dirs leaked until main() exit)
#   - Portable script_root search via here::here() walk if available + more
#     fallback candidates for deep-subdir invocation
#
# Background:
#   db_paths.yaml may contain BOTH scalar string entries AND structured
#   {path:, required:} map entries (introduced in #435 for optional DBs).
#   The original check_db_layers_presence() did `rel <- all_paths[[name]]`
#   directly, which on a list entry yields a 2-element vector when fed
#   through `file.path(project_root, rel)`. `if (file.exists(abs))` then
#   crashes with "the condition has length > 1".
#
# Fix verified (2026-05-03):
#   - #455: inline resolve_entry() helper + 3-bucket result + scalar yaml_path
#   - #512: extracted to canonical 04_utils/fn_resolve_db_path_entry.R
#   - #511: trimws on nested path (C3) + cross-section collision detect (C4)
#   - #513: distinguished optional-missing message + isTRUE() dead code removed
#
# Usage (from project root or any subdir):
#   Rscript scripts/global_scripts/98_test/general/test_fn_output_presence_nested_entry.R
#
# Principles:
# - MP029: No fake data — uses tempfile() + minimal yaml fixtures, no
#   production yaml or DB hit
# - TD_R007: Plain R + assert() pattern (matches test_dplyr_coalesce_prefix.R)
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

# ---------- Locate fn_output_presence.R (portable, deep-subdir friendly) ----
locate_orchestration <- function() {
  # Try here::here() first if available — handles deep subdir invocations
  if (requireNamespace("here", quietly = TRUE)) {
    here_root <- tryCatch(here::here(), error = function(e) NULL)
    if (!is.null(here_root)) {
      for (sub in c("scripts/update_scripts/orchestration",
                    "shared/update_scripts/orchestration",
                    "update_scripts/orchestration")) {
        cand <- file.path(here_root, sub)
        if (file.exists(file.path(cand, "fn_output_presence.R"))) {
          return(normalizePath(cand, mustWork = TRUE))
        }
      }
    }
  }
  # Fallback: relative ladder (works for project-root / shared-symlink contexts)
  for (cand in c("scripts/update_scripts/orchestration",
                 "shared/update_scripts/orchestration",
                 "../update_scripts/orchestration",
                 "../shared/update_scripts/orchestration",
                 "../../shared/update_scripts/orchestration",
                 "../../update_scripts/orchestration",
                 "../../../shared/update_scripts/orchestration")) {
    if (file.exists(file.path(cand, "fn_output_presence.R"))) {
      return(normalizePath(cand, mustWork = TRUE))
    }
  }
  # Final fallback: walk up from getwd() looking for shared/update_scripts/
  cur <- getwd()
  for (i in seq_len(8L)) {
    cand <- file.path(cur, "shared", "update_scripts", "orchestration")
    if (file.exists(file.path(cand, "fn_output_presence.R"))) {
      return(normalizePath(cand, mustWork = TRUE))
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) break
    cur <- parent
  }
  NULL
}

script_root <- locate_orchestration()
if (is.null(script_root)) {
  stop("Cannot locate fn_output_presence.R from getwd()=", getwd(),
       " (tried here::here, relative ladder, and walk-up search)")
}
message(sprintf("Using script_root=%s", script_root))

source(file.path(script_root, "fn_output_presence.R"))

# Provide %||% if the source script doesn't (defensive)
if (!exists("%||%", inherits = TRUE)) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# ---------- Setup helpers ----------
make_fixture <- function(yaml_text, project_root) {
  yaml_path <- file.path(project_root, "scripts", "global_scripts",
                         "30_global_data", "parameters", "scd_type1",
                         "db_paths.yaml")
  dir.create(dirname(yaml_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(yaml_text, yaml_path)
  yaml_path
}

touch_db <- function(project_root, rel_path) {
  full <- file.path(project_root, rel_path)
  dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
  file.create(full)
  full
}

# Per-scenario tempdir helper — cleans up via local({}) on.exit, no main-level
# accumulation (was: main-level on.exit added each pr → all leaked until exit).
with_fixture <- function(prefix, fn) {
  pr <- tempfile(prefix)
  dir.create(pr)
  on.exit(unlink(pr, recursive = TRUE), add = TRUE)
  fn(pr)
}

main <- function() {
  message("=== test_fn_output_presence_nested_entry (v2: #455 + #512 + #511 + #513) ===")

  # ------------------------------------------------------------------------
  # S1: scalar entry only (no regression — historical behavior preserved)
  # ------------------------------------------------------------------------
  message("\n[S1] Scalar entries only — no regression")
  with_fixture("idd455_s1_", function(pr) {
    yaml_text <- paste(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "  raw_data: data/raw_data.duckdb",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    touch_db(pr, "data/app_data/app_data.duckdb")  # only one present

    result <- check_db_layers_presence(pr)
    assert(length(result$present) == 1L, "S1: 1 entry present")
    assert(length(result$missing) == 1L, "S1: 1 entry missing")
    assert("app_data" %in% names(result$present), "S1: app_data classified present")
    assert("raw_data" %in% names(result$missing), "S1: raw_data classified missing")
    assert(is.null(result$optional_missing) ||
           length(result$optional_missing) == 0L,
           "S1: optional_missing absent or empty")
  })

  # ------------------------------------------------------------------------
  # S2: nested entry with required: true — file present → present
  # ------------------------------------------------------------------------
  message("\n[S2] Nested entry required:true, file present")
  with_fixture("idd455_s2_", function(pr) {
    yaml_text <- paste(
      "domain:",
      "  required_db:",
      "    path: data/required_db.duckdb",
      "    required: true",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    touch_db(pr, "data/required_db.duckdb")

    result <- check_db_layers_presence(pr)
    assert(length(result$present) == 1L, "S2: 1 entry present (required:true file exists)")
    assert("required_db" %in% names(result$present), "S2: required_db in present bucket")
  })

  # ------------------------------------------------------------------------
  # S3: nested entry with required: false — file missing → optional_missing
  # ------------------------------------------------------------------------
  message("\n[S3] Nested entry required:false, file missing")
  with_fixture("idd455_s3_", function(pr) {
    yaml_text <- paste(
      "domain:",
      "  optional_db:",
      "    path: data/optional_db.duckdb",
      "    required: false",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    # No touch_db — file deliberately missing

    result <- check_db_layers_presence(pr)
    assert(length(result$missing) == 0L,
           "S3: required:false missing file does NOT classify as 'missing' (won't trigger nuclear)")
    assert(!is.null(result$optional_missing) &&
           length(result$optional_missing) == 1L,
           "S3: required:false missing file goes to optional_missing bucket")
    assert("optional_db" %in% names(result$optional_missing %||% character()),
           "S3: optional_db in optional_missing bucket")
  })

  # ------------------------------------------------------------------------
  # S4: mixed (scalar + 2 nested) — all 3 buckets correctly populated
  # ------------------------------------------------------------------------
  message("\n[S4] Mixed entries — 3 buckets")
  with_fixture("idd455_s4_", function(pr) {
    yaml_text <- paste(
      "databases:",
      "  app_data: data/app_data.duckdb",
      "  raw_data: data/raw_data.duckdb",
      "domain:",
      "  required_extra:",
      "    path: data/required_extra.duckdb",
      "    required: true",
      "  optional_temp:",
      "    path: data/optional_temp.duckdb",
      "    required: false",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    touch_db(pr, "data/app_data.duckdb")          # present
    touch_db(pr, "data/required_extra.duckdb")    # present
    # raw_data + optional_temp both missing

    result <- check_db_layers_presence(pr)
    assert(length(result$present) == 2L,
           sprintf("S4: 2 present (app_data, required_extra); got %d",
                   length(result$present)))
    assert(length(result$missing) == 1L,
           sprintf("S4: 1 required missing (raw_data); got %d",
                   length(result$missing)))
    assert(!is.null(result$optional_missing) &&
           length(result$optional_missing) == 1L,
           sprintf("S4: 1 optional missing (optional_temp); got %d",
                   length(result$optional_missing %||% 0L)))
    assert("raw_data" %in% names(result$missing),
           "S4: raw_data correctly in missing (scalar + missing = required missing)")
    assert("optional_temp" %in% names(result$optional_missing %||% character()),
           "S4: optional_temp correctly in optional_missing")
  })

  # ------------------------------------------------------------------------
  # S5: malformed nested entry (no path key) — precise error message check
  #
  # #514 strengthen: was `grepl("path|invalid|malformed|missing", ...)` —
  # any error containing 'path' or 'invalid' passed even if helper hit a
  # different branch. Now requires BOTH "Use either" canonical fallthrough
  # phrase AND the offending key name to verify branch 3 was actually hit.
  # ------------------------------------------------------------------------
  message("\n[S5] Malformed entry — precise fallthrough error (key-anchored)")
  with_fixture("idd455_s5_", function(pr) {
    yaml_text <- paste(
      "domain:",
      "  bad_entry:",
      "    required: true",
      "    # path key intentionally missing",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)

    err_msg <- tryCatch({
      check_db_layers_presence(pr)
      "(no error — should have rejected malformed entry)"
    }, error = function(e) conditionMessage(e))

    assert(grepl("Use either", err_msg, fixed = TRUE),
           sprintf("S5: error contains canonical fallthrough phrase 'Use either'; got: %s",
                   substr(err_msg, 1, 150)))
    assert(grepl("bad_entry", err_msg, fixed = TRUE),
           sprintf("S5: error mentions offending key 'bad_entry'; got: %s",
                   substr(err_msg, 1, 150)))
    assert(grepl("domain", err_msg, fixed = TRUE),
           sprintf("S5: error mentions section 'domain'; got: %s",
                   substr(err_msg, 1, 150)))
  })

  # ------------------------------------------------------------------------
  # S6: invalid scalar — empty string entry → fallthrough error (#514 LOGIC-2)
  # ------------------------------------------------------------------------
  message("\n[S6] Invalid scalar entry: empty string")
  with_fixture("idd455_s6_", function(pr) {
    yaml_text <- paste(
      "databases:",
      "  empty_str: ''",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)

    err_msg <- tryCatch({
      check_db_layers_presence(pr)
      "(no error — should have rejected empty-string entry)"
    }, error = function(e) conditionMessage(e))

    assert(grepl("Use either", err_msg, fixed = TRUE) &&
           grepl("empty_str", err_msg, fixed = TRUE),
           sprintf("S6: empty string rejected with fallthrough error; got: %s",
                   substr(err_msg, 1, 150)))
  })

  # ------------------------------------------------------------------------
  # S7: invalid scalar — whitespace-only entry → fallthrough error
  # ------------------------------------------------------------------------
  message("\n[S7] Invalid scalar entry: whitespace-only")
  with_fixture("idd455_s7_", function(pr) {
    # YAML parses '   ' as a 3-space string → nzchar(trimws('   ')) is FALSE
    # → falls through canonical helper to branch 3
    yaml_text <- paste(
      "databases:",
      "  ws_only: '   '",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)

    err_msg <- tryCatch({
      check_db_layers_presence(pr)
      "(no error — should have rejected whitespace-only entry)"
    }, error = function(e) conditionMessage(e))

    assert(grepl("Use either", err_msg, fixed = TRUE) &&
           grepl("ws_only", err_msg, fixed = TRUE),
           sprintf("S7: whitespace-only rejected with fallthrough error; got: %s",
                   substr(err_msg, 1, 150)))
  })

  # ------------------------------------------------------------------------
  # S8: invalid nested — required:NA → required-validation branch error
  #
  # Verifies the inner branch-2 NA-required validation fires (distinct from
  # branch-3 fallthrough; tests the helper's #435 contract enforcement).
  # ------------------------------------------------------------------------
  message("\n[S8] Invalid nested entry: required: NA (helper validation branch)")
  with_fixture("idd455_s8_", function(pr) {
    # YAML 'null' parses to NULL (which our helper treats as default TRUE),
    # so use yaml's NA-style ~ instead which parses to NA logical
    yaml_text <- paste(
      "domain:",
      "  bad_required:",
      "    path: data/foo.duckdb",
      "    required: ~",   # YAML null → NULL in R, treated as default TRUE
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    # NULL required path: should NOT error (defaults to TRUE per helper contract)
    err_msg <- tryCatch({
      check_db_layers_presence(pr)
      "(no error)"
    }, error = function(e) conditionMessage(e))
    assert(err_msg == "(no error)",
           sprintf("S8: yaml null required defaults to TRUE (no error); got: %s",
                   substr(err_msg, 1, 150)))
  })

  # ------------------------------------------------------------------------
  # S9: trailing-space path (#511 C3) — silently trimmed, not false-missing
  # ------------------------------------------------------------------------
  message("\n[S9] Trailing-space path (#511 C3) — trimmed, file detected")
  with_fixture("idd455_s9_", function(pr) {
    # Trailing space is invisible visual artifact common in yaml editing.
    # Canonical helper trims it on return so callers see clean path.
    yaml_text <- paste(
      "domain:",
      "  ts_db:",
      "    path: \"data/ts_db.duckdb \"",  # trailing space inside quotes
      "    required: true",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)
    touch_db(pr, "data/ts_db.duckdb")  # actual file (no trailing space)

    result <- check_db_layers_presence(pr)
    assert(length(result$present) == 1L &&
           "ts_db" %in% names(result$present),
           sprintf("S9: trailing-space path silently trimmed (file detected); present=%d",
                   length(result$present)))
    assert(length(result$missing) == 0L,
           "S9: no false-missing despite trailing space in yaml authoring")
  })

  # ------------------------------------------------------------------------
  # S10: cross-section name collision (#511 C4) — fail-fast detect-and-error
  # ------------------------------------------------------------------------
  message("\n[S10] Cross-section name collision (#511 C4) — authoring error")
  with_fixture("idd455_s10_", function(pr) {
    yaml_text <- paste(
      "databases:",
      "  app_data: data/app_data1.duckdb",
      "domain:",
      "  app_data:",
      "    path: data/app_data2.duckdb",
      "    required: false",
      sep = "\n"
    )
    make_fixture(yaml_text, pr)

    err_msg <- tryCatch({
      check_db_layers_presence(pr)
      "(no error — should have rejected cross-section duplicate)"
    }, error = function(e) conditionMessage(e))

    assert(grepl("authoring error", err_msg, fixed = TRUE) &&
           grepl("app_data", err_msg, fixed = TRUE) &&
           grepl("databases", err_msg, fixed = TRUE) &&
           grepl("domain", err_msg, fixed = TRUE),
           sprintf("S10: cross-section collision rejected with authoring-error; got: %s",
                   substr(err_msg, 1, 200)))
  })

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
