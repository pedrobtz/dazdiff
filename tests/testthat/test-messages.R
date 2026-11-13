# The wording of every condition dazdiff raises, one call per site in R/.
#
# Elsewhere the suite tells conditions apart by their class and the fields
# they carry, never by their text; the text is pinned here instead, where a
# change to it shows up as a reviewable snapshot diff. A new dazdiff_abort(),
# dazdiff_warn() or dazdiff_inform() needs a snapshot here.

# Classes ------------------------------------------------------------------------

test_that("every condition carries its kind's parent class", {
  err <- expect_error(diff_table(1, 2), class = "dazdiff_error_input")
  expect_s3_class(err, c("dazdiff_error_input", "dazdiff_error", "error", "condition"), exact = TRUE)
  expect_null(err$call)

  x <- data.table(id = c("a", "a"), v = c(1, 2))
  w <- expect_warning(diff_table(x, x), class = "dazdiff_warning_duplicates")
  expect_s3_class(w, c("dazdiff_warning_duplicates", "dazdiff_warning", "warning", "condition"), exact = TRUE)

  m <- expect_message(
    diff_table(data.table(id = "a", v = 1), data.table(id = "a", v = 1, w = 2)),
    class = "dazdiff_message_dropped_columns"
  )
  expect_s3_class(m, c("dazdiff_message_dropped_columns", "dazdiff_message", "message", "condition"), exact = TRUE)
  # message() prints conditionMessage() as is, so the newline is dazdiff's.
  expect_match(conditionMessage(m), "\n$")
})

test_that("a caller can catch any dazdiff condition by its parent class", {
  expect_error(diff_table(1, 2), class = "dazdiff_error")
  expect_warning(
    diff_table(data.table(id = c("a", "a"), v = 1:2 + 0), data.table(id = c("a", "a"), v = 1:2 + 0)),
    class = "dazdiff_warning"
  )
  expect_message(
    diff_table(data.table(k = "a"), data.table(k = "a")),
    class = "dazdiff_message"
  )
})

# fmt_names() ----------------------------------------------------------------------

test_that("fmt_names() bounds a long list of names", {
  expect_identical(fmt_names(character()), "<none>")
  expect_identical(fmt_names(c("a", "b")), "a, b")
  expect_identical(fmt_names(letters[1:10]), paste(letters[1:10], collapse = ", "))
  expect_identical(
    fmt_names(letters[1:12]),
    paste0(paste(letters[1:10], collapse = ", "), ", ... (2 more)")
  )
  expect_identical(fmt_names(letters, max_n = 2L), "a, b, ... (24 more)")
})

test_that("a message about a very wide table stays bounded", {
  x <- as.data.table(stats::setNames(as.list(seq_len(15)), sprintf("c%02d", 1:15)))
  expect_snapshot(error = TRUE, diff_table(x, data.table(c01 = 1)))
})

# diff_table() ---------------------------------------------------------------------

test_that("diff_table()'s argument errors", {
  x <- data.table(id = "a", v = 1)
  expect_snapshot(error = TRUE, diff_table(x, 1:3))
  expect_snapshot(error = TRUE, diff_table(x, x, tolerance = -1))
  expect_snapshot(error = TRUE, diff_table(x, x, rel_tol = NA))
  expect_snapshot(error = TRUE, diff_table(x, x, truncate = NA))
  expect_snapshot(error = TRUE, diff_table(x, x, nan_is_na = "yes"))
  expect_snapshot(error = TRUE, diff_table(x, x, mode = "equal", cast = TRUE))
  expect_snapshot(error = TRUE, diff_table(x, x, cast = NA))
  expect_snapshot(error = TRUE, diff_table(x, x, by = NA_character_))
  expect_snapshot(error = TRUE, diff_table(x, x, exclude = 1))
  expect_snapshot(error = TRUE, diff_table(x, x, duplicates = "aggregate", tolerance = 0.1))
})

test_that("diff_table()'s column errors and messages", {
  x <- data.table(id = c("a", "b"), note = c("p", "q"), v = c(1, 2))
  expect_snapshot(error = TRUE, diff_table(x, x[, .(id, v)]))
  expect_snapshot(invisible(diff_table(x[, .(id, v)], x)))
  expect_snapshot(error = TRUE, diff_table(x, data.table(id = "a", v = 1, w = 2), mode = "equal"))
  expect_snapshot(error = TRUE, diff_table(x, x, by = c("id", "ID", "nope")))
  expect_snapshot(error = TRUE, diff_table(x, x, by = "v", measures = "v"))
  expect_snapshot(invisible(diff_table(x, x, exclude = c("note", "nope"))))
  expect_snapshot(error = TRUE, diff_table(x, x, by = "id", exclude = "ID"))
  expect_snapshot(error = TRUE, diff_table(x, x, mode = "equal", by = "id"))
  expect_snapshot(invisible(diff_table(x, x, by = "id")))
  expect_snapshot(invisible(diff_table(data.table(k = "a"), data.table(k = "a"))))
})

test_that("diff_table()'s type errors", {
  stamp <- as.POSIXct("2024-01-01 10:00", tz = "UTC")
  expect_snapshot(
    error = TRUE,
    diff_table(data.table(t = stamp, f = factor("a"), v = 1), data.table(t = stamp, f = "a", v = 1))
  )
  x <- data.table(id = "1", v = 1)
  y <- data.table(id = 1, v = "1")
  expect_snapshot(error = TRUE, diff_table(x, y, cast = FALSE))
  expect_snapshot(error = TRUE, diff_table(x, x[, .(id, v = "1")], mode = "equal"))
})

test_that("diff_table()'s key errors", {
  expect_snapshot(error = TRUE, diff_table(data.table(v = 1), data.table(v = 1)))
})

test_that("diff_table()'s duplicate key warning and error", {
  x <- data.table(id = c("a", "a", "b"), v = c(1, 2, 3))
  expect_snapshot(invisible(diff_table(x, x)))
  expect_snapshot(error = TRUE, diff_table(x, x, duplicates = "error"))
})

test_that("diff_table()'s refusal of a comparison that aligns nothing", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  y <- data.table(id = c("A", "B"), v = c(1, 2))
  expect_snapshot(error = TRUE, diff_table(x, y))
  expect_snapshot(error = TRUE, diff_table(x, y[0]))
  expect_snapshot(
    error = TRUE,
    diff_table(
      data.table(src = "p", day = as.IDate("2024-01-01"), id = 1:5, v = 1),
      data.table(src = "d", day = as.IDate("2024-01-02"), id = 6:9, v = 1)
    )
  )
  expect_snapshot(
    error = TRUE,
    diff_table(
      data.table(run = "r1", id = 1:2, v = 1),
      data.table(run = "r2", id = 1:2, v = 1)
    )
  )
  expect_snapshot(error = TRUE, diff_table(data.table(k = "a"), data.table(k = "b")))
})

test_that("diff_table() names columns in the caller's own spelling", {
  expect_snapshot(
    error = TRUE,
    diff_table(data.table(id = 1L, `unit price` = 1), data.table(id = 1L, Unit.Price = "x"))
  )
  expect_snapshot(error = TRUE, diff_table(data.table(a = 1, A = 2), data.table(a = 1)))
  expect_snapshot(error = TRUE, diff_table(data.table(`%` = 1, a = 2), data.table(a = 1)))
})

# Casting --------------------------------------------------------------------------

test_that("cast_value()'s refusals say why", {
  expect_snapshot(error = TRUE, cast_value(c("1", "abc"), "numeric", "col"))
  expect_snapshot(error = TRUE, cast_value(c("a", "b", "c", "d"), "numeric", "THE_COL"))
  expect_snapshot(error = TRUE, cast_value("05/03/2024", "Date", "col"))
  expect_snapshot(error = TRUE, cast_value("2024-01-01junk", "Date", "col"))
  expect_snapshot(error = TRUE, cast_value("24-01-01", "Date", "col"))
  expect_snapshot(error = TRUE, cast_value(1 + .Machine$double.eps, "character", "col"))
  expect_snapshot(error = TRUE, cast_value(c("TRUE", "maybe"), "logical", "col"))
  expect_snapshot(error = TRUE, cast_value(c(0, 1), "logical", "col"))
  expect_snapshot(error = TRUE, cast_value(factor(c("a", "b")), "numeric", "col"))
  expect_snapshot(error = TRUE, cast_value("3000000000", "integer", "col"))
  expect_snapshot(error = TRUE, cast_value(complex(real = 1), "numeric", "col"))
  expect_snapshot(error = TRUE, cast_value("2024-03-05", "POSIXct", "col"))
  expect_snapshot(error = TRUE, cast_value("3.7", "integer", "col", truncate = FALSE))
  expect_snapshot(error = TRUE, cast_value(1.5, "Date", "col", truncate = FALSE))
  expect_snapshot(
    error = TRUE,
    cast_value(as.POSIXct("2024-01-01 10:00", tz = "UTC"), "Date", "col", truncate = FALSE)
  )
  expect_snapshot(error = TRUE, cast_value(NaN, "integer", "col", nan_is_na = FALSE))
  expect_snapshot(error = TRUE, cast_value("2024-01-01", "Date", "col", date_format = c("%Y", "%m")))
})

test_that("cast_value()'s refusals of integer64", {
  skip_if_not_installed("bit64")
  big <- bit64::as.integer64(c("1", "9007199254740993"))
  expect_snapshot(error = TRUE, cast_value(big, "numeric", "col"))
})

test_that("converting integer64 needs bit64", {
  skip_if_not_installed("bit64")
  v <- bit64::as.integer64(1)
  local_missing_package("bit64")
  expect_error(cast_value(v, "numeric", "col"), class = "dazdiff_error_dependency")
  expect_snapshot(error = TRUE, cast_value(v, "numeric", "col"))
})

test_that("cast_dt()'s errors and its truncation message", {
  num <- function(id) data.table(id = id, v = seq_along(id) + 0.5)
  expect_snapshot(invisible(diff_table(num(c("1.0", "2.00", "3")), num(c(1, 2, 3)))))
  expect_snapshot(invisible(diff_table(num(c("-0.0", "1.0")), num(c(0, 1)))))
  expect_snapshot(invisible(diff_table(num(c("007", "2")), num(c(7, 2)))))
  expect_snapshot(invisible(diff_table(num(c("1", "2")), num(c(1, 2)))))
  expect_snapshot(invisible(diff_table(num(c("1.0", "2.0")), num(c(1, 2)))))
  expect_snapshot(invisible(diff_table(num(c("1.2", "1.3")), num(c(1.2, 1.25)))))
  x <- data.table(a = 1L, b = 1L, c = "k")
  expect_snapshot(error = TRUE, cast_dt(x, data.frame(a = 1)))
  expect_snapshot(error = TRUE, cast_dt(x, data.table(a = 1), cols = "nope"))
  expect_snapshot(error = TRUE, cast_dt(data.table(z = complex(real = 1)), data.table(z = "1")))
  expect_snapshot(invisible(cast_dt(x, data.table(a = c(1.7, 2), b = c("3.2", "3.2"), c = "k"))))
})

test_that("normalize_dt()'s errors", {
  stamps <- data.table(t = as.POSIXct("2024-01-01 10:00", tz = "UTC"), z = complex(real = 1))
  expect_snapshot(error = TRUE, normalize_dt(1:3))
  expect_snapshot(error = TRUE, normalize_dt(stamps, cols = "nope"))
  expect_snapshot(error = TRUE, normalize_dt(stamps))
})

# Helpers --------------------------------------------------------------------------

test_that("the helpers' input errors", {
  expect_snapshot(error = TRUE, summarize_dt(1:3))
  expect_snapshot(error = TRUE, compare_columns(data.table(a = 1), 1:3))
  expect_snapshot(error = TRUE, melt_dt(1:3))
  expect_snapshot(error = TRUE, select_measures(data.table(a = 1), NA_character_))
  expect_snapshot(
    error = TRUE,
    select_measures(data.table(a = "x", b = 1), c("b", "b", "nope", "a"))
  )
  expect_snapshot(error = TRUE, diff_table(data.table(id = "a", v = 1), data.table(id = "a", v = 1), measures = "id"))
})

test_that("the key helpers' errors", {
  expect_snapshot(error = TRUE, unique_by_key(data.frame(a = 1)))
  expect_snapshot(error = TRUE, unique_by_key(data.table(a = 1)))
  expect_snapshot(error = TRUE, disambiguate_by_key(data.frame(a = 1)))
  expect_snapshot(error = TRUE, disambiguate_by_key(data.table(a = 1)))
  expect_snapshot(error = TRUE, aggregate_by_key(data.frame(a = 1)))
  expect_snapshot(error = TRUE, aggregate_by_key(data.table(a = 1)))
})

test_that("the merge helpers' errors", {
  kx <- kx_fixture()
  expect_snapshot(error = TRUE, merge_dry_run(as.data.frame(kx), ky_fixture()))
  expect_snapshot(error = TRUE, merge_dry_run(data.table(a = 1), data.table(a = 1)))
  expect_snapshot(error = TRUE, merge_dry_run(kx, ky_fixture(), on = "nope"))
  expect_snapshot(error = TRUE, merge_dt(as.data.frame(kx), ky_fixture()))
  expect_snapshot(
    error = TRUE,
    merge_dt(
      setkey(data.table(id = c("a", "a"), v = 1:2), id),
      setkey(data.table(id = c("a", "a"), w = 1:2), id)
    )
  )
  expect_snapshot(
    error = TRUE,
    merge_dt(setkey(data.table(id = 1L, a = 1, a_y = 5), id), setkey(data.table(id = 1L, a = 7), id))
  )
})

# Results ----------------------------------------------------------------------------

test_that("diff_summary() and diff_report()'s errors", {
  d <- diff_table(x3_fixture(), y3_fixture())
  expect_snapshot(error = TRUE, diff_summary(data.table(a = 1)))
  expect_snapshot(error = TRUE, diff_report(d, x_name = ""))
  expect_snapshot(error = TRUE, diff_explain(d, 1))
  expect_snapshot(error = TRUE, diff_explain(d, "v"))
  expect_snapshot(error = TRUE, diff_report(d, sample_k = 1.5))
  expect_snapshot(error = TRUE, format(diff_report(d), unicode = NA))
})

# expect_table_equal() ---------------------------------------------------------------

test_that("expect_table_equal()'s errors", {
  expected <- data.table(id = c("a", "a"), v = c(1, 2))
  expect_snapshot(error = TRUE, expect_table_equal(expected, expected, max_rows = -1))
  expect_snapshot(error = TRUE, expect_table_equal(expected[2:1], expected))
  local_missing_package("testthat")
  expect_snapshot(error = TRUE, expect_table_equal(expected, expected))
})

test_that("a choice argument outside its choices is a classed input error", {
  x <- data.frame(id = 1:2, v = c(1, 2))
  expect_error(diff_table(x, x, row_key = "random"), class = "dazdiff_error_input")
  expect_identical(
    suppressMessages(diff_table(x, x, mode = "eq"))$status,
    suppressMessages(diff_table(x, x, mode = "equal"))$status
  )
  expect_snapshot(diff_table(x, x, duplicates = "ignore"), error = TRUE)
})
