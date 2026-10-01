# 05 · Integers and overflow

C's integer types have sizes the standard leaves partly open; on this machine, they are:

<!-- output: ./example -->
```text
bytes: char 1, short 2, int 4, long 8, long long 8
int goes from -2147483648 to 2147483647
unsigned int goes from 0 to 4294967295
UINT_MAX + 1 = 0
INT_MAX + 1, as a long long = 2147483648
```

Past the end, the two kinds behave differently. An **unsigned** type wraps round, by definition: `UINT_MAX + 1` is 0, everywhere, always. A **signed** type has no defined behaviour past its end at all. `overflow.c` adds 1 to `INT_MAX`:

<!-- output: cc overflow.c -o overflow && ./overflow -->
```text
INT_MAX + 1 = -2147483648
```

That looks like a wrap too, but nothing promises it: the compiler is allowed to assume a signed overflow never happens, and at `-O2` code is shaped on that assumption. UBSan, the undefined-behaviour sanitizer, checks while it runs:

<!-- output: cc -fsanitize=undefined overflow.c -o overflow && ./overflow 2>&1 | grep -o 'runtime error: .*' -->
```text
runtime error: signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'
```

To get past the end of an `int`, widen first: `(long long)INT_MAX + 1` converts before it adds, and a `long long` has room.

## Your turn

`exercise.c` is `midpoint(a, b)`, halfway between two ints. `(a + b) / 2` is right for small numbers, and the check tries big ones, under UBSan.
