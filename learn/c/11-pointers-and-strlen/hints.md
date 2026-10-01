Look at `count_char` in example.c: `for (const char *p = s; *p != '\0'; p++)` walks a pointer along a string until the `'\0'`.
---
You don't need a counter. Walk `p` to the `'\0'`, and the length is how far it went: `p - s`, the distance between two pointers into the same string.
---
`p - s` is a `ptrdiff_t`; return it as a `size_t`: `return (size_t)(p - s);`
---
`const char *p = s; while (*p != '\0') p++; return (size_t)(p - s);`
