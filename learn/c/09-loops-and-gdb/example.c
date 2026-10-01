/* example.c: a loop, to step through in gdb (see lesson.md). Built with
 * -g, the program carries its own line numbers and variable names. */
#include <stdio.h>

/* sum_squares: 1*1 + 2*2 + ... + n*n. */
static int sum_squares(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++)
        total += i * i;
    return total;
}

int main(void)
{
    printf("sum_squares(4) = %d\n", sum_squares(4));
    return 0;
}
