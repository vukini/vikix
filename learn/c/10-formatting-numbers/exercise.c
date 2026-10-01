/* exercise.c: with_commas, a project by the design recipe.
 *
 * with_commas(n, out, size) writes n with a comma every three digits,
 * and a '\0', into out, which has room for size chars:
 *     1234567  ->  "1,234,567"      -1000  ->  "-1,000"      999  ->  "999"
 * It returns the length written (not counting the '\0'), or -1 if it
 * doesn't fit, and then out is "" (when size is at least 1).
 *
 * As in lesson 08, the check goes step by step:
 *   1. a purpose statement, in place of "write it here"
 *   2. examples: asserts for 0, a negative number and LLONG_MIN
 *   3. the body, against yours and the check's examples, in buffers of
 *      exactly the right size, under the sanitizers
 * Then delete the NOT DONE line to go on.
 */
// NOT DONE
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

/* Purpose: write it here. */
int with_commas(long long n, char *out, size_t size);

static void examples(void)
{
    char out[32];
    assert(with_commas(1234567, out, sizeof out) == 9 && strcmp(out, "1,234,567") == 0);
    assert(with_commas(999, out, sizeof out) == 3 && strcmp(out, "999") == 0);
}

int with_commas(long long n, char *out, size_t size)
{
    (void)n;
    (void)size;
    out[0] = '\0';
    return 0;
}

int main(void)
{
    examples();
    char out[32];
    with_commas(-9876543210LL, out, sizeof out);
    printf("%s\n", out);
    return 0;
}
