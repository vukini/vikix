/* example.c: how big the integer types are here, where they end, and
 * what happens past the end. */
#include <limits.h>
#include <stdio.h>

int main(void)
{
    printf("bytes: char %zu, short %zu, int %zu, long %zu, long long %zu\n",
           sizeof(char), sizeof(short), sizeof(int), sizeof(long), sizeof(long long));
    printf("int goes from %d to %d\n", INT_MIN, INT_MAX);
    printf("unsigned int goes from 0 to %u\n", UINT_MAX);

    unsigned u = UINT_MAX;
    u = u + 1;                        /* unsigned: wraps round to 0, always */
    printf("UINT_MAX + 1 = %u\n", u);

    long long wide = (long long)INT_MAX + 1;   /* widened first, then added */
    printf("INT_MAX + 1, as a long long = %lld\n", wide);
    return 0;
}
