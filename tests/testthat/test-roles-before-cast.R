# Roles are decided before casting, so a column the call does not compare is
# never type-checked or cast (#48).

test_that("an ignored column that cannot be cast does not refuse the comparison", {
  x <- data.frame(id = 1:2, v = c(1, 2), loaded = as.Date(c("2024-01-01", "2024-01-02")))
  y <- data.frame(id = 1:2, v = c(1, 2), loaded = c("01/01/2024", "02/01/2024"))
  expect_message(
    d <- diff_table(x, y, by = "id", measures = "v"),
    class = "dazdiff_message_ignored_columns"
  )
  expect_identical(as.character(d$status), c("same", "same"))

  y$loaded <- c(TRUE, FALSE)
  expect_no_error(suppressMessages(diff_table(x, y, by = "id", measures = "v")))
})

test_that("an ignored column of an unsupported type is not refused", {
  x <- data.frame(id = 1:2, v = c(1, 2), at = as.POSIXct(c(0, 1), origin = "1970-01-01", tz = "UTC"))
  d <- suppressMessages(diff_table(x, x, by = "id", measures = "v"))
  expect_identical(nrow(d), 2L)
  expect_error(diff_table(x, x, by = c("id", "at")), class = "dazdiff_error_types")
})

test_that("an ignored column is not truncated or recorded", {
  x <- data.frame(id = 1:2, v = c(1, 2), n = 1:2)
  y <- data.frame(id = 1:2, v = c(1, 2), n = c(1.5, 2))
  expect_message(
    d <- diff_table(x, y, by = "id", measures = "v"),
    class = "dazdiff_message_ignored_columns"
  )
  expect_identical(nrow(attr(d, "truncated")), 0L)
})

test_that("cast = FALSE checks types of compared columns only", {
  x <- data.frame(id = 1:2, v = c(1, 2), n = 1:2)
  y <- data.frame(id = 1:2, v = c(1, 2), n = c("a", "b"))
  d <- suppressMessages(diff_table(x, y, by = "id", measures = "v", cast = FALSE))
  expect_identical(nrow(d), 2L)
})
