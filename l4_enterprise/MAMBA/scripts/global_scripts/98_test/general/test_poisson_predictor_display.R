#!/usr/bin/env Rscript
# test_poisson_predictor_display.R
# ==============================================================================
# #758 — Hide raw `predictor` from poissonCommentAnalysis hover + DT table
#
# Background:
#   #756 + PR #757 修了 `fn_generate_display_name.R` 的 display-name layer,
#   讓 `display_name_safe` 不含 `_rating` 後綴。但 `poissonCommentAnalysis.R`
#   原本同時顯示 `display_name_safe`(口碑指標)跟 `predictor`(技術名稱)兩欄,
#   raw `predictor` 仍會洩漏 `_rating` 給使用者。
#
#   Path A fix: 移除 `predictor` 在 hover/table 的顯示(swap → display_name_safe;
#   重複的 `技術名稱` surface 直接刪除),保留 `display_name_safe` 作為唯一
#   user-facing name。
#
# Test strategy:
#   Hermetic — read poissonCommentAnalysis.R 原始檔內容,做 structural assertion。
#   不啟動 Shiny reactive context(過重),用 file content grep 確認:
#   (a) hover_text 區塊內無 `"技術名稱: ", predictor` 殘留
#   (b) DT select() 內無 `predictor,` 殘留(在 display_name_safe 之後)
#   (c) colnames vector 內無 `"Technical Name"` 殘留
#
# Refs #758 (this issue), #756 (parent fn-level fix), #733 (suffix origin)
#
# Usage:
#   Rscript shared/global_scripts/98_test/general/test_poisson_predictor_display.R
#
# Principles:
# - MP029: real source under test, no fake mocks
# - TD_R007: Plain R + assert() pattern (matches #756 / 98_test/general/ convention)
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
            "poissonCommentAnalysis", "poissonCommentAnalysis.R"),
  file.path("global_scripts", "10_rshinyapp_components", "poisson",
            "poissonCommentAnalysis", "poissonCommentAnalysis.R"),
  file.path("..", "..", "10_rshinyapp_components", "poisson",
            "poissonCommentAnalysis", "poissonCommentAnalysis.R"),
  file.path("10_rshinyapp_components", "poisson",
            "poissonCommentAnalysis", "poissonCommentAnalysis.R")
)
source_path <- source_candidates[file.exists(source_candidates)][1]
if (is.na(source_path)) {
  stop("poissonCommentAnalysis.R not found in candidate paths")
}
src <- paste(readLines(source_path, warn = FALSE), collapse = "\n")
message(sprintf("Testing source: %s (%d chars)\n", source_path, nchar(src)))

# ---------- Tests ----------

# Case 1: hover_text block — must NOT contain `"技術名稱: ", predictor`
# This was the L613 leak surface. After fix the entire hover line is deleted.
# The hover_text is built via paste0(...) inside output$rating_multiplier_plot.
assert(
  !grepl('"技術名稱:\\s*",\\s*predictor', src),
  "hover_text no longer contains `\"技術名稱: \", predictor` (raw predictor in hover removed)"
)

# Case 2: DT select() block — must NOT contain isolated `predictor,` between
# `display_name_safe,` and `rating_type,` (the L737 leak).
# We assert: anywhere in the file, the sequence `display_name_safe,\s*predictor,\s*rating_type,`
# does NOT match. (After fix, predictor is gone, so the sequence collapses to
# `display_name_safe,\s*rating_type,`.)
assert(
  !grepl("display_name_safe,\\s*predictor,\\s*rating_type,", src),
  "DT select() no longer has `predictor,` between display_name_safe and rating_type"
)

# Case 3: colnames translate vector — `"Technical Name"` must not appear.
# Pre-fix: `c("WOM Metric", "Technical Name", "Variable Type", ...)`.
# Post-fix: `c("WOM Metric", "Variable Type", ...)` — length 10 → 9.
assert(
  !grepl('"Technical Name"', src, fixed = TRUE),
  "colnames vector no longer references `\"Technical Name\"` (DT column removed)"
)

# Case 4: regression — `display_name_safe` must STILL be referenced in both
# the hover_text and DT select positions (the swap target must remain).
# This guards against an over-zealous deletion that removes BOTH columns by accident.
assert(
  grepl("口碑指標:\\s*\",\\s*display_name_safe", src),
  "hover_text still shows `口碑指標: <display_name_safe>` (positive case preserved)"
)
assert(
  grepl("dplyr::select\\(\\s*display_name_safe,", src),
  "DT select() still starts with `display_name_safe,` (positive case preserved)"
)

# Case 5: order index audit — `list(list(2, 'desc'))` should stay unchanged.
# Pre-fix this 0-indexed position pointed to `rating_type` (off-by-one bug);
# post-fix it points to `track_multiplier`, matching the existing comment
# "預設按賽道倍數排序". Removal of predictor incidentally aligns sort with intent.
assert(
  grepl("order\\s*=\\s*list\\(list\\(2,\\s*['\"]desc['\"]\\)\\)", src),
  "DT order option `list(list(2, 'desc'))` unchanged (now correctly targets track_multiplier post-removal)"
)

# Case 6: predictor is still used inside the component for filtering / data flow,
# just NOT for direct user-facing display. We don't try to forbid `predictor`
# entirely — only the two surfaces above. Confirm the symbol still appears
# (data layer still references it).
assert(
  grepl("\\bpredictor\\b", src),
  "predictor symbol still present (data-layer references preserved; only display surfaces removed)"
)

# Case 7: coalesce fallback must also strip `_rating$` (Codex F1 finding).
# Pre-fix at L292: `coalesce(display_name, predictor)` would leak raw
# `<name>_rating` when display_name is NA (e.g. stale app_data rows pre-#756
# fn rerun). Post-fix: `coalesce(display_name, sub("_rating$", "", predictor))`.
assert(
  grepl('coalesce\\(\\s*display_name,\\s*sub\\("_rating\\$",\\s*""\\s*,\\s*predictor\\s*\\)', src),
  "coalesce fallback strips `_rating$` from predictor (Codex F1 defense)"
)

# Case 8: behavioral fixture — simulate the Codex F1 scenario.
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
