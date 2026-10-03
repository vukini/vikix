#!/usr/bin/env bash
# tests/times.sh — how long the desktop takes, against lib/times.limits:
# StumpWM's start to ready, a reload, a key to its command, an Emacs frame,
# StumpWM answering after them (lib/times-measure.sh, on a hidden screen
# with this checkout's config). A measure over its limit fails, and so does
# one missing: the timer in commands.lisp (login, reload) must write them.
# Run alone (run.sh's alone list): other tests side by side would slow it.
# Needs Xvfb, xdotool and Vikix's StumpWM; GitHub's runners have no X, so
# there it says so and stops.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
set +e
out=$(bash "$here/lib/times-measure.sh" 2>"$t/err"); code=$?
set -e
if [ "$code" = 2 ]; then echo "times: $(cat "$t/err"); skipped"; exit 0; fi
[ "$code" = 0 ] || { echo "FAIL: measuring: $(cat "$t/err")"; exit 1; }
# A busy machine (other sessions' tests, an update) slows everything for a
# while: a measure over its limit is taken again once, and the quicker counts.
over=$(while read -r what limit; do
  got=$(awk -v w="$what" '$1 == w {print $2}' <<<"$out")
  [ -n "$got" ] && python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)' "$got" "$limit" && echo "$what" || true
done < <(grep -v '^#' "$here/lib/times.limits" | awk 'NF == 2'))
if [ -n "$over" ]; then
  again=$(bash "$here/lib/times-measure.sh" 2>/dev/null || true)
  out=$(python3 -c '
import sys
a = dict(l.split() for l in sys.argv[1].splitlines() if len(l.split()) == 2)
b = dict(l.split() for l in sys.argv[2].splitlines() if len(l.split()) == 2)
for k in a: print(k, min(float(a[k]), float(b.get(k, a[k]))))' "$out" "$again")
fi
fail=0
while read -r what limit; do
  [ "$what" = login ] && continue          # the real session's: not on a hidden screen
  got=$(awk -v w="$what" '$1 == w {print $2}' <<<"$out")
  if [ -z "$got" ]; then
    [ "$what" = emacs ] && ! command -v emacs >/dev/null && continue
    echo "FAIL: no $what measured: $out"; fail=1
  elif python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) <= float(sys.argv[2]) else 1)' "$got" "$limit"; then :
  else echo "FAIL: $what took ${got}s, over its limit of ${limit}s"; fail=1
  fi
done < <(grep -v '^#' "$here/lib/times.limits" | awk 'NF == 2')
[ "$fail" = 0 ] && echo "times: $(tr '\n' ' ' <<<"$out")(seconds, each under its limit)"
exit "$fail"
