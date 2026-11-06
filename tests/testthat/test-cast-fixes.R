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
