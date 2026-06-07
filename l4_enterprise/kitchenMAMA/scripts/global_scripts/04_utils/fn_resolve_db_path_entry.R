#' resolve_db_path_entry --------------------------------------------------------
#' Single canonical resolver for db_paths.yaml dual-shape entries.
#'
#' Replaces 2 prior inline duplicates (#512 fix):
#'   - `04_utils/fn_load_db_paths.R::resolve_db_path_entry()` (was nested-local)
#'   - `update_scripts/orchestration/fn_output_presence.R::.resolve_db_entry()`
#'     (was inline, returning richer list with `required`)
#'
#' #435 introduced structured `{path:, required:}` entries (optional DB layer
#' opt-in). Legacy scalar `<name>: relative/path.duckdb` shape remains
#' supported. Both resolvers had identical scalar/list parsing logic but
#' different returns — causing silent drift risk when the contract evolved
#' (#512). This canonical version returns the rich shape; callers needing
#' just the path access `$path`.
#'
#' Following principles:
#' - SO_R007: One Function One File
#' - MP122: Penta-Track Subrepo Architecture (cross-co shared via shared/)
#' - DM_R048: YAML for configuration
#'
#' @param entry yaml-loaded value: either character(1) scalar or list with
#'   `path` (character(1)) + optional `required` (logical(1)).
#' @param name  Entry key (for error message context).
#' @param section "databases" or "domain" (for error message context).
#' @return list(path = character(1), required = logical(1)). For legacy scalar
#'   entries, `required` defaults to TRUE (preserves #455 default).
#' @export
resolve_db_path_entry <- function(entry, name, section) {
  # Branch 1: legacy scalar string
  # #511 C3: trimws after nzchar gate guards trailing/leading whitespace
  # (yaml editing typo); we strip it on return so callers see the clean path.
  if (is.character(entry) && length(entry) == 1L &&
      !is.na(entry) && nzchar(trimws(entry))) {
    return(list(path = trimws(entry), required = TRUE))
  }

  # Branch 2: structured {path:, required:}
  # #511 C3: trimws on $path mirrors scalar branch — yaml authors easily
  # leave a trailing space on path values, which silently breaks file.exists().
  if (is.list(entry) &&
      !is.null(entry$path) &&
      is.character(entry$path) &&
      length(entry$path) == 1L &&
      !is.na(entry$path) &&
      nzchar(trimws(entry$path))) {
    required <- entry$required
    if (is.null(required)) {
      required <- TRUE  # default per #435 contract
    } else if (!is.logical(required) ||
               length(required) != 1L ||
               is.na(required)) {
      stop(sprintf(
        paste0("Invalid 'required' in db_paths.yaml %s.%s: ",
               "must be logical TRUE or FALSE (or absent). Got: %s (class=%s)"),
        section, name,
        paste(deparse(required), collapse = " "),
        paste(class(required), collapse = "/")
      ), call. = FALSE)
    }
    return(list(path = trimws(entry$path), required = required))
  }

  # Branch 3: fallthrough — invalid shape
  stop(sprintf(
    paste0("Invalid db_paths.yaml entry for %s.%s. ",
           "Use either '<name>: relative/path.duckdb' or ",
           "'<name>: {path: relative/path.duckdb, required: false}'."),
    section, name
  ), call. = FALSE)
}
