/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). digits, by the design recipe.
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
#include <assert.h>
#include <limits.h>
#include <stdio.h>

/* 1. Data: n is any int, INT_MIN to INT_MAX. */

/* 2. Purpose: how many decimal digits n has, not counting a minus sign. */
int digits(int n);

/* 3. Examples. */
static void examples(void)
{
    assert(digits(7) == 1);
    assert(digits(42) == 2);
    assert(digits(0) == 1);
    assert(digits(-305) == 3);
    assert(digits(INT_MIN) == 10);
    assert(digits(INT_MAX) == 10);
}

/* 4. Template, then 5. body. Dividing by 10 rounds towards zero, for
 *    negative numbers too, so n never has to be made positive: -n would
 *    overflow for INT_MIN. */
int digits(int n)
{
    int count = 1;
    while (n / 10 != 0) {
        n /= 10;
        count++;
    }
    return count;
}

int main(void)
{
    examples();
    printf("digits(-305) = %d\n", digits(-305));
    return 0;
}
