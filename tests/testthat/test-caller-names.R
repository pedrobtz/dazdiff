# Messages name columns as the caller wrote them (#25), and character(0)
# asks for no measures (#42).

test_that("measure and by problems quote the caller's spelling", {
  x <- data.frame(
    `order id` = c(1L, 2L), `unit price` = c(1, 2), note = c("a", "b"),
    check.names = FALSE
  )
  expect_error(
    diff_table(x, x, measures = "note"),
    "not numeric or integer: note \\(character\\)",
    class = "daffiz_error_measures"
  )
  expect_error(
    diff_table(x, x, measures = "Missing col"),
    "not a column: Missing col",
    class = "daffiz_error_measures"
  )
})

test_that("the duplicates and disjoint messages quote the caller's spelling", {
  x <- data.frame(`order id` = c(1L, 1L), `unit price` = c(1, 2), check.names = FALSE)
  expect_warning(
    diff_table(x, x, by = "order id"),
    "identity: \"order id\" \\(ORDER_ID\\)",
    class = "daffiz_warning_duplicates"
  )
  y <- data.frame(`order id` = 3:4, `unit price` = c(1, 2), check.names = FALSE)
  x <- data.frame(`order id` = 1:2, `unit price` = c(1, 2), check.names = FALSE)
  expect_error(
    diff_table(x, y, by = "order id"),
    "identity: \"order id\" \\(ORDER_ID\\)",
    class = "daffiz_error_disjoint"
  )
})

test_that("a by column only y has is said to be dropped", {
  x <- data.frame(id = 1:2, v = c(1, 2))
  y <- data.frame(id = 1:2, v = c(1, 2), extra = 1:2)
  expect_error(
    suppressMessages(diff_table(x, y, by = "extra")),
    "only `y` has, which benchmark mode drops: extra",
    class = "daffiz_error_columns"
  )
})

test_that("measures = character(0) compares whole rows", {
  x <- data.frame(id = 1:2, v = c(1, 2))
  y <- data.frame(id = 1:2, v = c(1, 3))
  expect_message(
    d <- diff_table(x, y, measures = character()),
    class = "daffiz_message_no_measures"
  )
  expect_identical(sort(as.character(d$status)), c("only_x", "only_y", "same"))
})
