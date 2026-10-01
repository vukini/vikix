# 13 · Arrays in functions

In the function that declares it, an array is the array: `sizeof` gives its whole size, and `sizeof marks / sizeof marks[0]` its length. Passed to a function, it becomes a pointer to its first element, and the length is left behind. That's why `strlen` needs a `'\0'` to find the end, and why most functions that take an array take its length too.

<!-- output: ./example -->
```text
sizeof marks = 16, so 4 marks
average = 7.00
```

`sizeof.c` asks the same question inside a function that was passed the array. The `[4]` in `int v[4]` looks like an array, and isn't:

<!-- output: cc sizeof.c -o sizeof 2>&1 | grep -o 'warning: .*'; ./sizeof -->
```text
warning: 'sizeof' on array function parameter 'v' will return size of 'int *' [-Wsizeof-array-argument]
in main: sizeof marks = 16
inside show: sizeof v = 8
```

gcc warns, and the program says 8: the size of a pointer. Code that does `sizeof v / sizeof v[0]` there gets 2, whatever the array's length.

## Your turn

`exercise.c` is `sum`, which works its length out with that same sizeof, and so gets it wrong. Give it the length instead.
