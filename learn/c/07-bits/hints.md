bits8: the highest bit goes first. For place i of out (0 to 7), the bit is `7 - i`: shift it down to the bottom, `x >> (7 - i)`, and `& 1` keeps only it. Then `out[8] = '\0'`.
---
count_ones: look at the lowest bit, `x & 1`, add it, and shift x down one, `x >>= 1`, until x is 0.
---
set_bit: OR with a mask that has only bit n: `x | (1u << n)`. Use `1u`: `1 << 31` shifts a 1 into an int's sign bit, which is undefined, and the check tries bit 31.
---
clear_bit: AND with the mask turned over, `x & ~(1u << n)`. test_bit: `(x >> n) & 1`.
