# check.sh: 06, signed and unsigned. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning (gcc has seen something about the loop)" "$out"
pass "it compiles"
got=$(timeout 5 bash -c "$(declare -f runs); runs ./exercise"); status=$?
[ "$status" = 124 ] && fail "it never stops: does the loop's test ever become false?"
case $got in
  *AddressSanitizer*) fail "it reads outside s" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "your own examples should pass" "$got"
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
long last_index(const char *s, size_t n, char c);
int main(void)
{
    struct { const char *s; char c; long want; } t[] = {
        {"", 'a', -1}, {"a", 'a', 0}, {"a", 'b', -1}, {"abca", 'a', 3}, {"xyz", 'x', 0}, {"zzz", 'z', 2},
    };
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        size_t n = strlen(t[i].s);
        char *buf = malloc(n ? n : 1);     /* exactly n chars, no '\0' after them */
        memcpy(buf, t[i].s, n);
        long got = last_index(buf, n, t[i].c);
        free(buf);
        if (got != t[i].want) {
            printf("last_index(\"%s\", %zu, '%c') gave %ld, not %ld\n", t[i].s, n, t[i].c, got, t[i].want);
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
[ "$status" = 124 ] && fail "on the check's examples, it never stops (an empty one, n == 0?)"
case $got in
  *AddressSanitizer*) fail "it reads outside s, on the check's examples (n == 0?)" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right, n == 0 included, and nothing read outside s"
