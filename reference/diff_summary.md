# Summarize a comparison by measure

Counts of each status for every measure of a
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
result, and, for the usual one-row-per-value shape, how large the
differences are.

## Usage

``` r
diff_summary(d)
```

## Arguments

- d:

  A result of
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).

## Value

A `data.table` with one row per measure, in the benchmark's column order
(a single row when there are no measures): `metric`, `n`, `n_same`,
`n_changed`, `n_only_x`, `n_only_y`, and for the `"cells"` shape
`max_abs_diff`, `mean_abs_diff`, `rmse` and `max_rel_diff` (`NA` for a
measure with no finite pair).

## Details

The magnitudes are taken over every value compared on both sides where
both source values are finite. They are filtered on the source values,
not on `diff`: two finite values can differ by more than the largest
double, and filtering on the difference would drop exactly that value
and report the largest difference in the table as 0. `rmse` is computed
with scaling, so squaring cannot overflow either.

## Examples

``` r
x <- data.frame(id = 1:3, amount = c(10, 20, 30), rate = c(1, 1, 1))
y <- data.frame(id = 1:3, amount = c(10, 25, 27), rate = c(1, 1, 1))
diff_summary(diff_table(x, y))
#>    metric     n n_same n_changed n_only_x n_only_y max_abs_diff mean_abs_diff
#>    <char> <int>  <int>     <int>    <int>    <int>        <num>         <num>
#> 1: AMOUNT     3      1         2        0        0            5      2.666667
#> 2:   RATE     3      3         0        0        0            0      0.000000
#>        rmse max_rel_diff
#>       <num>        <num>
#> 1: 3.366502          0.2
#> 2: 0.000000          0.0
```
