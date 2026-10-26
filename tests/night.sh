#!/usr/bin/env bash
# tests/night.sh — .claude/night-tests runs the whole set at night and tells
# the morning: it waits for a free machine (no test of another run, no
# release under way, the load under the cores, on mains power), judges the
# run by its exit AND its "all passed" line, writes one line the bar and the
# doctor read, keeps the logs, and says a night that didn't pass once.
#
# A stand-in runner does what a file tells it; the machine's looks are
# pointed at made-up files (the slots' notes, a release lock of a made-up
# repository, a loadavg, a power supply); notify-send and vikix-updates are
# stand-ins on PATH that write down that they were called.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
no() { ! "$@"; }
git_q() { git -c user.name=t -c user.email=t@t "$@"; }

# The made-up repository the night runs in, with its runner.
repo="$t/repo"
mkdir -p "$repo/tests" "$t/bin" "$t/slots/notes" "$t/power/BAT0" "$t/power/AC" "$t/state"
printf '0.72.200\n' > "$repo/VERSION"
cat > "$repo/tests/run.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$t/runner-args"
case \$(cat "$t/runner-mode") in
  pass)   echo "=== lint (1s)"; echo "all passed: lint lisp night"; exit 0 ;;
  flaky)  echo "(passed only once more alone, a timing flake: docs; noted in /x/test-flakes.log)"; echo "all passed: lint docs"; exit 0 ;;
  fail)   echo "=== palette (3s)"; echo "FAIL: a thing"; echo "FAILED: palette docs"; exit 1 ;;
  silent) exit 0 ;;
  hang)   trap 'echo "stopped before the end:"; echo "  FAILED: viri"; exit 124' TERM; sleep 60 & wait \$!; exit 0 ;;
esac
EOF
chmod +x "$repo/tests/run.sh"
git_q -C "$repo" init -q && git_q -C "$repo" add -A && git_q -C "$repo" commit -q -m one
sha=$(git -C "$repo" rev-parse HEAD)
printf 'Battery\n' > "$t/power/BAT0/type"
printf 'Mains\n' > "$t/power/AC/type"; printf '1\n' > "$t/power/AC/online"
printf '0.50 0.40 0.30 1/100 1\n' > "$t/loadavg"
printf '#!/bin/sh\necho "$*" >> "%s/notified"\n' "$t" > "$t/bin/notify-send"
printf '#!/bin/sh\necho called >> "%s/updates-called"\n' "$t" > "$t/bin/vikix-updates"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" XDG_STATE_HOME="$t/state" DISPLAY=:7 \
       VIKIX_NIGHT_REPO="$repo" VIKIX_TEST_SLOTS_DIR="$t/slots" VIKIX_POWER_SUPPLY="$t/power" VIKIX_LOADAVG="$t/loadavg" \
       VIKIX_NIGHT_POLL=1 VIKIX_NIGHT_LIMIT=2
night() { out=$("$here/.claude/night-tests" "$@" 2>&1) && code=0 || code=$?; }
status_file="$t/state/vikix/tests/night"
verdict() { cut -f4 "$status_file"; }
detail() { cut -f5 "$status_file"; }
notified() { grep -c . "$t/notified" 2>/dev/null || echo 0; }

echo "--- nothing yet"
night --status
check "no run yet is said, exit 2: $code: $out" test "$code" = 2
grep -q '^no night run yet' <<<"$out" || { echo "FAIL: $out"; fail=1; }

echo "--- the machine isn't free: not run, with why"
printf 'running\nviri\n%s\n' "$(date +%s)" > "$t/slots/notes/$$"   # a live test of another run
printf 'pass\n' > "$t/runner-mode"
night --now
check "a test of another run: not-run, exit 2: $code: $out" test "$code" = 2
check "the verdict" test "$(verdict)" = not-run
check "with the reason: $(detail)" grep -q "^the machine wasn't free: 1 test(s) of other runs on the machine$" <<<"$(detail)"
check "the runner never ran" no test -e "$t/runner-args"
check "said in a notification once: $(notified)" test "$(notified)" = 1
check "naming the verdict and where to look" grep -q "tests not-run: the machine wasn't free.*--status" "$t/notified"
check "the bar refreshed" test -f "$t/updates-called"
check "the commit and version in the line: $(cat "$status_file")" grep -q "^$(date +%Y%m%d)-[0-9]*	$sha	0.72.200	not-run	" "$status_file"
printf 'dead\nviri\n1\n' > "$t/slots/notes/4000000"   # a note whose process is gone is nobody's
rm "$t/slots/notes/$$"
exec 8>"$repo/.git/vikix-release.lock"; flock 8   # a release under way
night --now
check "a release under way: not-run: $code: $(detail)" test "$(detail)" = "the machine wasn't free: a release is under way"
exec 8>&-
printf '99.00 50.00 20.00 1/100 1\n' > "$t/loadavg"
night --now
check "a load past the cores: not-run: $(detail)" grep -q "^the machine wasn't free: load 99.00 on [0-9]* cores$" <<<"$(detail)"
printf '0.50 0.40 0.30 1/100 1\n' > "$t/loadavg"
printf '0\n' > "$t/power/AC/online"
night --now
check "on battery: not-run: $(detail)" test "$(detail)" = "the machine wasn't free: on battery"
rm "$t/power/AC/online"   # no mains known at all, a battery there: still on battery
night --now
check "a battery and no mains: not-run: $(detail)" test "$(detail)" = "the machine wasn't free: on battery"
printf '1\n' > "$t/power/AC/online"
check "the runner still never ran" no test -e "$t/runner-args"
check "each not-run told: $(notified)" test "$(notified)" = 5

echo "--- waiting for a free machine"
printf 'running\nviri\n%s\n' "$(date +%s)" > "$t/slots/notes/$$"
VIKIX_NIGHT_WAIT=1 night
check "the wait given up: not-run, exit 2: $code: $(detail)" test "$code" = 2
check "saying how long: $(detail)" grep -q "other runs on the machine (waited 1s)$" <<<"$(detail)"
( sleep 1.5; rm -f "$t/slots/notes/$$" ) &
pids+=("$!")
VIKIX_NIGHT_WAIT=10 night
check "the machine freed within the wait: the run went: $code: $out" test "$code" = 0
check "the verdict ok" test "$(verdict)" = ok
check "the runner was asked for --all: $(cat "$t/runner-args")" grep -qx -- '--all' "$t/runner-args"
wait "${pids[-1]}" 2>/dev/null || true; pids=()

echo "--- a run that passed"
rm -f "$t/notified" "$t/updates-called"
night --now
check "ok, exit 0: $code: $out" test "$code" = 0
check "the detail counts the tests: $(detail)" test "$(detail)" = "3 tests passed"
check "nothing told for a pass" test "$(notified)" = 0
check "the bar refreshed all the same" test -f "$t/updates-called"
check "the run's output kept" grep -q '^all passed: lint lisp night$' "$t/state/vikix/tests/night-$(cut -f1 "$status_file").log"
check "a line a run in night.log: $(wc -l < "$t/state/vikix/tests/night.log")" test "$(wc -l < "$t/state/vikix/tests/night.log")" = 8
check "said in the terminal: $out" grep -q "^night tests, .*: ok (3 tests passed) on ${sha:0:7}, Vikix 0.72.200, [0-9]*s$" <<<"$out"
night --status
check "--status is the line, exit 0: $code: $out" test "$code" = 0
grep -q "^[0-9-]*: ok (3 tests passed) on ${sha:0:7}, Vikix 0.72.200, [0-9]*s; the log: $t/state/vikix/tests/night-" <<<"$out" || { echo "FAIL: --status: $out"; fail=1; }
printf 'flaky\n' > "$t/runner-mode"
night --now
check "a flake named in the detail: $(detail)" test "$(detail)" = "2 tests passed, once more alone: docs"
check "and still ok" test "$code" = 0

echo "--- a run that failed, one that was stopped, one that said nothing"
printf 'fail\n' > "$t/runner-mode"
night --now
check "failed, exit 1: $code" test "$code" = 1
check "the failed tests named: $(detail)" test "$(detail)" = "palette docs"
check "told: $(notified)" test "$(notified)" = 1
check "with the names" grep -q "tests failed: palette docs (${sha:0:7})" "$t/notified"
night --status
check "--status exits 1 on a failed night: $code" test "$code" = 1
printf 'hang\n' > "$t/runner-mode"
night --now
check "a run past the bound is stopped, exit 1: $code: $(detail)" test "$code" = 1
check "the verdict stopped" test "$(verdict)" = stopped
check "saying the bound and what had failed: $(detail)" test "$(detail)" = "stopped at the bound of 2s; failed before it: viri"
printf 'silent\n' > "$t/runner-mode"
night --now
check "a runner that ends well saying nothing is unsure, exit 1: $code: $(detail)" test "$code" = 1
check "the verdict unsure" test "$(verdict)" = unsure
check "not green: $(detail)" test "$(detail)" = "the runner ended well but never said all passed"
VIKIX_NIGHT_RUNNER="$t/no-such-runner" night --now
check "no runner is failed, never green: $code: $(detail)" test "$code" = 1
check "naming it: $(detail)" test "$(detail)" = "no runner at $t/no-such-runner"
check "each told: $(notified)" test "$(notified)" = 4

echo "--- one night run at a time, a signal ends the runner's tree, and the logs kept to fourteen"
printf 'hang\n' > "$t/runner-mode"
VIKIX_NIGHT_LIMIT=20 "$here/.claude/night-tests" --now >"$t/first.out" 2>&1 &
pids+=("$!")
sleep 1
night --now
check "a second run says one is going, exit 2: $code: $out" test "$code" = 2
grep -q '^a night run is going already$' <<<"$out" || { echo "FAIL: $out"; fail=1; }
check "the runner is running under it" pgrep -f "$repo/tests/run.sh --all" >/dev/null
kill -TERM "${pids[-1]}"
wait "${pids[-1]}" 2>/dev/null && code=0 || code=$?
check "the night ended by the signal exits 1: $code: $(cat "$t/first.out")" test "$code" = 1
check "the verdict stopped, saying so: $(detail)" test "$(detail)" = "ended by SIGTERM before the run ended"
sleep 0.5
check "nothing of the run left: $(pgrep -af "$repo/tests/run.sh" || true)" no pgrep -f "$repo/tests/run.sh --all" >/dev/null
pids=()
for i in $(seq 1 16); do printf 'old\n' > "$t/state/vikix/tests/night-2020010$((i / 10))-$(printf '%02d' $i)00.log"; done
printf 'pass\n' > "$t/runner-mode"
night --now
check "the run went after the other ended: $code" test "$code" = 0
check "fourteen logs kept: $(ls "$t/state/vikix/tests"/night-*.log | wc -l)" test "$(ls "$t/state/vikix/tests"/night-*.log | wc -l)" = 14
check "the oldest gone" no test -e "$t/state/vikix/tests/night-20200100-0100.log"
check "the newest there" test -s "$t/state/vikix/tests/night-$(cut -f1 "$status_file").log"

echo "--- help, and a bad option"
night --help
check "help prints the header: $code" test "$code" = 0
grep -q '^# night-tests — the whole test set at night' <<<"$out" || { echo "FAIL: $out"; fail=1; }
grep -q '(at "03:30" (run' <<<"$out" || { echo "FAIL: the rule to add isn't in the header: $out"; fail=1; }
night --tonight
check "a bad option: usage, exit 2: $code: $out" test "$code" = 2

[ "$fail" = 0 ] && echo "night: the whole set at night, the machine free first, the verdict never green on a missing runner or a silent run, the morning told"
exit "$fail"
