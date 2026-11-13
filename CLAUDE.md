# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

`dazdiff` is a small R package around one function, `diff_table()`, which
compares two tables value by value, plus a few helpers (`diff_summary()`,
`diff_report()`, `diff_explain()`, `expect_table_equal()`, `compare_columns()`,
`normalize_dt()`, `cast_rules()`). `data.table` is the engine and the only
hard dependency besides `utils`. Keep the public surface small; new features
go through `.agents/roadmap.md` first.

Version 0.1.0 was rebuilt around the core in `.agents/compare.R`. Its planning
documents live in `.agents/`, and they outrank this file:

- `plan.md`: what 0.1.0 is;
- `core-review.md`: the findings (F1–F8, D-a…D-h) the rebuild fixed;
- `roadmap.md`: the features of the earlier draft that were dropped, where
  their code lives, and how to re-add them;
- `review.md`: the pre-release review.

The draft is tagged `draft-0.1.0`; read any of its files with
`git show draft-0.1.0:R/<file>`.

Comments in `R/` carry reasoning that is not recoverable from the code. Read
them before rewriting a function.

The package was renamed from `daffiz` to `dazdiff` (#46, #59).

## Current state

Verified 2026-11-11. `DESCRIPTION` is at 0.1.0 and the package is not on CRAN
yet (crandb has no record, and there is no `CRAN-SUBMISSION` file). Every
sub-issue of the `v0.1.0` issue is closed (14 of 14).

Do not claim the package "checks cleanly" without re-running
`R CMD check --as-cran` on a fresh tarball; that claim was wrong once already.
Deviation from the shared definition of done: besides "New submission", a
local check may show "unable to verify current time" when the machine cannot
reach a time server. That NOTE is expected locally; it is not a package
defect.

## Versions and dependents

The current version's parent issue is `#4` for `v0.1.0`. Sibling packages
that depend on this one before CRAN does: none yet. RFC 0047 (`zufaode`, not
started) plans to take it in `Suggests` for `expect_table_equal()`.

## Commands

Beyond the shared commands:

```sh
Rscript -e 'devtools::test(filter = "diff-table")'   # test-diff-table*.R
Rscript -e 'testthat::test_file("tests/testthat/test-cast.R")'
R CMD build . && R CMD check --as-cran dazdiff_*.tar.gz   # the fresh-tarball check
```

`benchmarks/` (`run-benchmarks.R`, `benchmark-worker.R`) still measures the
draft's pipeline, not 0.1.0's.

## Architecture

`diff_table()` runs a 13-step pipeline, numbered in its body. Each helper it
calls lives in its own file and is tested on its own:

- `R/diff-table.R`: `diff_table()`: arguments, names, columns per mode, roles,
  types (of the compared columns only), index, duplicates, alignment, melt,
  merge, classification.
- `R/names.R`: `canonical_names()`, `name_map()`, `check_names()`,
  `shallow_dt()`.
- `R/types.R`: `col_type()`, the only type vocabulary; `CAST_RULES`;
  `cast_rules()`.
- `R/cast.R`: `cast_value()`, `cast_dt()` (truncation record and message),
  `normalize_dt()`.
- `R/columns.R`: `summarize_dt()`, `compare_columns()`.
- `R/melt.R`: `select_measures()`, `index_dt()` (row numbers and key),
  `melt_dt()`.
- `R/keys.R`: `unique_by_key()`, `disambiguate_by_key()`, `aggregate_by_key()`.
- `R/merge.R`: `merge_dry_run()` (index-only, exact), `merge_dt()` (one-to-one
  only), `disjoint_columns()` (the key columns named when nothing aligns).
- `R/summary.R`: `diff_summary()`, `is_finite_pair()`, `scaled_rmse()`.
- `R/explain.R`: `diff_explain()`: which key values split the result into
  same and not same.
- `R/report.R`: `diff_report()` and its `format()`/`print()` methods: the text
  report.
- `R/expect.R`: `expect_table_equal()`.
- `R/conditions.R`: `dazdiff_abort()`, `dazdiff_warn()`, `dazdiff_inform()`,
  `fmt_names()`.

Express comparisons as `data.table` joins and grouped operations; avoid
row-wise R loops.

Conditions carry a `dazdiff_*` class. An *error* means the question cannot be
answered; a *warning* means the answer may be wrong; a *message* reports an
expected consequence of the settings. Messages name columns in the caller's
own spelling (`name_map()$label`).

## Invariants that are easy to break

Each is covered by a test.

- **User column names are normalized to upper-case letters, digits and `_`;
  every internal column contains a lowercase ASCII letter.** ASCII is
  upper-cased by table (`chartr()`), so no normalized name holds one in any
  locale, Turkish included; non-ASCII letters are kept, since erasing them
  paired `Größe` with `Grüße` across tables. That is what makes a collision
  between the two impossible (`test-names.R` asserts it for every internal
  name). A new internal column name must contain a lowercase letter. Names
  that normalize to nothing, or to the same thing within one table, are an
  error for the caller to fix, never suffixed or guessed.
- **The caller's tables are never modified.** `shallow_dt()` shares the
  caller's column vectors, so later steps may *replace* a column
  (`set(j = , value = )` swaps a pointer) but never write into one.
  `index_dt()` copies the columns it keeps, because `setkeyv()` reorders rows
  in place, writing into the vectors.
- **Benchmark mode drops `y`'s extra columns before anything else.** The
  core's final `setnames(..., "_x")` relabels every column carried from `y`,
  so a `y`-only column that reached the merge came out named as `x`'s.
- **Truncating casts are allowed by default, and announced by a message, not
  a warning.** The benchmark's types are the truth: Spark, ADLS and Delta turn
  a locally built double into an integer, and the comparison has to follow.
  A warning would fail `expect_no_warning()` pipelines on this expected path.
  `truncate = FALSE` refuses the cast instead.
- **Duplicates are checked and numbered on the wide table, before the melt.**
  The answer is the same as on the melted table, the work is smaller by the
  number of measures, and `key_seq` is the same for every measure of a row.
  The pairing warning fires only when there are measures: without them the
  paired rows are identical in every compared column. `expect_table_equal()`
  relies on exactly that, turning the warning into an error.
- **Pairing is by arrival order, never by value.** Sorting by value pairs rows
  so as to minimise differences and can pass tables that disagree; arrival
  order can only produce false failures.
- **A comparison that aligns nothing is refused before the melt.** Every row
  would be `only_x`/`only_y`, which almost always means a wrong `by` or a
  key-format skew, and it is the case that builds the largest table. Two
  empty tables are exempt.
- **Membership comes from `row_id` or `n_rows`, never from the value.** An NA
  value says nothing about whether the row was there.
- **Equality before tolerance.** `Inf - Inf` is NaN, so a tolerance test alone
  calls two identical infinities a change.
- **The tolerances apply to finite pairs only.** `rel_tol` times an infinite
  magnitude is infinite, so without the guard 1 and `Inf` would be `same`.
  `rel_diff` is relative to the larger magnitude (symmetric in equal mode),
  scaled before subtracting so `-1e308` vs `1e308` gives 2, not `Inf`.
- **`nan_is_na` must act in three places**: value cells, the `%a` encoding of
  `"aggregate"`, and double key columns. data.table joins and groups NA and
  NaN as different keys (verified), so skipping the keys splits a row into
  `only_x` + `only_y`.
- **Every zero in a double key is written as `+0`.** A join treats `-0` and
  `0` as one key but keyed grouping keeps them apart, so a key holding both
  slipped past the duplicate check and paired one row twice: a silent false
  pass in the rows shape. `canonical_missing()` does it, and skips
  `integer64`, whose `NA` has the bit pattern of `-0`.
- **Roles are decided before casting, and only compared columns are cast.**
  Roles depend on `x`'s types, which a cast never changes; casting first let
  a column the call ignores refuse the comparison or report a truncation.
- **The `%a` multiset encoding sorts the encoded strings, in radix (C
  locale) order, after `+ 0`.** `sort()` leaves NA and NaN in arrival order
  among themselves, and `%a` writes `-0` and `0` differently.
- **Magnitude statistics filter on the source values, not on `diff`.** Two
  finite values can differ by more than the largest double; filtering the
  difference drops that value and reports the largest difference as 0.
  `scaled_rmse()` keeps squaring from overflowing.
- **Counts that can pass 2^31 are doubles, and are never formatted with
  `%d`.** `sprintf("%d", 3e9)` is an error, so the message for exactly the
  fanout worth refusing would fail to build.
- **A number cast to text follows the benchmark's decimals, read off the
  whole column.** Every distinct value of `x` must be plain decimal text
  with one number of decimals, or nothing is inferred: choosing between
  `"1.0"` and `"1.00"` would be a guess. A sample would miss the one odd
  value. A value is reformatted only when the text reads back exactly, so
  1.25 never becomes `"1.3"` and joins `x`'s 1.3. What still matches only by
  value is `dazdiff_warning_cast_format`.
- **Text dates before the year 1000 are refused, by reading the year off the
  parsed date.** The format-back round trip alone is platform-dependent:
  glibc writes year 24 as `"24"` under `%Y` (macOS writes `"0024"`), so
  `"24-01-01"` passed on Linux only. CI caught it; macOS cannot reproduce it.
- **`col_type()` is the only type vocabulary.** A second one (`class()[1]`)
  made IDate and integer64 one type to one function and another to the next.
- **A table is well-formed when it has at least one key column; it may have
  no measures.** With no key, the error offers `row_key`, which adds a
  lowercase `row_number` key: the position, or the rank after sorting by
  every compared column. `"sorted"` sorts in radix (C locale) order with NaN
  as NA, so both tables sort alike in any session. Compared exactly it can
  only pair badly, never pass different rows.
- **Measure keywords are lowercase; normalized names never are.** So
  `measures = "numeric"` can never mean a column.
- **`NORMALIZE_TO` has no POSIXct default.** Turning a stamp into a Date
  drops the time and can make two keys one; the caller chooses.

## Testing

The tests in `test-types.R`, `test-cast.R`, `test-columns.R`, `test-melt.R`,
`test-keys.R`, `test-merge.R`, `test-diff-table.R` and
`test-diff-table-cases.R` were ported from `.agents/test.R` and
`.agents/test-cases.R`. They use the `check()` helpers in `helper-check.R`,
the scratch suites' checks reported through testthat. New tests are ordinary
testthat (`test-diff-table-modes.R`, `test-names.R`, `test-summary.R`,
`test-expect.R`, `test-explain.R`, `test-report.R`, whose drawings are snapshots in
`_snaps/report.md`).

Shared fixtures are functions in `helper-fixtures.R` that build a fresh table
each call; `helper-fake.R` generates fake tables from a column layout
(`FAKE_COLS`). Mocks go through `testthat::local_mocked_bindings()`, and
collation through `withr::local_*()` like the seed and time zone.

Error paths are asserted by condition class (`expect_error(class = )`,
`check_error(label, expr, class)`) and the fields a condition carries. The
wording of every `dazdiff_abort()`, `dazdiff_warn()` and `dazdiff_inform()`
site is pinned once in `test-messages.R` (`_snaps/messages.md`); a new site
needs a snapshot there.

## Continuous integration

- `R-CMD-check.yaml` calls r-actions' `r-cmd-check.yml@v1`.
- `coverage.yml` calls r-actions' `coverage.yml`, pinned to a commit
  (`v1.21.0`).
- `pkgdown.yaml` is the package's own: it builds the site and deploys it to
  GitHub Pages. `docs/` is the local pkgdown build and is git-ignored.

`docs/`, `.claude/`, `.agents/`, `benchmarks/`, `inst/WORDLIST` and
`CLAUDE.md` are listed in `.Rbuildignore`. pkgdown does not read
`.Rbuildignore`: it renders every top-level `.md` file other than the README,
licence, NEWS and `cran-comments.md`, so this file reaches the site as
`CLAUDE.html` unless the build excludes it. That is why it used to live in
`.claude/`.
