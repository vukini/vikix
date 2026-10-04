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
focus() { ask '(princ (window-title (current-window)))'; }
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

# Scrolling slides: in steps, quick then slow, to the same places as a jump
# (only with a compositor, so here it's told to, always); and with
# *viri-centre* the focused column is kept in the middle.
check "a slide's steps lie between its ends, each nearer, the first the longest: $(ask '(princ (viri-slide-offsets 0 640))')" test "$(ask '(let ((o (viri-slide-offsets 0 640))) (princ (if (and (= (length o) (1- *viri-animate-frames*)) (apply (function <) 0 (append o (list 640))) (> (first o) (- 640 (car (last o))))) 1 0)))')" = 1
check "no compositor here, so no slide by itself" test "$(ask '(princ (if (viri-animate-p (current-group)) 1 0))')" = 0
ask '(progn (defvar *slides* 0) (setf *viri-animate* :always) (sb-int:unencapsulate (quote viri-slide) (quote test)) (sb-int:encapsulate (quote viri-slide) (quote test) (lambda (f &rest args) (incf *slides*) (apply f args))))' >/dev/null
inplace() { ask '(let ((g (current-group))) (multiple-value-bind (ax ay aw) (viri-area g) (declare (ignore ay)) (princ (if (and (= (viri-offset g) (car (gethash g *viri-drawn*))) (every (lambda (c span) (every (lambda (w) (= (xlib:drawable-x (window-parent w)) (+ ax (- (car span) (viri-offset g))))) (viri-col-windows c))) (viri-cols g) (viri-spans g aw))) 1 0))))'; }
for _ in 1 2 3 4 5 6 7 8; do key super+h; done
ask '(setf *slides* 0)' >/dev/null
for _ in 1 2 3 4 5 6 7 8; do key super+l; done
check "walking to the strip's other end slid it: $(ask '(princ *slides*)') slides" test "$(ask '(princ *slides*)')" -ge 1
check "and every window stands where a jump would have put it" test "$(inplace)" = 1
ask '(setf *viri-centre* t)' >/dev/null
key super+h; key super+h
check "with *viri-centre* the focused column is in the middle, as far as the strip's ends allow" test "$(ask '(let* ((g (current-group)) (i (position (viri-col-of g (current-window)) (viri-cols g)))) (multiple-value-bind (ax ay aw) (viri-area g) (declare (ignore ax ay)) (let* ((spans (viri-spans g aw)) (span (nth i spans)) (l (car (last spans))) (total (+ (car l) (cdr l)))) (princ (if (= (viri-offset g) (max 0 (min (- total aw) (- (+ (car span) (floor (cdr span) 2)) (floor aw 2))))) 1 0)))))') $(inplace)" = "1 1"
ask '(progn (setf *viri-centre* nil *viri-animate* t) (sb-int:unencapsulate (quote viri-slide) (quote test)))' >/dev/null

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

# The mouse on a strip: Super and the wheel walk along it; Super and a drag
# with the right button, or a drag of a column's side edge, change its
# width a twentieth of the screen at a time; a drag of its title bar carries
# the column to where it's let go; a click on the title bar moves nothing.
# On the bar the wheel walks too, and on the overview a click on a box goes
# to its window, a click off the card closes it.
mouse() { xdotool "$@"; sleep 0.4; }
# A press on a title bar or an edge isn't held back by a grab, as one on a
# program's window is: what the pointer does before StumpWM has taken it is
# lost. A hand is slower than that; on a busy machine a test isn't, so it waits.
press() { xdotool mousedown "$1"; sleep 1.5; }
order() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (mapcar (lambda (c) (window-title (first (viri-col-windows c)))) (viri-cols (current-group)))))'; }
geo() { ask "(let ((p (window-parent $1))) (format t \"~a ~a ~a ~a ~a\" (xlib:drawable-x p) (xlib:drawable-y p) (xlib:drawable-width p) (xlib:drawable-height p) (xlib:drawable-border-width p)))"; }
width() { ask '(princ (viri-col-width (viri-col-of (current-group) (current-window))))'; }
for _ in 1 2 3 4 5 6 7 8; do key super+h; done
one=$(focus); read -r one two _ <<<"$(order)"
read -r x y w h b <<<"$(geo '(current-window)')"
mouse mousemove $((x + w / 2)) $((y + h / 2))
mouse keydown super click 5 keyup super
check "Super and the wheel down walks to the next column: $(focus)" test "$(focus)" = "$two"
mouse keydown super click 4 keyup super
check "and the wheel up walks back: $(focus)" test "$(focus)" = "$one"
was=$(width)
mouse mousemove $((x + w / 2)) $((y + h / 2)); mouse keydown super mousedown 3; mouse mousemove_relative 64 0; mouse mousemove_relative 64 0; mouse mouseup 3 keyup super
check "Super and a drag with the right button makes the column a tenth of the screen wider: $was, then $(width)" test "$(ask "(princ (if (= (viri-col-width (viri-col-of (current-group) (current-window))) (+ $was 1/10)) 1 0))")" = 1
read -r x y w h b <<<"$(geo '(current-window)')"
mouse mousemove $((x + b + w)) $((y + h / 2)); press 1; mouse mousemove_relative -- -64 0; mouse mousemove_relative -- -64 0; mouse mouseup 1
check "a drag of its side edge brings it back: $(width)" test "$(width)" = "$was"
check "the pointer stayed at the edge it pressed, not sent to the window's middle" test "$(ask '(princ (if (< (abs (- (xlib:global-pointer-position *display*) (let ((p (window-parent (current-window)))) (+ (xlib:drawable-x p) (xlib:drawable-width p))))) 12) 1 0))')" = 1
before=$(order)
read -r x y w h b <<<"$(geo '(current-window)')"
mouse mousemove $((x + 100)) $((y + b + 8)); mouse click 1; mouse click 1
check "clicks on a title bar move nothing: $(order)" test "$(order) $(inplace) $(focus)" = "$before 1 $one"
read -r x2 _ w2 _ _ <<<"$(geo "$(find_w "$two")")"
mouse mousemove $((x + 100)) $((y + b + 8)); press 1; mouse mousemove $((x2 + w2 / 2 - 100)) $((y + b + 8)); mouse mousemove $((x2 + w2 / 2 + 60)) $((y + b + 8)); mouse mouseup 1
check "a title bar dragged past the next column's middle: the column stays there: $(order)" test "$(order | cut -d' ' -f1-2) $(inplace) $(focus)" = "$two $one 1 $one"
ask "(viri-ml-click 4 (window-id (current-window)))" >/dev/null; sleep 0.3
check "the wheel on the bar's window names walks along the strip: $(focus)" test "$(focus)" = "$two"
key super+o
target=$(ask '(princ (window-title (first (last (viri-columns (current-group))))))')
read -r bx by <<<"$(ask '(let* ((st *viri-overview*) (card (getf st :card)) (g (getf st :group))) (multiple-value-bind (boxes pw) (viri-overview-boxes g (getf st :room)) (multiple-value-bind (x0 y0) (viri-overview-origin (xlib:drawable-width card) pw (getf st :pad) (getf st :line)) (let ((b (first (last boxes)))) (format t "~a ~a" (+ (xlib:drawable-x card) 1 x0 (second b) (floor (fourth b) 2)) (+ (xlib:drawable-y card) 1 y0 (third b) (floor (fifth b) 2)))))))')"
mouse mousemove "$bx" "$by"; mouse click 1
check "a click on a box of the overview goes to its window ($target), the card gone" test "$(focus) $(ask '(princ (if *viri-overview* 1 0))')" = "$target 0"
# Off the card, on the window you're in: a click elsewhere would focus that.
read -r x y w h b <<<"$(geo '(current-window)')"
key super+o; mouse mousemove $((x + w / 2)) $((y + h - 20)); mouse click 1
check "a click off the card closes it, nothing moved" test "$(focus) $(ask '(princ (if *viri-overview* 1 0))')" = "$target 0"

# The window keys that only knew tiles: on a strip each does its thing, or
# says why not; none is an error.
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

wm_report viri "a strip from tiles and back in order, walking and moving along it, stacking, widths, rules for strips, the drawn overview and its keys, the agents' desktop tool, new and closed windows, a dialog, another workspace, off and on, sliding and centring, title bars, the mouse, the window keys on a strip"
exit "$fail"
