# Convert a table to the types dazdiff compares

[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
compares columns of five types: character, logical, Date, numeric
(double) and integer. In `mode = "benchmark"` the benchmark `x` must
already hold only those; in `mode = "equal"` both tables must. This
converts the columns that are something else, explicitly, so that any
lossy conversion is the caller's choice and not a silent default.

## Usage

``` r
normalize_dt(dt, to = c(factor = "character"), cols = names(dt))
```

## Arguments

- dt:

  A data.frame or data.table.

- to:

  Named character: which supported type (`"character"`, `"logical"`,
  `"Date"`, `"numeric"` or `"integer"`) each other type becomes, named
  by `"factor"`, `"POSIXct"` or `"integer64"`. The mappings given are
  added to the default, `factor` to `"character"`, and replace it only
  where they name `factor` themselves. A column whose type is in neither
  is an error, not a guess.

- cols:

  The columns to consider, by default all of them.

## Value

A `data.table`. `dt` is never modified; a copy is made only when there
is something to convert, so the result is `dt` itself when there is not,
and callers must treat it as read-only.

## Details

A factor (ordered or not) becomes its labels by default. A timestamp
(POSIXct) has no default: `c(POSIXct = "Date")` keeps the calendar day
in the stamp's own zone (the session's zone for a stamp with none, as it
prints) and drops the time, so two stamps on the same day become one
value; `c(POSIXct = "character")` keeps the stamp as text, written as
its local time in its own zone as `"%Y-%m-%d %H:%M:%S"` (with the
fraction of a second, to the microsecond, when it has one) and without
naming the zone, so the same instant held in two zones becomes two
different strings: give both tables the same zone first. Name the one
you mean in `to`.

An `integer64` column (from bit64) has no default either:
`c(integer64 = "numeric")` is exact below 2^53 and refuses larger
values, `"integer"` refuses values outside the integer range, and
`"character"` keeps every digit.

## Examples

``` r
x <- data.frame(
  day = as.POSIXct("2024-01-01 10:00", tz = "UTC"),
  kind = factor("a"),
  amount = 1.5
)
normalize_dt(x, to = c(POSIXct = "Date", factor = "character"))
#>           day   kind amount
#>        <Date> <char>  <num>
#> 1: 2024-01-01      a    1.5
```
