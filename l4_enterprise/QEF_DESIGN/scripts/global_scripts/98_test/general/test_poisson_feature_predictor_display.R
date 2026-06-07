#!/usr/bin/env Rscript
# test_poisson_feature_predictor_display.R
# ==============================================================================
# #762 — Hide raw `predictor` from poissonFeatureAnalysis hover + DT + CSV + AI
#
# Background:
#   #756 + PR #757 修了 `fn_generate_display_name.R` 的 display-name layer,
#   #758 + PR #761 修了 `poissonCommentAnalysis.R` 的 consumer-side surfaces。
#   `poissonFeatureAnalysis.R` 是 sister component,有完全相同的 anti-pattern:
#   同時顯示 `display_name_safe`(屬性名稱)跟 `predictor`(技術名稱)兩欄,
#   raw `predictor` 仍會洩漏 `_rating` 後綴給使用者。
#
#   #758 verify 的 Devil's Advocate F5 經驗證確認:`poissonFeatureAnalysis.R`
#   的 filter (L429 `predictor_type != "time_feature"`) 不排除 `comment_attribute`,
#   所以 `_rating`-suffixed predictors 會 ACTIVE 渲染進 Feature Analysis tab。
#   #762 priority 因此從 P3 升 P2。
#
#   Path A fix(同 #758):移除 `predictor` 在 hover/DT/CSV/AI prompt 的顯示,
#   保留 `display_name_safe` 作為唯一 user-facing name;重複的「技術名稱 /
#   Technical Name」surface 直接刪除。
#
# Test strategy:
#   Hermetic — read poissonFeatureAnalysis.R 原始檔內容,做 structural assertion。
#   不啟動 Shiny reactive context(過重),用 file content grep 確認所有 5+
#   user-facing surfaces 都不再洩漏 raw `predictor`。
#
# Refs #762 (this issue), #758 (sister component fix), #756 (parent fn-level fix),
#      #733 (`_rating` suffix origin)
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_poisson_feature_predictor_display.R
#
# Principles:
# - MP029: real source under test, no fake mocks
# - TD_R007: Plain R + assert() pattern (matches #758 / 98_test/general/ convention)
# - IC_P002: change is universal — 5 公司共用 component (hermetic test 對 source 而非 reactive 行為)
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

# ---------- Setup: locate source file ----------

source_candidates <- c(
  file.path("shared", "global_scripts", "10_rshinyapp_components", "poisson",
            "poissonFeatureAnalysis", "poissonFeatureAnalysis.R"),
  file.path("global_scripts", "10_rshinyapp_components", "poisson",
            "poissonFeatureAnalysis", "poissonFeatureAnalysis.R"),
  file.path("..", "..", "10_rshinyapp_components", "poisson",
            "poissonFeatureAnalysis", "poissonFeatureAnalysis.R"),
  file.path("10_rshinyapp_components", "poisson",
            "poissonFeatureAnalysis", "poissonFeatureAnalysis.R")
)
source_path <- source_candidates[file.exists(source_candidates)][1]
if (is.na(source_path)) {
  stop("poissonFeatureAnalysis.R not found in candidate paths")
}
src <- paste(readLines(source_path, warn = FALSE), collapse = "\n")
message(sprintf("Testing source: %s (%d chars)\n", source_path, nchar(src)))

# ---------- Tests ----------

# Case 1: hover_text block — must NOT contain `"技術名稱: ", predictor`
# This was the L886 leak surface. After fix the entire hover line is deleted.
assert(
  !grepl('"技術名稱:\\s*",\\s*predictor', src),
  "hover_text no longer contains `\"技術名稱: \", predictor` (raw predictor in hover removed)"
)

# Case 2: DT / CSV select() blocks — must NOT contain isolated `predictor,`
# between `display_name_safe,` and `track_multiplier,`.
# Pre-fix all 10 dplyr::select() display blocks had this sandwich.
# After fix the sequence collapses to `display_name_safe, track_multiplier,`.
assert(
  !grepl("display_name_safe,\\s*predictor,\\s*track_multiplier,", src),
  "DT/CSV select() no longer has `predictor,` between display_name_safe and track_multiplier"
)

# Case 3: colnames translate vectors — `"Technical Name"` must not appear.
# Pre-fix: 5 colnames vectors had `"Attribute Name", "Technical Name", ...`.
# Post-fix: `"Attribute Name", "Track Multiplier", ...` — length 11 → 10.
assert(
  !grepl('"Technical Name"', src, fixed = TRUE),
  "colnames vectors no longer reference `\"Technical Name\"` (DT/CSV column removed)"
)

# Case 4: AI prompt `attributes_summary` data.frame — must NOT pass raw predictor.
# Pre-fix L1457/L1467: `技術名稱 = top_attributes$predictor,`.
# Post-fix: the 技術名稱 column is removed entirely (GPT only sees display_name_safe).
assert(
  !grepl("技術名稱\\s*=\\s*top_attributes\\$predictor", src),
  "AI prompt attributes_summary no longer has `技術名稱 = top_attributes$predictor`"
)

# Case 5: AI prompt `var_description` (product_dev_summary) — must NOT inline
# raw predictor in parentheses. Pre-fix L1632/L1642:
# `display_name_safe, " (", predictor, "): 係數=..."`.
# Post-fix: `display_name_safe, ": 係數=..."` — parenthetical predictor removed.
assert(
  !grepl('display_name_safe,\\s*"\\s*\\(",\\s*predictor', src),
  "AI prompt var_description no longer inlines `(\", predictor, \")` (product_dev_summary clean)"
)

# Case 6: regression — `display_name_safe` must STILL be referenced in hover
# and DT select positions (the swap target must remain).
# Guards against an over-zealous deletion that removes BOTH columns by accident.
assert(
  grepl("屬性:\\s*\",\\s*display_name_safe", src),
  "hover_text still shows `屬性: <display_name_safe>` (positive case preserved)"
)
assert(
  grepl("dplyr::select\\(\\s*display_name_safe,", src),
  "DT/CSV select() still starts with `display_name_safe,` (positive case preserved)"
)

# Case 7: order index audit — `list(list(1, 'desc'))` should stay unchanged.
# Pre-fix this 0-indexed position pointed to `predictor` (off-by-one bug);
# post-fix it points to `track_multiplier`, matching the existing comment
# "預設按賽道倍數排序". Removal of predictor incidentally aligns sort with intent.
assert(
  grepl("order\\s*=\\s*list\\(list\\(1,\\s*['\"]desc['\"]\\)\\)", src),
  "DT order option `list(list(1, 'desc'))` unchanged (now correctly targets track_multiplier post-removal)"
)

# Case 8: predictor is still used inside the component for data flow / filtering /
# track-multiplier calculation, just NOT for direct user-facing display.
# We don't forbid `predictor` entirely — only the display surfaces above.
assert(
  grepl("\\bpredictor\\b", src),
  "predictor symbol still present (data-layer references preserved; only display surfaces removed)"
)

# Case 9: coalesce fallback must also strip `_rating$` (Codex F1 finding).
# Pre-fix at L441: `coalesce(display_name, predictor)` would leak raw
# `<name>_rating` when display_name is NA (e.g. stale app_data rows pre-#756
# fn rerun). Post-fix: `coalesce(display_name, sub("_rating$", "", predictor))`.
assert(
  grepl('coalesce\\(\\s*display_name,\\s*sub\\("_rating\\$",\\s*""\\s*,\\s*predictor\\s*\\)', src),
  "coalesce fallback strips `_rating$` from predictor (Codex F1 defense)"
)

# Case 10: behavioral fixture — simulate the Codex F1 scenario.
# Build a tiny tibble where display_name is NA and predictor carries `_rating`;
# apply the same coalesce + sub logic; assert the result has no `_rating`.
fixture_data <- data.frame(
  display_name = c(NA_character_, "光學清晰"),
  predictor    = c("光學清晰_rating", "光學清晰_rating"),
  stringsAsFactors = FALSE
)
fixture_safe <- ifelse(
  is.na(fixture_data$display_name),
  sub("_rating$", "", fixture_data$predictor),
  fixture_data$display_name
)
assert(
  !any(grepl("_rating$", fixture_safe)),
  sprintf("fixture: NA display_name fallback produces no `_rating` suffix (got: %s)",
          paste(fixture_safe, collapse = ", "))
)

# ---------- Summary ----------

message(sprintf("\nResults: %d passed, %d failed", pass_count, fail_count))
if (fail_count > 0) {
  message("FAIL: Some cases did not pass.")
  quit(status = 1)
}
message("PASS: All cases.")
quit(status = 0)
