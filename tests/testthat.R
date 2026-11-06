# testthat is a suggested package: without it (CRAN's NOSUGGESTS flavor) the
# tests are skipped rather than failing to start.
if (requireNamespace("testthat", quietly = TRUE)) {
  library(testthat)
  library(dazdiff)

  test_check("dazdiff")
}
