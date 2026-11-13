# Which key values split the result into same and not same ---------------------

#' Explain a comparison by its key columns
#'
#' Which values of the key columns separate the rows that match from the ones
#' that do not. After [diff_table()] reports differences, the next question
#' is usually *where*: one region, one load date, one measure. This answers
#' it from the result alone.
#'
#' Called with no `column`, it returns one row per key column, and per
#' `metric` when the result has measures. Each distinct value of the column
#' is classed by the records that hold it: `same` when every one of them
#' matches, `differ` when none does, `mixed` otherwise. A column
#' `separates` the result when no value is mixed: knowing the value tells
#' whether the record matches.
#'
#' A column that holds a different value on every row (an id) always
#' separates and explains nothing; it is marked `identifies` and ranked
#' last. The others come first, fewest mixed values first, then fewest
#' values: the shortest explanation leads.
#'
#' Called with a `column`, it returns one row per value of that column, with
#' its counts of each status, most differences first: the values to look at.
#'
#' @section What is counted:
#' For a key column the unit is the row: a row matches only when every one of
#' its measures does, as in [diff_report()]. With `duplicates = "aggregate"`
#' the unit is the key. For `metric` the unit is the value, one per row and
#' measure, so it can say that only one measure changes.
#'
#' A row found in only one table and a value that changed usually have
#' different causes. `among = "joined"` counts only the rows found in both
#' tables, so the explanation is of the changed values alone.
#'
#' @param d A result of [diff_table()].
#' @param column `NULL` (the default) for the overview of every key column,
#'   or one column to break down by value: a key column, in either spelling,
#'   or `"metric"`.
#' @param among `"all"` (the default) counts every record; `"joined"` only
#'   those of rows found in both tables.
#' @return A `data.table`. The overview has `column`, `n_values`,
#'   `same_only`, `differ_only` and `mixed` (the number of values of each
#'   class), `separates` and `identifies`. The breakdown has the column's
#'   values, `n`, `n_same`, `n_changed`, `n_only_x`, `n_only_y` and `class`.
#' @export
#' @examples
#' x <- data.frame(
#'   id = 1:4,
#'   region = c("north", "south", "east", "west"),
#'   amount = c(100, 200, 300, 400)
#' )
#' y <- data.frame(
#'   id = c(1:3, 5L),
#'   region = c("north", "south", "east", "north"),
#'   amount = c(100, 200.5, 300, 500)
#' )
#' d <- diff_table(x, y, by = c("id", "region"))
#' diff_explain(d)
#' diff_explain(d, "region")
#' diff_explain(d, "region", among = "joined")
diff_explain <- function(d, column = NULL, among = c("all", "joined")) {
  check_diff_result(d)
  among <- arg_match(among)
  # As in diff_report(): user columns have no lowercase letter, internal ones
  # always do, and `row_number` is the one internal key. Read off the names,
  # not key(d), so a filtered or re-sorted result still explains.
  ids <- names(d)[!grepl("[a-z]", names(d)) | names(d) == "row_number"]
  has_metric <- "metric" %in% names(d)
  candidates <- c(ids, if (has_metric) "metric")

  if (!is.null(column)) {
    if (!is.character(column) || length(column) != 1L || is.na(column)) {
      dazdiff_abort(
        "dazdiff_error_input",
        "`column` must be NULL or a single column name"
      )
    }
    given <- column
    column <- if (column %in% candidates) column else canonical_names(column)
    if (!column %in% candidates) {
      dazdiff_abort(
        "dazdiff_error_columns",
        paste0(
          "`column` must be a key column of the result",
          if (has_metric) " or \"metric\"",
          "; got ",
          given,
          "; the key columns are ",
          fmt_names(ids)
        ),
        columns = given
      )
    }
  }

  units <- explain_units(d, ids)
  cells <- if (has_metric) explain_cells(d) else NULL
  if (among == "joined") {
    units <- units[units$status %in% c("same", "changed")]
    if (has_metric) {
      cells <- cells[cells$status %in% c("same", "changed")]
    }
  }
  records <- function(col) if (col == "metric") cells else units

  if (!is.null(column)) {
    return(explain_values(records(column), column))
  }

  out <- rbindlist(c(
    list(data.table(
      column = character(),
      n_values = integer(),
      same_only = integer(),
      differ_only = integer(),
      mixed = integer(),
      separates = logical(),
      identifies = logical()
    )),
    lapply(candidates, function(col) {
      r <- records(col)
      v <- explain_values(r, col)
      data.table(
        column = col,
        n_values = nrow(v),
        same_only = sum(v$class == "same"),
        differ_only = sum(v$class == "differ"),
        mixed = sum(v$class == "mixed"),
        separates = !any(v$class == "mixed"),
        # metric is never an identifier: it repeats on every row.
        identifies = col != "metric" && nrow(v) > 1L && nrow(v) == nrow(r)
      )
    })
  ))
  setorderv(out, c("identifies", "mixed", "n_values"))
  out[]
}

# One record per row (per key with duplicates = "aggregate"), with the status
# of the row as a whole: only_x or only_y by membership, which comes from
# row_id or n_rows and never from the value; otherwise changed when any of
# its measures changed.
explain_units <- function(d, ids) {
  present <- if (attr(d, "shape") == "groups") "n_rows" else "row_id"
  row_by <- intersect(c(ids, "key_seq"), names(d))
  w <- d[, row_by, with = FALSE]
  set(w, j = "in_x", value = as.integer(!is.na(d[[paste0(present, "_x")]])))
  set(w, j = "in_y", value = as.integer(!is.na(d[[paste0(present, "_y")]])))
  set(w, j = "is_changed", value = as.integer(d$status == "changed"))
  # max() of an empty group warns, so an empty result skips the grouping.
  if (nrow(w)) {
    w <- w[,
      lapply(.SD, max),
      by = row_by,
      .SDcols = c("in_x", "in_y", "is_changed")
    ]
  }
  status <- with(
    w,
    ifelse(
      !in_y,
      "only_x",
      ifelse(!in_x, "only_y", ifelse(is_changed == 1L, "changed", "same"))
    )
  )
  out <- w[, row_by, with = FALSE]
  set(out, j = "status", value = as.character(status))
  out
}

# One record per row and measure: the result itself.
explain_cells <- function(d) {
  data.table(metric = as.character(d$metric), status = as.character(d$status))
}

# The counts of each status per value of `col`, with the value's class: most
# differences first, then the values that only differ before the mixed ones,
# since they are the cleaner lead.
explain_values <- function(r, col) {
  s <- r$status
  v <- data.table(
    value = r[[col]],
    same = s == "same",
    changed = s == "changed",
    only_x = s == "only_x",
    only_y = s == "only_y"
  )
  out <- v[,
    .(
      n = .N,
      n_same = sum(same),
      n_changed = sum(changed),
      n_only_x = sum(only_x),
      n_only_y = sum(only_y)
    ),
    by = "value"
  ]
  set(
    out,
    j = "class",
    value = ifelse(
      out$n_same == out$n,
      "same",
      ifelse(out$n_same == 0L, "differ", "mixed")
    )
  )
  rank <- match(out$class, c("differ", "mixed", "same"))
  out <- out[order(-(out$n - out$n_same), rank, out$value)]
  setnames(out, "value", col)
  out[]
}
