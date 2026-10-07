#!/usr/bin/env bash
# tests/maps.sh — the maps (help.lisp, vikix-map; registry.lisp, :map), in a
# real StumpWM on a hidden screen.
#
#   Super+Ctrl+Space opens the layout map: its keys show in the message
#   window; m puts the workspace in main and stack and the map stays open,
#   m again takes it out, the map drawn again; Escape closes it; the
#   opening key again closes it; it closes by itself after its seconds;
#   Space opens the layout menu inside it and Escape there comes back to
#   the map; a key of nobody's closes it and does nothing; a key of the
#   top map (Super+/) closes it and runs; the key card open gives way to
#   it. A map of your own from user.lisp: a key that runs a command keeps
#   it open, one that starts a program closes it first; the key is noted
#   for why as both keys and counted by vikix used as one key.
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
wm_setup maps
cat > "$home/.stumpwm.d/user.lisp" <<'L'
(in-package :stumpwm)
(setf *vikix-map-timeout* 2)   ; the test waits for it
(define-vikix-command tmap "Test keys: x says hello, p starts a program"
  :run "vikix-map tmap" :key "s-M-F11")
(define-vikix-command tmap-hello "Hello from the map"
  :run "echo hello from the map" :map "tmap x")
(define-vikix-command tmap-program "A program"
  :run "exec true" :map "tmap p")
L
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
open() { ask '(princ (or *vikix-map-open* "none"))'; }
shown() { ask '(princ (xlib:window-map-state (screen-message-window (current-screen))))'; }
said() { ask '(princ (first (first (screen-last-msg (current-screen)))))'; }   # the last message's first line

for w in A B; do win "$w"; done

# The layout map.
key super+ctrl+space
check "Super+Ctrl+Space opens the layout map: $(open)" test "$(open)" = layout
check "its keys show in the message window: $(shown)" test "$(shown)" = VIEWABLE
check "the lines are the map's: its name, a key a line, how it closes" \
  yes '(let ((lines (vikix-map-strings "layout"))) (and (search "Layout keys" (first lines)) (find-if (lambda (l) (and (search "m" l) (search "Main and stack" l))) lines) (search "Escape or Super+Ctrl+Space again closes it" (car (last lines)))))'
key m
check "m puts the workspace in main and stack" yes '(vikix-main-p)'
check "and the map stays open: $(open)" test "$(open)" = layout
key m
check "m again takes it out" yes '(not (vikix-main-p))'
check "the map is still open, drawn again: $(open) $(shown)" test "$(open) $(shown)" = "layout VIEWABLE"
key Escape
check "Escape closes it: $(open) $(shown)" test "$(open) $(shown)" = "none UNMAPPED"
check "and the keyboard is given back: the handler is StumpWM's own again" yes '(not (eq *custom-key-event-handler* (quote vikix-map-key)))'
key super+ctrl+space
key super+ctrl+space
check "the opening key again closes it: $(open)" test "$(open)" = none
key super+ctrl+space
sleep 3
check "it closes by itself after its seconds: $(open)" test "$(open)" = none

# A menu inside the map: the layout picker on Space.
key super+ctrl+space
xdotool key space; sleep 1
key Escape
check "Space opened the layout menu, and Escape there came back to the map: $(open)" test "$(open)" = layout
key Escape

# Keys that aren't the map's.
key super+ctrl+space
ask '(message "nothing yet")' >/dev/null
key q
check "a key of nobody's closes the map and does nothing: $(open), said: $(said)" test "$(open) $(said)" = "none nothing yet"
key super+ctrl+space
key super+slash
check "a key of the top map closes the map and runs: the key card is open" yes '(and (null *vikix-map-open*) *vikix-card-open*)'
key super+ctrl+space
check "and the card gives way to the map: $(open)" yes '(and (equal *vikix-map-open* "layout") (not *vikix-card-open*))'
key Escape

# A map of your own, from user.lisp.
check "a map written in user.lisp is a key of the help: Super+Alt+F11, then x and then p under it" \
  yes '(let ((entries (vikix-key-entries))) (equal (mapcar (function first) (member "Super+Alt+F11" entries :key (function first) :test (function equal))) (list "Super+Alt+F11" "then x" "then p" "Super+1 ... Super+9" "Super+Shift+1 ... 9" "Ctrl+t then ?" "Super+Ctrl+Alt+Escape")))'
key super+alt+F11
check "it opens: $(open)" test "$(open)" = tmap
key x
check "a key that runs a command runs it: $(said)" test "$(said)" = "hello from the map"
check "and the map stays open, what the command said under its keys" \
  yes '(and (equal *vikix-map-open* "tmap") (find-if (lambda (l) (search "hello from the map" l)) (vikix-map-strings "tmap" "hello from the map")))'
check "why noted the two keys: $(ask '(princ (vikix-one-line (vikix-why-text 2) 200))')" \
  yes '(search "Super+Alt+F11 then x" (vikix-why-text 3))'
check "and vikix used counted them as one key: $(ask '(princ (vikix-used-count :key (format nil "s-M-F11 x~cecho hello from the map" #\Tab)))')" \
  yes '(= 1 (vikix-used-count :key (format nil "s-M-F11 x~cecho hello from the map" #\Tab)))'
key p
check "a key that starts a program closes the map first: $(open)" test "$(open)" = none

# The ways of asking for a map there isn't.
ask '(vikix-map "nowhere")' >/dev/null
check "a map there isn't is said: $(said)" grep -q 'no map called nowhere' <<<"$(said)"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report maps "Super+Ctrl+Space opens the layout map with its keys shown, m switches main and stack with the map open, Escape, the key again and the seconds close it, the layout menu inside it comes back to it, a key of nobody's closes it, the top map's keys run, a map of your own from user.lisp works, with why and vikix used told"
exit "$fail"
