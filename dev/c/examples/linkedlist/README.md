# linkedlist (C)

What C is known for: you manage memory yourself. A linked list of heap
nodes, reversed in place by turning its pointers round, then freed.

    make run
    make check      # valgrind: does every malloc have its free?

Try: delete the `free_list(list);` line and run `make check` again;
step through `reverse` in gdb (`gdb ./list`, then `break reverse`, `run`,
`next`, `print *list`); add a function that removes one value.
Docs: `man 3 malloc`, `info gdb`, `man valgrind`.
