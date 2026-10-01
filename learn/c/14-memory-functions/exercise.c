/* exercise.c: your own memcpy, memset and strcmp: a project.
 *
 * my_memcpy(dest, src, n) copies n bytes from src to dest, returns dest.
 * my_memset(s, c, n) sets n bytes of s to c (as an unsigned char),
 *     returns s.
 * my_strcmp(a, b) compares two strings a byte at a time, as unsigned
 *     char: below 0 if a comes first, 0 if equal, above 0 if b comes
 *     first. A shorter string that matches so far comes first.
 *
 * Walk pointers, without the library's versions (no <string.h>). The
 * check compares yours with the library's, on buffers of exactly the
 * right size, with bytes above 127 too, under the sanitizers. Then
 * delete the NOT DONE line to go on.
 */
// NOT DONE
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

void *my_memcpy(void *dest, const void *src, size_t n);
void *my_memset(void *s, int c, size_t n);
int my_strcmp(const char *a, const char *b);

static void examples(void)
{
    char buf[4] = "abc";
    char out[4];
    assert(my_memcpy(out, buf, 4) == out && out[0] == 'a' && out[3] == '\0');
    assert(my_memset(out, 'z', 2) == out && out[0] == 'z' && out[1] == 'z' && out[2] == 'c');
    assert(my_strcmp("ab", "ab") == 0);
    assert(my_strcmp("ab", "ac") < 0);
    assert(my_strcmp("abc", "ab") > 0);
}

void *my_memcpy(void *dest, const void *src, size_t n)
{
    (void)src;
    (void)n;
    return dest;
}

void *my_memset(void *s, int c, size_t n)
{
    (void)c;
    (void)n;
    return s;
}

int my_strcmp(const char *a, const char *b)
{
    while (*a == *b) {
        a++;
        b++;
    }
    return *a - *b;
}

int main(void)
{
    examples();
    printf("my_strcmp(\"void\", \"vikix\") > 0: %d\n", my_strcmp("void", "vikix") > 0);
    return 0;
}
