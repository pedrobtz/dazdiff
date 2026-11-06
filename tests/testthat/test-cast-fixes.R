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
