/* example.c: the library's memcpy, memset and strcmp, the three the
 * project writes again. They work on bytes: memcpy and memset don't stop
 * at a '\0', and strcmp compares bytes as unsigned char. */
#include <stdio.h>
#include <string.h>

int main(void)
{
    char a[8] = "abcdefg";
    char b[8];
    memcpy(b, a, sizeof a);              /* every byte, the '\0' too */
    printf("memcpy: %s\n", b);

    memset(b, '-', 3);                   /* the first 3 bytes */
    printf("memset: %s\n", b);

    /* strcmp's answer is a sign: below 0, 0, or above 0. */
    printf("strcmp(\"apple\", \"apricot\") %s 0\n", strcmp("apple", "apricot") < 0 ? "<" : ">=");
    printf("strcmp(\"ab\", \"ab\") == %d\n", strcmp("ab", "ab"));
    printf("strcmp(\"abc\", \"ab\") %s 0\n", strcmp("abc", "ab") > 0 ? ">" : "<=");
    /* 0xE9 (an é in Latin-1) is 233 as unsigned char, -23 as a signed one. */
    printf("strcmp(\"\\xe9\", \"e\") %s 0\n", strcmp("\xe9", "e") > 0 ? ">" : "<=");
    return 0;
}
