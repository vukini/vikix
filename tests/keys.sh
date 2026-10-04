#!/usr/bin/env bash
# tests/keys.sh — the keys in a real StumpWM on a hidden screen (as
# tests/viri.sh): what tests/lisp.sh can't see without a keyboard.
#
#   Super+Shift+digit sends the window to that workspace, the key's name
#   asked of the keyboard: on a US layout (Shift+2 is @), on a British one
#   after its layout is applied (Shift+2 is "), and where the digits
#   themselves need Shift (French) Super+Ctrl+digit instead; the keys of
#   the layout before are let go. Super+Shift+arrow and Super+Shift+letter
#   move the window. A desktop that was running the keys from before the
#   rule lets them go at a reload, but not one you gave something else.
#
# Needs Xvfb, xdotool, setxkbmap, alacritty and Vikix's own StumpWM;
# skipped, saying so, without them.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
ql=$HOME/quicklisp
for need in Xvfb xdotool setxkbmap alacritty xdpyinfo; do
  command -v "$need" >/dev/null || { echo "keys: needs $need and an X server; skipped"; exit 0; }
done
[ -x "$wm" ] || { echo "keys: needs Vikix's StumpWM ($wm); skipped"; exit 0; }

t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# A free screen and a free port: tests run side by side.
n=$(( 900 + RANDOM % 400 ))
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
echo "keys-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal

for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
setxkbmap us
HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
until=$((SECONDS + 60))
while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
[ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start: $(grep -v '^;' "$t/wm.log" | tail -5)"; exit 1; }

win() {   # win TITLE: a window, and wait till StumpWM has it
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class keystest --title "$1" -e sleep 300 >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do
    [ "$(ask "(princ (if (find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
    sleep 0.25
  done
  sleep 0.3
}
key() { xdotool key "$1"; sleep 0.5; }
where() { ask "(princ (group-number (window-group (find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)))))"; }
sends() { ask '(princ (format nil "~{~a~^ ~}" *vikix-workspace-send-keys*))'; }
bound() { ask "(princ (or (lookup-key *top-map* (kbd \"$1\")) \"nothing\"))"; }

check "on a US keyboard, Super+Shift+digit is the key Shift+digit types: $(sends)" \
  test "$(sends)" = "s-exclam s-at s-numbersign s-dollar s-percent s-asciicircum s-ampersand s-asterisk s-parenleft"
check "Super+Ctrl+digit sends nothing any more: $(bound s-C-2)" test "$(bound s-C-2)" = nothing

win A; win B
key super+shift+2
check "Super+Shift+2 sends the window to workspace 2: $(where B)" test "$(where B)" = 2
check "and you stay where you were" test "$(ask '(princ (group-number (current-group)))')" = 1

ask '(run-commands "hsplit")' >/dev/null; win C; sleep 0.3
frame() { ask '(princ (frame-number (window-frame (current-window))))'; }
before=$(frame)
key super+shift+Right
check "Super+Shift+Right moves the window to the frame on the right: $before, then $(frame)" test "$(frame)" != "$before"
key super+shift+h
check "Super+Shift+h moves it back left: $(frame)" test "$(frame)" = "$before"

# Another keyboard: Shift+2 is " and Shift+3 is £ on a British one.
setxkbmap gb; sleep 1
ask '(vikix-bind-workspace-keys)' >/dev/null
check "on a British keyboard the keys follow it: $(sends)" grep -q '^s-exclam s-quotedbl s-sterling ' <<<"$(sends)"
check "and the US ones that differ are let go: $(bound s-at)" test "$(bound s-at)" = nothing
key super+shift+3
check "Super+Shift+3 there sends the window to workspace 3: $(where C)" test "$(where C)" = 3

# Where the digits themselves need Shift, Shift+digit can't be the key.
setxkbmap fr; sleep 1
ask '(vikix-bind-workspace-keys)' >/dev/null
check "on a French keyboard, Super+Ctrl+digit: $(sends)" test "$(sends)" = "s-C-1 s-C-2 s-C-3 s-C-4 s-C-5 s-C-6 s-C-7 s-C-8 s-C-9"
setxkbmap us; sleep 1
ask '(vikix-bind-workspace-keys)' >/dev/null
check "and back on a US one: $(bound s-C-2), $(bound s-at)" test "$(bound s-C-2) $(bound s-at)" = "nothing gmove 2"

# A desktop that ran the keys from before the rule: a reload lets them go.
ask '(progn (define-key *top-map* (kbd "s-E") "exec spacefm") (define-key *top-map* (kbd "s-M-a") "vikix-awake") (define-key *top-map* (kbd "s-C-Left") "vikix-move left") (define-key *top-map* (kbd "s-C-4") "gmove 4") (define-key *top-map* (kbd "s-P") "exec my-own-program"))' >/dev/null
ask '(loadrc)' >/dev/null
until=$((SECONDS + 60))
while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
check "after a reload the old keys are gone: $(bound s-E) $(bound s-M-a) $(bound s-C-Left) $(bound s-C-4)" \
  test "$(bound s-E) $(bound s-M-a) $(bound s-C-Left) $(bound s-C-4)" = "nothing nothing nothing nothing"
check "one of them you gave something else stays: $(bound s-P)" test "$(bound s-P)" = "exec my-own-program"
check "the new ones are there: $(bound s-M-s), $(bound s-C-a), $(bound s-S-Left)" \
  test "$(bound s-M-s)|$(bound s-C-a)|$(bound s-S-Left)" = "exec spacefm|vikix-awake|vikix-move left"
check "no key of Vikix's breaks the rule for keys: $(ask '(princ (vikix-key-problems))')" test "$(ask '(princ (length (vikix-key-problems)))')" = 0

# Super+g's list: each line has the window's workspace, its title, and for
# a terminal its folder and what runs in it, so two terminals with one
# title can be told apart; the focused window isn't in it.
lines() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~%~}" (mapcar (function first) (vikix-window-lines (vikix-other-windows)))))'; }
check "the window list says each window's workspace and what runs in it: $(lines | head -3 | tr '\n' '|')" grep -qE '^2 +B +.*sleep 300' <<<"$(lines)"
check "and leaves the focused window out" test "$(lines | grep -c " $(ask '(princ (window-title (current-window)))') ")" = 0

# "What does a key do?" from the menu: the answer stays. The menu closes
# over the pointer, X says the pointer entered the window beneath, and
# focusing it again took the answer off the screen as it came.
xdotool mousemove 640 400; sleep 0.5
xdotool key super+m; sleep 1; xdotool type "What does"; sleep 0.5; key Return; key super+ctrl+a; sleep 1
check "the answer of What does a key do? stays on the screen" test "$(ask '(princ (xlib:window-map-state (screen-message-window (current-screen))))')" = VIEWABLE
key Escape
check "nothing failed on the way" test -z "$(ls "$home/.local/state/vikix/errors/" 2>/dev/null)"

[ "$fail" = 0 ] && echo "keys: Super+Shift+digit by the keyboard's layout (US, British, French), Super+Shift moves the window, the old keys let go at a reload, the window list, the key help's answer stays"
exit "$fail"
