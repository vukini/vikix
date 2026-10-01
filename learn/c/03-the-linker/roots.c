/* roots.c: sqrt of a number given when it runs: the program calls sqrt,
 * and the linker has to find it, in the maths library (-lm). */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    double x = argc > 1 ? atof(argv[1]) : 2.0;
    printf("sqrt(%g) = %g\n", x, sqrt(x));
    return 0;
}
