/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). with_commas, by the design recipe.
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
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

/* Purpose: n with a comma every three digits, into out (size chars);
 * the length, or -1 and "" if it doesn't fit. */
int with_commas(long long n, char *out, size_t size);

static void examples(void)
{
    char out[32];
    assert(with_commas(1234567, out, sizeof out) == 9 && strcmp(out, "1,234,567") == 0);
    assert(with_commas(999, out, sizeof out) == 3 && strcmp(out, "999") == 0);
    assert(with_commas(0, out, sizeof out) == 1 && strcmp(out, "0") == 0);
    assert(with_commas(-1000, out, sizeof out) == 6 && strcmp(out, "-1,000") == 0);
    assert(with_commas(LLONG_MIN, out, sizeof out) == 26 &&
           strcmp(out, "-9,223,372,036,854,775,808") == 0);
    assert(with_commas(1000, out, 5) == -1 && strcmp(out, "") == 0);
}

int with_commas(long long n, char *out, size_t size)
{
    /* The size of n as an unsigned number: -n would overflow for
     * LLONG_MIN, but 0 - (unsigned)n wraps, which is defined. */
    unsigned long long u = n < 0 ? 0 - (unsigned long long)n : (unsigned long long)n;
    char tmp[32];
    int len = 0, digits = 0;
    do {                                   /* from the right */
        if (digits > 0 && digits % 3 == 0)
            tmp[len++] = ',';
        tmp[len++] = (char)('0' + u % 10);
        u /= 10;
        digits++;
    } while (u != 0);
    if (n < 0)
        tmp[len++] = '-';
    if ((size_t)len + 1 > size) {          /* no room for it and its '\0' */
        if (size > 0)
            out[0] = '\0';
        return -1;
    }
    for (int i = 0; i < len; i++)          /* backwards, into out */
        out[i] = tmp[len - 1 - i];
    out[len] = '\0';
    return len;
}

int main(void)
{
    examples();
    char out[32];
    with_commas(-9876543210LL, out, sizeof out);
    printf("%s\n", out);
    return 0;
}
