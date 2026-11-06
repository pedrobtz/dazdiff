# The checks the scratch suites were written with, as testthat expectations.
# A check is a label and something that must be TRUE; the semantics of each
# helper are unchanged, only the reporting now goes through testthat.

check <- function(label, ok) {
  testthat::expect_true(isTRUE(ok), label = label)
}

# `expr` must raise an error of `class`. Which check fired is told by the
# class, never by the wording: the wording is pinned by the snapshots in
# test-messages.R. `expr` stays unevaluated until it is forced inside
# tryCatch().
check_error <- function(label, expr, class) {
  e <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = function(e) e
  )
  info <- if (is.null(e)) {
    "no error"
  } else {
    paste0("got <", paste(class(e), collapse = "/"), ">: ", conditionMessage(e))
  }
  testthat::expect_true(inherits(e, class), label = label, info = info)
}

# `expr` must be TRUE and must warn; `pattern` pins which warning.
check_warns <- function(label, expr, pattern = NULL) {
  w <- NULL
  val <- withCallingHandlers(
    expr,
    warning = function(cond) {
      w <<- c(w, conditionMessage(cond))
      invokeRestart("muffleWarning")
    }
  )
  hit <- length(w) > 0L && (is.null(pattern) || any(grepl(pattern, w)))
  testthat::expect_true(hit && isTRUE(val), label = label, info = paste(w, collapse = "; "))
}

# `expr` must be TRUE and must not warn at all.
check_clean <- function(label, expr) {
  w <- NULL
  val <- withCallingHandlers(
    expr,
    warning = function(cond) {
      w <<- c(w, conditionMessage(cond))
      invokeRestart("muffleWarning")
    }
  )
  testthat::expect_true(is.null(w) && isTRUE(val), label = label, info = paste(w, collapse = "; "))
}

# How many rows of each status came back. Absent statuses read as 0.
tally <- function(res) {
  want <- c("same", "changed", "only_x", "only_y")
  out <- stats::setNames(integer(length(want)), want)
  got <- res[, .N, by = status]
  out[as.character(got$status)] <- got$N
  out
}

is_tally <- function(res, same = 0L, changed = 0L, only_x = 0L, only_y = 0L) {
  identical(tally(res), c(same = same, changed = changed, only_x = only_x, only_y = only_y))
}
