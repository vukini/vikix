# 02 · What the warnings catch

A C compiler accepts a great deal that is wrong. The warnings are where it tells you, and which ones you see depends on what you ask for. `warnings.c` has four mistakes; here is what each set of flags finds.

```sh
cc -c warnings.c
```

<!-- output: echo "$(cc -c warnings.c 2>&1 | grep -c warning) warnings" -->
```text
0 warnings
```

None at all. Without flags, gcc warns about very little.

```sh
cc -Wall -c warnings.c
```

<!-- output: cc -Wall -c warnings.c 2>&1 | grep -o 'warning: .*' -->
```text
warning: unused variable 'unused' [-Wunused-variable]
warning: control reaches end of non-void function [-Wreturn-type]
```

`-Wall` isn't all: it's a set of warnings that are nearly always right. A function that can end without returning its value is one; the caller gets whatever was in the register.

```sh
cc -Wall -Wextra -c warnings.c
```

<!-- output: cc -Wall -Wextra -c warnings.c 2>&1 | grep -o 'warning: .*' -->
```text
warning: comparison of integer expressions of different signedness: 'unsigned int' and 'int' [-Wsign-compare]
warning: unused variable 'unused' [-Wunused-variable]
warning: control reaches end of non-void function [-Wreturn-type]
```

`-Wextra` adds more. Comparing an `unsigned` with an `int` converts the `int`, so a negative one would count as huge.

```sh
cc -Wall -Wextra -pedantic -c warnings.c
```

<!-- output: cc -Wall -Wextra -pedantic -c warnings.c 2>&1 | grep -o 'warning: .*' -->
```text
warning: comparison of integer expressions of different signedness: 'unsigned int' and 'int' [-Wsign-compare]
warning: overflow in conversion from 'int' to 'signed char' changes value from '200' to '-56' [-Woverflow]
warning: unused variable 'unused' [-Wunused-variable]
warning: control reaches end of non-void function [-Wreturn-type]
```

Only `-pedantic` notices that 200 doesn't fit in a `signed char`, which goes to 127. And the program ran all along, quietly wrong:

<!-- output: cc warnings.c -o warnings 2>/dev/null && ./warnings -->
```text
average 6, offset -56
```

`example.c` is the same program with each one fixed; it compiles without a word under all four flags.

## Some warnings need -O2

gcc finds a variable used before it's set by following the program the way the optimiser does. Without `-O2`, that analysis isn't done, and the warning doesn't come.

## Your turn

`exercise.c` has three bugs and a variable that does nothing; the warnings point at each one. The checks compile it the way every lesson's checks do, `-std=c17 -Wall -Wextra -pedantic`, with each warning an error, and then once more with `-O2`.
