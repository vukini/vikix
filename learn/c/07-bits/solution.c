/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). printbits, and functions on bits.
 *
 * Bits are counted from 0, the lowest. Each function's examples say what
 * it does. The program itself prints its argument in binary:
 *
 *     ./exercise 90       prints  90 = 01011010 (4 ones)
 *
 * The check tries every byte value (0 to 255) and every bit position (0
 * to 31). Then delete the NOT DONE line to go on.
 */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* bits8: x as 8 binary digits and a '\0', highest bit first, into out. */
void bits8(unsigned char x, char out[9]);
/* count_ones: how many bits of x are 1. */
int count_ones(unsigned x);
/* set_bit, clear_bit: x with bit n made 1, or 0 (n from 0 to 31). */
unsigned set_bit(unsigned x, int n);
unsigned clear_bit(unsigned x, int n);
/* test_bit: 1 if bit n of x is 1, else 0. */
int test_bit(unsigned x, int n);

static void examples(void)
{
    char out[9];
    bits8(90, out);
    assert(strcmp(out, "01011010") == 0);
    assert(count_ones(90) == 4);
    assert(count_ones(0xFFFFFFFFu) == 32);
    assert(set_bit(0, 3) == 8);
    assert(clear_bit(15, 0) == 14);
    assert(test_bit(8, 3) == 1 && test_bit(8, 2) == 0);
}

void bits8(unsigned char x, char out[9])
{
    for (int i = 0; i < 8; i++)
        out[i] = (x >> (7 - i)) & 1 ? '1' : '0';
    out[8] = '\0';
}

int count_ones(unsigned x)
{
    int n = 0;
    for (; x != 0; x >>= 1)
        n += x & 1;
    return n;
}

unsigned set_bit(unsigned x, int n)
{
    return x | (1u << n);       /* 1u: a 1 << 31 in an int would overflow */
}

unsigned clear_bit(unsigned x, int n)
{
    return x & ~(1u << n);
}

int test_bit(unsigned x, int n)
{
    return (x >> n) & 1;
}

int main(int argc, char **argv)
{
    examples();
    unsigned char x = argc > 1 ? (unsigned char)atoi(argv[1]) : 90;
    char out[9];
    bits8(x, out);
    printf("%u = %s (%d ones)\n", x, out, count_ones(x));
    return 0;
}
