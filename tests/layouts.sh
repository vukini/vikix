#!/usr/bin/env bash
# tests/layouts.sh — saved layouts (layouts.lisp, vikix layout), in a real
# StumpWM on a hidden screen.
#
#   vikix layout save NAME writes a file of plain Lisp: windows by class and
#   title, splits as parts of the screen, no X ids; vikix layout NAME puts
#   the splits back with each window in its frame, a strip's columns with
#   their widths and stacking, and turns the workspace into what the layout
#   was (strip or tiles); a window the layout doesn't know stays; a saved
#   one that's closed is named; a file changed by hand is followed; the
#   rule verb (layout "NAME"); list and rm; a bad name refused.
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
wm_setup layouts
cat > "$home/.stumpwm.d/rules.lisp" <<'EOF'
(when-window (:title "Trigger") (layout "split"))
EOF
wm_start

layout() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_DIR=$here bash "$here/bin/vikix" layout "$@" 2>&1; }
w() { echo "(find \"$1\" (group-windows (current-group)) :key (function window-title) :test (function equal))"; }
# Tiles as one line: frames, and whether Alpha is shown in a frame of its
# own, apart from Gamma's (the split saved).
tiles() { ask "(let* ((g (current-group)) (a $(w Alpha)) (c $(w Gamma))) (format t \"~a frames=~a alpha-alone=~a\" (if (typep g (quote tile-group)) \"tiles\" \"strip\") (length (group-frames g)) (and a c (typep a (quote tile-window)) (eq (frame-window (window-frame a)) a) (not (eq (window-frame a) (window-frame c))))))"; }
strip() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^|~}" (mapcar (lambda (c) (format nil "~{~a~^/~}@~a" (mapcar (function window-title) (viri-col-windows c)) (viri-col-width c))) (viri-cols (current-group)))))'; }
file="$home/.config/vikix/layouts"

for n in Alpha Beta Gamma; do win "$n"; done
ask "(progn (run-commands \"hsplit\") (pull-window $(w Alpha) (second (group-frames (current-group)))) (focus-all $(w Gamma)))" >/dev/null; sleep 0.5
check "the split to save: $(tiles)" test "$(tiles)" = "tiles frames=2 alpha-alone=T"

out=$(layout save split)
check "vikix layout save says so: $out" grep -q 'saved split' <<<"$out"
check "the file is there" test -f "$file/split.lisp"
check "it is plain data: (:layout \"split\" :kind :tiles ...)" grep -q '(:layout "split" :kind :tiles' "$file/split.lisp"
check "windows by class and title, not X ids" grep -q ':title "Alpha"' "$file/split.lisp"
check "the splits as parts of the screen" grep -q ':x 0.5 :y 0.0 :width 0.5 :height 1.0' "$file/split.lisp"

ask '(run-commands "only")' >/dev/null; sleep 0.3
check "made one frame: $(tiles)" test "$(tiles)" = "tiles frames=1 alpha-alone=NIL"
out=$(layout split)
check "vikix layout split puts the split back, Alpha alone in its frame: $(tiles)" test "$(tiles)" = "tiles frames=2 alpha-alone=T"
check "and says nothing is missing: $out" test "$out" = "layout split"

# A strip: two columns, Gamma under Alpha, the first two thirds wide.
ask '(run-commands "vikix-viri on")' >/dev/null; sleep 0.5
ask "(group-focus-window (current-group) $(w Alpha))" >/dev/null; sleep 0.3
ask "(progn (viri-stack (current-group) :left :window $(w Gamma)) (setf (viri-col-width (first (viri-cols (current-group)))) 2/3) (viri-layout (current-group)))" >/dev/null
before=$(strip)
layout save desk >/dev/null
check "a strip's layout: its columns, widths, stacking" grep -q ':kind :strip :columns' "$file/desk.lisp"
ask '(run-commands "vikix-viri off")' >/dev/null; sleep 0.5
layout desk >/dev/null; sleep 0.5
check "vikix layout desk from tiles makes the strip again, as it was: $before -> $(strip)" test "$(strip)" = "$before"

layout split >/dev/null; sleep 0.5
check "and the tiles' layout from the strip: tiles, split as saved: $(tiles)" test "$(tiles)" = "tiles frames=2 alpha-alone=T"

# A window the layout doesn't know stays; a saved one that's closed is named.
# (Another program: one of the same class would take the closed one's place.)
win Delta other
ask "(kill-window $(w Beta))" >/dev/null
for _ in $(seq 1 20); do [ "$(ask "(princ (if $(w Beta) 1 0))")" = 0 ] && break; sleep 0.25; done
out=$(layout split)
check "a closed window is named: $out" grep -q 'not open: viritest (Beta)' <<<"$out"
check "a window it doesn't know stays on the workspace" test "$(ask "(princ (if $(w Delta) 1 0))")" = 1

# Changed by hand: the first column a third wide.
sed -i 's/:width 2\/3/:width 1\/3/' "$file/desk.lisp"
layout desk >/dev/null; sleep 0.5
check "a layout changed by hand is followed: $(strip)" grep -q '@1/3' <<<"$(strip)"

# From a rule: a window called Trigger puts the split back.
ask '(run-commands "vikix-viri off")' >/dev/null; sleep 0.5
ask '(run-commands "only")' >/dev/null; sleep 0.3
win Trigger other; sleep 0.5
check "the rule verb (layout \"split\") puts it back: $(tiles)" test "$(tiles)" = "tiles frames=2 alpha-alone=T"

check "vikix layout list: $(layout list | tr '\n' ' ')" test "$(layout list | tr '\n' ' ')" = "desk split "
layout rm desk >/dev/null
check "vikix layout rm removes it" test ! -e "$file/desk.lisp"
out=$(layout save '../x' || true)
check "a name with / is refused: $out" grep -q 'a name is' <<<"$out"
out=$(layout nosuch || true)
check "a layout that isn't there is said: $out" grep -qi 'no layout nosuch' <<<"$out"

wm_report layouts "a split and a strip saved as plain Lisp and put back, either from the other, a window it doesn't know kept, a closed one named, a hand change followed, from a rule, list, rm, bad names refused"
exit "$fail"
