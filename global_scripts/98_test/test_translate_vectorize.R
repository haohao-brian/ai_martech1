#####
# Test: translate() must accept character vector input
#
# Issue #595 Phase E (Bug C):
#   dplyr::rename_with(translate, .cols = everything()) passes 200+ column names
#   as a single vector. Original translate() called `if (text %in% names(...))`
#   which threw "the condition has length > 1" when text is a vector.
#
# Reproduction: l4_enterprise/QEF_DESIGN BrandEdge -> 品牌屬性評價 with hsg
# selected. UI showed "Error: the condition has length > 1" red text.
#
# Contract: translate() should accept character vector (or character(0))
# and return a vector of equal length.
#####

library(testthat)

# Source under test — resolve path robustly across run contexts
candidates <- c(
  "shared/global_scripts/04_utils/fn_translation.R",
  "scripts/global_scripts/04_utils/fn_translation.R",
  "global_scripts/04_utils/fn_translation.R",
  "04_utils/fn_translation.R",
  "../04_utils/fn_translation.R"
)
translation_file <- Find(file.exists, candidates)
if (is.null(translation_file)) {
  stop("Cannot locate fn_translation.R; tried: ",
       paste(candidates, collapse = ", "))
}
source(translation_file)

# Build a known dictionary so we can assert exact mappings.
test_dict <- list(
  zh_TW = c(
    "Hello"     = "你好",
    "Goodbye"   = "再見",
    "Customer"  = "顧客"
  )
)

initialize_translation_system(language = "zh_TW", translation_dict = test_dict)

test_that("scalar input still works (regression)", {
  expect_equal(translate("Hello"), "你好")
  expect_equal(translate("UnknownKey"), "UnknownKey")
})

test_that("vector input returns translated vector (Bug C fix)", {
  result <- translate(c("Hello", "Goodbye", "Customer"))
  expect_equal(length(result), 3L)
  expect_equal(result, c("你好", "再見", "顧客"))
})

test_that("vector input with mix of known and unknown keys", {
  result <- translate(c("Hello", "UnknownKey", "Customer"))
  expect_equal(result, c("你好", "UnknownKey", "顧客"))
})

test_that("dplyr::rename_with usage pattern works (BrandEdge case)", {
  skip_if_not_installed("dplyr")
  df <- data.frame(Hello = 1, Goodbye = 2, Customer = 3, UnknownCol = 4)
  renamed <- dplyr::rename_with(df, translate, .cols = dplyr::everything())
  expect_equal(
    colnames(renamed),
    c("你好", "再見", "顧客", "UnknownCol")
  )
})

test_that("zero-length character input returns zero-length", {
  expect_equal(translate(character(0)), character(0))
})

test_that("NA character input passes through", {
  expect_equal(translate(NA_character_), NA_character_)
  expect_equal(translate(c("Hello", NA_character_)),
               c("你好", NA_character_))
})
