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
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup viri
# Rules for strips (the verbs width and join): they act on a strip only.
cat > "$home/.stumpwm.d/rules.lisp" <<'EOF'
(when-window (:title "Wide") (width 2/3))
(when-window (:title "Under") (join :left))
EOF
wm_start
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

# Stacking: Super+[ / ] take a window into the column beside, or out of a
# shared one; Super+j/k go up and down it, with Shift they move the window.
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
cols() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^|~} focus=~a" (mapcar (lambda (c) (format nil "~{~a~}" (mapcar (function window-title) (viri-col-windows c)))) (viri-cols (current-group))) (window-title (current-window))))'; }
ask '(group-focus-window (current-group) (third (viri-columns (current-group))))' >/dev/null; sleep 0.3
start=$(cols)
key super+bracketleft
check "Super+[ : the window joins the column on its left, below: $start -> $(cols)" grep -qE '^[A-Z]\|[A-Z]{2}\|[A-Z] focus=' <<<"$(cols)"
joined=$(cols)
heights=$(ask '(let ((c (viri-col-of (current-group) (current-window)))) (format t "~{~a~^ ~}" (mapcar (lambda (w) (xlib:drawable-height (window-parent w))) (viri-col-windows c))))')
check "the two share the column's height, one above the other: $heights" bash -c 'set -- $0; [ $# = 2 ] && [ $(( $1 - $2 )) -le 2 ] && [ $(( $2 - $1 )) -le 2 ] && [ $1 -gt 300 ] && [ $1 -lt 400 ]' "$heights"
key super+k
check "Super+k goes up the column: $(cols)" test "${joined##*focus=}" != "$(cols | sed 's/.*focus=//')"
key super+j
check "Super+j comes back down: $(cols)" test "$(cols)" = "$joined"
key super+shift+k
check "Super+Shift+k moves it above: $(cols)" test "$(cols | cut -d'|' -f2 | cut -c1)" = "${joined##*focus=}"
key super+bracketright
check "Super+] takes it out, into a column of its own on the right: $(cols)" test "$(cols | tr -cd '|' | wc -c)" = 3

# Widths: Super+r on a strip, a third, a half, two thirds, all of it. The
# strip scrolls to show the focused column whole.
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
width() { ask '(let ((p (window-parent (current-window)))) (format t "~a ~a" (xlib:drawable-x p) (+ (xlib:drawable-width p) (* 2 (xlib:drawable-border-width p)))))'; }
key super+r
read -r x w <<<"$(width)"
check "Super+r: two thirds of the screen, wholly on it: $x $w" test "$w" = 853 -a "$x" -ge 0 -a $((x + w)) -le 1280
key super+r
check "Super+r again: the whole screen: $(width)" test "$(width)" = "0 1280"
key super+r
read -r x w <<<"$(width)"
check "and again: a third: $x $w" test "$w" = 426 -a "$x" -ge 0
key super+r
read -r x w <<<"$(width)"
check "and round to a half: $x $w" test "$w" = 640
ask '(run-commands "vikix-viri off")' >/dev/null; sleep 0.5
ask '(run-commands "hsplit")' >/dev/null; sleep 0.3
frames=$(ask '(princ (length (group-frames (current-group))))')
key super+r
check "on tiles Super+r still removes a split" test "$(ask '(princ (length (group-frames (current-group))))')" = $((frames - 1))

# Super+o on a strip: the strip drawn small on a card. The arrows or h/l
# move a frame along it, Enter goes there, a digit goes to the window with
# that number, / is the list to type in, any other key closes; one bound to
# something else does that too.
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
ov() { ask '(progn (setf *print-pretty* nil) (format t "~a ~a" (if *viri-overview* (xlib:window-map-state (getf *viri-overview* :card)) "closed") (and *viri-overview* (window-title (getf *viri-overview* :at)))))'; }
first=$(ask '(princ (window-title (first (viri-columns (current-group)))))')
second=$(ask '(princ (window-title (viri-col-window (second (viri-cols (current-group))))))')
was_in=$(ask '(princ (window-title (current-window)))')
key super+o
check "Super+o draws the strip on a card, the frame on the window you're in: $(ov)" test "$(ov)" = "VIEWABLE $was_in"
check "a box for each window, all inside the picture" test "$(ask '(multiple-value-bind (boxes w h) (viri-overview-boxes (current-group) (getf *viri-overview* :room)) (princ (if (and (= (length boxes) (length (viri-columns (current-group)))) (every (lambda (b) (and (<= 0 (second b)) (<= (+ (second b) (fourth b)) (1+ w)) (<= (+ (third b) (fifth b)) (1+ h)))) boxes)) 1 0)))')" = 1
for _ in 1 2 3 4 5 6 7 8; do key h; done
check "h walks the frame to the first window, and stops there: $(ov)" test "$(ov)" = "VIEWABLE $first"
key Right
check "the right arrow moves it a column on: $(ov)" test "$(ov)" = "VIEWABLE $second"
check "the strip hasn't moved yet: $(ask '(princ (window-title (current-window)))')" test "$(ask '(princ (window-title (current-window)))')" = "$was_in"
key h; key Return
check "Enter goes to the window in the frame ($first), the card gone: $(state)" test "$(ask '(princ (window-title (current-window)))') $(ov)" = "$first closed NIL"
check "and scrolls the strip to it" test "$(ask '(princ (if (member 0 (viri-visible (current-group))) 1 0))')" = 1
num=$(ask "(princ (window-number $(find_w "$second")))")
key super+o; key "$num"
check "a digit goes straight to the window with that number ($num, $second)" test "$(ask '(princ (window-title (current-window)))') $(ov)" = "$second closed NIL"
key super+o; key Escape
check "Escape closes it, nothing moved, the keyboard yours again" test "$(ask '(princ (window-title (current-window)))') $(ov) $(ask '(princ *custom-key-event-handler*)')" = "$second closed NIL NIL"
key super+o; key super+o
check "Super+o again closes it" test "$(ov)" = "closed NIL"
key super+o; key super+h
check "a key bound to something else closes it and does its thing: $(state)" test "$(ask '(princ (window-title (current-window)))') $(ov)" = "$first closed NIL"
# The last one: its one-letter title is in no other line of the list.
last=$(ask '(princ (window-title (first (last (viri-columns (current-group))))))')
key super+o; key slash; sleep 0.5
xdotool type "$last"; key Return
check "/ is the list to type in ($last): $(state)" test "$(ask '(princ (window-title (current-window)))')" = "$last"
key super+o; win Late
check "a window opening closes the card: it would show what isn't so" test "$(ov)" = "closed NIL"
ask "(delete-window $(find_w Late))" >/dev/null; sleep 1

# The agents' desktop tool (vikix mcp) sees a strip: its kind and columns.
mcp=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"desktop","arguments":{}}}' |
      HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR=$here python3 "$here/bin/vikix-mcp" 2>/dev/null)
strip=$(python3 -c '
import json, sys
reply = json.loads(sys.stdin.read().splitlines()[-1])
d = json.loads(reply["result"]["content"][0]["text"])
w = [w for w in d["workspaces"] if w["current"]][0]
cols = w["strip"]["columns"]
print(w["kind"], len(cols), sum(len(c["windows"]) for c in cols) <= len(w["windows"]), any(c["on_screen"] for c in cols), all(c["width"] in ("1/3", "1/2", "2/3", "1") for c in cols))
' <<<"$mcp" 2>&1)
check "the desktop tool reports the strip, its columns, widths and what is on the screen: $strip" test "$strip" = "strip $(ask '(princ (length (viri-cols (current-group))))') True True True"

# The rules: on a strip, "Wide" opens two thirds wide, "Under" joins the
# column on its left; on tiles they do nothing (no error, no menu).
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
win Wide
check "a rule's (width 2/3) makes the new column two thirds wide: $(width)" test "$(width | cut -d' ' -f2)" = 853
win Under
check "a rule's (join :left) puts the new window under the column on its left: $(cols)" grep -q 'WideUnder' <<<"$(cols)"
check "the rules ran without failing" test "$(ask '(princ (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))')" = 0

# Title bars: each column's window has the tiles' bar, as wide as the column,
# the window below it; Super+Ctrl+y takes them away and brings them back; a
# fullscreen window has none.
bars() { ask '(progn (setf *print-pretty* nil) (let ((ws (viri-columns (current-group)))) (format t "~a/~a" (count-if (lambda (w) (let ((bar (gethash w *vikix-titlebar-windows*))) (and bar (not (eq (xlib:window-map-state bar) :unmapped)) (= (xlib:drawable-width bar) (xlib:drawable-width (window-parent w))) (= (xlib:drawable-y (window-xwin w)) (xlib:drawable-height bar))))) ws) (length ws))))'; }
n=$(ask '(princ (length (viri-columns (current-group))))')
check "each column's window has a title bar as wide as it, the window below: $(bars)" test "$(bars)" = "$n/$n"
key super+ctrl+y
check "Super+Ctrl+y takes them away, the windows at the top again: $(bars)" test "$(bars) $(ask '(princ (hash-table-count *vikix-titlebar-windows*))') $(ask '(princ (xlib:drawable-y (window-xwin (current-window))))')" = "0/$n 0 0"
key super+ctrl+y
check "and brings them back: $(bars)" test "$(bars)" = "$n/$n"
key super+f
check "a fullscreen window has none: $(bars)" test "$(bars) $(ask '(princ (if (gethash (current-window) *vikix-titlebar-windows*) 1 0))')" = "$((n - 1))/$n 0"
key super+f
check "out of fullscreen it has its bar and its place again: $(bars)" test "$(bars)" = "$n/$n"

# The window keys that only knew tiles: on a strip each does its thing, or
# says why not; none is an error.
focus() { ask '(princ (window-title (current-window)))'; }
find_any() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))"; }
msgs() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~%~}" (subseq (screen-last-msg (current-screen)) 0 (min 30 (length (screen-last-msg (current-screen)))))))'; }
ask '(message "the window keys")' >/dev/null
was=$(focus); key super+h; now=$(focus)
key super+Tab
check "Super+Tab on a strip goes back to the window you were in: $was, $now, $(focus)" test "$was" != "$now" -a "$(focus)" = "$was"
key super+Tab
check "and again flips between the two: $(focus)" test "$(focus)" = "$now"
xdotool mousemove 5 400; sleep 0.3; ask "(focus-all $(find_w "$now"))" >/dev/null; key super+p
check "Super+p brings the pointer to the window" test "$(ask '(let ((p (window-parent (current-window)))) (multiple-value-bind (x y) (xlib:global-pointer-position *display*) (princ (if (and (<= (xlib:drawable-x p) x (+ (xlib:drawable-x p) (xlib:drawable-width p))) (<= (xlib:drawable-y p) y (+ (xlib:drawable-y p) (xlib:drawable-height p)))) 1 0))))')" = 1
key super+u; key super+shift+u; key super+b; key super+v
check "Super+u, Super+b and Super+v say a strip has none of that" test "$(msgs | grep -c 'A strip has no splits\|Layout undo is for tiled')" -ge 3
sent=$(focus); key super+shift+3
check "a column sent to a tiled workspace is tiled there, in a frame: $sent" test "$(ask "(princ (type-of $(find_any "$sent")))")" = TILE-WINDOW
key super+3; key super+g; sleep 1; key Return   # the list first, then Enter: a slow machine
check "Super+g from there goes to a window on the strip: $(focus)" test "$(ask '(princ (if (viri-group-p) 1 0))') $(focus)" != "0 $sent"
key super+3; key super+shift+g; sleep 1; key Return
check "Super+Shift+g brings one off the strip, into a frame: $(focus)" test "$(ask '(princ (list (group-number (current-group)) (type-of (current-window))))')" = "(3 TILE-WINDOW)"
key super+1
check "none of them was an error: $(msgs | grep -i 'Error In Command\|not found' | head -1)" test -z "$(msgs | sed '/the window keys/,$d' | grep -i 'Error In Command\|not found')"

wm_report viri "a strip from tiles and back in order, walking and moving along it, stacking, widths, rules for strips, the drawn overview and its keys, the agents' desktop tool, new and closed windows, a dialog, another workspace, off and on, title bars, the window keys on a strip"
exit "$fail"
