/* example.c: where signed and unsigned meet. When an int and an unsigned
 * are compared or combined, the int is converted to unsigned first, and a
 * negative one becomes a very large number. */
#include <stdio.h>
#include <string.h>

int main(void)
{
    size_t len = strlen("ab");                     /* 2; size_t is unsigned */
    printf("(size_t)-1 = %zu\n", (size_t)-1);      /* the largest size_t */
    printf("len - 3 = %zu\n", len - 3);            /* wraps: not -1 */
    printf("len - 3 > 0 is %d\n", len - 3 > 0);    /* true, without a warning */
    printf("(int)len - 3 > 0 is %d\n", (int)len - 3 > 0);   /* signed: false */
    return 0;
}
