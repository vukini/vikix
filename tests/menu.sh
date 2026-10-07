#!/usr/bin/env bash
# tests/menu.sh — the Super+m menu leaves out what isn't here: an entry
# that names a program (on PATH) or a file (~/...) it needs is shown only
# when that is there, so JupyterLab, Zeal, Printers, Windows and local AI
# appear with their features. Entries that name nothing are always shown,
# and every entry that needs something names a real program or file.
#
# Each entry shows its key in a straight column, a plugin's and a web
# app's too. Super+m is in sections: a row a section, saying what it
# holds; a section of one entry is that entry; lines about one thing stay
# together; typing finds an entry of any section.
#
# The menu's functions are read from commands.lisp and run in sbcl, with a
# made-up PATH and home. The menu's own entries are the registry's
# (lib/registry.sh menu). tests/registry.sh opens the menu in a real
# StumpWM.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
command -v sbcl >/dev/null || { echo "(menu needs sbcl; skipped here)"; exit 0; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
lisp="$here/config/stumpwm/vikix/commands.lisp"

mkdir -p "$t/bin" "$t/home/dev/python/.venv/bin"
touch "$t/bin/zeal" "$t/home/dev/python/.venv/bin/jupyter"
fns=$(awk '/^\(defun vikix-program-p/,/^$/; /^\(defun vikix-menu-entry-here-p/,/^$/' "$lisp")
[ -n "$fns" ] || { echo "FAIL: the menu's functions aren't in commands.lisp"; exit 1; }
cat > "$t/check.lisp" <<EOF
(require :asdf)
$fns
(defun say (entry) (format t "~a=~a~%" (first entry) (if (vikix-menu-entry-here-p entry) "shown" "hidden")))
(say '("Zeal" nil "zeal"))
(say '("Printers" nil "system-config-printer"))
(say '("JupyterLab" nil "~/dev/python/.venv/bin/jupyter"))
(say '("Docs" nil "~/dev/index.html"))
(say '("Plain" nil))
EOF
sbcl=$(command -v sbcl)
out=$(HOME="$t/home/" PATH="$t/bin:/nonexistent" "$sbcl" --script "$t/check.lisp" 2>&1) ||
  { echo "FAIL: the menu's functions didn't run: $out"; exit 1; }
for want in Zeal=shown Printers=hidden JupyterLab=shown Docs=hidden Plain=shown; do
  grep -qx "$want" <<<"$out" || { echo "FAIL: expected $want, got: $(tr '\n' ' ' <<<"$out")"; fail=1; }
done

# Each entry shows its key, found in *vikix-bindings*: a command, or a
# program the key starts too; an entry no key does shows none.
fns=$(awk '/^\(defun vikix-menu-entry-command/,/^$/; /^\(defun vikix-menu-entry-key/,/^$/; /^\(defun vikix-menu-lines/,/^$/' "$lisp")
cat > "$t/keys.lisp" <<EOF
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defvar *vikix-bindings* '(("s-C-d" "vikix-quiet" "Do not disturb") ("s-F10" "exec vikix-dictate toggle ask" "Voice")
                           ("s-M-t" "vikix-webapp teams" "Teams (web app)") ("s-M-u" "ai-usage" "Claude plan")
                           ("s-C-v" "vikix-record area" "Record")))
(defun vikix-pretty-key (k)
  (or (second (assoc k '(("s-C-d" "Super+Ctrl+d") ("s-F10" "Super+F10") ("s-M-t" "Super+Alt+t") ("s-M-u" "Super+Alt+u")
                         ("s-C-v" "Super+Ctrl+v"))
                     :test #'equal))
      k))
$fns
(dolist (line (vikix-menu-lines '(("Do not disturb on/off" vikix-quiet)
                                  ("Voice: talk to the AI" (run-shell-command "vikix-dictate toggle ask"))
                                  ("Install a program" (vikix-in-terminal "vikix pkg add"))
                                  ("Theme" vikix-pick-theme))))
  (format t "[~a]~%" (first line)))
;; A web app's and a plugin's entries are forms that call a command: their
;; keys are found too. The column of keys is straight, after the longest
;; label that has one, however long that is.
(dolist (line (vikix-menu-lines '(("Web app: Teams" (vikix-webapp "teams") nil "Apps")
                                  ("Claude plan: how much is used" (ai-usage) :plugin)
                                  ("Record the screen, an area of it or a window, with or without the pointer" (run-commands "vikix-record area"))
                                  ("A form no key could be" (progn (message "x") (vikix-quiet))))))
  (format t "[~a]~%" (first line)))
EOF
out=$("$sbcl" --script "$t/keys.lisp" 2>&1)
for want in "[Do not disturb on/off  Super+Ctrl+d]" "[Voice: talk to the AI  Super+F10]" "[Install a program]" "[Theme]" \
    "[Web app: Teams                                                             Super+Alt+t]" \
    "[Claude plan: how much is used                                              Super+Alt+u]" \
    "[Record the screen, an area of it or a window, with or without the pointer  Super+Ctrl+v]" \
    "[A form no key could be]"; do
  grep -qxF "$want" <<<"$out" || { echo "FAIL: the menu should show $want, got: $(tr '\n' ' ' <<<"$out")"; fail=1; }
done

# Super+m in sections. The registry's own entries, then what a web app, two
# plugins and the user add as they do: before Power, and (the user's old
# way) after it.
fns=$(awk '/^\(defun vikix-menu-(entry-command|entry-key|lines|typed-p|entry-section|head|together|sections|hint|rows|row-shown-p|everything) /,/^$/' "$lisp")
cat > "$t/sections.lisp" <<EOF
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(load "$here/config/stumpwm/vikix/registry.lisp")
(defvar *vikix-menu* (vikix-registry-menu))
(defvar *vikix-bindings* (vikix-registry-bindings))
(defvar *vikix-apps-menu* '(("Video: edit (Shotcut)" (run-shell-command "shotcut") "shotcut")
                            ("Pictures: edit a photo (GIMP)" (run-shell-command "gimp") "gimp")))
$fns
(setf *vikix-menu* (append (butlast *vikix-menu*)
                           '(("Web app: Teams" (vikix-webapp "teams") nil "Apps")
                             ("Sums: a+b, and (more" (sums) nil "Work")
                             ("Projects: what to push, pull or commit" (repos-term) :plugin "Work")
                             ("Flights: search" (flights-search) :plugin)
                             ("Flights: the watched ones that got cheaper" (flights-drops) :plugin)
                             ("Tides: today's" (tides) :plugin "Sailing"))
                           (last *vikix-menu*)
                           '(("iPhone" iphone-menu))))
(defvar *sections* (vikix-menu-sections (vikix-menu-everything)))
(defvar *rows* (vikix-menu-rows *sections*))
(defun shown (typed) (remove-if-not (lambda (row) (vikix-menu-row-shown-p (first row) (second row) typed)) *rows*))
(format t "sections=~{~a~^,~}~%" (mapcar #'first *sections*))
(dolist (row (shown "")) (format t "top=[~a]~%" (first row)))
(dolist (name '("Work" "Apps" "Windows" "System"))
  (format t "~a=~{~a~^|~}~%" name (mapcar #'first (rest (assoc name *sections* :test #'equal)))))
(dolist (row (shown "lay")) (format t "lay=[~a]~%" (first row)))
(format t "kinds=~{~(~a~)~^,~}~%" (remove-duplicates (mapcar #'second (shown "lay"))))
(format t "spaces=~a~%" (length (shown "  ")))
;; What is typed is plain letters, in any case and any order of words: a
;; key's own name finds it, plus sign and all.
(format t "words=~{~a~^|~}~%" (mapcar (lambda (row) (first (third row))) (shown "S-c-spc  layout")))
(format t "plus=~{~a~^|~}~%" (mapcar (lambda (row) (first (third row))) (shown "a+b")))
(format t "none=~a~%" (length (shown "layout zzz")))
(dolist (label '("Layout: save this workspace's, by name" "Do not disturb on/off" "The bar on/off (hide it for the whole screen)"
                 "Why did that happen? What the desktop just did, and what made it" "What does a key do?"
                 "Find a window, any workspace" "Tray on/off: network and Bluetooth icons in the bar" "Emoji"))
  (format t "head=~a~%" (vikix-menu-head label)))
(format t "hint=~a~%" (vikix-menu-hint '(("One: a") ("One: b") ("Two") ("Three (x)") ("Four, and more")) 20))
(format t "longest=~a~%" (reduce #'max (mapcar (lambda (row) (length (first row))) (shown ""))))
EOF
out=$("$sbcl" --script "$t/sections.lisp" 2>&1) || { echo "FAIL: the menu's sections didn't run: $(tail -5 <<<"$out")"; exit 1; }
has() { grep -qxF -- "$1" <<<"$out" || { echo "FAIL: $2: no line '$1' in: $(grep "^${1%%=*}=" <<<"$out" | tr '\n' ' ')"; fail=1; }; }
has "sections=Start,Help,Vikix,AI,Work,Notifications,Desktop,Windows,System,Apps,Plugins,Sailing,Yours,Power" \
  "the sections come in Vikix's order, a plugin's own, Plugins and Yours after them, Power last"
has "top=[Start          Welcome, Add software, Install a program, Remove a program]" "a section's row says what it holds"
has "top=[Notifications  Notifications, Do not disturb, Focus time]" "a section's row names each thing once"
has "top=[Plugins        Flights]" "a plugin's entry that names no section is in Plugins"
has "top=[Tides: today's]" "a section of one entry is that entry, at the top"
has "top=[iPhone]" "an entry of yours that names no section is in Yours: alone there, it is at the top"
has "top=[Power: lock, suspend, log out, reboot, power off  s-S-ESC]" "Power is the last row, with its key"
[ "$(grep -c '^top=' <<<"$out")" = 14 ] || { echo "FAIL: the top of the menu should have 14 rows: $(grep -c '^top=' <<<"$out")"; fail=1; }
[ "$(grep '^top=' <<<"$out" | tail -1)" = "top=[Power: lock, suspend, log out, reboot, power off  s-S-ESC]" ] ||
  { echo "FAIL: Power should be the menu's last row: $(grep '^top=' <<<"$out" | tail -1)"; fail=1; }
longest=$(sed -n 's/^longest=//p' <<<"$out")
[ "${longest:-99}" -le 80 ] || { echo "FAIL: a row at the top of the menu is $longest letters wide; 80 fit a small screen"; fail=1; }
has "Work=Projects: open one (a terminal there, its log in the editor)|Projects: what to push, pull or commit|Where was I? (the project, its next step, what isn't saved)|My day: each project's time, entries and commits (kept in ~/journal)|Clipboard history|Emoji|Calculator|Learn C: the lesson, and a shell beside it|JupyterLab (in ~/dev)|Sums: a+b, and (more" \
  "a plugin's line goes beside Vikix's about the same thing (Projects)"
has "Apps=Video: edit (Shotcut)|Pictures: edit a photo (GIMP)|Dropbox|Windows (the VM)|Web app: Teams" \
  "Apps has the apps that came with features, then Dropbox, Windows and the web apps"
has "Windows=Overview: every workspace, drawn small|Layout: pick this workspace's (tiles, main and stack, grid, strip)|Layout: save this workspace's, by name|Layout: put this workspace back as one you saved|Strip: this workspace scrolls sideways (Viri), or tiled again|Gaps around windows on/off|Find a window, any workspace|Bring every window of another workspace here|Remember this window here: write the rule for where it is|Rules: the list, one off or on, why this window is where it is|Bring my windows back, as they were before the restart" \
  "Windows keeps the three layout lines together"
has "System=Wi-Fi: pick a network (scans first)|Network: everything else (nmtui)|Network use: which program is using it (nethogs)|Firewall: on or off, and what it lets in|Bluetooth|Sound (pavucontrol)|Screens: extend, mirror, one only, arrange|Screens: arrange (arandr)|Screens: save this layout|Printers|Eject a drive|Apply keyboard settings|Firmware updates" \
  "System keeps the three lines for screens together"
has "lay=[Windows        Layout: pick this workspace's (tiles, main and stack, grid, strip)    s-C-SPC SPC]" "typing finds an entry, its section before it and its key after (one inside a map: both keys)"
has "lay=[System         Screens: save this layout]" "typing looks in every section"
has "kinds=found" "while something is typed, no section's row shows"
has "spaces=14" "spaces alone are nothing typed"
has "words=Layout: pick this workspace's (tiles, main and stack, grid, strip)" "every word typed is looked for, in any case, a key's name too"
has "plus=Sums: a+b, and (more" "what is typed is plain letters, not a pattern"
has "none=0" "a word that is nowhere finds nothing"
for head in "Layout" "Do not disturb" "The bar" "Why did that happen?" "What does a key do?" "Find a window" "Tray" "Emoji"; do
  has "head=$head" "what a line is about"
done
has "hint=One, Two, Three ..." "what a section holds is cut at a whole word, and says there is more"
# So no label names a key itself: it would go stale when the key moves.
if "$here/lib/registry.sh" menu | cut -f1 | grep -q 'Super+'; then
  echo "FAIL: a Super+m label names its key; the menu shows keys by itself"; fail=1
fi

# Every need the menu names is a program some package list installs, or a
# file Vikix makes: a typo would hide the entry for good.
while IFS= read -r need; do
  # shellcheck disable=SC2088  # a literal "~/" in the menu, not a path to expand
  case $need in
    "~/"*) grep -rqF "${need##*/}" "$here/install" "$here/bin" ||      # its name, at least
             { echo "FAIL: the menu needs $need, which nothing makes"; fail=1; } ;;
    ghb) grep -qx handbrake <(sed 's/[[:space:]]*#.*//' "$here"/packages/optional/video.list) ||  # HandBrake's program
           { echo "FAIL: the menu needs ghb, but no list installs handbrake"; fail=1; } ;;
    *) grep -rqxE "$need( .*)?" <(cat "$here"/packages/*.list "$here"/packages/optional/*.list | sed 's/[[:space:]]*#.*//') ||
         { echo "FAIL: the menu needs the program $need, but no list installs a package of that name"; fail=1; } ;;
  esac
done < <("$here/lib/registry.sh" menu | cut -f2 | grep . | sort -u
         awk '/^\(defparameter \*vikix-apps-menu\*/,/^  "The apps of Super/' "$lisp" |
           grep -oE '(\) |^ +)"(~/[^"]+|[a-z-]+)"\)+$' | sed -E 's/^(\) | +)"//; s/"\)+$//')

# Super+a asks: an agent here, or at a new desk (vikix-agent-choice), a
# plain menu in *vikix-menu*'s form; here first, where a stray Enter lands.
choice=$(awk '/^\(defparameter \*vikix-agent-choice-menu\*/,/^  "What Super\+a asks/' "$lisp")
grep -q '^(defcommand vikix-agent-choice ' "$lisp" || { echo "FAIL: no vikix-agent-choice command in commands.lisp"; fail=1; }
grep -qE ':run "vikix-agent-choice" :key "s-a"' "$here/config/stumpwm/vikix/registry.lisp" ||
  { echo "FAIL: Super+a doesn't run vikix-agent-choice"; fail=1; }
printf '%s\n' "$choice" | grep -A1 "'((" | head -1 | grep -q 'here.*(run-shell-command "vikix-agents here")' ||
  { echo "FAIL: the first choice of Super+a isn't the agent here (vikix-agents here)"; fail=1; }
printf '%s\n' "$choice" | grep -q 'new desk.*(run-shell-command "vikix-agents desk")' ||
  { echo "FAIL: Super+a doesn't offer an agent at a new desk (vikix-agents desk)"; fail=1; }

# The launcher (Super+d) lists config/applications/*.desktop: each runs a
# command Vikix has, and JupyterLab answers to what people type, jlab too.
for f in "$here"/config/applications/*.desktop; do
  exe=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$f")
  [ -e "$here/bin/$exe" ] || command -v "$exe" >/dev/null ||
    { echo "FAIL: ${f##*/} runs '$exe', which isn't in bin/"; fail=1; }
done
grep -q '^Keywords=.*jlab;' "$here/config/applications/vikix-jupyterlab.desktop" ||
  { echo "FAIL: typing jlab in the launcher wouldn't find JupyterLab (no Keywords=jlab)"; fail=1; }

[ "$fail" = 0 ] && echo "menu: entries whose program or file isn't here are left out, the rest shown with their keys in a straight column (a web app's and a plugin's too), Super+m in sections that say what they hold, lines about one thing together, typing finds an entry of any section, Super+a asks here (then which agent) or a new desk, every need is real, and the launcher entries run and are found (jlab)"
exit "$fail"
