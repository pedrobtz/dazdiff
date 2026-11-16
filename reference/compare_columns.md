# Compare the columns of two tables

The schema view of a comparison: which columns each table has, their
types, and how much their values overlap. It reads every column of both
tables, including the ones
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
would drop, so it is the place to look when a comparison refuses to run.

## Usage

``` r
compare_columns(x, y)
```

## Arguments

- x, y:

  Tables to compare: data.frames or data.tables.

## Value

A `data.table` with one row per column of either side: the normalized
name `colname`, the names as written in each table (`name_x`, `name_y`),
the two types and whether they match, the two unique counts, and the
value overlap (`n_common`, `n_union`, `over_pct`). Rows follow `x`'s
column order, then whatever is only in `y`. A column missing from one
side has `NA` for that side. A list column has `NA` counts and no
overlap.

## Details

Column names are normalized first, as
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
does: upper case, with every run of other characters replaced by `_`,
and `_` trimmed from both ends. So `amount` in `x` and `Amount` in `y`
are one column. Two names in one table that normalize to the same thing
are an error.

`over_pct` is the distinct values shared by both sides over the distinct
values seen in either, `n_common / n_union`. 100 means the two columns
draw on exactly the same set of values; a value `y` invents or one it
never uses both pull it down.

The overlap is measured only where the two types agree. `%in%` coerces
before matching, so a numeric 1 would count as a match for the string
`"1"` and two columns that are not the same thing would report a full
overlap. A column whose type differs gets `NA` for `n_common`, `n_union`
and `over_pct`.

## Examples

``` r
x <- data.frame(id = 1:3, amount = c(1, 2, 3))
y <- data.frame(ID = c(1L, 2L, 4L), Amount = c("1", "2", "3"), note = "a")
compare_columns(x, y)
#>    colname name_x name_y  type_x    type_y type_match n_unique_x n_unique_y
#>     <char> <char> <char>  <char>    <char>     <lgcl>      <int>      <int>
#> 1:      ID     id     ID integer   integer       TRUE          3          3
#> 2:  AMOUNT amount Amount numeric character      FALSE          3          3
#> 3:    NOTE   <NA>   note    <NA> character         NA         NA          1
#>    n_common n_union over_pct
#>       <int>   <int>    <num>
#> 1:        2       4       50
#> 2:       NA      NA       NA
#> 3:       NA      NA       NA
```
