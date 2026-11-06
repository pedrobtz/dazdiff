# the drawing of an exact match that dropped a column

    Code
      print(r, unicode = FALSE)
    Output
      +==================================================+
      |                  daffiz report                   |
      +==================================================+
         Identity: id
         Mode:     benchmark: y is tested against x
      
         --- x and y match exactly (2 rows, 1 measure) ---
      
       Columns
       -------
         Compared 2 columns: 1 key, 1 measure.
         Only in y, dropped: loaded_at.

# the drawing of a change in one measure of several

    Code
      print(r, unicode = FALSE)
    Output
      +============================================================================+
      |                               daffiz report                                |
      +============================================================================+
         Identity: id
         Mode:     benchmark: y is tested against x
      
       Columns
       -------
         Compared 4 columns: 1 key, 3 measures.
      
       Rows
       ----
         x rows               y rows
           3     (no change)    3
      
         +=+=+=+=+=+...+=+=+=+=+=+......................+
         | | | | | | = | | | | | |  2 same    (66.67%)  |
         +-+-+-+-+-+...+-+-+-+-+-+......................+-  3 joined
         | | | | | | ! | | | | | |  1 changed (33.33%)  |
         +=+=+=+=+=+...+=+=+=+=+=+......................+
      
       Measures
       --------
         +---------+------------+------------+--------------+----------------------+
         | Measure | Match rate | Max |diff| | Max rel diff | Top changes          |
         +---------+------------+------------+--------------+----------------------+
         | b       |     66.67% |         54 |          0.9 | 6 -> 60 (1x, e.g. 3) |
         +---------+------------+------------+--------------+----------------------+
         2 other measures match on every row found in both tables.

# the drawing of paired rows and a truncating cast

    Code
      print(r, unicode = FALSE)
    Output
      +==================================================================================+
      |                                  daffiz report                                   |
      +==================================================================================+
         Identity: id, n
         Mode:     benchmark: y is tested against x
         Repeated keys were paired in arrival order (key_seq).
      
       Columns
       -------
         Compared 3 columns: 2 keys, 1 measure.
         Truncated by the cast to x's types:
           n: 1 value (1.7 -> 1)
      
       Rows
       ----
         x rows               y rows
           3     (no change)    3
      
         +=+=+=+=+=+...+=+=+=+=+=+......................+
         | | | | | | = | | | | | |  2 same    (66.67%)  |
         +-+-+-+-+-+...+-+-+-+-+-+......................+-  3 joined
         | | | | | | ! | | | | | |  1 changed (33.33%)  |
         +=+=+=+=+=+...+=+=+=+=+=+......................+
      
       Measures
       --------
         +---------+------------+------------+--------------+----------------------------+
         | Measure | Match rate | Max |diff| | Max rel diff | Top changes                |
         +---------+------------+------------+--------------+----------------------------+
         | v       |     66.67% |          1 |         0.25 | 3 -> 4 (1x, e.g. ("b", 3)) |
         +---------+------------+------------+--------------+----------------------------+

# the drawing of a result filtered down to y's own rows

    Code
      print(r, unicode = FALSE)
    Output
      +=============================================================+
      |                        daffiz report                        |
      +=============================================================+
         Identity: id
         Mode:     benchmark: y is tested against x
      
       Columns
       -------
         Compared 2 columns: 1 key, 1 measure.
      
       Rows
       ----
         x rows    y rows
           0         1
      
       Measures
       --------
         Every measure matches on every row found in both tables (1).
      
       Rows only in y
       --------------
         +-----+
         | id  |
         +-----+
         | "d" |
         +-----+

# the drawing

    Code
      print(diff_report(diff_table(x3, y3)), unicode = FALSE)
    Output
      +===============================================================================+
      |                                 daffiz report                                 |
      +===============================================================================+
         Identity: id
         Mode:     benchmark: y is tested against x
      
       Columns
       -------
         Compared 2 columns: 1 key, 1 measure.
      
       Rows
       ----
         x rows               y rows
           3     (no change)    3
      
         +=+=+=+=+=+
         |-|-|-|-|-|                1 only in x (33.33%)
         +-+-+-+-+-+...+=+=+=+=+=+........................+
         | | | | | | = | | | | | |  1 same      (50.00%)  |
         +-+-+-+-+-+...+-+-+-+-+-+........................+-  2 joined
         | | | | | | ! | | | | | |  1 changed   (50.00%)  |
         +=+=+=+=+=+...+-+-+-+-+-+........................+
                       |+|+|+|+|+|  1 only in y (33.33%)
                       +=+=+=+=+=+
      
       Measures
       --------
         +---------+------------+------------+--------------+-------------------------+
         | Measure | Match rate | Max |diff| | Max rel diff | Top changes             |
         +---------+------------+------------+--------------+-------------------------+
         | value   |     50.00% |        0.5 |          0.2 | 2 -> 2.5 (1x, e.g. "b") |
         +---------+------------+------------+--------------+-------------------------+
      
       Rows only in x
       --------------
         +-----+
         | id  |
         +-----+
         | "c" |
         +-----+
      
       Rows only in y
       --------------
         +-----+
         | id  |
         +-----+
         | "d" |
         +-----+

---

    Code
      print(diff_report(diff_table(x3, x3)), unicode = FALSE)
    Output
      +==================================================+
      |                  daffiz report                   |
      +==================================================+
         Identity: id
         Mode:     benchmark: y is tested against x
      
         --- x and y match exactly (3 rows, 1 measure) ---

---

    Code
      print(diff_report(d, x_name = "bench", y_name = "tested", top_k = 1), unicode = FALSE)
    Output
      +====================================================================================+
      |                                   daffiz report                                    |
      +====================================================================================+
         Identity: id, region
         Mode:     benchmark: tested is tested against bench
      
       Columns
       -------
         Compared 4 columns: 2 keys, 2 measures.
         Only in tested, dropped: loaded.
         In neither the identity nor the measures: note.
      
       Rows
       ----
         bench rows             tested rows
             6       (+16.67%)       7
      
         +=+=+=+=+=+
         |-|-|-|-|-|                1 only in bench  (16.67%)
         +-+-+-+-+-+...+=+=+=+=+=+.............................+
         | | | | | | = | | | | | |  3 same           (60.00%)  |
         +-+-+-+-+-+...+-+-+-+-+-+.............................+-  5 joined
         | | | | | | ! | | | | | |  2 changed        (40.00%)  |
         +=+=+=+=+=+...+-+-+-+-+-+.............................+
                       |+|+|+|+|+|  2 only in tested (28.57%)
                       +=+=+=+=+=+
      
       Measures
       --------
         +---------+------------+------------+--------------+------------------------------+
         | Measure | Match rate | Max |diff| | Max rel diff | Top changes                  |
         +---------+------------+------------+--------------+------------------------------+
         | amount  |     60.00% |          1 |      0.04762 | 20 -> 21 (1x, e.g. (2, "s")) |
         |         |            |            |              | (...and 1 other)             |
         +---------+------------+------------+--------------+------------------------------+
         | rate    |     80.00% |        0.5 |          0.2 | 2 -> 2.5 (1x, e.g. (4, "s")) |
         +---------+------------+------------+--------------+------------------------------+
      
       Rows only in bench
       ------------------
         +----+--------+
         | id | region |
         +----+--------+
         | 6  | "w"    |
         +----+--------+
      
       Rows only in tested
       -------------------
         +----+--------+
         | id | region |
         +----+--------+
         | 7  | "w"    |
         | 8  | "w"    |
         +----+--------+

# the drawing, in box-drawing characters

    Code
      print(diff_report(diff_table(x3, y3)), unicode = TRUE)
    Output
      ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
      ┃                                 daffiz report                                 ┃
      ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
         Identity: id
         Mode:     benchmark: y is tested against x
      
       Columns
       ▔▔▔▔▔▔▔
         Compared 2 columns: 1 key, 1 measure.
      
       Rows
       ▔▔▔▔
         x rows               y rows
           3     (no change)    3
      
         ┏━┯━┯━┯━┯━┓
         ┃-│-│-│-│-┃                1 only in x (33.33%)
         ┠─┼─┼─┼─┼─┨╌╌╌┏━┯━┯━┯━┯━┓╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
         ┃ │ │ │ │ ┃ = ┃ │ │ │ │ ┃  1 same      (50.00%)  │
         ┠─┼─┼─┼─┼─┨╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌├╴  2 joined
         ┃ │ │ │ │ ┃ ≠ ┃ │ │ │ │ ┃  1 changed   (50.00%)  │
         ┗━┷━┷━┷━┷━┛╌╌╌┠─┼─┼─┼─┼─┨╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯
                       ┃+│+│+│+│+┃  1 only in y (33.33%)
                       ┗━┷━┷━┷━┷━┛
      
       Measures
       ▔▔▔▔▔▔▔▔
         ┌─────────┬────────────┬────────────┬──────────────┬─────────────────────────┐
         │ Measure │ Match rate │ Max |diff| │ Max rel diff │ Top changes             │
         ├─────────┼────────────┼────────────┼──────────────┼─────────────────────────┤
         │ value   │     50.00% │        0.5 │          0.2 │ 2 -> 2.5 (1x, e.g. "b") │
         └─────────┴────────────┴────────────┴──────────────┴─────────────────────────┘
      
       Rows only in x
       ▔▔▔▔▔▔▔▔▔▔▔▔▔▔
         ┌─────┐
         │ id  │
         ├─────┤
         │ "c" │
         └─────┘
      
       Rows only in y
       ▔▔▔▔▔▔▔▔▔▔▔▔▔▔
         ┌─────┐
         │ id  │
         ├─────┤
         │ "d" │
         └─────┘

