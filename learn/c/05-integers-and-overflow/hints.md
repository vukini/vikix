Try it on the numbers that break it: `midpoint(INT_MAX, INT_MAX - 2)`. `a + b` is bigger than INT_MAX before `/ 2` ever happens, and in an `int` that's undefined.
---
Do the adding in a type that's big enough: a `long long` holds the sum of any two ints. Convert one of them first, `(long long)a + b`, so the whole sum is done in `long long`.
---
Halved, the sum fits in an int again. `/` in a `long long` rounds towards zero, as the examples want: `return (int)(((long long)a + b) / 2);`
---
`a + (b - a) / 2` is the other famous fix, and it overflows too when a and b have different signs: `b - a` for INT_MAX and INT_MIN. The check tries that pair.
