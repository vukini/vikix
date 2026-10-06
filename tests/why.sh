#!/usr/bin/env bash
# tests/why.sh — "why did that happen?" (why.lisp), in a real StumpWM on a
# hidden screen.
#
#   A key of Vikix's is noted with its command, what that does and where
#   it is written (the registry's line), and can be seen there, not edited,
#   and, being a switch, taken back; a key of yours is "your key", at its
#   line of user.lisp, to edit; the same key again is the same line,
#   counted; a rule that sent a window to another workspace is noted with
#   the window, and offers its line of rules.lisp, bringing the window here
#   and switching the rule off, each of which does it; an entry of Super+m
#   is the menu's doing, once, not also a command "asked for"; an agent's
#   command is the agent's; one run from outside is "asked for"; Super+?
#   itself is never noted; the last notification is in the list, by the
#   program that sent it; vikix why prints the same lines in a terminal;
#   the list keeps fifty; a reload keeps it.
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
wm_setup why
cat > "$home/.stumpwm.d/user.lisp" <<'L'
(in-package :stumpwm)
(vikix-bind "s-M-F12" "echo hello from a key of mine")
L
cat > "$home/.stumpwm.d/rules.lisp" <<'L'
(in-package :stumpwm)
(when-window (:class "whytest") (workspace 3))
L
# The notifications' history, and Emacs: stand-ins, first on StumpWM's PATH.
mkdir -p "$t/bin"
printf '#!/bin/sh\n[ "$1" = last ] && printf "7\\tMail\\tA letter came\\t5\\n"\n' > "$t/bin/vikix-notifications"
printf '#!/bin/sh\necho "emacsclient $*" >> %s/emacs\n' "$t" > "$t/bin/emacsclient"
printf '#!/bin/sh\necho "dunstctl $*" >> %s/dunst\n' "$t" > "$t/bin/dunstctl"
chmod +x "$t/bin/vikix-notifications" "$t/bin/emacsclient" "$t/bin/dunstctl"
PATH="$t/bin:$PATH" wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
# The newest thing noted: its line, and what can be done about it.
newest() { ask '(princ (vikix-why-line (first *vikix-why-ring*)))'; }
choices() { ask "(progn (setf *print-pretty* nil) (format t \"~{~a~^ | ~}\" (mapcar (function first) (vikix-why-choices (find $1 *vikix-why-ring* :key (lambda (e) (getf e :kind)))))))"; }
# Do what the choice of ENTRY-KIND whose label starts with WORDS says.
choose() { ask "(funcall (second (find-if (lambda (c) (eql 0 (search \"$2\" (first c)))) (vikix-why-choices (find $1 *vikix-why-ring* :key (lambda (e) (getf e :kind)))))))" >/dev/null; sleep 0.5; }
line=$(grep -n '^(define-vikix-command titlebars ' "$here/config/stumpwm/vikix/registry.lisp" | cut -d: -f1)


# A key of Vikix's: a switch.
bars=$(ask '(princ (if *vikix-titlebars* 1 0))')
key super+ctrl+y
check "a key of Vikix's: the key, its command, what that does, where it is written: $(newest)" \
  grep -q "  Super+Ctrl+y ran vikix-titlebars (Title bars on/off)  ·  Vikix's key: registry.lisp, line $line\$" <<<"$(newest)"
check "it can be seen where it is written, not edited, and taken back: $(choices :key)" \
  grep -q "^See where it is written: registry.lisp, line $line (Vikix's own.*| Take it back: run vikix-titlebars again (it is a switch) | What is this key? " <<<"$(choices :key)"
choose :key "Take it back"
check "taking it back runs the switch again" yes "(eq (and *vikix-titlebars* t) (= $bars 1))"
check "which is noted as its own doing, not the key's: $(newest)" grep -q 'Something asked for it ran vikix-titlebars' <<<"$(newest)"
choose :key "See where"
check "seeing where opens Vikix's file to read, at its line: $(cat "$t/emacs" 2>/dev/null)" grep -q "view-file .*registry.lisp.*forward-line $((line - 1))" "$t/emacs"

# A key of yours.
key super+alt+F12
check "a key of yours, at its line of user.lisp: $(newest)" \
  grep -q "  Super+Alt+F12 ran echo hello from a key of mine.*  ·  your key: user.lisp, line 2\$" <<<"$(newest)"
check "which can be edited, and asked about (what.lisp): $(choices :key)" grep -q '^Edit it: user.lisp, line 2, in Emacs | What is this key? ' <<<"$(choices :key)"
: > "$t/emacs"; choose :key "Edit it"
check "editing opens user.lisp at the line: $(cat "$t/emacs")" grep -q 'emacsclient -n -c -a  +2 .*/.stumpwm.d/user.lisp' "$t/emacs"
key super+alt+F12
check "the same key again is the same line, counted: $(newest)" grep -q '×2  ·  your key' <<<"$(newest)"
check "and no new one: two keys so far" yes '(= 2 (count :key *vikix-why-ring* :key (lambda (e) (getf e :kind))))'

# A rule that sends a window to another workspace.
win Gone whytest
check "the window went where the rule sends it" yes '(eql 3 (group-number (window-group (find "Gone" (screen-windows (current-screen)) :key (function window-title) :test (function equal)))))'
check "the rule is noted, with its window and its line: $(newest)" \
  grep -q '  A rule, as a window opened ran (when-window (:class "whytest") (workspace 3))  ·  rules.lisp:2, for whytest "Gone"$' <<<"$(newest)"
check "it offers its line, the window back and the rule off: $(choices :rule)" \
  grep -q '^Edit it: rules.lisp, line 2, in Emacs | Bring that window here (it is on workspace 3) | Switch that rule off' <<<"$(choices :rule)"
check "and asks what that window is (what.lisp)" grep -q '| What is this window? ' <<<"$(choices :rule)"
choose :rule "Bring that window here"
check "bringing the window here does" yes '(eq (window-group (find "Gone" (screen-windows (current-screen)) :key (function window-title) :test (function equal))) (current-group))'
choose :rule "Switch that rule off"
check "switching the rule off does, until the next reload" yes '(not (vikix-rule-on-p (vikix-rule-called "whytest")))'

# The menu: its entry, once.
ask '(setf *vikix-why-ring* nil)' >/dev/null
gaps=$(ask '(princ (if swm-gaps:*gaps-on* 1 0))')
xdotool key super+m; sleep 1; xdotool type --delay 40 "Gaps around"; sleep 0.5; key Return
check "an entry of Super+m did what it says" yes "(not (eq (and swm-gaps:*gaps-on* t) (= $gaps 1)))"
check "and is the menu's doing, with where it is written: $(newest)" \
  grep -q '  The menu did "Gaps around windows on/off"  ·  an entry of Super+m: registry.lisp, line [0-9]*$' <<<"$(newest)"
check "under it the key that opened the menu, and no command asked for: $(ask '(progn (setf *print-pretty* nil) (princ (mapcar (lambda (e) (getf e :kind)) *vikix-why-ring*)))')" \
  test "$(ask '(progn (setf *print-pretty* nil) (princ (mapcar (lambda (e) (getf e :kind)) *vikix-why-ring*)))')" = "(MENU KEY)"
ask '(run-commands "toggle-gaps")' >/dev/null

# An agent, and something from outside.
ask '(vikix-agent-run "titlebars")' >/dev/null
check "an agent's command is the agent's: $(newest)" grep -q '  An agent ran titlebars (Title bars on/off)  ·  through vikix mcp' <<<"$(newest)"
ask '(vikix-agent-run "titlebars")' >/dev/null
ask '(run-commands "vikix-pointer")' >/dev/null
check "a command from outside is asked for: $(newest)" grep -q '  Something asked for it ran vikix-pointer (Move the pointer to this window)  ·  not a key' <<<"$(newest)"

# Super+? itself, and the last notification.
before=$(ask '(princ (length *vikix-why-ring*))')
xdotool key super+question; sleep 1.5; xdotool key Escape; sleep 0.5
check "Super+? opens the list, and asking why isn't itself noted" test "$(ask '(princ (length *vikix-why-ring*))')" = "$before"
check "Super+? is the key" yes '(equal (lookup-key *top-map* (kbd "s-?")) "vikix-why")'
text=$(ask '(princ (vikix-why-text))')
check "the last notification is in the list, by its program: $(grep notification <<<"$text")" \
  grep -q '  A notification "A letter came"  ·  sent by Mail$' <<<"$text"
check "newest first: $(head -1 <<<"$text" | cut -c1-80)" grep -q 'Something asked for it ran vikix-pointer' <<<"$(head -1 <<<"$text")"
check "it can be shown again: $(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function first) (vikix-why-choices (vikix-why-notification)))))')" \
  grep -q 'Show that notification again' <<<"$(ask '(progn (setf *print-pretty* nil) (princ (mapcar (function first) (vikix-why-choices (vikix-why-notification)))))')"

# vikix why, in a terminal: the same lines.
why_cli() { HOME=$home VIKIX_SWANK_PORT=$port "$here/bin/vikix-why" "$@" 2>&1 || true; }
out=$(why_cli)
check "vikix why prints the list, each line once, newest first: $(head -2 <<<"$out" | cut -c1-90)" \
  test "$(grep -c 'Something asked for it ran vikix-pointer' <<<"$out") $(grep -c 'A notification' <<<"$out")" = "1 1"
check "vikix why 1 prints one" test "$(why_cli 1 | grep -c .)" = 1
check "vikix why with words says what it takes: $(why_cli lots)" grep -q 'how many, a number' <<<"$(why_cli lots)"

# Fifty are kept; a reload keeps them.
ask '(dotimes (i 70) (vikix-why-note :asked (list :test i) :what "Test" :does (format nil "~d" i) :from "the test"))' >/dev/null
check "the list keeps the last fifty: $(ask '(princ (length *vikix-why-ring*))')" yes '(= 50 (length *vikix-why-ring*))'
ask '(loadrc)' >/dev/null; sleep 2
check "a reload keeps what was noted, and notes on: $(ask '(princ (length *vikix-why-ring*))')" yes '(= 50 (length *vikix-why-ring*))'
key super+ctrl+y
check "after it a key is still noted: $(newest)" grep -q 'Super+Ctrl+y ran vikix-titlebars' <<<"$(newest)"
check "once a press, not twice (eval-command is wrapped once)" test -z "$(grep '×' <<<"$(newest)" || true)"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report why "a key with its command and where it is written, Vikix's to see and yours to edit, a switch taken back, a rule with its window brought back and switched off, the menu, an agent, something from outside, the last notification, fifty kept, a reload"
exit "$fail"
