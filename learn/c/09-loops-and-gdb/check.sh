# check.sh: 09, loops and gdb. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning" "$out"
pass "it compiles"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it reads past the end of the array: which i is the last one the loop looks at?" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
  esac
  fail "your own examples should pass: step through one in gdb" "$(printf '%s\n' "$got" | grep -o 'Assertion .*' | head -1)"
}
pass "your examples pass, and nothing past the end is read"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int longest_run(const int *v, int n);
int main(void)
{
    struct { int n; int v[8]; int want; } t[] = {
        {0, {0}, 0}, {1, {9}, 1}, {2, {4, 4}, 2}, {2, {4, 5}, 1}, {5, {3, 3, 1, 3, 3}, 2},
        {6, {1, 2, 2, 2, 2, 1}, 4}, {7, {8, 8, 8, 1, 1, 1, 1}, 4}, {4, {-1, -1, -1, -1}, 4},
    };
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        int *copy = malloc(t[i].n ? t[i].n * sizeof(int) : 1);   /* exactly n values */
        memcpy(copy, t[i].v, t[i].n * sizeof(int));
        int got = longest_run(copy, t[i].n);
        free(copy);
        if (got != t[i].want) {
            printf("longest_run of %d values {%d, %d, ...} gave %d, not %d\n", t[i].n, t[i].v[0], t[i].v[1], got, t[i].want);
            return 1;
        }
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *AddressSanitizer*) fail "it reads past the end of the array" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right on the check's examples too"
