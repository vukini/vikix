/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). Answers back through pointers.
 *
 * swap(a, b) exchanges the two ints a and b point to.
 * min_max(v, n, min, max) puts the smallest and largest of v[0..n-1]
 * into *min and *max, and returns 1; when n is 0 there's no answer: it
 * returns 0 and leaves *min and *max as they were.
 *
 * The check runs them on arrays of exactly n values, under the sanitizers.
 * Then delete the NOT DONE line to go on.
 */
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

/* swap: exchange *a and *b. */
void swap(int *a, int *b);
/* min_max: the smallest and largest of v[0..n-1], into *min and *max;
 * 1, or 0 (and nothing changed) when n is 0. */
int min_max(const int *v, size_t n, int *min, int *max);

static void examples(void)
{
    int a = 3, b = 9;
    swap(&a, &b);
    assert(a == 9 && b == 3);

    int v[] = {4, -2, 7, 0};
    int lo = 0, hi = 0;
    assert(min_max(v, 4, &lo, &hi) == 1 && lo == -2 && hi == 7);
    int lo2 = 42, hi2 = 42;
    assert(min_max(v, 0, &lo2, &hi2) == 0 && lo2 == 42 && hi2 == 42);
}

void swap(int *a, int *b)
{
    int t = *a;
    *a = *b;                     /* the int a points to, not a itself */
    *b = t;
}

int min_max(const int *v, size_t n, int *min, int *max)
{
    if (n == 0)
        return 0;                /* no answer, and nothing changed */
    int lo = v[0], hi = v[0];    /* start from a value that's really there */
    for (size_t i = 1; i < n; i++) {
        if (v[i] < lo)
            lo = v[i];
        if (v[i] > hi)
            hi = v[i];
    }
    *min = lo;                   /* into the caller's variables */
    *max = hi;
    return 1;
}

int main(void)
{
    examples();
    int marks[] = {12, 5, 19, 8};
    int lo, hi;
    min_max(marks, 4, &lo, &hi);
    printf("smallest %d, largest %d\n", lo, hi);
    return 0;
}
