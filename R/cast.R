# Casting to the reference types ---------------------------------------------

#' Write doubles as text the way a table of text ids writes them
#'
#' `as.character()` follows R's `scipen` rule, so a round number
#' whose exponent form is shorter comes out as `"1e+05"`, and never joins
#' the benchmark's `"100000"`. Values are written in fixed notation with
#' up to 15 significant digits instead, which is how such ids are written.
#' Outside [1e-15, 2^53) fixed notation would mean a run of zeros or digits
#' beyond the double's precision, and no table of ids writes those, so they
#' keep `as.character()`'s form.
#'
#' @param v A double vector.
#' @return A character vector, NA where `v` is NA (NaN is `"NaN"`).
#' @noRd
num_to_text <- function(v) {
  txt <- as.character(v)
  fixed <- is.finite(v) & (v == 0 | (abs(v) >= 1e-15 & abs(v) < 2^53))
  if (any(fixed)) {
    # `+ 0` turns -0 into 0, which as.character() writes as "0" as well.
    txt[fixed] <- trimws(formatC(v[fixed] + 0, format = "fg", digits = 15L))
  }
  txt
}

#' The decimals a text column writes its numbers with
#'
#' Read off every distinct value, not a sample: one `"1.00"` among a million
#' `"1.0"` is exactly the value a sample misses, and the format would then be
#' wrong for its row. Only plain decimal text counts (`-?(0|[1-9][0-9]*)`,
#' then optionally `.` and digits); a sign, leading zeros, separators or an
#' exponent mean the column has no single number format to follow.
#'
#' @param ref A character vector, the benchmark's column.
#' @return A list: `decimals`, the one number of decimal places every value
#'   uses, or NA when there is none; `seen`, the counts of decimal places
#'   found (sorted, for the message); and `plain`, whether every value is
#'   plain decimal text.
#' @noRd
text_decimals <- function(ref) {
  u <- unique(ref[!is.na(ref)])
  plain <- grepl("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$", u)
  seen <- sort(unique(nchar(sub("^[^.]*\\.?", "", u[plain]))))
  list(
    decimals = if (length(u) && all(plain) && length(seen) == 1L) {
      seen
    } else {
      NA_integer_
    },
    seen = seen,
    plain = all(plain)
  )
}

#' Write numbers as text the way the benchmark writes them
#'
#' A double cast to text is written as `num_to_text()` writes it, `"2"`, which
#' never joins a benchmark that writes `"2.0"`. When every value of the
#' benchmark's column has the same number of decimals, `y`'s numbers are
#' written with that many instead. A value is reformatted only when the text
#' reads back as the same number: 1.25 at one decimal would become `"1.3"`
#' and join the benchmark's 1.3, a silent false match, so it keeps its own
#' text and shows as unmatched instead.
#'
#' Whatever the format, a value of `x` that equals one of `y`'s as a number
#' but not as text is warned about: those rows will not align, and the
#' comparison may be reporting a format skew as missing rows.
#'
#' @param v `y`'s column before the cast, numeric or integer.
#' @param out The same column cast to text by `cast_value()`.
#' @param ref The benchmark's column.
#' @param label The column as messages name it.
#' @return `out`, with the values the benchmark's format fits rewritten.
#' @noRd
number_as_text_like <- function(v, out, ref, label) {
  fmt <- text_decimals(ref)
  k <- fmt$decimals
  if (!is.na(k) && k > 0L) {
    # `+ 0` turns -0 into 0, which sprintf() would write as "-0.0".
    txt <- sprintf("%.*f", k, as.double(v) + 0)
    fits <- is.finite(v) & suppressWarnings(as.numeric(txt)) == v
    out[fits] <- txt[fits]
  }

  # x's values that are numbers y has, written differently.
  u <- unique(ref[!is.na(ref)])
  num <- suppressWarnings(as.numeric(u))
  skew <- is.finite(num) & num %in% v & !u %in% out
  if (any(skew)) {
    at <- match(num[skew], v)
    shown <- head(seq_len(sum(skew)), 3L)
    dazdiff_warn(
      "dazdiff_warning_cast_format",
      paste0(
        "column ",
        label,
        ": ",
        format(sum(skew), big.mark = ","),
        if (sum(skew) == 1L) {
          " value of `x` equals a number of `y` but not its text ("
        } else {
          " values of `x` equal a number of `y` but not its text ("
        },
        paste0(
          "\"",
          u[skew][shown],
          "\" vs \"",
          out[at][shown],
          "\"",
          collapse = ", "
        ),
        if (sum(skew) > 3L) ", ...",
        "), so those rows will not align; ",
        if (!is.na(k) && k > 0L) {
          sprintf(
            "`y`'s numbers were written with %d decimal place%s, as `x` writes them",
            k,
            if (k == 1L) "" else "s"
          )
        } else if (!fmt$plain) {
          "no decimal places were inferred, since not every value of `x` is plain decimal text"
        } else if (length(fmt$seen) > 1L) {
          paste0(
            "no decimal places were inferred, since `x` writes them with ",
            paste(fmt$seen, collapse = ", "),
            " decimal places"
          )
        } else {
          "`x` writes them with no decimal places"
        },
        "; cast the column of `x` to a number to compare by value"
      ),
      column = label,
      decimals = k,
      n = sum(skew)
    )
  }
  out
}

#' Write timestamps as text in one fixed format
#'
#' `as.character()` cannot be used: since R 4.3 it drops the time from each
#' stamp that is exactly at midnight and keeps it on the others, so one
#' column comes out in two formats, and before 4.3 it dropped the time for the
#' whole column only when every stamp was at midnight. Either way a midnight
#' stamp never joined the benchmark's `"2024-01-01 00:00:00"`, and the output
#' depended on the R version.
#'
#' Every stamp is written `"%Y-%m-%d %H:%M:%S"`, the local time in the stamp's
#' own zone (the session's, for a stamp with none). A stamp with a fraction of
#' a second adds it after a dot, to the microsecond (what databases store),
#' without trailing zeros. The fraction is rounded off the stamp's seconds
#' before formatting, because `format()` truncates `%OS` digits and a double
#' rarely holds a decimal fraction exactly: 0.1 s would print as `.099999`.
#'
#' @param v A POSIXct vector.
#' @return A character vector, NA where `v` is NA.
#' @noRd
stamp_to_text <- function(v) {
  s <- as.numeric(v)
  whole <- floor(s)
  us <- round((s - whole) * 1e6)
  # Rounding can reach the next second: 0.9999996 s is 1 s, not 0.1000000.
  carry <- !is.na(us) & us >= 1e6
  whole[carry] <- whole[carry] + 1
  us[carry] <- 0
  txt <- format(.POSIXct(whole, tz = attr(v, "tzone")), "%Y-%m-%d %H:%M:%S")
  frac <- !is.na(us) & us > 0
  if (any(frac)) {
    txt[frac] <- paste0(
      txt[frac],
      ".",
      sub("0+$", "", sprintf("%06.0f", us[frac]))
    )
  }
  txt
}

#' Cast one column to a target type
#'
#' One column of `v` cast to `to`. Refuses anything ambiguous instead
#' of letting R's coercion rules quietly produce NAs. The one loss it will
#' accept is a truncation -- a fraction dropped on the way to a whole integer
#' or a whole day -- and only when `truncate` says so.
#'
#' @param v The vector to convert.
#' @param to The target type, one of `CAST_TYPES`.
#' @param nm The column's name, used in error messages.
#' @param origin The type the value arrived as. Text and factors are converted
#'   in two hops, and the message should name the type the caller actually
#'   passed, not the intermediate one. Defaults to `col_type(v)`.
#' @param date_format The `strptime` format dates are read and written in,
#'   `"%Y-%m-%d"` by default. Text is parsed with it and must match it
#'   exactly, and a Date written back out to text is formatted with it, so the
#'   two directions stay inverse to one another.
#' @param truncate Whether a cast may drop a fraction: a double to an integer
#'   (toward zero), a number to a Date (to the day it prints as), a timestamp
#'   to a Date (the time of day). When it does, the result carries a
#'   `"truncated"` attribute: the count, up to three examples and the
#'   positions of every truncated value. When FALSE, the cast is refused
#'   instead.
#' @param nan_is_na Whether NaN and NA are the same missing value. NaN has no
#'   integer or Date form and becomes NA on the way; with FALSE that would hide
#'   a difference, so the cast is refused instead.
#' @return `v` converted to `to`, or an error naming the column, the
#'   pair of types, the reason and up to three offending values.
#' @noRd
cast_value <- function(
  v,
  to,
  nm,
  origin = NULL,
  date_format = "%Y-%m-%d",
  truncate = TRUE,
  nan_is_na = TRUE
) {
  if (
    !is.character(date_format) ||
      length(date_format) != 1L ||
      is.na(date_format)
  ) {
    dazdiff_abort(
      "dazdiff_error_input",
      "`date_format` must be a single format string"
    )
  }
  from <- col_type(v)
  if (is.null(origin)) {
    origin <- from
  }
  if (identical(from, to)) {
    return(v)
  }
  refuse <- function(why, vals = NULL) {
    msg <- sprintf("column %s: %s -> %s, %s", nm, origin, to, why)
    if (length(vals)) {
      msg <- paste0(msg, ": ", paste(head(unique(vals), 3L), collapse = ", "))
    }
    dazdiff_abort(
      "dazdiff_error_cast",
      msg,
      column = nm,
      from = origin,
      to = to
    )
  }
  if (!from %in% CAST_FROM) {
    refuse("unsupported source type")
  }

  # Readers such as read.csv() and fread() type a column with no values as
  # logical. It stands for a column of the target type with no values, so it
  # becomes one, before the rules are read: logical -> Date is refused for
  # any column that has a value (see CAST_RULES).
  if (from == "logical" && all(is.na(v)) && to %in% CAST_TYPES) {
    return(switch(
      to,
      character = rep(NA_character_, length(v)),
      integer = rep(NA_integer_, length(v)),
      numeric = rep(NA_real_, length(v)),
      Date = structure(rep(NA_real_, length(v)), class = "Date")
    ))
  }

  rule <- cast_rule(from, to)
  if (!isTRUE(rule$allowed)) {
    refuse(if (is.na(rule$allowed)) "no rule for this pair" else rule$note)
  }

  hop <- function(value) {
    cast_value(
      value,
      to,
      nm,
      origin = origin,
      date_format = date_format,
      truncate = truncate,
      nan_is_na = nan_is_na
    )
  }

  # integer64 is a double's bits holding a 64-bit integer: only bit64 can read
  # it. It becomes its decimal text, or a double when that is exact (every
  # integer below 2^53 is), and the double then meets the rules below, the
  # integer range among them.
  if (from == "integer64") {
    if (!requireNamespace("bit64", quietly = TRUE)) {
      dazdiff_abort(
        "dazdiff_error_dependency",
        sprintf("column %s: converting integer64 needs the bit64 package", nm)
      )
    }
    if (to == "character") {
      return(as.character(v))
    }
    # 2^53 + 1 rounds to 2^53 on the way, so the check cannot be made after
    # the fact on a value above it: from 2^53 on, every value is refused.
    dbl <- suppressWarnings(as.double(v))
    off <- !is.na(dbl) & abs(dbl) >= 2^53
    if (any(off)) {
      refuse("loses precision as a double (2^53 or more)", as.character(v[off]))
    }
    return(if (to == "numeric") dbl else hop(dbl))
  }

  # A factor means its labels, never its integer codes -- as.numeric() on a
  # factor silently hands back the codes -- so convert the labels instead.
  if (from == "factor") {
    return(hop(as.character(v)))
  }

  # Text is parsed to the underlying value first, so the rules below see numbers
  # rather than strings, and "3.7" meets the same truncation rule as 3.7.
  if (from == "character" && to %in% c("logical", "integer", "numeric")) {
    parsed <- if (to == "logical") {
      ok <- c("TRUE", "FALSE", "T", "F", "true", "false", "True", "False")
      if (any(!is.na(v) & !v %in% ok)) {
        refuse("not a logical literal", v[!is.na(v) & !v %in% ok])
      }
      as.logical(v)
    } else {
      # as.numeric() also accepts surrounding whitespace, hex ("0x10") and
      # "Inf"/"NaN". All of them are numbers, so they are let through: NaN is
      # is.na() too, so it is told apart from a failed parse explicitly. The
      # text "NA" is not a number and is refused like any other word; a
      # missing value has to arrive as NA.
      num <- suppressWarnings(as.numeric(v))
      bad <- is.na(num) & !is.nan(num) & !is.na(v)
      if (any(bad)) {
        refuse("not a number", v[bad])
      }
      num
    }
    return(if (to == "numeric") parsed else hop(parsed))
  }

  # NaN has no integer or Date form, so it becomes NA on the way. When NaN and
  # NA are the same missing value that loses nothing; when they are not, it
  # would turn a difference into a match.
  if (
    !nan_is_na && to %in% c("integer", "Date") && is.double(v) && any(is.nan(v))
  ) {
    refuse("NaN has no such form (nan_is_na = FALSE)")
  }

  # `lost` marks the values a cast truncated; `why` says what was dropped.
  lost <- NULL
  why <- NULL
  out <- switch(
    to,
    # A Date goes back out through the same format it would be read in by, so
    # the two directions are inverse. A double is written the way a table of
    # text ids writes it (see num_to_text()), and a timestamp in one fixed
    # format (see stamp_to_text()). Everything else is as.character()'s job.
    character = if (from == "Date") {
      # A Date can hold part of a day, which no date format writes: it is
      # written as the day it falls in, the same loss numeric -> Date records.
      day <- unclass(v)
      lost <- is.finite(day) & day != floor(day)
      why <- "not a whole day"
      format(v, date_format)
    } else if (from == "POSIXct") {
      stamp_to_text(v)
    } else if (from == "numeric") {
      txt <- num_to_text(v)
      # Fifteen significant digits, so two doubles that differ further out
      # than that land on the same text and would join as one key. Reading
      # the text back is what catches it. Non-finite values are left to the
      # comparison: they print and re-read exactly.
      off <- is.finite(v) & suppressWarnings(as.numeric(txt)) != v
      if (any(off)) {
        # Printed at full precision: at 15 digits the offending value looks
        # identical to the one it collides with.
        refuse("loses precision as text", format(v[off], digits = 17L))
      }
      txt
    } else {
      as.character(v)
    },
    integer = {
      if (from == "logical") {
        as.integer(v)
      } else {
        # Date -> integer is days since 1970-01-01, POSIXct -> integer seconds.
        num <- as.numeric(v)
        off <- num[!is.na(num) & abs(num) > .Machine$integer.max]
        if (length(off)) {
          # Written as num_to_text() writes it: pasted as a double, an
          # integer64 of 3000000000 would read "3e+09".
          refuse("outside integer range", num_to_text(off))
        }
        lost <- !is.na(num) & num != trunc(num)
        why <- "not a whole number"
        as.integer(num)
      }
    },
    numeric = as.numeric(v),
    Date = {
      if (from == "POSIXct") {
        # Take the calendar day in the stamp's own zone, so the date matches
        # the timestamp as it prints. A stamp with no zone (tzone "") prints
        # in the session's zone, so that is the zone its day is read in: R
        # gives it no other meaning, and as.Date() and format() agree.
        tz <- attr(v, "tzone")
        tz <- if (is.null(tz) || !nzchar(tz[1L])) "" else tz[1L]
        d <- as.Date(v, tz = tz)
        # The time of day is read off the stamp itself rather than by
        # comparing it with the day's midnight: where a zone skips midnight
        # (a DST change at 00:00) that midnight does not exist, and parsing
        # it is an error rather than an NA.
        lt <- as.POSIXlt(v, tz = tz)
        lost <- !is.na(v) & (lt$hour != 0L | lt$min != 0L | lt$sec != 0)
        why <- "has a time of day"
        d
      } else if (from %in% c("integer", "numeric")) {
        num <- as.numeric(v)
        # A fractional day prints as the day it falls in but does not equal
        # it, so it is floored to that day rather than kept fractional.
        lost <- is.finite(num) & num != floor(num)
        why <- "not a whole day"
        as.Date(floor(num), origin = "1970-01-01")
      } else if (from == "character") {
        d <- suppressWarnings(as.Date(v, format = date_format))
        if (any(is.na(d) & !is.na(v))) {
          refuse(
            sprintf("not a date in format %s", date_format),
            v[is.na(d) & !is.na(v)]
          )
        }
        # as.Date() stops at the end of the format and ignores whatever trails
        # it, so "2024-01-01junk" parses clean and "24-01-01" quietly becomes
        # the year 24. Formatting the parsed date back out is what separates a
        # date from a string that merely starts with one.
        off <- !is.na(d) & format(d, date_format) != v
        # The round trip alone cannot catch a short year on every platform:
        # glibc writes year 24 as "24" under %Y where macOS writes "0024", so
        # on Linux "24-01-01" formats back to itself. No real date precedes
        # the year 1000, and a two- or three-digit year lands exactly there,
        # so those are refused too, reading the year from the date itself.
        off <- off | (!is.na(d) & as.POSIXlt(d)$year + 1900L < 1000L)
        if (any(off)) {
          refuse(sprintf("not a canonical %s date", date_format), v[off])
        }
        d
      } else {
        refuse("no sound conversion")
      }
    },
    refuse("unsupported target type")
  )

  if (!is.null(lost) && any(lost)) {
    # A Date's fraction of a day does not print, so "2024-01-01 -> 2024-01-01"
    # would hide the loss; the day count shows it.
    src <- if (from == "Date") unclass(v) else v
    if (!truncate) {
      refuse(paste0(why, " (truncate = FALSE)"), src[lost])
    }
    # One example per distinct value: a repeated value says nothing new.
    at <- which(lost)
    shown <- head(at[!duplicated(v[at])], 3L)
    # The examples show what kind of loss it was; the positions are what lets
    # the caller find every affected row afterwards, a `same` that was really
    # 1.5 against 1 among them.
    attr(out, "truncated") <- list(
      n = sum(lost),
      examples = vapply(
        shown,
        function(i) {
          paste(format(src[i]), "->", format(out[i]))
        },
        character(1L)
      ),
      rows = at
    )
  }

  # Backstop: nothing may turn into NA on the way across.
  if (any(is.na(out) & !is.na(v))) {
    refuse("conversion produced NA", v[is.na(out) & !is.na(v)])
  }
  out
}

#' Store a Date the way a reference Date is stored
#'
#' A Date is a double, an IDate (and a Date built from integers) an integer,
#' and `col_type()` calls both `"Date"`. Left mismatched, the rows of the two
#' tables are later stacked into one key column, and data.table coerces a
#' double into an integer column with its own, unclassed warning. `d` is a
#' whole-day Date by the time it gets here, so changing its storage loses
#' nothing.
#'
#' @param d A Date, IDate or integer-stored Date of whole days.
#' @param ref The reference column whose storage `d` takes.
#' @return `d` stored as `ref` is, with its `"truncated"` attribute kept.
#' @noRd
date_like <- function(d, ref) {
  if (identical(typeof(d), typeof(ref)) && identical(class(d), class(ref))) {
    return(d)
  }
  rec <- attr(d, "truncated")
  out <- if (inherits(ref, "IDate")) {
    as.IDate(d)
  } else if (is.integer(ref)) {
    structure(as.integer(unclass(d)), class = "Date")
  } else {
    structure(as.double(unclass(d)), class = "Date")
  }
  attr(out, "truncated") <- rec
  out
}

#' Widen integer-stored Dates to doubles where the other table has doubles
#'
#' Where nothing is cast (`mode = "equal"`, `cast = FALSE`), a Date in one
#' table and an IDate in the other are still one type to `col_type()`, but
#' stacking a double Date that holds part of a day into an integer column
#' truncates it with data.table's unclassed warning. Widening the integer
#' side to a double loses nothing. Columns are replaced, never written into.
#'
#' @param x,y data.tables with the same column names.
#' @return `NULL`, invisibly; `x` and `y` are modified by reference.
#' @noRd
widen_dates <- function(x, y) {
  for (nm in names(x)) {
    a <- x[[nm]]
    b <- y[[nm]]
    if (inherits(a, "Date") && inherits(b, "Date") && typeof(a) != typeof(b)) {
      wide <- if (is.integer(a)) x else y
      v <- wide[[nm]]
      set(
        wide,
        j = nm,
        value = structure(as.double(unclass(v)), class = "Date")
      )
    }
  }
  invisible(NULL)
}

#' Say how to fix columns of a type dazdiff does not compare
#'
#' The tail of the message refusing such columns. normalize_dt() is offered
#' only for the types it can convert (`CAST_FROM`): offered for a difftime or
#' a list column, it led to a second refusal and then a third, none of them a
#' fix. Those the caller has to convert or drop.
#'
#' @param labels The columns, as the caller spells them.
#' @param types Their types, as `col_type()` names them.
#' @return A string starting with `"; "`, or `""` when there is nothing.
#' @noRd
fix_hint <- function(labels, types) {
  ok <- types %in% CAST_FROM
  paste0(
    if (any(ok)) {
      sprintf("; convert %s with normalize_dt() first", fmt_names(labels[ok]))
    },
    if (any(!ok)) {
      sprintf(
        paste0(
          "; normalize_dt() cannot convert %s, so convert or drop %s ",
          "yourself (with as.numeric() or as.character(), say)"
        ),
        paste(unique(types[!ok]), collapse = ", "),
        fmt_names(labels[!ok])
      )
    }
  )
}

# The record of a cast that truncated nothing.
truncated_empty <- function() {
  data.table(
    column = character(),
    n = integer(),
    examples = character(),
    rows = list()
  )
}

#' Cast a table's columns to a reference table's types
#'
#' Cast the columns of `y` to the types they have in the reference
#' `x`. Every column is validated and converted before any is written, so a
#' refusal leaves `y` exactly as it was.
#'
#' A truncation is reported, never silent: the columns, counts, examples and
#' the row numbers of `y` truncated (list column `rows`) are
#' recorded on `y` as `attr(y, "truncated")` (an empty table when
#' nothing was truncated) and announced in one message of class
#' `dazdiff_message_truncation`.
#'
#' @param x The reference table, whose column types are the targets.
#' @param y The table to convert. Modified by reference, so it must be a
#'   data.table; columns only in `y` are left alone.
#' @param cols The columns to cast, by default those present in both tables.
#' @param date_format,truncate,nan_is_na See `cast_value()`.
#' @param labels How each column is named in messages, by column; the column
#'   names themselves by default. `diff_table()` passes the caller's own
#'   spelling of names it has normalized.
#' @return `y`, invisibly.
#' @noRd
cast_dt <- function(
  x,
  y,
  cols = intersect(names(x), names(y)),
  date_format = "%Y-%m-%d",
  truncate = TRUE,
  nan_is_na = TRUE,
  labels = NULL
) {
  if (!is.data.frame(x) || !is.data.table(y)) {
    dazdiff_abort(
      "dazdiff_error_input",
      "`x` must be a data.frame and `y` a data.table"
    )
  }

  unknown <- setdiff(cols, intersect(names(x), names(y)))
  if (length(unknown)) {
    dazdiff_abort(
      "dazdiff_error_columns",
      paste0(
        "column(s) missing from x or y: ",
        paste(unknown, collapse = ", ")
      ),
      columns = unknown
    )
  }

  targets <- vapply(cols, function(nm) col_type(x[[nm]]), character(1L))
  bad <- targets[!targets %in% CAST_TYPES]
  if (length(bad)) {
    dazdiff_abort(
      "dazdiff_error_types",
      paste0(
        "x has column(s) of unsupported type: ",
        paste(sprintf("%s (%s)", names(bad), bad), collapse = ", ")
      ),
      columns = names(bad)
    )
  }

  if (is.null(labels)) {
    labels <- structure(cols, names = cols)
  }
  values <- Map(
    function(nm, to) {
      v <- y[[nm]]
      ref <- x[[nm]]
      # col_type() calls an IDate (integer storage) and a Date (double) one
      # type, so cast_value() would pass a Date onto an IDate untouched. A
      # double Date can hold part of a day, which an integer cannot: it goes
      # through numeric -> Date instead, floored and recorded like any number.
      if (
        to == "Date" && inherits(v, "Date") && is.double(v) && is.integer(ref)
      ) {
        v <- as.numeric(v)
      }
      out <- cast_value(
        v,
        to,
        labels[[nm]],
        origin = col_type(y[[nm]]),
        date_format = date_format,
        truncate = truncate,
        nan_is_na = nan_is_na
      )
      if (to == "character" && col_type(v) %in% c("numeric", "integer")) {
        out <- number_as_text_like(v, out, ref, labels[[nm]])
      }
      if (to == "Date") date_like(out, ref) else out
    },
    cols,
    targets
  )

  truncated <- rbindlist(c(
    list(truncated_empty()),
    lapply(cols, function(nm) {
      t <- attr(values[[nm]], "truncated")
      if (is.null(t)) {
        return(NULL)
      }
      data.table(
        column = labels[[nm]],
        n = t$n,
        examples = paste(t$examples, collapse = ", "),
        rows = list(t$rows)
      )
    })
  ))

  for (nm in cols) {
    v <- values[[nm]]
    attr(v, "truncated") <- NULL
    set(y, j = nm, value = v)
  }
  setattr(y, "truncated", truncated)

  if (nrow(truncated)) {
    dazdiff_inform(
      "dazdiff_message_truncation",
      paste0(
        "Truncated ",
        format(sum(truncated$n), big.mark = ","),
        " value(s) while casting to the reference types:\n",
        paste0(
          "  ",
          truncated$column,
          ": ",
          format(truncated$n, big.mark = ","),
          " (",
          truncated$examples,
          ")",
          collapse = "\n"
        )
      ),
      truncated = truncated
    )
  }
  invisible(y)
}

#' Convert a table to the types dazdiff compares
#'
#' [diff_table()] compares columns of five types: character, logical, Date,
#' numeric (double) and integer. In `mode = "benchmark"` the benchmark `x` must
#' already hold only those; in `mode = "equal"` both tables must. This converts
#' the columns that are something else, explicitly, so that any lossy
#' conversion is the caller's choice and not a silent default.
#'
#' A factor (ordered or not) becomes its labels by default. A timestamp
#' (POSIXct) has no default: `c(POSIXct = "Date")` keeps the calendar day in
#' the stamp's own zone (the session's zone for a stamp with none, as it
#' prints) and drops the time, so two stamps on the same day become one
#' value; `c(POSIXct = "character")` keeps the stamp as text, written as its
#' local time in its own zone as `"%Y-%m-%d %H:%M:%S"` (with the fraction of
#' a second, to the microsecond, when it has one) and without naming the
#' zone, so the same instant
#' held in two zones becomes two different strings: give both tables the
#' same zone first. Name the one you mean in `to`.
#'
#' An `integer64` column (from \pkg{bit64}) has no default either:
#' `c(integer64 = "numeric")` is exact below 2^53 and refuses larger values,
#' `"integer"` refuses values outside the integer range, and `"character"`
#' keeps every digit.
#'
#' @param dt A data.frame or data.table.
#' @param to Named character: which supported type (`"character"`,
#'   `"logical"`, `"Date"`, `"numeric"` or `"integer"`) each other type
#'   becomes, named by `"factor"`, `"POSIXct"` or `"integer64"`. The mappings
#'   given are added to the default, `factor` to `"character"`, and replace it
#'   only where they name `factor` themselves. A column whose type is in
#'   neither is an error, not a guess.
#' @param cols The columns to consider, by default all of them.
#' @return A `data.table`. `dt` is never modified; a copy is made only when
#'   there is something to convert, so the result is `dt` itself when there is
#'   not, and callers must treat it as read-only.
#' @export
#' @examples
#' x <- data.frame(
#'   day = as.POSIXct("2024-01-01 10:00", tz = "UTC"),
#'   kind = factor("a"),
#'   amount = 1.5
#' )
#' normalize_dt(x, to = c(POSIXct = "Date", factor = "character"))
normalize_dt <- function(dt, to = c(factor = "character"), cols = names(dt)) {
  if (!is.data.frame(dt)) {
    dazdiff_abort("dazdiff_error_input", "`dt` must be a data.frame")
  }
  # `to` is checked whole, before any column is looked at: a typo in it is a
  # mistake in the call whatever the table holds, and caught here it names
  # the valid choices rather than surfacing as a cast with "no rule".
  sources <- setdiff(CAST_FROM, CAST_TYPES)
  if (
    !is.character(to) ||
      (length(to) && is.null(names(to))) ||
      anyNA(to) ||
      anyDuplicated(names(to)) ||
      !all(names(to) %in% sources) ||
      !all(to %in% CAST_TYPES)
  ) {
    dazdiff_abort(
      "dazdiff_error_input",
      paste0(
        "`to` must be a character vector named by type, each name one of ",
        paste0("\"", sources, "\"", collapse = ", "),
        " (at most once) and each value one of ",
        paste0("\"", CAST_TYPES, "\"", collapse = ", "),
        if (is.character(to) && length(to)) {
          paste0(
            "; got ",
            paste0(
              if (is.null(names(to))) "" else paste0(names(to), " = "),
              "\"",
              to,
              "\"",
              collapse = ", "
            )
          )
        }
      )
    )
  }
  # The caller's mappings are added to the default, not put in its place:
  # naming the one conversion a table needs should not cost the factor one.
  to <- c(to, NORMALIZE_TO[setdiff(names(NORMALIZE_TO), names(to))])

  dt <- as.data.table(dt)

  unknown <- setdiff(cols, names(dt))
  if (length(unknown)) {
    dazdiff_abort(
      "dazdiff_error_columns",
      paste0("unknown column(s): ", paste(unknown, collapse = ", ")),
      columns = unknown
    )
  }

  types <- vapply(cols, function(nm) col_type(dt[[nm]]), character(1L))
  need <- cols[!types %in% CAST_TYPES]
  if (!length(need)) {
    return(dt)
  }

  unmapped <- need[!types[need] %in% names(to)]
  if (length(unmapped)) {
    # Naming a target in `to` is the fix only for a type normalize_dt() can
    # convert; for the others, fix_hint() says so.
    can <- types[unmapped] %in% CAST_FROM
    dazdiff_abort(
      "dazdiff_error_types",
      paste0(
        "no conversion given for column(s): ",
        paste(sprintf("%s (%s)", unmapped, types[unmapped]), collapse = ", "),
        if (any(can)) {
          sprintf(
            "; name the target type for %s in `to`",
            paste(unique(types[unmapped][can]), collapse = ", ")
          )
        },
        if (any(!can)) {
          fix_hint(unmapped[!can], types[unmapped][!can])
        }
      ),
      columns = unmapped
    )
  }

  # The caller named these conversions, truncating ones included, so what they
  # drop is the point rather than news: the record is not kept.
  out <- copy(dt)
  for (nm in need) {
    v <- cast_value(out[[nm]], to[[types[[nm]]]], nm)
    attr(v, "truncated") <- NULL
    set(out, j = nm, value = v)
  }
  out
}
