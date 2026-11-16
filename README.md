
<!-- README.md is generated from README.Rmd. Please edit that file -->

# dazdiff

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/pedrobtz/dazdiff/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/dazdiff/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/dazdiff/gh-pages/badges/coverage.svg)](https://github.com/pedrobtz/dazdiff/actions/workflows/coverage.yaml)
<!-- badges: end -->

dazdiff compares two tables value by value and returns one row per
compared value, traced back to its source row in both tables.

- It can test a table against a benchmark whose column types are the
  truth: the tested table’s columns are cast to those types and its
  column names normalized, so a table that went through a database or
  Spark compares with the one that went in.
- Rows are paired on their identity columns, never by position, and a
  key that repeats is reported rather than silently paired.
- Its one dependency outside base R is
  [data.table](https://rdatatable.gitlab.io/data.table/).

## Installation

Install the released version from CRAN:

``` r
install.packages("dazdiff")
```

Or the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("pedrobtz/dazdiff")
```

## Usage

A table, and the same data after a round trip through storage: the names
changed case, the ids became text, one amount moved and one row was
replaced. `diff_table()` pairs the rows on `id` and compares `amount`:

``` r
library(dazdiff)

benchmark <- data.frame(id = 1:3, amount = c(100, 200, 300))
stored <- data.frame(ID = c("1", "2", "4"), Amount = c(100, 200.5, 400))

diff_table(benchmark, stored, by = "id")
#> Key: <ID, metric>
#>       ID metric row_id_x row_id_y value_x value_y  diff abs_diff    rel_diff  status
#>    <int> <char>    <int>    <int>   <num>   <num> <num>    <num>       <num>  <fctr>
#> 1:     1 AMOUNT        1        1     100   100.0   0.0      0.0 0.000000000    same
#> 2:     2 AMOUNT        2        2     200   200.5   0.5      0.5 0.002493766 changed
#> 3:     3 AMOUNT        3       NA     300      NA    NA       NA          NA  only_x
#> 4:     4 AMOUNT       NA        3      NA   400.0    NA       NA          NA  only_y
```

Column names are normalized to upper case, which is how `id` pairs with
`ID`. `status` says what happened to each value, and `row_id_x` and
`row_id_y` are its rows in the two tables.

dazdiff also summarizes and draws a comparison, finds which keys hold
the differences, compares two tables as equals, and works as a testthat
expectation. Get started shows each of these.

## Learn more

- [Get
  started](https://pedrobtz.github.io/dazdiff/articles/dazdiff.html):
  one comparison taken from the first call to a test.
- [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.html):
  every argument, the result’s columns and how values are classified.
- [Reference](https://pedrobtz.github.io/dazdiff/reference/index.html):
  every function.
