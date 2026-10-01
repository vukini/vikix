/* exercise.c: digits, by the design recipe.
 *
 * digits(n) is how many decimal digits n has, without the sign:
 * digits(42) is 2, digits(-305) is 3, digits(0) is 1.
 *
 * The check goes through the steps in order and stops at the first
 * that isn't done:
 *   2. a purpose statement: replace the line that says "write it here"
 *   3. examples: add asserts for 0, a negative number and INT_MIN
 *   4. the template still compiles
 *   5. the body: the examples pass (yours, and the check's own)
 *   6. it runs clean under the sanitizers, INT_MIN included
 * Then delete the NOT DONE line to go on.
 */
// NOT DONE
#include <assert.h>
#include <limits.h>
#include <stdio.h>

/* 1. Data: n is any int, INT_MIN to INT_MAX. */

/* 2. Purpose: write it here. */
int digits(int n);

/* 3. Examples. */
static void examples(void)
{
    assert(digits(7) == 1);
    assert(digits(42) == 2);
}

/* 4. Template, then 5. body. */
int digits(int n)
{
    (void)n;
    return 0;
}

int main(void)
{
    examples();
    printf("digits(-305) = %d\n", digits(-305));
    return 0;
}
