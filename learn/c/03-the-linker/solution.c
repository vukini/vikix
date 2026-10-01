/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). A program in two files.
 *
 * It uses two functions from stats.c, and the check builds the two
 * together (cc ... exercise.c stats.c). Two things are wrong:
 *   - it uses mean without saying what mean is: write its declaration
 *     (its prototype), copied from stats.c
 *   - then the compiler is happy, and the linker can't find one name:
 *     read its message, and fix this file (stats.c stays as it is)
 * The output it wants:
 *
 *     mean 6.5, largest 12
 *
 * Then delete the NOT DONE line to go on.
 */
#include <stdio.h>

/* What stats.c has: the declarations. */
double mean(const double *v, int n);
double largest(const double *v, int n);

int main(void)
{
    double marks[] = {4, 7, 3, 12};
    printf("mean %g, largest %g\n", mean(marks, 4), largest(marks, 4));
    return 0;
}
