# 07 · Bits: a project

Every value is bits, and C lets you work on them directly: flags packed into one number, hardware registers, file permissions (`0755` is three groups of three bits). `example.c` shows each operator on one byte, printed in binary:

<!-- output: ./example -->
```text
01011010  a
00001111  b
00001010  a & b: 1 where both are
01011111  a | b: 1 where either is
01010101  a ^ b: 1 where they differ
10100101  ~a: every bit turned over
10110100  a << 1: one place up (the top bit falls off)
00000101  a >> 4: four places down
01011011  a | (1u << 0): bit 0 set
01010010  a & ~(1u << 3): bit 3 cleared
```

- `&` keeps a bit where both have one: with a mask, it picks bits out.
- `|` sets a bit where either has one: it turns bits on.
- `^` sets a bit where they differ: it flips the bits of the mask.
- `~` turns every bit over; `&` with `~mask` turns the mask's bits off.
- `<<` and `>>` move bits along: `x >> n & 1` is bit n of x, and `1u << n` is a mask with only bit n.

Shift `unsigned` values: shifting a 1 into an `int`'s top bit is undefined, and UBSan says so.

## The project

`exercise.c` is `printbits`: `./exercise 90` prints `90 = 01011010 (4 ones)`. It needs five small functions, each with its examples: `bits8`, `count_ones`, `set_bit`, `clear_bit` and `test_bit`. The check tries every byte and every bit position.
