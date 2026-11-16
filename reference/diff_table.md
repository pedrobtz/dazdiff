# Compare two tables value by value

`x` is the benchmark: in the default `mode = "benchmark"` it is the
source of truth, and `y` is the table being tested against it. With
`mode = "equal"` the two are peers, and the question is simply whether
they are equal. Rows are aligned on their identity columns and every
numeric measure is compared, one row per value, each traceable to its
source row in both tables.

## Usage

``` r
diff_table(
  x,
  y,
  mode = c("benchmark", "equal"),
  by = NULL,
  exclude = NULL,
  row_key = c("none", "position", "sorted"),
  measures = "numeric",
  tolerance = 0,
  rel_tol = 0,
  duplicates = c("disambiguate", "aggregate", "error"),
  cast = mode == "benchmark",
  truncate = TRUE,
  nan_is_na = TRUE,
  date_format = "%Y-%m-%d"
)
```

## Arguments

- x:

  The benchmark table (in `"equal"` mode, simply the first table).

- y:

  The table to compare with it.

- mode:

  `"benchmark"` (the default) or `"equal"`. See Modes.

- by:

  Identity columns, by name, in either spelling. `NULL` (the default)
  uses every column that is not a measure.

- exclude:

  Columns to leave out of the comparison, by name, in either spelling.
  They are removed from both tables before anything else, in either
  mode: an excluded column need not be in both tables, is not announced
  as dropped or ignored, and does not stop `mode = "equal"` from calling
  the rest equal. A name in neither table is a warning, not an error, so
  one list of technical columns can serve many tables; a name that `by`
  or `measures` also names is an error.

- row_key:

  `"none"` (the default), `"position"` or `"sorted"`: add a virtual
  `row_number` key column. See Well-formed tables.

- measures:

  `"numeric"` (the default) compares the double columns;
  `"numeric+integer"` the integer columns too. Or column names, which
  must be numeric or integer, or `character(0)` for none, which compares
  whole rows.

- tolerance:

  The largest absolute difference still counted as `same`.

- rel_tol:

  The largest relative difference still counted as `same`, relative to
  the larger magnitude of the two values. A value is `same` when it is
  within either tolerance.

- duplicates:

  `"disambiguate"` (the default), `"aggregate"` or `"error"`. See
  Duplicate keys.

- cast:

  Whether to cast `y` to `x`'s types. Defaults to `TRUE` in benchmark
  mode; with `FALSE` the types must already agree. Equal mode never
  casts.

- truncate:

  Whether a cast may drop a fraction. See Truncation.

- nan_is_na:

  Whether NaN and NA are the same missing value.

- date_format:

  The format text dates are read in when cast to `Date`. Text must match
  it exactly, so a string that merely starts with a date is refused
  rather than read as one.

## Value

A `data.table` keyed by the identity columns (and `key_seq`, `metric`
when present), with `status` a factor with levels `same`, `changed`,
`only_x` and `only_y`. The key includes `row_number` when `row_key`
added it. Its shape is in `attr(d, "shape")`:

- `"cells"`, the usual one: one row per row and measure, with `key_seq`
  (only when duplicates were numbered), `metric`, `row_id_x`, `row_id_y`
  (the source rows, `NA` on the side the row is missing from),
  `value_x`, `value_y`, `diff` (`value_y - value_x`), `abs_diff`
  (`abs(diff)`), `rel_diff`
  (`abs_diff / pmax(abs(value_x), abs(value_y))`, 0 when both are 0,
  `NA` unless both are finite) and `status`.

- `"groups"`, with `duplicates = "aggregate"`: one row per key and
  measure, with `n_rows_x`, `n_rows_y`, `n_na_x`, `n_na_y`,
  `value_key_x`, `value_key_y` (the exact multiset of values, as
  hexadecimal text from the C library: compare them within one session,
  not with text stored on another platform) and `status`. Without
  measures only the row counts are compared.

- `"rows"`, when there are no measures: one row per row, with `key_seq`
  (when present), `row_id_x`, `row_id_y` and `status`, which is never
  `changed`.

The attributes `mode`, `tolerance` (`abs` and `rel`), `name_map` (each
column's name in `x` and `y`), `dropped` (columns of `y` dropped in
benchmark mode), `excluded` (the columns `exclude` removed, as named in
`x` or `y`), `ignored` (columns not compared) and `truncated` (the casts
that truncated, with the rows of `y` each one touched) record what was
done on the way.

## Modes

- `"benchmark"`: does `y` match the benchmark `x`? Columns of `y` that
  `x` does not have are dropped, with a message. A column of `x` missing
  from `y` is an error. Each compared column of `y` (in `by` or
  `measures`) is cast to the type it has in `x` (see
  [`cast_rules()`](https://pedrobtz.github.io/dazdiff/reference/cast_rules.md)),
  so a number stored as text, or a double stored as an integer, still
  compares. Columns that are not compared are neither cast nor
  type-checked. A number cast to text is written with the decimals `x`
  uses, when every value of `x`'s column uses the same number of them:
  `2` in `y` becomes `"2.0"` to meet `x`'s `"2.0"`, which a message
  announces. A value of `x` that equals one of `y`'s as a number but not
  as text is warned about, since those rows will not align.

- `"equal"`: are `x` and `y` equal? Every column must be in both tables
  and have the same type in both; nothing is cast. The result is
  symmetric: swapping `x` and `y` swaps `only_x` with `only_y` and
  negates `diff`.

## Column names

Column names are normalized in both tables before anything else: upper
case, with every run of characters other than letters and digits
replaced by `_`, and `_` trimmed from the ends. Letters outside ASCII
are kept, so `Größe` and `Grüße` stay two columns. So `unit price`,
`Unit.Price` and `UNIT_PRICE` are one column, in either table. Two names
in one table that normalize to the same thing are an error to fix before
comparing. The result uses the normalized names; `attr(d, "name_map")`
maps them back.

## Truncation

In benchmark mode a cast that drops a fraction – a double to an integer,
a number or a timestamp to a whole day – is made by default, because the
benchmark's types are taken as the truth: storage such as Spark or Delta
turns a locally built double into an integer, and the comparison has to
follow it. Each truncation is announced in a message and recorded in
`attr(d, "truncated")`: per column, the count, up to three examples, and
in the list column `rows` the row numbers of `y` that were truncated,
which are the `row_id_y` of the result. A truncated key column can pair
rows that differ (`1.5` in `y` becomes `1` and aligns with `x`'s `1`),
so read the message when it names a key, and find the rows with
`d[row_id_y %in% attr(d, "truncated")$rows[[1]]]`. Set
`truncate = FALSE` to refuse such casts instead.

## Measures and identity

The measures are the numeric columns compared value by value; `measures`
picks them by type or by name, always from `x`. The row identity is `by`
when given, otherwise every column that is not a measure. With `by`
given, a column in neither role is not compared: that is announced in
benchmark mode and an error in equal mode, which cannot call two tables
equal while ignoring a column. A numeric column that is part of the
identity is matched exactly, with no tolerance. So is a Date key, on its
exact value: a Date can hold a fraction of a day, and two Dates that
print as the same day then do not align.

With no measures at all the question becomes *do the two tables have the
same rows?*, and the result has one row per row (see Value).

## Well-formed tables

A table must have at least one key column to be compared; it may have no
measures. When every column is a measure there is nothing to align rows
on, and `diff_table()` refuses unless it is given a key: `by`, fewer
`measures`, or a virtual one with `row_key`, which adds a `row_number`
key column to both tables:

- `"position"` numbers the rows as they come, so row *i* of `x` pairs
  with row *i* of `y`, and a different row order shows as differences.

- `"sorted"` numbers the rows after sorting both tables by all their
  compared columns, so row order does not matter. Compared exactly, that
  pairs the tables as multisets of rows, and cannot pass two tables that
  hold different rows. It can pair badly instead: one changed value can
  move its row within the sort, and the rows after it then pair with the
  wrong partners and show as changes too. With other key columns, rows
  are sorted and numbered within each of their groups.

## Duplicate keys

When the identity does not tell rows apart, `duplicates` decides:

- `"disambiguate"` numbers the rows of each repeated key in arrival
  order (`key_seq`) and pairs them by that number, with a warning: the
  pairing is an assumption. Reordered rows then show as changes, never
  as matches. Without measures the repeated rows are identical in every
  compared column, so pairing them assumes nothing and there is no
  warning.

- `"aggregate"` compares the multiset of values of each key and measure
  instead, exactly (`tolerance` must be 0).

- `"error"` refuses.

## Values

A value is `same` when both are equal, or when both are finite and their
difference is within `tolerance` or within `rel_tol` relative to the
larger of the two: `abs_diff <= tolerance` or `rel_diff <= rel_tol`.
Both tolerances default to 0, so by default only equal values are the
same. Two missing values are the same; with `nan_is_na = TRUE` NaN and
NA are the same missing value, in measures and in key columns alike.

## Conditions

Every condition `diff_table()` signals has a class, so it can be caught
or tested for without matching its text, and inherits from
`dazdiff_error`, `dazdiff_warning` or `dazdiff_message`. An error means
the question cannot be answered; a warning, that the answer may be
wrong; a message reports an expected consequence of the settings.

- `dazdiff_error_input`: an argument is malformed.

- `dazdiff_error_columns`: columns missing, unknown, or not compared in
  equal mode; names that are empty or collide once normalized.

- `dazdiff_error_types`: a column of a type that cannot be compared, or
  types that differ where nothing is cast.

- `dazdiff_error_cast`: a value that cannot be cast to the benchmark's
  type.

- `dazdiff_error_keys`: no key column to align rows on.

- `dazdiff_error_measures`: `measures` names something that cannot be
  measured, or a column `by` names too.

- `dazdiff_error_duplicates`: repeated keys under
  `duplicates = "error"`.

- `dazdiff_error_disjoint`: no key appears in both tables. Its field
  `disjoint_columns` names the key columns that alone share no value,
  and `constant_columns` those among them holding one value in each
  table (a run id, a source tag), which usually belong in `exclude`.

- `dazdiff_error_dependency`: a suggested package is needed but missing.

- `dazdiff_warning_duplicates`: repeated keys paired in arrival order.

- `dazdiff_warning_exclude`: `exclude` names a column in neither table.

- `dazdiff_warning_cast_format`: a number of `y` cast to text does not
  match `x`'s text for the same number (`"2.00"` against `"2"`).

- `dazdiff_message_dropped_columns`, `dazdiff_message_ignored_columns`,
  `dazdiff_message_no_measures`, `dazdiff_message_truncation`,
  `dazdiff_message_cast_format`: columns of `y` dropped, columns not
  compared, no measures, values truncated, numbers written as text in
  `x`'s format.

## Examples

``` r
benchmark <- data.frame(id = 1:4, amount = c(10, 20, 30, 40))
tested <- data.frame(
  ID = c("1", "2", "3", "5"),
  Amount = c(10, 20.5, 30, 50),
  loaded_at = "2024-01-01"
)
d <- diff_table(benchmark, tested)
#> Dropped column(s) of `y` that the benchmark `x` does not have: loaded_at.
d
#> Key: <ID, metric>
#>       ID metric row_id_x row_id_y value_x value_y  diff abs_diff   rel_diff
#>    <int> <char>    <int>    <int>   <num>   <num> <num>    <num>      <num>
#> 1:     1 AMOUNT        1        1      10    10.0   0.0      0.0 0.00000000
#> 2:     2 AMOUNT        2        2      20    20.5   0.5      0.5 0.02439024
#> 3:     3 AMOUNT        3        3      30    30.0   0.0      0.0 0.00000000
#> 4:     4 AMOUNT        4       NA      40      NA    NA       NA         NA
#> 5:     5 AMOUNT       NA        4      NA    50.0    NA       NA         NA
#>     status
#>     <fctr>
#> 1:    same
#> 2: changed
#> 3:    same
#> 4:  only_x
#> 5:  only_y
d[status != "same"]
#> Key: <ID, metric>
#>       ID metric row_id_x row_id_y value_x value_y  diff abs_diff   rel_diff
#>    <int> <char>    <int>    <int>   <num>   <num> <num>    <num>      <num>
#> 1:     2 AMOUNT        2        2      20    20.5   0.5      0.5 0.02439024
#> 2:     4 AMOUNT        4       NA      40      NA    NA       NA         NA
#> 3:     5 AMOUNT       NA        4      NA    50.0    NA       NA         NA
#>     status
#>     <fctr>
#> 1: changed
#> 2:  only_x
#> 3:  only_y

# Equal mode: no casting, every column in both tables.
diff_table(benchmark, benchmark, mode = "equal")
#> Key: <ID, metric>
#>       ID metric row_id_x row_id_y value_x value_y  diff abs_diff rel_diff
#>    <int> <char>    <int>    <int>   <num>   <num> <num>    <num>    <num>
#> 1:     1 AMOUNT        1        1      10      10     0        0        0
#> 2:     2 AMOUNT        2        2      20      20     0        0        0
#> 3:     3 AMOUNT        3        3      30      30     0        0        0
#> 4:     4 AMOUNT        4        4      40      40     0        0        0
#>    status
#>    <fctr>
#> 1:   same
#> 2:   same
#> 3:   same
#> 4:   same

# Leave a column out of the comparison, in either table.
diff_table(benchmark, tested, exclude = "loaded_at")
#> Key: <ID, metric>
#>       ID metric row_id_x row_id_y value_x value_y  diff abs_diff   rel_diff
#>    <int> <char>    <int>    <int>   <num>   <num> <num>    <num>      <num>
#> 1:     1 AMOUNT        1        1      10    10.0   0.0      0.0 0.00000000
#> 2:     2 AMOUNT        2        2      20    20.5   0.5      0.5 0.02439024
#> 3:     3 AMOUNT        3        3      30    30.0   0.0      0.0 0.00000000
#> 4:     4 AMOUNT        4       NA      40      NA    NA       NA         NA
#> 5:     5 AMOUNT       NA        4      NA    50.0    NA       NA         NA
#>     status
#>     <fctr>
#> 1:    same
#> 2: changed
#> 3:    same
#> 4:  only_x
#> 5:  only_y

# No key at all: align rows by sorting both tables by their values.
diff_table(
  data.frame(a = c(3, 1, 2), b = c(30, 10, 20)),
  data.frame(a = c(1, 2, 3), b = c(10, 25, 30)),
  row_key = "sorted"
)
#> Key: <row_number, metric>
#>    row_number metric row_id_x row_id_y value_x value_y  diff abs_diff rel_diff
#>         <int> <char>    <int>    <int>   <num>   <num> <num>    <num>    <num>
#> 1:          1      A        2        1       1       1     0        0      0.0
#> 2:          1      B        2        1      10      10     0        0      0.0
#> 3:          2      A        3        2       2       2     0        0      0.0
#> 4:          2      B        3        2      20      25     5        5      0.2
#> 5:          3      A        1        3       3       3     0        0      0.0
#> 6:          3      B        1        3      30      30     0        0      0.0
#>     status
#>     <fctr>
#> 1:    same
#> 2:    same
#> 3:    same
#> 4: changed
#> 5:    same
#> 6:    same

# No measures: do the tables have the same rows?
diff_table(data.frame(k = c("a", "b")), data.frame(k = c("b", "c", "a")))
#> No measure columns (measures = "numeric"), so rows are compared as wholes: do the two tables have the same rows?
#> Key: <K>
#>         K row_id_x row_id_y status
#>    <char>    <int>    <int> <fctr>
#> 1:      a        1        3   same
#> 2:      b        2        1   same
#> 3:      c       NA        2 only_y
```
