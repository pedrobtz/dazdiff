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
    class = "dazdiff_error_cast"
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
    class = "dazdiff_message_truncation"
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
    class = "dazdiff_message_truncation"
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
    class = "dazdiff_error_cast"
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

# An empty logical column as a Date -----------------------------------------

test_that("an all-NA logical column casts to a Date of NA", {
  out <- cast_value(c(NA, NA), "Date", "d")
  expect_s3_class(out, "Date")
  expect_true(all(is.na(out)))
  expect_length(out, 2L)
  expect_identical(cast_value(NA, "integer", "d"), NA_integer_)
  expect_match(cast_rule("logical", "Date")$note, "entirely NA")
})

test_that("a logical column with values is refused as a Date", {
  expect_error(
    cast_value(c(TRUE, NA), "Date", "d"),
    class = "dazdiff_error_cast"
  )
})

test_that("diff_table() compares a Date against an empty logical column", {
  expect_message(
    out <- diff_table(
      data.frame(id = 1:2, d = as.Date(c("2024-01-01", NA))),
      data.frame(id = 1:2, d = NA)
    ),
    class = "dazdiff_message_no_measures"
  )
  expect_identical(
    as.character(out$status),
    c("only_y", "only_x", "same")
  )
})

test_that("an all-NA logical column onto an IDate takes the IDate storage", {
  x <- data.table::data.table(
    id = 1:2,
    d = data.table::as.IDate(c("2024-01-01", NA))
  )
  out <- suppressMessages(diff_table(x, data.frame(id = 1:2, d = NA)))
  expect_s3_class(out$D, "IDate")
  expect_identical(
    as.character(out$status),
    c("only_y", "only_x", "same")
  )
})

# normalize_dt()'s `to` -----------------------------------------------------

test_that("normalize_dt() adds the caller's mappings to the factor default", {
  dt <- data.frame(
    t = as.POSIXct("2024-01-01 10:00:00", tz = "UTC"),
    f = factor("a")
  )
  out <- normalize_dt(dt, to = c(POSIXct = "Date"))
  expect_identical(out$t, as.Date("2024-01-01"))
  expect_identical(out$f, "a")
})

test_that("normalize_dt() lets the caller replace the factor default", {
  out <- normalize_dt(
    data.frame(f = factor(c("a", NA))),
    to = c(factor = "character")
  )
  expect_identical(out$f, c("a", NA))
  # An empty `to` still keeps the default.
  expect_identical(
    normalize_dt(data.frame(f = factor("a")), to = character())$f,
    "a"
  )
})

test_that("normalize_dt() refuses a `to` value that is not a type", {
  err <- expect_error(
    normalize_dt(data.frame(f = factor("a")), to = c(factor = "text")),
    class = "dazdiff_error_input"
  )
  expect_match(conditionMessage(err), "\"character\"", fixed = TRUE)
  expect_match(conditionMessage(err), "factor = \"text\"", fixed = TRUE)
})

test_that("normalize_dt() refuses a `to` name it cannot convert from", {
  expect_error(
    normalize_dt(data.frame(a = 1), to = c(difftime = "numeric")),
    class = "dazdiff_error_input"
  )
  expect_error(
    normalize_dt(data.frame(a = 1), to = "character"),
    class = "dazdiff_error_input"
  )
  expect_error(
    normalize_dt(data.frame(a = 1), to = c(factor = "character", factor = "Date")),
    class = "dazdiff_error_input"
  )
  expect_error(
    normalize_dt(data.frame(a = 1), to = c(factor = NA_character_)),
    class = "dazdiff_error_input"
  )
})

# How to fix an unsupported column -----------------------------------------

test_that("diff_table() points at normalize_dt() only for what it converts", {
  x <- data.table::data.table(
    id = 1:2,
    t = as.POSIXct(c("2024-01-01 10:00:00", "2024-01-02 10:00:00"), tz = "UTC"),
    span = as.difftime(c(1, 2), units = "hours")
  )
  err <- expect_error(diff_table(x, x), class = "dazdiff_error_types")
  msg <- conditionMessage(err)
  expect_match(msg, "convert t with normalize_dt() first", fixed = TRUE)
  expect_match(
    msg,
    "normalize_dt() cannot convert difftime, so convert or drop span",
    fixed = TRUE
  )
})

test_that("diff_table() does not offer normalize_dt() for a list column", {
  x <- data.table::data.table(id = 1:2, l = list(1, "a"))
  err <- expect_error(diff_table(x, x), class = "dazdiff_error_types")
  expect_no_match(
    conditionMessage(err),
    "with normalize_dt() first",
    fixed = TRUE
  )
  expect_match(conditionMessage(err), "cannot convert list", fixed = TRUE)
})

test_that("normalize_dt() asks for `to` only for types it can convert", {
  dt <- data.frame(
    t = as.POSIXct("2024-01-01 10:00:00", tz = "UTC"),
    span = as.difftime(1, units = "hours")
  )
  err <- expect_error(normalize_dt(dt), class = "dazdiff_error_types")
  msg <- conditionMessage(err)
  expect_match(msg, "name the target type for POSIXct in `to`", fixed = TRUE)
  expect_match(msg, "cannot convert difftime", fixed = TRUE)

  err <- expect_error(normalize_dt(dt["span"]), class = "dazdiff_error_types")
  expect_no_match(conditionMessage(err), "`to`", fixed = TRUE)
})

# Out-of-range values are written in full ----------------------------------

test_that("an integer64 outside integer range is written as an integer", {
  skip_if_not_installed("bit64")
  err <- expect_error(
    cast_value(bit64::as.integer64(3000000000), "integer", "id"),
    class = "dazdiff_error_cast"
  )
  expect_match(conditionMessage(err), "outside integer range: 3000000000", fixed = TRUE)
  expect_match(conditionMessage(err), "integer64 -> integer", fixed = TRUE)
})

test_that("a double outside integer range is written in full", {
  err <- expect_error(
    cast_value(c(1e10, -Inf), "integer", "v"),
    class = "dazdiff_error_cast"
  )
  expect_match(conditionMessage(err), "10000000000, -Inf", fixed = TRUE)
})
