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

# Every need the menu names is a program some package list installs, or a
# file Vikix makes: a typo would hide the entry for good.
while IFS= read -r need; do
  # shellcheck disable=SC2088  # a literal "~/" in the menu, not a path to expand
  case $need in
    "~/"*) grep -rqF "${need##*/}" "$here/install" "$here/bin" ||      # its name, at least
             { echo "FAIL: the menu needs $need, which nothing makes"; fail=1; } ;;
    *) grep -rqxE "$need( .*)?" <(cat "$here"/packages/*.list "$here"/packages/optional/*.list | sed 's/[[:space:]]*#.*//') ||
         { echo "FAIL: the menu needs the program $need, but no list installs a package of that name"; fail=1; } ;;
  esac
done < <(awk '/^\(defparameter \*vikix-menu\*/,/^  "Each entry/' "$lisp" |
         grep -oE '\) "(~/[^"]+|[a-z-]+)"\)$' | sed -E 's/^\) "//; s/"\)$//')

[ "$fail" = 0 ] && echo "menu: entries whose program or file isn't here are left out, the rest shown, and every need is real"
exit "$fail"
