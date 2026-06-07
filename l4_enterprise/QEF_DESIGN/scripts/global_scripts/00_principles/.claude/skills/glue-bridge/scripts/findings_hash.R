# findings_hash.R — deterministic sha256 over a list of finding tuples
#
# Used by run_ensemble_review.R for plateau detection: if iteration N's hash
# equals iteration N-1's hash, the ensemble loop has stopped making progress.
#
# Bound by spectra change: glue-bridge-self-converging-review (#500)
# Layer 2 helper for /glue-bridge skill self-converging loop.
#
# Determinism contract:
#   - Input order does NOT affect output (findings sorted by canonical key)
#   - NA / NULL / missing fields normalized to "" for stable hashing
#   - severity normalized: trimmed + uppercased (so "critical" / " CRITICAL " hash same as "CRITICAL")
#   - Hash covers the tuple (severity, rule_id, file, line, summary)

suppressPackageStartupMessages({
  library(digest)
})

# Normalize one field value to a deterministic string representation.
# NA / NULL / missing -> ""
# Numeric line numbers preserved as-is when finite; NA/NaN -> ""
.normalize_field <- function(x) {
  if (is.null(x) || length(x) == 0L) return("")
  if (is.na(x)) return("")
  if (is.numeric(x) && !is.finite(x)) return("")
  as.character(x)
}

# Build a canonical-key string from a finding (used for sorting + hashing).
.canonical_tuple <- function(finding) {
  severity <- toupper(trimws(.normalize_field(finding$severity)))
  rule_id  <- .normalize_field(finding$rule_id)
  file     <- .normalize_field(finding$file)
  line     <- .normalize_field(finding$line)
  summary  <- .normalize_field(finding$summary)
  paste(severity, rule_id, file, line, summary, sep = "")  # unit separator
}

#' Compute a deterministic sha256 hash over a list of findings.
#'
#' @param findings list of findings; each finding is a list/named vector with
#'   fields: severity (CRITICAL/HIGH/MEDIUM/LOW/SUGGESTION), rule_id (e.g., "MP160"),
#'   file, line, summary.
#' @return character(1) — 64-char lowercase hex sha256 digest.
#'
#' @details
#' Normalizes severity (uppercase + trim) and treats NA / NULL / missing fields
#' as empty string. Sorts findings by canonical-key tuple before hashing so that
#' input order does not affect output. Empty list produces a stable hash.
compute_findings_hash <- function(findings) {
  if (is.null(findings)) findings <- list()
  tuples <- vapply(findings, .canonical_tuple, character(1))
  sorted_tuples <- sort(tuples)
  payload <- paste(sorted_tuples, collapse = "")  # record separator
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}
