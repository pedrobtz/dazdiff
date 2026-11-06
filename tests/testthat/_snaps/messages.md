# diff_table()'s key errors

    Code
      diff_table(data.table(v = 1), data.table(v = 1))
    Condition
      Error:
      ! the tables are not well-formed: they have no key column, since every column is a measure, so rows cannot be aligned; name the key with `by`, leave some columns out of `measures`, or add a virtual key: row_key = "position" pairs the rows as they come, and row_key = "sorted" pairs them after sorting both tables by their values

# diff_table()'s refusal of a comparison that aligns nothing

    Code
      diff_table(x, y)
    Condition
      Error:
      ! no identity value of `x` appears in `y` (identity: id), so nothing can be compared; check `by`, and the format of the key values

---

    Code
      diff_table(x, y[0])
    Condition
      Error:
      ! no identity value of `x` appears in `y` (identity: id), so nothing can be compared (one table is empty); check `by`, and the format of the key values

---

    Code
      diff_table(data.table(k = "a"), data.table(k = "b"))
    Message
      No measure columns (measures = "numeric"), so rows are compared as wholes: do the two tables have the same rows?
    Condition
      Error:
      ! no row of `x` appears in `y`, so nothing can be compared

# diff_table()'s type errors

    Code
      diff_table(data.table(t = stamp, f = factor("a"), v = 1), data.table(t = stamp,
        f = "a", v = 1))
    Condition
      Error:
      ! x has column(s) of unsupported type: t (POSIXct), f (factor); convert t, f with normalize_dt() first

---

    Code
      diff_table(x, y, cast = FALSE)
    Condition
      Error:
      ! cast = FALSE, but x and y disagree on the type of: id (character vs numeric), v (numeric vs character)

---

    Code
      diff_table(x, x[, .(id, v = "1")], mode = "equal")
    Condition
      Error:
      ! mode = "equal" does not cast, but x and y disagree on the type of: v (numeric vs character)

# the merge helpers' errors

    Code
      merge_dry_run(as.data.frame(kx), ky_fixture())
    Condition
      Error:
      ! `x` and `y` must be data.tables

---

    Code
      merge_dry_run(data.table(a = 1), data.table(a = 1))
    Condition
      Error:
      ! no columns to join on

---

    Code
      merge_dry_run(kx, ky_fixture(), on = "nope")
    Condition
      Error:
      ! not in both tables: nope

---

    Code
      merge_dt(as.data.frame(kx), ky_fixture())
    Condition
      Error:
      ! `x` and `y` must be data.tables

---

    Code
      merge_dt(setkey(data.table(id = c("a", "a"), v = 1:2), id), setkey(data.table(
        id = c("a", "a"), w = 1:2), id))
    Condition
      Error:
      ! keys are not one to one: 2 rows would become 4 (max fanout 4; 1 duplicate key(s) in x, 1 in y); number the duplicates or aggregate them first (`duplicates` in diff_table())

---

    Code
      merge_dt(setkey(data.table(id = 1L, a = 1, a_y = 5), id), setkey(data.table(id = 1L,
        a = 7), id))
    Condition
      Error:
      ! suffix "_y" would write over existing column(s): a_y; pick another suffix

# converting integer64 needs bit64

    Code
      cast_value(v, "numeric", "col")
    Condition
      Error:
      ! column col: converting integer64 needs the bit64 package

# diff_table()'s duplicate key warning and error

    Code
      invisible(diff_table(x, x))
    Condition
      Warning:
      the id columns do not tell rows apart: 1 key(s) repeat (identity: id); rows within each were paired in arrival order (key_seq), which assumes both tables list them in the same order

---

    Code
      diff_table(x, x, duplicates = "error")
    Condition
      Error:
      ! the id columns do not tell rows apart: 1 key(s) repeat (identity: id); use duplicates = "disambiguate" or "aggregate"

# a message about a very wide table stays bounded

    Code
      diff_table(x, data.table(c01 = 1))
    Condition
      Error:
      ! `y` is missing column(s) the benchmark `x` has: c02, c03, c04, c05, c06, c07, c08, c09, c10, c11, ... (4 more)

# cast_value()'s refusals say why

    Code
      cast_value(c("1", "abc"), "numeric", "col")
    Condition
      Error:
      ! column col: character -> numeric, not a number: abc

---

    Code
      cast_value(c("a", "b", "c", "d"), "numeric", "THE_COL")
    Condition
      Error:
      ! column THE_COL: character -> numeric, not a number: a, b, c

---

    Code
      cast_value("05/03/2024", "Date", "col")
    Condition
      Error:
      ! column col: character -> Date, not a date in format %Y-%m-%d: 05/03/2024

---

    Code
      cast_value("2024-01-01junk", "Date", "col")
    Condition
      Error:
      ! column col: character -> Date, not a canonical %Y-%m-%d date: 2024-01-01junk

---

    Code
      cast_value("24-01-01", "Date", "col")
    Condition
      Error:
      ! column col: character -> Date, not a canonical %Y-%m-%d date: 24-01-01

---

    Code
      cast_value(1 + .Machine$double.eps, "character", "col")
    Condition
      Error:
      ! column col: numeric -> character, loses precision as text: 1.0000000000000002

---

    Code
      cast_value(c("TRUE", "maybe"), "logical", "col")
    Condition
      Error:
      ! column col: character -> logical, not a logical literal: maybe

---

    Code
      cast_value(c(0, 1), "logical", "col")
    Condition
      Error:
      ! column col: numeric -> logical, no sound conversion

---

    Code
      cast_value(factor(c("a", "b")), "numeric", "col")
    Condition
      Error:
      ! column col: factor -> numeric, convert the labels with as.character() first

---

    Code
      cast_value("3000000000", "integer", "col")
    Condition
      Error:
      ! column col: character -> integer, outside integer range: 3000000000

---

    Code
      cast_value(complex(real = 1), "numeric", "col")
    Condition
      Error:
      ! column col: complex -> numeric, unsupported source type

---

    Code
      cast_value("2024-03-05", "POSIXct", "col")
    Condition
      Error:
      ! column col: character -> POSIXct, no rule for this pair

---

    Code
      cast_value("3.7", "integer", "col", truncate = FALSE)
    Condition
      Error:
      ! column col: character -> integer, not a whole number (truncate = FALSE): 3.7

---

    Code
      cast_value(1.5, "Date", "col", truncate = FALSE)
    Condition
      Error:
      ! column col: numeric -> Date, not a whole day (truncate = FALSE): 1.5

---

    Code
      cast_value(as.POSIXct("2024-01-01 10:00", tz = "UTC"), "Date", "col", truncate = FALSE)
    Condition
      Error:
      ! column col: POSIXct -> Date, has a time of day (truncate = FALSE): 2024-01-01 10:00:00

---

    Code
      cast_value(NaN, "integer", "col", nan_is_na = FALSE)
    Condition
      Error:
      ! column col: numeric -> integer, NaN has no such form (nan_is_na = FALSE)

---

    Code
      cast_value("2024-01-01", "Date", "col", date_format = c("%Y", "%m"))
    Condition
      Error:
      ! `date_format` must be a single format string

# diff_table()'s column errors and messages

    Code
      diff_table(x, x[, .(id, v)])
    Condition
      Error:
      ! `y` is missing column(s) the benchmark `x` has: note

---

    Code
      invisible(diff_table(x[, .(id, v)], x))
    Message
      Dropped column(s) of `y` that the benchmark `x` does not have: note.

---

    Code
      diff_table(x, data.table(id = "a", v = 1, w = 2), mode = "equal")
    Condition
      Error:
      ! mode = "equal" needs the same columns in both tables
        only in `x`: note
        only in `y`: w

---

    Code
      diff_table(x, x, by = c("id", "ID", "nope"))
    Condition
      Error:
      ! `by` names a column more than once: id, ID; names column(s) not in the tables: nope

---

    Code
      diff_table(x, x, by = "v", measures = "v")
    Condition
      Error:
      ! `by` and `measures` both name: v

---

    Code
      diff_table(x, x, mode = "equal", by = "id")
    Condition
      Error:
      ! mode = "equal" compares every column, but these are in neither `by` nor `measures`: note; add them to `by` (matched exactly, as part of the row identity) or, if numeric, to `measures`

---

    Code
      invisible(diff_table(x, x, by = "id"))
    Message
      Not compared, being in neither `by` nor `measures`: note.

---

    Code
      invisible(diff_table(data.table(k = "a"), data.table(k = "a")))
    Message
      No measure columns (measures = "numeric"), so rows are compared as wholes: do the two tables have the same rows?

# the key helpers' errors

    Code
      unique_by_key(data.frame(a = 1))
    Condition
      Error:
      ! `dt` must be a data.table

---

    Code
      unique_by_key(data.table(a = 1))
    Condition
      Error:
      ! `dt` has no key to check

---

    Code
      disambiguate_by_key(data.frame(a = 1))
    Condition
      Error:
      ! `long` must be a data.table

---

    Code
      disambiguate_by_key(data.table(a = 1))
    Condition
      Error:
      ! no key to disambiguate by

---

    Code
      aggregate_by_key(data.frame(a = 1))
    Condition
      Error:
      ! `long` must be a data.table

---

    Code
      aggregate_by_key(data.table(a = 1))
    Condition
      Error:
      ! no key to aggregate by

# cast_dt()'s errors and its truncation message

    Code
      cast_dt(x, data.frame(a = 1))
    Condition
      Error:
      ! `x` must be a data.frame and `y` a data.table

---

    Code
      cast_dt(x, data.table(a = 1), cols = "nope")
    Condition
      Error:
      ! column(s) missing from x or y: nope

---

    Code
      cast_dt(data.table(z = complex(real = 1)), data.table(z = "1"))
    Condition
      Error:
      ! x has column(s) of unsupported type: z (complex)

---

    Code
      invisible(cast_dt(x, data.table(a = c(1.7, 2), b = c("3.2", "3.2"), c = "k")))
    Message
      Truncated 3 value(s) while casting to the reference types:
        a: 1 (1.7 -> 1)
        b: 2 (3.2 -> 3)

# diff_table()'s argument errors

    Code
      diff_table(x, 1:3)
    Condition
      Error:
      ! `x` and `y` must be data.frames

---

    Code
      diff_table(x, x, tolerance = -1)
    Condition
      Error:
      ! `tolerance` must be a single finite number >= 0

---

    Code
      diff_table(x, x, rel_tol = NA)
    Condition
      Error:
      ! `rel_tol` must be a single finite number >= 0

---

    Code
      diff_table(x, x, truncate = NA)
    Condition
      Error:
      ! `truncate` must be TRUE or FALSE

---

    Code
      diff_table(x, x, nan_is_na = "yes")
    Condition
      Error:
      ! `nan_is_na` must be TRUE or FALSE

---

    Code
      diff_table(x, x, mode = "equal", cast = TRUE)
    Condition
      Error:
      ! mode = "equal" never casts: neither table is the reference for the other

---

    Code
      diff_table(x, x, cast = NA)
    Condition
      Error:
      ! `cast` must be TRUE or FALSE

---

    Code
      diff_table(x, x, by = NA_character_)
    Condition
      Error:
      ! `by` must be NULL or column names

---

    Code
      diff_table(x, x, duplicates = "aggregate", tolerance = 0.1)
    Condition
      Error:
      ! duplicates = "aggregate" compares values exactly; `tolerance` and `rel_tol` must be 0

# cast_value()'s refusals of integer64

    Code
      cast_value(big, "numeric", "col")
    Condition
      Error:
      ! column col: integer64 -> numeric, loses precision as a double (2^53 or more): 9007199254740993

# a choice argument outside its choices is a classed input error

    Code
      diff_table(x, x, duplicates = "ignore")
    Condition
      Error:
      ! `duplicates` must be one of "disambiguate", "aggregate", "error"

# the helpers' input errors

    Code
      summarize_dt(1:3)
    Condition
      Error:
      ! `dt` must be a data.frame

---

    Code
      compare_columns(data.table(a = 1), 1:3)
    Condition
      Error:
      ! `x` and `y` must be data.frames

---

    Code
      melt_dt(1:3)
    Condition
      Error:
      ! `dt` must be a data.frame

---

    Code
      select_measures(data.table(a = 1), NA_character_)
    Condition
      Error:
      ! `measures` must be "numeric", "numeric+integer", column names, or character(0) for none

---

    Code
      select_measures(data.table(a = "x", b = 1), c("b", "b", "nope", "a"))
    Condition
      Error:
      ! `measures` named more than once: b; not a column: nope; not numeric or integer: a (character)

---

    Code
      diff_table(data.table(id = "a", v = 1), data.table(id = "a", v = 1), measures = "id")
    Condition
      Error:
      ! `measures` not numeric or integer: id (character)

# normalize_dt()'s errors

    Code
      normalize_dt(1:3)
    Condition
      Error:
      ! `dt` must be a data.frame

---

    Code
      normalize_dt(stamps, cols = "nope")
    Condition
      Error:
      ! unknown column(s): nope

---

    Code
      normalize_dt(stamps)
    Condition
      Error:
      ! no conversion given for column(s): t (POSIXct), z (complex); name the target type for POSIXct in `to`; normalize_dt() cannot convert complex, so convert or drop z yourself (with as.numeric() or as.character(), say)

# diff_summary() and diff_report()'s errors

    Code
      diff_summary(data.table(a = 1))
    Condition
      Error:
      ! `d` must be a result of diff_table()

---

    Code
      diff_report(d, x_name = "")
    Condition
      Error:
      ! `x_name` must be a single non-empty string

---

    Code
      diff_report(d, top_k = 1.5)
    Condition
      Error:
      ! `top_k` must be a single whole number >= 0

---

    Code
      format(diff_report(d), unicode = NA)
    Condition
      Error:
      ! `unicode` must be TRUE or FALSE

# expect_table_equal()'s errors

    Code
      expect_table_equal(expected, expected, max_rows = -1)
    Condition
      Error:
      ! `max_rows` must be a single number >= 0

---

    Code
      expect_table_equal(expected[2:1], expected)
    Condition
      Error:
      ! the id columns do not tell rows apart: 1 key(s) repeat (identity: id); rows within each were paired in arrival order (key_seq), which assumes both tables list them in the same order
      expect_table_equal() does not pair duplicate keys; pass duplicates = "disambiguate" or "aggregate" to accept them.

---

    Code
      expect_table_equal(expected, expected)
    Condition
      Error:
      ! expect_table_equal() requires the suggested package 'testthat'

# diff_table() names columns in the caller's own spelling

    Code
      diff_table(data.table(id = 1L, `unit price` = 1), data.table(id = 1L,
        Unit.Price = "x"))
    Condition
      Error:
      ! column "Unit.Price" (UNIT_PRICE): character -> numeric, not a number: x

---

    Code
      diff_table(data.table(a = 1, A = 2), data.table(a = 1))
    Condition
      Error:
      ! `x` has columns whose names are the same after normalization to A-Z, 0-9 and _:
        A <- "a", "A"
      Rename or drop these columns before comparing.

---

    Code
      diff_table(data.table(`%` = 1, a = 2), data.table(a = 1))
    Condition
      Error:
      ! `x` has column name(s) with no letter or digit, so nothing is left of them after normalization: "%"; rename these columns before comparing

