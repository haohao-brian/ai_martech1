#####
# Test: run_smoke_lite.R walker recursion (Phase 2)
#
# Spectra change: adaptive-dashboard-test-loop (issue #653, Phase 2)
#
# Locks contract:
#   - .smoke_extract_sub_tab_refs identifies leaf sub-tabs between
#     two top-level nav anchors in agent-browser snapshot output
#   - Filters out accordion expanders (產品線 / 平台) + radio/checkbox/button
#   - Backward compat: returns character(0) when no sub-tabs found
#####

library(testthat)

# Source under test — robust path resolution
.locate_smoke_lite <- function() {
  rel_candidates <- c(
    "shared/global_scripts/98_test/e2e/run_smoke_lite.R",
    "scripts/global_scripts/98_test/e2e/run_smoke_lite.R",
    "global_scripts/98_test/e2e/run_smoke_lite.R",
    "98_test/e2e/run_smoke_lite.R",
    "../e2e/run_smoke_lite.R",
    "e2e/run_smoke_lite.R"
  )
  hit <- Find(file.exists, rel_candidates)
  if (!is.null(hit)) return(hit)

  abs_paths <- c(
    "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/ai_martech/l4_enterprise/shared/global_scripts/98_test/e2e/run_smoke_lite.R"
  )
  Find(file.exists, abs_paths)
}
smoke_file <- .locate_smoke_lite()
if (is.null(smoke_file)) stop("Cannot locate run_smoke_lite.R")
source(smoke_file)


# ---------- Fixtures — real agent-browser snapshot patterns (refs #653) ----------

# Snapshot from 2026-05-13 visual walkthrough after clicking InsightForge 360 with
# sub-menus expanded (16 lines). InsightForge has 3 sub-tabs: 市場賽道 / 時間分析 / 精準行銷
.fixture_full_nav <- paste(
  "- link \"bars icon\" [ref=e1]",
  "- button \"\" [ref=e2]",
  "- link \"AI行銷平台\" [ref=e5]",
  "- link \"平台\" [ref=e6]",
  "- link \"產品線\" [ref=e7] [expanded]:",
  "- radio \"所有產品\" [ref=e8] [checked]",
  "- link \"gauge-high icon 總覽儀表板\" [ref=e21]",
  "- link \"tag icon TagPilot \" [ref=e22]",
  "- link \"chart-line icon Marketing Vital-Signs \" [ref=e23]",
  "- link \"gem icon BrandEdge \" [ref=e24]",
  "- link \"lightbulb icon InsightForge 360 \" [ref=e25]",
  "- link \"trophy icon 市場賽道\" [ref=e26]",
  "- link \"clock icon 時間分析\" [ref=e27]",
  "- link \"bullseye icon 精準行銷\" [ref=e28]",
  "- link \"file-lines icon 報告中心\" [ref=e29]",
  "- button \"wand-magic icon 生成整合報告\" [ref=e30]",
  sep = "\n"
)

# Snapshot with BrandEdge expanded showing 6 sub-tabs
.fixture_brandedge_expanded <- paste(
  "- link \"gauge-high icon 總覽儀表板\" [ref=e8]",
  "- link \"tag icon TagPilot \" [ref=e9]",
  "- link \"chart-line icon Marketing Vital-Signs \" [ref=e19]",
  "- link \"gem icon BrandEdge \" [ref=e20]",
  "- link \"table icon 品牌屬性評價\" [ref=e25]",
  "- link \"chart-line icon 品牌DNA\" [ref=e26]",
  "- link \"crosshairs icon 市場區隔與目標市場分析\" [ref=e27]",
  "- link \"key icon 關鍵因素分析\" [ref=e28]",
  "- link \"star icon 理想點分析\" [ref=e29]",
  "- link \"compass icon 品牌定位策略建議\" [ref=e30]",
  "- link \"lightbulb icon InsightForge 360 \" [ref=e31]",
  "- link \"file-lines icon 報告中心\" [ref=e32]",
  sep = "\n"
)

# Snapshot with no sub-tabs expanded (backward compat path)
.fixture_no_subs <- paste(
  "- link \"gauge-high icon 總覽儀表板\" [ref=e8]",
  "- link \"tag icon TagPilot \" [ref=e9]",
  "- link \"chart-line icon Marketing Vital-Signs \" [ref=e10]",
  "- link \"gem icon BrandEdge \" [ref=e11]",
  "- link \"lightbulb icon InsightForge 360 \" [ref=e12]",
  "- link \"file-lines icon 報告中心\" [ref=e13]",
  sep = "\n"
)

# Last top-level (報告中心) with no sub-tabs after it (end-of-nav case)
.fixture_last_top <- paste(
  "- link \"lightbulb icon InsightForge 360 \" [ref=e12]",
  "- link \"file-lines icon 報告中心\" [ref=e13]",
  "- button \"wand-magic icon 生成整合報告\" [ref=e14]",
  sep = "\n"
)


# ---------- .smoke_extract_sub_tab_refs ----------

test_that(".smoke_extract_sub_tab_refs finds InsightForge 3 sub-tabs (refs #653 evidence)", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_full_nav,
    this_top_label = "InsightForge 360",
    next_top_labels = "報告中心"
  )
  expect_equal(length(refs), 3L)
  expect_setequal(refs, c("@e26", "@e27", "@e28"))
})

test_that(".smoke_extract_sub_tab_refs finds BrandEdge 6 sub-tabs", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_brandedge_expanded,
    this_top_label = "BrandEdge",
    next_top_labels = "InsightForge 360"
  )
  expect_equal(length(refs), 6L)
  expect_setequal(refs, c("@e25", "@e26", "@e27", "@e28", "@e29", "@e30"))
})

test_that(".smoke_extract_sub_tab_refs returns empty for top-only nav (backward compat)", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_no_subs,
    this_top_label = "BrandEdge",
    next_top_labels = "InsightForge 360"
  )
  expect_length(refs, 0L)
})

test_that(".smoke_extract_sub_tab_refs handles last top-level (no next anchor)", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_last_top,
    this_top_label = "報告中心",
    next_top_labels = character(0)  # last item
  )
  # button is filtered, no sub-tabs expected — but if last top has trailing
  # link items they'd be included. Verify filter excludes the button.
  expect_length(refs, 0L)
})

test_that(".smoke_extract_sub_tab_refs filters main-panel links without icon prefix", {
  # Phase 2 walker regression: 報告中心 (last top-level) found 4 false-positive
  # main-panel link elements as 'sub-tabs' because they appeared between the
  # top-level and end-of-snap. Fix: filter out links without ` icon ` prefix
  # (sidebar nav convention).
  fixture_with_panel_links <- paste(
    "- link \"file-lines icon 報告中心\" [ref=e14]",
    "- link \"report row 1\" [ref=e47]",          # main panel — no icon
    "- link \"report row 2\" [ref=e59]",          # main panel — no icon
    "- link \"chart-line icon 真正子分頁\" [ref=e60]",  # legit sub-tab WITH icon
    sep = "\n"
  )
  refs <- .smoke_extract_sub_tab_refs(
    snap = fixture_with_panel_links,
    this_top_label = "報告中心",
    next_top_labels = character(0)
  )
  expect_length(refs, 1L)
  expect_equal(refs, "@e60")  # only the icon-prefixed link survives
})

test_that(".smoke_extract_sub_tab_refs filters 平台 / 產品線 accordion expanders", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_full_nav,
    this_top_label = "AI行銷平台",
    next_top_labels = "總覽儀表板"
  )
  # Between AI行銷平台 (e5) and 總覽儀表板 (e21):
  #   平台 [e6], 產品線 [e7 expanded], 所有產品 [e8 radio]
  # All filtered (平台 / 產品線 hard-coded filter terms + radio is filtered by link-only)
  expect_length(refs, 0L)
})

test_that(".smoke_extract_sub_tab_refs returns empty when top label not found", {
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_full_nav,
    this_top_label = "Nonexistent Tab",
    next_top_labels = "報告中心"
  )
  expect_length(refs, 0L)
})

test_that(".smoke_extract_sub_tab_refs walks all the way to end when next_top not found", {
  # If next_top_label arg is given but doesn't appear in snapshot, sub-tabs
  # extend to end of nav. This matters when a previous tab's sub-tabs were
  # already collapsed and re-snapshot lost the next anchor.
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_full_nav,
    this_top_label = "InsightForge 360",
    next_top_labels = "DoesNotExist"  # phantom next anchor
  )
  # Should still find 市場賽道 / 時間分析 / 精準行銷 (and possibly 報告中心 + button which gets filtered)
  expect_true(length(refs) >= 3L)
  expect_true("@e26" %in% refs)
  expect_true("@e27" %in% refs)
  expect_true("@e28" %in% refs)
})

test_that(".smoke_extract_sub_tab_refs walks remaining top labels in order", {
  # When passed multiple next_top_labels, function should use the FIRST one
  # that appears (left-to-right is natural nav order)
  refs <- .smoke_extract_sub_tab_refs(
    snap = .fixture_brandedge_expanded,
    this_top_label = "BrandEdge",
    next_top_labels = c("InsightForge 360", "報告中心")  # both present
  )
  expect_equal(length(refs), 6L)  # stops at InsightForge 360, doesn't go through 報告中心
})


# ---------- Sanity checks on existing .smoke_extract_ref unchanged ----------

test_that(".smoke_extract_ref still finds top-level items (v2 backward compat)", {
  ref <- .smoke_extract_ref(.fixture_full_nav,
                            "link\\s+\"[^\"]*總覽儀表板[^\"]*\"\\s+\\[ref=")
  expect_equal(ref, "@e21")
})
