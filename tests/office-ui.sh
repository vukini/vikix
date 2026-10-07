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
epid=''
trap '[ -z "$epid" ] || kill "$epid" 2>/dev/null; [ -z "$xpid" ] || kill "$xpid" 2>/dev/null; rm -rf "$t"' EXIT
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

if command -v emacs >/dev/null; then
  # The terminal path, end to end: a daemon of its own (the visual check's
  # ends with kill-emacs), the real launcher on a pty with no display, the
  # Office drawn there, and q giving the shell back.
  export EMACS_SOCKET_NAME="$t/office-tty"
  emacs -Q --fg-daemon="$EMACS_SOCKET_NAME" >"$t/daemon-tty.log" 2>&1 &
  epid=$!
  for ((i=0; i<100; i++)); do [ ! -S "$EMACS_SOCKET_NAME" ] || break; sleep 0.1; done
  [ -S "$EMACS_SOCKET_NAME" ] || { cat "$t/daemon-tty.log"; exit 1; }
  timeout --kill-after=5s 90s python3 "$here/tests/office-ui-tty.py" || { cat "$t/daemon-tty.log"; exit 1; }
  timeout 10 emacsclient --alternate-editor=false --eval '(kill-emacs 0)' >/dev/null 2>&1 || true
  wait "$epid" || true
  epid=''
  export EMACS_SOCKET_NAME=/nonexistent/emacs-server
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
    # Exercise the terminal-only daemon used by the real launcher as well.
    export EMACS_SOCKET_NAME="$t/office-server"
    emacs -Q --fg-daemon="$EMACS_SOCKET_NAME" >"$t/daemon.log" 2>&1 &
    epid=$!
    for ((i=0; i<100; i++)); do [ ! -S "$EMACS_SOCKET_NAME" ] || break; sleep 0.1; done
    [ -S "$EMACS_SOCKET_NAME" ] || { cat "$t/daemon.log"; exit 1; }
    rm -f "$t/visual-result"
    timeout 10 emacsclient --alternate-editor=false --eval "(load \"$here/tests/office-ui-visual.el\" nil t)"
    for ((i=0; i<100; i++)); do [ ! -f "$t/visual-result" ] || break; sleep 0.1; done
    [ -f "$t/visual-result" ] || { cat "$t/daemon.log"; exit 1; }
    cat "$t/visual-result"
    wait "$epid"
    epid=''
  else
    echo 'SKIP: safe display unavailable; Office visual testing unavailable'
  fi
else
  echo 'SKIP: Xvfb or Emacs unavailable; Office visual testing unavailable'
fi
