#!/usr/bin/env bash
# tests/workspaces.sh — workspaces past the nine (groups.lisp), in a real
# StumpWM on a hidden screen.
#
#   The nine are always there. A claim for a name (a desk's topic, a
#   project) takes the first empty one of the nine while there is one, and
#   makes a workspace of that name only once all nine have windows; the
#   same name again is the same workspace. Super+0 (vikix-workspace) goes
#   to one by name, and a new name there makes a workspace of that name at
#   once, empty numbered ones or not (the user named it); Super+Shift+0
#   sends the window to one by name, the same way. The palette lists
#   the workspaces in use and the named ones. A named workspace left with
#   no window goes, after its first minute; one with a window stays; a
#   workspace made in user.lisp is never taken; a strip on and off keeps a
#   named workspace Vikix's. The desk's and the project's claims go through
#   it. Resume saves each workspace's name and makes a named one again.
#
# Super+Shift+0 with a new name makes the workspace and sends the window.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM; without them it
# says so and stops there. Its own screen, port and home.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup workspaces
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
names() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (vikix-workspace-names)))'; }
here_name() { ask '(princ (group-name (current-group)))'; }
said() { ask '(princ (first (first (screen-last-msg (current-screen)))))'; }
on() { ask "(progn (setf *print-pretty* nil) (format t \"~{~a~^ ~}\" (sort (mapcar (function window-title) (group-windows (find-group (current-screen) \"$1\"))) (function string<))))"; }
palette_workspaces() { ask '(progn (setf *print-pretty* nil) (vikix-palette-lines))' | grep '^workspace' | tr '\t' '|' | tr '\n' ' '; }

check "the nine are there, and nothing else: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"
ok=$(ask '(princ (list (vikix-workspace-name-ok "wifi-fix") (vikix-workspace-name-ok "12") (vikix-workspace-name-ok ".x") (vikix-workspace-name-ok "")))')
check "a name is a word or two, not a number, not hidden: $ok" test "$ok" = "(wifi-fix NIL NIL NIL)"

# While one of the nine is empty, a claim takes it, whatever the name.
check "a claim with every workspace empty takes the first of the nine: $(ask '(princ (group-name (vikix-workspace-claim "early")))')" test "$(here_name)" = 1
check "no workspace was made for it: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"
ask '(vikix-workspace "early")' >/dev/null
check "Super+0 with a new name makes a workspace of that name though the nine are empty: $(here_name)" test "$(here_name)" = early
check "and says so: $(said)" grep -q 'Workspace early, new' <<<"$(said)"
check "it is Vikix's to take away" yes '(gethash "early" *vikix-workspaces-made*)'
ask '(vikix-workspace "1")' >/dev/null
ask '(setf *vikix-workspace-grace* 0)' >/dev/null
ask '(vikix-workspace "early")' >/dev/null; key super+1
check "left empty past its minute, it is gone again: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"
ask '(setf *vikix-workspace-grace* 60)' >/dev/null
win E1
ask '(vikix-send-named "notes")' >/dev/null; sleep 0.5
check "Super+Shift+0 with a new name sends the window to a new workspace of that name though the nine are empty: $(on notes)" test "$(on notes)" = "E1"
check "said so: $(said)" grep -q 'Workspace notes, new' <<<"$(said)"
check "and you stayed: $(here_name)" test "$(here_name)" = 1
ask '(progn (switch-to-group (find-group (current-screen) "notes")) (delete-window (current-window)))' >/dev/null; sleep 0.5
ask '(setf *vikix-workspace-grace* 0)' >/dev/null; key super+1; sleep 0.3
ask '(setf *vikix-workspace-grace* 60)' >/dev/null
check "the nine alone again: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9"

# All nine in use.
for n in 1 2 3 4 5 6 7 8 9; do key "super+$n"; win "W$n"; done
key super+1
check "a claim with all nine in use makes a workspace of that name: $(ask '(princ (group-name (vikix-workspace-claim "wifi-fix")))')" test "$(here_name)" = wifi-fix
check "it is listed after the nine: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 wifi-fix"
check "the same name again is the same workspace" test "$(ask '(princ (eq (vikix-workspace-claim "wifi-fix") (find-group (current-screen) "wifi-fix")))')" = T
check "the desk's claim goes through it: $(ask '(princ (vikix-agent-desk-claim "deskish"))')" test "$(here_name)" = deskish
check "the project's claim too, named for the project without its collection: $(ask '(princ (vikix-project-claim "books/novel"))')" test "$(here_name)" = novel
check "the three are there: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 wifi-fix deskish novel"

# Leaving an empty named workspace: within its first minute it stays.
key super+1
check "leaving a new named workspace within its first minute keeps it: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 wifi-fix deskish novel"
check "the palette lists the workspaces in use and the named ones, not this one: $(palette_workspaces)" \
  bash -c "[ \"\$1\" = 'workspace|2|2|workspace: 1 window workspace|3|3|workspace: 1 window workspace|4|4|workspace: 1 window workspace|5|5|workspace: 1 window workspace|6|6|workspace: 1 window workspace|7|7|workspace: 1 window workspace|8|8|workspace: 1 window workspace|9|9|workspace: 1 window workspace|wifi-fix|wifi-fix|workspace, empty workspace|deskish|deskish|workspace, empty workspace|novel|novel|workspace, empty ' ]" _ "$(palette_workspaces)"
ask '(vikix-palette-run "workspace" "novel")' >/dev/null; sleep 0.7
check "picked in the palette, you are there: $(here_name)" test "$(here_name)" = novel
win N1
# Past the minute: an empty one goes, one with a window stays.
ask '(setf *vikix-workspace-grace* 0)' >/dev/null
key super+1
check "leaving a named workspace with a window keeps it: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 wifi-fix deskish novel"
ask '(vikix-workspace "deskish")' >/dev/null
check "Super+0 goes to a named workspace: $(here_name)" test "$(here_name)" = deskish
ask '(vikix-workspace "2")' >/dev/null
check "and to one of the nine by its number: $(here_name)" test "$(here_name)" = 2
check "the empty named workspace left past its minute is gone: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 wifi-fix novel"
ask '(switch-to-group (find-group (current-screen) "wifi-fix"))' >/dev/null; key super+3
check "and the other: $(names)" test "$(names)" = "1 2 3 4 5 6 7 8 9 novel"

# A workspace of the user's own is never taken.
ask '(gnewbg "mine")' >/dev/null
ask '(switch-to-group (find-group (current-screen) "mine"))' >/dev/null; key super+1
# (Its number is one a named workspace gave back, so it may come before novel.)
check "a workspace made in user.lisp, left empty, stays: $(names)" test "$(names | tr ' ' '\n' | sort | tr '\n' ' ')" = "1 2 3 4 5 6 7 8 9 mine novel "

# A strip on and off is a new group of the same name: still Vikix's.
ask '(vikix-workspace "novel")' >/dev/null
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
ask '(vikix-viri "off")' >/dev/null; sleep 0.5
check "a strip on and off keeps the named workspace, and its window: $(on novel)" test "$(on novel)" = "N1"
check "and it is still Vikix's to take away" yes '(gethash "novel" *vikix-workspaces-made*)'

# The keys: Super+0 asks for a name, Super+Shift+0 sends the window to one.
key super+1
xdotool key super+0; sleep 0.7; xdotool type --delay 40 "novel"; sleep 0.3; key Return; sleep 0.5
check "Super+0, a name, Enter: you are there: $(here_name)" test "$(here_name)" = novel
key super+2
xdotool key super+shift+0; sleep 0.7; xdotool type --delay 40 "novel"; sleep 0.3; key Return; sleep 0.7
check "Super+Shift+0, a name, Enter: the window went there: $(on novel)" test "$(on novel)" = "N1 W2"
check "and you stayed: $(here_name)" test "$(here_name)" = 2
win W2b     # the nine full again
key super+3
ask '(vikix-send-named "12")' >/dev/null
check "a number that is no workspace is refused: $(said)" grep -q 'no name for a workspace' <<<"$(said)"
ask '(vikix-send-named "reading")' >/dev/null; sleep 0.5
check "Super+Shift+0 with a new name makes the workspace and sends the window there: $(on reading)" test "$(on reading)" = "W3"
check "said so: $(said)" grep -q 'Workspace reading, new' <<<"$(said)"
check "and you stayed: $(here_name)" test "$(here_name)" = 3
check "it is Vikix's to take away" yes '(gethash "reading" *vikix-workspaces-made*)'


# Resume saves the name, and makes a named workspace again.
ask '(vikix-resume-save)' >/dev/null
check "resume's index carries each workspace's name" grep -q '(1 1 "1")' "$home/.local/state/vikix/resume/index.lisp"
check "the named one too" grep -q '"novel")' "$home/.local/state/vikix/resume/index.lisp"
check "a saved workspace is found by its name, whatever its number now" test "$(ask '(princ (group-name (vikix-resume-group 99 "novel")))')" = novel
check "one of the nine by its number alone, as before" test "$(ask '(princ (group-name (vikix-resume-group 4)))')" = 4
check "a named one that is gone is made again: $(ask '(princ (group-name (vikix-resume-group 99 "ghost")))')" test "$(ask '(princ (if (find-group (current-screen) "ghost") 1 0))')" = 1
check "and is Vikix's to take away" yes '(gethash "ghost" *vikix-workspaces-made*)'

check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report workspaces "the nine always there, a claim takes an empty one of them first and makes a named workspace once all nine are in use, the desk's and the project's claims, Super+0 and Super+Shift+0 by name (a new name a new workspace at once), the palette's rows, an empty named workspace gone after its minute and one with a window kept, the user's own and a strip's left alone, resume by name"
exit "$fail"
