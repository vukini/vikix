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
rm -f "$t/fail-b"

# Without flock (a machine that hasn't it): as before, no queue, no failure.
mkdir -p "$t/noflock"
for tool in bash sh sleep date mktemp rm cat mv wc sort head awk nproc seq dirname printf; do
  p=$(command -v "$tool" 2>/dev/null) && [ -x "$p" ] && ln -sf "$p" "$t/noflock/$tool"
done
: > "$t/log"
out=$(PATH="$t/noflock" VIKIX_TEST_SLOTS=1 "$t/tests/run.sh" a b 2>&1) && code=0 || code=$?
check "without flock a run goes on as before: $code $(tail -1 <<<"$out")" bash -c "[ $code = 0 ] && grep -q '^all passed: a b' <<<\"\$1\"" _ "$out"

[ "$fail" = 0 ] && echo "queue: runs on one machine share the test slots, a test that wants the machine alone has it, and a run passes or fails as before"
exit "$fail"
