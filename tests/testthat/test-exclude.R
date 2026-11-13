# exclude ----------------------------------------------------------------------

test_that("exclude leaves a column out of both tables, in either spelling", {
  x <- data.table(id = 1:2, v = c(1, 2), note = c("p", "q"))
  y <- data.table(ID = 1:2, V = c(1, 2), Note = c("r", "s"))
  d <- expect_no_message(diff_table(x, y, mode = "equal", exclude = "NOTE"))
  expect_true(all(d$status == "same"))
  expect_identical(attr(d, "excluded"), c("note", "Note"))
  expect_identical(attr(d, "ignored"), character())
  expect_false("NOTE" %in% attr(d, "name_map")$column)
})

test_that("an excluded column need not be in both tables", {
  x <- data.table(id = 1:2, v = c(1, 2), w = c(3, 4))
  y <- data.table(id = 1:2, v = c(1, 2), loaded_at = "today")
  # x's w would be missing from y; y's loaded_at would be dropped.
  d <- expect_no_message(diff_table(x, y, exclude = c("w", "loaded_at")))
  expect_true(all(d$status == "same"))
  expect_identical(attr(d, "dropped"), character())
  expect_identical(attr(d, "excluded"), c("w", "loaded_at"))
  d <- diff_table(x, y[, .(id, v)], mode = "equal", exclude = "w")
  expect_true(all(d$status == "same"))
})

test_that("an excluded measure is not compared, and an excluded key not aligned on", {
  x <- data.table(id = 1:2, batch = c("a", "b"), v = c(1, 2), w = c(3, 4))
  y <- data.table(id = 1:2, batch = c("z", "z"), v = c(1, 2), w = c(9, 9))
  d <- diff_table(x, y, exclude = c("batch", "w"))
  expect_identical(unique(d$metric), "V")
  expect_true(all(d$status == "same"))
  expect_identical(key(d), c("ID", "metric"))
})

test_that("excluding a column is never cast or type-checked", {
  x <- data.table(id = 1:2, v = c(1, 2), when = as.POSIXct("2024-01-01", tz = "UTC"))
  y <- data.table(id = 1:2, v = c(1, 2), when = "garbage")
  expect_error(diff_table(x, y), class = "dazdiff_error_types")
  expect_true(all(diff_table(x, y, exclude = "when")$status == "same"))
})

test_that("excluding a normalized name settles a collision on it", {
  x <- data.frame(id = 1:2, v = c(1, 2), Amount = 1, amount = 2)
  expect_error(diff_table(x, x), class = "dazdiff_error_columns")
  d <- diff_table(x, x, exclude = "AMOUNT")
  expect_identical(attr(d, "excluded"), c("Amount", "amount"))
})

test_that("an empty exclude excludes nothing", {
  x <- base_fixture()
  expect_identical(
    diff_table(x, x, exclude = character()),
    diff_table(x, x)
  )
})

test_that("exclude refuses unknown names and names by or measures use", {
  x <- data.table(id = 1:2, v = c(1, 2), w = c(3, 4))
  err <- expect_error(diff_table(x, x, exclude = c("w", "nope")), class = "dazdiff_error_columns")
  expect_identical(err$columns, "nope")
  err <- expect_error(diff_table(x, x, by = "id", exclude = "ID"), class = "dazdiff_error_columns")
  expect_identical(err$columns, "ID")
  err <- expect_error(diff_table(x, x, measures = "v", exclude = "v"), class = "dazdiff_error_columns")
  expect_identical(err$columns, "v")
  expect_error(diff_table(x, x, exclude = 1), class = "dazdiff_error_input")
  expect_error(diff_table(x, x, exclude = NA_character_), class = "dazdiff_error_input")
})

test_that("a measure keyword is not read as a column name to clash with", {
  x <- data.table(id = 1:2, NUMERIC = c(1, 2), v = c(3, 4))
  d <- diff_table(x, x, measures = "numeric", exclude = "NUMERIC")
  expect_identical(unique(d$metric), "V")
})

test_that("expect_table_equal() passes exclude on", {
  x <- data.table(id = 1:2, v = c(1, 2), w = c(3, 4))
  y <- data.table(id = 1:2, v = c(1, 2), w = c(5, 6))
  expect_table_equal(y, x, exclude = "w")
})
