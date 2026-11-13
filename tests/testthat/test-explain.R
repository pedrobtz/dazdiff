# diff_explain() ---------------------------------------------------------------

test_that("a row matches only when every measure does", {
  e <- diff_explain(explain_fixture(), "id")
  expect_identical(e$ID, c(2L, 4L, 5L, 1L, 3L))
  expect_identical(e$class, c("differ", "differ", "differ", "same", "same"))
  expect_identical(e$n, rep(1L, 5L))
  expect_identical(e[ID == 2L, n_changed], 1L)
})

test_that("the overview classes every value, and ranks identifiers last", {
  e <- diff_explain(explain_fixture())
  expect_identical(e$column, c("REGION", "metric", "ID"))
  expect_identical(e[column == "REGION", c(same_only, differ_only, mixed)], c(1L, 2L, 1L))
  expect_identical(e[column == "ID", c(separates, identifies)], c(TRUE, TRUE))
  expect_identical(e[column == "metric", c(n_values, mixed)], c(2L, 2L))
  expect_false(e[column == "metric", identifies])
})

test_that("a column that separates without identifying leads", {
  x <- data.table(id = 1:4, grp = c("a", "a", "b", "b"), v = c(1, 2, 3, 4))
  y <- data.table(id = 1:4, grp = c("a", "a", "b", "b"), v = c(1, 2, 9, 9))
  e <- diff_explain(diff_table(x, y))
  expect_identical(e$column[1], "GRP")
  expect_true(e$separates[1])
  expect_false(e$identifies[1])
  g <- diff_explain(diff_table(x, y), "grp")
  expect_identical(g$GRP, c("b", "a"))
  expect_identical(g$class, c("differ", "same"))
})

test_that("metric counts each value on its own, and joined leaves out membership", {
  d <- explain_fixture()
  all <- diff_explain(d, "metric")
  expect_identical(all$class, c("mixed", "mixed"))
  joined <- diff_explain(d, "metric", among = "joined")
  expect_identical(joined$metric, c("AMOUNT", "UNITS"))
  expect_identical(joined$class, c("mixed", "same"))
  expect_identical(joined$n, c(3L, 3L))
  r <- diff_explain(d, "region", among = "joined")
  expect_identical(r$REGION, c("south", "east", "north"))
  expect_identical(sum(r$n_only_x + r$n_only_y), 0L)
})

test_that("membership comes from row_id, not from the value", {
  x <- data.table(id = 1:2, v = c(1, NA))
  y <- data.table(id = 1:3, v = c(1, NA, 3))
  e <- diff_explain(diff_table(x, y), "id")
  expect_identical(e[ID == 2L, class], "same")
  expect_identical(e[ID == 3L, n_only_y], 1L)
})

test_that("it explains every shape of result", {
  x <- data.table(k = c("a", "b", "b"), v = c(1, 2, 2))
  y <- data.table(k = c("a", "b"), v = c(1, 5))
  g <- diff_explain(diff_table(x, y, duplicates = "aggregate"), "k")
  expect_identical(g$class, c("differ", "same"))
  rows <- suppressMessages(diff_table(data.table(k = c("a", "b")), data.table(k = c("a", "c"))))
  e <- diff_explain(rows)
  expect_identical(e$column, "K")
  expect_identical(diff_explain(rows, "k")$class, c("differ", "differ", "same"))
  d <- diff_table(x[1:2, .(v)], y[, .(v)], row_key = "position")
  e <- diff_explain(d)
  expect_identical(e[column == "row_number", c(separates, identifies)], c(TRUE, TRUE))
})

test_that("an empty or filtered result still explains", {
  d <- explain_fixture()
  expect_identical(nrow(diff_explain(d[0], "region")), 0L)
  expect_true(all(diff_explain(d[status == "same"])$separates))
})

test_that("diff_explain() refuses what is not a key column", {
  d <- explain_fixture()
  expect_error(diff_explain(data.table(a = 1)), class = "dazdiff_error_input")
  expect_error(diff_explain(d, c("id", "region")), class = "dazdiff_error_input")
  err <- expect_error(diff_explain(d, "amount"), class = "dazdiff_error_columns")
  expect_identical(err$columns, "amount")
  expect_error(diff_explain(d, among = "some"), class = "dazdiff_error_input")
  expect_identical(diff_explain(d, "Region"), diff_explain(d, "REGION"))
})
