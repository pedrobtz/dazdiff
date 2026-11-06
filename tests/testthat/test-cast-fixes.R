# Timestamps as text --------------------------------------------------------

test_that("a timestamp is written as text in one format, midnight included", {
  p <- as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 10:00:00", NA),
    tz = "UTC"
  )
  expect_identical(
    cast_value(p, "character", "t"),
    c("2024-01-01 00:00:00", "2024-01-02 10:00:00", NA)
  )
  # All at midnight: still the full format, not the bare day.
  expect_identical(
    cast_value(p[1], "character", "t"),
    "2024-01-01 00:00:00"
  )
})

test_that("a timestamp's fraction of a second is kept, to the microsecond", {
  p <- .POSIXct(
    as.numeric(as.POSIXct("2024-01-01 10:00:00", tz = "UTC")) +
      c(0, 0.1, 0.25, 0.9999996),
    tz = "UTC"
  )
  expect_identical(
    cast_value(p, "character", "t"),
    c(
      "2024-01-01 10:00:00",
      "2024-01-01 10:00:00.1",
      "2024-01-01 10:00:00.25",
      "2024-01-01 10:00:01"
    )
  )
})

test_that("a timestamp is written in its own zone", {
  p <- as.POSIXct("2024-01-01 00:00:00", tz = "America/New_York")
  expect_identical(cast_value(p, "character", "t"), "2024-01-01 00:00:00")
})

test_that("midnight stamps align with their text in diff_table()", {
  p <- as.POSIXct(c("2024-01-01 00:00:00", "2024-01-02 10:00:00"), tz = "UTC")
  out <- diff_table(
    data.frame(t = c("2024-01-01 00:00:00", "2024-01-02 10:00:00"), v = c(1, 2)),
    data.frame(t = p, v = c(1, 2))
  )
  expect_identical(as.character(out$status), c("same", "same"))
})

test_that("normalize_dt() writes timestamps as text in the same format", {
  dt <- data.frame(t = as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 10:00:00"),
    tz = "UTC"
  ))
  expect_identical(
    normalize_dt(dt, to = c(POSIXct = "character"))$t,
    c("2024-01-01 00:00:00", "2024-01-02 10:00:00")
  )
})

# A Date written as text ----------------------------------------------------

test_that("a Date's fraction of a day is recorded when written as text", {
  out <- cast_value(as.Date(c(19723.5, 19724, NA)), "character", "d")
  expect_identical(as.vector(out), c("2024-01-01", "2024-01-02", NA))
  rec <- attr(out, "truncated")
  expect_identical(rec$n, 1L)
  expect_identical(rec$rows, 1L)
  expect_identical(rec$examples, "19723.5 -> 2024-01-01")
})

test_that("a Date's fraction of a day is refused as text with truncate = FALSE", {
  expect_error(
    cast_value(as.Date(19723.5), "character", "d", truncate = FALSE),
    class = "daffiz_error_cast"
  )
  expect_identical(
    cast_value(as.Date(19723), "character", "d", truncate = FALSE),
    "2024-01-01"
  )
})

test_that("diff_table() announces the day a text benchmark truncates", {
  expect_message(
    out <- diff_table(
      data.frame(d = "2024-01-01", v = 1),
      data.frame(d = as.Date(19723.5), v = 1)
    ),
    class = "daffiz_message_truncation"
  )
  expect_identical(as.character(out$status), "same")
  expect_identical(nrow(attr(out, "truncated")), 1L)
})

# Date storage: IDate against Date ------------------------------------------

test_that("a fractional Date is floored onto an IDate benchmark", {
  x <- data.table::data.table(
    d = data.table::as.IDate(c("2024-01-01", "2024-01-02")),
    v = c(1, 2)
  )
  y <- data.table::data.table(d = as.Date(c(19723.5, 19724)), v = c(1, 2))
  expect_message(
    out <- expect_no_warning(diff_table(x, y)),
    class = "daffiz_message_truncation"
  )
  expect_identical(as.character(out$status), c("same", "same"))
  expect_s3_class(out$D, "IDate")
  rec <- attr(out, "truncated")
  expect_identical(rec$column, "d")
  expect_identical(rec$rows, list(1L))
  expect_identical(rec$examples, "19723.5 -> 2024-01-01")
})

test_that("a fractional Date onto an IDate is refused with truncate = FALSE", {
  x <- data.table::data.table(d = data.table::as.IDate("2024-01-01"), v = 1)
  y <- data.table::data.table(d = as.Date(19723.5), v = 1)
  expect_error(
    diff_table(x, y, truncate = FALSE),
    class = "daffiz_error_cast"
  )
})

test_that("a whole Date onto an IDate benchmark takes the IDate storage", {
  x <- data.table::data.table(d = data.table::as.IDate("2024-01-01"), v = 1)
  y <- data.table::data.table(d = as.Date("2024-01-01"), v = 1)
  out <- expect_no_message(diff_table(x, y))
  expect_identical(as.character(out$status), "same")
  expect_s3_class(out$D, "IDate")
})

test_that("an IDate onto a Date benchmark becomes a double Date", {
  x <- data.table::data.table(d = as.Date(c(19723.5, 19724)), v = c(1, 2))
  y <- data.table::data.table(
    d = data.table::as.IDate(c("2024-01-01", "2024-01-02")),
    v = c(1, 2)
  )
  out <- expect_no_warning(diff_table(x, y))
  expect_true(is.double(out$D))
  expect_identical(
    as.character(out$status),
    c("only_y", "only_x", "same")
  )
})

test_that("equal mode widens an IDate against a fractional Date", {
  x <- data.table::data.table(
    d = data.table::as.IDate(c("2024-01-01", "2024-01-02")),
    v = c(1, 2)
  )
  y <- data.table::data.table(d = as.Date(c(19723.5, 19724)), v = c(1, 2))
  out <- expect_no_warning(diff_table(x, y, mode = "equal"))
  expect_true(is.double(out$D))
  expect_identical(sort(unclass(out$D)), c(19723, 19723.5, 19724))
  # The caller's tables are untouched.
  expect_true(is.integer(x$d))
})
