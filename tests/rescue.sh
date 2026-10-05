#!/usr/bin/env bash
# tests/rescue.sh — a way out when the desktop is stuck (rescue.lisp,
# bin/vikix-rescue, bin/vikix-lock), in a real StumpWM on a hidden screen.
#
#   The watcher and the key's thread are up, with one beat. A desktop that
#   is coming round: `vikix rescue` says so (exit 0), and the key only says
#   there is nothing to free. The main thread made to go round and round:
#   `vikix eval` gets no answer, the watcher says so in a notification and
#   writes down what the thread was doing; `vikix rescue` shows it (exit 1);
#   `vikix rescue free` pauses the rules, puts focus on clicks, starts a
#   fresh event loop, and the desktop answers again; `undo` puts rules and
#   focus back. Super+Ctrl+Alt+Escape frees it too, read on its own
#   connection while StumpWM's keys are dead. Left alone, the watcher eases
#   it and then starts the fresh loop by itself. A menu left open is
#   waiting, not stuck: nothing is said or done. A reload keeps one beat,
#   one watcher, one key thread. And with a compositor running, the lock
#   screen comes back in front of a window raised over it.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM (the lock part
# i3lock and picom too); skipped, saying so, without them. Nothing here
# reaches the real desktop: its own screen, Swank port, home, a dead
# session bus, stand-ins for notify-send and dunstctl, and only its own
# processes ended, by their numbers.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
ql=$HOME/quicklisp
for need in Xvfb xdotool alacritty xdpyinfo; do
  command -v "$need" >/dev/null || { echo "rescue: needs $need and an X server; skipped"; exit 0; }
done
[ -x "$wm" ] || { echo "rescue: needs Vikix's StumpWM ($wm); skipped"; exit 0; }

t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# Stand-ins: what would be shown is written down instead.
mkdir -p "$t/bin"
printf '#!/bin/sh\necho "notify-send $*" >> "%s/notes"\n' "$t" > "$t/bin/notify-send"
printf '#!/bin/sh\n[ "$1" = is-paused ] && echo true\nexit 0\n' > "$t/bin/dunstctl"
chmod +x "$t/bin/"*
real_path=$PATH
export PATH="$t/bin:$PATH"
: > "$t/notes"

n=$(( 1700 + RANDOM % 400 ))
while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
pids+=($!)

home="$t/home"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
[ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
echo "rescue-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal

for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
answers() { local until=$((SECONDS + $1)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && return 0; sleep 0.5; done; return 1; }
answers 60 || { echo "FAIL: the test StumpWM didn't start: $(grep -v '^;' "$t/wm.log" | tail -5)"; exit 1; }
rescue() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-rescue" "$@" 2>&1; }
said() { grep -c "notify-send .* -- $1" "$t/notes" || true; }
# spin: the main thread goes round and round, as a loop of rules and focus did.
spin() { ( ask '(rescue-test-spin)' >/dev/null 2>&1 & ); }
ask '(progn (defun rescue-test-spin () (loop)) (setf *vikix-stuck-after* 4 *vikix-stuck-ease-after* 1000 *vikix-stuck-loop-after* 1000))' >/dev/null

check "the watcher, the key's thread and one beat are up: $(ask '(princ (list (vikix-thread-alive-p *vikix-watch-thread*) (vikix-thread-alive-p *vikix-rescue-key-thread*) (count (quote vikix-beat) *timer-list* :key (function timer-function))))')" \
  test "$(ask '(princ (list (vikix-thread-alive-p *vikix-watch-thread*) (vikix-thread-alive-p *vikix-rescue-key-thread*) (count (quote vikix-beat) *timer-list* :key (function timer-function))))')" = "(T T 1)"

# --- Coming round ---------------------------------------------------------------------
out=$(rescue) && code=0 || code=$?
check "a desktop coming round: vikix rescue says so, exit 0: $code $out" bash -c "[ $code = 0 ] && grep -q 'The desktop is coming round' <<<\"\$1\"" _ "$out"
xdotool key super+ctrl+alt+Escape; sleep 1.5
check "the key, then, only says there is nothing to free: $(cat "$t/notes")" test "$(said 'The desktop is coming round Nothing to free')" = 1
check "and changes nothing" test "$(ask '(princ (list *vikix-rules-paused* *mouse-focus-policy*))')" = "(NIL SLOPPY)"
out=$(rescue free) && code=0 || code=$?
check "vikix rescue free, then, frees nothing: $out" grep -q 'nothing to free' <<<"$out"
: > "$t/notes"

# --- Stuck: found, shown, freed by the command ----------------------------------------
spin; sleep 9
check "a stuck desktop gives vikix eval no answer" test "$(ask '(princ 1)')" != 1
check "the watcher says so, once: $(cat "$t/notes")" test "$(said 'The desktop is stuck')" = 1
report=$(grep -l "main loop hadn't come round" "$home"/.local/state/vikix/errors/*.txt 2>/dev/null | head -1)
check "and writes down what the main thread was doing" grep -q 'RESCUE-TEST-SPIN' "${report:-/dev/null}"
out=$(rescue) && code=0 || code=$?
check "vikix rescue says it is stuck, exit 1: $code" bash -c "[ $code = 1 ] && grep -q 'The desktop is stuck' <<<\"\$1\"" _ "$out"
check "and shows what its main thread is doing" grep -q 'RESCUE-TEST-SPIN' <<<"$out"
out=$(rescue free) && code=0 || code=$?
check "vikix rescue free frees it, exit 0: $code $out" bash -c "[ $code = 0 ] && grep -q 'coming round again' <<<\"\$1\"" _ "$out"
check "by pausing the rules, putting focus on clicks, and a fresh event loop: $out" grep -q 'rules paused, focus follows clicks, not the mouse, a fresh event loop' <<<"$out"
check "the desktop answers again" answers 10
check "rules are paused and focus is on clicks till undone" test "$(ask '(princ (list *vikix-rules-paused* *mouse-focus-policy*))')" = "(T CLICK)"
out=$(rescue undo)
check "vikix rescue undo puts both back: $out" test "$(ask '(princ (list *vikix-rules-paused* *mouse-focus-policy*))')" = "(NIL SLOPPY)"
sleep 4; : > "$t/notes"

# --- Stuck: freed by the key, on its own connection -----------------------------------
spin; sleep 7
xdotool key super+ctrl+alt+Escape; sleep 1
check "Super+Ctrl+Alt+Escape frees a stuck desktop" answers 20
check "and says what it did: $(cat "$t/notes")" test "$(said 'Freed It had been stuck')" = 1
rescue undo >/dev/null; sleep 4; : > "$t/notes"

# --- Stuck and left alone: the watcher's own steps -----------------------------------
ask '(setf *vikix-stuck-after* 4 *vikix-stuck-ease-after* 7 *vikix-stuck-loop-after* 10)' >/dev/null
spin; sleep 3          # the spin first: an answer before it starts would prove nothing
check "it is stuck, to begin with" test "$(ask '(princ 1)')" != 1
check "left alone, the watcher frees it by itself" answers 40
sleep 4
check "having said so, eased it, then started a fresh loop: $(cut -c1-60 "$t/notes" | tr '\n' ';')" \
  test "$(said 'The desktop is stuck') $(said 'Still stuck: eased') $(said 'Still stuck: a fresh event loop') $(said 'The desktop is coming round again')" = "1 1 1 1"
rescue undo >/dev/null; : > "$t/notes"
ask '(setf *vikix-rescue-auto* nil)' >/dev/null
spin; sleep 14
check "with *vikix-rescue-auto* off it only says so: $(cut -c1-50 "$t/notes" | tr '\n' ';')" \
  test "$(said 'The desktop is stuck') $(said 'Still stuck')" = "1 0"
rescue free >/dev/null; answers 10 || true; rescue undo >/dev/null
ask '(setf *vikix-rescue-auto* t *vikix-stuck-ease-after* 1000 *vikix-stuck-loop-after* 1000)' >/dev/null
sleep 4; : > "$t/notes"

# --- A menu open: waiting, not stuck ------------------------------------------------
xdotool key super+m; sleep 9
check "a menu left open sets nothing off: $(cat "$t/notes")" test ! -s "$t/notes"
out=$(rescue) && code=0 || code=$?
check "vikix rescue calls it waiting, not stuck: $code $(head -1 <<<"$out")" bash -c "[ $code = 1 ] && grep -q 'waiting, not stuck' <<<\"\$1\"" _ "$out"
xdotool key Escape
check "Escape, and it answers" answers 10

# --- A reload ---------------------------------------------------------------------------
ask '(loadrc)' >/dev/null; answers 60 || true
check "a reload keeps one beat, one watcher, one key thread: $(ask '(princ (list (count (quote vikix-beat) *timer-list* :key (function timer-function)) (count "vikix-watch" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal)) (count "vikix-rescue-key" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal))))')" \
  test "$(ask '(princ (list (count (quote vikix-beat) *timer-list* :key (function timer-function)) (count "vikix-watch" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal)) (count "vikix-rescue-key" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal))))')" = "(1 1 1)"
check "nothing went into a debugger on the way" test -z "$(grep -il 'debugger invoked\|unhandled' "$t/wm.log" 2>/dev/null)"

# --- The lock screen stays in front ----------------------------------------------------
if PATH=$real_path command -v i3lock >/dev/null && PATH=$real_path command -v picom >/dev/null; then
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class rescuetest --title W -e sleep 300 >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do [ "$(ask '(princ (length (screen-windows (current-screen))))')" = 1 ] && break; sleep 0.25; done
  picom --backend xrender >/dev/null 2>&1 &
  pids+=($!)
  sleep 1
  HOME=$home sh "$here/bin/vikix-lock" --locker >/dev/null 2>&1 &
  locker=$!
  pids+=("$locker")
  sleep 2
  lock=$(pgrep -P "$locker" -x i3lock | head -1)
  [ -n "$lock" ] && pids+=("$lock")
  top() { xwininfo -root -children | grep -E '^\s+0x' | head -1; }
  check "locked: the lock screen is in front: $(top)" grep -q i3lock <<<"$(top)"
  ask '(setf (xlib:window-priority (window-parent (first (screen-windows (current-screen))))) :above)' >/dev/null
  # The locker lifts it every half second; on a busy machine that has taken more than the 1.5 s once waited here.
  for _ in $(seq 1 24); do sleep 0.25; grep -q i3lock <<<"$(top)" && break; done
  check "a window raised over it, with a compositor running: the lock screen is in front again: $(top)" grep -q i3lock <<<"$(top)"
  out=$(rescue lock)
  check "vikix rescue lock says the screen is locked and brings it forward: $out" grep -q 'in front again' <<<"$out"
  [ -n "$lock" ] && kill "$lock" 2>/dev/null
  sleep 1
  check "nothing is left raising it after it's unlocked" test -z "$(pgrep -P "$locker" 2>/dev/null)"
  said_lock=", the lock screen kept in front of a raised window"
else
  echo "(the lock part needs i3lock and picom; skipped here)"
  said_lock=""
fi

[ "$fail" = 0 ] && echo "rescue: stuck found and written down, freed by vikix rescue, by Super+Ctrl+Alt+Escape and by the watcher itself; a menu is only waiting; one of each after a reload$said_lock"
exit "$fail"
