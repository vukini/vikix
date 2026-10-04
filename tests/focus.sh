#!/usr/bin/env bash
# tests/focus.sh — focus follows the mouse, and never runs away with the
# desktop: in a real StumpWM on a hidden screen.
#
#   A floating window over a tile, the pointer resting on both, and four
#   changes of focus handled in one go: the desktop still answers, and the
#   two windows haven't gone on taking the focus from each other (they did
#   for ever, with StumpWM's one thread never free again: the desktop froze).
#   With floating windows kept in front (a rule with the verb dialog): the
#   pointer moved onto a window gives it the focus, tiled or floating; a
#   window gone to with a key keeps the focus while the pointer rests on
#   another; the mouse moved away and back to the same spot is the mouse
#   again; and five changes at once still don't run away.
#   A window a rule floats as it opens: it has the focus wherever the
#   pointer rests, so a rule that keeps floating windows in front holds
#   for it from the start; the frame in front keeps its window; and opened
#   for a workspace not in view, it is shown there, with the focus, when
#   that workspace is gone to. So is a floating window sent to another
#   workspace (Super+Shift+digit): StumpWM never showed either again.
#   A window whose WM_HINTS can't be read (a number that is no X id where
#   its icon belongs): StumpWM goes on, and the window is raised and takes
#   the focus like any other.
#
# Needs what tests/lib/wm.sh needs (Xvfb, xdotool, alacritty, Vikix's
# StumpWM); skipped without.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup focus
wm_start

w() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))"; }
focused() { ask '(princ (let ((w (current-window))) (and w (window-title w))))'; }
# Is the floating window above the tile, as X stacks them?
in_front() { [ "$(ask "(let ((kids (xlib:query-tree (screen-root (current-screen))))) (princ (if (> (position (window-parent $(w Over)) kids) (position (window-parent $(w Under)) kids)) 1 0)))")" = 1 ]; }
# How often the focus has changed, counted in the test StumpWM.
ask '(progn (defvar *focus-test-changes* 0)
       (defun focus-test-count (&rest ignore) (declare (ignore ignore)) (incf *focus-test-changes*))
       (add-hook *focus-window-hook* (quote focus-test-count)))' >/dev/null
changes() { ask '(princ *focus-test-changes*)'; }

# A tile filling the screen, and a window floating over its middle.
win Under
win Over
ask "(let ((*vikix-rule-window* $(w Over))) (vikix-verb-float :width \"50%\" :height \"50%\"))" >/dev/null
sleep 0.5
off=(3 790)      # on the tile alone
on=(640 400)     # on the floating window (and the tile under it)

# --- the freeze --------------------------------------------------------------------
# The floating window has the focus (it opened last) and is in front; the
# pointer rests on it, and so on the tile under it. Four changes of focus
# before StumpWM looks at X again leave the EnterNotify events of the
# windows raised over each other waiting, out of step with where the
# focus is.
xdotool mousemove "${on[@]}"; sleep 0.5
before=$(changes)
ask "(progn (focus-all $(w Under)) (focus-all $(w Over)) (focus-all $(w Under)) (focus-all $(w Over)) (princ 1))" >/dev/null
sleep 3
after=$(changes)
check "StumpWM still answers three seconds after four changes of focus in one go: $after" grep -qE '^[0-9]+$' <<<"$after"
case $after in
  ''|*[!0-9]*) ;;   # no answer: said above
  *) check "the two windows went on taking the focus from each other: $((after - before)) changes for four asked" test $((after - before)) -le 8 ;;
esac
check "and the focus is where it was last put: $(focused)" test "$(focused)" = Over

# --- floating windows kept in front: the mouse, a key, and four at once ----------
# (A tile that gets the focus is raised over a floating window; this rule
# puts the floating ones back above it, as dialogs are.)
ask '(when-window (:where (lambda (w) (typep w (quote float-window)))) :on :focus :name "in front" (dialog))' >/dev/null
ask "(progn (focus-all $(w Under)) (focus-all $(w Over)))" >/dev/null; sleep 0.5   # the rule runs for the floating window
xdotool mousemove "${off[@]}"; sleep 0.5
check "the pointer moved onto the tile gives it the focus: $(focused)" test "$(focused)" = Under
check "the floating window is still in front of it" in_front
xdotool mousemove "${on[@]}"; sleep 0.5
check "the pointer moved onto the floating window gives it the focus: $(focused)" test "$(focused)" = Over
ask "(focus-all $(w Under))" >/dev/null; sleep 1
check "the tile gone to with a key keeps the focus while the pointer rests on the floating window in front: $(focused)" test "$(focused)" = Under
check "which is still in front" in_front
xdotool mousemove "${off[@]}"; sleep 0.4
xdotool mousemove "${on[@]}"; sleep 0.5
check "the mouse moved off and back to the same spot gives the floating window the focus again: $(focused)" test "$(focused)" = Over
before=$(changes)
ask "(progn (focus-all $(w Under)) (focus-all $(w Over)) (focus-all $(w Under)) (focus-all $(w Over)) (focus-all $(w Under)) (princ 1))" >/dev/null
sleep 3
after=$(changes)
check "StumpWM still answers with floating windows kept in front: $after" grep -qE '^[0-9]+$' <<<"$after"
case $after in
  ''|*[!0-9]*) ;;
  *) check "nor do the two take the focus from each other then: $((after - before)) changes for five asked" test $((after - before)) -le 10 ;;
esac
check "and the focus is where it was last put: $(focused)" test "$(focused)" = Under
# --- a window a rule floats as it opens ---------------------------------------------
# StumpWM gives a new window the focus as a tile, and only shows a floating
# one: a window a rule floated had the focus only with the pointer where it
# appeared, so the rule above never ran for it and the next tile to take
# the focus covered it; the frame in front was left with no window; and on
# a workspace not in view the window was never shown at all.
above() { [ "$(ask "(let ((kids (xlib:query-tree (screen-root (current-screen))))) (princ (if (> (position (window-parent $(w "$1")) kids) (position (window-parent $(w "$2")) kids)) 1 0)))")" = 1 ]; }
front_frame() { ask '(princ (let ((w (frame-window (tile-group-current-frame (current-group))))) (and w (window-title w))))'; }
shown() { ask "(princ (xlib:window-map-state (window-parent $(w "$1"))))"; }
ask '(progn (when-window (:class "Small") (float :width "30%" :height "30%" :corner :bottom-right))
       (when-window (:class "Away") (workspace 3) (float :width "30%" :height "30%" :corner :bottom-right)))' >/dev/null
ask '(run-commands "gselect 3")' >/dev/null; sleep 0.4
win There
ask '(run-commands "gselect 2")' >/dev/null; sleep 0.4
win Left
ask '(run-commands "hsplit")' >/dev/null; sleep 0.3
ask '(run-commands "fnext")' >/dev/null; sleep 0.3
win Right
xdotool mousemove 300 300; sleep 0.5      # on Left, far from where the window will appear
ask "(focus-all $(w Right))" >/dev/null; sleep 0.5
win Small Small
check "a window a rule floats as it opens has the focus, the pointer resting elsewhere: $(focused)" test "$(focused)" = Small
check "the frame in front keeps the window it shows: $(front_frame)" test "$(front_frame)" = Right
ask '(run-commands "fnext")' >/dev/null; sleep 0.5
check "a tile gone to with a key has the focus: $(focused)" test "$(focused)" = Left
check "and the floating window, kept in front by the rule, is still over the tile under it" above Small Right
xdotool mousemove 900 300; sleep 0.5
check "the same with the mouse moved to the tile under it: $(focused)" test "$(focused)" = Right
check "the floating window still in front" above Small Right

# Opened for a workspace that isn't in view.
LIBGL_ALWAYS_SOFTWARE=1 alacritty --class Away --title Away -e sleep 300 >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 1 40); do [ "$(ask "(princ (if $(w Away) 1 0))")" = 1 ] && break; sleep 0.25; done
sleep 0.5
check "a window a rule floats on another workspace leaves the focus where it is: $(focused), workspace $(ask '(princ (group-number (current-group)))')" \
  test "$(focused) $(ask '(princ (group-number (current-group)))')" = "Right 2"
ask '(run-commands "gselect 3")' >/dev/null; sleep 0.7
check "gone to, that workspace shows it: $(shown Away)" test "$(shown Away)" = VIEWABLE
check "with the focus: $(focused)" test "$(focused)" = Away
check "in front of the tile there" above Away There
xdotool mousemove 1000 700; sleep 0.4     # onto it, and off: the pointer was on the tile all along
xdotool mousemove 300 300; sleep 0.5
check "and it stays in front when the mouse gives the tile the focus: $(focused)" test "$(focused)" = There
check "(in front)" above Away There
ask '(run-commands "gselect 2")' >/dev/null; sleep 0.4
ask '(run-commands "gselect 3")' >/dev/null; sleep 0.7
check "away and back, it is still shown, and the tile keeps the focus: $(shown Away), $(focused)" test "$(shown Away) $(focused)" = "VIEWABLE There"
# A floating window sent away once it is open: by a rule (vikix rules
# apply), and with Super+Shift+digit.
ask "(let ((*vikix-rule-window* $(w Away))) (vikix-verb-workspace 2))" >/dev/null; sleep 0.5
ask '(run-commands "gselect 2")' >/dev/null; sleep 0.7
check "a floating window a rule sends to another workspace is shown there too: $(shown Away), $(focused)" test "$(shown Away) $(focused)" = "VIEWABLE Away"
ask '(run-commands "gmove 3")' >/dev/null; sleep 0.5
check "sent back with the key, it is gone from here: $(shown Away)" test "$(shown Away)" = UNMAPPED
ask '(run-commands "gselect 3")' >/dev/null; sleep 0.7
check "and shown there, with the focus: $(shown Away), $(focused)" test "$(shown Away) $(focused)" = "VIEWABLE Away"

# --- a window whose WM_HINTS can't be read ----------------------------------------
# One program wrote the letters "calc" (1668047203) where its icon's id
# belongs. CLX refuses the number, and StumpWM reads the hints at every
# raise and every change of them: an error it didn't catch.
ask '(run-commands "gselect 4")' >/dev/null; sleep 0.4
win Odd
win Plain
ask "(xlib:change-property (window-xwin $(w Odd)) :WM_HINTS (list (+ 7 256) 1 1 1668047203 0 0 0 0 0) :WM_HINTS 32)" >/dev/null; sleep 0.5
check "StumpWM still answers when a window's hints can't be read: $(ask '(princ 1)')" test "$(ask '(princ 1)')" = 1
out=$(ask "(princ (let ((h (xlib:wm-hints (window-xwin $(w Odd))))) (and h (list (xlib:wm-hints-flags h) (xlib:wm-hints-input h)))))")
check "what it asks of them is kept, the keyboard and the urgency, and the icon left out: $out" test "$out" = "(257 ON)"
ask "(focus-all $(w Odd))" >/dev/null; sleep 0.5
check "and the window is raised and takes the focus like any other: $(focused)" test "$(focused)" = Odd
ask "(xlib:change-property (window-xwin $(w Plain)) :WM_HINTS (list 3 1 1 0 0 0 0 0 0) :WM_HINTS 32)" >/dev/null; sleep 0.3
out=$(ask "(princ (let ((h (xlib:wm-hints (window-xwin $(w Plain))))) (and h (list (xlib:wm-hints-input h) (xlib:wm-hints-initial-state h)))))")
check "hints that can be read are read whole, as before: $out" test "$out" = "(ON NORMAL)"

check "no rule failed" test "$(ask '(princ (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))')" = 0

wm_report focus "the mouse gives the focus, four changes of focus in one go don't set a floating window and the tile under it taking it from each other for ever, a window gone to with a key keeps it under a still pointer, floating windows kept in front too, a window a rule floats has the focus as it opens, a floating window opened on or sent to a workspace that wasn't in view is shown there, a window whose hints can't be read is raised like any other"
exit "$fail"
