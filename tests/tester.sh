#!/usr/bin/env bash
# tests/tester.sh — the tester (vikix agents test), without a screen: a
# made-up project whose tests/run.sh is a stand-in that records what it ran
# and fails when told, three desks in review, and a project with no tests.
#
#   One desk's tests run in its worktree with --changed from where its
#   branch left main, and the result goes into its record as a check by
#   vikix (the failing tests named, the first failure's line) and into its
#   inbox; --log shows the run's output; a tester at work refuses a second;
#   --all merges the desks that changed no file in common onto main in a
#   throwaway worktree, gone afterwards, and tests them once, each check
#   saying with which, while a desk that overlaps another runs alone and is
#   told which it overlaps on; a hand-in (status review) runs the desk's
#   tests by itself, apart from the caller; a project with no tests/run.sh
#   is said so, with no check and no note. A desk joins the batch when it
#   changed no file the batch has, in the order they went to review.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
export TESTER_CALLS="$t/calls" TESTER_FAIL="$t/fail"
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/proc"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}

# A project whose runner is a stand-in: it records where it ran, its words
# and the files there, and fails when the fail file stands.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; mkdir tests
cat > tests/run.sh <<'R'
#!/bin/sh
# A stand-in for a project's runner (it takes --changed REF).
{ printf '%s %s:' "$PWD" "$*"; ls *.md | tr '\n' ' '; echo; } >> "$TESTER_CALLS"
if [ -f "$TESTER_FAIL" ]; then echo "=== spell (1s)"; echo "FAIL: the spell check found 2 words"; echo "FAILED: spell"; exit 1; fi
echo "all passed: spell"
R
chmod +x tests/run.sh; git add log.md tests/run.sh; git commit -q -m first
base=$(git rev-parse HEAD)
for d in a b c; do git worktree add -q "$t/src/book-$d" -b "$d"; done
echo "chapter a" > "$t/src/book-a/a.md"; git -C "$t/src/book-a" add a.md; git -C "$t/src/book-a" commit -q -m a
echo "chapter b" > "$t/src/book-b/b.md"; git -C "$t/src/book-b" add b.md; git -C "$t/src/book-b" commit -q -m b
echo "chapter a, again" > "$t/src/book-c/a.md"; git -C "$t/src/book-c" add a.md; git -C "$t/src/book-c" commit -q -m c
cd "$here"
records="$HOME/.local/state/vikix/office/desks"

# --- One desk --------------------------------------------------------------------------------
VIKIX_TESTER=0 agents handoff set --desk a --task "Chapter a" >/dev/null
out=$(agents test --log a)
check "no run yet is said: $out" grep -q 'book-a: no test run yet (vikix agents test book-a)' <<<"$out"
out=$(agents test a)
check "a desk's tests run, and pass: $out" grep -qE "book-a: tests passed \(tests/run.sh --changed ${base:0:7}, [0-9]+ s\)" <<<"$out"
check "in its worktree, with --changed from where its branch left main: $(cat "$t/calls")" \
  grep -q "^$t/src/book-a --changed $base:a.md log.md" "$t/calls"
# A release's tests go first: .claude/release's note in the repository (the
# file its pid, alive: this shell's) says testing while they run.
q="$t/src/book/.git/vikix-release-queue"; mkdir -p "$q"
printf 'topic-x\ntesting (quick)\n%s\n\n\n' "$(date +%s)" > "$q/$$"
out=$(VIKIX_RELEASE_WAIT=2 agents test a)
check "the tester waits while a release of the project is testing, then runs: $out" \
  bash -c 'grep -q "book-a: a release of topic-x is testing; waiting for it" <<<"$1" && grep -q "book-a: tests passed" <<<"$1"' _ "$out"
printf 'topic-x\nwaiting for its turn\n%s\n\n\n' "$(date +%s)" > "$q/$$"
out=$(VIKIX_RELEASE_WAIT=2 agents test a)
check "a release waiting for its turn holds nothing: $out" not grep -q "waiting for it" <<<"$out"
rm -rf "$q"
out=$(agents handoff a)
check "the record has the check, by vikix, on the desk's commit: $(grep 'tests/run.sh' <<<"$out")" \
  grep -qE 'passed  tests/run.sh --changed [0-9a-f]{7}  \(vikix, just now, on [0-9a-f]{7}, clean tree\)  fresh' <<<"$out"
check "and the inbox has the word for the worker" grep -q '^  vikix (just now): tests passed (tests/run.sh --changed' <<<"$out"
touch "$TESTER_FAIL"
out=$(agents test a)
check "a failure names the tests and where to read them: $out" \
  grep -q 'book-a: tests: 1 failed (spell); vikix agents test --log book-a shows them' <<<"$out"
out=$(agents handoff a)
check "the check failed, with the first failure's line: $(grep -A1 'FAILED  tests' <<<"$out" | tail -1)" \
  bash -c 'grep -q "^  FAILED  tests/run.sh --changed" <<<"$1" && grep -q "failed: spell; FAIL: the spell check found 2 words" <<<"$1"' _ "$out"
out=$(agents test --log a)
check "--log shows the run's output: $(head -2 <<<"$out" | tr '\n' ' ')" bash -c 'grep -q "^=== spell" <<<"$1" && grep -q "^FAILED: spell" <<<"$1"' _ "$out"
rm -f "$TESTER_FAIL"
mkdir -p "$HOME/.local/state/vikix/office/tests"
id_a=$(ls "$records" | head -1 | sed 's/.json//')
echo "$$ $(date +%s)" > "$HOME/.local/state/vikix/office/tests/$id_a.running"
out=$(agents test a)
check "a tester at work on the desk refuses a second: $out" grep -q "book-a: a tester is at work there already (pid $$)" <<<"$out"
rm -f "$HOME/.local/state/vikix/office/tests/$id_a.running"

# --- Every desk in review: a batch of the disjoint, the overlapping alone ---------------------
for d in a b c; do VIKIX_TESTER=0 agents handoff set --desk "$d" --task "Chapter $d" --status review >/dev/null; done
: > "$t/calls"
out=$(agents test --all)
check "the two that changed no file in common are tested together, the third alone: $(tr '\n' '|' <<<"$out")" \
  bash -c 'grep -q "book-a: tests passed (tests/run.sh --changed .* (batch), .*\[with .*/book-b\]" <<<"$1" && grep -q "book-b: tests passed .*\[with .*/book-a\]" <<<"$1" && grep -q "book-c: tests passed .*\[overlaps .*/book-a on a.md\]" <<<"$1"' _ "$out"
check "the batch ran once, in a throwaway worktree holding both desks' files, the other alone in its own: $(cut -c1-120 "$t/calls" | tr '\n' '|')" \
  bash -c '[ "$(wc -l < "$1")" = 2 ] && grep -q "vikix-tester-.*/batch --changed .*:a.md b.md log.md" "$1" && grep -q "^$2/src/book-c --changed .*:a.md log.md" "$1"' _ "$t/calls" "$t"
check "the throwaway worktree is gone" test -z "$(git -C "$t/src/book" worktree list | grep vikix-tester || true)"
check "each desk's record says with which it was tested" \
  bash -c 'grep -q "with .*/book-b; passed" <<<"$(python3 "$1" handoff a)" && grep -q "overlaps .*/book-a on a.md; passed" <<<"$(python3 "$1" handoff c)"' _ "$here/bin/vikix-agents"

# --- A hand-in runs the tests by itself ------------------------------------------------------
proc 1001 claude "$t/src/book-a"
: > "$t/calls"
as 1001 handoff set --status working >/dev/null
out=$(as 1001 handoff set --status review --next "merge")
check "the agent hands in: $out" grep -q 'status review' <<<"$out"
for _ in $(seq 1 60); do grep -q "book-a --changed" "$t/calls" 2>/dev/null && break; sleep 0.25; done
check "and the tests ran by themselves, in its worktree: $(cat "$t/calls")" grep -q "^$t/src/book-a --changed $base:a.md log.md" "$t/calls"
for _ in $(seq 1 40); do grep -q 'tests passed' <<<"$(agents handoff a | tail -3)" && break; sleep 0.25; done
check "the result reached its record and its inbox" grep -q '^  vikix (just now): tests passed' <<<"$(agents handoff a)"
: > "$t/calls"
as 1001 handoff set --summary "more" >/dev/null; sleep 1
check "a status that stayed review runs nothing again" test ! -s "$t/calls"

# --- A project with no tests ----------------------------------------------------------------
git -C "$t/src" init -q -b main novel; cd "$t/src/novel"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; git add log.md; git commit -q -m first; git worktree add -q "$t/src/novel-x" -b x; cd "$here"
VIKIX_TESTER=0 agents handoff set --desk x --task "X" --status review >/dev/null
out=$(agents test x)
check "a project with no tests/run.sh is said so: $out" grep -q 'novel-x: no tests/run.sh in this project, nothing to run' <<<"$out"
check "with no check and no note" bash -c 'grep -q "^Checks: none recorded" <<<"$1" && ! grep -q "Notes waiting" <<<"$1"' _ "$(agents handoff x)"
out=$(agents test --all)
check "--all skips it the same way, after the others" grep -q 'novel-x: no tests/run.sh' <<<"$out"

[ "$fail" = 0 ] && echo "tester: ok (a desk's tests in its worktree, the check and the note; --log; a batch of the disjoint desks on a throwaway worktree, the overlapping alone; a hand-in runs them by itself; no runner, no check)"
exit $fail
