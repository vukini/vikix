# check.sh: 02, the design recipe. Runs in your copy of the lesson.
. "$LEARN_LIB"

# 2. A purpose statement above the signature.
grep -qF '/* 2. Purpose: write it here. */' exercise.c && fail "write the purpose statement: one sentence, in place of \"write it here\""
grep -B3 '^int digits(int n);' exercise.c | grep -q '/\*\|//' || fail "a purpose statement goes just above int digits(int n);"
pass "the signature has its purpose"

# 3. Examples: 0, a negative number, and INT_MIN.
grep -q 'assert(digits(0)' exercise.c || fail "add an example for 0" "assert(digits(0) == ...);"
grep -q 'assert(digits(-[0-9]' exercise.c || fail "add an example for a negative number" "assert(digits(-305) == ...);"
grep -q 'assert(digits(INT_MIN)' exercise.c || fail "add an example for INT_MIN, the most negative int"
pass "the examples cover 0, a negative number and INT_MIN"

# 4. The template compiles.
out=$(build exercise.c ./.template.o -c) || fail "it should compile without a warning" "$out"
rm -f ./.template.o
pass "it compiles"

# 5. The examples pass: yours, then the check's own (your digits, its main).
out=$(build exercise.c ./exercise) || fail "it should link" "$out"
got=$(runs ./exercise) || {
  case $got in
    *AddressSanitizer*) fail "it reads or writes memory it shouldn't" "$(brief "$got")" ;;
    *runtime\ error*) fail "it runs into undefined behaviour" "$(brief "$got")" ;;
  esac
  fail "your own examples should pass" "$got"
}
cat > ./.check-main.c <<'C'
#include <limits.h>
#include <stdio.h>
int digits(int n);
int main(void)
{
    int n[] = {0, 9, 10, -1, -305, 99999, 100000, INT_MAX, INT_MIN};
    int want[] = {1, 1, 2, 1, 3, 5, 6, 10, 10};
    for (unsigned i = 0; i < sizeof n / sizeof n[0]; i++)
        if (digits(n[i]) != want[i]) {
            printf("digits(%d) gave %d, not %d\n", n[i], digits(n[i]), want[i]);
            return 1;
        }
    return 0;
}
C
# Your file with its main renamed, then linked to the check's main.
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check)
status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in
  *runtime\ error*|*AddressSanitizer*) fail "it runs into undefined behaviour (step 6)" "$(brief "$got")" ;;
esac
[ "$status" = 0 ] || fail "the body isn't right yet" "$got"
pass "the examples pass, the check's too"
_san_ok >/dev/null && pass "and clean under the sanitizers" || pass "(without the sanitizers: vikix update installs them)"
