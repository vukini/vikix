#!/usr/bin/env bash
# tests/gather.sh — bringing a whole workspace's windows here (vikix-gather,
# windows.lisp), and what a rule's "dialog" means on a strip; in a real
# StumpWM on a hidden screen.
#
#   With a rule that calls every floating window that takes the focus a
#   dialog (Vid's own), a strip's columns are no dialogs: the workspace made
#   tiles has them all tiled, and made a strip again has them all as columns.
#   vikix-gather N brings every window of workspace N here as an ordinary
#   window: a strip's onto tiles are tiles, the one that had the focus in
#   front, and the workspace made a strip afterwards has them as columns; a
#   window floated by hand becomes a column on a strip and a tile on tiles;
#   a dialog by what it is, and a window a rule floats, stay afloat; a
#   workspace without windows, or one there isn't, is said; the menu lists
#   the workspaces that have windows. StumpWM's own gmerge from a strip, and
#   a strip made of what it brought, has columns too.
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
wm_setup gather
cat > "$home/.stumpwm.d/rules.lisp" <<'L'
(in-package :stumpwm)
;; Floating windows stay in front of the tiles (Vid's own rule).
(when-window (:where (lambda (w) (typep w 'float-window))) :on :focus (dialog))
;; A window a rule floats as it opens.
(when-window (:class "floaty") (float :width 300 :height 200))
L
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
# This workspace's windows, by title in order: T tile, F floating, D dialog (Vikix's word for it).
here_is() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (sort (mapcar (lambda (w) (format nil "~a:~a~:[~;D~]" (window-title w) (if (typep w (quote float-window)) "F" "T") (vikix-dialog-p w))) (group-windows (current-group))) (function string<))))'; }
columns() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ ~}" (sort (mapcar (function window-title) (viri-columns (current-group))) (function string<))))'; }
said() { ask '(princ (first (first (screen-last-msg (current-screen)))))'; }
focus() { ask '(princ (and (current-window) (window-title (current-window))))'; }

# A strip, every column of which has had the focus.
key super+2
for w in A B C; do win "$w"; done
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
key super+h; key super+h; key super+l
check "the rule ran for the columns, as they took the focus" yes '(plusp (vikix-rule-runs (vikix-rule-called "dialog")))'
check "a strip's columns are no dialogs, whatever a rule for floating windows says: $(here_is)" test "$(here_is)" = "A:F B:F C:F"
ask '(vikix-viri "off")' >/dev/null; sleep 0.5
check "made tiles, they are all tiled: $(here_is)" test "$(here_is)" = "A:T B:T C:T"
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
check "and made a strip again, all columns: $(columns)" test "$(columns)" = "A B C"
front=$(focus)

# Every window of that strip, onto an empty tiled workspace.
key super+1
ask '(vikix-gather "2")' >/dev/null; sleep 0.5
check "vikix-gather 2 brings a strip's windows here as tiles: $(here_is)" test "$(here_is)" = "A:T B:T C:T"
check "it says how many came: $(said)" grep -q '^3 windows from workspace 2 are here' <<<"$(said)"
check "the one that had the focus there has it here: $(focus)" test "$(focus)" = "$front"
check "the workspace they left is empty" yes '(null (group-windows (find-group (current-screen) "2")))'
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
check "made a strip afterwards, they are its columns, none left afloat: $(columns)" test "$(columns)" = "A B C"

# A window floated by hand (and called a dialog by the rule): a column on a
# strip, a tile on tiles.
key super+3
win D; win E
ask '(group-focus-window (current-group) (find "D" (group-windows (current-group)) :key (function window-title) :test (function equal)))' >/dev/null
key super+t
# The rule runs as a floating window takes the focus: away, and back to it.
for w in E D; do ask "(group-focus-window (current-group) (find \"$w\" (group-windows (current-group)) :key (function window-title) :test (function equal)))" >/dev/null; sleep 0.3; done
check "(a window floated by hand is a dialog to the rule: $(here_is))" test "$(here_is)" = "D:FD E:T"
key super+1
ask '(vikix-gather "3")' >/dev/null; sleep 0.5
check "brought onto a strip, a floated window is a column like the rest: $(columns)" test "$(columns)" = "A B C D E"
key super+4
win F
key super+t
key super+5
ask '(vikix-gather "4")' >/dev/null; sleep 0.5
check "brought onto tiles, a floated window is a tile: $(here_is)" test "$(here_is)" = "F:T"

# What floats by what it is, or by a rule for it, stays afloat.
key super+6
win G; win Z zenity; win R floaty
check "(a dialog and a window a rule floats, both afloat: $(here_is))" test "$(here_is)" = "G:T R:F Z:FD"
key super+5
ask '(vikix-gather "6")' >/dev/null; sleep 0.5
check "a dialog by what it is, and a window a rule floats, stay afloat: $(here_is)" grep -q 'G:T R:F.* Z:FD$' <<<"$(here_is)"

# Said, not done.
ask '(vikix-gather "9")' >/dev/null
check "a workspace without windows is said: $(said)" grep -q 'No other workspace called 9 has windows' <<<"$(said)"
check "the menu lists the other workspaces that have windows: $(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function first) (vikix-gather-choices))))')" \
  grep -q '^(1  5 windows: ' <<<"$(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function first) (vikix-gather-choices))))')"
check "Super+m has it" yes '(find (quote vikix-gather) *vikix-menu* :key (function second))'

# StumpWM's own gmerge from a strip, then a strip of what it brought.
key super+7
win H; win I
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
key super+h; key super+l
key super+8
ask '(run-commands "gmerge 7")' >/dev/null; sleep 0.5
check "gmerge from a strip brings tiles: $(here_is)" test "$(here_is)" = "H:T I:T"
ask '(vikix-viri "on")' >/dev/null; sleep 0.5
check "and a strip made of them has them as columns: $(columns)" test "$(columns)" = "H I"
# The desktop as JSON (vikix-desktop-json: vikix mcp's desktop tool and Cuis's
# VikixDesktop read it): the workspaces in order, this strip's columns, the
# windows with their titles, the screens.
desktop_json=$(HOME=$home VIKIX_SWANK_PORT=$port VIKIX_SOCKET=$wm_socket python3 "$here/bin/vikix-eval" '(princ (vikix-desktop-json))' 2>&1 | grep -v '^=> ')
check "vikix-desktop-json should be JSON naming the windows and the strip: $(head -c 300 <<<"$desktop_json")" python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
ws = {w["number"]: w for w in d["workspaces"]}
assert [w["number"] for w in d["workspaces"]] == sorted(ws), "not in order"
eight = ws[8]
assert eight["kind"] == "strip" and len(eight["strip"]["columns"]) == 2, eight
assert sorted(w["title"] for w in eight["windows"]) == ["H", "I"], eight["windows"]
assert sum(1 for w in d["workspaces"] if w["current"]) == 1
assert d["screens"] and all(k in d["screens"][0] for k in ("x", "y", "width", "height"))
' <<<"$desktop_json"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report gather "a strip's columns are no dialogs to a rule for floating windows, tiles and a strip again keep them, a whole workspace's windows brought here tiled or as columns, floated ones too, real dialogs and rule-floated windows left afloat, gmerge from a strip"
exit "$fail"
