# Non-ASCII letters are kept (#49); ASCII is upper-cased the same in every
# locale (#26).

test_that("non-ASCII letters survive normalization", {
  grosse <- "Gr\u00f6\u00dfe"
  gruesse <- "Gr\u00fc\u00dfe"
  expect_false(identical(canonical_names(grosse), canonical_names(gruesse)))
  expect_identical(canonical_names("prix_unit\u00e9"), "PRIX_UNIT\u00c9")
  expect_identical(canonical_names("\u0446\u0435\u043d\u0430 2024"), "\u0426\u0415\u041d\u0410_2024")
  expect_true(all(!grepl("[a-z]", canonical_names(c(grosse, "\u00e9t\u00e9")))))
})

test_that("measures that differ only in non-ASCII letters do not pair", {
  x <- data.frame(id = 1L, a = 1)
  y <- data.frame(id = 1L, a = 5)
  names(x)[2] <- "Gr\u00f6\u00dfe"
  names(y)[2] <- "Gr\u00fc\u00dfe"
  expect_error(diff_table(x, y), class = "daffiz_error_columns")
})

test_that("a table named in Cyrillic is accepted", {
  x <- data.frame(id = 1:2, v = c(1, 2))
  names(x) <- c("\u043a\u043e\u0434", "\u0446\u0435\u043d\u0430")
  d <- diff_table(x, x, by = "\u043a\u043e\u0434")
  expect_identical(as.character(d$status), c("same", "same"))
})

# macOS toupper() writes I even under tr_TR, so only glibc (CI) can fail here.
test_that("ASCII i upper-cases to I in a Turkish locale", {
  ok <- tryCatch(
    {
      withr::local_locale(c(LC_CTYPE = "tr_TR.UTF-8"))
      TRUE
    },
    warning = function(w) FALSE
  )
  skip_if_not(ok, "tr_TR.UTF-8 locale not available")
  withr::local_locale(c(LC_CTYPE = "tr_TR.UTF-8"))
  expect_identical(canonical_names(c("id", "price")), c("ID", "PRICE"))
})
