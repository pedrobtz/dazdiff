# The type conversions dazdiff will make

In `mode = "benchmark"`,
[`diff_table()`](https://pedrobtz.github.io/dazdiff/reference/diff_table.md)
casts each column of the candidate to the type it has in the benchmark.
These are the conversions it will attempt and the ones it refuses. A
conversion that would need a guess – a number read as a flag, a factor's
integer codes read as values – is refused rather than made.

## Usage

``` r
cast_rules(wide = TRUE)
```

## Arguments

- wide:

  If `TRUE` (the default), a grid of source types by target types, with
  `"yes"` for an allowed conversion, `"-"` for a refused one and `"="`
  where source and target are the same type. If `FALSE`, one row per
  pair, with each rule's `note`.

## Value

A `data.table`.

## Details

A cast that drops the fraction of a value (a double to an integer, a
timestamp to its calendar day, a Date holding part of a day to its text)
is a *truncation*: it is made when `truncate = TRUE`, which is the
default, and refused otherwise.

Text is parsed strictly: anything that is not a number, a logical
literal or a date in `date_format` is refused, and that includes the
text `"NA"`, since a missing value has to arrive as `NA`. `"NaN"` and
`"Inf"` are numbers. A double written as text is written in fixed
notation, so `100000` becomes `"100000"`, not `"1e+05"`. A timestamp
written as text is its local time in its own timezone, which the text
does not record, always as `"%Y-%m-%d %H:%M:%S"` (midnight included),
followed by the fraction of a second to the microsecond when it has one,
as in `"2024-01-01 10:00:00.25"`. An `integer64` column (from bit64)
becomes a double when that is exact, an integer within range, or its
decimal text.

A logical column becomes a Date only when every value is `NA`: that is
how readers such as
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) and
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
type a column with no values, and the Date column it stands for is then
all `NA` as well.

## Examples

``` r
cast_rules()
#>         from character logical   Date numeric integer
#>       <char>    <char>  <char> <char>  <char>  <char>
#> 1: character         =     yes    yes     yes     yes
#> 2:   logical       yes       =      -     yes     yes
#> 3:      Date       yes       -      =     yes     yes
#> 4:   numeric       yes       -    yes       =     yes
#> 5:   integer       yes       -    yes     yes       =
#> 6:   POSIXct       yes       -    yes     yes     yes
#> 7:    factor       yes       -      -       -       -
#> 8: integer64       yes       -      -     yes     yes
cast_rules(wide = FALSE)
#>          from        to allowed
#>        <char>    <char>  <lgcl>
#>  1: character   logical    TRUE
#>  2: character      Date    TRUE
#>  3: character   numeric    TRUE
#>  4: character   integer    TRUE
#>  5:   logical character    TRUE
#>  6:   logical      Date   FALSE
#>  7:   logical   numeric    TRUE
#>  8:   logical   integer    TRUE
#>  9:      Date character    TRUE
#> 10:      Date   logical   FALSE
#> 11:      Date   numeric    TRUE
#> 12:      Date   integer    TRUE
#> 13:   numeric character    TRUE
#> 14:   numeric   logical   FALSE
#> 15:   numeric      Date    TRUE
#> 16:   numeric   integer    TRUE
#> 17:   integer character    TRUE
#> 18:   integer   logical   FALSE
#> 19:   integer      Date    TRUE
#> 20:   integer   numeric    TRUE
#> 21:   POSIXct character    TRUE
#> 22:   POSIXct   logical   FALSE
#> 23:   POSIXct      Date    TRUE
#> 24:   POSIXct   numeric    TRUE
#> 25:   POSIXct   integer    TRUE
#> 26:    factor character    TRUE
#> 27:    factor   logical   FALSE
#> 28:    factor      Date   FALSE
#> 29:    factor   numeric   FALSE
#> 30:    factor   integer   FALSE
#> 31: integer64 character    TRUE
#> 32: integer64   logical   FALSE
#> 33: integer64      Date   FALSE
#> 34: integer64   numeric    TRUE
#> 35: integer64   integer    TRUE
#>          from        to allowed
#>        <char>    <char>  <lgcl>
#>                                                                                                                                                                                                                                                                                           note
#>                                                                                                                                                                                                                                                                                         <char>
#>  1:                                                                                                                                                                                                                        parsed from the text; a missing value must be NA, not the text "NA"
#>  2:                                                                                                                                                                                                                        parsed from the text; a missing value must be NA, not the text "NA"
#>  3:                                                                                                                                                                                                                        parsed from the text; a missing value must be NA, not the text "NA"
#>  4:                                                                                                                                                                                          a fraction is truncated toward zero (refused with truncate = FALSE); must be within integer range
#>  5:                                                                                                                                                                                                                                                                                      as is
#>  6:                                                                                                                                                                                no sound conversion, except that a column that is entirely NA (how readers type an empty column) becomes NA
#>  7:                                                                                                                                                                                                                                                                                      as is
#>  8:                                                                                                                                                                                                                                                                                      as is
#>  9:                                                                                                                                                                                                   written in date_format; a fraction of a day is truncated (refused with truncate = FALSE)
#> 10:                                                                                                                                                                                                                                                                        no sound conversion
#> 11:                                                                                                                                                                                                                                          days (Date) or seconds (POSIXct) since 1970-01-01
#> 12:                                                                                                                                                                                 days (Date) or seconds (POSIXct) since 1970-01-01; a fraction is truncated (refused with truncate = FALSE)
#> 13: fixed notation, up to 15 significant digits (scientific outside [1e-15, 2^53)); refused when the text does not read back as the same number. When every value of the reference column has the same number of decimals ("2.0"), written with that many wherever the text reads back exactly
#> 14:                                                                                                                                                                                                                                                                        no sound conversion
#> 15:                                                                                                                                                                                                    days since 1970-01-01; a fraction of a day is truncated (refused with truncate = FALSE)
#> 16:                                                                                                                                                                                          a fraction is truncated toward zero (refused with truncate = FALSE); must be within integer range
#> 17:                                                                                                                                                                                                                                                                                      as is
#> 18:                                                                                                                                                                                                                                                                        no sound conversion
#> 19:                                                                                                                                                                                                                                                                      days since 1970-01-01
#> 20:                                                                                                                                                                                                                                                                                      as is
#> 21:                                                                                     "%Y-%m-%d %H:%M:%S", plus ".ffffff" (to the microsecond, trailing zeros dropped) when the stamp has a fraction of a second: the local time in the stamp's own timezone, which the text does not record
#> 22:                                                                                                                                                                                                                                                                        no sound conversion
#> 23:                                                                                                                                                calendar day in the stamp's own timezone (the session's, for a stamp with none); a time of day is truncated (refused with truncate = FALSE)
#> 24:                                                                                                                                                                                                                                          days (Date) or seconds (POSIXct) since 1970-01-01
#> 25:                                                                                                                                                                                 days (Date) or seconds (POSIXct) since 1970-01-01; a fraction is truncated (refused with truncate = FALSE)
#> 26:                                                                                                                                                                                                                                                        the labels, never the integer codes
#> 27:                                                                                                                                                                                                                                               convert the labels with as.character() first
#> 28:                                                                                                                                                                                                                                               convert the labels with as.character() first
#> 29:                                                                                                                                                                                                                                               convert the labels with as.character() first
#> 30:                                                                                                                                                                                                                                               convert the labels with as.character() first
#> 31:                                                                                                                                                                                                                                                             the decimal text (needs bit64)
#> 32:                                                                                                                                                                                                                                                                        no sound conversion
#> 33:                                                                                                                                                                                                                                                                        no sound conversion
#> 34:                                                                                                                                                                                                                                  exact below 2^53, larger values are refused (needs bit64)
#> 35:                                                                                                                                                                                                                                                 must be within integer range (needs bit64)
#>                                                                                                                                                                                                                                                                                           note
#>                                                                                                                                                                                                                                                                                         <char>
```
