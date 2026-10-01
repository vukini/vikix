/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). sum, told its length.
 *
 * sum(v, n) adds up v[0..n-1]. As it comes, it works out the length
 * itself, with sizeof, which can't work inside a function (lesson.md
 * says why, and so does gcc). Give it the length as a second argument,
 * size_t n, and pass it from main.
 *
 * The check calls sum(v, n) on arrays of exactly n values, under the
 * sanitizers. Then delete the NOT DONE line to go on.
 */
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

/* sum: v[0] + v[1] + ... + v[n-1]. */
long sum(const int *v, size_t n);

long sum(const int *v, size_t n)
{
    long total = 0;
    for (size_t i = 0; i < n; i++)
        total += v[i];
    return total;
}

int main(void)
{
    int marks[] = {7, 9, 4, 8, 2};
    printf("sum = %ld\n", sum(marks, sizeof marks / sizeof marks[0]));
    return 0;
}
