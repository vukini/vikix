#!/usr/bin/env bash
# tests/soak.sh — lib/soak.py for a minute: a hidden desktop worked hard
# (windows opening, closing, moving, floating, splits, reloads) answers
# quickly throughout, and ends as it began, with every window closed: no
# more heap than allowed, no extra timers or hooks, no errors written.
# `vikix times soak` runs the hour. Run alone (run.sh's alone list).
# Needs Xvfb, xdotool and Vikix's StumpWM; GitHub's runners have no X.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
set +e
out=$(XDG_STATE_HOME="$t/state" python3 "$here/lib/soak.py" "${VIKIX_SOAK_MINUTES:-1}" 2>&1); code=$?
set -e
if [ "$code" = 2 ]; then echo "soak: $out; skipped"; exit 0; fi
if [ "$code" = 0 ]; then echo "${out##*$'\n'}"; else echo "FAIL: ${out##*$'\n'}"; exit 1; fi
