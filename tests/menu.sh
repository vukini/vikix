#!/usr/bin/env bash
# tests/menu.sh — the Super+m menu leaves out what isn't here: an entry
# that names a program (on PATH) or a file (~/...) it needs is shown only
# when that is there, so JupyterLab, Zeal, Printers, Windows and local AI
# appear with their features. Entries that name nothing are always shown,
# and every entry that needs something names a real program or file.
#
# vikix-program-p and vikix-menu-entry-here-p are read from commands.lisp
# and run in sbcl, with a made-up PATH and home.

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
(defvar *vikix-bindings* '(("s-C-d" "vikix-quiet" "Do not disturb") ("s-F10" "exec vikix-dictate toggle ask" "Voice")))
(defun vikix-pretty-key (k) (cond ((equal k "s-C-d") "Super+Ctrl+d") ((equal k "s-F10") "Super+F10") (t k)))
$fns
(dolist (line (vikix-menu-lines '(("Do not disturb on/off" vikix-quiet)
                                  ("Voice: talk to the AI" (run-shell-command "vikix-dictate toggle ask"))
                                  ("Install a program" (vikix-in-terminal "vikix pkg add"))
                                  ("Theme" vikix-pick-theme))))
  (format t "[~a]~%" (first line)))
EOF
out=$("$sbcl" --script "$t/keys.lisp" 2>&1)
for want in "[Do not disturb on/off  Super+Ctrl+d]" "[Voice: talk to the AI  Super+F10]" "[Install a program]" "[Theme]"; do
  grep -qxF "$want" <<<"$out" || { echo "FAIL: the menu should show $want, got: $(tr '\n' ' ' <<<"$out")"; fail=1; }
done
# So no label names a key itself: it would go stale when the key moves.
if awk '/^\(defparameter \*vikix-menu\*/,/^  "Each entry/' "$lisp" | grep -qE '^ *\("[^"]*Super\+'; then
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
done < <(awk '/^\(defparameter \*vikix-menu\*/,/^  "Each entry/; /^\(defparameter \*vikix-apps-menu\*/,/^  "The apps menu/' "$lisp" |
         grep -oE '(\) |^ +)"(~/[^"]+|[a-z-]+)"\)+$' | sed -E 's/^(\) | +)"//; s/"\)+$//')

# The launcher (Super+d) lists config/applications/*.desktop: each runs a
# command Vikix has, and JupyterLab answers to what people type, jlab too.
for f in "$here"/config/applications/*.desktop; do
  exe=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$f")
  [ -e "$here/bin/$exe" ] || command -v "$exe" >/dev/null ||
    { echo "FAIL: ${f##*/} runs '$exe', which isn't in bin/"; fail=1; }
done
grep -q '^Keywords=.*jlab;' "$here/config/applications/vikix-jupyterlab.desktop" ||
  { echo "FAIL: typing jlab in the launcher wouldn't find JupyterLab (no Keywords=jlab)"; fail=1; }

[ "$fail" = 0 ] && echo "menu: entries whose program or file isn't here are left out, the rest shown, every need is real, and the launcher entries run and are found (jlab)"
exit "$fail"
