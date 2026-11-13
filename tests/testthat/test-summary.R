test_that("diff_summary counts each status per measure, in x's column order", {
  x <- data.table(id = c("a", "b", "c"), w = c(1, 2, 3), v = c(1, 2, 3))
  y <- data.table(id = c("a", "b", "d"), w = c(1, 2, 3), v = c(1, 2.5, 4))
  s <- diff_summary(diff_table(x, y))
  expect_identical(s$metric, c("W", "V"))
  expect_identical(s$n, c(4L, 4L))
  expect_identical(s$n_same, c(2L, 1L))
  expect_identical(s$n_changed, c(0L, 1L))
  expect_identical(s$n_only_x, c(1L, 1L))
  expect_identical(s$n_only_y, c(1L, 1L))
  expect_identical(s$max_abs_diff, c(0, 0.5))
  # Over the two values found in both tables.
  expect_identical(s$mean_abs_diff, c(0, 0.25))
  expect_identical(s$rmse, c(0, sqrt(0.125)))
})

test_that("mean_abs_diff is the mean of the absolute differences, not their max", {
  x <- data.table(id = 1:4, v = c(1, 2, 3, 4))
  y <- data.table(id = 1:4, v = c(1, 3, 1, 8))
  s <- diff_summary(diff_table(x, y))
  # |diff| = 0, 1, 2, 4
  expect_identical(s$max_abs_diff, 4)
  expect_identical(s$mean_abs_diff, 7 / 4)
  expect_equal(s$rmse, sqrt(21 / 4))
  expect_equal(s$max_rel_diff, 2 / 3)
})

test_that("magnitudes keep a difference that overflows to Inf", {
  # Both source values are finite; only their difference is not. Filtering on
  # the difference would report 0 for the largest difference in the table.
  x <- data.table(id = c("a", "b"), v = c(-1e308, 1))
  y <- data.table(id = c("a", "b"), v = c(1e308, 2))
  s <- diff_summary(diff_table(x, y))
  expect_identical(s$max_abs_diff, Inf)
  expect_identical(s$rmse, Inf)
})

test_that("rmse does not overflow on large finite differences", {
  x <- data.table(id = c("a", "b"), v = c(0, 0))
  y <- data.table(id = c("a", "b"), v = c(1e200, 1e200))
  expect_equal(diff_summary(diff_table(x, y))$rmse, 1e200)
})

test_that("a measure with no finite pair has NA magnitudes", {
  x <- data.table(id = "a", v = NA_real_)
  s <- diff_summary(diff_table(x, x))
  expect_true(is.na(s$max_abs_diff) && is.na(s$mean_abs_diff) && is.na(s$rmse))
})

test_that("diff_summary works on the groups and rows shapes", {
  x <- data.table(id = c("a", "a", "b"), v = c(1, 2, 3))
  g <- diff_summary(diff_table(x, x, duplicates = "aggregate"))
  expect_identical(names(g), c("metric", "n", "n_same", "n_changed", "n_only_x", "n_only_y"))
  expect_identical(g$n_same, 2L)

  expect_message(
    r <- diff_table(data.table(k = c("a", "b")), data.table(k = c("a", "c"))),
    class = "dazdiff_message_no_measures"
  )
  s <- diff_summary(r)
  expect_identical(nrow(s), 1L)
  expect_identical(c(s$n_same, s$n_only_x, s$n_only_y), c(1L, 1L, 1L))
})

test_that("diff_summary of an empty rows-shape result is one row of zeros", {
  e <- data.table(k = character())
  expect_message(d <- diff_table(e, e), class = "dazdiff_message_no_measures")
  expect_identical(attr(d, "shape"), "rows")
  expect_identical(nrow(d), 0L)
  expect_identical(
    diff_summary(d),
    data.table(n = 0L, n_same = 0L, n_changed = 0L, n_only_x = 0L, n_only_y = 0L)
  )
})

test_that("diff_summary refuses anything but a diff_table() result", {
  expect_error(diff_summary(data.table(a = 1)), class = "dazdiff_error_input")
})

# is_matching() ----------------------------------------------------------------

test_that("is_matching() reads the status by default", {
  x <- data.table(id = 1:3, v = c(100, 200, 300))
  expect_true(is_matching(diff_table(x, x)))
  expect_false(is_matching(diff_table(x, x[, .(id, v = v + c(0, 0.5, 0))])))
  expect_false(is_matching(diff_table(x, x[1:2])))
  expect_true(is_matching(diff_table(x[0], x[0])))
  expect_true(is_matching(diff_table(x, x[, .(id, v = v + 0.5)], tolerance = 1)))
})

test_that("is_matching() re-judges the values at other thresholds, both ways", {
  x <- data.table(id = 1:3, v = c(100, 200, 300))
  y <- data.table(id = 1:3, v = c(100, 200.5, 300))
  d <- diff_table(x, y)
  expect_false(is_matching(d))
  expect_true(is_matching(d, tolerance = 0.5))
  expect_false(is_matching(d, tolerance = 0.4))
  expect_true(is_matching(d, rel_tol = 0.01))
  expect_false(is_matching(d, rel_tol = 0.001))
  # Stricter than the comparison: same there, changed here.
  loose <- diff_table(x, y, tolerance = 1)
  expect_true(is_matching(loose))
  expect_false(is_matching(loose, tolerance = 0))
  # Agrees with running the comparison at the same threshold.
  for (t in c(0, 0.4, 0.5, 1)) {
    expect_identical(is_matching(d, tolerance = t), is_matching(diff_table(x, y, tolerance = t)), info = t)
  }
})

test_that("no threshold matches a missing row, or a pair that is not finite", {
  x <- data.table(id = 1:4, v = c(1, Inf, NA, NaN))
  y <- data.table(id = 1:4, v = c(1, Inf, NA, NA))
  # Equal or missing on both sides: same at any threshold.
  expect_true(is_matching(diff_table(x, y), tolerance = 0))
  expect_false(is_matching(diff_table(x, y[, .(id, v = c(1, 5, NA, NA))]), tolerance = 1e300))
  expect_false(is_matching(diff_table(x, y[, .(id, v = c(1, Inf, 3, NA))]), rel_tol = 1e300))
  expect_false(is_matching(diff_table(x, y[1:3]), tolerance = 1e300))
  # Two finite values whose difference overflows.
  big <- diff_table(data.table(id = 1L, v = -1e308), data.table(id = 1L, v = 1e308))
  expect_false(is_matching(big, tolerance = 1e300))
  expect_true(is_matching(big, rel_tol = 2))
})

test_that("is_matching() works on every shape, and refuses a tolerance on aggregates", {
  x <- data.table(k = c("a", "b", "b"), v = c(1, 2, 2))
  g <- diff_table(x, x, duplicates = "aggregate")
  expect_true(is_matching(g, tolerance = 0))
  expect_error(is_matching(g, tolerance = 1), class = "dazdiff_error_input")
  rows <- suppressMessages(diff_table(data.table(k = "a"), data.table(k = c("a", "b"))))
  expect_false(is_matching(rows, tolerance = 1))
  d <- diff_table(x[1:2], x[1:2])
  expect_error(is_matching(d, tolerance = -1), class = "dazdiff_error_input")
  expect_error(is_matching(d, rel_tol = NA), class = "dazdiff_error_input")
  expect_error(is_matching(data.table(a = 1)), class = "dazdiff_error_input")
})
