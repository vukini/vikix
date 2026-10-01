# check.sh: 04, make. Runs in your copy of the lesson; builds in a scratch
# copy of it, so your folder isn't filled with .o files.
. "$LEARN_LIB"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cp Makefile main.c words.c words.h "$scratch/" 2>/dev/null || fail "Makefile, main.c, words.c and words.h should all be here"
cd "$scratch" || exit 1
later() { touch -d "@$(( $(date +%s) + $1 ))" "$2"; }   # a change, a few seconds on

out=$(make 2>&1) || fail "make should build wordcount" "$out"
[ -x wordcount ] || fail "make should build a program called wordcount" "$out"
got=$(runs ./wordcount)
[ "$got" = "5 words" ] || fail "wordcount should print 5 words" "got: $got"
pass "make builds wordcount, which counts 5 words"
[ -f main.o ] && [ -f words.o ] ||
  fail "each .c file should be compiled on its own, to main.o and words.o, then linked" "after make, there's: $(ls | tr '\n' ' ')"
grep -q -- '-Wall' <<<"$out" || fail "compile with \$(CFLAGS), so the warnings are on" "$out"
pass "main.c and words.c are compiled on their own, with the warnings on"
out=$(make -n 2>&1)
[ -z "$out" ] || [[ $out == *"up to date"* ]] || [[ $out == *"Nothing to be done"* ]] ||
  fail "a second make, with nothing changed, should do nothing" "it would run:" "$out"
pass "with nothing changed, make does nothing"
later 5 words.c
out=$(make -n 2>&1)
[[ $out == *"-c words.c"* ]] || fail "after words.c changes, make should compile words.c again" "it would run:" "$out"
[[ $out != *"-c main.c"* ]] || fail "after words.c changes, main.c hasn't: it shouldn't be compiled again" "it would run:" "$out"
[[ $out == *"-o wordcount"* ]] || fail "and wordcount should be linked again" "it would run:" "$out"
pass "a change to words.c compiles only words.c, then links"
make >/dev/null 2>&1
later 10 words.h
out=$(make -n 2>&1)
[[ $out == *"-c words.c"* && $out == *"-c main.c"* ]] ||
  fail "after words.h changes, both .c files include it: both should be compiled again" "it would run:" "$out"
pass "a change to words.h compiles both"
make clean >/dev/null 2>&1 || fail "make clean should work"
[ ! -e wordcount ] && [ ! -e main.o ] && [ ! -e words.o ] || fail "make clean should remove wordcount and the .o files" "left: $(ls | tr '\n' ' ')"
pass "make clean tidies up"
