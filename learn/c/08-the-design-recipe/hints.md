Start with step 2: say in one sentence what `digits` gives back. "How many decimal digits n has, not counting a minus sign" is enough.
---
Examples first, body after: `assert(digits(0) == 1);`, `assert(digits(-305) == 3);`, and what should `digits(INT_MIN)` be? INT_MIN is -2147483648.
---
A template from the data: count digits by dividing by 10 until nothing is left. `n / 10` drops the last digit.
---
Making n positive first (`if (n < 0) n = -n;`) breaks on INT_MIN: -INT_MIN doesn't fit in an int, and that's undefined behaviour, which the sanitizers catch. In C, `-305 / 10` is `-30`: division rounds towards zero, so you never have to negate.
---
`int count = 1; while (n / 10 != 0) { n /= 10; count++; } return count;`
