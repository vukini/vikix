# check.sh: 12, out-parameters. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning (one says a parameter is set and never used: what does setting it change?)" "$out"
pass "it compiles"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it reads or writes memory it shouldn't" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
  esac
  fail "your own examples should pass" "$(printf '%s\n' "$got" | grep -o 'Assertion .*' | head -1)"
}
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void swap(int *a, int *b);
int min_max(const int *v, size_t n, int *min, int *max);
int main(void)
{
    int a = -5, b = 5;
    swap(&a, &b);
    if (a != 5 || b != -5) { printf("swap(-5, 5) left %d and %d\n", a, b); return 1; }
    swap(&a, &a);
    if (a != 5) { printf("swap of a variable with itself changed it to %d\n", a); return 1; }
    struct { size_t n; int v[5]; int lo, hi; } t[] = {
        {1, {7}, 7, 7}, {3, {5, 9, 6}, 5, 9}, {4, {-3, -8, -1, -8}, -8, -1}, {5, {10, 20, 30, 40, 50}, 10, 50},
    };
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        int *copy = malloc(t[i].n * sizeof(int));           /* exactly n values */
        memcpy(copy, t[i].v, t[i].n * sizeof(int));
        int lo = 999, hi = 999;
        int ok = min_max(copy, t[i].n, &lo, &hi);
        free(copy);
        if (ok != 1 || lo != t[i].lo || hi != t[i].hi) {
            printf("min_max of {%d, ...} (%zu values) gave %d, %d and %d, not 1, %d and %d\n",
                   t[i].v[0], t[i].n, ok, lo, hi, t[i].lo, t[i].hi);
            return 1;
        }
    }
    int lo = 1, hi = 2;
    if (min_max(NULL, 0, &lo, &hi) != 0 || lo != 1 || hi != 2) { printf("min_max of no values should return 0 and change nothing\n"); return 1; }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *AddressSanitizer*) fail "it reads or writes memory it shouldn't" "$(brief "$got")" ;;
  *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right on the check's examples: all negative, all positive, one value, none"
