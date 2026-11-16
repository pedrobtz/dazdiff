# Explain a comparison by its key columns

Which values of the key columns separate the rows that match from the
ones that do not. After
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
reports differences, the next question is usually *where*: one region,
one load date, one measure. This answers it from the result alone.

## Usage

``` r
diff_explain(d, column = NULL, among = c("all", "joined"))
```

## Arguments

- d:

  A result of
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).

- column:

  `NULL` (the default) for the overview of every key column, or one
  column to break down by value: a key column, in either spelling, or
  `"metric"`.

- among:

  `"all"` (the default) counts every record; `"joined"` only those of
  rows found in both tables.

## Value

A `data.table`. The overview has `column`, `n_values`, `same_only`,
`differ_only` and `mixed` (the number of values of each class),
`separates` and `identifies`. The breakdown has the column's values,
`n`, `n_same`, `n_changed`, `n_only_x`, `n_only_y` and `class`.

## Details

Called with no `column`, it returns one row per key column, and per
`metric` when the result has measures. Each distinct value of the column
is classed by the records that hold it: `same` when every one of them
matches, `differ` when none does, `mixed` otherwise. A column
`separates` the result when no value is mixed: knowing the value tells
whether the record matches.

A column that holds a different value on every row (an id) always
separates and explains nothing; it is marked `identifies` and ranked
last. The others come first, fewest mixed values first, then fewest
values: the shortest explanation leads.

Called with a `column`, it returns one row per value of that column,
with its counts of each status, most differences first: the values to
look at.

## What is counted

For a key column the unit is the row: a row matches only when every one
of its measures does, as in
[`diff_report()`](https://pedrobtz.github.io/dazdiff/reference/diff_report.md).
With `duplicates = "aggregate"` the unit is the key. For `metric` the
unit is the value, one per row and measure, so it can say that only one
measure changes.

A row found in only one table and a value that changed usually have
different causes. `among = "joined"` counts only the rows found in both
tables, so the explanation is of the changed values alone.

## Examples

``` r
x <- data.frame(
  id = 1:4,
  region = c("north", "south", "east", "west"),
  amount = c(100, 200, 300, 400)
)
y <- data.frame(
  id = c(1:3, 5L),
  region = c("north", "south", "east", "north"),
  amount = c(100, 200.5, 300, 500)
)
d <- diff_table(x, y, by = c("id", "region"))
diff_explain(d)
#>    column n_values same_only differ_only mixed separates identifies
#>    <char>    <int>     <int>       <int> <int>    <lgcl>     <lgcl>
#> 1: metric        1         0           0     1     FALSE      FALSE
#> 2: REGION        4         1           2     1     FALSE      FALSE
#> 3:     ID        5         2           3     0      TRUE       TRUE
diff_explain(d, "region")
#>    REGION     n n_same n_changed n_only_x n_only_y  class
#>    <char> <int>  <int>     <int>    <int>    <int> <char>
#> 1:  south     1      0         1        0        0 differ
#> 2:   west     1      0         0        1        0 differ
#> 3:  north     2      1         0        0        1  mixed
#> 4:   east     1      1         0        0        0   same
diff_explain(d, "region", among = "joined")
#>    REGION     n n_same n_changed n_only_x n_only_y  class
#>    <char> <int>  <int>     <int>    <int>    <int> <char>
#> 1:  south     1      0         1        0        0 differ
#> 2:   east     1      1         0        0        0   same
#> 3:  north     1      1         0        0        0   same
```
