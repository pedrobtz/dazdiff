# expect_table_equal shows at most max_rows of the records that differ

    Code
      expect_table_equal(actual, expected, max_rows = 2)
    Condition
      Error:
      ! `actual` does not match `expected`: 4 of 5 records differ.
      
         metric     n n_same n_changed n_only_x n_only_y max_abs_diff mean_abs_diff
         <char> <int>  <int>     <int>    <int>    <int>        <num>         <num>
      1: AMOUNT     5      1         4        0        0            1           0.8
              rmse max_rel_diff
             <num>        <num>
      1: 0.8944272   0.09090909
      
      First 2 records that differ:
      Key: <ID, metric>
            ID metric row_id_x row_id_y value_x value_y  diff abs_diff   rel_diff
         <int> <char>    <int>    <int>   <num>   <num> <num>    <num>      <num>
      1:     1 AMOUNT        1        1      10      11     1        1 0.09090909
      2:     2 AMOUNT        2        2      20      21     1        1 0.04761905
          status
          <fctr>
      1: changed
      2: changed

---

    Code
      expect_table_equal(actual, expected, max_rows = 0)
    Condition
      Error:
      ! `actual` does not match `expected`: 4 of 5 records differ.
      
         metric     n n_same n_changed n_only_x n_only_y max_abs_diff mean_abs_diff
         <char> <int>  <int>     <int>    <int>    <int>        <num>         <num>
      1: AMOUNT     5      1         4        0        0            1           0.8
              rmse max_rel_diff
             <num>        <num>
      1: 0.8944272   0.09090909

# expect_table_equal fails with a summary and the records that differ

    Code
      expect_table_equal(actual, expected)
    Condition
      Error:
      ! `actual` does not match `expected`: 1 of 3 records differ.
      
         metric     n n_same n_changed n_only_x n_only_y max_abs_diff mean_abs_diff
         <char> <int>  <int>     <int>    <int>    <int>        <num>         <num>
      1: AMOUNT     3      2         1        0        0            1     0.3333333
              rmse max_rel_diff
             <num>        <num>
      1: 0.5773503   0.04761905
      
      Key: <ID, metric>
            ID metric row_id_x row_id_y value_x value_y  diff abs_diff   rel_diff
         <int> <char>    <int>    <int>   <num>   <num> <num>    <num>      <num>
      1:     2 AMOUNT        2        2      20      21     1        1 0.04761905
          status
          <fctr>
      1: changed

