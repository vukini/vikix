#!/usr/bin/env bash
# tests/drawer.sh — the drawer (drawer.lisp), in a real StumpWM on a hidden
# screen.
#
#   Super+Ctrl+b starts the drawer's programs and puts their windows in a
#   column at the right edge, 30% wide, one above the other, floating over
#   the tiles, which stay as they are; a program is known by the process
#   that started it, or by its MATCH when its window is another process's,
#   and is the drawer's whatever a rule of yours says of that program;
#   the key again puts them away on the hidden workspace, not shown, the
#   focus back where it was, the bar not listing that workspace; again and
#   they are back, the same windows; on another workspace the key brings the
#   drawer there; a closed program is started again; on a strip the drawer's
#   windows are no columns; it slides in and away; a restart's tiles are the
#   drawer's again; the left edge and another width; a window tiled
#   with Super+t leaves the drawer; a reload keeps it; no programs, said.
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
wm_setup drawer
export LIBGL_ALWAYS_SOFTWARE=1   # the drawer's programs are alacritty, started by StumpWM
# Two programs: one known by its process, one whose window comes from a
# process the drawer didn't start (setsid -f leaves it nobody's child).
cat > "$home/.stumpwm.d/user.lisp" <<'L'
(in-package :stumpwm)
(setf *vikix-drawer-apps*
      '(("One" "alacritty --class drawerone --title One -e sleep 300")
        ("Two" "setsid -f alacritty --class drawertwo --title Two -e sleep 300" :class "drawertwo")))
L
# A rule of the user's for the first program: the drawer's window is the
# drawer's all the same.
cat > "$home/.stumpwm.d/rules.lisp" <<'L'
(in-package :stumpwm)
(when-window (:class "drawerone") (workspace 3) (float :width 300 :height 200))
L
wm_start

# The drawer's windows on the current workspace, top to bottom: title,
# x, y, width, height of the whole window; then the focused window.
state() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~} focus=~a" (mapcar (lambda (w) (let ((p (window-parent w))) (format nil "~a:~d,~d,~dx~d" (window-title w) (xlib:drawable-x p) (xlib:drawable-y p) (+ (xlib:drawable-width p) (* 2 (xlib:drawable-border-width p))) (+ (xlib:drawable-height p) (* 2 (xlib:drawable-border-width p)))))) (remove (current-group) (vikix-drawer-windows) :key (function window-group) :test-not (function eq))) (and (current-window) (window-title (current-window)))))'; }
names() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (mapcar (function window-title) (remove (current-group) (vikix-drawer-windows) :key (function window-group) :test-not (function eq)))))'; }
parked() { ask '(progn (setf *print-pretty* nil) (let ((g (find-group (current-screen) ".drawer"))) (format t "~{~a~^ ~}" (and g (sort (mapcar (lambda (w) (format nil "~a:~a" (window-title w) (if (window-visible-p w) "shown" "hidden"))) (group-windows g)) (function string<))))))'; }
tiles() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (mapcar (lambda (f) (format nil "~a@~d" (let ((w (frame-window f))) (and w (window-title w))) (frame-x f))) (sort (copy-list (group-frames (current-group))) (function <) :key (function frame-x)))))'; }
wait_for() {   # wait_for COMMAND WANTED: until COMMAND prints WANTED, ten seconds at most
  for _ in $(seq 1 40); do [ "$("$1")" = "$2" ] && return 0; sleep 0.25; done
  return 0
}
bar=$(ask '(princ (let ((ml (head-mode-line (current-head)))) (if ml (mode-line-height ml) 0)))')
below=$((800 - bar))

win A; win B
key super+b    # two tiles, side by side
ask '(focus-frame (current-group) (first (sort (copy-list (group-frames (current-group))) (function <) :key (function frame-x))))' >/dev/null
before=$(tiles)
key super+ctrl+b
wait_for names "One Two"
sleep 0.5
check "Super+Ctrl+b: the drawer's programs come out, in their order: $(names)" test "$(names)" = "One Two"
read -r one two _ <<<"$(state)"
check "a column at the right edge, 30% wide, from the bar down: $one" grep -qx "One:896,$bar,384x$((below / 2))" <<<"$one"
check "the second below the first, to the bottom: $two" grep -qx "Two:896,$((bar + below / 2)),384x$((below - below / 2))" <<<"$two"
check "they float: the tiles stay as they were: $(tiles)" test "$(tiles)" = "$before"
check "a window known by its MATCH, not by its process: $(ask '(princ (vikix-drawer-started-by-p (find "Two" (vikix-drawer-windows) :key (function window-title) :test (function equal)) 1))')" test "$(names)" = "One Two"
check "a rule of yours for the same program (another workspace, a size) doesn't take it out of the drawer: $(ask '(princ (vikix-rule-runs (vikix-rule-called "drawerone")))') run" test "$(ask '(princ (vikix-rule-runs (vikix-rule-called "drawerone")))')" = 1

ask '(group-focus-window (current-group) (find "A" (group-windows (current-group)) :key (function window-title) :test (function equal)))' >/dev/null; sleep 0.3
check "with a tile focused the drawer is still in front" test "$(ask '(princ (let* ((d (find "One" (vikix-drawer-windows) :key (function window-title) :test (function equal))) (order (xlib:query-tree (screen-root (current-screen)))) (a (find "A" (group-windows (current-group)) :key (function window-title) :test (function equal)))) (if (> (position (window-parent d) order :test (function xlib:window-equal)) (position (window-parent a) order :test (function xlib:window-equal))) 1 0)))')" = 1

key super+ctrl+b
check "the key again: away, nothing of it on this workspace: '$(names)'" test -z "$(names)"
check "waiting on the hidden workspace, not shown: $(parked)" test "$(parked)" = "One:hidden Two:hidden"
check "the focus is back where it was: $(state)" grep -q 'focus=A$' <<<"$(state)"
check "the tiles are as they were: $(tiles)" test "$(tiles)" = "$before"
check "the bar doesn't list the hidden workspace: $(ask '(princ (vikix-mode-line-groups (head-mode-line (current-head))))')" test -z "$(ask '(princ (if (search ".drawer" (vikix-mode-line-groups (head-mode-line (current-head)))) "listed" ""))')"

ids=$(ask '(progn (setf *print-pretty* nil) (princ (sort (mapcar (function window-id) (vikix-drawer-windows)) (function <))))')
key super+ctrl+b
check "and out again, the same windows, none started twice: $(names)" test "$(names) $(ask '(progn (setf *print-pretty* nil) (princ (sort (mapcar (function window-id) (vikix-drawer-windows)) (function <))))')" = "One Two $ids"
check "nothing left waiting: '$(parked)'" test -z "$(parked)"
check "the first has the focus: $(state)" grep -q 'focus=One$' <<<"$(state)"

# Another workspace: the key brings the drawer there.
key super+2
check "on another workspace the drawer isn't there: '$(names)'" test -z "$(names)"
key super+ctrl+b
check "the key brings it here: $(names)" test "$(names)" = "One Two"
key super+1
check "and it has left the workspace it was on: '$(names)'" test -z "$(names)"
check "whose tiles are as they were: $(tiles)" test "$(tiles)" = "$before"
key super+2

# A program closed is started again the next time.
ask '(delete-window (find "One" (vikix-drawer-windows) :key (function window-title) :test (function equal)))' >/dev/null
wait_for names "Two"
check "a closed program's window is gone, the other has the column: $(names)" test "$(names)" = "Two"
key super+ctrl+b; key super+ctrl+b
wait_for names "One Two"
sleep 0.5
check "and it is started again when the drawer next comes out: $(names)" test "$(names)" = "One Two"

# A strip: the drawer's windows float over it, never a column.
win C
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
check "on a strip the drawer's windows are no columns: $(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function window-title) (viri-columns (current-group)))))')" test "$(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function window-title) (viri-columns (current-group)))))')" = "(C)"
read -r one _ <<<"$(state)"
check "and stand in their column still: $one" grep -q "^One:896,$bar,384x" <<<"$one"
key super+ctrl+b
check "away from a strip: '$(names)', the strip keeps its window" test "$(names)$(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function window-title) (viri-columns (current-group)))))')" = "(C)"
key super+ctrl+b
check "and out on it again: $(names)" test "$(names)" = "One Two"
key super+ctrl+b
ask '(vikix-viri "off")' >/dev/null; sleep 0.5

# With a compositor the drawer slides (here: told to, always); it ends where
# it stands without one, and goes away the same.
ask '(setf *viri-animate* :always)' >/dev/null
key super+ctrl+b
read -r one two _ <<<"$(state)"
check "sliding in, it ends in its column: $one $two" grep -qx "One:896,$bar,384x$((below / 2)) Two:896,$((bar + below / 2)),384x$((below - below / 2))" <<<"$one $two"
key super+ctrl+b
check "and slides away: '$(names)' $(parked)" test "$(names)$(parked)" = "One:hidden Two:hidden"
ask '(setf *viri-animate* t)' >/dev/null

# A desktop started again makes every window a tile and forgets whose it
# was: the name written on the window says, and it waits, floating, again.
ask '(let ((w (find "Two" (vikix-drawer-windows) :key (function window-title) :test (function equal)))) (move-window-to-group w (current-group)) (unfloat-window w (current-group)) (clrhash *vikix-drawer-windows*) (vikix-drawer-recover))' >/dev/null; sleep 0.5
check "after a restart the drawer knows its windows again, and they wait: $(parked)" test "$(parked) $(ask '(princ (length (vikix-drawer-windows)))')" = "One:hidden Two:hidden 2"
check "the tiles got their frame back: $(tiles)" grep -qv 'Two' <<<"$(tiles)"

# The left edge, another width.
ask '(setf *vikix-drawer-side* :left *vikix-drawer-width* 400)' >/dev/null
key super+ctrl+b
read -r one _ <<<"$(state)"
check "the left edge, 400 pixels wide: $one" grep -q "^One:0,$bar,400x" <<<"$one"

# Tiled with Super+t, a window is an ordinary one from then on.
ask '(group-focus-window (current-group) (find "Two" (vikix-drawer-windows) :key (function window-title) :test (function equal)))' >/dev/null
key super+t
check "a window tiled with Super+t has left the drawer: $(names)" test "$(names)" = "One"
ask '(delete-window (find "Two" (group-windows (current-group)) :key (function window-title) :test (function equal)))' >/dev/null; sleep 0.5

# A reload keeps the drawer's windows.
ask '(loadrc)' >/dev/null; sleep 2
check "after a reload the drawer still has its window: $(names)" test "$(names)" = "One"
key super+ctrl+b
check "and the key still puts it away: '$(names)' $(parked)" test "$(names)$(parked)" = "One:hidden"

check "no programs: said, nothing done" grep -q "no programs" <<<"$(ask '(progn (setf *vikix-drawer-apps* nil) (vikix-drawer) (princ (first (screen-last-msg (current-screen)))))')"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report drawer "its programs started and kept, a column at the edge over the tiles and over a strip, away on the hidden workspace and back, brought to another workspace, a closed program started again, sliding, known again after a restart, the other edge and width, Super+t takes a window out, a reload keeps it"
exit "$fail"
