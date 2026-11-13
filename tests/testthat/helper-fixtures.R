# Fixtures are functions, so every test builds its own fresh copy: the suite
# runs under `devtools::test(shuffle = TRUE)`, and nothing a test needs may
# be left behind by another one.

# The baseline table the original cases used.
d1_fixture <- function() {
  fake_dt(
    n = 3,
    n_cols = c(character = 2, date = 1, integer = 1, numeric = 2),
    seed = 42
  )
}

# Hand-built tables where every row is identifiable, so the expectations are
# about the code and not about what fake_dt() happened to draw.
base_fixture <- function() data.table(id = c("a", "b", "c"), v = c(1, 2, 3))

# All four statuses at once: a same, a changed, an only_x and an only_y row.
x3_fixture <- function() data.table(id = c("a", "b", "c"), v = c(1, 2, 3))
y3_fixture <- function() data.table(id = c("a", "b", "d"), v = c(1, 2.5, 4))

# The same pair as x3 and y3, as test-report.R draws it: the measure is value.
report_x <- function() data.table(id = c("a", "b", "c"), value = c(1, 2, 3))
report_y <- function() data.table(id = c("a", "b", "d"), value = c(1, 2.5, 4))

# The table of test-melt.R: one id of each kind, two doubles.
melt_fixture <- function() {
  fake_dt(4, n_cols = c(character = 1, integer = 1, numeric = 2), seed = 1)
}

# The keyed pair of test-merge.R: "a" and "b" shared, "c" and "d" not.
kx_fixture <- function() setkey(data.table(id = c("a", "b", "c"), v = 1:3), id)
ky_fixture <- function() setkey(data.table(id = c("a", "b", "d"), w = 4:6), id)

# The table of test-diff-table-cases.R. VAL is the only numeric, so it is the
# measure and the other four columns are the ids.
cases_fixture <- function() {
  data.table(
    ID = c("a", "b", "c", "d"),
    GRP = c("x", "x", "y", "y"),
    DAY = as.Date("2024-01-01") + 0:3,
    CNT = 1:4,
    VAL = c(10, 20, 30, 40)
  )
}

# One representative value per source type, chosen so an allowed conversion
# has something it can actually convert.
cast_sample <- function(from, to) {
  switch(
    from,
    character = switch(
      to,
      logical = "TRUE",
      Date = "2024-03-05",
      integer = "3",
      numeric = "1.5",
      "abc"
    ),
    logical = TRUE,
    Date = as.Date("2024-03-05"),
    numeric = 3.5,
    integer = 3L,
    POSIXct = as.POSIXct("2024-03-05 23:30:00", tz = "UTC"),
    factor = factor("abc"),
    integer64 = bit64::as.integer64(3)
  )
}

# The cast rules this session can exercise: integer64 converts through bit64,
# a suggested package.
cast_rules_here <- function() {
  if (requireNamespace("bit64", quietly = TRUE)) {
    CAST_RULES
  } else {
    CAST_RULES[from != "integer64"]
  }
}

# Makes requireNamespace() report `pkg` as missing for the rest of the calling
# test, leaving every other package alone.
local_missing_package <- function(pkg, env = parent.frame()) {
  real <- base::requireNamespace
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) {
      if (identical(package, pkg)) FALSE else real(package, ...)
    },
    .package = "base",
    .env = env
  )
}

# testthat runs every test with LC_COLLATE=C, where radix order and the
# locale's order agree, so a test of "sorts in the C locale" passes whether or
# not the code asks for radix. These run under a locale that sorts otherwise,
# and fail if it is not asked for.
local_english_collation <- function(env = parent.frame()) {
  ok <- tryCatch(
    {
      withr::local_collate("en_US.UTF-8", .local_envir = env)
      TRUE
    },
    warning = function(w) FALSE,
    error = function(e) FALSE
  )
  testthat::skip_if_not(ok, "the en_US.UTF-8 locale is not available")
  # The locale must really sort otherwise, or the test proves nothing.
  testthat::skip_if(
    identical(sort(c("B", "a")), c("B", "a")),
    "en_US.UTF-8 sorts as the C locale does here"
  )
}

# The README's comparison, as test-explain.R explains it: ID 1 and 3 match,
# 2 changed, 4 and 5 are in one table only, and REGION north is mixed.
explain_fixture <- function() {
  x <- data.table(
    id = 1:4,
    region = c("north", "south", "east", "west"),
    amount = c(100, 200, 300, 400),
    units = c(10, 20, 30, 40)
  )
  y <- data.table(
    id = c(1:3, 5L),
    region = c("north", "south", "east", "north"),
    amount = c(100, 200.5, 300, 500),
    units = c(10, 20, 30, 50)
  )
  diff_table(x, y, by = c("id", "region"))
}
