#!/usr/bin/env bash
# tests/main.sh — main and stack mode (windows.lisp), in a real StumpWM on
# a hidden screen.
#
#   Super+Ctrl+m puts the workspace into main and stack: the focused window
#   down the left, three fifths wide, the others in a column beside it; a
#   new window opens at the top of the stack and takes the focus (or as the
#   main one, with *vikix-main-new* :main); Super+Shift+h makes a stack
#   window the main one, Super+Shift+j swaps two in the stack; Super+r goes
#   through the main window's widths; a closed window's place is filled; a
#   split made by hand is put back; Super+z and back keeps the shape; the
#   stack shows four windows at most, the rest behind the last; a dialog
#   floats and takes no frame; another workspace and back; off, and the
#   layout is yours again; grid mode and this one never both; the picker
#   (Super+Ctrl+Space, or vikix-layout-pick NAME) goes between tiles, main
#   and stack, a grid and a strip; a layout saved in the mode comes back in it.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM, as viri does;
# without them it says so and stops there. Its own screen, port and home.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup main
wm_start

# The workspace as one line: the window each frame shows, main first then
# down the stack; the frames' left edges; the focused window.
state() { ask '(progn (setf *print-pretty* nil) (let ((fs (sort (copy-list (group-frames (current-group))) (lambda (a b) (or (< (frame-x a) (frame-x b)) (and (= (frame-x a) (frame-x b)) (< (frame-y a) (frame-y b)))))))) (format t "~{~a~} x=~{~a~^,~} focus=~a" (mapcar (lambda (f) (if (frame-window f) (window-title (frame-window f)) "-")) fs) (mapcar (function frame-x) fs) (and (current-window) (window-title (current-window))))))'; }
heights() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (mapcar (function frame-height) (rest (sort (copy-list (group-frames (current-group))) (lambda (a b) (or (< (frame-x a) (frame-x b)) (and (= (frame-x a) (frame-x b)) (< (frame-y a) (frame-y b))))))))))'; }
on() { ask '(princ (if (vikix-main-p) 1 0))'; }
shape() { ask '(princ (if (vikix-main-in-shape-p (current-group)) 1 0))'; }
frames() { ask '(princ (length (group-frames (current-group))))'; }

for w in A B C; do win "$w"; done
key super+ctrl+m
check "Super+Ctrl+m: the focused window is the main one, three fifths wide, the others stacked beside it: $(state)" test "$(state)" = "CBA x=0,768,768 focus=C"
read -r h1 h2 <<<"$(heights)"
check "the stack's windows share the height: $h1 $h2" test "$h1" -gt 300 -a "$((h1 - h2))" -ge -1 -a "$((h1 - h2))" -le 1

win D
check "a new window opens at the top of the stack and takes the focus: $(state)" test "$(state)" = "CDBA x=0,768,768,768 focus=D"
key super+shift+h
check "Super+Shift+h makes it the main one, the old main in its place: $(state)" test "$(state)" = "DCBA x=0,768,768,768 focus=D"
key super+l; key super+k; key super+k   # to the top of the stack, whichever of it Super+l reached
key super+shift+j
check "Super+Shift+j swaps two in the stack: $(state)" test "$(state)" = "DBCA x=0,768,768,768 focus=C"

key super+r
check "Super+r: the main window two thirds wide: $(state)" test "$(state)" = "DBCA x=0,853,853,853 focus=C"
key super+r
check "then a half: $(state)" test "$(state)" = "DBCA x=0,640,640,640 focus=C"
win E
check "a new window keeps the width chosen: $(state)" test "$(state)" = "DEBCA x=0,640,640,640,640 focus=E"
key super+r
check "and three fifths again: $(state)" test "$(state)" = "DEBCA x=0,768,768,768,768 focus=E"

ask '(delete-window (current-window))' >/dev/null; sleep 1
check "a closed window's place is filled, the order kept: $(state)" grep -q '^DBCA x=0,768,768,768 ' <<<"$(state)"
key super+b
check "a split made by hand is put back at once: $(state)" grep -q '^DBCA x=0,768,768,768 ' <<<"$(state)"
key super+z
check "Super+z: only this window" test "$(frames)" = 1
key super+z
check "and back, in shape: $(state)" grep -q '^DBCA x=0,768,768,768 ' <<<"$(state)"

for w in F G H; do win "$w"; done
check "the stack shows four at most, the rest wait behind the last: $(state)" test "$(frames) $(shape)" = "5 1"
check "the last one opened is at the top of the stack, focused: $(state)" grep -q '^DH.* focus=H$' <<<"$(state)"

# A dialog floats (windows.lisp) and takes no frame.
LIBGL_ALWAYS_SOFTWARE=1 alacritty --class zenity --title Ask -e sleep 300 >/dev/null 2>&1 &
pids+=($!)
sleep 2
check "a dialog floats over it and takes no frame: $(state)" test "$(frames) $(shape) $(ask '(princ (count-if (function float-window-p) (group-windows (current-group))))')" = "5 1 1"

before=$(state)
key super+2; key super+1
# The frames, not the focus: back on the workspace, focus follows the mouse.
check "another workspace and back, as it was: $(state)" test "$(state | sed 's/ focus=.*//')" = "${before% focus=*}"

ask '(setf *vikix-main-new* :main)' >/dev/null
win I
check "with *vikix-main-new* :main a new window is the main one: $(state)" grep -q '^ID.* focus=I$' <<<"$(state)"
ask '(setf *vikix-main-new* :stack)' >/dev/null

ask '(run-commands "vikix-main on")' >/dev/null
check "vikix-main on keeps it on" test "$(on)" = 1
key super+ctrl+m
check "Super+Ctrl+m again: off" test "$(on)" = 0
n=$(frames); key super+b
check "and a split stays" test "$(frames)" = "$((n + 1))"
ask '(run-commands "vikix-main on")' >/dev/null
check "on again from any layout: in shape" test "$(on) $(shape)" = "1 1"
key super+shift+o
check "grid mode takes the workspace over: one mode, never both" test "$(on) $(ask '(princ (if (member (current-group) *vikix-grid-groups*) 1 0))')" = "0 1"
key super+ctrl+m
check "and main and stack takes it back" test "$(on) $(shape) $(ask '(princ (if (member (current-group) *vikix-grid-groups*) 1 0))')" = "1 1 0"

# The picker: Super+Ctrl+Space is a menu of the layouts, the current one
# chosen; by name from a rule or a key of your own.
now() { ask '(princ (vikix-layout-now))'; }
key super+ctrl+m
check "off: plain tiles" test "$(now)" = TILES
key super+ctrl+space; key Down; key Return
check "Super+Ctrl+Space, down, Enter: main and stack: $(now)" test "$(now) $(shape)" = "MAIN 1"
ask '(run-commands "vikix-layout-pick grid")' >/dev/null; sleep 0.5
check "vikix-layout-pick grid: $(now)" test "$(now) $(on)" = "GRID 0"
ask '(run-commands "vikix-layout-pick strip")' >/dev/null; sleep 0.5
check "vikix-layout-pick strip: $(now)" test "$(now)" = STRIP
ask '(run-commands "vikix-layout-pick main")' >/dev/null; sleep 0.5
check "from a strip to main and stack: $(now)" test "$(now) $(shape)" = "MAIN 1"
ask '(vikix-layout-save "kept")' >/dev/null
check "a layout saved in the mode says so" grep -q ':mode :main' "$home/.config/vikix/layouts/kept.lisp"
ask '(run-commands "vikix-layout-pick tiles")' >/dev/null; key super+b
check "vikix-layout-pick tiles: the layout is yours: $(now)" test "$(now) $(on)" = "TILES 0"
ask '(vikix-layout-restore "kept" (current-group) :start nil)' >/dev/null; sleep 0.5
check "and put back, the workspace is in the mode again: $(now)" test "$(now) $(shape)" = "MAIN 1"

# Super+o: every workspace that has windows, drawn small on one card
# (overview.lisp). Tiles are their frames; a frame's windows behind the one
# it shows are lines in its box, and can be picked; the frame goes from one
# workspace's windows to another's; g is StumpWM's expose, the real grid.
ov() { ask '(progn (setf *print-pretty* nil) (format t "~a ~a" (if *vikix-overview* (xlib:window-map-state (getf *vikix-overview* :card)) "closed") (and *vikix-overview* (getf *vikix-overview* :at) (window-title (getf *vikix-overview* :at)))))'; }
focus() { ask '(princ (window-title (current-window)))'; }
ask '(progn (run-commands "vikix-layout-pick tiles") (run-commands "only") (run-commands "hsplit"))' >/dev/null; sleep 0.5
key super+shift+3
# The frame the window left may be empty: a window in it, to start from.
ask '(unless (current-window) (run-commands "pull-hidden-next"))' >/dev/null; sleep 0.3
tiled=$(ask '(princ (length (remove-if-not (lambda (w) (typep w (quote tile-window))) (group-windows (current-group)))))')
key super+o
check "Super+o on tiles: the card, the frame on the window you're in: $(ov)" test "$(ov)" = "VIEWABLE $(focus)"
check "a panel for each workspace with windows: $(ask '(princ (mapcar (lambda (p) (group-name (getf p :group))) (getf (getf *vikix-overview* :plan) :panels)))')" test "$(ask '(princ (mapcar (lambda (p) (group-name (getf p :group))) (getf (getf *vikix-overview* :plan) :panels)))')" = "(1 3)"
check "every tiled window here is a box, a line behind its frame's, or counted in a line of more" test "$(ask '(let* ((panel (first (getf (getf *vikix-overview* :plan) :panels)))) (princ (+ (length (getf panel :boxes)) (reduce (function +) (getf panel :notes) :key (function first)))))')" = "$tiled"
key j
behind=$(ask '(princ (window-title (getf *vikix-overview* :at)))')
check "down from a frame's window: one behind it: $behind" test "$(ask '(princ (getf (find (getf *vikix-overview* :at) (vikix-overview-boxes) :key (lambda (b) (getf b :window))) :kind))')" = HIDDEN
key Return
check "Enter brings it to the front of its frame: $(focus)" test "$(focus) $(ask '(princ (window-title (frame-window (window-frame (current-window)))))') $(ov)" = "$behind $behind closed NIL"
key super+o
other=$(ask '(princ (window-title (getf (first (getf (second (getf (getf *vikix-overview* :plan) :panels)) :boxes)) :window)))')
for _ in 1 2 3 4 5 6; do [ "$(ov)" = "VIEWABLE $other" ] && break; key l; done
check "the frame walks on to the other workspace's window ($other): $(ov)" test "$(ov)" = "VIEWABLE $other"
key Return
check "Enter goes there, workspace and all: $(focus) on $(ask '(princ (group-name (current-group)))')" test "$(focus) $(ask '(princ (group-name (current-group)))')" = "$other 3"
key super+o; xdotool mousemove 3 3; sleep 0.3; xdotool click 1; sleep 0.5
check "a click off the card closes it" test "$(ov)" = "closed NIL"
key super+1; key super+o; key g; sleep 1; key 0
check "g is the real grid: the frame picked there has the workspace to itself, as expose leaves it" test "$(frames) $(ov)" = "1 closed NIL"
key super+o; key slash; sleep 0.7; key Escape
check "/ is the list of every window, closed with Escape; the card is gone" test "$(ov)" = "closed NIL"
check "nothing was written to the errors folder" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report main "main and stack from any layout, a new window at the top of the stack (or as the main one), swapping, widths, a closed window, a split put back, focus mode and back, a full stack, a dialog, another workspace, off and on, grid mode, the layout picker, a saved layout, the overview of every workspace"
exit "$fail"
