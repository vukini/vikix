# check.sh: 03, the linker. Runs in your copy of the lesson.
. "$LEARN_LIB"

out=$(build exercise.c ./.exercise.o -c) ||
  fail "it doesn't compile yet: does it say what every function it calls is?" "$out"
rm -f ./.exercise.o
pass "it compiles: every function it calls is declared"
rm -f ./exercise
out=$(build exercise.c ./exercise stats.c)
if [ ! -x ./exercise ]; then
  case $out in
    *"undefined reference"*) fail "it compiles, and the linker can't find a name: which one, and what is it called in stats.c?" "$(printf '%s\n' "$out" | grep -o "undefined reference to .*" | sort -u)" ;;
  esac
  fail "it doesn't build with stats.c" "$out"
fi
pass "it links with stats.c"
# LEARN_LESSON is Vikix's copy of the lesson (bin/vikix-learn sets it).
if [ -n "${LEARN_LESSON:-}" ] && ! cmp -s stats.c "$LEARN_LESSON/stats.c"; then
  fail "stats.c should stay as it came: fix exercise.c instead (vikix learn c reset 03 brings it back)"
fi
got=$(runs ./exercise) || fail "it should run cleanly" "$got"
[ "$got" = "mean 6.5, largest 12" ] || fail "the output isn't right yet" "got: $got" "want: mean 6.5, largest 12"
pass "it prints mean 6.5, largest 12"
