# Do the two tables match?

`TRUE` when every record of a
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
result is `same`: no value changed and no row is found in only one
table. Two empty tables match.

## Usage

``` r
is_matching(d, tolerance = NULL, rel_tol = NULL)
```

## Arguments

- d:

  A result of
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).

- tolerance, rel_tol:

  `NULL` (the default) keeps the thresholds of the comparison. A number
  re-judges the values: a value matches when within either. When only
  one is given, the other is 0.

## Value

`TRUE` or `FALSE`.

## Details

With `tolerance` or `rel_tol` given, the values are judged again at
those thresholds instead of the ones
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
used, from the `abs_diff` and `rel_diff` it stores. That works in both
directions, looser or stricter, so one comparison can be asked at
several thresholds without being run again. The rule is
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)'s:
two equal or two missing values always match, and the tolerances apply
to finite pairs only. A row found in only one table never matches,
whatever the threshold.

## Examples

``` r
x <- data.frame(id = 1:3, amount = c(100, 200, 300))
y <- data.frame(id = 1:3, amount = c(100, 200.5, 300))
d <- diff_table(x, y)
is_matching(d)
#> [1] FALSE
is_matching(d, tolerance = 1)
#> [1] TRUE
is_matching(d, rel_tol = 0.001)
#> [1] FALSE
is_matching(d, rel_tol = 0.01)
#> [1] TRUE
```
