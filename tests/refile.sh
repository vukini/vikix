#!/usr/bin/env bash
# tests/refile.sh — refiling the workspaces (vikix-refile-workspaces,
# groups.lisp), in a real StumpWM on a hidden screen.
#
#   From 2 on, each workspace with windows moves left into the nearest
#   empty one, as far as it can, the order among them kept; workspace 1 is
#   neither moved nor filled; a named workspace past the nine stays. A
#   workspace keeps its layout entire as it moves: its frames, a strip and
#   its columns, a floating window, grid mode, and (winner-mode being
#   there) the layout steps Super+u undoes. The names and the numbers
#   agree afterwards, so Super+digit reaches the moved workspace, and the
#   workspace you were on is still the one you are on. It says what moved,
#   and when nothing does. Super+m has it.
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
wm_setup refile
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
names() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (vikix-workspace-names)))'; }
here_name() { ask '(princ (group-name (current-group)))'; }
said() { ask '(princ (first (first (screen-last-msg (current-screen)))))'; }
on() { ask "(progn (setf *print-pretty* nil) (format t \"~{~a~^ ~}\" (sort (mapcar (function window-title) (group-windows (find-group (current-screen) \"$1\"))) (function string<))))"; }
frames() { ask "(princ (length (group-frames (find-group (current-screen) \"$1\"))))"; }
refile() { ask '(vikix-refile-workspaces)' >/dev/null; sleep 0.3; }
# Every numbered workspace's name is its number.
agree() { yes '(every (lambda (g) (equal (group-name g) (princ-to-string (group-number g)))) (remove-if-not (lambda (g) (member (group-name g) *vikix-group-names* :test (function equal))) (screen-groups (current-screen))))'; }

check "the nine are there: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"

# One workspace with windows and a split, 1 and 2 empty: it goes to 2, not 1.
key super+3
win B; win C
ask '(run-commands "hsplit")' >/dev/null; sleep 0.3
check "(workspace 3 has two frames: $(frames 3))" test "$(frames 3)" = 2
refile
check "the workspace moved left, to 2: $(on 2)" test "$(on 2)" = "B C"
check "and 3 is empty" test -z "$(on 3)"
check "workspace 1 is never filled" test -z "$(on 1)"
check "the frames came along: $(frames 2)" test "$(frames 2)" = 2
check "you are on it still: $(here_name)" test "$(here_name)" = 2
check "it says what moved: $(said)" test "$(said)" = "Refiled: 3 to 2."
check "the names and the numbers agree" agree
if yes '(find-package :winner-mode)'; then
  ask '(vikix-layout-undo)' >/dev/null; sleep 0.3
  check "Super+u on the moved workspace undoes its own split: $(frames 2)" test "$(frames 2)" = 1
  ask '(vikix-layout-redo)' >/dev/null; sleep 0.3
else
  echo "(winner-mode isn't in this StumpWM: the undo steps' move is not checked)"
fi

# Several at once, each with a layout of its own: a strip, a floating
# window, grid mode; the strip is the one you are on.
key super+7
win E
key super+t   # floats E
check "(E floats: $(ask '(princ (if (typep (current-window) (quote float-window)) 1 0))'))" yes '(typep (current-window) (quote float-window))'
key super+9
win F; win G
ask '(vikix-grid)' >/dev/null; sleep 0.3
check "(9 is in grid mode)" yes '(member (current-group) *vikix-grid-groups*)'
key super+5
win D
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
check "(5 is a strip)" yes '(viri-group-p (current-group))'
refile
check "the order is kept, each left as far as it can: 2 $(on 2) / 3 $(on 3) / 4 $(on 4) / 5 $(on 5)" \
  test "$(on 2)|$(on 3)|$(on 4)|$(on 5)" = "B C|D|E|F G"
check "6 to 9 are empty" test -z "$(on 6)$(on 7)$(on 8)$(on 9)"
check "the strip is a strip on 3, and you are on it: $(here_name)" test "$(here_name)" = 3 && yes '(viri-group-p (current-group))'
check "the floating window still floats on 4" yes '(typep (first (group-windows (find-group (current-screen) "4"))) (quote float-window))'
check "grid mode came along to 5" yes '(member (find-group (current-screen) "5") *vikix-grid-groups*)'
check "it says every move: $(said)" test "$(said)" = "Refiled: 5 to 3, 7 to 4, 9 to 5."
check "the names and the numbers agree" agree
key super+2
check "Super+2 reaches the moved workspace: $(here_name) $(on "$(here_name)")" test "$(here_name)" = 2
check "the bar lists them in order: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"

# Nothing to do, said; a named workspace stays.
refile
check "nothing to move is said: $(said)" grep -q '^Nothing to refile' <<<"$(said)"
ask '(vikix-workspace "novel")' >/dev/null; sleep 0.3
win N
key super+3
refile
check "a named workspace is left where it is: $(names), $(on novel)" test "$(names)" = "1 2 3 4 5 6 7 8 9 novel" && test "$(on novel)" = N
check "Super+m has it" yes '(find (quote vikix-refile-workspaces) *vikix-menu* :key (function second))'
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report refile "workspaces from 2 on move left into the empty ones in order, 1 never filled, frames, a strip, a floating window, grid mode and the undo steps come along, names and numbers agree, the one you were on stays yours, what moved is said, a named workspace stays, Super+m has it"
exit "$fail"
