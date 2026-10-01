# check.sh: 03, pointers and my_strlen. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./.template.o -c) || fail "it should compile without a warning" "$out"
rm -f ./.template.o
pass "it compiles"
# The library's strlen would make this too easy (comments don't count).
code=$(sed -e 's://.*$::' exercise.c | grep -v '^ */\{0,1\}\*')
if printf '%s\n' "$code" | grep -qE '(^|[^_[:alnum:]])strlen *\(' || grep -q '^ *# *include *<string.h>' exercise.c; then
  fail "walk the string yourself: no strlen, no <string.h>"
fi
pass "it doesn't use the library's strlen"
out=$(build exercise.c ./exercise) || fail "it should link" "$out"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it reads or writes memory it shouldn't" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
  esac
  fail "your own examples should pass" "$got"
}
pass "your examples pass"
# Each string in a heap buffer of exactly its size: one char too far is
# outside it, and AddressSanitizer says so.
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
size_t my_strlen(const char *s);
int main(void)
{
    const char *words[] = {"", "a", "void", "supercharged", "a\tb c"};
    for (unsigned i = 0; i < sizeof words / sizeof words[0]; i++) {
        size_t n = strlen(words[i]);
        char *copy = malloc(n + 1);
        memcpy(copy, words[i], n + 1);
        size_t got = my_strlen(copy);
        free(copy);
        if (got != n) {
            printf("my_strlen(\"%s\") gave %zu, not %zu\n", words[i], got, n);
            return 1;
        }
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check)
status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *AddressSanitizer*) fail "it reads memory it shouldn't: past the end of the string?" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "it measures every string, and reads nothing past the end"
