/* example.c: warnings.c with each mistake fixed, so it compiles without a
 * word under -std=c17 -Wall -Wextra -pedantic. */
#include <stdio.h>

static int average(const int *v, int n)
{
    if (n <= 0)
        return 0;                       /* every path returns */
    int sum = 0;
    for (int i = 0; i < n; i++)         /* i and n both int */
        sum += v[i];
    return sum / n;
}

int main(void)
{
    int marks[] = {7, 9, 4};
    int offset = 200;                   /* an int holds 200 */
    printf("average %d, offset %d\n", average(marks, 3), offset);
    return 0;
}
