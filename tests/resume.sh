#!/usr/bin/env bash
# tests/resume.sh — your windows back after a restart (resume.lisp,
# bin/vikix-resume), in a real StumpWM, over several made-up logins, each
# on an X server of its own.
#
#   A first login with nothing saved asks nothing. Saving writes each
#   workspace that has windows (tiled, and a strip) and says how many;
#   `vikix resume` says what is saved and what a login will do. After
#   everything has ended and a new login started: with "always", the
#   windows are back on their workspaces, split as they were, a strip a
#   strip again, a terminal in the folder it was in, and you are on the
#   workspace you were on; an empty desktop just logged in to never
#   replaces what was saved; a reload in the same login doesn't bring them
#   back again. With "never" nothing comes back by itself, and `vikix
#   resume now` still does it. With "ask" a menu asks, and Enter on its
#   first line brings them back.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM; skipped, saying
# so, without them.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
ql=$HOME/quicklisp
for need in Xvfb xdotool alacritty xdpyinfo; do
  command -v "$need" >/dev/null || { echo "resume: needs $need and an X server; skipped"; exit 0; }
done
[ -x "$wm" ] || { echo "resume: needs Vikix's StumpWM ($wm); skipped"; exit 0; }

t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; end_windows; rm -rf "$t"; }
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

mkdir -p "$t/bin"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/notify-send"
printf '#!/bin/sh\n[ "$1" = is-paused ] && echo false\nexit 0\n' > "$t/bin/dunstctl"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"

home="$t/home"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix" "$home/work"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
[ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
echo "resume-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
answers() { local until=$((SECONDS + $1)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && return 0; sleep 0.5; done; return 1; }
resume() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR="$here" bash "$here/bin/vikix-resume" "$@" 2>&1; }
# The test's own windows, found by its made-up home in their environment:
# the ones a restart starts again aren't this script's children.
its_windows() { local p; for p in $(pgrep -f "alacritty --class Resume[A-E] " || true); do grep -qz "HOME=$home" "/proc/$p/environ" 2>/dev/null && echo "$p"; done; }
end_windows() { local p; for p in $(its_windows); do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

x_pid='' wm_pid=''
login() {   # a new X server and a StumpWM on it, as a login is
  local n=$(( 2500 + RANDOM % 400 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  export DISPLAY=":$n"
  Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
  x_pid=$!; pids+=("$x_pid")
  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  HOME=$home VIKIX_SWANK_PORT=$port "$wm" >>"$t/wm.log" 2>&1 &
  wm_pid=$!; pids+=("$wm_pid")
}
logout() {  # everything ends: the windows, StumpWM, the X server
  end_windows
  kill "$wm_pid" "$x_pid" 2>/dev/null || true
  for _ in $(seq 1 20); do kill -0 "$x_pid" 2>/dev/null || break; sleep 0.25; done
}
win() {   # win NAME [FOLDER]: a terminal of that class and title, started in FOLDER
  (cd "${2:-$home}" && LIBGL_ALWAYS_SOFTWARE=1 HOME=$home setsid alacritty --class "$1" --title "$1" -e sleep infinity >/dev/null 2>&1 &)
  for _ in $(seq 1 40); do
    [ "$(ask "(princ (if (find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
    sleep 0.25
  done
  sleep 0.3
}
go() { ask "(switch-to-group (find $1 (screen-groups (current-screen)) :key (function group-number)))" >/dev/null; sleep 0.3; }
# The desktop in a line: each workspace, tiles or a strip, its windows.
where() { ask '(princ (mapcar (lambda (g) (list (group-number g) (if (viri-group-p g) :strip :tiles) (sort (mapcar (function window-title) (vikix-resume-windows g)) (function string<)))) (vikix-resume-groups)))'; }
settled() { local until=$((SECONDS + ${1:-60})); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ (if (and *vikix-resume-decided* (not *vikix-resume-run*)) 1 0))')" = 1 ] && return 0; sleep 1; done; return 1; }
frames_on_1() { ask '(princ (length (group-frames (find 1 (screen-groups (current-screen)) :key (function group-number)))))'; }
was="((1 TILES (ResumeA ResumeB)) (2 TILES (ResumeC)) (3 STRIP (ResumeD ResumeE)))"

# --- The first login: nothing saved ------------------------------------------------
login; answers 60 || { echo "FAIL: the test StumpWM didn't start: $(grep -v '^;' "$t/wm.log" | tail -5)"; exit 1; }
check "a login with nothing saved asks nothing, and saving may begin" settled 20
out=$(resume)
check "vikix resume says nothing is saved yet: $out" grep -q 'Nothing is saved yet' <<<"$out"
check "and that a login asks first, as it starts out" grep -q 'you are asked first' <<<"$out"
out=$(resume save)
check "saving an empty desktop keeps what was saved: $out" grep -q 'No windows to save' <<<"$out"

win ResumeA; ask '(run-commands "hsplit")' >/dev/null; win ResumeB "$home/work"
go 2; win ResumeC
go 3; win ResumeD; win ResumeE; ask '(run-commands "vikix-viri")' >/dev/null; sleep 0.5
go 2
check "the desktop to save: $(where)" test "$(where)" = "$was"
out=$(resume save)
check "vikix resume save says how many windows: $out" test "$out" = "Saved: 5 windows."
check "each workspace is a layout file of its own, with an index" test "$(ls "$home/.local/state/vikix/resume/" | tr '\n' ' ')" = "index.lisp workspace-1.lisp workspace-2.lisp workspace-3.lisp "
out=$(resume)
check "vikix resume says what is saved: $out" grep -q 'Saved: 5 windows on 3 workspaces, saved today at' <<<"$out"
check "the save that happens by itself is one timer, in whole seconds" test "$(ask '(princ (list (count (quote vikix-resume-tick) *timer-list* :key (function timer-function)) (integerp *vikix-resume-every*)))')" = "(1 T)"
out=$(resume always)
check "vikix resume always: $out" grep -q 'without asking' <<<"$out"

# --- A new login, with always ----------------------------------------------------------
logout; login; answers 60 || { echo "FAIL: StumpWM didn't start at the second login"; exit 1; }
check "the new login starts empty: $(where)" test "$(where)" = NIL
check "and the windows come back by themselves" settled 90
check "each on its workspace, a strip a strip again: $(where)" test "$(where)" = "$was"
check "workspace 1 is split in two as it was: $(frames_on_1)" test "$(frames_on_1)" = 2
check "you are on the workspace you were on: $(ask '(princ (group-number (current-group)))')" test "$(ask '(princ (group-number (current-group)))')" = 2
b=$(for p in $(its_windows); do if tr '\0' ' ' < "/proc/$p/cmdline" | grep -q 'class ResumeB '; then echo "$p"; fi; done | head -1)
check "a terminal is back in the folder it was in: $(readlink "/proc/${b:-0}/cwd" 2>/dev/null)" test "$(readlink "/proc/${b:-0}/cwd" 2>/dev/null)" = "$home/work"
check "five windows, no more: $(its_windows | wc -l)" test "$(its_windows | wc -l)" = 5
ask '(loadrc)' >/dev/null; answers 60 || true; sleep 4
check "a reload in the same login brings nothing back again: $(its_windows | wc -l)" test "$(its_windows | wc -l)" = 5

# --- A login to an empty desktop doesn't replace what was saved; never; now ---
resume never >/dev/null
logout; login; answers 60 || { echo "FAIL: StumpWM didn't start at the third login"; exit 1; }
check "with never, a login brings nothing back" settled 20
sleep 2
check "the desktop stays empty: $(where)" test "$(where)" = NIL
ask '(vikix-resume-tick)' >/dev/null
out=$(resume)
check "the empty desktop's own save didn't replace what was saved: $out" grep -q 'Saved: 5 windows on 3 workspaces' <<<"$out"
out=$(resume now)
check "vikix resume now brings them back all the same: $out" grep -q 'Bringing back 5 windows on 3 workspaces' <<<"$out"
check "and they come" settled 90
check "as they were: $(where)" test "$(where)" = "$was"

# --- ask -------------------------------------------------------------------------------
resume ask >/dev/null
logout; login
sleep 8          # the menu is up, and has the main thread: nothing answers
check "with ask, a login waits with a menu: vikix eval gets no answer meanwhile" test "$(ask '(princ 1)')" != 1
xdotool key Return
check "Enter on its first line (Bring them back) starts it" answers 30
check "and the windows come back" settled 90
check "as they were: $(where)" test "$(where)" = "$was"
check "nothing failed on the way: $(ls "$home/.local/state/vikix/errors/" 2>/dev/null | wc -l) errors" bash -c "[ -z \"\$(ls '$home/.local/state/vikix/errors/' 2>/dev/null)\" ] && [ -z \"\$(grep -il 'debugger invoked\\|unhandled' '$t/wm.log' 2>/dev/null)\" ]"

[ "$fail" = 0 ] && echo "resume: every workspace saved, tiled or a strip; back after a new login by itself, by vikix resume now, or after a menu's Enter; an empty desktop never replaces what was saved"
exit "$fail"
