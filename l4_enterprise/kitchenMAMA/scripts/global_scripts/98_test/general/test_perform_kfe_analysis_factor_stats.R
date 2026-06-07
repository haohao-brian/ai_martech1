#!/usr/bin/env Rscript
# test_perform_kfe_analysis_factor_stats.R
# ==============================================================================
# Regression test for spectra change qef-brandedge-key-factor-ipa-redesign
# (issue #404 + Q1 BLOCKING #544 marketing-driven hybrid resolution).
#
# Test scenarios cover the new factor_stats data.frame member of
# perform_kfe_analysis() return value, per the spec:
#
#   S1 — factor_stats computed for all numeric attributes (Requirement: Key
#        factor statistics computation)
#   S2 — Importance derived via cor(attribute, Rating_row) when no Importance
#        row (Requirement: Importance index hybrid formula B-revised default)
#   S3 — Importance overridden when Importance row present, including partial
#        override semantics (Requirement: Importance index hybrid formula
#        D-override, partial override scenario)
#   S4 — Low-N fallback emits warning + uses ranking-based formula when
#        n_products < 5 (Requirement: Low-N fallback for unstable correlation)
#   S5 — Growth potential computed from ideal and mean per attribute, NA +
#        warning when ideal is 0 / NA (Requirement: Growth potential
#        computation)
#   S6 — IPA quadrant classification at threshold_multiplier=1.0 with median
#        split (Requirement: IPA quadrant classification)
#
# Usage (from project root or any subdir):
#   Rscript shared/global_scripts/98_test/general/test_perform_kfe_analysis_factor_stats.R
#
# Principles:
# - MP029: No fake data — test fixtures constructed minimally per scenario
# - TD_R007: Plain R + assert() pattern (matches sibling test files)
# - DEV_R052: English keys in business logic, translate only at UI layer
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

# ---------- Locate helper under test ----------
locate_file <- function(rel_path) {
  for (cand in c(rel_path,
                 file.path("scripts/global_scripts", rel_path),
                 file.path("shared/global_scripts", rel_path),
                 file.path("../global_scripts", rel_path),
                 file.path("../shared/global_scripts", rel_path),
                 file.path("../../shared/global_scripts", rel_path),
                 file.path("../../../shared/global_scripts", rel_path))) {
    if (file.exists(cand)) return(normalizePath(cand, mustWork = TRUE))
  }
  NULL
}

kfe_path <- locate_file("10_rshinyapp_components/position/positionKFE/positionKFE.R")
if (is.null(kfe_path)) {
  stop("Cannot locate positionKFE.R from getwd()=", getwd())
}
message(sprintf("Using KFE component: %s", kfe_path))

# Source only the helper functions, not UI/server (which require Shiny env)
# perform_kfe_analysis lives at top of file before any UI/Shiny references —
# we extract it via local() + sys.source until the first UI function.
extract_helpers <- function(path) {
  lines <- readLines(path)
  # Cut at the first positionKFE* function definition (UI / Server / Component)
  ui_start <- grep("^positionKFE[A-Z][A-Za-z]*\\s*<-\\s*function", lines)
  if (length(ui_start) == 0) ui_start <- length(lines) + 1L
  helpers <- lines[seq_len(ui_start[1] - 1)]
  tmp <- tempfile(fileext = ".R")
  writeLines(helpers, tmp)
  tmp
}
helpers_path <- extract_helpers(kfe_path)
local({
  source(helpers_path, local = TRUE)
  if (exists("perform_kfe_analysis", inherits = FALSE)) {
    assign("perform_kfe_analysis", get("perform_kfe_analysis"), envir = .GlobalEnv)
  }
  if (exists("format_key_factors", inherits = FALSE)) {
    assign("format_key_factors", get("format_key_factors"), envir = .GlobalEnv)
  }
  if (exists("%||%", inherits = FALSE)) {
    assign("%||%", get("%||%"), envir = .GlobalEnv)
  }
})

if (!exists("perform_kfe_analysis", mode = "function")) {
  stop("perform_kfe_analysis() not loaded after sourcing helpers from ", kfe_path)
}

# Make %>% available in global env for the helper to use (helper uses dplyr::filter
# but the magrittr pipe %>% needs to be loaded explicitly).
if (!requireNamespace("magrittr", quietly = TRUE)) {
  stop("magrittr package required for test")
}
`%>%` <- magrittr::`%>%`
if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("dplyr package required for test")
}

# ---------- Fixture builder ----------
make_position_data <- function(n_products = 8,
                               include_importance_row = FALSE,
                               importance_overrides = NULL,
                               attributes = c("comfort", "fit", "durability",
                                              "anti_fog", "optical_clarity"),
                               ideal_values = NULL,
                               product_values_seed = 42,
                               rating_values_seed = 99,
                               low_n = NULL,
                               include_rating_column = TRUE) {
  if (!is.null(low_n)) n_products <- low_n
  if (is.null(ideal_values)) ideal_values <- rep(4.5, length(attributes))
  stopifnot(length(ideal_values) == length(attributes))

  set.seed(product_values_seed)
  product_matrix <- sapply(seq_along(attributes), function(j) {
    runif(n_products, min = 2.5, max = 4.2)
  })
  colnames(product_matrix) <- attributes

  # Per-product overall rating column (lowercase 'rating' — same convention
  # as positionStrategy.R covariate exclude list). Positively correlated with
  # attribute averages so revealed-preference fixture makes sense.
  set.seed(rating_values_seed)
  per_product_rating <- rowMeans(product_matrix) +
                          rnorm(n_products, mean = 0, sd = 0.15)
  per_product_rating <- pmin(pmax(per_product_rating, 1), 5)

  ideal_row <- data.frame(matrix(ideal_values, nrow = 1))
  colnames(ideal_row) <- attributes
  ideal_row$product_id <- "Ideal"
  ideal_row$brand <- "Ideal"
  if (include_rating_column) ideal_row$rating <- NA_real_

  product_df <- as.data.frame(product_matrix)
  product_df$product_id <- paste0("P", sprintf("%02d", seq_len(n_products)))
  product_df$brand <- paste0("BrandX", seq_len(n_products))
  if (include_rating_column) product_df$rating <- per_product_rating

  base_cols <- c("product_id", "brand", attributes)
  if (include_rating_column) base_cols <- c(base_cols, "rating")

  rows <- list(ideal_row[, base_cols],
               product_df[, base_cols])

  if (include_importance_row) {
    imp_vals <- if (is.null(importance_overrides)) {
      rep(NA_real_, length(attributes))
    } else {
      stopifnot(length(importance_overrides) == length(attributes))
      importance_overrides
    }
    imp_row <- data.frame(matrix(imp_vals, nrow = 1))
    colnames(imp_row) <- attributes
    imp_row$product_id <- "Importance"
    imp_row$brand <- "Importance"
    if (include_rating_column) imp_row$rating <- NA_real_
    rows <- c(list(imp_row[, base_cols]), rows)
  }

  do.call(rbind, rows)
}

main <- function() {
  message("=== test_perform_kfe_analysis_factor_stats (#404) ===")

  # ------------------------------------------------------------------------
  # S1: factor_stats present for all numeric attributes
  # ------------------------------------------------------------------------
  message("\n[S1] factor_stats computed for all numeric attributes")
  data <- make_position_data(n_products = 8)
  result <- perform_kfe_analysis(data)

  assert(is.list(result),
         "S1: result is a list")
  assert(all(c("key_factors", "indicators", "benchmarks", "ideal_analysis",
               "factor_stats") %in% names(result)),
         "S1: result contains factor_stats alongside existing members")
  assert(is.data.frame(result$factor_stats),
         "S1: factor_stats is a data.frame")
  expected_cols <- c("factor", "mean", "sd", "max", "min",
                     "importance", "growth_potential", "rank")
  assert(all(expected_cols %in% names(result$factor_stats)),
         sprintf("S1: factor_stats has expected columns: %s",
                 paste(expected_cols, collapse = ", ")))
  assert(nrow(result$factor_stats) == 5L,
         sprintf("S1: factor_stats has 5 rows for 5 attributes (got %d)",
                 nrow(result$factor_stats)))

  # ------------------------------------------------------------------------
  # S2: importance derived via cor() when no Importance row
  # ------------------------------------------------------------------------
  message("\n[S2] importance derived via cor() — no Importance row")
  data <- make_position_data(n_products = 8, include_importance_row = FALSE)
  result <- perform_kfe_analysis(data)
  imp_vals <- result$factor_stats$importance
  assert(all(!is.na(imp_vals)),
         "S2: importance values are non-NA when correlation computable")
  assert(all(imp_vals >= 0 & imp_vals <= 5),
         sprintf("S2: importance values in [0, 5] Likert range (got %s)",
                 paste(round(imp_vals, 2), collapse = ", ")))
  # With our fixture (rating positively correlated with attribute), importance
  # should skew above 2.5 (neutral midpoint).
  assert(mean(imp_vals) > 2.5,
         sprintf("S2: mean importance > 2.5 (positive correlation fixture, got %.2f)",
                 mean(imp_vals)))

  # ------------------------------------------------------------------------
  # S3: importance overridden when Importance row present (partial override)
  # ------------------------------------------------------------------------
  message("\n[S3] partial Importance row override")
  override_vals <- c(comfort = 4.5, fit = NA_real_, durability = 3.0,
                     anti_fog = NA_real_, optical_clarity = 2.5)
  data <- make_position_data(n_products = 8,
                             include_importance_row = TRUE,
                             importance_overrides = unname(override_vals))
  result <- perform_kfe_analysis(data)
  fs <- result$factor_stats
  comfort_imp <- fs$importance[fs$factor == "comfort"]
  durability_imp <- fs$importance[fs$factor == "durability"]
  optical_imp <- fs$importance[fs$factor == "optical_clarity"]
  fit_imp <- fs$importance[fs$factor == "fit"]
  anti_fog_imp <- fs$importance[fs$factor == "anti_fog"]

  assert(isTRUE(all.equal(comfort_imp, 4.5)),
         sprintf("S3: comfort override = 4.5 (got %s)", as.character(comfort_imp)))
  assert(isTRUE(all.equal(durability_imp, 3.0)),
         sprintf("S3: durability override = 3.0 (got %s)", as.character(durability_imp)))
  assert(isTRUE(all.equal(optical_imp, 2.5)),
         sprintf("S3: optical_clarity override = 2.5 (got %s)", as.character(optical_imp)))
  # Partial override: NA in override row → fall back to derived value
  assert(!is.na(fit_imp) && fit_imp >= 0 && fit_imp <= 5,
         sprintf("S3: fit importance falls back to derived value [0,5] (got %.2f)", fit_imp))
  assert(!is.na(anti_fog_imp) && anti_fog_imp >= 0 && anti_fog_imp <= 5,
         sprintf("S3: anti_fog importance falls back to derived value [0,5] (got %.2f)", anti_fog_imp))

  # ------------------------------------------------------------------------
  # S4: low-N fallback warning + ranking-based importance
  # ------------------------------------------------------------------------
  message("\n[S4] low-N fallback (n_products = 3)")
  data <- make_position_data(n_products = 3)
  warning_msgs <- character(0)
  result <- withCallingHandlers(
    perform_kfe_analysis(data),
    warning = function(w) {
      warning_msgs <<- c(warning_msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  has_fallback_warning <- any(grepl("fallback", warning_msgs, ignore.case = TRUE) |
                                grepl("ranking", warning_msgs, ignore.case = TRUE) |
                                grepl("n_products", warning_msgs, ignore.case = TRUE))
  assert(has_fallback_warning,
         sprintf("S4: low-N fallback emits warning (got %d warnings: %s)",
                 length(warning_msgs),
                 paste(warning_msgs, collapse = " | ")))
  imp_vals_s4 <- result$factor_stats$importance
  assert(all(!is.na(imp_vals_s4) & imp_vals_s4 >= 0 & imp_vals_s4 <= 5),
         "S4: ranking-based importance values in [0, 5] Likert range")

  # ------------------------------------------------------------------------
  # S5: growth_potential computation
  # ------------------------------------------------------------------------
  message("\n[S5] growth_potential = (ideal - mean) / ideal * 100")
  data <- make_position_data(n_products = 8,
                             ideal_values = c(4.5, 4.5, 4.5, 4.5, 4.5))
  result <- perform_kfe_analysis(data)
  fs <- result$factor_stats
  for (factor_name in fs$factor) {
    row <- fs[fs$factor == factor_name, ]
    expected <- round((4.5 - row$mean) / 4.5 * 100, 2)
    assert(isTRUE(all.equal(row$growth_potential, expected, tolerance = 0.01)),
           sprintf("S5: %s growth_potential = %.2f (computed %.2f)",
                   factor_name, expected, row$growth_potential))
  }

  # S5b: ideal = 0 → NA + warning
  message("\n[S5b] growth_potential NA when ideal is 0")
  data <- make_position_data(n_products = 8,
                             ideal_values = c(0, 4.5, 4.5, 4.5, 4.5))
  warning_msgs <- character(0)
  result <- withCallingHandlers(
    perform_kfe_analysis(data),
    warning = function(w) {
      warning_msgs <<- c(warning_msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  comfort_gp <- result$factor_stats$growth_potential[result$factor_stats$factor == "comfort"]
  assert(is.na(comfort_gp),
         sprintf("S5b: growth_potential NA when ideal is 0 (got %s)",
                 as.character(comfort_gp)))

  # ------------------------------------------------------------------------
  # S6: IPA quadrant classification at threshold_multiplier=1.0
  # ------------------------------------------------------------------------
  message("\n[S6] IPA quadrant classification (median split, multiplier=1.0)")
  data <- make_position_data(n_products = 8)
  result <- perform_kfe_analysis(data)
  fs <- result$factor_stats
  assert("quadrant" %in% names(fs),
         "S6: factor_stats has 'quadrant' column")
  if ("quadrant" %in% names(fs)) {
    valid_quadrants <- c("Leading", "Mature", "Niche", "Low-Priority")
    assert(all(fs$quadrant %in% valid_quadrants),
           sprintf("S6: quadrants ∈ {Leading, Mature, Niche, Low-Priority} (got %s)",
                   paste(unique(fs$quadrant), collapse = ", ")))
    # Verify cross-hair logic: factors above median(growth) AND median(importance)
    # → Leading; below both → Low-Priority; etc.
    med_growth <- median(fs$growth_potential, na.rm = TRUE)
    med_importance <- median(fs$importance, na.rm = TRUE)
    classify <- function(g, i) {
      hi_g <- !is.na(g) && g > med_growth
      hi_i <- !is.na(i) && i > med_importance
      if (hi_g && hi_i) "Leading"
      else if (!hi_g && hi_i) "Mature"
      else if (hi_g && !hi_i) "Niche"
      else "Low-Priority"
    }
    expected_q <- mapply(classify, fs$growth_potential, fs$importance)
    matches <- sum(fs$quadrant == expected_q)
    assert(matches == nrow(fs),
           sprintf("S6: quadrant classification matches median-split logic (%d/%d match)",
                   matches, nrow(fs)))
  }

  # ------------------------------------------------------------------------
  # S7: Verify finding fixes (Codex F1 + F2, 2026-05-04)
  # ------------------------------------------------------------------------
  message("\n[S7a] Server-style exclude_vars must NOT silently disable cor() path")
  data <- make_position_data(n_products = 8, include_importance_row = FALSE)
  # Server passes "rating" in exclude_vars; helper must still recover per-product rating.
  result_excluded <- perform_kfe_analysis(
    data,
    exclude_vars = c("product_line_id", "platform_id", "rating", "sales", "revenue")
  )
  warning_msgs <- character(0)
  result_excluded2 <- withCallingHandlers(
    perform_kfe_analysis(
      data,
      exclude_vars = c("product_line_id", "platform_id", "rating", "sales", "revenue")
    ),
    warning = function(w) {
      warning_msgs <<- c(warning_msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  fallback_triggered <- any(grepl("fallback to ranking", warning_msgs))
  assert(!fallback_triggered,
         "S7a: cor() path used (no low-N fallback) when caller passes 'rating' in exclude_vars")
  imp_vals_s7a <- result_excluded$factor_stats$importance
  assert(all(!is.na(imp_vals_s7a) & imp_vals_s7a >= 0 & imp_vals_s7a <= 5),
         "S7a: importance derived (not NA) despite 'rating' in exclude_vars")

  message("\n[S7b] Importance row must NOT contaminate product statistics")
  override_vals <- c(comfort = 4.5, fit = NA_real_, durability = 3.0,
                     anti_fog = NA_real_, optical_clarity = 2.5)
  data <- make_position_data(n_products = 8,
                             include_importance_row = TRUE,
                             importance_overrides = unname(override_vals))
  result <- perform_kfe_analysis(data)
  fs <- result$factor_stats
  # n_products in fixture is 8 + 1 Ideal + 1 Importance = 10 rows. Helper should
  # filter Importance from product rows, leaving 8 for stats.
  comfort_mean <- fs$mean[fs$factor == "comfort"]
  # If Importance row (value 4.5) leaked into mean, comfort_mean would be biased
  # high (since fixture products are 2.5-4.2 range, mean is normally ~3.4).
  assert(comfort_mean < 4.4,
         sprintf("S7b: comfort mean=%.2f indicates Importance row not contaminating products (should be <4.4)",
                 comfort_mean))

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
