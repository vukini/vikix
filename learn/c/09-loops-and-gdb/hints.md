Build it for gdb, then stop inside longest_run each time round the loop:
`cc -g -o exercise exercise.c` and then
`gdb -q -batch -ex 'break 34' -ex run -ex 'info locals' -ex continue -ex 'info locals' ./exercise`
(34 is the line with `if (v[i] == v[i - 1])`; `info locals` shows i, run and best each time).
---
Watch i: the loop goes on while `i <= n`. With n values, the last one is `v[n - 1]`; what is `v[n]`? The check's AddressSanitizer says the same.
---
Watch run on {1, 2, 1, 2}: it never goes down. When a value differs from the one before, a new run starts, of length 1.
---
`for (int i = 1; i < n; i++)`, and `else run = 1;` after `run++;`.
