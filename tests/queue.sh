#!/usr/bin/env bash
# tests/queue.sh — tests/run.sh's slots: runs on one machine share them.
#
#   Two runs at once with one slot: no two tests overlap; with two slots,
#   never more than two at a time; a test of the `alone` list runs while
#   nothing else does, in either run; a run still passes and fails as its
#   tests do; without flock it runs as before.
#
# The tests here are stand-ins that note when they start and end.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

mkdir -p "$t/tests"
cp "$here/tests/run.sh" "$t/tests/"
for name in a b c d e f soak; do
  cat > "$t/tests/$name.sh" <<END
#!/bin/sh
echo "$name start \$(date +%s.%N)" >> "$t/log"
sleep 0.6
echo "$name end \$(date +%s.%N)" >> "$t/log"
[ ! -e "$t/fail-$name" ]
END
done
chmod +x "$t/tests/"*.sh
export VIKIX_TEST_SLOTS_DIR="$t/slots"

# most LOG: the most tests running at one moment; overlaps LOG NAME: how
# many others ran while NAME did.
most() { python3 - "$1" <<'PY'
import sys
ev=[]
for line in open(sys.argv[1]):
    name, what, at = line.split()
    ev.append((float(at), 1 if what == "start" else -1))
n = top = 0
for _, d in sorted(ev):
    n += d; top = max(top, n)
print(top)
PY
}
overlaps() { python3 - "$1" "$2" <<'PY'
import sys
spans={}
for line in open(sys.argv[1]):
    name, what, at = line.split()
    spans.setdefault(name, {})[what] = float(at)
me = spans[sys.argv[2]]
print(sum(1 for n, s in spans.items() if n != sys.argv[2] and s["start"] < me["end"] and me["start"] < s["end"]))
PY
}

: > "$t/log"
VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a b c > "$t/one.out" 2>&1 &
VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" d e f > "$t/two.out" 2>&1 &
wait
check "two runs, one slot: six tests ran: $(grep -c start "$t/log")" test "$(grep -c end "$t/log")" = 6
check "and never two at a time: $(most "$t/log")" test "$(most "$t/log")" = 1
check "each run still says its own passed: $(tail -1 "$t/one.out")" grep -q '^all passed: a b c$' "$t/one.out"

: > "$t/log"
VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a b c > "$t/one.out" 2>&1 &
VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" d e f > "$t/two.out" 2>&1 &
wait
check "two slots: two at a time, never three: $(most "$t/log")" test "$(most "$t/log")" = 2

: > "$t/log"
VIKIX_TEST_SLOTS=4 "$t/tests/run.sh" a soak > "$t/one.out" 2>&1 &
VIKIX_TEST_SLOTS=4 "$t/tests/run.sh" b c d e > "$t/two.out" 2>&1 &
wait
check "a test that wants the machine to itself runs while nothing else does: $(overlaps "$t/log" soak) beside it" test "$(overlaps "$t/log" soak)" = 0
check "and the others ran, side by side: $(most "$t/log")" test "$(most "$t/log")" -ge 2

: > "$t/log"; touch "$t/fail-b"
out=$(VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a b 2>&1) && code=0 || code=$?
check "a run fails as its tests do: $code $(tail -1 <<<"$out")" bash -c "[ $code = 1 ] && grep -qx 'FAILED: b' <<<\"\$1\"" _ "$out"
check "and says the load as the run began, since a load past the cores fails a timing check alone: $(grep load <<<"$out")" \
  grep -qE '^\(load [0-9.]+ [0-9.]+ [0-9.]+ on [0-9]+ cores as the run began\)$' <<<"$out"
rm -f "$t/fail-b"
# Stopped from outside (a timeout on the run) while a test waits for a slot: what passed is
# said, with what was running and what never ran, rather than lost (two runs hit their
# deadline waiting for the alone tests, 2026-10-11).
cat > "$t/tests/slowb.sh" <<END
#!/bin/sh
sleep 20
END
chmod +x "$t/tests/slowb.sh"
out=$(VIKIX_TEST_SLOTS=1 VIKIX_TEST_JOBS=1 timeout 4 "$t/tests/run.sh" a slowb c 2>&1) && code=0 || code=$?
check "a run stopped before its end says what passed, what was stopped and what never ran: $code $(tr '\n' '|' <<<"$out")" \
  bash -c "[ $code = 124 ] && grep -q '^stopped before the end (load .* as the run began):' <<<\"\$1\" && grep -q '^  running, stopped: slowb' <<<\"\$1\" && grep -q '^  not run: c (waiting for a slot or for the machine: other runs were testing)' <<<\"\$1\" && grep -q '^  passed: a' <<<\"\$1\"" _ "$out"
sleep 0.5
check "and its tests are gone with it" bash -c '! pgrep -u "$(id -u)" -f "^/bin/sh $1" >/dev/null' _ "$t/tests/slowb.sh"

# Each test leaves a note of what it does, for vikix agents: with one slot
# taken by a slow test, a run's tests all wait, and the agent above that run
# is waiting for a test slot; a process no agent is above is found by the
# folder it works in; the notes are gone when the tests end.
cat > "$t/tests/slow.sh" <<END
#!/bin/sh
sleep 3
END
chmod +x "$t/tests/slow.sh"
export HOME="$t/home"; mkdir -p "$HOME"    # no projects, no seats: the notes alone
VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" slow > "$t/one.out" 2>&1 &
sleep 0.5
mkdir -p "$t/desk"   # the agent's own folder: the other run isn't under it
# (Two commands, or bash would exec the run and the agent would be the run itself.)
( cd "$t/desk" && exec -a claude bash -c "VIKIX_TEST_SLOTS=1 '$t/tests/run.sh' a b; exit \$?" ) > "$t/two.out" 2>&1 &
agent=$!
sleep 1
# Read the actual live runner, not its completed output: two simultaneous
# runs have separate plans, and a slot wait has no elapsed runtime.
python3 - "$here" "$t" <<'PYTEST' || fail=1
import importlib.util
from importlib.machinery import SourceFileLoader
import sys
spec = importlib.util.spec_from_loader('progress_agents', SourceFileLoader('progress_agents', sys.argv[1] + '/bin/vikix-agents'))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
runs = a.test_progress(sys.argv[2])
assert len(runs) == 2, runs
rows = [row for run in runs for row in run['tests']]
assert sorted(row['state'] for row in rows) == ['queued', 'queued', 'running'], rows
assert all(row['elapsed'] == 0 and not row['stalled'] for row in rows if row['state'] == 'queued'), rows
PYTEST
states=$(cat "$t/slots/notes"/* 2>/dev/null | awk 'NR % 3 == 1' | sort | tr '\n' ' ')
check "one test runs and two wait, each with a note: $states" test "$states" = "running waiting waiting "
held=$(python3 "$here/bin/vikix-agents" --waits "$agent" 2>&1)
check "the agent above the run that waits is waiting for a test slot: $held" \
  grep -qE "^$agent	waiting for a test slot	its tests a, b wait for a slot since [0-9]{2}:[0-9]{2}: other runs are testing on this machine\$" <<<"$held"
( cd "$t/tests" && exec sleep 20 ) &
bystander=$!
held=$(python3 "$here/bin/vikix-agents" --waits "$bystander" 2>&1)
check "a process no agent is above is found by its folder, with every run's tests there: $held" \
  grep -qE "^$bystander	testing	its tests: 1 running, 2 waiting for a slot since [0-9]{2}:[0-9]{2}\$" <<<"$held"
kill "$bystander" 2>/dev/null; wait "$bystander" 2>/dev/null || true
wait "$agent" || true; wait
check "the notes are gone when the tests end: $(ls "$t/slots/notes" | tr '\n' ' ')" test -z "$(ls "$t/slots/notes")"

check "run progress notes are cleaned up" test -z "$(ls "$t/slots/runs")"

# Without flock (a machine that hasn't it): as before, no queue, no failure.
mkdir -p "$t/noflock"
for tool in bash sh sleep date mktemp rm cat mv wc sort head awk nproc seq dirname printf; do
  p=$(command -v "$tool" 2>/dev/null) && [ -x "$p" ] && ln -sf "$p" "$t/noflock/$tool"
done
: > "$t/log"
out=$(PATH="$t/noflock" VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a b 2>&1) && code=0 || code=$?
check "without flock a run goes on as before: $code $(tail -1 <<<"$out")" bash -c "[ $code = 0 ] && grep -q '^all passed: a b' <<<\"\$1\"" _ "$out"

# A run at a desk records itself in the desk's record (vikix agents handoff
# check), passed or failed, by the words it was run with; not a run a test
# started (VIKIX_TEST_RUN set as it began), and nothing said either way.
mkdir -p "$t/bin"
printf '#!/bin/sh\necho "$@" >> "%s/agents-calls"\n' "$t" > "$t/bin/vikix-agents"; chmod +x "$t/bin/vikix-agents"
: > "$t/agents-calls"
env -u VIKIX_TEST_RUN VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a b > "$t/rec.out" 2>&1
check "a run that passed is recorded at the desk, by its words: $(cat "$t/agents-calls")" \
  grep -q "^handoff check tests/run.sh a b --ok --note 2 tests in [0-9]* s (load .* as the run began) --desk $t$" "$t/agents-calls"
: > "$t/agents-calls"; touch "$t/fail-b"
env -u VIKIX_TEST_RUN VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a b > "$t/rec.out" 2>&1 || true
check "a failed one too, naming the tests: $(cat "$t/agents-calls")" grep -q "^handoff check tests/run.sh a b --failed --note failed: b (load" "$t/agents-calls"
rm -f "$t/fail-b"; : > "$t/agents-calls"
VIKIX_TEST_RUN=1 VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a > /dev/null 2>&1
check "a run a test started (VIKIX_TEST_RUN set) records nothing" test ! -s "$t/agents-calls"

# Once more, alone: a screen test (one naming tests/lib/wm.sh or Xvfb) that
# fails runs again by itself, once; passing then it counts as passed, said,
# and noted in the flakes log with its first FAIL lines; failing again it
# fails. A plain test isn't tried again, nor is a screen test with
# VIKIX_TEST_RETRY=0, nor a single named test; a retry runs with the
# machine to itself (no other test of any run beside it).
# x: a stand-in screen test that fails once (its marker removed as it fails), then passes.
cat > "$t/tests/x.sh" <<END
#!/bin/sh
# a stand-in for a test that starts an Xvfb
echo "x start \$(date +%s.%N)" >> "$t/log"
sleep 0.6
echo "x end \$(date +%s.%N)" >> "$t/log"
[ -e "$t/fail-x" ] && { rm "$t/fail-x"; echo "FAIL: typed too soon"; exit 1; }
exit 0
END
chmod +x "$t/tests/x.sh"
export VIKIX_TEST_FLAKES="$t/flakes.log"
: > "$t/log"; touch "$t/fail-x"
out=$(VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a x b 2>&1) && code=0 || code=$?
check "a screen test that fails once passes on its second run alone: $code" test "$code" = 0
check "and the run says so: $(grep -c 'once more alone' <<<"$out")" \
  bash -c "grep -q '^=== x, once more alone' <<<\"\$1\" && grep -q '^=== x passed once more alone' <<<\"\$1\" && grep -q '^(passed only once more alone, a timing flake: x;' <<<\"\$1\" && grep -q '^all passed: a x b' <<<\"\$1\"" _ "$out"
check "the first failure is still shown whole" grep -q '^FAIL: typed too soon' <<<"$out"
check "the flake is noted with its FAIL line: $(cat "$t/flakes.log" 2>/dev/null)" grep -qP '^\S+\t\S+\tx\tload .*\tFAIL: typed too soon' "$t/flakes.log"
check "the retry ran alone: $(overlaps "$t/log" x) others beside it on its second run" test "$(python3 - "$t/log" <<'PY2'
import sys
spans=[]
for line in open(sys.argv[1]):
    name, what, at = line.split()
    if name == "x" and what == "start": spans.append({})
    if name == "x": spans[-1][what] = float(at)
me = spans[-1]
others=[]
cur={}
for line in open(sys.argv[1]):
    name, what, at = line.split()
    if name == "x": continue
    cur.setdefault(name, {})[what] = float(at)
print(sum(1 for n, s in cur.items() if s["start"] < me["end"] and me["start"] < s["end"]))
PY2
)" = 0
touch "$t/fail-x"
out=$(VIKIX_TEST_RETRY=0 VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a x 2>&1) && code=0 || code=$?
check "VIKIX_TEST_RETRY=0 keeps the first answer: $code" bash -c "[ $code != 0 ] && ! grep -q 'once more alone' <<<\"\$1\" && grep -q '^FAILED: x' <<<\"\$1\"" _ "$out"
touch "$t/fail-x"
out=$(VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" x 2>&1) && code=0 || code=$?
check "a single named test isn't tried again: $code" bash -c "[ $code != 0 ] && ! grep -q 'once more alone' <<<\"\$1\"" _ "$out"
touch "$t/fail-b"
out=$(VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a b 2>&1) && code=0 || code=$?
check "a plain test that fails isn't tried again: $code" bash -c "[ $code != 0 ] && ! grep -q 'once more alone' <<<\"\$1\" && grep -q '^FAILED: b' <<<\"\$1\"" _ "$out"
rm -f "$t/fail-b"
# y: a screen test that fails every time.
printf '#!/bin/sh\n# starts an Xvfb\necho "FAIL: always"; exit 1\n' > "$t/tests/y.sh"; chmod +x "$t/tests/y.sh"
out=$(VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" a y 2>&1) && code=0 || code=$?
check "a screen test that fails again alone fails the run: $code" \
  bash -c "[ $code != 0 ] && grep -q '^=== y failed again alone' <<<\"\$1\" && grep -q '^FAILED: y' <<<\"\$1\" && ! grep -q 'passed only once more' <<<\"\$1\"" _ "$out"
check "and isn't noted as a flake" test "$(grep -c . "$t/flakes.log")" = 1

# k: a test that would see the machine's keys and agent settings; the
# runner drops them first (plans/DESIGN-ci.md 5), and keeps its own.
printf '#!/bin/sh\necho "k sees ${ANTHROPIC_API_KEY:-none} ${GITHUB_TOKEN:-none} ${CLAUDECODE:-none} ${OLLAMA_HOST:-none} ${VIKIX_TEST_RUN:-none}"\n' > "$t/tests/k.sh"; chmod +x "$t/tests/k.sh"
out=$(ANTHROPIC_API_KEY=sk-test GITHUB_TOKEN=ghp-test CLAUDECODE=1 OLLAMA_HOST=127.0.0.1:1 VIKIX_TEST_SLOTS=2 "$t/tests/run.sh" k 2>&1) && code=0 || code=$?
check "a test sees none of the machine's keys or agent settings: $code: $out" grep -q '^k sees none none none none 1$' <<<"$out"

[ "$fail" = 0 ] && echo "queue: runs on one machine share the test slots, a test that wants the machine alone has it, each leaves a note vikix agents reads, a run at a desk records itself, a screen test that fails runs once more alone and is noted as a flake when it passes then, and a run passes or fails as before"
exit "$fail"
