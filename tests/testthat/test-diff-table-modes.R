# Modes ---------------------------------------------------------------------

test_that("benchmark mode drops y's extra columns, with a message", {
  x <- data.table(id = 1:2, v = c(1, 2))
  y <- data.table(id = 1:2, v = c(1, 2), loaded_at = "today")
  m <- expect_message(d <- diff_table(x, y), class = "daffiz_message_dropped_columns")
  expect_identical(m$columns, "loaded_at")
  expect_true(all(d$status == "same"))
  expect_identical(attr(d, "dropped"), "loaded_at")
  expect_false(any(grepl("LOADED", names(d))))
})

test_that("benchmark mode refuses a column the benchmark has and y lacks", {
  x <- data.table(id = 1:2, v = c(1, 2), w = c(3, 4))
  y <- data.table(id = 1:2, v = c(1, 2))
  err <- expect_error(diff_table(x, y), class = "daffiz_error_columns")
  expect_identical(err$columns, "w")
})

test_that("equal mode needs every column on both sides, and says which", {
  x <- data.table(id = 1:2, v = c(1, 2), w = c(3, 4))
  y <- data.table(id = 1:2, v = c(1, 2), z = "z")
  err <- expect_error(diff_table(x, y, mode = "equal"), class = "daffiz_error_columns")
  expect_identical(err$only_x, "w")
  expect_identical(err$only_y, "z")
})

test_that("equal mode casts nothing, and refuses to be asked to", {
  x <- data.table(id = 1:2, v = c(1, 2))
  y <- data.table(id = 1:2, v = c("1", "2"))
  err <- expect_error(diff_table(x, y, mode = "equal"), class = "daffiz_error_types")
  expect_identical(err$columns, "V")
  expect_error(diff_table(x, x, mode = "equal", cast = TRUE), class = "daffiz_error_input")
  # The same tables compare in benchmark mode, which casts.
  expect_true(all(diff_table(x, y)$status == "same"))
})

test_that("equal mode is symmetric", {
  x <- data.table(id = c("a", "b", "c"), n = c(1L, 2L, 3L), v = c(1, 2, 3))
  y <- data.table(id = c("a", "b", "d"), n = c(1L, 5L, 4L), v = c(1.5, 2, 4))
  for (measures in list("numeric", "numeric+integer", "v")) {
    for (by in list(NULL, c("id", "n"))) {
      if (identical(measures, "numeric+integer") && !is.null(by)) next
      case <- paste0("measures = ", measures, ", by = ", paste(by, collapse = "+"))
      xy <- diff_table(x, y, mode = "equal", measures = measures, by = by)
      yx <- diff_table(y, x, mode = "equal", measures = measures, by = by)
      swap <- c(same = "same", changed = "changed", only_x = "only_y", only_y = "only_x")
      expect_identical(unname(swap[as.character(yx$status)]), as.character(xy$status), info = case)
      expect_equal(yx$diff, -xy$diff, info = case)
      expect_identical(yx$row_id_x, xy$row_id_y, info = case)
    }
  }
})

test_that("both modes give the same answer when there is nothing to cast or drop", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  y <- data.table(id = c("a", "b"), v = c(1, 3))
  expect_identical(
    as.character(diff_table(x, y)$status),
    as.character(diff_table(x, y, mode = "equal")$status)
  )
})

# Column names --------------------------------------------------------------

test_that("columns pair by their normalized names, and the result uses them", {
  x <- data.table(id = 1:2, `unit price` = c(1, 2))
  y <- data.table(ID = 1:2, Unit.Price = c(1, 2))
  d <- diff_table(x, y, mode = "equal")
  expect_identical(names(d)[1:2], c("ID", "metric"))
  expect_identical(unique(d$metric), "UNIT_PRICE")
  expect_identical(attr(d, "name_map")$name_y, c("ID", "Unit.Price"))
})

test_that("a user column named like an internal one cannot collide with it", {
  x <- data.table(row_id = c(10L, 20L), metric = c("m", "n"), status = c("p", "q"), value = c(1, 2))
  y <- x[2:1]
  d <- diff_table(x, y)
  expect_identical(key(d), c("ROW_ID", "METRIC", "STATUS", "metric"))
  expect_identical(d$STATUS, c("p", "q"))
  expect_true(all(d$status == "same"))
})

test_that("a name collision is an error, in either table", {
  err <- expect_error(
    diff_table(data.table(a = 1, A = 2), data.table(a = 1)),
    class = "daffiz_error_columns"
  )
  expect_identical(c(err$side, err$columns), c("x", "a", "A"))
  err <- expect_error(
    diff_table(data.table(id = "a", v = 1), data.table(id = "a", v = 1, V = 2)),
    class = "daffiz_error_columns"
  )
  expect_identical(c(err$side, err$columns), c("y", "v", "V"))
})

test_that("in benchmark mode a collision among y's dropped columns does not matter", {
  x <- data.table(id = "a", v = 1)
  y <- data.table(id = "a", v = 1, foo = 1, Foo = 2)
  expect_true(suppressMessages(diff_table(x, y))$status == "same")
  expect_error(
    diff_table(x, y, mode = "equal"),
    class = "daffiz_error_columns"
  )
})

# Casting and truncation ------------------------------------------------------

test_that("truncation in benchmark mode is announced and recorded", {
  x <- data.table(id = c("a", "b"), n = c(1L, 2L))
  y <- data.table(id = c("a", "b"), n = c(1.7, 2))
  # A message, not a warning: expect_no_warning() pipelines must pass.
  expect_no_warning(
    m <- expect_message(
      d <- diff_table(x, y, measures = "numeric+integer"),
      class = "daffiz_message_truncation"
    )
  )
  expect_identical(m$truncated$examples, "1.7 -> 1")
  expect_true(all(d$status == "same"))
  expect_identical(attr(d, "truncated")$column, "n")
  expect_identical(attr(d, "truncated")$n, 1L)
  err <- expect_error(
    diff_table(x, y, measures = "numeric+integer", truncate = FALSE),
    class = "daffiz_error_cast"
  )
  expect_identical(c(err$column, err$from, err$to), c("n", "numeric", "integer"))
})

test_that("the record names every truncated row, as row_id_y", {
  # More distinct values than the message has examples for.
  x <- data.table(id = c("a", "b", "c", "d", "e"), n = 1:5)
  y <- data.table(id = c("e", "d", "c", "b", "a"), n = c(5.1, 4, 3.3, 2.2, 1.9))
  d <- suppressMessages(diff_table(x, y, measures = "numeric+integer"))
  rec <- attr(d, "truncated")
  expect_identical(rec$rows, list(c(1L, 3L, 4L, 5L)))
  expect_setequal(d[row_id_y %in% rec$rows[[1]], ID], c("e", "c", "b", "a"))
})

test_that("a truncated key's rows can be found among the matches", {
  d <- suppressMessages(diff_table(data.frame(id = 1:2, v = 1), data.frame(id = c(1.5, 2), v = 1)))
  expect_true(all(d$status == "same"))
  rec <- attr(d, "truncated")
  expect_identical(rec$column, "id")
  expect_identical(d[row_id_y %in% rec$rows[[1]], ID], 1L)
})

test_that("the record keeps its rows under duplicates = \"aggregate\"", {
  d <- suppressMessages(diff_table(
    data.frame(id = c(1L, 1L), v = c(1, 2)),
    data.frame(id = c(1.2, 1), v = c(1, 2)),
    duplicates = "aggregate"
  ))
  expect_identical(attr(d, "shape"), "groups")
  expect_identical(attr(d, "truncated")$rows, list(1L))
})

test_that("a comparison that truncated nothing has an empty record", {
  rec <- attr(diff_table(data.frame(id = 1L, v = 1), data.frame(id = 1L, v = 1)), "truncated")
  expect_identical(nrow(rec), 0L)
  expect_named(rec, c("column", "n", "examples", "rows"))
})

test_that("a cast error names the column in the tested table's spelling", {
  err <- expect_error(
    diff_table(data.table(id = 1, `unit price` = 1), data.table(id = 1, Unit.Price = "x")),
    class = "daffiz_error_cast"
  )
  expect_identical(err$column, "\"Unit.Price\" (UNIT_PRICE)")
})

# Measures and identity -------------------------------------------------------

test_that("measures can be chosen by type or by name, in either spelling", {
  x <- data.table(id = c("a", "b"), n = c(1L, 2L), v = c(1, 2), w = c(3, 4))
  y <- data.table(id = c("a", "b"), n = c(1L, 2L), v = c(1, 9), w = c(3, 4))
  expect_setequal(diff_table(x, y)$metric, c("V", "W"))
  expect_setequal(diff_table(x, y, measures = "numeric+integer")$metric, c("N", "V", "W"))
  d <- diff_table(x, y, measures = c("V", "n"))
  expect_setequal(d$metric, c("V", "N"))
  # W was not named, so it is part of the identity, matched exactly.
  expect_true("W" %in% key(d))
})

test_that("measures = \"numeric\" is the keyword even beside a column called numeric", {
  # Keywords are lowercase and normalized names never are, so the column,
  # NUMERIC once normalized, is never what the keyword means.
  x <- data.table(id = c("a", "b"), numeric = c(1, 2), other = c(3, 4))
  y <- data.table(id = c("a", "b"), numeric = c(1, 5), other = c(3, 4))
  d <- diff_table(x, y, measures = "numeric")
  expect_identical(unique(d$metric), c("NUMERIC", "OTHER"))
  expect_identical(d[status == "changed", paste(ID, metric)], "b NUMERIC")
  # Named in its own spelling, it is the column.
  d <- diff_table(x, y, measures = "NUMERIC")
  expect_identical(unique(d$metric), "NUMERIC")
  expect_true("OTHER" %in% key(d))
})

test_that("a named measure that is not numeric is refused", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  err <- expect_error(diff_table(x, x, measures = "id"), class = "daffiz_error_measures")
  expect_identical(err$columns, "ID")
})

test_that("by picks the identity; other columns are ignored in benchmark mode", {
  x <- data.table(id = c("a", "b"), note = c("p", "q"), v = c(1, 2))
  y <- data.table(id = c("a", "b"), note = c("p", "CHANGED"), v = c(1, 2))
  m <- expect_message(d <- diff_table(x, y, by = "id"), class = "daffiz_message_ignored_columns")
  expect_identical(m$columns, "NOTE")
  expect_true(all(d$status == "same"))
  expect_identical(attr(d, "ignored"), "NOTE")
  expect_identical(key(d), c("ID", "metric"))
})

test_that("equal mode refuses to ignore a column", {
  x <- data.table(id = c("a", "b"), note = c("p", "q"), v = c(1, 2))
  err <- expect_error(diff_table(x, x, mode = "equal", by = "id"), class = "daffiz_error_columns")
  expect_identical(err$columns, "NOTE")
  # Named in `by`, it takes part and the comparison runs.
  expect_true(all(diff_table(x, x, mode = "equal", by = c("id", "note"))$status == "same"))
})

test_that("by is validated", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  # Which problem each is, in words, is pinned in test-messages.R.
  expect_error(diff_table(x, x, by = "nope"), class = "daffiz_error_columns")
  expect_error(diff_table(x, x, by = c("id", "ID")), class = "daffiz_error_columns")
  expect_error(diff_table(x, x, by = "v", measures = "v"), class = "daffiz_error_measures")
  expect_error(diff_table(x, x, by = character()), class = "daffiz_error_input")
  expect_error(diff_table(x, x, by = 1), class = "daffiz_error_input")
  expect_error(diff_table(x, x, by = NA_character_), class = "daffiz_error_input")
})

test_that("a table with no key column is not well-formed", {
  x <- data.table(v = c(1, 2))
  # The message offers row_key; test-messages.R pins it.
  expect_error(diff_table(x, x), class = "daffiz_error_keys")
  expect_true(all(diff_table(x, x, row_key = "position")$status == "same"))
})

# Virtual keys ----------------------------------------------------------------

test_that("row_key = \"position\" pairs rows as they come", {
  x <- data.table(a = c(3, 1, 2), b = c(30, 10, 20))
  y <- data.table(a = c(3, 1, 2, 4), b = c(30, 11, 20, 40))
  d <- diff_table(x, y, row_key = "position")
  expect_identical(key(d), c("row_number", "metric"))
  expect_identical(d[status == "changed", paste(row_number, metric)], "2 B")
  expect_identical(unique(d[status == "only_y", row_number]), 4L)
  # Same rows in another order: every row differs by position.
  expect_true(all(diff_table(x, x[c(2, 3, 1)], row_key = "position")$status == "changed"))
})

test_that("row_key = \"sorted\" pairs rows whatever their order", {
  x <- data.table(a = c(3, 1, 2), b = c(30, 10, 20))
  y <- x[c(2, 3, 1)]
  d <- diff_table(x, y, row_key = "sorted")
  expect_true(all(d$status == "same"))
  # row_id_x/row_id_y still point at each table's own rows.
  expect_identical(d[metric == "A", row_id_x], c(2L, 3L, 1L))
  expect_identical(d[metric == "A", row_id_y], 1:3)
})

test_that("row_key = \"sorted\" compares multisets of rows exactly", {
  x <- data.table(a = c(1, 1, 2), b = c(10, 10, 20))
  expect_true(all(diff_table(x, x[c(3, 1, 2)], row_key = "sorted", mode = "equal")$status == "same"))
  # A different multiset can never pass.
  y <- data.table(a = c(1, 2, 2), b = c(10, 20, 20))
  expect_true(is_tally(diff_table(x, y, row_key = "sorted"), same = 4L, changed = 2L))
})

test_that("row_key = \"sorted\" numbers rows within the other key columns", {
  x <- data.table(id = c("a", "a", "b"), v = c(2, 1, 3))
  y <- data.table(id = c("a", "a", "b"), v = c(1, 2, 3))
  expect_no_warning(d <- diff_table(x, y, row_key = "sorted"))
  expect_identical(key(d), c("ID", "row_number", "metric"))
  expect_true(all(d$status == "same"))
})

test_that("the virtual key is never a measure, and is symmetric in equal mode", {
  x <- data.table(n = c(1L, 2L), v = c(1, 2))
  y <- data.table(n = c(2L, 1L), v = c(2, 1.5))
  d <- diff_table(x, y, row_key = "sorted", measures = "numeric+integer")
  expect_setequal(unique(d$metric), c("N", "V"))
  for (how in c("position", "sorted")) {
    xy <- diff_table(x, y, mode = "equal", row_key = how, measures = "numeric+integer")
    yx <- diff_table(y, x, mode = "equal", row_key = how, measures = "numeric+integer")
    expect_identical(yx$status, xy$status, info = how)
    expect_equal(yx$diff, -xy$diff, info = how)
  }
})

test_that("row_key sorts NaN as NA when they are the same missing value", {
  x <- data.table(a = c(NA, 1))
  y <- data.table(a = c(1, NaN))
  expect_true(all(diff_table(x, y, row_key = "sorted")$status == "same"))
})

test_that("row_key works without measures, and with a user column called row_number", {
  x <- data.table(row_number = c("p", "q", "r"))
  d <- suppressMessages(diff_table(x, x[c(1, 3, 2)], row_key = "position"))
  expect_identical(names(d), c("ROW_NUMBER", "row_number", "row_id_x", "row_id_y", "status"))
  expect_identical(sort(as.character(d$status)), c("only_x", "only_x", "only_y", "only_y", "same"))
})

# Values ------------------------------------------------------------------------

test_that("NA and NaN: the same missing value by default, told apart on request", {
  x <- data.table(id = c("a", "b", "c", "d"), v = c(NA, NaN, NA, NaN))
  y <- data.table(id = c("a", "b", "c", "d"), v = c(NA, NaN, NaN, NA))
  expect_identical(as.character(diff_table(x, y)$status), rep("same", 4L))
  expect_identical(
    as.character(diff_table(x, y, nan_is_na = FALSE)$status),
    c("same", "same", "changed", "changed")
  )
  # A missing value against a number is always a change.
  z <- data.table(id = c("a", "b", "c", "d"), v = 1)
  expect_true(all(diff_table(x, z)$status == "changed"))
})

test_that("NaN and NA key values align when they are the same missing value", {
  x <- data.table(k = c(NA, 1), v = c(1, 2))
  y <- data.table(k = c(NaN, 1), v = c(1, 2))
  d <- diff_table(x, y, by = "k")
  expect_true(all(d$status == "same"))
  d2 <- diff_table(x, y, by = "k", nan_is_na = FALSE)
  expect_identical(sort(as.character(d2$status)), c("only_x", "only_y", "same"))
})

test_that("NA and NaN follow nan_is_na under aggregation too", {
  x <- data.table(id = c("a", "a"), v = c(1, NA))
  y <- data.table(id = c("a", "a"), v = c(NaN, 1))
  expect_identical(as.character(diff_table(x, y, duplicates = "aggregate")$status), "same")
  expect_identical(
    as.character(diff_table(x, y, duplicates = "aggregate", nan_is_na = FALSE)$status),
    "changed"
  )
})

test_that("tolerance must be a single finite number >= 0", {
  x <- data.table(id = "a", v = 1)
  for (bad in list(-1, NA_real_, c(1, 0), "1", Inf)) {
    expect_error(diff_table(x, x, tolerance = bad), class = "daffiz_error_input", info = deparse(bad))
  }
  expect_error(diff_table(x, x, duplicates = "aggregate", tolerance = 0.1), class = "daffiz_error_input")
})

test_that("the flags must be TRUE or FALSE", {
  x <- data.table(id = "a", v = 1)
  for (bad in list(NA, "TRUE", c(TRUE, FALSE), 1, NULL)) {
    case <- deparse(bad)
    expect_error(diff_table(x, x, truncate = bad), class = "daffiz_error_input", info = case)
    expect_error(diff_table(x, x, nan_is_na = bad), class = "daffiz_error_input", info = case)
    expect_error(diff_table(x, x, cast = bad), class = "daffiz_error_input", info = case)
  }
  # And TRUE or FALSE are accepted, so the refusal is about the value.
  expect_true(all(diff_table(x, x, truncate = FALSE, nan_is_na = FALSE, cast = FALSE)$status == "same"))
})

test_that("status is a factor with every level", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  d <- diff_table(x, x)
  expect_identical(levels(d$status), c("same", "changed", "only_x", "only_y"))
  expect_identical(attr(d, "shape"), "cells")
  expect_identical(attr(d, "mode"), "benchmark")
})

# No measures: do the tables have the same rows? ---------------------------

test_that("with no measures, rows are compared as wholes", {
  x <- data.table(k = c("a", "b", "c"))
  y <- data.table(k = c("c", "a", "d"))
  expect_message(d <- diff_table(x, y), class = "daffiz_message_no_measures")
  expect_identical(attr(d, "shape"), "rows")
  expect_identical(names(d), c("K", "row_id_x", "row_id_y", "status"))
  expect_identical(as.character(d$status), c("same", "only_x", "same", "only_y"))
  expect_identical(d$row_id_y, c(2L, NA, 1L, 3L))
})

test_that("with no measures, duplicates compare as multisets under every policy", {
  x <- data.table(k = c("a", "a", "b"))
  y <- data.table(k = c("a", "b", "b"))
  quiet <- function(...) suppressMessages(diff_table(...))
  # Pairing identical rows assumes nothing, so there is no warning.
  expect_no_warning(d <- quiet(x, y))
  expect_identical(sort(as.character(d$status)), c("only_x", "only_y", "same", "same"))
  g <- quiet(x, y, duplicates = "aggregate")
  expect_identical(attr(g, "shape"), "groups")
  expect_identical(as.character(g$status), c("changed", "changed"))
  expect_identical(as.character(quiet(x, x, duplicates = "aggregate")$status), c("same", "same"))
  expect_error(quiet(x, y, duplicates = "error"), class = "daffiz_error_duplicates")
})

test_that("with no measures, equal mode still compares every column", {
  x <- data.table(k = c("a", "b"), n = c(1L, 2L))
  d <- suppressMessages(diff_table(x, x[2:1], mode = "equal"))
  expect_true(all(d$status == "same"))
})

# Alignment -----------------------------------------------------------------

test_that("a comparison in which nothing aligns is refused", {
  x <- data.table(id = c("a", "b"), v = c(1, 2))
  y <- data.table(id = c("A", "B"), v = c(1, 2))
  # The three wordings (keys, one empty table, whole rows) are pinned in
  # test-messages.R.
  err <- expect_error(diff_table(x, y), class = "daffiz_error_disjoint")
  expect_identical(c(err$dry_run$keys_common, err$dry_run$rows_y), c(0L, 2L))
  err <- expect_error(diff_table(x, y[0]), class = "daffiz_error_disjoint")
  expect_identical(err$dry_run$rows_y, 0L)
  expect_error(
    suppressMessages(diff_table(data.table(k = "a"), data.table(k = "b"))),
    class = "daffiz_error_disjoint"
  )
})

test_that("two empty tables are equal, not ill-formed", {
  x <- data.table(id = character(), v = numeric())
  d <- diff_table(x, x)
  expect_identical(nrow(d), 0L)
})

# The inputs ----------------------------------------------------------------

test_that("the caller's tables are never modified", {
  x <- data.table(id = c("b", "a"), n = c(2L, 1L), v = c(2, NaN))
  y <- data.table(ID = c("a", "b"), N = c("1", "2.5"), V = c(NA, 2), extra = 1)
  before_x <- copy(x)
  before_y <- copy(y)
  suppressMessages(diff_table(x, y, measures = "numeric+integer"))
  suppressMessages(diff_table(x, y, by = "id"))
  suppressMessages(diff_table(x, x, mode = "equal", duplicates = "aggregate"))
  expect_identical(x, before_x)
  expect_identical(y, before_y)
})

test_that("data.frames work as well as data.tables", {
  x <- data.frame(id = c("a", "b"), v = c(1, 2))
  expect_true(all(diff_table(x, x)$status == "same"))
})

# A computed NA (NA + 0, as.Date(NA) + 1) carries a different bit pattern from
# a literal NA; R calls both NA, and so must the comparison.

test_that("a computed NA key is the same key as a literal one: rows", {
  na_q <- NA_real_ + 0
  expect_message(
    d <- diff_table(data.frame(k = c(NA_real_, na_q)), data.frame(k = NA_real_), by = "k"),
    class = "daffiz_message_no_measures"
  )
  expect_identical(d$key_seq, 1:2)
  expect_identical(as.character(d$status), c("same", "only_x"))
  expect_identical(d$row_id_y, c(1L, NA))
})

test_that("a computed NA key is the same key as a literal one: cells", {
  na_q <- NA_real_ + 0
  x <- data.frame(k = c(NA_real_, na_q), v = c(1, 2))
  y <- data.frame(k = NA_real_, v = 1)
  for (nan_is_na in c(TRUE, FALSE)) {
    case <- paste("nan_is_na =", nan_is_na)
    expect_warning(
      d <- diff_table(x, y, by = "k", nan_is_na = nan_is_na),
      class = "daffiz_warning_duplicates"
    )
    expect_identical(as.character(d$status), c("same", "only_x"), info = case)
    expect_error(
      diff_table(x, y, by = "k", duplicates = "error", nan_is_na = nan_is_na),
      class = "daffiz_error_duplicates"
    )
  }
  # Two computed NAs against two literal ones pair up in arrival order.
  expect_warning(
    d <- diff_table(x, data.frame(k = c(na_q, NA_real_), v = c(1, 2)), by = "k", nan_is_na = FALSE),
    class = "daffiz_warning_duplicates"
  )
  expect_identical(as.character(d$status), c("same", "same"))
  d <- diff_table(x, data.frame(k = c(na_q, NA_real_), v = c(1, 2)), by = "k", duplicates = "aggregate")
  expect_identical(as.character(d$status), "same")
})

test_that("a computed NA Date key is the same key as a literal one", {
  d <- as.Date(c("2024-01-01", NA)) + 1
  x <- data.frame(d = c(as.Date(NA), d))
  out <- suppressMessages(diff_table(x, x))
  expect_identical(out$row_id_x, out$row_id_y)
  expect_true(all(out$status == "same"))
  expect_setequal(out$row_id_y, 1:3)
})
