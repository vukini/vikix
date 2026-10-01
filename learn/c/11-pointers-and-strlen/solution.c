/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). my_strlen, your own strlen.
 *
 * my_strlen(s) is how many chars come before the '\0' that ends s:
 * my_strlen("void") is 4, my_strlen("") is 0. Walk a pointer along s,
 * as count_char does in example.c; don't use strlen or <string.h>.
 *
 * The check runs it on strings in buffers of exactly the right size, so
 * reading even one char past the '\0' is caught (by AddressSanitizer).
 * Delete the NOT DONE line when it passes.
 */
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

/* my_strlen: how many chars s has before its '\0'. */
size_t my_strlen(const char *s);

static void examples(void)
{
    assert(my_strlen("void") == 4);
    assert(my_strlen("") == 0);
    assert(my_strlen("supercharged") == 12);
}

size_t my_strlen(const char *s)
{
    const char *p = s;
    while (*p != '\0')
        p++;
    return (size_t)(p - s);   /* how far p walked */
}

int main(void)
{
    examples();
    printf("my_strlen(\"Vikix\") = %zu\n", my_strlen("Vikix"));
    return 0;
}
