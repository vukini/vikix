Compile it the way the check does and read the warnings one by one: `cc -std=c17 -Wall -Wextra -pedantic -c exercise.c`. The bracket at the end of each names the flag that found it.
---
`-Wformat`: `total` is a `long`, and `%d` reads an `int`. The format for a `long` is `%ld`. On this machine a `long` is 8 bytes and an `int` 4, so `%d` would print the wrong number.
---
`-Wsign-compare`: `strlen` gives a `size_t`, which is unsigned. Comparing it with an `int` converts the `int`, and a negative one becomes huge. Make `best` a `size_t` too, and return `(int)best`.
---
When those are gone, the check compiles with `-O2` too, and gcc finds one more: `best` is used before anything is put in it. Without `-O2` gcc doesn't do the analysis that sees it. `size_t best = 0;`
---
`spare` is never used: delete it.
