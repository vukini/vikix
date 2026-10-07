#!/usr/bin/env bash
# tests/office-ui.sh — lib/office.py, bin/vikix-agents and vikix-office.el,
# using fixture records and stand-in commands; never a live agent or display.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # never the live session settings
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
xpid=''
trap '[ -z "$xpid" ] || kill "$xpid" 2>/dev/null; rm -rf "$t"' EXIT
export HOME="$t"
export XDG_STATE_HOME="$t/state" XDG_CONFIG_HOME="$t/config" XDG_DATA_HOME="$t/data"
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/office-test
unset DISPLAY
python3 "$here/tests/office-ui.py"
if command -v emacs >/dev/null; then
  emacs --batch -Q -l "$here/tests/office-ui.el" -f ert-run-tests-batch-and-exit
else
  echo 'SKIP: Office UI tests need Emacs'
fi

if command -v Xvfb >/dev/null && command -v emacs >/dev/null; then
  Xvfb -displayfd 3 -screen 0 1600x1000x24 -nolisten tcp 3>"$t/display" >"$t/xvfb.log" 2>&1 &
  xpid=$!
  for ((i=0; i<50; i++)); do [ ! -s "$t/display" ] || break; sleep 0.1; done
  if [ -s "$t/display" ]; then
    DISPLAY=":$(cat "$t/display")"
    export DISPLAY
    code=0
    timeout 20 emacs -Q --no-splash -l "$here/tests/office-ui-visual.el" || code=$?
    [ ! -f "$t/visual-result" ] || cat "$t/visual-result"
    [ "$code" = 0 ] || exit "$code"
  else
    echo 'SKIP: safe display unavailable; Office visual testing unavailable'
  fi
else
  echo 'SKIP: Xvfb or Emacs unavailable; Office visual testing unavailable'
fi
