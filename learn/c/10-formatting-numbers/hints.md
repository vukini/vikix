Steps first: the purpose in one sentence, then the examples you're missing. What should `with_commas(LLONG_MIN, out, sizeof out)` give? LLONG_MIN is -9223372036854775808.
---
Build the text from the right, as example.c's to_decimal does: the last digit is `u % 10`, then `u /= 10`. Before every third digit (but not the first), put a ','.
---
For a negative n, work with its size and add the '-' at the end. `-n` overflows for LLONG_MIN, but in unsigned arithmetic it doesn't: `unsigned long long u = n < 0 ? 0 - (unsigned long long)n : n;`
---
Build into a buffer of your own first (32 chars is plenty), then check it fits: the text and its '\0' need `len + 1 <= size`. If not, `out[0] = '\0'` (when size > 0) and return -1. Otherwise copy it into out, backwards.
