# Ported from .agents/test-cases.R. Every block builds what it checks, so the
# file runs in any order (devtools::test(shuffle = TRUE)). cases_fixture() is
# the table A of the original cases.

test_that("B is A", {
  A <- cases_fixture()
  check_clean("identical tables: every row same, and nothing warns",
    is_tally(diff_table(A, copy(A)), same = 4L))
  check("identical tables: no diff", diff_table(A, copy(A))[, all(diff == 0)])
  check("row order does not matter", is_tally(diff_table(A, A[c(3, 1, 4, 2)]), same = 4L))
})

test_that("rows added and removed", {
  A <- cases_fixture()
  check("B is a subset: the missing row is only_x",
    is_tally(diff_table(A, A[1:3]), same = 3L, only_x = 1L))
  B_extra <- rbind(A, data.table(ID = "e", GRP = "z", DAY = as.Date("2024-02-01"), CNT = 9L, VAL = 90))
  check("B has an extra row: it is only_y", is_tally(diff_table(A, B_extra), same = 4L, only_y = 1L))
  # Nothing aligns, so nothing would be compared: every row one-sided. That
  # is almost always a wrong key, and is refused rather than reported.
  check_error("B shares no ids with A: refused, since nothing aligns",
    diff_table(A, copy(A)[, ID := paste0(ID, "!")]), class = "dazdiff_error_disjoint")
})

test_that("changing an id column is an identity change, not a value change", {
  A <- cases_fixture()
  B_id <- copy(A)[ID == "b", GRP := "q"]
  check("a changed id splits into only_x + only_y",
    is_tally(diff_table(A, B_id), same = 3L, only_x = 1L, only_y = 1L))
})

test_that("values change", {
  A <- cases_fixture()
  B_val <- copy(A)[ID == "c", VAL := 31]
  check("one changed value", is_tally(diff_table(A, B_val), same = 3L, changed = 1L))
  check("the diff is reported", diff_table(A, B_val)[status == "changed", diff == 1])
  B_all <- copy(A)[, VAL := VAL * 2]
  check("every value changed", is_tally(diff_table(A, B_all), changed = 4L))
})

test_that("one row dropped, one added, one edited, one untouched", {
  A <- cases_fixture()
  B_mix <- rbind(
    copy(A)[2:4][ID == "c", VAL := 99],
    data.table(ID = "e", GRP = "z", DAY = as.Date("2024-02-01"), CNT = 9L, VAL = 90)
  )
  check("added, removed, changed and untouched at once",
    is_tally(diff_table(A, B_mix), same = 2L, changed = 1L, only_x = 1L, only_y = 1L))
  check("in_place leaves A alone", {
    before <- copy(A)
    invisible(diff_table(A, B_mix))
    identical(before, A)
  })
  check("in_place leaves B alone", {
    before <- copy(B_mix)
    invisible(diff_table(A, B_mix))
    identical(before, B_mix)
  })
})

test_that("a tolerance absorbs a tiny difference, not a real one", {
  A <- cases_fixture()
  B_tiny <- copy(A)[ID == "a", VAL := VAL + 1e-9]
  B_val <- copy(A)[ID == "c", VAL := 31]
  check("a tiny difference counts by default", is_tally(diff_table(A, B_tiny), same = 3L, changed = 1L))
  check("tolerance absorbs it", is_tally(diff_table(A, B_tiny, tolerance = 1e-6), same = 4L))
  check("tolerance is not a free pass", is_tally(diff_table(A, B_val, tolerance = 1e-6), same = 3L, changed = 1L))
})

test_that("types: a drifted type is cast back, or refused without casting", {
  A <- cases_fixture()
  B_chr <- copy(A)[, VAL := as.character(VAL)]
  check("a drifted type is cast back", is_tally(diff_table(A, B_chr), same = 4L))
  check_error("without casting the type mismatch is refused",
    diff_table(A, B_chr, cast = FALSE), class = "dazdiff_error_types")
})

test_that("types: integers are ids unless asked to be measures", {
  A <- cases_fixture()
  B_int <- copy(A)[ID == "a", CNT := 99L]
  check("integers are ids by default, so CNT is an identity",
    is_tally(diff_table(A, B_int), same = 3L, only_x = 1L, only_y = 1L))
  # Melting an integer column alongside a double one puts both in one value
  # column, so CNT widens to double -- promoted up front, so melt() has no
  # reason to warn about it.
  check_clean("measures = numeric+integer makes CNT a measure",
    is_tally(diff_table(A, B_int, measures = "numeric+integer"), same = 7L, changed = 1L))
})

test_that("an extra column in B is dropped, a missing one refused", {
  A <- cases_fixture()
  B_wide <- copy(A)[, NOTE := "hi"]
  m <- expect_message(d <- diff_table(A, B_wide), class = "dazdiff_message_dropped_columns")
  check("an extra column in B does not stop the compare", is_tally(d, same = 4L))
  check("the message names the dropped column", identical(m$columns, "NOTE"))
  err <- expect_error(diff_table(A, copy(A)[, GRP := NULL]), class = "dazdiff_error_columns")
  check("a missing column in B is refused, naming it", identical(err$columns, "GRP"))
})

test_that("NA values", {
  A <- cases_fixture()
  A_na <- copy(A)[ID == "a", VAL := NA_real_]
  B_na <- copy(A_na)
  check("NA on both sides is not a change", is_tally(diff_table(A_na, B_na), same = 4L))
  check("NA appearing in B is a change",
    is_tally(diff_table(A, B_na), same = 3L, changed = 1L))
  check("NA disappearing in B is a change",
    is_tally(diff_table(A_na, A), same = 3L, changed = 1L))
  check("a row missing from B is only_x even when its value is NA",
    is_tally(diff_table(A_na, A_na[2:4]), same = 3L, only_x = 1L))
})

test_that("ids that do not tell rows apart", {
  # Two rows identical in every id column, differing only in the measure.
  A_dup <- data.table(
    ID = c("a", "a", "b"),
    GRP = c("x", "x", "y"),
    DAY = as.Date("2024-01-01"),
    CNT = c(1L, 1L, 2L),
    VAL = c(10, 11, 20)
  )
  B_dup <- copy(A_dup)
  expect_warning(d <- diff_table(A_dup, B_dup), class = "dazdiff_warning_duplicates")
  check("duplicate ids: disambiguated by arrival order", is_tally(d, same = 3L))
  # The edit is inside the repeated group, on its second row.
  expect_warning(
    d <- diff_table(A_dup, copy(A_dup)[2, VAL := 12]),
    class = "dazdiff_warning_duplicates"
  )
  check("duplicate ids: a change inside the group is found", is_tally(d, same = 2L, changed = 1L))
  check(
    "duplicate ids: on the row it was made to",
    d[status == "changed", ID == "a" && key_seq == 2L && row_id_x == 2L && row_id_y == 2L]
  )
  check_error("duplicates = error refuses", diff_table(A_dup, B_dup, duplicates = "error"),
    class = "dazdiff_error_duplicates")
  check("duplicates = aggregate collapses the group", {
    res <- diff_table(A_dup, B_dup, duplicates = "aggregate")
    nrow(res) == 2L && all(res$status == "same")
  })
  check("duplicates = aggregate sees a change in the group", {
    res <- diff_table(A_dup, copy(A_dup)[2, VAL := 12], duplicates = "aggregate")
    is_tally(res, same = 1L, changed = 1L)
  })
})

test_that("a repeated key numbers a row once, the same for all its measures", {
  # Numbered on the wide table, before the melt: numbering each measure on its
  # own could give one source row two numbers.
  x <- data.table(id = c("a", "a", "a"), v = c(1, 2, 3), w = c(30, 20, 10))
  y <- data.table(id = c("a", "a", "a"), v = c(1, 2, 3), w = c(30, 21, 10))
  expect_warning(d <- diff_table(x, y), class = "dazdiff_warning_duplicates")
  by_row <- d[, .(n_seq = uniqueN(key_seq), n_metric = .N), by = row_id_x]
  expect_identical(by_row$n_seq, c(1L, 1L, 1L))
  expect_identical(by_row$n_metric, c(2L, 2L, 2L))
  expect_identical(d[metric == "V", key_seq], d[metric == "W", key_seq])
  expect_identical(d[metric == "V", row_id_x], d[metric == "W", row_id_x])
  expect_identical(d[status == "changed", paste(metric, key_seq, row_id_x)], "W 2 2")
})
