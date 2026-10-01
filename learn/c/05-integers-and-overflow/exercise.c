/* exercise.c: midpoint, without overflowing.
 *
 * midpoint(a, b) is halfway between a and b, rounded towards zero, as
 * (a + b) / 2 would be if a + b always fitted in an int. It doesn't:
 * midpoint(INT_MAX, INT_MAX - 2) adds past INT_MAX. This bug sat in
 * binary searches for years.
 *
 * The check runs it on pairs up to INT_MIN and INT_MAX, under UBSan, which
 * stops at a signed overflow. Then delete the NOT DONE line to go on.
 */
// NOT DONE
#include <assert.h>
#include <limits.h>
#include <stdio.h>

/* midpoint: halfway between a and b, rounded towards zero. */
int midpoint(int a, int b);

static void examples(void)
{
    assert(midpoint(2, 8) == 5);
    assert(midpoint(-3, 4) == 0);      /* 1 / 2, towards zero */
    assert(midpoint(-7, -2) == -4);    /* -9 / 2, towards zero */
}

int midpoint(int a, int b)
{
    return (a + b) / 2;
}

int main(void)
{
    examples();
    printf("midpoint(10, 20) = %d\n", midpoint(10, 20));
    return 0;
}
