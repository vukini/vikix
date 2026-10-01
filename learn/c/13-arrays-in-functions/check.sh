# check.sh: 13, arrays in functions. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning (gcc says what sizeof gives inside sum)" "$out"
pass "it compiles"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it reads past the end of the array" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
  esac
  fail "it should run cleanly" "$got"
}
[ "$got" = "sum = 30" ] || fail "main should print sum = 30" "got: $got"
pass "it prints sum = 30"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
long sum(const int *v, size_t n);
int main(void)
{
    struct { size_t n; int v[12]; long want; } t[] = {
        {0, {0}, 0}, {1, {41}, 41}, {3, {1, 2, 3}, 6}, {12, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 100}, 111}, {2, {-4, 4}, 0},
    };
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        int *copy = malloc(t[i].n ? t[i].n * sizeof(int) : 1);     /* exactly n values */
        memcpy(copy, t[i].v, t[i].n * sizeof(int));
        long got = sum(copy, t[i].n);
        free(copy);
        if (got != t[i].want) { printf("sum of %zu values gave %ld, not %ld\n", t[i].n, got, t[i].want); return 1; }
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) ||
  fail "it should build with the check's examples, which call sum(v, n), with n a size_t" "$out"
got=$(runs ./.check); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *AddressSanitizer*) fail "it reads past the end of the array" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right for 0 to 12 values, and nothing read past the end"
