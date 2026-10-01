# check.sh: 05, integers and overflow. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning" "$out"
pass "it compiles"
got=$(runs ./exercise) || {
  case $got in *runtime\ error*) fail "it overflows" "$(brief "$got")" ;; esac
  fail "your own examples should pass" "$got"
}
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <limits.h>
#include <stdio.h>
int midpoint(int a, int b);
int main(void)
{
    int pairs[][2] = {{0, 0}, {1, 2}, {-1, -2}, {INT_MAX, INT_MAX}, {INT_MAX, INT_MAX - 2},
                      {INT_MIN, INT_MIN}, {INT_MIN, INT_MAX}, {INT_MAX, INT_MIN + 1}, {-5, 5}};
    for (unsigned i = 0; i < sizeof pairs / sizeof pairs[0]; i++) {
        int a = pairs[i][0], b = pairs[i][1];
        int want = (int)(((long long)a + b) / 2);
        if (midpoint(a, b) != want) {
            printf("midpoint(%d, %d) gave %d, not %d\n", a, b, midpoint(a, b), want);
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
case $got in *runtime\ error*) fail "it overflows, on the check's examples" "$(brief "$got")" ;; esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right up to INT_MIN and INT_MAX, and no overflow"
