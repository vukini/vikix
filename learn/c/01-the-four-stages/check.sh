# check.sh: 01, the four stages. Runs in your copy of the lesson.
. "$LEARN_LIB"
want=$'SQUARE(1 + 2) = 9\nSQUARE(10 - 4) = 36\n100 / SQUARE(5) = 4'

out=$(build exercise.c ./exercise) || fail "it should compile without a warning" "$out"
pass "it compiles"
for call in 'SQUARE(1 + 2))' 'SQUARE(10 - 4))' '100 / SQUARE(5))'; do
  grep -qF "$call" exercise.c || fail "the printf lines should stay as they were: fix the macro instead" "missing: $call"
done
pass "the printf lines are as they were"
got=$(runs ./exercise) || fail "it should run cleanly" "$got"
[ "$got" = "$want" ] || fail "the answers aren't all right yet (cc -E exercise.c | tail -n 6 shows why)" "got:" "$got" "want:" "$want"
pass "SQUARE gives 9, 36 and 4"
