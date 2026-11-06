test_that("canonical_names keeps only letters, digits and _", {
  nms <- c(
    "amount", "Unit Price", "unit.price", "unit-price", "unit  price",
    "amount ", " _id_ ", paste0("prix_unit", "\u00e9"), "Q1", "2024", "%"
  )
  expect_identical(canonical_names(nms), c(
    "AMOUNT", "UNIT_PRICE", "UNIT_PRICE", "UNIT_PRICE", "UNIT_PRICE",
    "AMOUNT", "ID", "PRIX_UNIT\u00c9", "Q1", "2024", ""
  ))
})

test_that("every column daffiz creates contains a lowercase letter", {
  # This is what makes a collision with a normalized user column impossible.
  # A new internal name without one would silently break that guarantee, so
  # the names are read off real results of every shape, in both modes, and
  # off the intermediate tables, not kept by hand.
  x <- data.table(id = c("a", "a", "b"), n = c(1L, 2L, 3L), v = c(1, 2, 3))
  y <- data.table(id = c("a", "a", "c"), n = c(1L, 2L, 3L), v = c(1, 5, 3))
  user <- canonical_names(names(x))
  results <- list(
    cells = suppressWarnings(diff_table(x, y, by = c("id", "n"))),
    paired = suppressWarnings(diff_table(x, y, mode = "equal", measures = "numeric+integer")),
    groups = diff_table(x, y, mode = "equal", by = c("id", "n"), duplicates = "aggregate"),
    groups_rows = suppressMessages(diff_table(x[, .(id)], y[, .(id)], duplicates = "aggregate")),
    rows = suppressMessages(diff_table(x[, .(id)], y[, .(id)])),
    row_key = diff_table(x[, .(v)], y[, .(v)], row_key = "sorted")
  )
  expect_identical(
    vapply(results, attr, "", "shape"),
    c(cells = "cells", paired = "cells", groups = "groups", groups_rows = "groups", rows = "rows", row_key = "cells")
  )
  wide <- index_dt(x, ids = "id", measures = "v")
  long <- melt_dt(wide, measures = "v")
  intermediate <- list(
    wide = wide,
    long = long,
    paired = disambiguate_by_key(melt_dt(wide, measures = "v")),
    moments = aggregate_by_key(long),
    exact = aggregate_by_key(long, stats = "exact")
  )
  internal <- setdiff(unique(unlist(lapply(c(results, intermediate), names))), user)
  # The derivation found the names it should: one of each kind at least.
  expect_true(all(c(
    "row_id", "row_id_x", "row_id_y", "row_number", "key_seq", "metric", "value",
    "value_x", "value_y", "diff", "abs_diff", "rel_diff", "status",
    "n_rows", "n_rows_x", "n_na_x", "value_key", "value_key_y", "value_sum"
  ) %in% internal))
  expect_identical(internal[!grepl("[a-z]", internal)], character())
  expect_true(all(grepl("[a-z]", names(MEASURE_TYPES))))
})

test_that("name_map labels a column by its own spelling, adding the normalized one only when it is more than a change of case", {
  map <- name_map(data.table(ID = 1, amount = 2, `unit price` = 3))
  expect_identical(map$column, c("ID", "AMOUNT", "UNIT_PRICE"))
  expect_identical(map$label, c("ID", "amount", "\"unit price\" (UNIT_PRICE)"))
})

test_that("check_names refuses empty and colliding names, naming each group", {
  # The groups, as drawn in the message, are pinned in test-messages.R.
  err <- expect_error(
    check_names(name_map(data.table(`%` = 1, a = 2)), "x"),
    class = "daffiz_error_columns"
  )
  expect_identical(c(err$side, err$columns), c("x", "%"))
  err <- expect_error(
    check_names(name_map(data.table(a = 1, A = 2, b.c = 3, `b c` = 4)), "x"),
    class = "daffiz_error_columns"
  )
  expect_identical(err$columns, c("a", "A", "b.c", "b c"))
})

test_that("check_names can be limited to the names that matter", {
  map <- name_map(data.table(foo = 1, Foo = 2, id = 3))
  expect_silent(check_names(map, "y", only = "ID"))
  err <- expect_error(check_names(map, "y", only = c("ID", "FOO")), class = "daffiz_error_columns")
  expect_identical(err$columns, c("foo", "Foo"))
})

test_that("shallow_dt renames without copying the caller's vectors", {
  dt <- data.table(a = c(1, 2))
  out <- shallow_dt(dt, new = "A")
  expect_identical(names(out), "A")
  expect_identical(address(out$A), address(dt$a))
  # Replacing a column swaps a pointer and leaves the caller's table alone.
  set(out, j = "A", value = c(9, 9))
  expect_identical(dt$a, c(1, 2))
})
