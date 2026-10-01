/* words.c: counting words. */
#include "words.h"

int count_words(const char *s)
{
    int n = 0, in_word = 0;
    for (; *s != '\0'; s++) {
        if (*s == ' ') {
            in_word = 0;
        } else if (!in_word) {
            in_word = 1;
            n++;
        }
    }
    return n;
}
