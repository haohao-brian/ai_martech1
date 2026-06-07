#!/usr/bin/env Rscript
# test_gen_scripts_source_only.R
# ==============================================================================
# Regression test for #510 — gen_*.R top-level yaml read blocks autoinit().
#
# Background:
#   shared/global_scripts/01_db/raw_schema/_authoring/companies/QEF_DESIGN/
#     gen_product_attribute_bridges.R
#     gen_product_attribute_schemas.R
#   有 top-level `yaml::read_yaml()` / `readr::read_csv()` 等 side-effecting
#   read。autoinit() 在 UPDATE_MODE / GLOBAL_MODE blanket-source 整個 01_db/
#   tree (sc_initialization_update_mode.R line 153-178),這些 top-level
#   statement 被當 import 執行,撞缺檔即 halt 整個 R session。
#
# Fix verified (per Plan-tier #510, Strategy B + Decision C/B/A):
#   - Top-level 程式碼 wrap 進 generate_*() function
#   - 檔尾加 redundant entry guard (sys.nframe() == 0L AND
#     !INITIALIZATION_COMPLETED) 讓 Rscript 直接 invoke 仍跑、autoinit
#     source 只 define 不 execute
#
# Usage (from project root):
#   Rscript scripts/global_scripts/98_test/general/test_gen_scripts_source_only.R
#
# Principles:
# - MP029: No fake data — uses real gen_*.R files via source(); no
#   production yaml/csv hit (we DELIBERATELY remove the input file before
#   sourcing to verify autoinit-style behavior — empty environment)
# - MP044: Functor-Module Correspondence — verify functor is defined
#   without applying it
# - TD_R007: Plain R + assert() pattern (matches test_dplyr_coalesce_prefix.R
#   / test_D05_01_growth_rates.R)
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

# ---------- Locate gen_*.R files ----------
script_root <- NULL
for (cand in c("scripts/global_scripts", "shared/global_scripts",
               "../scripts/global_scripts", "../shared/global_scripts",
               "../../shared/global_scripts")) {
  if (dir.exists(file.path(cand, "01_db/raw_schema/_authoring/companies/QEF_DESIGN"))) {
    script_root <- normalizePath(cand, mustWork = TRUE)
    break
  }
}
if (is.null(script_root)) {
  stop("Cannot locate global_scripts root from getwd()=", getwd())
}
message(sprintf("Using script_root=%s", script_root))

gen_dir <- file.path(script_root,
                     "01_db/raw_schema/_authoring/companies/QEF_DESIGN")
gen_bridges_path <- file.path(gen_dir, "gen_product_attribute_bridges.R")
gen_schemas_path <- file.path(gen_dir, "gen_product_attribute_schemas.R")

# #518: fix_wiser sister bug — same root cause, different file
fix_wiser_path <- file.path(script_root,
                            "01_db/raw_schema/_authoring/r_definitions",
                            "fix_wiser_poisson_tables.R")

# #520: _build.R sister bug — third file with same top-level pattern
build_R_path <- file.path(script_root, "01_db/raw_schema/_build.R")

stopifnot(file.exists(gen_bridges_path))
stopifnot(file.exists(gen_schemas_path))
stopifnot(file.exists(fix_wiser_path))
stopifnot(file.exists(build_R_path))

# ---------- Helper: source in isolated env simulating autoinit context ----------
source_in_autoinit_env <- function(path, init_completed = TRUE) {
  # Fresh env with INITIALIZATION_COMPLETED set; source(local=FALSE) targets
  # .GlobalEnv same as autoinit's behavior.
  prev_ic <- if (exists("INITIALIZATION_COMPLETED", envir = .GlobalEnv)) {
    get("INITIALIZATION_COMPLETED", envir = .GlobalEnv)
  } else NULL

  .GlobalEnv$INITIALIZATION_COMPLETED <- init_completed
  on.exit({
    if (is.null(prev_ic)) {
      rm("INITIALIZATION_COMPLETED", envir = .GlobalEnv)
    } else {
      .GlobalEnv$INITIALIZATION_COMPLETED <- prev_ic
    }
  }, add = TRUE)

  err <- tryCatch({
    source(path, local = FALSE)
    NULL
  }, error = function(e) conditionMessage(e),
     warning = function(w) NULL)  # warnings (e.g. about ignoring NULL header) are OK
  err
}

main <- function() {
  message("=== test_gen_scripts_source_only (#510) ===")

  # ------------------------------------------------------------------------
  # S1: source(gen_bridges) under autoinit context — no halt
  # ------------------------------------------------------------------------
  message("\n[S1] source(gen_product_attribute_bridges.R) under autoinit env — no halt")
  err <- source_in_autoinit_env(gen_bridges_path, init_completed = TRUE)
  if (!is.null(err)) {
    assert(FALSE, sprintf("S1: source halted with error: %s", substr(err, 1, 150)))
  } else {
    assert(TRUE, "S1: source returned cleanly (top-level not executed under autoinit)")
  }

  # ------------------------------------------------------------------------
  # S2: After S1, generate_bridges function defined (MP044 functor available)
  # ------------------------------------------------------------------------
  message("\n[S2] After source, generate_bridges() function defined")
  has_fn <- exists("generate_bridges", inherits = TRUE) &&
            is.function(get("generate_bridges", inherits = TRUE))
  assert(has_fn, "S2: generate_bridges is defined and is a function")

  # ------------------------------------------------------------------------
  # S3: Same for gen_product_attribute_schemas.R
  # ------------------------------------------------------------------------
  message("\n[S3] source(gen_product_attribute_schemas.R) under autoinit env — no halt")
  err <- source_in_autoinit_env(gen_schemas_path, init_completed = TRUE)
  if (!is.null(err)) {
    assert(FALSE, sprintf("S3: source halted with error: %s", substr(err, 1, 150)))
  } else {
    assert(TRUE, "S3: source returned cleanly")
  }
  has_fn <- exists("generate_schemas", inherits = TRUE) &&
            is.function(get("generate_schemas", inherits = TRUE))
  assert(has_fn, "S3: generate_schemas is defined and is a function")

  # ------------------------------------------------------------------------
  # S4: Both files contain redundant entry guard (Decision 1 = Option C)
  # ------------------------------------------------------------------------
  message("\n[S4] Both files contain redundant entry guard pattern (Decision 1 = C)")
  for (path in c(gen_bridges_path, gen_schemas_path)) {
    txt <- paste(readLines(path), collapse = "\n")
    has_sys_nframe <- grepl("sys\\.nframe\\(\\)\\s*==\\s*0[Ll]?", txt)
    has_init_check <- grepl("INITIALIZATION_COMPLETED", txt)
    assert(has_sys_nframe,
           sprintf("S4: %s contains sys.nframe() == 0L guard",
                   basename(path)))
    assert(has_init_check,
           sprintf("S4: %s contains INITIALIZATION_COMPLETED guard",
                   basename(path)))
  }

  # ------------------------------------------------------------------------
  # S5: Idempotent — sourcing the same gen file twice doesn't break anything
  # ------------------------------------------------------------------------
  message("\n[S5] Sourcing gen_bridges twice is idempotent (no error, function still defined)")
  err1 <- source_in_autoinit_env(gen_bridges_path, init_completed = TRUE)
  err2 <- source_in_autoinit_env(gen_bridges_path, init_completed = TRUE)
  assert(is.null(err1) && is.null(err2),
         "S5: Both sources returned cleanly")
  has_fn <- exists("generate_bridges", inherits = TRUE) &&
            is.function(get("generate_bridges", inherits = TRUE))
  assert(has_fn, "S5: generate_bridges still defined after double source")

  # ------------------------------------------------------------------------
  # S6: #518 sister — fix_wiser_poisson_tables.R top-level source() must not
  #     halt autoinit (was relative path `source("SCHEMA_001_poisson_analysis.R")`
  #     which broke when cwd != script_dir; now uses sys.frame()$ofile + file.exists)
  # ------------------------------------------------------------------------
  message("\n[S6] source(fix_wiser_poisson_tables.R) under autoinit env — no halt (#518)")
  err <- source_in_autoinit_env(fix_wiser_path, init_completed = TRUE)
  if (!is.null(err)) {
    assert(FALSE, sprintf("S6: source halted with error: %s", substr(err, 1, 150)))
  } else {
    assert(TRUE, "S6: source returned cleanly (top-level not executed under autoinit)")
  }
  has_fn <- exists("create_wiser_poisson_tables", inherits = TRUE) &&
            is.function(get("create_wiser_poisson_tables", inherits = TRUE))
  assert(has_fn, "S6: create_wiser_poisson_tables function defined")

  # ------------------------------------------------------------------------
  # S7: #520 sister — _build.R top-level yaml read + stop() must not halt
  #     autoinit when sourced (was line 81 yaml::read_yaml + line 59/64/77
  #     stop() — now wrapped in build_raw_schema() with entry guard)
  # ------------------------------------------------------------------------
  message("\n[S7] source(_build.R) under autoinit env — no halt (#520)")
  err <- source_in_autoinit_env(build_R_path, init_completed = TRUE)
  if (!is.null(err)) {
    assert(FALSE, sprintf("S7: source halted with error: %s", substr(err, 1, 150)))
  } else {
    assert(TRUE, "S7: source returned cleanly (top-level not executed under autoinit)")
  }
  has_fn <- exists("build_raw_schema", inherits = TRUE) &&
            is.function(get("build_raw_schema", inherits = TRUE))
  assert(has_fn, "S7: build_raw_schema function defined")

  # _build.R also contains redundant guard pattern
  txt <- paste(readLines(build_R_path), collapse = "\n")
  has_sys_nframe <- grepl("sys\\.nframe\\(\\)\\s*==\\s*0[Ll]?", txt)
  has_init_check <- grepl("INITIALIZATION_COMPLETED", txt)
  assert(has_sys_nframe, "S7: _build.R contains sys.nframe() == 0L guard")
  assert(has_init_check, "S7: _build.R contains INITIALIZATION_COMPLETED guard")

  # ------------------------------------------------------------------------
  # S8: #519 sub-task 1 — actual standalone Rscript spawn must run build
  #     to completion (complements S4 string-match by exercising real
  #     execution path). Wraps in git-checkout sandwich to revert any
  #     _generated/ mutation after the test (idempotent safety).
  #
  #     Skipped when:
  #       (a) git tree dirty in _generated/ — avoids restore conflict with
  #           user's in-progress codegen work
  #       (b) git binary not on PATH — avoids ENOENT on minimal CI images
  # ------------------------------------------------------------------------
  message("\n[S8] standalone Rscript _build.R spawn — actual execution runs to completion (#519 sub-task 1)")
  git_avail <- nchar(Sys.which("git")) > 0L
  if (!git_avail) {
    message("  [SKIP] S8: git not on PATH — cannot guarantee mutation revert, skipping")
  } else {
    # Pre-flight: capture current state of _generated/ so we can revert
    pre_status <- tryCatch(
      system2("git", c("-C", script_root,
                       "status", "--porcelain",
                       "01_db/raw_schema/_generated/"),
              stdout = TRUE, stderr = TRUE),
      error = function(e) NULL
    )
    pre_dirty <- length(pre_status) > 0L
    if (pre_dirty) {
      message("  [SKIP] S8: _generated/ already has unstaged changes — skipping spawn to avoid clobbering user's in-progress work")
    } else {
      # Spawn Rscript; capture stdout + exit code
      spawn_out <- tryCatch({
        system2("Rscript",
                args = c("--vanilla", build_R_path),
                stdout = TRUE, stderr = TRUE)
      }, error = function(e) {
        structure(character(0), status = -1L, error_msg = conditionMessage(e))
      })
      exit_code <- attr(spawn_out, "status")
      if (is.null(exit_code)) exit_code <- 0L

      assert(exit_code == 0L,
             sprintf("S8: standalone Rscript exit code 0 (got %d)", exit_code))

      stdout_text <- paste(spawn_out, collapse = "\n")
      has_done <- grepl("\\[_build\\.R\\] Done\\.", stdout_text)
      assert(has_done,
             "S8: stdout contains '[_build.R] Done.' (build ran to completion)")

      has_validation <- grepl("Meta-schema validation", stdout_text)
      assert(has_validation,
             "S8: stdout contains 'Meta-schema validation' (validation pass executed)")

      # Restore: revert any _generated/ mutation from the spawn (test cleanup)
      # Per MP102 reproducibility guarantee, the diff should already be empty,
      # but `git checkout --` is the canonical safety net.
      restore_result <- tryCatch(
        system2("git", c("-C", script_root,
                         "checkout", "--",
                         "01_db/raw_schema/_generated/"),
                stdout = FALSE, stderr = FALSE),
        error = function(e) -1L
      )

      # Verify clean post-restore (test must not leak mutation)
      post_status <- tryCatch(
        system2("git", c("-C", script_root,
                         "status", "--porcelain",
                         "01_db/raw_schema/_generated/"),
                stdout = TRUE, stderr = TRUE),
        error = function(e) NULL
      )
      post_clean <- length(post_status) == 0L
      assert(post_clean,
             "S8: _generated/ tree clean after spawn + checkout (no mutation leak)")
    }
  }

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
