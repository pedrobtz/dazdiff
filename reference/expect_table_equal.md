# Expect a table to match another

A testthat expectation built on
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md):
it passes when every compared value is `same`. `expected` is the
benchmark, as in testthat's `expect_equal(object, expected)`, so the
comparison is `diff_table(expected, object, ...)`: `object` is cast to
`expected`'s types and its extra columns are dropped. Pass
`mode = "equal"` to compare the two as peers instead.

## Usage

``` r
expect_table_equal(
  object,
  expected,
  ...,
  rel_tol = sqrt(.Machine$double.eps),
  max_rows = 10L
)
```

## Arguments

- object:

  The table under test.

- expected:

  The benchmark table.

- ...:

  Passed to
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md):
  `mode`, `by`, `measures`, `tolerance`, `duplicates` and so on.

- rel_tol:

  The largest relative difference still counted as `same`, as in
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).
  With `duplicates = "aggregate"`, which compares exactly, it defaults
  to 0.

- max_rows:

  The most records that differ shown in a failure.

## Value

The
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
result, invisibly. On failure it is also attached to the failed
expectation, as its `"diff"` attribute. `NULL` when the tables share no
key, since there is no result.

## Details

Unlike
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md),
which is exact by default, the expectation allows a relative difference
of `sqrt(.Machine$double.eps)` (about `1.5e-8`), the default of
testthat's `expect_equal()`: a value computed again rarely agrees with
its stored copy to the last bit (`0.1 + 0.2` is not `0.3`), and a test
should not fail on that. It is still far below any difference a person
would call real. Pass `rel_tol = 0` for an exact comparison.

Duplicate keys are an error (`dazdiff_error_duplicates`), not a failure:
pairing rows by arrival order is an assumption, and an assertion should
not rest on one, so the test cannot be judged as written. The exception
is a comparison with no measures, where the repeated rows are identical
in every compared column and pairing them assumes nothing. Pass
`duplicates = "disambiguate"` or `"aggregate"` to accept duplicates.

Tables that share no key – most often because `object` came back empty –
fail the expectation.
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
refuses such a comparison as ill-formed, but under test it is an answer:
the two tables differ in every row.

## Examples

``` r
expected <- data.frame(id = 1:3, amount = c(10, 20, 30))
actual <- data.frame(id = 1:3, amount = c(10, 20, 30 + 1e-9))
expect_table_equal(actual, expected, tolerance = 1e-6)
```
