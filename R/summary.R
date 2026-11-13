# Summaries of a comparison ---------------------------------------------------

#' Summarize a comparison by measure
#'
#' Counts of each status for every measure of a [diff_table()] result, and,
#' for the usual one-row-per-value shape, how large the differences are.
#'
#' The magnitudes are taken over every value compared on both sides where both
#' source values are finite. They are filtered on the source values, not on
#' `diff`: two finite values can differ by more than the largest double, and
#' filtering on the difference would drop exactly that value and report the
#' largest difference in the table as 0. `rmse` is computed with scaling, so
#' squaring cannot overflow either.
#'
#' @param d A result of [diff_table()].
#' @return A `data.table` with one row per measure, in the benchmark's column
#'   order (a single row when there are no measures): `metric`, `n`,
#'   `n_same`, `n_changed`, `n_only_x`, `n_only_y`, and for the `"cells"`
#'   shape `max_abs_diff`, `mean_abs_diff`, `rmse` and `max_rel_diff` (`NA`
#'   for a measure with no finite pair).
#' @export
#' @examples
#' x <- data.frame(id = 1:3, amount = c(10, 20, 30), rate = c(1, 1, 1))
#' y <- data.frame(id = 1:3, amount = c(10, 25, 27), rate = c(1, 1, 1))
#' diff_summary(diff_table(x, y))
diff_summary <- function(d) {
  check_diff_result(d)
  shape <- attr(d, "shape")
  grp <- intersect("metric", names(d))
  counts <- d[,
    .(
      n = .N,
      n_same = sum(status == "same"),
      n_changed = sum(status == "changed"),
      n_only_x = sum(status == "only_x"),
      n_only_y = sum(status == "only_y")
    ),
    by = grp
  ]
  if (!length(grp) && !nrow(counts)) {
    counts <- data.table(
      n = 0L,
      n_same = 0L,
      n_changed = 0L,
      n_only_x = 0L,
      n_only_y = 0L
    )
  }

  if (shape == "cells") {
    sizes <- d[,
      {
        finite <- is_finite_pair(value_x, value_y)
        z <- (value_y - value_x)[finite]
        .(
          max_abs_diff = if (length(z)) max(abs(z)) else NA_real_,
          mean_abs_diff = if (length(z)) mean(abs(z)) else NA_real_,
          rmse = scaled_rmse(z),
          max_rel_diff = if (length(z)) max(rel_diff[finite]) else NA_real_
        )
      },
      by = metric
    ]
    counts <- counts[sizes, on = "metric"]
  }

  if (length(grp)) {
    order_of <- attr(d, "name_map")$column
    counts <- counts[order(match(metric, order_of))]
  }
  counts[]
}

check_diff_result <- function(d) {
  if (
    !is.data.table(d) || is.null(attr(d, "shape")) || !"status" %in% names(d)
  ) {
    dazdiff_abort("dazdiff_error_input", "`d` must be a result of diff_table()")
  }
  invisible(d)
}

# A value contributes to the magnitudes when both *source values* are finite.
# Filtering on the derived difference instead would discard a genuine,
# enormous difference whose subtraction overflowed to Inf.
is_finite_pair <- function(value_x, value_y) {
  is.finite(value_x) & is.finite(value_y)
}

# Root mean square, scaled by the largest magnitude so that squaring cannot
# overflow. Plain `sqrt(mean(z^2))` returns Inf for any difference above about
# 1.3e154, well inside the representable range.
scaled_rmse <- function(z) {
  if (!length(z)) {
    return(NA_real_)
  }
  m <- max(abs(z))
  if (!is.finite(m)) {
    return(Inf)
  }
  if (m == 0) {
    return(0)
  }
  m * sqrt(mean((z / m)^2))
}

#' Do the two tables match?
#'
#' `TRUE` when every record of a [diff_table()] result is `same`: no value
#' changed and no row is found in only one table. Two empty tables match.
#'
#' With `tolerance` or `rel_tol` given, the values are judged again at those
#' thresholds instead of the ones `diff_table()` used, from the `abs_diff`
#' and `rel_diff` it stores. That works in both directions, looser or
#' stricter, so one comparison can be asked at several thresholds without
#' being run again. The rule is `diff_table()`'s: two equal or two missing
#' values always match, and the tolerances apply to finite pairs only. A row
#' found in only one table never matches, whatever the threshold.
#'
#' @param d A result of [diff_table()].
#' @param tolerance,rel_tol `NULL` (the default) keeps the thresholds of the
#'   comparison. A number re-judges the values: a value matches when within
#'   either. When only one is given, the other is 0.
#' @return `TRUE` or `FALSE`.
#' @export
#' @examples
#' x <- data.frame(id = 1:3, amount = c(100, 200, 300))
#' y <- data.frame(id = 1:3, amount = c(100, 200.5, 300))
#' d <- diff_table(x, y)
#' is_matching(d)
#' is_matching(d, tolerance = 1)
#' is_matching(d, rel_tol = 0.001)
#' is_matching(d, rel_tol = 0.01)
is_matching <- function(d, tolerance = NULL, rel_tol = NULL) {
  check_diff_result(d)
  for (arg in c("tolerance", "rel_tol")) {
    v <- get(arg)
    if (
      !is.null(v) &&
        (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 0)
    ) {
      dazdiff_abort(
        "dazdiff_error_input",
        sprintf("`%s` must be NULL or a single finite number >= 0", arg)
      )
    }
  }
  status <- as.character(d$status)
  if (is.null(tolerance) && is.null(rel_tol)) {
    return(all(status == "same"))
  }
  tolerance <- if (is.null(tolerance)) 0 else tolerance
  rel_tol <- if (is.null(rel_tol)) 0 else rel_tol

  shape <- attr(d, "shape")
  # The multisets of "aggregate" are compared exactly and hold no difference
  # to re-judge, as diff_table() refuses a tolerance with them.
  if (shape == "groups" && (tolerance > 0 || rel_tol > 0)) {
    dazdiff_abort(
      "dazdiff_error_input",
      "a result of duplicates = \"aggregate\" compares values exactly; `tolerance` and `rel_tol` must be 0"
    )
  }
  if (shape != "cells") {
    return(all(status == "same"))
  }

  joined <- status %in% c("same", "changed")
  # rel_diff is defined exactly where both values are finite, which is where
  # the tolerances apply. Elsewhere a value matched by equality or by being
  # missing on both sides, which no threshold changes.
  finite <- !is.na(d$rel_diff)
  same <- joined &
    ifelse(
      finite,
      d$abs_diff <= tolerance | d$rel_diff <= rel_tol,
      status == "same"
    )
  all(same)
}
