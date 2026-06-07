#!/usr/bin/env Rscript
# test_check_db_locks_system_daemon.R
# ==============================================================================
# Test suite for .is_system_daemon_command() helper (#452)
#
# Background (from #452):
#   #437 DuckDB lock pre-flight check falsely flags macOS system daemons
#   (mdworker_shared, fileproviderd, Time Machine etc.) that hold fd on
#   .duckdb files in Dropbox/CloudStorage. The daemons are read-only
#   indexers/sync coordinators — NOT competing RW writers — but the original
#   lsof-based detection treats any fd holder as hostile. Result: every
#   `make run PLATFORM=*` intermittently aborts in the middle of pipeline.
#
# Fix: exclude holders whose command line starts with /System/Library/*,
# /System/iOSSupport/*, /System/Applications/*, /usr/sbin/*, /usr/libexec/*.
# These are macOS-canonical daemon paths (non-writable to user, cryptographic
# signature required → low spoof risk).
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_check_db_locks_system_daemon.R
#
# Principles:
# - MP029: No fake data — test commands are verbatim production strings from
#   issue #452 reproduction logs (mdworker_shared + fileproviderd exact paths)
# - TD_R007: Plain R + assert() pattern, consistent with
#   test_check_db_locks.R / test_dplyr_coalesce_prefix.R
# ==============================================================================

# ---------- Locate and source fn_check_db_locks.R ----------

fn_candidates <- c(
  file.path("scripts", "global_scripts", "04_utils", "fn_check_db_locks.R"),
  file.path("global_scripts", "04_utils", "fn_check_db_locks.R"),
  file.path("..", "global_scripts", "04_utils", "fn_check_db_locks.R"),
  file.path("..", "..", "global_scripts", "04_utils", "fn_check_db_locks.R"),
  file.path("..", "..", "04_utils", "fn_check_db_locks.R")
)
fn_path <- fn_candidates[file.exists(fn_candidates)][1]
if (is.na(fn_path)) {
  stop("fn_check_db_locks.R not found in expected paths")
}
source(fn_path)

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

main <- function() {
  message("=== test_check_db_locks_system_daemon (#452) ===")

  # ---- Scenario A: Real mdworker_shared command from #452 Run 1 log ----
  message("\n[A] Real Spotlight mdworker_shared command → excluded")
  cmd_a <- paste(
    "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks",
    "Metadata.framework/Versions/A/Support/mdworker_shared -s mdworker",
    "-c MDSImporterWorker -m com.apple.mdworker.shared", sep = "/"
  )
  assert(isTRUE(.is_system_daemon_command(cmd_a)),
         sprintf("mdworker_shared identified as daemon"))

  # ---- Scenario B: Real fileproviderd command from #452 Run 2 log ----
  message("\n[B] Real fileproviderd command → excluded")
  cmd_b <- paste0(
    "/System/Library/PrivateFrameworks/FileProvider.framework",
    "/Support/fileproviderd"
  )
  assert(isTRUE(.is_system_daemon_command(cmd_b)),
         "fileproviderd identified as daemon")

  # ---- Scenario C: Normal R session → NOT daemon (must remain detected) ----
  message("\n[C] Normal R/Rscript command → NOT daemon (keep reporting)")
  cmd_c1 <- "/Library/Frameworks/R.framework/Resources/R --vanilla --no-restore --no-save"
  cmd_c2 <- "/opt/homebrew/bin/Rscript /path/to/app.R"
  cmd_c3 <- "/Applications/RStudio.app/Contents/MacOS/RStudio"
  assert(!isTRUE(.is_system_daemon_command(cmd_c1)),
         sprintf("R framework not daemon; cmd='%s'", substr(cmd_c1, 1, 50)))
  assert(!isTRUE(.is_system_daemon_command(cmd_c2)),
         sprintf("homebrew Rscript not daemon; cmd='%s'", substr(cmd_c2, 1, 50)))
  assert(!isTRUE(.is_system_daemon_command(cmd_c3)),
         sprintf("RStudio not daemon; cmd='%s'", substr(cmd_c3, 1, 50)))

  # ---- Scenario D: Additional daemon paths ----
  message("\n[D] Other canonical daemon paths → excluded")
  cmd_d1 <- "/usr/sbin/cupsd"
  cmd_d2 <- "/usr/libexec/bluetoothd"
  cmd_d3 <- "/System/iOSSupport/somed"
  cmd_d4 <- "/System/Applications/Mail.app/Contents/MacOS/Mail"
  assert(isTRUE(.is_system_daemon_command(cmd_d1)), "cupsd excluded")
  assert(isTRUE(.is_system_daemon_command(cmd_d2)), "bluetoothd excluded")
  assert(isTRUE(.is_system_daemon_command(cmd_d3)), "iOSSupport path excluded")
  assert(isTRUE(.is_system_daemon_command(cmd_d4)), "System Applications excluded")

  # ---- Scenario E: Edge cases — empty / NA / whitespace ----
  message("\n[E] Edge: empty/NA/whitespace → NOT daemon (treat as normal)")
  assert(!isTRUE(.is_system_daemon_command("")), "empty string not daemon")
  assert(!isTRUE(.is_system_daemon_command(NA_character_)), "NA not daemon")
  assert(!isTRUE(.is_system_daemon_command("  ")), "whitespace-only not daemon")
  assert(!isTRUE(.is_system_daemon_command(NULL)), "NULL not daemon")

  # ---- Scenario F: Path traversal lookalike (should NOT match) ----
  message("\n[F] Non-canonical paths that LOOK similar → NOT daemon")
  cmd_f1 <- "/tmp/System/Library/fake"          # not prefix match
  cmd_f2 <- "/home/user/system/library/thing"   # lowercase
  cmd_f3 <- "relative/System/Library/x"         # relative
  assert(!isTRUE(.is_system_daemon_command(cmd_f1)),
         "non-prefix /tmp/System/... not daemon")
  assert(!isTRUE(.is_system_daemon_command(cmd_f2)),
         "lowercase path not daemon")
  assert(!isTRUE(.is_system_daemon_command(cmd_f3)),
         "relative path not daemon")

  # ---- Summary ----
  message(sprintf("\n=== Results: %d passed / %d failed ===",
                  pass_count, fail_count))
  if (fail_count > 0L) {
    stop(sprintf("TEST FAILED: %d assertion(s) failed", fail_count))
  }
  message("All scenarios passed ✓")
}

main()
