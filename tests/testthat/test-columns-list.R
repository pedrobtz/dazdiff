# compare_columns() describes a list column instead of refusing it (#52).

test_that("compare_columns() reports a list column with no counts", {
  dl <- data.table(id = 1:2, l = list(1, "a"))
  out <- compare_columns(dl, dl)
  row <- out[colname == "L"]
  expect_identical(row$n_unique_x, NA_integer_)
  expect_identical(row$over_pct, NA_real_)
  expect_identical(out[colname == "ID", over_pct], 100)
})
