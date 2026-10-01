gcc says it first: `comparison of unsigned expression in '>= 0' is always true`. A `size_t` is never below 0: after 0, `i--` gives the largest size_t, and the loop goes on.
---
And when n is 0, `n - 1` is already the largest size_t: the loop starts far past the end of s.
---
Let i count how many are still to look at, from n down to 1, and look at `s[i - 1]`: `for (size_t i = n; i > 0; i--)`. The test is `i > 0`, which does become false, and an empty s is never read at all.
---
Return the place, not the count: `return (long)(i - 1);`
