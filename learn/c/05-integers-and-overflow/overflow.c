/* overflow.c: one past INT_MAX, in an int. argc is 1 when it runs with
 * no arguments, so the compiler can't work the answer out beforehand. */
#include <limits.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    (void)argv;
    int x = INT_MAX;
    x = x + argc;                     /* signed overflow: undefined */
    printf("INT_MAX + 1 = %d\n", x);
    return 0;
}
