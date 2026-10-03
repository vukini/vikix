#!/usr/bin/env bash
# tests/viri.sh — a workspace that scrolls sideways (viri.lisp), in a real
# StumpWM on a hidden screen.
#
#   vikix-viri makes the workspace a strip, its windows kept in the order
#   they stood; each column is half the screen, two show, the rest stand
#   past the edges; Super+h / Super+l walk along it and scroll it, and stop
#   at its ends; Super+Shift+l moves a column; a new window opens right of
#   the focused one and takes the focus; closing one focuses the one that
#   took its place; a dialog floats in the middle, not as a column; another
#   workspace and back, and the strip is as it was; vikix-viri off makes it
#   tiles again with the same windows, and on again keeps their order;
#   commands that only know tiles (layout undo's recording) say nothing.
#
# Needs Xvfb, xdotool, alacritty (the windows) and Vikix's own StumpWM
# (~/.local/bin/stumpwm, with Swank inside): there's no X on GitHub's
# runners, so it says so and stops there. Its own screen and Swank port,
# both free ones, and its own home: never the desktop's.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
ql=$HOME/quicklisp
for need in Xvfb xdotool alacritty; do
  command -v "$need" >/dev/null || { echo "viri: needs $need and an X server; skipped"; exit 0; }
done
[ -x "$wm" ] || { echo "viri: needs Vikix's StumpWM ($wm); skipped"; exit 0; }

t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# A free screen and a free port: tests run side by side.
n=$(( 100 + RANDOM % 400 ))
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
echo "viri-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal

for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "$1" 2>&1 | grep -v '^=> ' || true; }
for _ in $(seq 1 60); do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
[ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start: $(tail -5 "$t/wm.log")"; exit 1; }

win() {   # win TITLE: a window, and wait till StumpWM has it
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class viritest --title "$1" -e sleep 300 >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do
    [ "$(ask "(princ (if (find \"$1\" (group-windows (current-group)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
    sleep 0.25
  done
  sleep 0.3
}
key() { xdotool key "$1"; sleep 0.5; }
# The strip as one line: its columns, the first shown, the focused window.
state() { ask '(progn (setf *print-pretty* nil) (if (viri-group-p) (format t "~{~a~} left=~a focus=~a" (mapcar (function window-title) (viri-columns (current-group))) (viri-left (current-group)) (window-title (current-window))) (format t "tiles focus=~a" (and (current-window) (window-title (current-window))))))'; }
xs() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (mapcar (lambda (w) (xlib:drawable-x (window-parent w))) (viri-columns (current-group)))))'; }

for w in A B C D; do win "$w"; done
ask '(run-commands "vikix-viri")' >/dev/null; sleep 0.5
check "a strip keeps the windows in the order they stood, the focused one shown: $(state)" test "$(state)" = "ABCD left=2 focus=D"
check "two columns of half the screen show, the rest past the edges: $(xs)" test "$(xs)" = "-1280 -640 0 640"
bar() { ask '(princ (viri-mode-line-windows (head-mode-line (current-head))))' | head -1; }
plain_bar() { bar | sed 's/\^([^)]*)//g; s/[0-9]* //g'; }
check "the bar shows the strip, the two on the screen in brackets: $(plain_bar)" test "$(plain_bar)" = "AB[CD]"
check "and the focused one picked out" grep -qE '\(:fg [^)]*\)[0-9]+ D' <<<"$(bar)"
check "the focused column has the accent border, as a tile would" test "$(ask '(let ((w (current-window))) (princ (if (= (xlib:drawable-border-width (window-parent w)) *normal-border-width*) 1 0)))')" = 1
check "every column is drawn (none left hidden by the tiles)" test "$(ask '(princ (count-if (function window-hidden-p) (viri-columns (current-group))))')" = 0

key super+h; key super+h
check "Super+h walks left and scrolls: $(state)" test "$(state)" = "ABCD left=1 focus=B"
key super+h; key super+h
check "and stops at the first: $(state)" test "$(state)" = "ABCD left=0 focus=A"
check "the bar follows: $(plain_bar)" test "$(plain_bar)" = "[AB]CD"
key super+shift+l
check "Super+Shift+l moves the column right: $(state)" test "$(state)" = "BACD left=0 focus=A"

win E
check "a new window opens right of the focused one and takes the focus: $(state)" test "$(state)" = "BAECD left=1 focus=E"
ask '(delete-window (current-window))' >/dev/null; sleep 1
check "closing it focuses the one that took its place: $(state)" test "$(state)" = "BACD left=1 focus=C"

zenity --info --title=ViriDialog --text=x >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 1 40); do [ "$(ask '(princ (if (equal (window-title (current-window)) "ViriDialog") 1 0))')" = 1 ] && break; sleep 0.25; done
check "a dialog floats, not as a column: $(state)" test "$(state)" = "BACD left=1 focus=ViriDialog"
check "in the middle of the screen" test "$(ask '(let ((p (window-parent (current-window)))) (princ (if (< 200 (xlib:drawable-x p) 900) 1 0)))')" = 1
kill "${pids[-1]}" 2>/dev/null || true; sleep 1
check "when it goes, the strip has the focus again: $(state)" test "$(state)" = "BACD left=1 focus=C"

key super+2; key super+1
check "another workspace and back: the strip as it was: $(state)" test "$(state)" = "BACD left=1 focus=C"

key super+u
check "layout undo's recording says nothing on a strip (no menu waits)" test "$(ask '(princ 1)')" = 1

ask '(run-commands "vikix-viri off")' >/dev/null; sleep 0.5
check "off: tiles again, with all four windows: $(state)" test "$(state)" = "tiles focus=C"
check "each in a frame, none afloat" test "$(ask '(princ (count-if (lambda (w) (typep w (quote tile-window))) (group-windows (current-group))))')" = 4
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
check "and on again, the order kept, the focus too: $(state)" grep -qE '^BACD left=[12] focus=C$' <<<"$(state)"

# StumpWM's own ways to focus (Super+` cycles windows) come through the
# strip too: whatever gets the focus is scrolled to.
for _ in 1 2 3; do
  key super+grave
  check "Super+\` focuses a window on the screen: $(state)" test "$(ask '(let ((x (xlib:drawable-x (window-parent (current-window))))) (princ (if (<= 0 x 640) 1 0)))')" = 1
done

# The same from a shell.
HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR=$here bash "$here/bin/vikix" viri off; sleep 0.5
check "vikix viri off from a shell: $(state)" grep -q '^tiles' <<<"$(state)"
HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR=$here bash "$here/bin/vikix" viri; sleep 0.5
check "vikix viri switches it back: $(state)" grep -q '^BACD' <<<"$(state)"

# Off puts back the splits the tiles had: two frames, A alone on the right.
HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR=$here bash "$here/bin/vikix" viri off; sleep 0.5
find_w() { echo "(find \"$1\" (group-windows (current-group)) :key (function window-title) :test (function equal))"; }
ask "(progn (run-commands \"only\") (run-commands \"hsplit\") (pull-window $(find_w A) (second (group-frames (current-group)))) (focus-all $(find_w D)))" >/dev/null; sleep 0.5
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
key super+l; key super+h
ask '(run-commands "vikix-viri off")' >/dev/null; sleep 0.5
split=$(ask "(let* ((g (current-group)) (a $(find_w A)) (f (current-window))) (format t \"frames=~a A-alone-shown=~a focused-elsewhere=~a\" (length (group-frames g)) (eq (frame-window (window-frame a)) a) (or (eq f a) (not (eq (window-frame f) (window-frame a))))))")
check "off puts the split back, A shown in its own frame: $split" test "$split" = "frames=2 A-alone-shown=T focused-elsewhere=T"
check "and the window focused on the strip has the focus: $(state)" grep -q 'focus=' <<<"$(state)"

[ "$fail" = 0 ] && echo "viri: a strip from tiles and back in order, walking and moving along it, new and closed windows, a dialog, another workspace, off and on"
exit "$fail"
