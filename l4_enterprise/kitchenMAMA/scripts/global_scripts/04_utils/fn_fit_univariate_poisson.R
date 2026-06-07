# fn_fit_univariate_poisson.R
# Per-predictor univariate Poisson regression with per-predictor NA filtering.
#
# Extracted from `update_scripts/DRV/D04/D04_02.R` per the #755 fix. The script
# previously did a GLOBAL complete-case `tidyr::drop_na()` on the whole
# (sales + ~150 predictor) table before the univariate loop — wrong for a
# univariate design, where model k only needs (sales, predictor_k) non-NA.
# With heterogeneous NA patterns (the #733 `_rating` JOIN), global complete-case
# returned 0 rows and zeroed 8/12 product lines.
#
# This helper does NA filtering PER PREDICTOR: each `glm(sales ~ predictor_k)`
# fits on its own maximal non-NA subset. It also emits per-predictor `n_obs`
# (#755 — real sample size, replacing the single global row count) and
# `drop_reason` (#718 — explainable dropped rate).
#
# Refs #755 (per-predictor NA filter), #718 (drop-reason classification)
# Principle: MP163 (estimate what you can; don't drop rows for absent inputs),
#            DM_R066 (platform-agnostic — no platform coupling here).

#' Fit univariate Poisson regressions, one per predictor, with per-predictor
#' NA filtering.
#'
#' Each predictor `k` is fit as `glm(sales ~ k, family = poisson())` on the
#' subset of rows where both `sales` and `k` are non-NA. This is the correct
#' completeness scope for a univariate design — model k is unaffected by NA in
#' predictor j (j != k).
#'
#' @param model_data data.frame containing a numeric `sales` column plus the
#'   predictor columns. `sales` is assumed already non-NA (the caller drops
#'   sales-NA rows upstream); any residual sales-NA rows are dropped per
#'   predictor anyway.
#' @param predictor_cols Character vector of predictor column names to fit.
#'
#' @return data.frame, one row per predictor, with columns:
#'   predictor, coefficient, std_error, z_value, p_value, conf_low, conf_high,
#'   incidence_rate_ratio, irr_conf_low, irr_conf_high, deviance, aic,
#'   convergence, estimation_status, n_obs, drop_reason.
#'
#'   `estimation_status` is `"estimated"` or `"not_estimable"`.
#'   `drop_reason` is NA for estimated predictors; for `not_estimable` it is one
#'   of: `"insufficient_rows"` (< 2 non-NA rows), `"constant_in_subset"`
#'   (predictor has < 2 distinct values within its non-NA subset), `"aliased"`
#'   (glm dropped the term), `"glm_error"` (glm threw), `"missing_column"`
#'   (predictor name not in `model_data` — defensive, current callers cannot
#'   trigger this by construction but kept so helper never zeros a PL).
#'
#' @export
fit_univariate_poisson <- function(model_data, predictor_cols) {

  if (!is.data.frame(model_data)) {
    stop("fit_univariate_poisson: 'model_data' must be a data.frame.")
  }
  if (!"sales" %in% names(model_data)) {
    stop("fit_univariate_poisson: 'model_data' must contain a 'sales' column.")
  }
  if (is.null(predictor_cols) || length(predictor_cols) == 0L) {
    stop("fit_univariate_poisson: 'predictor_cols' must be a non-empty vector.")
  }

  # One NA-filled result row — used for every not_estimable / error outcome so
  # the output column set is identical across predictors.
  na_row <- function(predictor, convergence, drop_reason, n_obs) {
    data.frame(
      predictor            = predictor,
      coefficient          = NA_real_,
      std_error            = NA_real_,
      z_value              = NA_real_,
      p_value              = NA_real_,
      conf_low             = NA_real_,
      conf_high            = NA_real_,
      incidence_rate_ratio = NA_real_,
      irr_conf_low         = NA_real_,
      irr_conf_high        = NA_real_,
      deviance             = NA_real_,
      aic                  = NA_real_,
      convergence          = convergence,
      estimation_status    = "not_estimable",
      n_obs                = as.integer(n_obs),
      drop_reason          = drop_reason,
      stringsAsFactors     = FALSE
    )
  }

  results <- vector("list", length(predictor_cols))

  for (i in seq_along(predictor_cols)) {
    predictor <- predictor_cols[i]

    # ---- Defensive: predictor not in model_data ----
    # Current production callers co-derive `predictor_cols` and `model_data`
    # via `select(sales, all_of(predictor_cols))` so this branch is unreachable
    # in normal flow. Kept so any future caller that passes mismatched lists
    # gets a per-predictor sentinel row instead of crashing the whole loop with
    # base R's cryptic "undefined columns selected".
    if (!predictor %in% names(model_data)) {
      results[[i]] <- na_row(predictor, "skipped", "missing_column", 0L)
      next
    }

    # ---- Per-predictor NA filter (#755) ----
    # Only (sales, predictor) needs to be complete for this univariate model.
    pred_df <- model_data[, c("sales", predictor), drop = FALSE]
    pred_df <- pred_df[stats::complete.cases(pred_df), , drop = FALSE]
    n_obs <- nrow(pred_df)

    # ---- #718 drop-reason: insufficient rows ----
    if (n_obs < 2L) {
      results[[i]] <- na_row(predictor, "skipped", "insufficient_rows", n_obs)
      next
    }

    # ---- #718 drop-reason: constant within the non-NA subset ----
    # A predictor non-constant globally can still be constant inside its own
    # non-NA subset; glm would alias the term. Catch it explicitly so the
    # dropped count is explainable rather than a black box.
    pred_vals <- pred_df[[predictor]]
    n_distinct <- if (is.factor(pred_vals)) {
      length(unique(droplevels(pred_vals)))
    } else {
      length(unique(pred_vals))
    }
    if (n_distinct < 2L) {
      results[[i]] <- na_row(predictor, "dropped", "constant_in_subset", n_obs)
      next
    }

    # ---- Fit ----
    fit_result <- tryCatch({
      # Backtick-quote the predictor — names may be non-ASCII (Chinese review
      # attributes) or otherwise non-syntactic.
      formula_str <- paste0("sales ~ `", predictor, "`")
      model <- stats::glm(stats::as.formula(formula_str),
                          data = pred_df, family = stats::poisson())

      coef_info <- broom::tidy(model, conf.int = TRUE, conf.level = 0.95)
      # The predictor term may appear backticked or bare in the tidy output.
      term_row <- coef_info[coef_info$term %in% c(predictor,
                                                  paste0("`", predictor, "`")), ,
                            drop = FALSE]

      if (nrow(term_row) == 0L) {
        # glm aliased / dropped the term.
        na_row(predictor, "dropped", "aliased", n_obs)
      } else {
        stats_glance <- broom::glance(model)
        data.frame(
          predictor            = predictor,
          coefficient          = term_row$estimate[1L],
          std_error            = term_row$std.error[1L],
          z_value              = term_row$statistic[1L],
          p_value              = term_row$p.value[1L],
          conf_low             = term_row$conf.low[1L],
          conf_high            = term_row$conf.high[1L],
          incidence_rate_ratio = exp(term_row$estimate[1L]),
          irr_conf_low         = exp(term_row$conf.low[1L]),
          irr_conf_high        = exp(term_row$conf.high[1L]),
          deviance             = stats_glance$deviance[1L],
          aic                  = stats_glance$AIC[1L],
          convergence          = if (isTRUE(model$converged)) "converged"
                                 else "not_converged",
          estimation_status    = "estimated",
          n_obs                = as.integer(n_obs),
          drop_reason          = NA_character_,
          stringsAsFactors     = FALSE
        )
      }
    }, error = function(e) {
      na_row(predictor, "error", "glm_error", n_obs)
    })

    results[[i]] <- fit_result
  }

  do.call(rbind, results)
}
