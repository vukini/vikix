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
# (|| true: a daemon gone on its own would stop the trap at its kill, under
# set -e, and leave the screen running.) The Xvfb is ended for sure: one
# left behind (2026-10-08) held, through a descriptor it inherited, the
# release queue locked for hours.
end_xvfb() {
  [ -n "$xpid" ] || return 0
  kill "$xpid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$xpid" 2>/dev/null || return 0; sleep 0.2; done
  kill -KILL "$xpid" 2>/dev/null || true
}
trap '[ -z "$epid" ] || kill "$epid" 2>/dev/null || true; end_xvfb; rm -rf "$t"' EXIT
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
  # A free screen of its own, as every hidden-screen test picks one: tests
  # run side by side, and -displayfd, taking the lowest free number, once
  # met another server on :1 and lost the display under the daemon.
  n=$(( 4600 + RANDOM % 400 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  Xvfb ":$n" -screen 0 1600x1000x24 -nolisten tcp >"$t/xvfb.log" 2>&1 &
  xpid=$!
  for ((i=0; i<100; i++)); do [ ! -S "/tmp/.X11-unix/X$n" ] || break; sleep 0.1; done
  if [ -S "/tmp/.X11-unix/X$n" ]; then
    export DISPLAY=":$n"
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
    # When the daemon can't draw, say what the screen was doing: it once
    # said "cannot open display" seconds after the first part drew on it.
    screen() {
      echo "--- the daemon: $(cat "$t/daemon.log")"
      echo "--- Xvfb $xpid $(kill -0 "$xpid" 2>/dev/null && echo alive || echo gone), socket $(test -S "/tmp/.X11-unix/X$n" && echo there || echo gone), lock $(cat "/tmp/.X$n-lock" 2>/dev/null || echo gone): $(cat "$t/xvfb.log")"
      echo "--- xdpyinfo: $(timeout 5 xdpyinfo -display ":$n" 2>&1 | head -2)"
    }
    timeout 10 emacsclient --alternate-editor=false --eval "(load \"$here/tests/office-ui-visual.el\" nil t)" || { screen; exit 1; }
    for ((i=0; i<100; i++)); do [ ! -f "$t/visual-result" ] || break; sleep 0.1; done
    [ -f "$t/visual-result" ] || { screen; exit 1; }
    cat "$t/visual-result"
    wait "$epid"
    epid=''
  else
    echo 'SKIP: safe display unavailable; Office visual testing unavailable'
  fi
else
  echo 'SKIP: Xvfb or Emacs unavailable; Office visual testing unavailable'
fi
