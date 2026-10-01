# check.sh: 02, what the warnings catch. Runs in your copy of the lesson.
. "$LEARN_LIB"
want=$'longest: 12\nnone: 0\ntotal: 5000000000'

out=$(build exercise.c ./exercise) || fail "it should compile without a warning (each one is an error here)" "$out"
pass "no warnings, without optimising"
# Some warnings come only from the analysis -O2 does: a variable used
# before it's set is one.
out=$(build exercise.c ./.exercise-O2 -O2) || fail "with -O2, gcc finds more: fix that too" "$out"
rm -f ./.exercise-O2
pass "no warnings at -O2 either"
grep -q 'longest(words, 0)' exercise.c && grep -q '"total: ' exercise.c ||
  fail "the program should still print the same three things"
got=$(runs ./exercise) || fail "it should run cleanly" "$got"
[ "$got" = "$want" ] || fail "the output isn't right yet" "got:" "$got" "want:" "$want"
pass "it prints 12, 0 and 5000000000"
