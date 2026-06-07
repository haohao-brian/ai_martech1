#!/usr/bin/env Rscript

# Test: fn_check_db_locks utility (#437 DuckDB lock pre-flight)
#
# Verifies check_db_locks() correctly identifies foreign R processes holding
# a DuckDB file's write lock, and correctly excludes the caller's own PID
# (so a script RW-connecting to a db doesn't flag itself).

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

# --- Locate repo root ------------------------------------------------------
this_file <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile %||% commandArgs(trailingOnly = FALSE)[4],
                mustWork = FALSE),
  error = function(e) NA_character_
)
repo_root <- if (!is.na(this_file) && nzchar(this_file)) {
  normalizePath(file.path(dirname(this_file), "..", "..", "..", ".."))
} else getwd()

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

util_file <- file.path(repo_root, "shared", "global_scripts", "04_utils",
                       "fn_check_db_locks.R")
if (!file.exists(util_file)) {
  alt <- c(
    file.path("shared", "global_scripts", "04_utils", "fn_check_db_locks.R"),
    file.path("scripts", "global_scripts", "04_utils", "fn_check_db_locks.R")
  )
  util_file <- alt[file.exists(alt)][1]
  if (is.na(util_file)) stop("fn_check_db_locks.R not found")
}
source(util_file)

# --- Fixtures --------------------------------------------------------------

expect <- function(label, ok, detail = "") {
  status <- if (isTRUE(ok)) "PASS" else "FAIL"
  msg <- sprintf("[%s] %s%s", status, label,
                 if (nzchar(detail)) paste0(" \u2014 ", detail) else "")
  message(msg)
  invisible(isTRUE(ok))
}

tmpdir <- tempfile("db_lock_test_")
dir.create(tmpdir, recursive = TRUE)
on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

# Seed duckdb files
path_fake   <- file.path(tmpdir, "fake_does_not_exist.duckdb")
path_free   <- file.path(tmpdir, "free.duckdb")
path_self   <- file.path(tmpdir, "self_held.duckdb")
path_other  <- file.path(tmpdir, "other_held.duckdb")

# Create and immediately close free db
ec <- dbConnect(duckdb::duckdb(), path_free, read_only = FALSE)
dbDisconnect(ec, shutdown = TRUE)
# Create the others likewise so file exists
for (p in c(path_self, path_other)) {
  ec <- dbConnect(duckdb::duckdb(), p, read_only = FALSE)
  dbDisconnect(ec, shutdown = TRUE)
}

results <- list()

# --- Scenario 1: file missing → graceful skip ------------------------------
r1 <- check_db_locks(list(fake = path_fake))
results$missing_file_skipped <- expect(
  "missing file: no error, empty holders",
  length(r1) == 0L
)

# --- Scenario 2: free file → empty holders ---------------------------------
r2 <- check_db_locks(list(free = path_free))
results$free_file_empty <- expect(
  "free file: no lock holders",
  length(r2) == 0L
)

# --- Scenario 3: self holds lock → excluded by default --------------------
self_con <- dbConnect(duckdb::duckdb(), path_self, read_only = FALSE)
r3 <- check_db_locks(list(self_held = path_self))
results$self_excluded <- expect(
  "self PID excluded from holders (RW connect in same process)",
  length(r3) == 0L,
  sprintf("got %d holders", length(r3))
)
dbDisconnect(self_con, shutdown = TRUE)

# --- Scenario 4: foreign R subprocess holds lock → returned with PID/cmd --
# Launch a detached Rscript that opens path_other RW and sleeps. Write its
# PID to a sentinel file so we can verify the detector picks it up.

pid_file <- file.path(tmpdir, "child.pid")
child_script <- file.path(tmpdir, "child.R")
writeLines(sprintf('
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})
writeLines(as.character(Sys.getpid()), "%s")
con <- dbConnect(duckdb::duckdb(), "%s", read_only = FALSE)
Sys.sleep(20)
try(dbDisconnect(con, shutdown = TRUE), silent = TRUE)
', pid_file, path_other), child_script)

system2("Rscript", c("--vanilla", child_script), wait = FALSE,
        stdout = FALSE, stderr = FALSE)

# Wait up to 5s for the child to write its pid and open the lock
child_pid <- NA_integer_
for (i in 1:25) {
  if (file.exists(pid_file)) {
    child_pid <- as.integer(readLines(pid_file)[1])
    if (!is.na(child_pid)) {
      # Give it an extra moment to take the duckdb lock
      Sys.sleep(0.4)
      break
    }
  }
  Sys.sleep(0.2)
}

# Make sure we kill the subprocess at the end even if assertions throw
on.exit({
  if (!is.na(child_pid)) {
    try(tools::pskill(child_pid), silent = TRUE)
    try(system2("kill", c("-9", child_pid), stdout = FALSE, stderr = FALSE),
        silent = TRUE)
  }
}, add = TRUE)

results$child_pid_captured <- expect(
  "child subprocess started and wrote PID sentinel",
  !is.na(child_pid) && child_pid > 0L,
  sprintf("child_pid=%s", child_pid)
)

r4 <- check_db_locks(list(other_held = path_other))
child_holders <- Filter(function(h) isTRUE(h$pid == child_pid), r4)

results$foreign_pid_detected <- expect(
  "foreign subprocess PID appears in holders list",
  length(child_holders) >= 1L,
  sprintf("r4 length=%d, child_pid=%s", length(r4), child_pid)
)

if (length(child_holders) >= 1L) {
  h <- child_holders[[1]]
  results$holder_has_command <- expect(
    "holder entry includes 'command' field (non-empty)",
    !is.null(h$command) && nzchar(h$command),
    sprintf("command='%s'", h$command %||% "")
  )
  results$holder_has_user <- expect(
    "holder entry includes 'user' field (non-empty)",
    !is.null(h$user) && nzchar(h$user),
    sprintf("user='%s'", h$user %||% "")
  )
  results$holder_has_db_name <- expect(
    "holder entry includes 'db_name' matching input key",
    identical(h$db_name, "other_held"),
    sprintf("db_name='%s'", h$db_name %||% "")
  )
} else {
  results$holder_has_command <- expect("holder_has_command (skipped, no holder)", FALSE)
  results$holder_has_user    <- expect("holder_has_user (skipped, no holder)",    FALSE)
  results$holder_has_db_name <- expect("holder_has_db_name (skipped, no holder)", FALSE)
}

# --- Summary ---------------------------------------------------------------
passed <- sum(vapply(results, isTRUE, logical(1)))
total  <- length(results)
message(sprintf("\n==== %d / %d assertions passed ====", passed, total))

if (passed < total) quit(status = 1)
invisible(TRUE)
