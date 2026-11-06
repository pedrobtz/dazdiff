# -0 and 0 are one key to a join but two groups to keyed grouping (#47).

test_that("a key holding -0 and 0 is one key in the rows shape", {
  x <- data.frame(k = c(1, -0, 0), tag = "t")
  y <- data.frame(k = c(1, 0), tag = "t")
  d <- suppressMessages(suppressWarnings(diff_table(x, y, by = "k")))
  expect_identical(sum(d$status == "only_x"), 1L)
  expect_failure(suppressMessages(expect_table_equal(x, y, by = "k")))
})

test_that("rows keyed -0 and 0 trace back to distinct source rows", {
  x <- data.frame(k = c(0, -0), s = c("a", "b"))
  d <- suppressMessages(suppressWarnings(diff_table(x, x, by = "k")))
  expect_setequal(d$row_id_y, 1:2)
  expect_identical(d$row_id_x, d$row_id_y)
})

test_that("duplicates across -0 and 0 are seen before the merge", {
  x <- data.frame(k = c(0, -0, 1), v = c(1, 2, 3))
  y <- data.frame(k = c(0, 5, 1), v = c(1, 2, 3))
  expect_warning(
    diff_table(x, y, by = "k", measures = "V"),
    class = "daffiz_warning_duplicates"
  )
  expect_error(
    diff_table(x, y, by = "k", measures = "V", duplicates = "error"),
    class = "daffiz_error_duplicates"
  )
})

test_that("Date keys at -0 and 0 aggregate as one key", {
  x <- data.frame(k = as.Date(c(0, -0)), v = 1)
  d <- diff_table(x, x, by = "k", measures = "V", duplicates = "aggregate")
  expect_identical(nrow(d), 1L)
  expect_identical(d$n_rows_x, 2L)
})

test_that("canonical_missing() leaves integer64 bits alone", {
  skip_if_not_installed("bit64")
  v <- bit64::as.integer64(c(0, NA, 3))
  expect_identical(canonical_missing(v), v)
})
