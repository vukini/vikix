/* exercise.c: a macro that gives the wrong answers.
 *
 * Run the program: SQUARE(1 + 2) should be 9, and it isn't. Look at what
 * the preprocessor makes of it:
 *
 *     cc -E exercise.c | tail -n 6
 *
 * then fix SQUARE, and only SQUARE: the three printf lines stay as they
 * are. Every save is checked. When all three answers are right, delete
 * the NOT DONE line below to go on.
 */
#include <stdio.h>

#define SQUARE(x) ((x) * (x))

int main(void)
{
    printf("SQUARE(1 + 2) = %d\n", SQUARE(1 + 2));     /* should be 9 */
    printf("SQUARE(10 - 4) = %d\n", SQUARE(10 - 4));   /* should be 36 */
    printf("100 / SQUARE(5) = %d\n", 100 / SQUARE(5)); /* should be 4 */
    return 0;
}
