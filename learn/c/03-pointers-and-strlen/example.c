/* example.c: pointers, by walking along a string.
 *
 * A pointer holds an address. *p is what's there; p + 1 is the address
 * of the next element, however big the elements are. A string is just
 * chars in a row, ended by a '\0'. */
#include <stdio.h>

/* count_char: how many times c appears in the string s. */
static int count_char(const char *s, char c)
{
    int n = 0;
    for (const char *p = s; *p != '\0'; p++)   /* p moves; *p reads */
        if (*p == c)
            n++;
    return n;
}

int main(void)
{
    char word[] = "supercharged";
    char *first = word;      /* an array, used as a value, is a pointer to its first element */
    char *third = word + 2;  /* two chars on */

    printf("*first = %c, *third = %c\n", *first, *third);
    printf("third - first = %td\n", third - first);
    printf("sizeof word = %zu, sizeof first = %zu\n", sizeof word, sizeof first);

    int numbers[3] = {10, 20, 30};
    int *ip = numbers;
    printf("ip + 1 is %td bytes on from ip, and *(ip + 1) = %d\n",
           (char *)(ip + 1) - (char *)ip, *(ip + 1));

    printf("count_char(\"%s\", 'e') = %d\n", word, count_char(word, 'e'));
    return 0;
}
