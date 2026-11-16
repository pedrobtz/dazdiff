# Report on a comparison, as text

A bounded, readable account of a
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
result: which columns were compared, how the rows of the two tables
align, and, for each measure that changed, how often it matches and by
how much it differs. Printing the report draws it; the numbers are in
the returned list.

## Usage

``` r
diff_report(d, x_name = "x", y_name = "y", sample_k = 5L)
```

## Arguments

- d:

  A result of
  [`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md).

- x_name, y_name:

  The names the report gives the two tables.

- sample_k:

  The number of keys shown of the rows found in only one table; 0 hides
  them.

## Value

A `dazdiff_report`: a list holding the counts the report draws, with
[`format()`](https://rdrr.io/r/base/format.html) and
[`print()`](https://rdrr.io/r/base/print.html) methods.
[`format()`](https://rdrr.io/r/base/format.html) takes `unicode`,
whether to draw with box-drawing characters (by default, when the
session's encoding is UTF-8), and returns the lines of text.

## Details

A row counts as `changed` when any of its measures changed. With
`duplicates = "aggregate"` the units are keys rather than rows.

The counts describe the records passed in. A filtered result, such as
`d[status != "same"]`, is reported as if it were the whole comparison,
so its match rates are those of the subset; report the full result for
table-level figures.

The layout is adapted from the summary of the Python package
[diffly](https://github.com/Quantco/diffly).

## Examples

``` r
x <- data.frame(id = c("a", "b", "c"), value = c(1, 2, 3))
y <- data.frame(id = c("a", "b", "d"), value = c(1, 2.5, 4))
diff_report(diff_table(x, y))
#> ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#> ┃                        dazdiff report                        ┃
#> ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#>    Identity: id
#>    Mode:     benchmark: y is tested against x
#> 
#>  Columns
#>  ▔▔▔▔▔▔▔
#>    Compared 2 columns: 1 key, 1 measure.
#> 
#>  Rows
#>  ▔▔▔▔
#>    x rows               y rows
#>      3     (no change)    3
#> 
#>    ┏━┯━┯━┯━┯━┓
#>    ┃-│-│-│-│-┃                1 only in x (33.33%)
#>    ┠─┼─┼─┼─┼─┨╌╌╌┏━┯━┯━┯━┯━┓╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
#>    ┃ │ │ │ │ ┃ = ┃ │ │ │ │ ┃  1 same      (50.00%)  │
#>    ┠─┼─┼─┼─┼─┨╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌├╴  2 joined
#>    ┃ │ │ │ │ ┃ ≠ ┃ │ │ │ │ ┃  1 changed   (50.00%)  │
#>    ┗━┷━┷━┷━┷━┛╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯
#>                  ┃+│+│+│+│+┃  1 only in y (33.33%)
#>                  ┗━┷━┷━┷━┷━┛
#> 
#>  Measures
#>  ▔▔▔▔▔▔▔▔
#>    ┌─────────┬────────────┬────────────┬──────────────┐
#>    │ Measure │ Match rate │ Max |diff| │ Max rel diff │
#>    ├─────────┼────────────┼────────────┼──────────────┤
#>    │ value   │     50.00% │        0.5 │          0.2 │
#>    └─────────┴────────────┴────────────┴──────────────┘
#> 
#>  Rows only in x
#>  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#>    ┌─────┐
#>    │ id  │
#>    ├─────┤
#>    │ "c" │
#>    └─────┘
#> 
#>  Rows only in y
#>  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#>    ┌─────┐
#>    │ id  │
#>    ├─────┤
#>    │ "d" │
#>    └─────┘

print(diff_report(diff_table(x, y)), unicode = FALSE)
#> +==============================================================+
#> |                        dazdiff report                        |
#> +==============================================================+
#>    Identity: id
#>    Mode:     benchmark: y is tested against x
#> 
#>  Columns
#>  -------
#>    Compared 2 columns: 1 key, 1 measure.
#> 
#>  Rows
#>  ----
#>    x rows               y rows
#>      3     (no change)    3
#> 
#>    +=+=+=+=+=+
#>    |-|-|-|-|-|                1 only in x (33.33%)
#>    +-+-+-+-+-+...+=+=+=+=+=+........................+
#>    | | | | | | = | | | | | |  1 same      (50.00%)  |
#>    +-+-+-+-+-+...+-+-+-+-+-+........................+-  2 joined
#>    | | | | | | ! | | | | | |  1 changed   (50.00%)  |
#>    +=+=+=+=+=+...+-+-+-+-+-+........................+
#>                  |+|+|+|+|+|  1 only in y (33.33%)
#>                  +=+=+=+=+=+
#> 
#>  Measures
#>  --------
#>    +---------+------------+------------+--------------+
#>    | Measure | Match rate | Max |diff| | Max rel diff |
#>    +---------+------------+------------+--------------+
#>    | value   |     50.00% |        0.5 |          0.2 |
#>    +---------+------------+------------+--------------+
#> 
#>  Rows only in x
#>  --------------
#>    +-----+
#>    | id  |
#>    +-----+
#>    | "c" |
#>    +-----+
#> 
#>  Rows only in y
#>  --------------
#>    +-----+
#>    | id  |
#>    +-----+
#>    | "d" |
#>    +-----+
```
