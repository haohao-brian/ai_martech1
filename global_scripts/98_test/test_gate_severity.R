#####
# Test: dashboard_presence_gate.R severity behavior (MP165 9.2)
#
# Locks Tier 2 severity logic: critical -> refuse deploy (exit 1);
# warning -> report + allow (exit 0 by default --allow-warnings).
#####

library(testthat)

# Source the gate script — only definitions; main() guarded by sys.nframe()
gate_path <- Find(file.exists, c(
  "shared/global_scripts/23_deployment/dashboard_presence_gate.R",
  "scripts/global_scripts/23_deployment/dashboard_presence_gate.R",
  "global_scripts/23_deployment/dashboard_presence_gate.R",
  "23_deployment/dashboard_presence_gate.R",
  "../../23_deployment/dashboard_presence_gate.R",
  "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/shared/global_scripts/23_deployment/dashboard_presence_gate.R"
))
source(gate_path)


# ---------- format_gate_report severity behavior ----------

test_that("format_gate_report says REFUSE DEPLOY on any critical failure", {
  results <- list(
    list(pass = TRUE, severity = "critical", selector = "ok"),
    list(pass = FALSE, severity = "critical", selector = "bad-kpi", message = "kpi=0")
  )
  rpt <- format_gate_report(results, "QEF_DESIGN", allow_warnings = TRUE)
  expect_match(rpt, "REFUSE DEPLOY")
  expect_match(rpt, "Critical failed:\\s*1")
})

test_that("format_gate_report says PASS with warnings when only warnings fail", {
  results <- list(
    list(pass = TRUE, severity = "critical", selector = "ok"),
    list(pass = FALSE, severity = "warning", selector = "soft-fail", message = "msg")
  )
  rpt <- format_gate_report(results, "QEF_DESIGN", allow_warnings = TRUE)
  expect_match(rpt, "PASS \\(with warnings")
  expect_no_match(rpt, "REFUSE DEPLOY")
})

test_that("format_gate_report says REFUSE DEPLOY with --block-warnings on warning failure", {
  results <- list(
    list(pass = FALSE, severity = "warning", selector = "soft-fail", message = "msg")
  )
  rpt <- format_gate_report(results, "QEF_DESIGN", allow_warnings = FALSE)
  expect_match(rpt, "REFUSE DEPLOY")
})

test_that("format_gate_report says PASS when all critical+warning satisfied", {
  results <- list(
    list(pass = TRUE, severity = "critical", selector = "a"),
    list(pass = TRUE, severity = "warning", selector = "b")
  )
  rpt <- format_gate_report(results, "QEF_DESIGN", allow_warnings = TRUE)
  expect_match(rpt, "PASS: all contracts satisfied")
})

test_that("format_gate_report includes failure detail per selector", {
  results <- list(
    list(pass = FALSE, severity = "critical",
         selector = "position-position_table",
         message = "rows = 0 (1 placeholder excluded)")
  )
  rpt <- format_gate_report(results, "QEF_DESIGN", allow_warnings = TRUE)
  expect_match(rpt, "position-position_table", fixed = TRUE)
  expect_match(rpt, "1 placeholder excluded", fixed = TRUE)
  expect_match(rpt, "CRITICAL")
})


# ---------- Default opts: allow_warnings TRUE ----------

test_that("parse_args defaults allow_warnings to TRUE (Tier 2 spec: warnings do not block)", {
  opts <- parse_args(c("--company", "QEF_DESIGN"))
  expect_true(opts$allow_warnings)
})

test_that("parse_args --block-warnings flips allow_warnings to FALSE", {
  opts <- parse_args(c("--company", "QEF_DESIGN", "--block-warnings"))
  expect_false(opts$allow_warnings)
})

test_that("parse_args --dry-run flag works", {
  opts <- parse_args(c("--company", "QEF_DESIGN", "--dry-run"))
  expect_true(opts$dry_run)
})


# ---------- Tier 1 vs Tier 2 contract: severity is Tier 2 concept ----------
# (Tier 1 lite check in 6.1 uses NULL output detection only; severity is
#  not applied at Tier 1. This test documents the design intent that
#  Tier 1 lite ignores severity by NOT having a severity parameter.)

test_that("Tier 1 lite NULL detection has no severity parameter", {
  # Expected design: run_dashboard_smoke_lite_check (6.1) does NOT take
  # a severity argument. Whether the function exists yet depends on
  # whether 6.1 has been implemented.
  if (exists("run_dashboard_smoke_lite_check", mode = "function")) {
    fmls <- formals(run_dashboard_smoke_lite_check)
    expect_false("severity" %in% names(fmls),
                 info = "Tier 1 lite must not parameterize severity")
  } else {
    skip("run_dashboard_smoke_lite_check not yet implemented (task 6.1)")
  }
})
