/* exercise.c: last_index, the loop that counts down.
 *
 * last_index(s, n, c) is where c last appears among the n chars of s, or
 * -1 if it doesn't: last_index("banana", 6, 'a') is 5. Counting down from
 * the end with a size_t, which can't go below 0, is the trap: gcc's
 * warning says why, and n == 0 is the other edge.
 *
 * s is n chars, not a string: there may be no '\0' after them. The check
 * puts them in a buffer of exactly n, so reading s[n] or s[-1] is caught.
 * Then delete the NOT DONE line to go on.
 */
// NOT DONE
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

/* last_index: the last place c is among s[0..n-1], or -1. */
long last_index(const char *s, size_t n, char c);

static void examples(void)
{
    assert(last_index("banana", 6, 'a') == 5);
    assert(last_index("banana", 6, 'b') == 0);
    assert(last_index("banana", 6, 'z') == -1);
}

long last_index(const char *s, size_t n, char c)
{
    for (size_t i = n - 1; i >= 0; i--)
        if (s[i] == c)
            return (long)i;
    return -1;
}

int main(void)
{
    examples();
    printf("last_index(\"supercharged\", 12, 'e') = %ld\n", last_index("supercharged", 12, 'e'));
    return 0;
}
