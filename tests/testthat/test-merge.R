# Ported from .agents/test.R. Every block builds what it checks, so the file
# runs in any order (devtools::test(shuffle = TRUE)).

test_that("merge_dry_run counts a one-to-one join", {
  dry <- merge_dry_run(kx_fixture(), ky_fixture())
  check("merge_dry_run: counts the rows on each side", dry$rows_x == 3L && dry$rows_y == 3L)
  check("merge_dry_run: counts the distinct keys", dry$keys_x == 3L && dry$keys_y == 3L)
  check("merge_dry_run: counts the shared keys", dry$keys_common == 2L)
  check("merge_dry_run: counts the matching rows", dry$matched_x == 2L && dry$matched_y == 2L)
  check("merge_dry_run: reports the matched share of x", dry$pct_x == 200 / 3)
  check("merge_dry_run: reports the matched share of y", dry$pct_y == 200 / 3)
  check("merge_dry_run: an inner join would keep 2 rows", dry$est_merge_rows == 2L)
  check("merge_dry_run: no key produces more than one row", dry$max_fanout == 1L)
  check("merge_dry_run: so the join is one to one", isTRUE(dry$one_to_one))
  check("merge_dry_run: no duplicate keys on either side", dry$dups_x == 0L && dry$dups_y == 0L)
})

test_that("merge_dry_run reports the share of each side separately", {
  dry <- merge_dry_run(kx_fixture(), setkey(data.table(id = c("a", "x", "y", "z"), w = 1:4), id))
  check("merge_dry_run: 1 of x's 3 rows matches", dry$pct_x == 100 / 3)
  check("merge_dry_run: 1 of y's 4 rows matches", dry$pct_y == 25)
})

test_that("merge_dry_run counts the fanout of a repeated key", {
  fan <- merge_dry_run(
    setkey(data.table(id = c("a", "a"), v = 1:2), id),
    setkey(data.table(id = c("a", "a", "a"), w = 1:3), id)
  )
  check("merge_dry_run: 2 x 3 rows on one key would be 6", fan$est_merge_rows == 6L)
  check("merge_dry_run: and that is the fanout", fan$max_fanout == 6L)
  check("merge_dry_run: so the join is refused as not one to one", isFALSE(fan$one_to_one))
  check("merge_dry_run: it says which side repeats", fan$dups_x == 1L && fan$dups_y == 1L)
})

test_that("merge_dry_run of two tables with no shared key", {
  none <- merge_dry_run(kx_fixture(), setkey(data.table(id = c("x", "y"), w = 1:2), id))
  check("merge_dry_run: no shared keys", none$keys_common == 0L && none$est_merge_rows == 0L)
  check("merge_dry_run: nothing matches, so nothing fans out", none$max_fanout == 0L && isTRUE(none$one_to_one))
})

# Fanout only sees shared keys, so duplicates on one side alone used to slip
# through the gate. Finding 6.
test_that("a key repeating on one side alone is not one to one", {
  # The repeated key is shared by nothing, so nothing fans out.
  lop <- merge_dry_run(
    setkey(data.table(id = "a", v = 1), id),
    setkey(data.table(id = c("b", "b"), w = 1:2), id)
  )
  check("merge_dry_run: no key is shared", lop$keys_common == 0L)
  check("merge_dry_run: so nothing fans out", lop$max_fanout == 0)
  check("merge_dry_run: but it is not a one-to-one join", isFALSE(lop$one_to_one))
  check("merge_dry_run: and it says which side repeats", lop$dups_y == 1L && lop$dups_x == 0L)
  check_error(
    "merge_dt: so the merge is refused",
    merge_dt(setkey(data.table(id = "a", v = 1), id),
             setkey(data.table(id = c("b", "b"), w = 1:2), id), all = TRUE),
    class = "daffiz_error_keys"
  )
  # The shared key is unique, so the fanout is 1, and still the gate holds.
  side <- merge_dry_run(
    setkey(data.table(id = "a", v = 1), id),
    setkey(data.table(id = c("a", "c", "c"), w = 1:3), id)
  )
  check("merge_dry_run: a unique shared key fans out to 1", side$max_fanout == 1)
  check("merge_dry_run: the repeat elsewhere still breaks one to one", isFALSE(side$one_to_one))
})

# Integer counts square past 2^31 on a wide join. Finding 7.
test_that("merge_dry_run counts a fanout past 2^31 without overflow", {
  big <- 46341L
  big_dry <- merge_dry_run(
    setkey(data.table(id = rep(1L, big)), id),
    setkey(data.table(id = rep(1L, big)), id)
  )
  check("merge_dry_run: a large fanout does not overflow", big_dry$est_merge_rows == as.double(big) * big)
  check("merge_dry_run: nor does the fanout itself", big_dry$max_fanout == as.double(big) * big)
  check("merge_dry_run: and the gate still answers", isFALSE(big_dry$one_to_one))
})

test_that("merge_dry_run: an empty side, and refusals", {
  kx <- kx_fixture()
  empty <- merge_dry_run(kx[0], ky_fixture())
  check("merge_dry_run: an empty side gives NA for its share", is.na(empty$pct_x))
  check_error("merge_dry_run: no key to join on", merge_dry_run(data.table(a = 1), data.table(a = 1)), class = "daffiz_error_keys")
  check_error("merge_dry_run: a column missing from one side", merge_dry_run(kx, ky_fixture(), on = "nope"), class = "daffiz_error_columns")
  check_error("merge_dry_run: refuses a data.frame", merge_dry_run(as.data.frame(kx), ky_fixture(), on = "id"), class = "daffiz_error_input")
})

test_that("merge_dt defaults to a new inner join", {
  kx <- kx_fixture()
  m_inner <- merge_dt(kx, ky_fixture())
  check("merge_dt: new mode defaults to an inner join", nrow(m_inner) == 2L)
  check("merge_dt: it carries y's columns across", "w" %in% names(m_inner))
  check("merge_dt: x is left alone", !"w" %in% names(kx))
})

# A suffixed name must not land on a name x already uses: in place that
# overwrites it, in a new table it duplicates it. Finding 3.
test_that("merge_dt refuses a suffix that lands on an existing column", {
  sfx_x <- setkey(data.table(id = 1L, a = 1, a_y = 5), id)
  sfx_y <- setkey(data.table(id = 1L, a = 7), id)
  before <- copy(sfx_x)
  check_error(
    "merge_dt: a suffix that would overwrite an existing column is refused",
    merge_dt(sfx_x, sfx_y, mode = "in_place"),
    class = "daffiz_error_columns"
  )
  check("merge_dt: x is untouched by the refusal", identical(sfx_x, before))
  check_error(
    "merge_dt: and refused in new mode too, where it would duplicate the name",
    merge_dt(sfx_x, sfx_y, mode = "new"),
    class = "daffiz_error_columns"
  )
  check("merge_dt: x is still untouched", identical(sfx_x, before))
  check(
    "merge_dt: another suffix gets it through",
    merge_dt(copy(sfx_x), sfx_y, mode = "new", suffix = "_from_y")$a_from_y == 7
  )
})

test_that("merge_dt with all = TRUE keeps every key", {
  m_outer <- merge_dt(kx_fixture(), ky_fixture(), all = TRUE)
  check("merge_dt: all = TRUE keeps every key", nrow(m_outer) == 4L)
  check("merge_dt: unmatched rows get NA", m_outer[id == "c", is.na(w)])
})

test_that("merge_dt suffixes a clashing name of y", {
  kx <- kx_fixture()
  clash <- setkey(data.table(id = c("a", "b", "c"), v = 7:9), id)
  m_clash <- merge_dt(kx, clash)
  check("merge_dt: a clashing name gets the suffix", "v_y" %in% names(m_clash))
  check("merge_dt: x's own name never moves", "v" %in% names(m_clash))
  check("merge_dt: the suffix is configurable", "v_two" %in% names(merge_dt(kx, clash, suffix = "_two")))
})

test_that("merge_dt in place is a left join into x", {
  ip <- kx_fixture()
  merge_dt(ip, ky_fixture(), mode = "in_place")
  check("merge_dt: in_place adds y's columns by reference", "w" %in% names(ip))
  check("merge_dt: in_place keeps every row of x", nrow(ip) == 3L)
  check("merge_dt: in_place is a left join, so misses are NA", ip[id == "c", is.na(w)])
  check("merge_dt: in_place does not pick up y-only rows", !"d" %in% ip$id)
})

test_that("merge_dt refuses a join that is not one to one, and bad input", {
  # The wording, which points at disambiguate_by_key(), is pinned in
  # test-messages.R.
  err <- expect_error(
    merge_dt(
      setkey(data.table(id = c("a", "a"), v = 1:2), id),
      setkey(data.table(id = c("a", "a"), w = 1:2), id)
    ),
    class = "daffiz_error_keys"
  )
  expect_identical(err$dry_run$est_merge_rows, 4)
  check_error("merge_dt: refuses a data.frame", merge_dt(as.data.frame(kx_fixture()), ky_fixture()), class = "daffiz_error_input")
  # match.arg()'s own error, unclassed.
  expect_error(merge_dt(kx_fixture(), ky_fixture(), mode = "sideways"), class = "daffiz_error_input")
})

test_that("the refusal of a fanout past 2^31 can still be written", {
  big <- 46341L
  bx <- setkey(data.table(id = rep(1L, big)), id)
  err <- expect_error(merge_dt(bx, copy(bx)), class = "daffiz_error_keys")
  expect_match(conditionMessage(err), "46,341 rows would become 2,147,488,281", fixed = TRUE)
})
