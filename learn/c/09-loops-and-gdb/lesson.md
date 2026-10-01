# 09 · Loops, and finding a bug with gdb

A loop is a start, a test, a step and a body, and most loop bugs are at the edges: one round too many, one too few, a variable not reset. Printing helps; a debugger lets you stop the program and look.

`gdb` runs a program built with `-g`, which keeps the line numbers and variable names. In batch mode, `-ex` gives it commands one after another, the way you'd type them at its prompt. `example.c` adds up squares; stop at the start of `sum_squares`, then on line 10, the loop's body, when `i` is 3:

<!-- output: cc -g -o example example.c && gdb -q -batch -ex 'break sum_squares' -ex run -ex 'info args' -ex 'break 10 if i == 3' -ex continue -ex 'info locals' -ex 'print i * i' ./example 2>&1 | grep -vE '^\[|libthread|debuginfod|Downloading|^$|Breakpoint [0-9]+ at ' -->
```text
Breakpoint 1, sum_squares (n=4) at example.c:8
8	    int total = 0;
n = 4
Breakpoint 2, sum_squares (n=4) at example.c:10
10	        total += i * i;
i = 3
total = 5
$1 = 9
```

- `break sum_squares` stops when the function starts; `break 10 if i == 3` stops on line 10, but only when the condition holds.
- `run` starts the program, and `continue` goes on to the next stop.
- `info args` and `info locals` show the variables there; `print` works out any C expression.

When i is 3, total is 5 (1 + 4), and `i * i` is about to add 9: the loop is doing what it should. Interactively, `gdb ./example` gives a prompt for the same commands, plus `next` (a line) and `step` (into a function).

## Your turn

`exercise.c` is `longest_run`, the longest run of equal values in a row, and it has two bugs: one an edge of the loop, one a variable not reset. Find them by stopping in the loop and watching `i` and `run`.
