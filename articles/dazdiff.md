# Get started with dazdiff

``` r

library(dazdiff)
```

We take one table through a round trip that changed it, compare it with
the original, and find out what changed and where. By the end you can
run a comparison, read its result, set a tolerance, compare two tables
as equals, and turn the comparison into a test. Every argument is
described in
[`?diff_table`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).

## Compare against a benchmark

The benchmark is a small sales table. `stored` is the same data after a
round trip through storage. On the way, the column names changed case,
the ids became text, `units` came back as a double, a load timestamp was
added, one row was lost and one was added:

``` r

benchmark <- data.frame(
  id     = c(1L, 2L, 3L, 4L),
  region = c("north", "south", "east", "west"),
  amount = c(100, 200, 300, 400),
  units  = c(10L, 20L, 30L, 40L)
)
stored <- data.frame(
  ID        = c("1", "2", "3", "5"),
  Region    = c("north", "south", "east", "north"),
  Amount    = c(100, 200.5, 300, 500),
  Units     = c(10.4, 20, 30, 50),
  loaded_at = "2026-09-29"
)
```

[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
takes the benchmark first. Rows are paired on their **identity**, the
`by` columns, and the **measures** are the numeric columns compared
value by value. Measures default to `"numeric"`, the double columns;
`"numeric+integer"` adds the integer `units`:

``` r

d <- diff_table(benchmark, stored, by = c("id", "region"), measures = "numeric+integer")
#> Dropped column(s) of `y` that the benchmark `x` does not have: loaded_at.
#> Truncated 1 value(s) while casting to the reference types:
#>   Units: 1 (10.4 -> 10)
d
#> Key: <ID, REGION, metric>
#>        ID REGION metric row_id_x row_id_y value_x value_y  diff abs_diff    rel_diff  status
#>     <int> <char> <char>    <int>    <int>   <num>   <num> <num>    <num>       <num>  <fctr>
#>  1:     1  north AMOUNT        1        1     100   100.0   0.0      0.0 0.000000000    same
#>  2:     1  north  UNITS        1        1      10    10.0   0.0      0.0 0.000000000    same
#>  3:     2  south AMOUNT        2        2     200   200.5   0.5      0.5 0.002493766 changed
#>  4:     2  south  UNITS        2        2      20    20.0   0.0      0.0 0.000000000    same
#>  5:     3   east AMOUNT        3        3     300   300.0   0.0      0.0 0.000000000    same
#>  6:     3   east  UNITS        3        3      30    30.0   0.0      0.0 0.000000000    same
#>  7:     4   west AMOUNT        4       NA     400      NA    NA       NA          NA  only_x
#>  8:     4   west  UNITS        4       NA      40      NA    NA       NA          NA  only_x
#>  9:     5  north AMOUNT       NA        4      NA   500.0    NA       NA          NA  only_y
#> 10:     5  north  UNITS       NA        4      NA    50.0    NA       NA          NA  only_y
```

The messages say what the comparison did on the way. `loaded_at` is not
in the benchmark, so it was dropped. `stored`‘s columns were cast to the
benchmark’s types, and `Units`’ `10.4` became the integer `10`. That
cast is recorded, with the rows it touched, in `attr(d, "truncated")`;
`truncate = FALSE` refuses it instead.

The result is a `data.table`, with one row per compared value:

- **`status`** is `same`, `changed`, `only_x` (the row is missing from
  the tested table) or `only_y` (the row exists only there).
- **`row_id_x` and `row_id_y`** are the row numbers in the two inputs,
  so every difference traces back to its source.
- **`diff`** is `value_y - value_x`, **`abs_diff`** its size, and
  **`rel_diff`** the size relative to the larger of the two values.

Column names are **normalized** in both tables, to upper case with other
characters turned into `_`. That is why `id` and `ID` pair up.

## Summarize the comparison

[`diff_summary()`](https://pedrobtz.github.io/dazdiff/reference/diff_summary.md)
condenses the result to one row per measure, with the counts of each
status and the size of the differences:

``` r

diff_summary(d)
#>    metric     n n_same n_changed n_only_x n_only_y max_abs_diff mean_abs_diff      rmse max_rel_diff
#>    <char> <int>  <int>     <int>    <int>    <int>        <num>         <num>     <num>        <num>
#> 1: AMOUNT     5      2         1        1        1          0.5     0.1666667 0.2886751  0.002493766
#> 2:  UNITS     5      3         0        1        1          0.0     0.0000000 0.0000000  0.000000000
```

[`diff_report()`](https://pedrobtz.github.io/dazdiff/reference/diff_report.md)
draws the whole comparison as text: the columns compared, how the rows
of the two tables align, and how much each measure differs. Name the two
tables for the drawing:

``` r

diff_report(d, x_name = "benchmark", y_name = "stored")
#> ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#> ┃                            dazdiff report                            ┃
#> ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#>    Identity: id, region
#>    Mode:     benchmark: stored is tested against benchmark
#> 
#>  Columns
#>  ▔▔▔▔▔▔▔
#>    Compared 4 columns: 2 keys, 2 measures.
#>    Only in stored, dropped: loaded_at.
#>    Truncated by the cast to benchmark's types:
#>      Units: 1 value (10.4 -> 10)
#> 
#>  Rows
#>  ▔▔▔▔
#>    benchmark rows               stored rows
#>          4         (no change)       4
#> 
#>    ┏━┯━┯━┯━┯━┓
#>    ┃-│-│-│-│-┃                1 only in benchmark (25.00%)
#>    ┠─┼─┼─┼─┼─┨╌╌╌┏━┯━┯━┯━┯━┓╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
#>    ┃ │ │ │ │ ┃ = ┃ │ │ │ │ ┃  2 same              (66.67%)  │
#>    ┠─┼─┼─┼─┼─┨╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌├╴  3 joined
#>    ┃ │ │ │ │ ┃ ≠ ┃ │ │ │ │ ┃  1 changed           (33.33%)  │
#>    ┗━┷━┷━┷━┷━┛╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯
#>                  ┃+│+│+│+│+┃  1 only in stored    (25.00%)
#>                  ┗━┷━┷━┷━┷━┛
#> 
#>  Measures
#>  ▔▔▔▔▔▔▔▔
#>    ┌─────────┬────────────┬────────────┬──────────────┐
#>    │ Measure │ Match rate │ Max |diff| │ Max rel diff │
#>    ├─────────┼────────────┼────────────┼──────────────┤
#>    │ amount  │     66.67% │        0.5 │     0.002494 │
#>    └─────────┴────────────┴────────────┴──────────────┘
#>    1 other measure matches on every row found in both tables.
#> 
#>  Rows only in benchmark
#>  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#>    ┌────┬────────┐
#>    │ id │ region │
#>    ├────┼────────┤
#>    │ 4  │ "west" │
#>    └────┴────────┘
#> 
#>  Rows only in stored
#>  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#>    ┌────┬─────────┐
#>    │ id │ region  │
#>    ├────┼─────────┤
#>    │ 5  │ "north" │
#>    └────┴─────────┘
```

## Allow a tolerance

[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
is exact by default. A value is `same` when it is within `tolerance`
(absolute) or `rel_tol` (relative to the larger magnitude). With
`rel_tol = 0.01`, the half unit on 200 passes, and only the rows missing
from one table remain:

``` r

d_tol <- diff_table(benchmark, stored, by = c("id", "region"),
                    measures = "numeric+integer", rel_tol = 0.01)
#> Dropped column(s) of `y` that the benchmark `x` does not have: loaded_at.
#> Truncated 1 value(s) while casting to the reference types:
#>   Units: 1 (10.4 -> 10)
d_tol[status != "same"]
#> Key: <ID, REGION, metric>
#>       ID REGION metric row_id_x row_id_y value_x value_y  diff abs_diff rel_diff status
#>    <int> <char> <char>    <int>    <int>   <num>   <num> <num>    <num>    <num> <fctr>
#> 1:     4   west AMOUNT        4       NA     400      NA    NA       NA       NA only_x
#> 2:     4   west  UNITS        4       NA      40      NA    NA       NA       NA only_x
#> 3:     5  north AMOUNT       NA        4      NA     500    NA       NA       NA only_y
#> 4:     5  north  UNITS       NA        4      NA      50    NA       NA       NA only_y
```

To ask one comparison at several thresholds without running it again,
use
[`is_matching()`](https://pedrobtz.github.io/dazdiff/reference/is_matching.md).
It is `TRUE` only when every value is `same`, so the rows found in one
table keep it `FALSE` at any threshold. Among the rows found in both,
the threshold decides:

``` r

is_matching(d, rel_tol = 0.01)
#> [1] FALSE
both <- d[status %in% c("same", "changed")]
is_matching(both)
#> [1] FALSE
is_matching(both, rel_tol = 0.01)
#> [1] TRUE
```

## Find where the differences are

[`diff_explain()`](https://pedrobtz.github.io/dazdiff/reference/diff_explain.md)
says which key columns split the rows that match from the ones that do
not. A column **separates** them when none of its values is `mixed`:
knowing the value tells whether the record matches. A column with a
different value on every row, like `ID`, always separates and so
explains nothing; it is marked **identifies** and listed last. Here no
other column separates:

``` r

diff_explain(d)
#>    column n_values same_only differ_only mixed separates identifies
#>    <char>    <int>     <int>       <int> <int>    <lgcl>     <lgcl>
#> 1: REGION        4         1           2     1     FALSE      FALSE
#> 2: metric        2         0           0     2     FALSE      FALSE
#> 3:     ID        5         2           3     0      TRUE       TRUE
```

Given a column, it lists that column’s values, with each classed as
`same`, `differ` or `mixed`:

``` r

diff_explain(d, "region")
#>    REGION     n n_same n_changed n_only_x n_only_y  class
#>    <char> <int>  <int>     <int>    <int>    <int> <char>
#> 1:  south     1      0         1        0        0 differ
#> 2:   west     1      0         0        1        0 differ
#> 3:  north     2      1         0        0        1  mixed
#> 4:   east     1      1         0        0        0   same
```

## Compare two tables as equals

The default `mode = "benchmark"` takes the first table’s types as the
truth. `mode = "equal"` compares the two tables as peers: nothing is
cast or dropped, and every column must be in both with the same type. So
`stored` does not compare with the benchmark at all:

``` r

diff_table(benchmark, stored, mode = "equal")
#> Error:
#> ! mode = "equal" needs the same columns in both tables
#>   only in `x`: <none>
#>   only in `y`: loaded_at
```

Row order never matters, because rows are aligned on their identity.
With no `by`, the identity is every column that is not a measure:

``` r

diff_table(benchmark, benchmark[c(4, 1, 2, 3), ], mode = "equal")
#> Key: <ID, REGION, UNITS, metric>
#>       ID REGION UNITS metric row_id_x row_id_y value_x value_y  diff abs_diff rel_diff status
#>    <int> <char> <int> <char>    <int>    <int>   <num>   <num> <num>    <num>    <num> <fctr>
#> 1:     1  north    10 AMOUNT        1        2     100     100     0        0        0   same
#> 2:     2  south    20 AMOUNT        2        3     200     200     0        0        0   same
#> 3:     3   east    30 AMOUNT        3        4     300     300     0        0        0   same
#> 4:     4   west    40 AMOUNT        4        1     400     400     0        0        0   same
```

In either mode, a comparison with no measures compares rows as wholes,
which answers “do the two tables have the same rows?”. A repeated row
counts once per copy, numbered by `key_seq`:

``` r

diff_table(
  benchmark[c("id", "region")],
  data.frame(ID = c(3L, 1L, 2L, 2L), REGION = c("east", "north", "south", "south"))
)
#> No measure columns (measures = "numeric"), so rows are compared as wholes: do the two tables have the same rows?
#> Key: <ID, REGION, key_seq>
#>       ID REGION key_seq row_id_x row_id_y status
#>    <int> <char>   <int>    <int>    <int> <fctr>
#> 1:     1  north       1        1        2   same
#> 2:     2  south       1        2        3   same
#> 3:     2  south       2       NA        4 only_y
#> 4:     3   east       1        3        1   same
#> 5:     4   west       1        4       NA only_x
```

A key that repeats in a comparison with measures is paired in arrival
order, with a warning. `duplicates = "aggregate"` compares the repeats
as multisets instead, and `duplicates = "error"` refuses them. A table
with no key column at all can get a virtual one: `row_key = "position"`
pairs rows as they come, and `row_key = "sorted"` pairs them after
sorting both tables by their values.

## Use it in tests

[`expect_table_equal()`](https://pedrobtz.github.io/dazdiff/reference/expect_table_equal.md)
is a testthat expectation built on
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).
Its second argument, `expected`, is the benchmark, as in testthat’s
`expect_equal()`. Like any expectation, it is silent when it passes,
here on the same rows in another order:

``` r

reference <- benchmark
expect_table_equal(benchmark[c(4, 1, 2, 3), ], reference)
```

Unlike
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md),
it allows a relative difference of `sqrt(.Machine$double.eps)` (about
`1.5e-8`) by default, as `expect_equal()` does, so floating-point noise
does not fail a test. Pass `rel_tol = 0` to compare exactly. A failure
shows
[`diff_summary()`](https://pedrobtz.github.io/dazdiff/reference/diff_summary.md)
and the first records that differ. A key that repeats is an error rather
than a guess, unless you pass `duplicates = "disambiguate"` or
`duplicates = "aggregate"`.

In a test file it reads like any other expectation:

``` r

test_that("the pipeline reproduces the reference output", {
  expect_table_equal(run_pipeline(), reference)
})
```

## Where next

- [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md):
  every argument, including `exclude`, `nan_is_na` and `truncate`, and
  how values are classified.
- [`normalize_dt()`](https://pedrobtz.github.io/dazdiff/reference/normalize_dt.md):
  prepare columns of a type other than character, logical, Date, numeric
  and integer.
- [`cast_rules()`](https://pedrobtz.github.io/dazdiff/reference/cast_rules.md)
  and
  [`compare_columns()`](https://pedrobtz.github.io/dazdiff/reference/compare_columns.md):
  the casts
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
  makes, and how the columns of two tables line up.
- [Reference](https://pedrobtz.github.io/dazdiff/reference/index.md):
  every function.
