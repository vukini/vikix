#!/usr/bin/env bash
# tests/registry.sh — the command registry (registry.lisp), in a real
# StumpWM on a hidden screen.
#
#   Vikix's keys are bound from its commands and *vikix-bindings* is made
#   from them; Super+m is made from them too, the welcome first, Power
#   last, an entry that runs a program as the menu always wrote it; a
#   command written in user.lisp is bound, on the key card's list and in
#   the menu, just before Power, and its key runs it; Super+m, by its
#   keys, opens on its sections, Enter (or Right) shows one's entries with
#   their keys, Escape (or Left) comes back and a second closes it, and
#   typing finds an entry of any section, which Enter runs; an agent may run a
#   command marked for agents (a switch flips) and is refused any other, in
#   words; a reload leaves one of each.
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
wm_setup registry
cat > "$home/.stumpwm.d/user.lisp" <<'L'
(in-package :stumpwm)
(define-vikix-command hello "Say hello"
  :run "echo hello from the registry" :key "s-M-F12"
  :menu "Work" :label "Hello, from the menu" :agent t)
;; What a menu shows, each time it is drawn: the test reads it, since
;; StumpWM answers nothing while a menu is open.
(defun test-menu-log (menu)
  (with-open-file (o (merge-pathnames "menu.log" (user-homedir-pathname))
                     :direction :output :if-exists :supersede :if-does-not-exist :create)
    (format o "prompt=~a~%selected=~a~%" (menu-prompt-line menu) (first (nth (menu-selected menu) (menu-table menu))))
    (dolist (row (menu-table menu)) (format o "row=~a~%" (first row)))))
(add-hook *menu-selection-hook* 'test-menu-log)
L
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
said() { ask '(princ (first (first (screen-last-msg (current-screen)))))'; }   # the last message's first line

keys=$("$here/lib/registry.sh" keys | wc -l)
check "Vikix's keys are its commands', and yours after them: $(ask '(princ (length *vikix-bindings*))') of $keys and 1" \
  yes "(= (length *vikix-bindings*) (1+ $keys))"
check "a key runs its command (Super+Return, Super+Ctrl+d)" \
  yes '(and (equal (lookup-key *top-map* (kbd "s-RET")) "vikix-terminal") (equal (lookup-key *top-map* (kbd "s-C-d")) "vikix-quiet"))'
check "every key of the registry is bound to its command" \
  yes '(every (lambda (b) (equal (lookup-key *top-map* (kbd (first b))) (second b))) (vikix-registry-bindings))'
check "every command a key or the menu names is a real one" test -z "$(ask '(progn (setf *print-pretty* nil) (princ (loop for c in *vikix-commands* for run = (getf c :run) for word = (and run (subseq run 0 (position #\Space run))) when (and word (not (equal word "exec")) (not (get-command-structure (intern (string-upcase word) :stumpwm) nil))) collect word)))' | grep -v '^NIL$' || true)"

check "Super+m starts with the welcome and ends with Power: $(ask '(princ (first (first *vikix-menu*)))') ... $(ask '(princ (first (car (last *vikix-menu*))))')" \
  yes '(and (equal (first (first *vikix-menu*)) "Welcome: first steps") (eq (second (car (last *vikix-menu*))) (quote vikix-power)))'
check "an entry that runs a program is as the menu always wrote it" \
  yes '(equal (second (assoc "Wallpaper" *vikix-menu* :test (function equal))) (quote (run-shell-command "vikix-wallpaper pick")))'
check "an entry shows its key, found among the keys" \
  yes '(equal (vikix-menu-entry-key (assoc "Do not disturb on/off" *vikix-menu* :test (function equal))) "Super+Ctrl+d")'

# A command of your own, written in user.lisp.
check "a command of yours is bound" yes '(equal (lookup-key *top-map* (kbd "s-M-F12")) "echo hello from the registry")'
check "and in the menu, just before Power: $(ask '(princ (first (car (last *vikix-menu* 2))))')" \
  yes '(equal (first (car (last *vikix-menu* 2))) "Hello, from the menu")'
key super+alt+F12
check "its key runs it: $(said)" test "$(said)" = "hello from the registry"

# Super+m itself, by its keys.
menu() { cat "$home/menu.log" 2>/dev/null || true; }
rows() { menu | sed -n 's/^row=//p'; }
ask '(message "nothing yet")' >/dev/null
key super+m
check "Super+m opens on its sections, Start first and Power last: $(rows | head -1 | cut -d' ' -f1) ... $(rows | tail -1 | cut -c1-6)" \
  test "$(rows | head -1 | cut -d' ' -f1) $(rows | tail -1)" = "Start Power: lock, suspend, log out, reboot, power off  Super+Shift+Escape"
check "a section's row says what it holds: $(rows | grep '^Windows ')" \
  grep -q '^Windows  *Overview, Layout, Strip, ' <(rows)
check "and no entry of a section shows yet" test -z "$(rows | grep -E '^(Hello|Emoji|Calculator)' || true)"
for _ in $(seq 1 12); do menu | grep -q '^selected=Work ' && break; key Down; done
key Return
check "Enter on Work shows what is in it, under its name: $(menu | head -1)" grep -q '^prompt=Work: ' <(menu)
check "with yours, and its key in the column: $(rows | grep Hello)" grep -qE '^Hello, from the menu +Super\+Alt\+F12$' <(rows)
check "the keys are in one column" test "$(rows | awk 'match($0, /  Super\+/) { print RSTART }' | sort -u | wc -l)" = 1
key Escape
check "Escape comes back to the sections, on Work: $(menu | sed -n 2p | cut -c1-20)" grep -q '^selected=Work ' <(menu)
key Right
check "Right opens the section too" grep -q '^prompt=Work: ' <(menu)
key Left
check "and Left comes back" grep -q '^selected=Work ' <(menu)
key Escape
check "a second Escape closes the menu" test "$(ask '(princ 1)')" = 1
key super+m
xdotool type --delay 60 "hello fr"; sleep 0.5
check "typing finds an entry of any section, its section before it: $(rows | head -3)" \
  test "$(rows | sed -E 's/  +/ | /g')" = "Work | Hello, from the menu | Super+Alt+F12"
key Return
check "and Enter runs it: $(said)" test "$(said)" = "hello from the registry"
check "the desktop noted what the menu did, for Super+?" \
  yes '(search "Hello, from the menu" (vikix-why-text 3))'

# Agents: only what is marked, by name.
check "agents are offered the commands marked for them, yours too: $(ask '(princ (length (vikix-agent-commands)))')" \
  yes '(and (find (quote hello) (vikix-agent-commands) :key (lambda (c) (getf c :name))) (not (find (quote terminal) (vikix-agent-commands) :key (lambda (c) (getf c :name)))))'
bars=$(ask '(princ (if *vikix-titlebars* 1 0))')
out=$(ask '(princ (vikix-agent-run "titlebars"))')
check "an agent may run one marked for agents, and it is done: $out" test "${out%% *} $(ask '(princ (if *vikix-titlebars* 1 0))')" = "done: $((1 - bars))"
ask '(vikix-agent-run "titlebars")' >/dev/null
out=$(ask '(princ (vikix-agent-run "terminal"))')
check "and is refused one that isn't, in words: $out" grep -q '^refused: terminal (Terminal) is not for agents to run; the user has it on Super+Return$' <<<"$out"
out=$(ask '(princ (vikix-agent-run "power"))')
check "the power menu is not an agent's: $out" grep -q '^refused: power ' <<<"$out"
out=$(ask '(princ (vikix-agent-run "no-such-thing"))')
check "nor a command there isn't: $out" grep -q '^refused: there is no command called no-such-thing' <<<"$out"
check "no terminal was started for the agent" yes '(null (group-windows (current-group)))'

# A reload: one of each.
ask '(loadrc)' >/dev/null; sleep 2
check "after a reload the keys are there once: $(ask '(princ (length *vikix-bindings*))')" \
  yes "(and (= (length *vikix-bindings*) (1+ $keys)) (= 1 (count \"s-M-F12\" *vikix-bindings* :key (function first) :test (function equal))))"
check "and your menu entry once, before Power" \
  yes '(and (= 1 (count "Hello, from the menu" *vikix-menu* :key (function first) :test (function equal))) (equal (first (car (last *vikix-menu* 2))) "Hello, from the menu"))'
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report registry "Vikix's keys and Super+m made from its commands, every one a real command, a command of yours bound and in the menu at once, Super+m opens on its sections, shows one's entries with their keys, comes back, and finds an entry of any section as it is typed, agents run only what is marked for them, a reload leaves one of each"
exit "$fail"
