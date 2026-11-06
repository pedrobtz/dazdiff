# Ported from .agents/test.R. Every block builds what it checks, so the file
# runs in any order (devtools::test(shuffle = TRUE)).

test_that("1) identical tables are the same everywhere", {
  d1 <- d1_fixture()
  t1 <- diff_table(d1, d1)
  check("1) identical tables: every value is the same", all(t1$status == "same"))
  check("1) identical tables: one row per row x measure", nrow(t1) == nrow(d1) * 2L)
  check("1) identical tables: the difference is zero", all(t1$diff == 0))
})

test_that("2) one changed value is found, and only that one", {
  d1 <- d1_fixture()
  d2 <- copy(d1)
  set(d2, i = 1L, j = "NUM_01", value = d1$NUM_01[1L] + 10)
  t2 <- diff_table(d1, d2)
  check("2) one changed value is found", sum(t2$status == "changed") == 1L)
  check("2) everything else is unchanged", sum(t2$status == "same") == nrow(t2) - 1L)
  check("2) the difference is reported", t2[status == "changed", abs(diff - 10) < 1e-9])
})

test_that("3) all four statuses at once", {
  t3 <- diff_table(x3_fixture(), y3_fixture())
  check("3) an unchanged row is 'same'", t3[ID == "a", status] == "same")
  check("3) a changed row is 'changed'", t3[ID == "b", status] == "changed")
  check("3) a row only in x is 'only_x'", t3[ID == "c", status] == "only_x")
  check("3) a row only in y is 'only_y'", t3[ID == "d", status] == "only_y")
  check("3) only_x has no y value", t3[ID == "c", is.na(value_y)])
  check("3) only_y has no x value", t3[ID == "d", is.na(value_x)])
})

test_that("4) the absolute tolerance", {
  x5 <- data.table(id = c("a", "b"), v = c(1, 2))
  y5 <- data.table(id = c("a", "b"), v = c(1.005, 2))
  check("4) without a tolerance a tiny drift is a change", diff_table(x5, y5)[ID == "a", status] == "changed")
  check("4) inside the tolerance it is the same", diff_table(x5, y5, tolerance = 0.01)[ID == "a", status] == "same")
  check("4) the tolerance is absolute, so it is not one-sided", diff_table(y5, x5, tolerance = 0.01)[ID == "a", status] == "same")
})

test_that("4) a difference exactly at the tolerance is the same, just past it is not", {
  # 1.5 - 1 is exactly 0.5 in binary, so this is the boundary itself.
  x <- data.table(id = "a", v = 1)
  at <- data.table(id = "a", v = 1.5)
  past <- data.table(id = "a", v = 1.5000001)
  expect_identical(as.character(diff_table(x, at, tolerance = 0.5)$status), "same")
  expect_identical(as.character(diff_table(at, x, tolerance = 0.5)$status), "same")
  expect_identical(as.character(diff_table(x, past, tolerance = 0.5)$status), "changed")
  expect_identical(as.character(diff_table(past, x, tolerance = 0.5)$status), "changed")
})

# Inf - Inf is NaN, so a tolerance test alone called two identical infinities a
# change. Finding 4.
test_that("5) infinities and NA", {
  inf_x <- data.table(id = c("a", "b"), v = c(Inf, -Inf))
  check("5) identical infinities are not a change", all(diff_table(inf_x, copy(inf_x))$status == "same"))
  check(
    "5) but opposite infinities are",
    diff_table(inf_x, data.table(id = c("a", "b"), v = c(-Inf, Inf)))[ID == "a", status] == "changed"
  )
  check(
    "5) an infinity against a finite value is a change",
    diff_table(data.table(id = "a", v = Inf), data.table(id = "a", v = 1))$status == "changed"
  )
  check(
    "5) equality still wins with a tolerance set",
    diff_table(inf_x, copy(inf_x), tolerance = 0.5)[ID == "a", status] == "same"
  )
  check(
    "5) NA on one side only is a change",
    diff_table(data.table(id = "a", v = NA_real_), data.table(id = "a", v = 1))$status == "changed"
  )
})

test_that("6) the candidate is cast to the benchmark's types first", {
  x6 <- data.table(id = c("a", "b"), v = c(1, 2))
  y6 <- data.table(id = c("a", "b"), v = c("1", "2"))
  check("6) a text column is cast to x's type first", all(diff_table(x6, y6)$status == "same"))
  err <- expect_error(diff_table(x6, y6, cast = FALSE), class = "daffiz_error_types")
  check("6) with cast = FALSE the type mismatch is reported up front", identical(err$columns, "V"))
  check_error(
    "6) a value that cannot be cast is refused",
    diff_table(x6, data.table(id = c("a", "b"), v = c("1", "two"))),
    class = "daffiz_error_cast"
  )
})

test_that("7) which columns count as measures", {
  x7 <- data.table(id = c("a", "b"), n = c(1L, 2L), v = c(1, 2))
  y7 <- data.table(id = c("a", "b"), n = c(1L, 9L), v = c(1, 2))
  check(
    "7) integers are ids by default, so a change to one moves the row",
    is_tally(diff_table(x7, y7), same = 1L, only_x = 1L, only_y = 1L)
  )
  t7 <- diff_table(x7, y7, measures = "numeric+integer")
  check("7) numeric+integer measures them instead", t7[metric == "N" & ID == "b", status] == "changed")
  check("7) and the unchanged double is still same", t7[metric == "V" & ID == "b", status] == "same")
})

test_that("8) duplicate keys are paired by arrival order, with a warning", {
  x8 <- data.table(id = c("a", "a", "b"), v = c(1, 2, 3))
  y8 <- data.table(id = c("a", "a", "b"), v = c(1, 2, 30))
  w <- expect_warning(t8 <- diff_table(x8, y8), class = "daffiz_warning_duplicates")
  check("8) the warning carries the repeated groups", identical(w$duplicates$ID, c("a", "a")))
  check("8) duplicates = 'disambiguate' pairs rows by arrival order", nrow(t8) == 3L)
  check("8) and finds the change", sum(t8$status == "changed") == 1L)
  check("8) the rows carry their sequence number", "key_seq" %in% names(t8))
})

test_that("8) duplicates = 'aggregate' and 'error'", {
  x8 <- data.table(id = c("a", "a", "b"), v = c(1, 2, 3))
  y8 <- data.table(id = c("a", "a", "b"), v = c(1, 2, 30))
  reordered <- data.table(id = c("a", "a", "b"), v = c(2, 1, 3))
  t8a <- diff_table(x8, y8, duplicates = "aggregate")
  check("8) duplicates = 'aggregate' answers per group instead", nrow(t8a) == 2L)
  check("8) it compares value multisets, not values", "value_key_x" %in% names(t8a))
  check("8) the untouched group is the same", t8a[ID == "a", status] == "same")
  check("8) the changed group is changed", t8a[ID == "b", status] == "changed")
  check(
    "8) aggregate is order-free: a reordered group is still the same",
    all(diff_table(x8, reordered, duplicates = "aggregate")$status == "same")
  )
  expect_warning(paired <- diff_table(x8, reordered), class = "daffiz_warning_duplicates")
  check(
    "8) while disambiguate pairs by position, so reordering shows up",
    is_tally(paired, same = 1L, changed = 2L)
  )
  err <- expect_error(diff_table(x8, y8, duplicates = "error"), class = "daffiz_error_duplicates")
  check("8) duplicates = 'error' refuses, naming the groups", identical(err$duplicates$ID, c("a", "a")))
})

# Membership comes from the row identity, not from the value: NA says nothing
# about whether the row was there. Two rows that both hold NA are unchanged,
# and a value turning into NA is a change to that row, not a deletion of it.
test_that("9) NA values", {
  x9 <- data.table(id = c("a", "b"), v = c(1, NA_real_))
  t9 <- diff_table(x9, copy(x9))
  check("9) an unchanged non-NA row is same", t9[ID == "a", status] == "same")
  check("9) NA on both sides is same", t9[ID == "b", status] == "same")
  check("9) a value that became NA is changed", diff_table(data.table(id = "a", v = 1), x9[1L][, v := NA_real_])[, status] == "changed")
  check("9) a value that arrived is changed", diff_table(data.table(id = "a", v = NA_real_), data.table(id = "a", v = 1))[, status] == "changed")
})

test_that("10) the inputs are never modified", {
  x10 <- data.table(id = c("a", "b"), v = c(1, 2))
  y10 <- data.table(id = c("a", "b"), v = c("1", "2"))
  before_x <- copy(x10)
  before_y <- copy(y10)
  invisible(diff_table(x10, y10))
  check("10) x is untouched", identical(x10, before_x))
  check("10) y is untouched, even though it was cast", identical(y10, before_y))
})

test_that("11) shapes and refusals", {
  x3 <- x3_fixture()
  check("11) a plain data.frame works too", all(diff_table(as.data.frame(x3), as.data.frame(x3))$status == "same"))
  check("11) the result is keyed by the ids and the measure", identical(key(diff_table(x3, y3_fixture())), c("ID", "metric")))
  check_error("11) refuses a non-table", diff_table(x3, 1:3), class = "daffiz_error_input")
  # match.arg()'s own errors, unclassed.
  expect_error(diff_table(x3, x3, mode = "sideways"), class = "daffiz_error_input")
  expect_error(diff_table(x3, x3, duplicates = "ignore"), class = "daffiz_error_input")
})

test_that("13) the baseline has to be in the baseline types", {
  x13 <- data.table(t = as.POSIXct(c("2024-01-01 10:00", "2024-01-02 10:00"), tz = "UTC"), v = c(1, 2))
  err <- expect_error(diff_table(x13, copy(x13)), class = "daffiz_error_types")
  check("13) a POSIXct baseline is refused, naming the column", identical(err$columns, "T"))
  err <- expect_error(
    diff_table(data.table(f = factor("a"), v = 1), data.table(f = factor("a"), v = 1)),
    class = "daffiz_error_types"
  )
  check("13) a factor baseline is refused too", identical(err$columns, "F"))
  check_error("13) the gate applies with cast = FALSE as well", diff_table(x13, copy(x13), cast = FALSE), class = "daffiz_error_types")
})

test_that("13) every column that is not of a baseline type is named at once", {
  x13m <- data.table(
    ok = c("a", "b"),
    t = as.POSIXct(c("2024-01-01 10:00", "2024-01-02 10:00"), tz = "UTC"),
    f = factor(c("p", "q")),
    z = c(complex(real = 1), complex(real = 2)),
    v = c(1, 2)
  )
  err <- expect_error(diff_table(x13m, copy(x13m)), class = "daffiz_error_types")
  check("13) all non-baseline columns are reported, not just the first", identical(err$columns, c("T", "F", "Z")))
  err <- expect_error(
    normalize_dt(data.table(z = complex(real = 1), w = complex(real = 2))),
    class = "daffiz_error_types"
  )
  check("13) normalize_dt reports every column it cannot convert", identical(err$columns, c("z", "w")))
  err <- expect_error(normalize_dt(x13m, to = c(POSIXct = "Date")), class = "daffiz_error_types")
  check("13) and stays quiet about the ones it can (factors convert by default)", identical(err$columns, "z"))
})

test_that("13) a converted baseline compares with a POSIXct candidate", {
  x13 <- data.table(t = as.POSIXct(c("2024-01-01 10:00", "2024-01-02 10:00"), tz = "UTC"), v = c(1, 2))
  bench <- normalize_dt(x13, to = c(POSIXct = "Date"))
  # The candidate keeps its time of day, which the cast to Date truncates.
  expect_message(d <- diff_table(bench, copy(x13)), class = "daffiz_message_truncation")
  check("13) converting the baseline first makes it work", all(d$status == "same"))
  expect_message(
    d <- diff_table(bench, data.table(t = as.POSIXct(c("2024-01-01 22:00", "2024-01-02 22:00"), tz = "UTC"), v = c(1, 2))),
    class = "daffiz_message_truncation"
  )
  check("13) a POSIXct candidate needs no conversion of its own", all(d$status == "same"))
  expect_message(
    d <- diff_table(
      data.table(d = as.Date("2024-01-01"), v = 1),
      data.table(d = as.POSIXct("2024-01-01 23:30:00", tz = "Europe/Lisbon"), v = 1)
    ),
    class = "daffiz_message_truncation"
  )
  check("13) a Date baseline still converts a POSIXct candidate in its own zone", d$status == "same")
})

test_that("14) cast = FALSE checks the types up front", {
  x14 <- data.table(id = c("1", "2"), v = c(1, 2))
  y14 <- data.table(id = c(1, 2), v = c(1, 2))
  err <- expect_error(diff_table(x14, y14, cast = FALSE), class = "daffiz_error_types")
  check("14) a type mismatch is named, not left to the join", identical(err$columns, "ID"))
  err <- expect_error(
    diff_table(data.table(id = "a", v = 1), data.table(id = "a", v = "1"), cast = FALSE),
    class = "daffiz_error_types"
  )
  check("14) a mismatch on a non-id column is caught too", identical(err$columns, "V"))
  check("14) matching types pass the check", all(diff_table(x14, copy(x14), cast = FALSE)$status == "same"))
})

test_that("12) a realistic fuzzed table, end to end", {
  d12 <- fake_dt(50, n_cols = c(character = 2, date = 1, integer = 1, numeric = 2), seed = 3)
  num12 <- summarize_dt(d12)[type == "numeric", colname]
  f12 <- fuzz_dt(d12, pct_replace = 0.2, cols = num12, seed = 5)
  # The fake ids repeat, so rows are paired, in arrival order, and fuzz_dt()
  # keeps the order: every row pairs with itself.
  expect_warning(t12 <- diff_table(d12, f12), class = "daffiz_warning_duplicates")
  check("12) every row pairs with its own counterpart", identical(t12$row_id_x, t12$row_id_y))
  # Changed exactly where fuzz_dt() changed the value, and nowhere else.
  touched <- mapply(
    function(m, i) d12[[m]][i] != f12[[m]][i],
    as.character(t12$metric),
    t12$row_id_x,
    USE.NAMES = FALSE
  )
  expect_identical(as.character(t12$status), ifelse(touched, "changed", "same"))
  check("12) the fuzz touched 10 rows in each of 2 measures", is_tally(t12, same = 80L, changed = 20L))
})

test_that("12) rows appended or dropped show up on their own side", {
  d12 <- fake_dt(50, n_cols = c(character = 2, date = 1, integer = 1, numeric = 2), seed = 3)
  num12 <- summarize_dt(d12)[type == "numeric", colname]
  f12b <- fuzz_dt(d12, pct_replace = 0, pct_new = 0.1, cols = num12, seed = 6)
  expect_warning(added <- diff_table(d12, f12b), class = "daffiz_warning_duplicates")
  check("12) appended rows show up as only_y", is_tally(added, same = 100L, only_y = 10L))
  check("12) and they are the 5 appended rows", setequal(added[status == "only_y", row_id_y], 51:55))
  expect_warning(dropped <- diff_table(d12, d12[1:40]), class = "daffiz_warning_duplicates")
  check("12) dropped rows show up as only_x", is_tally(dropped, same = 80L, only_x = 20L))
  check("12) and they are the 10 dropped rows", setequal(dropped[status == "only_x", row_id_x], 41:50))
})
