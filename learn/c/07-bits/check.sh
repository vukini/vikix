# check.sh: 07, bits. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./exercise) || fail "it should compile without a warning" "$out"
pass "it compiles"
got=$(runs ./exercise) || {
  case $got in *runtime\ error*|*AddressSanitizer*) fail "it runs into undefined behaviour" "$(brief "$got")" ;; esac
  fail "your own examples should pass" "$(printf '%s\n' "$got" | grep -o 'Assertion .*' | head -1)"
}
pass "your examples pass"
cat > ./.check-main.c <<'C'
#include <stdio.h>
#include <string.h>
void bits8(unsigned char x, char out[9]);
int count_ones(unsigned x);
unsigned set_bit(unsigned x, int n);
unsigned clear_bit(unsigned x, int n);
int test_bit(unsigned x, int n);
int main(void)
{
    for (unsigned v = 0; v < 256; v++) {
        char out[9], want[9];
        for (int i = 0; i < 8; i++) want[i] = (v >> (7 - i)) & 1 ? '1' : '0';
        want[8] = '\0';
        memset(out, 'x', sizeof out);
        bits8((unsigned char)v, out);
        if (memcmp(out, want, 9) != 0) { printf("bits8(%u) gave \"%.8s\", not \"%s\" (and a '\\0' after)\n", v, out, want); return 1; }
        if (count_ones(v) != __builtin_popcount(v)) { printf("count_ones(%u) gave %d, not %d\n", v, count_ones(v), __builtin_popcount(v)); return 1; }
    }
    if (count_ones(0xFFFFFFFFu) != 32) { printf("count_ones(0xFFFFFFFF) gave %d, not 32\n", count_ones(0xFFFFFFFFu)); return 1; }
    for (int n = 0; n < 32; n++) {
        unsigned x = 0xA5A5A5A5u;
        if (set_bit(x, n) != (x | (1u << n))) { printf("set_bit(0x%X, %d) gave 0x%X\n", x, n, set_bit(x, n)); return 1; }
        if (clear_bit(x, n) != (x & ~(1u << n))) { printf("clear_bit(0x%X, %d) gave 0x%X\n", x, n, clear_bit(x, n)); return 1; }
        if (test_bit(x, n) != (int)((x >> n) & 1)) { printf("test_bit(0x%X, %d) gave %d\n", x, n, test_bit(x, n)); return 1; }
    }
    return 0;
}
C
out=$(build exercise.c ./.exercise.o -c -Dmain=learner_main) &&
  out=$(build ./.check-main.c ./.check ./.exercise.o) || fail "it should build with the check's examples" "$out"
got=$(runs ./.check); status=$?
rm -f ./.check ./.check-main.c ./.exercise.o
case $got in *runtime\ error*|*AddressSanitizer*) fail "it runs into undefined behaviour (a shift of a 1 into bit 31?)" "$(brief "$got")" ;; esac
[ "$status" = 0 ] || fail "not right yet" "$got"
pass "right for every byte and every bit"
got=$(runs ./exercise 200)
[ "$got" = "200 = 11001000 (3 ones)" ] || fail "./exercise 200 should print 200 = 11001000 (3 ones)" "got: $got"
pass "./exercise 200 prints 11001000, 3 ones"
