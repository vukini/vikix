/* example.c: a number into text, two ways: digit by digit, from the
 * right, and with snprintf, which never writes past the size you give it
 * and says how long the whole text would have been. */
#include <stdio.h>

/* to_decimal: n's digits, and a '\0', into out (room for 21 chars). */
static void to_decimal(unsigned long long n, char *out)
{
    char tmp[21];
    int len = 0;
    do {
        tmp[len++] = (char)('0' + n % 10);   /* the last digit */
        n /= 10;                             /* and drop it */
    } while (n != 0);
    for (int i = 0; i < len; i++)            /* they came out backwards */
        out[i] = tmp[len - 1 - i];
    out[len] = '\0';
}

int main(int argc, char **argv)
{
    (void)argv;
    char buf[21];
    to_decimal(9876543210ULL, buf);
    printf("to_decimal: %s\n", buf);

    /* 1234567, from argc (1 with no arguments): a number the compiler
     * can't see in advance. With a plain 1234567 it would know the text
     * won't fit, and say so (-Wformat-truncation). */
    int big = 1234566 + argc;
    char small[6];
    int whole = snprintf(small, sizeof small, "%d", big);
    printf("snprintf into 6 chars: \"%s\", the whole was %d chars\n", small, whole);
    return 0;
}
