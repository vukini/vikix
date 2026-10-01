A `void *` can't be walked or read: say what's there. `unsigned char *d = dest;` and `const unsigned char *s = src;` let you go byte by byte: `while (n-- > 0) *d++ = *s++;`. Return the original `dest`.
---
my_memset is the same walk, writing `(unsigned char)c` each time. `c` is an int only so the function can take any value; it's the low 8 bits that are written.
---
my_strcmp as it comes never stops when the strings are equal: at the two '\0's, `*a == *b` still holds, and it walks on past the end. Stop at the end of a as well: `while (*a != '\0' && *a == *b)`.
---
And it compares `char`s, which are signed here: 0xE9 is -23, so "\xe9" would come before "e". Compare bytes as `unsigned char`, as strcmp does: walk `const unsigned char *` copies of a and b.
