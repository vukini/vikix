#!/usr/bin/env bash
# tests/learn.sh — vikix learn and its C course.
#
#   The course: every lesson has its files, and an exercise with the NOT
#   DONE line; its example compiles without a warning and runs; every
#   output lesson.md quotes (after a <!-- output: COMMAND --> line) is what
#   COMMAND prints now (the evidence rule: a gcc that behaves differently
#   fails here, not in front of a reader); the exercise as shipped fails
#   its check, and the worked answer (solution.c) passes it.
#
#   The runner: lessons are copied once, never over your work, without the
#   checks or the answers; list, go, hint (one at a time, and no further),
#   check (the NOT DONE gate, done, on to the next, the last lesson stays),
#   reset; watch checks on save and moves on; an unknown course is refused.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
command -v cc >/dev/null || { echo "(learn needs a C compiler; skipped here)"; exit 0; }
t=$(mktemp -d)
watch_pid=
trap 'kill "$watch_pid" 2>/dev/null || true; rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
course="$here/learn/c"

# --- the course ------------------------------------------------------------------
for dir in "$course"/[0-9][0-9]-*/; do
  l=$(basename "$dir")
  for f in lesson.md example.c exercise.c check.sh hints.md solution.c; do
    check "$l should have $f" test -f "$dir/$f"
  done
  check "$l's exercise should have the NOT DONE line" grep -qx '// NOT DONE' "$dir/exercise.c"
  check "$l's answer shouldn't" bash -c "! grep -qx '// NOT DONE' '$dir/solution.c'"

  w="$t/c-$l"; cp -r "$dir" "$w"
  ( cd "$w" && cc -std=c17 -Wall -Wextra -pedantic -Werror -g -o example example.c ) > "$t/out" 2>&1 ||
    { echo "FAIL: $l's example should compile without a warning:"; cat "$t/out"; fail=1; }
  check "$l's example should run" bash -c "cd '$w' && ./example >/dev/null"
  # The evidence rule: each quoted output, made again.
  python3 - "$w" <<'PY' > "$t/out" 2>&1 || { echo "FAIL: $l's lesson.md quotes an output its command doesn't print now:"; cat "$t/out"; fail=1; }
import re, subprocess, sys
d = sys.argv[1]
lines = open(f"{d}/lesson.md").read().split("\n")
bad, seen = 0, 0
for i, line in enumerate(lines):
    m = re.fullmatch(r"<!-- output: (.+) -->", line.strip())
    if not m:
        continue
    seen += 1
    assert lines[i + 1].startswith("```"), f"no block after the marker on line {i + 1}"
    end = next(j for j in range(i + 2, len(lines)) if lines[j].startswith("```"))
    quoted = "\n".join(lines[i + 2:end])
    got = subprocess.run(["bash", "-c", m.group(1)], cwd=d, capture_output=True, text=True).stdout.rstrip("\n")
    if got != quoted:
        bad += 1
        print(f"  {m.group(1)}\n  quoted:\n{quoted}\n  now:\n{got}")
assert seen, "no quoted outputs at all"
sys.exit(bad)
PY
  # As shipped, the exercise isn't done; the answer is.
  check "$l as shipped shouldn't pass its check" \
    bash -c "! (cd '$w' && LEARN_LIB='$course/lib.sh' bash '$dir/check.sh') >/dev/null 2>&1"
  cp "$dir/solution.c" "$w/exercise.c"
  ( cd "$w" && LEARN_LIB="$course/lib.sh" bash "$dir/check.sh" ) > "$t/out" 2>&1 ||
    { echo "FAIL: $l's answer should pass its check:"; cat "$t/out"; fail=1; }
done

# --- wrong answers the sanitizers catch (where they're installed) --------------------
if printf 'int main(void){return 0;}\n' | cc -fsanitize=address,undefined -x c -o /dev/null - 2>/dev/null; then
  w="$t/wrong-02"; cp -r "$course/02-the-design-recipe" "$w"
  # Negating first: -INT_MIN overflows, which only UBSan sees.
  sed 's|^    int count = 1;$|    if (n < 0)\n        n = -n;\n    int count = 1;|' "$course/02-the-design-recipe/solution.c" > "$w/exercise.c"
  out=$(cd "$w" && LEARN_LIB="$course/lib.sh" bash "$course/02-the-design-recipe/check.sh" 2>&1) &&
    { echo "FAIL: digits that negates INT_MIN passed"; fail=1; }
  check "UBSan should name the overflow, briefly: $out" grep -q 'exercise.c:[0-9]*: runtime error: negation of -2147483648' <<<"$out"
  check "and leave out the C library's frames: $out" bash -c "! grep -q 'libc' <<<\"\$1\"" _ "$out"
  w="$t/wrong-03"; cp -r "$course/03-pointers-and-strlen" "$w"
  # Looking one char past the '\0': only ASan sees it.
  sed "s|^    while (\*p != '\\\\0')$|    while (*p != '\\\\0' \|\| p[1] != '\\\\0')|" "$course/03-pointers-and-strlen/solution.c" > "$w/exercise.c"
  grep -q 'p\[1\]' "$w/exercise.c" || { echo "FAIL: the test couldn't make its wrong my_strlen"; fail=1; }
  out=$(cd "$w" && LEARN_LIB="$course/lib.sh" bash "$course/03-pointers-and-strlen/check.sh" 2>&1) &&
    { echo "FAIL: my_strlen reading past the end passed"; fail=1; }
  check "ASan should say where it read: $out" grep -q 'in my_strlen, exercise.c:[0-9]' <<<"$out"
  check "without the shadow-byte map: $out" bash -c "! grep -q 'Shadow' <<<\"\$1\"" _ "$out"
else
  echo "(no sanitizers here: their wrong answers are tested where libsanitizer is installed)"
fi

# --- the runner ----------------------------------------------------------------------
export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_LEARN_NO_SNAPSHOT=1 VIKIX_LEARN_POLL=0.1
mkdir -p "$HOME"
vl() { bash "$here/bin/vikix-learn" "$@"; }
work="$HOME/learn/c"
first=$(basename "$(ls -d "$course"/01-*/)")
second=$(basename "$(ls -d "$course"/02-*/)")
last=$(basename "$(ls -d "$course"/[0-9][0-9]-*/ | tail -n 1)")

out=$(vl 2>&1)
check "vikix learn should list the courses: $out" grep -q 'courses: c' <<<"$out"
vl nope > "$t/out" 2>&1 && { echo "FAIL: an unknown course should be refused"; fail=1; }
vl '../c' > "$t/out" 2>&1 && { echo "FAIL: a course named like a path should be refused"; fail=1; }

out=$(vl c list 2>&1)
check "list should mark the first lesson as current: $out" grep -q "\[ \] > $first" <<<"$out"
check "the lessons should be copied" test -f "$work/$first/exercise.c"
check "the checks shouldn't be copied" test ! -e "$work/$first/check.sh"
check "the answers shouldn't be copied" test ! -e "$work/$first/solution.c"
echo '/* mine */' >> "$work/$first/exercise.c"
vl c list >/dev/null 2>&1
check "a second run shouldn't overwrite your work" grep -qF '/* mine */' "$work/$first/exercise.c"

# Hints: one at a time, never past the last.
out=$(vl c hint 2>&1)
check "the first hint should come first: $out" grep -q '^:: hint 1 of' <<<"$out"
n=$(( $(grep -c '^---$' "$course/$first/hints.md") + 1 ))
for _ in $(seq 1 "$n"); do out=$(vl c hint 2>&1); done
check "hints should stop at the last: $out" grep -q "^:: hint $n of $n" <<<"$out"

# check: failing, then passing with NOT DONE left, then done.
vl c check > "$t/out" 2>&1 && { echo "FAIL: the shipped exercise passed"; fail=1; }
check "a failing check should say NOT YET" grep -q 'NOT YET' "$t/out"
{ echo '// NOT DONE'; cat "$course/$first/solution.c"; } > "$work/$first/exercise.c"
rc=0; vl c check > "$t/out" 2>&1 || rc=$?
check "passing with NOT DONE left should say so (rc 2, got $rc)" test "$rc" = 2
check "and name the line to delete" grep -q 'delete the NOT DONE line' "$t/out"
cp "$course/$first/solution.c" "$work/$first/exercise.c"
vl c check > "$t/out" 2>&1 || { echo "FAIL: the answer should pass:"; cat "$t/out"; fail=1; }
out=$(vl c list 2>&1)
check "the lesson should be ticked: $out" grep -q "\[x\]   $first" <<<"$out"
check "and the next one current" grep -q "\[ \] > $second" <<<"$out"

# go, and the last lesson stays current when it's done.
vl c go "${last%%-*}" >/dev/null 2>&1
cp "$course/$last/solution.c" "$work/$last/exercise.c"
vl c check >/dev/null 2>&1 || { echo "FAIL: the last lesson's answer should pass"; fail=1; }
check "the last lesson should stay current" test "$(cat "$VIKIX_STATE/learn/c/current")" = "$last"
vl c check >/dev/null 2>&1 || { echo "FAIL: checking the finished last lesson again should still work"; fail=1; }

# reset: as it came.
vl c reset "${last%%-*}" >/dev/null 2>&1
check "reset should bring the exercise back as it came" cmp -s "$course/$last/exercise.c" "$work/$last/exercise.c"

# watch: a save is checked, and passing moves on.
vl c go "${second%%-*}" >/dev/null 2>&1
vl c > "$t/watch" 2>&1 &
watch_pid=$!
for _ in $(seq 1 100); do grep -q 'watching' "$t/watch" && break; sleep 0.1; done
cp "$course/$second/solution.c" "$work/$second/exercise.c"
for _ in $(seq 1 200); do grep -q "lesson 3 of" "$t/watch" && break; sleep 0.1; done
kill "$watch_pid" 2>/dev/null || true
check "watch should check a save and mark the lesson done: $(tail -5 "$t/watch")" grep -q "lesson $second: done" "$t/watch"
check "and show the next lesson" grep -q "lesson 3 of" "$t/watch"

[ "$fail" = 0 ] && echo "learn: every C lesson's example and quoted output hold, its exercise fails and its answer passes; the runner copies once, checks, hints, moves on, resets and watches"
exit "$fail"
