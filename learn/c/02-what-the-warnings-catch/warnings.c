/* warnings.c: four mistakes, and which flag finds each (see lesson.md). */
#include <stdio.h>

static int average(const int *v, int n)
{
    int sum = 0;
    for (unsigned i = 0; i < n; i++)    /* an unsigned i against a signed n */
        sum += v[i];
    if (n > 0)
        return sum / n;
}                                       /* n == 0: nothing is returned */

int main(void)
{
    int marks[] = {7, 9, 4};
    signed char offset = 200;           /* a signed char goes to 127 */
    int unused;
    printf("average %d, offset %d\n", average(marks, 3), offset);
    return 0;
}
