/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). longest_run, with both bugs fixed.
 *
 * longest_run(v, n) is the length of the longest run of equal values
 * next to each other in v[0..n-1]: in {1, 1, 2, 2, 2, 1} it's 3 (the
 * 2s); 0 when n is 0. Its examples fail, and a careful look in gdb finds
 * out why (lesson.md shows how; vikix learn c hint shows the commands).
 *
 * The check also runs it on arrays of exactly n values, so reading one
 * past the end is caught. Then delete the NOT DONE line to go on.
 */
#include <assert.h>
#include <stdio.h>

/* longest_run: the longest run of equal neighbours in v[0..n-1]. */
int longest_run(const int *v, int n);

static void examples(void)
{
    int a[] = {1, 1, 2, 2, 2, 1};
    assert(longest_run(a, 6) == 3);
    int b[] = {5};
    assert(longest_run(b, 1) == 1);
    int c[] = {1, 2, 1, 2};
    assert(longest_run(c, 4) == 1);
}

int longest_run(const int *v, int n)
{
    if (n == 0)
        return 0;
    int best = 1, run = 1;
    for (int i = 1; i < n; i++) {        /* v[n] is past the end */
        if (v[i] == v[i - 1])
            run++;
        else
            run = 1;                        /* a new value starts a new run */
        if (run > best)
            best = run;
    }
    return best;
}

int main(void)
{
    examples();
    int marks[] = {7, 7, 7, 3, 3, 7};
    printf("longest_run = %d\n", longest_run(marks, 6));
    return 0;
}
