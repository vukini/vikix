/* solution.c: one way to finish exercise.c (Vikix's tests check it
 * passes; it isn't copied to ~/learn). A program the compiler has four
 * things to say about.
 *
 * Each warning here points at a real bug, or at code that does nothing.
 * The check compiles with -std=c17 -Wall -Wextra -pedantic -Werror (a
 * warning counts as an error) and then wants this output:
 *
 *     longest: 12
 *     none: 0
 *     total: 5000000000
 *
 * Fix what the warnings point at; don't change what the program prints.
 * See them with:  cc -std=c17 -Wall -Wextra -pedantic -c exercise.c
 * Then delete the NOT DONE line to go on.
 */
#include <stdio.h>
#include <string.h>

/* longest: the length of the longest word in words, 0 when n is 0. */
static int longest(const char *words[], int n)
{
    size_t best = 0;                 /* set, and the same type as strlen's */
    for (int i = 0; i < n; i++)
        if (strlen(words[i]) > best)
            best = strlen(words[i]);
    return (int)best;
}

int main(void)
{
    const char *words[] = {"void", "supercharged", "stumpwm"};
    long total = 5000000000;
    printf("longest: %d\n", longest(words, 3));
    printf("none: %d\n", longest(words, 0));
    printf("total: %ld\n", total);
    return 0;
}
