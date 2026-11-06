# expect_table_equal() reads `duplicates` the way diff_table() does (#50, #42)
# and fails, rather than errors, on tables that share no key (#27).

test_that("an abbreviated duplicates value is resolved", {
  a <- data.frame(id = c(1L, 1L), v = c(1, 2))
  expect_success(expect_table_equal(a, a, duplicates = "agg"))
  expect_success(suppressWarnings(expect_table_equal(a, a, duplicates = "dis")))
})

test_that("a partially matched duplicates argument is honoured", {
  a <- data.frame(id = c(1L, 1L), v = c(1, 2))
  expect_success(suppressWarnings(expect_table_equal(a, a, dup = "disambiguate")))
  expect_success(expect_table_equal(a, a, dup = "aggregate"))
})

test_that("duplicates still raise an error by default", {
  a <- data.frame(id = c(1L, 1L), v = c(1, 2))
  expect_error(expect_table_equal(a, a), class = "dazdiff_error_duplicates")
})

test_that("tables that share no key fail the expectation", {
  expected <- data.frame(id = 1:2, v = c(1, 2))
  expect_failure(expect_table_equal(expected[0, ], expected), "one table is empty")
  expect_failure(expect_table_equal(data.frame(id = 3:4, v = c(1, 2)), expected))
})
