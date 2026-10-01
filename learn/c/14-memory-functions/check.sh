# check.sh: 14, memory functions. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./.exercise.o -c) || fail "it should compile without a warning" "$out"
rm -f ./.exercise.o
pass "it compiles"
code=$(sed -e 's://.*$::' exercise.c | grep -v '^ */\{0,1\}\*')
if grep -q '^ *# *include *<string.h>' exercise.c ||
   printf '%s\n' "$code" | grep -qE '(^|[^_[:alnum:]])(memcpy|memset|strcmp) *\('; then
  fail "write them yourself: no <string.h>, no memcpy, memset or strcmp"
fi
pass "it doesn't use the library's versions"
out=$(build exercise.c ./exercise) || fail "it should link" "$out"
got=$(timeout 5 bash -c "$(declare -f runs); runs ./exercise"); status=$?
[ "$status" = 124 ] && fail "it never stops: when two strings are equal, what stops my_strcmp?"
case $got in
  *AddressSanitizer*) fail "it reads or writes memory it shouldn't" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "your own examples should pass" "$(printf '%s\n' "$got" | grep -o 'Assertion .*' | head -1)"
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void *my_memcpy(void *dest, const void *src, size_t n);
void *my_memset(void *s, int c, size_t n);
int my_strcmp(const char *a, const char *b);
static int sign(int x) { return (x > 0) - (x < 0); }
static char *exact(const char *s) { size_t n = strlen(s) + 1; char *p = malloc(n); memcpy(p, s, n); return p; }
int main(void)
{
    for (size_t n = 0; n <= 40; n += 7) {
        unsigned char *src = malloc(n ? n : 1), *dst = malloc(n ? n : 1);
        for (size_t i = 0; i < n; i++) src[i] = (unsigned char)(i * 37 + 200);
        if (my_memcpy(dst, src, n) != dst || memcmp(dst, src, n) != 0) { printf("my_memcpy of %zu bytes didn't copy them all\n", n); return 1; }
        if (my_memset(dst, 0x1F5, n) != dst) { printf("my_memset should return s\n"); return 1; }
        for (size_t i = 0; i < n; i++)
            if (dst[i] != 0xF5) { printf("my_memset(s, 0x1F5, %zu) set byte %zu to 0x%X, not 0xF5 (c as an unsigned char)\n", n, i, dst[i]); return 1; }
        free(src); free(dst);
    }
    const char *pairs[][2] = {{"", ""}, {"", "a"}, {"a", ""}, {"same", "same"}, {"abc", "abd"}, {"abd", "abc"},
                              {"ab", "abc"}, {"abc", "ab"}, {"\xe9", "e"}, {"e", "\xe9"}, {"Zebra", "apple"}};
    for (unsigned i = 0; i < sizeof pairs / sizeof pairs[0]; i++) {
        char *a = exact(pairs[i][0]), *b = exact(pairs[i][1]);
        int got = sign(my_strcmp(a, b)), want = sign(strcmp(a, b));
        free(a); free(b);
        if (got != want) {
            printf("my_strcmp(\"%s\", \"%s\") has the sign %d, strcmp's is %d\n", pairs[i][0], pairs[i][1], got, want);
            return 1;
        }
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(timeout 5 bash -c "$(declare -f runs); runs ./.check"); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
[ "$status" = 124 ] && fail "on the check's examples, it never stops"
case $got in
  *AddressSanitizer*) fail "it reads or writes outside a buffer of exactly the right size" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "they match the library's, bytes above 127 included, never outside a buffer"
