#!/usr/bin/env Rscript
# Test: autoinit optional db support (#435)
#
# Validates that `db_paths.yaml` structured entries with `required: false`
# allow autoinit() to skip fail-fast on missing files (unblocks new-company
# bootstrap when AI-rating DBs aren't yet materialized), while preserving:
#   - Required DB behavior (still fail-fast on missing)
#   - Backward compatibility (scalar entries still work)
#   - Strict validation of `required` field (malformed values stop with
#     actionable error — the B1 finding from /idd-verify #444)
#
# Run: Rscript shared/global_scripts/98_test/test_autoinit_optional_db.R
#
# Principles:
# - MP029: No fake info — tests drive real code; no placeholder skip
# - MP154: Side effect defense — malformed `required` must NOT silently
#   downgrade a required DB to optional

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

# ---------- Fake project fixture (mirror test_autoinit_failfast.R) ----------

build_fake_project <- function(root, yaml_body, present_files = character()) {
  # yaml_body: raw YAML string for db_paths.yaml (test writes whatever shape)
  # present_files: relative paths to touch on disk (simulate existing DBs)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "scripts", "global_scripts", "22_initializations"),
             recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "scripts", "global_scripts", "30_global_data",
                       "parameters", "scd_type1"),
             recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "scripts", "global_scripts", "04_utils"),
             recursive = TRUE, showWarnings = FALSE)

  file.create(file.path(root, ".here"))

  db_yaml_path <- file.path(root, "scripts", "global_scripts", "30_global_data",
                            "parameters", "scd_type1", "db_paths.yaml")
  writeLines(yaml_body, db_yaml_path)

  # Stub init scripts (autoinit sources these)
  for (f in c("sc_initialization_app_mode.R", "sc_initialization_update_mode.R")) {
    writeLines("# stub init script\n",
               file.path(root, "scripts", "global_scripts",
                         "22_initializations", f))
  }

  # Stub fn_check_db_locks so #437 precheck doesn't crash
  writeLines(c(
    "check_db_locks <- function(paths, exclude_self = TRUE) { list() }"
  ), file.path(root, "scripts", "global_scripts", "04_utils",
               "fn_check_db_locks.R"))

  for (rel in present_files) {
    full <- file.path(root, rel)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    file.create(full)
  }
  invisible(root)
}

# verify-435 P3 portability fix: derive real sc_Rprofile.R path from this
# test file's location instead of hardcoded absolute path. Falls back to
# SC_RPROFILE_PATH env var override if present (CI / custom layouts).
.locate_real_sc_rprofile <- function() {
  override <- Sys.getenv("SC_RPROFILE_PATH", "")
  if (nzchar(override) && file.exists(override)) return(override)

  # Derive from this test file's location: 98_test/ → ../22_initializations/
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)][1]
  if (!is.na(file_arg)) {
    test_dir <- dirname(normalizePath(sub("^--file=", "", file_arg)))
    candidate <- file.path(test_dir, "..", "22_initializations",
                           "sc_Rprofile.R")
    if (file.exists(candidate)) return(normalizePath(candidate))
  }

  # Interactive R / sourced test — fall back to relative guesses
  candidates <- c(
    file.path("22_initializations", "sc_Rprofile.R"),
    file.path("..", "22_initializations", "sc_Rprofile.R"),
    file.path("global_scripts", "22_initializations", "sc_Rprofile.R"),
    file.path("shared", "global_scripts", "22_initializations",
              "sc_Rprofile.R")
  )
  hit <- Filter(file.exists, candidates)
  if (length(hit) > 0L) return(normalizePath(hit[1]))

  stop("Could not locate sc_Rprofile.R. Set SC_RPROFILE_PATH env var or ",
       "run test from a directory where one of these paths resolves:\n",
       paste("  -", candidates, collapse = "\n"))
}

run_autoinit <- function(root, mode = "UPDATE_MODE") {
  real_sc_rprofile <- .locate_real_sc_rprofile()

  child_script <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf("setwd(%s)", shQuote(root)),
    sprintf("OPERATION_MODE <- %s", shQuote(mode)),
    sprintf("source(%s)", shQuote(real_sc_rprofile)),
    "result <- tryCatch({ autoinit(); list(ok = TRUE) },",
    "  error = function(e) list(ok = FALSE, err = conditionMessage(e)))",
    "cat(sprintf('RESULT_OK:%s\\n', as.character(result$ok)))",
    "if (!isTRUE(result$ok)) cat(sprintf('RESULT_ERR:%s\\n', result$err))"
  ), child_script)

  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", child_script),
    stdout = TRUE, stderr = TRUE
  ))
  ok <- any(grepl("^RESULT_OK:TRUE$", out))
  err <- ""
  idx <- grep("^RESULT_ERR:", out)
  if (length(idx) > 0L) err <- sub("^RESULT_ERR:", "", out[idx[1]])
  list(ok = ok, err = err, raw = out)
}

# ---------- Scenarios ----------

main <- function() {
  message("=== test_autoinit_optional_db (#435) ===")

  # Scenario 1: Optional missing → continue
  message("\n[S1] Optional entry missing → no stop")
  root1 <- tempfile("s1_")
  build_fake_project(root1,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "  raw_data: data/raw_data/raw_data.duckdb",
      "domain:",
      "  comment_property_rating_temp:",
      "    path: data/scd_type1/comment_property_rating_temp.duckdb",
      "    required: false"
    ),
    present_files = c("data/app_data/app_data.duckdb",
                      "data/raw_data/raw_data.duckdb")
  )
  r1 <- run_autoinit(root1)
  assert(r1$ok, sprintf("S1 optional missing OK — %s", r1$err))

  # Scenario 2: Required missing → stop (preserve existing behavior)
  message("\n[S2] Required entry missing → stop fail-fast")
  root2 <- tempfile("s2_")
  build_fake_project(root2,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "  raw_data: data/raw_data/raw_data.duckdb"
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r2 <- run_autoinit(root2)
  assert(!r2$ok && grepl("ETL pipeline incomplete", r2$err),
         sprintf("S2 required missing stops — err='%s'", substr(r2$err, 1, 80)))

  # Scenario 3: required: false explicit + file present → loaded + not required
  message("\n[S3] Explicit required: false + file present → loaded")
  root3 <- tempfile("s3_")
  build_fake_project(root3,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "domain:",
      "  optional_present:",
      "    path: data/foo/optional.duckdb",
      "    required: false"
    ),
    present_files = c("data/app_data/app_data.duckdb",
                      "data/foo/optional.duckdb")
  )
  r3 <- run_autoinit(root3)
  assert(r3$ok, sprintf("S3 optional present loaded — %s", r3$err))

  # Scenario 4: required: true explicit + missing → stop
  message("\n[S4] Explicit required: true + missing → stop")
  root4 <- tempfile("s4_")
  build_fake_project(root4,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "domain:",
      "  required_missing:",
      "    path: data/foo/req.duckdb",
      "    required: true"
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r4 <- run_autoinit(root4)
  assert(!r4$ok && grepl("ETL pipeline incomplete", r4$err),
         sprintf("S4 required:true explicit missing stops — %s",
                 substr(r4$err, 1, 80)))

  # Scenario 5: Structured entry WITHOUT required key → default TRUE → missing stops
  message("\n[S5] Structured entry omit required → default required=TRUE → stop")
  root5 <- tempfile("s5_")
  build_fake_project(root5,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "domain:",
      "  omit_required:",
      "    path: data/foo/bar.duckdb"
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r5 <- run_autoinit(root5)
  assert(!r5$ok && grepl("ETL pipeline incomplete", r5$err),
         sprintf("S5 default required=TRUE → missing stops — %s",
                 substr(r5$err, 1, 80)))

  # Scenario 6: Malformed required (typo "flase") → stop with clear error (B1)
  message("\n[S6] Malformed required typo → stop with validation error (B1)")
  root6 <- tempfile("s6_")
  build_fake_project(root6,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "domain:",
      "  typo_required:",
      "    path: data/foo/bar.duckdb",
      "    required: flase"
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r6 <- run_autoinit(root6)
  assert(!r6$ok && grepl("required", r6$err, ignore.case = TRUE),
         sprintf("S6 malformed 'flase' stops with validation error — %s",
                 substr(r6$err, 1, 120)))

  # Scenario 7: Malformed required (quoted string "false") → stop
  message("\n[S7] required: \"false\" (quoted string) → stop with validation error")
  root7 <- tempfile("s7_")
  build_fake_project(root7,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "domain:",
      "  quoted_required:",
      "    path: data/foo/bar.duckdb",
      "    required: \"false\""
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r7 <- run_autoinit(root7)
  assert(!r7$ok && grepl("required", r7$err, ignore.case = TRUE),
         sprintf("S7 quoted \"false\" stops — %s", substr(r7$err, 1, 120)))

  # Scenario 8: Scalar (old format) backward compat → required, missing stops
  message("\n[S8] Scalar entry (backward compat) missing → stop (required=TRUE)")
  root8 <- tempfile("s8_")
  build_fake_project(root8,
    c(
      "databases:",
      "  app_data: data/app_data/app_data.duckdb",
      "  scalar_missing: data/foo/scalar.duckdb"
    ),
    present_files = c("data/app_data/app_data.duckdb")
  )
  r8 <- run_autoinit(root8)
  assert(!r8$ok && grepl("ETL pipeline incomplete", r8$err),
         sprintf("S8 scalar backward-compat missing stops — %s",
                 substr(r8$err, 1, 80)))

  # ---------- Summary ----------
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
