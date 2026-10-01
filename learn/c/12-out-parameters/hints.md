In swap, `a = b` changes which int the parameter a points to, inside swap only. The caller's ints are `*a` and `*b`: `*a = *b;`.
---
gcc says min and max are "set but not used": `min = &lo` points swap's own copy of the pointer somewhere else, and the caller never sees it. Put the answer where min points: `*min = lo;`.
---
`int lo = 0` is wrong for {12, 5, 19, 8}: nothing is below 0, so lo stays 0, which isn't in the array. Start from a value that's there, `v[0]`, and look from `i = 1`.
---
With n == 0 there is no v[0]: return 0 first, before touching anything.
