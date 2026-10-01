/* example.c: sqrt of a number the compiler knows. gcc works it out
 * itself, so the program never calls sqrt, and the linker never needs
 * the maths library (-lm). Compare roots.c. */
#include <math.h>
#include <stdio.h>

int main(void)
{
    printf("sqrt(2) = %f\n", sqrt(2.0));
    return 0;
}
