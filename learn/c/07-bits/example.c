/* example.c: the bit operators, on one byte, printed in binary. */
#include <stdio.h>

/* show: x as 8 binary digits, then a label. */
static void show(unsigned char x, const char *label)
{
    for (int bit = 7; bit >= 0; bit--)
        putchar((x >> bit) & 1 ? '1' : '0');   /* shift the bit down, keep only it */
    printf("  %s\n", label);
}

int main(void)
{
    unsigned char a = 0x5A, b = 0x0F;      /* 01011010 and 00001111 */
    show(a, "a");
    show(b, "b");
    show(a & b, "a & b: 1 where both are");
    show(a | b, "a | b: 1 where either is");
    show(a ^ b, "a ^ b: 1 where they differ");
    show((unsigned char)~a, "~a: every bit turned over");
    show((unsigned char)(a << 1), "a << 1: one place up (the top bit falls off)");
    show(a >> 4, "a >> 4: four places down");
    show(a | (1u << 0), "a | (1u << 0): bit 0 set");
    show(a & ~(1u << 3), "a & ~(1u << 3): bit 3 cleared");
    return 0;
}
