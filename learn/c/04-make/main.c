/* main.c: the program, wordcount. */
#include <stdio.h>
#include "words.h"

int main(void)
{
    printf("%d words\n", count_words("Void Linux, supercharged by StumpWM"));
    return 0;
}
