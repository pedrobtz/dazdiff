# The testthat expectation ------------------------------------------------------

#' Expect a table to match another
#'
#' A testthat expectation built on [diff_table()]: it passes when every
#' compared value is `same`. `expected` is the benchmark, as in testthat's
#' `expect_equal(object, expected)`, so the comparison is
#' `diff_table(expected, object, ...)`: `object` is cast to `expected`'s types
#' and its extra columns are dropped. Pass `mode = "equal"` to compare the two
#' as peers instead.
#'
#' Unlike [diff_table()], which is exact by default, the expectation allows a
#' relative difference of `sqrt(.Machine$double.eps)` (about `1.5e-8`), the
#' default of testthat's `expect_equal()`: a value computed again rarely
#' agrees with its stored copy to the last bit (`0.1 + 0.2` is not `0.3`), and
#' a test should not fail on that. It is still far below any difference a
#' person would call real. Pass `rel_tol = 0` for an exact comparison.
#'
#' Duplicate keys are an error (`dazdiff_error_duplicates`), not a failure:
#' pairing rows by arrival order is an assumption, and an assertion should not
#' rest on one, so the test cannot be judged as written. The exception is a
#' comparison with no measures, where the repeated rows are identical in every
#' compared column and pairing them assumes nothing. Pass
#' `duplicates = "disambiguate"` or `"aggregate"` to accept duplicates.
#'
#' Tables that share no key -- most often because `object` came back empty --
#' fail the expectation. [diff_table()] refuses such a comparison as
#' ill-formed, but under test it is an answer: the two tables differ in every
#' row.
#'
#' @param object The table under test.
#' @param expected The benchmark table.
#' @param ... Passed to [diff_table()]: `mode`, `by`, `measures`,
#'   `tolerance`, `duplicates` and so on.
#' @param rel_tol The largest relative difference still counted as `same`,
#'   as in [diff_table()]. With `duplicates = "aggregate"`, which compares
#'   exactly, it defaults to 0.
#' @param max_rows The most records that differ shown in a failure.
#' @return The [diff_table()] result, invisibly. On failure it is also
#'   attached to the failed expectation, as its `"diff"` attribute. `NULL`
#'   when the tables share no key, since there is no result.
#' @export
#' @examplesIf requireNamespace("testthat", quietly = TRUE)
#' expected <- data.frame(id = 1:3, amount = c(10, 20, 30))
#' actual <- data.frame(id = 1:3, amount = c(10, 20, 30 + 1e-9))
#' expect_table_equal(actual, expected, tolerance = 1e-6)
expect_table_equal <- function(
  object,
  expected,
  ...,
  rel_tol = sqrt(.Machine$double.eps),
  max_rows = 10L
) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    dazdiff_abort(
      "dazdiff_error_dependency",
      "expect_table_equal() requires the suggested package 'testthat'"
    )
  }
  if (
    !is.numeric(max_rows) ||
      length(max_rows) != 1L ||
      is.na(max_rows) ||
      max_rows < 0
  ) {
    dazdiff_abort(
      "dazdiff_error_input",
      "`max_rows` must be a single number >= 0"
    )
  }
  object_label <- deparse1(substitute(object))
  expected_label <- deparse1(substitute(expected))

  dots <- list(...)
  # diff_table() matches `duplicates` partially and its value with
  # match.arg(), so `dup = "agg"` means "aggregate"; read it the same way.
  duplicates <- dots_duplicates(dots)
  # "aggregate" compares multisets of values exactly and refuses a tolerance,
  # so the default steps aside; one the caller sets explicitly still reaches
  # diff_table(), which refuses it.
  if (missing(rel_tol) && identical(duplicates, "aggregate")) {
    rel_tol <- 0
  }
  # diff_table() warns exactly when it pairs duplicate rows of measures, so
  # that warning is the error: an assertion must not decide identity by
  # arrival order. Without measures it does not warn, and pairing goes ahead.
  refuse_pairing <- is.null(duplicates)
  d <- tryCatch(
    withCallingHandlers(
      do.call(
        diff_table,
        c(list(expected, object), dots, list(rel_tol = rel_tol))
      ),
      dazdiff_warning_duplicates = function(w) {
        if (refuse_pairing) {
          dazdiff_abort(
            "dazdiff_error_duplicates",
            paste0(
              conditionMessage(w),
              "\nexpect_table_equal() does not pair duplicate keys; pass ",
              "duplicates = \"disambiguate\" or \"aggregate\" to accept them."
            ),
            duplicates = w$duplicates
          )
        }
      }
    ),
    dazdiff_error_disjoint = function(e) e
  )
  if (inherits(d, "dazdiff_error_disjoint")) {
    testthat::expectation(
      "failure",
      paste0(
        "`",
        object_label,
        "` does not match `",
        expected_label,
        "` (as `y` and `x`): ",
        conditionMessage(d)
      )
    )
    return(invisible(NULL))
  }

  if (all(d$status == "same")) {
    testthat::succeed()
    return(invisible(d))
  }

  off <- d[status != "same"]
  shown <- head(off, max_rows)
  msg <- paste0(
    "`",
    object_label,
    "` does not match `",
    expected_label,
    "`: ",
    format(nrow(off), big.mark = ","),
    " of ",
    format(nrow(d), big.mark = ","),
    " records differ.\n\n",
    paste(utils::capture.output(print(diff_summary(d))), collapse = "\n"),
    if (nrow(shown)) {
      paste0(
        "\n\n",
        if (nrow(off) > nrow(shown)) {
          sprintf("First %d records that differ:\n", nrow(shown))
        },
        paste(utils::capture.output(print(shown)), collapse = "\n")
      )
    }
  )
  # expectation() passes `...` on only since testthat 3.3.0; building the
  # expectation and signalling it works back to the Suggests floor.
  testthat::exp_signal(testthat::new_expectation("failure", msg, diff = d))
  invisible(d)
}

# The value of `duplicates` in the dots, as diff_table() will read it: the
# name matched partially against diff_table()'s arguments, the value with
# match.arg(). NULL when the caller did not pass it.
dots_duplicates <- function(dots) {
  nms <- names(dots)
  if (is.null(nms)) {
    return(NULL)
  }
  full <- names(formals(diff_table))
  hit <- which(full[pmatch(nms, full, duplicates.ok = TRUE)] == "duplicates")
  if (!length(hit)) {
    return(NULL)
  }
  value <- dots[[hit[1L]]]
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    return(value)
  }
  choices <- eval(formals(diff_table)$duplicates)
  i <- pmatch(value, choices)
  if (is.na(i)) value else choices[i]
}
