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
check "no rule failed" test "$(ask '(princ (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))')" = 0

wm_report focus "the mouse gives the focus, four changes of focus in one go don't set a floating window and the tile under it taking it from each other for ever, a window gone to with a key keeps it under a still pointer, floating windows kept in front too"
exit "$fail"
