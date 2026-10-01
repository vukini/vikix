# 06 · Signed and unsigned

Sizes and lengths in C are `size_t`, which is unsigned: `strlen`, `sizeof`, array indexes in the library. Mix one with an `int`, and C converts the `int` to unsigned first. A negative number becomes enormous, and an unsigned subtraction that "goes below zero" wraps round to the top.

<!-- output: ./example -->
```text
(size_t)-1 = 18446744073709551615
len - 3 = 18446744073709551615
len - 3 > 0 is 1
(int)len - 3 > 0 is 0
```

`len - 3` isn't -1: it wrapped round to the largest `size_t`, the same number as `(size_t)-1`. So `len - 3 > 0` is true, and gcc says nothing: nothing was converted, the subtraction was unsigned all along. Turned into an `int` first, the arithmetic is signed, and comes out as you'd expect.

When gcc *can* see a mix, `-Wextra` speaks up:

<!-- output: printf '#include <stdio.h>\nint main(void) { printf("%%d\\n", -1 < 1u); return 0; }\n' > cmp.c && cc -Wall -Wextra cmp.c -o cmp 2>&1 | grep -o 'warning: .*'; ./cmp -->
```text
warning: comparison of integer expressions of different signedness: 'int' and 'unsigned int' [-Wsign-compare]
0
```

-1 isn't less than 1u: as unsigned, -1 is the largest `unsigned int`.

## Your turn

`exercise.c` is `last_index`, which counts down from the end of an array. As it comes, gcc already has a warning about the loop, and an empty array is the other trap.
