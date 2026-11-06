# Melting to one row per measured value --------------------------------------

# The type keywords `measures` accepts, and the col_type()s each selects. The
# keywords are lower case and normalized column names never are, so a keyword
# can never be mistaken for a column.
MEASURE_TYPES <- list(
  numeric = "numeric",
  `numeric+integer` = c("numeric", "integer")
)

#' Resolve which columns are measures
#'
#' @param dt A data.frame.
#' @param measures A type keyword from `MEASURE_TYPES`, or column names.
#'   Named columns must be numeric or integer: they are melted into one double
#'   value column, and a Date or a string has no place there.
#' @param labels Optional: how messages name each column, by column name.
#' @param given Optional: `measures` as the caller wrote them, parallel to
#'   `measures`, quoted for a name that is repeated or not a column.
#' @return The measure column names, in `dt`'s column order for a keyword
#'   and in the given order for names. Possibly empty: `character(0)` asks
#'   for none.
#' @noRd
select_measures <- function(
  dt,
  measures = "numeric",
  labels = NULL,
  given = measures
) {
  if (!is.character(measures) || anyNA(measures)) {
    daffiz_abort(
      "daffiz_error_measures",
      paste0(
        "`measures` must be \"numeric\", \"numeric+integer\", column names, ",
        "or character(0) for none"
      )
    )
  }
  if (!length(measures)) {
    return(character())
  }
  if (is.null(labels)) {
    labels <- structure(names(dt), names = names(dt))
  }
  types <- vapply(dt, col_type, character(1L))
  if (length(measures) == 1L && measures %in% names(MEASURE_TYPES)) {
    return(names(dt)[types %in% MEASURE_TYPES[[measures]]])
  }

  # A repeated name would melt the column twice on each side, and the join
  # would then go cartesian and silently double every count.
  dup <- unique(measures[duplicated(measures)])
  unknown <- setdiff(measures, names(dt))
  said <- function(cols) unique(given[measures %in% cols])
  wrong <- setdiff(
    measures,
    c(unknown, names(dt)[types %in% c("numeric", "integer")])
  )
  problems <- c(
    if (length(dup)) {
      paste0("named more than once: ", paste(said(dup), collapse = ", "))
    },
    if (length(unknown)) {
      paste0("not a column: ", paste(said(unknown), collapse = ", "))
    },
    if (length(wrong)) {
      paste0(
        "not numeric or integer: ",
        paste(sprintf("%s (%s)", labels[wrong], types[wrong]), collapse = ", ")
      )
    }
  )
  if (length(problems)) {
    daffiz_abort(
      "daffiz_error_measures",
      paste0("`measures` ", paste(problems, collapse = "; ")),
      columns = c(dup, unknown, wrong)
    )
  }
  measures
}

#' Number and key the rows of a table
#'
#' The wide table the rest of the pipeline works on: `row_id` first, then
#' the id columns and the measures, keyed by the ids. `row_id` ties every
#' row, and later every molten value, back to the row of `dt` it came
#' from; downstream reads it as a presence marker, so it is never missing.
#'
#' The selected columns are copied. `setkeyv()` reorders rows in place,
#' writing into the column vectors, and those may be the caller's: a column of
#' a data.table subset, or of a table renamed by `shallow_dt()`, is the
#' caller's vector, not a copy of it. Columns in neither role are left out.
#'
#' Integer measures are promoted to double here: `melt()` puts all
#' measures into one value column, and warns when it has to widen them itself.
#'
#' @param dt A data.frame.
#' @param ids The row identity: the key.
#' @param measures The measure columns.
#' @param nan_is_na Map NaN to NA in double id columns. data.table joins and
#'   groups NA and NaN as different keys, so without this a row keyed NaN on
#'   one side and NA on the other would not align.
#' @return A keyed data.table. Every missing value and every zero in a double
#'   id column holds one bit pattern; see `canonical_missing()`.
#' @noRd
index_dt <- function(dt, ids, measures = character(), nan_is_na = FALSE) {
  cols <- c(ids, measures)
  wide <- lapply(as.list(dt)[cols], copy)
  for (nm in measures) {
    if (is.integer(wide[[nm]])) {
      wide[[nm]] <- as.double(wide[[nm]])
    }
  }
  for (nm in ids) {
    wide[[nm]] <- canonical_missing(wide[[nm]], nan_is_na)
  }
  wide <- setDT(c(list(row_id = seq_len(nrow(dt))), wide))
  if (length(ids)) {
    setkeyv(wide, ids)
  }
  wide[]
}

#' One bit pattern per missing value, and per zero, in a double key
#'
#' R calls NA any NaN whose low word is 1954, and arithmetic on NA
#' (`NA + 0`, `as.Date(NA) + 1`, `x / 1000`) sets the quiet bit
#' on the way, so a computed key column often holds two NA patterns.
#' data.table joins them as one key, but its keyed grouping keeps them apart,
#' so duplicate numbering and the fanout check disagreed with the join.
#' Writing every NA back as `NA_real_` and every NaN as `NaN` gives
#' data.table one pattern for each, in every class built on a double (Date
#' and POSIXct included).
#'
#' Zero has the same problem: `-0` and `0` are one key to a join but two
#' groups to keyed grouping, so a key holding both slipped past the duplicate
#' check and paired one row twice. `round(-0.4)` and `-1 * 0` are `-0`, so
#' every zero is written back as `+0`. `integer64` is left alone: its bits
#' are not a double, and the pattern of `-0` is its `NA`.
#'
#' @param v A vector; only doubles are touched.
#' @param nan_is_na Whether NaN becomes NA too.
#' @return `v`, with its class and attributes.
#' @noRd
canonical_missing <- function(v, nan_is_na = FALSE) {
  if (!is.double(v) || inherits(v, "integer64")) {
    return(v)
  }
  at <- attributes(v)
  v <- as.vector(unclass(v), "double")
  v[!is.na(v) & v == 0] <- 0
  if (anyNA(v)) {
    nan <- is.nan(v)
    v[is.na(v) & (nan_is_na | !nan)] <- NA_real_
    if (!nan_is_na) {
      v[nan] <- NaN
    }
  }
  attributes(v) <- at
  v
}

#' Melt a table, choosing the measures by type or by name
#'
#' Long form of `dt`, measuring the columns `measures` selects and
#' carrying the rest along as ids. The measure names come back as character
#' rather than the factor `melt()` defaults to, so they compare and join
#' like any label.
#'
#' A table that already carries `row_id` is taken as indexed by
#' `index_dt()` and melted as it is, keeping its key (`key_seq`
#' included, when duplicates were numbered). Any other table is indexed first,
#' with every column that is not a measure as its identity. User columns can
#' never be called `row_id`: `diff_table()` normalizes their names to
#' upper case first.
#'
#' @param dt A data.frame (or data.table).
#' @param measures `"numeric"` (the default) melts only the double columns.
#'   `"numeric+integer"` melts the integers too, as doubles. Column names
#'   melt exactly those.
#' @param variable_name Name of the column holding the measure names.
#' @param value_name Name of the column holding the measured values.
#' @return A long data.table keyed by the id columns, with `row_id` carried
#'   along as a column but left out of the key, so the key is made of real
#'   values. With no measures there is nothing to melt, and the indexed table
#'   comes back as it is: one row per row.
#' @noRd
melt_dt <- function(
  dt,
  measures = "numeric",
  variable_name = "metric",
  value_name = "value"
) {
  if (!is.data.frame(dt)) {
    daffiz_abort("daffiz_error_input", "`dt` must be a data.frame")
  }

  if ("row_id" %in% names(dt)) {
    own <- setdiff(names(dt), c("row_id", "key_seq"))
    measure <- select_measures(shallow_dt(dt, own), measures)
  } else {
    measure <- select_measures(dt, measures)
    dt <- index_dt(dt, setdiff(names(dt), measure), measure)
  }
  if (!length(measure)) {
    return(dt)
  }

  id_vars <- setdiff(names(dt), measure)
  long <- melt.data.table(
    dt,
    id.vars = id_vars,
    measure.vars = measure,
    variable.name = variable_name,
    value.name = value_name,
    variable.factor = FALSE
  )
  setcolorder(long, "row_id")
  key_cols <- setdiff(id_vars, "row_id")
  if (length(key_cols)) {
    setkeyv(long, key_cols)
  }
  long[]
}
