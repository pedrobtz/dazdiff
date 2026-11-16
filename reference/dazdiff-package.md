# dazdiff: Value-by-Value Comparison of Two Tables

Compares two tables value by value. A candidate table can be checked
against a benchmark whose column types are taken as the truth, with the
candidate's columns cast to those types first, or two tables can be
checked for equality as peers. Rows are aligned on their identity
columns, numeric measures are compared within an optional tolerance, and
the result is a long 'data.table' with one row per compared value that
traces back to the source rows of both inputs.

## See also

Useful links:

- <https://github.com/pedrobtz/dazdiff>

- <https://pedrobtz.github.io/dazdiff/>

- Report bugs at <https://github.com/pedrobtz/dazdiff/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]
