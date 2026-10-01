/* example.c: a function can only change the caller's variables if it's
 * given their addresses. C passes copies; a pointer is a copy too, but a
 * copy of an address, and *p reaches the variable itself. */
#include <stdio.h>

static void swap_copies(int a, int b)       /* changes its own copies only */
{
    int t = a;
    a = b;
    b = t;
}

static void swap_ints(int *a, int *b)      /* changes the caller's variables */
{
    int t = *a;
    *a = *b;
    *b = t;
}

/* divide: the quotient as the result, the remainder through a pointer. */
static int divide(int n, int d, int *remainder)
{
    *remainder = n % d;
    return n / d;
}

int main(void)
{
    int x = 1, y = 2;
    swap_copies(x, y);
    printf("after swap_copies: x = %d, y = %d\n", x, y);
    swap_ints(&x, &y);
    printf("after swap_ints:   x = %d, y = %d\n", x, y);

    int r;
    int q = divide(17, 5, &r);
    printf("17 / 5 = %d, remainder %d\n", q, r);
    return 0;
}
