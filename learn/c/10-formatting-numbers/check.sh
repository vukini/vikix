# check.sh: 10, formatting numbers. Runs in your copy of the lesson.
. "$LEARN_LIB"

grep -qF '/* Purpose: write it here. */' exercise.c && fail "write the purpose statement, in place of \"write it here\""
pass "the purpose is written"
grep -q 'with_commas(0,' exercise.c || fail "add an example for 0"
grep -q 'with_commas(-[0-9]' exercise.c || fail "add an example for a negative number"
grep -q 'with_commas(LLONG_MIN' exercise.c || fail "add an example for LLONG_MIN, the most negative long long"
pass "the examples cover 0, a negative number and LLONG_MIN"
out=$(build exercise.c ./exercise) || fail "it should compile without a warning" "$out"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it writes or reads outside a buffer" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour (-LLONG_MIN?)" "$(brief "$got")" ;;
  esac
  fail "your own examples should pass" "$(printf '%s\n' "$got" | grep -o 'Assertion .*' | head -1)"
}
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int with_commas(long long n, char *out, size_t size);
int main(void)
{
    struct { long long n; const char *want; } t[] = {
        {0, "0"}, {7, "7"}, {-7, "-7"}, {999, "999"}, {1000, "1,000"}, {-999999, "-999,999"},
        {1000000, "1,000,000"}, {LLONG_MAX, "9,223,372,036,854,775,807"}, {LLONG_MIN, "-9,223,372,036,854,775,808"},
    };
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        size_t len = strlen(t[i].want);
        char *exact = malloc(len + 1);                 /* exactly enough */
        int got = with_commas(t[i].n, exact, len + 1);
        if (got != (int)len || strcmp(exact, t[i].want) != 0) {
            printf("with_commas(%lld) gave %d and \"%s\", not %zu and \"%s\"\n", t[i].n, got, exact, len, t[i].want);
            return 1;
        }
        free(exact);
        char *short1 = malloc(len);                    /* one too few */
        got = with_commas(t[i].n, short1, len);
        if (got != -1 || short1[0] != '\0') {
            printf("with_commas(%lld) into %zu chars should give -1 and \"\", it gave %d\n", t[i].n, len, got);
            return 1;
        }
        free(short1);
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *AddressSanitizer*) fail "it writes or reads outside a buffer of exactly the right size" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right, LLONG_MIN and LLONG_MAX included, and never past the end of out"
