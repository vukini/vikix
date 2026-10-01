/* exercise.c: a program in two files, which won't build yet.
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
// NOT DONE
#include <stdio.h>

/* What stats.c has: the declarations. */
double biggest(const double *v, int n);

int main(void)
{
    double marks[] = {4, 7, 3, 12};
    printf("mean %g, largest %g\n", mean(marks, 4), biggest(marks, 4));
    return 0;
}
