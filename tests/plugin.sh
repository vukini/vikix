#!/usr/bin/env bash
# tests/plugin.sh — vikix plugin, against a plugins repo of its own (a git
# repository in the test folder, at a pinned commit):
#
#   list     fetches the pinned commit, lists every plugin, marks yours
#   add      shows what it runs and changes; refuses without a terminal
#            unless --yes; refuses a name that isn't there, and a plugin
#            for a newer Vikix; links its programs, writes their man
#            pages, copies its settings once, runs its setup, names it in
#            plugins.list; a failed setup adds nothing
#   off/on   off keeps it (and its programs) but stops it loading; on undoes
#   remove   runs its remove, unlinks its programs, takes their man pages
#            away and it off the list, keeps your settings
#   safe     the next login loads none
#   sync     fetches nothing without plugins; a moved pin is fetched
#   Lisp     plugins.lisp reads the list as StumpWM does (on, not off)
#
# Nothing reaches StumpWM (no DISPLAY) or the network (a local repo).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
HOME_REAL=$HOME   # the plugins repository is looked for in the real one
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME" "$VIKIX_STATE"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# A plugins repo: "demo" (a program, settings, a setup that leaves a mark,
# a remove that takes it), "broken" (its setup fails), "future" (for a
# Vikix far ahead).
repo="$t/repo"
mkdir -p "$repo/demo/bin" "$repo/demo/settings" "$repo/broken" "$repo/future"
printf 'name: demo\nabout: A demo\nkinds: bar\nvikix: 0.1.0\nlisp: plugin.lisp\nsetup: setup\nremove: remove\nchanges: leaves a mark in ~/mark\n' > "$repo/demo/manifest"
echo '(in-package :stumpwm)' > "$repo/demo/plugin.lisp"
printf '#!/bin/sh\n# demo-tool — a demo of a tool.\n#\n#   demo-tool   say demo\necho demo\n' > "$repo/demo/bin/demo-tool"
echo "colour = blue" > "$repo/demo/settings/demo.conf"
printf '#!/bin/sh\ntouch "$HOME/mark"\n' > "$repo/demo/setup"
printf '#!/bin/sh\nrm -f "$HOME/mark"\n' > "$repo/demo/remove"
printf 'name: broken\nabout: Fails\nkinds: menu\nvikix: 0.1.0\nsetup: setup\nchanges: none\n' > "$repo/broken/manifest"
printf '#!/bin/sh\nexit 1\n' > "$repo/broken/setup"
printf 'name: future\nabout: Later\nkinds: key\nvikix: 99.0.0\n' > "$repo/future/manifest"
chmod +x "$repo"/demo/bin/demo-tool "$repo"/demo/setup "$repo"/demo/remove "$repo"/broken/setup
git -C "$repo" init -q && git -C "$repo" add . && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm one
export VIKIX_PLUGINS_REPO="$repo" VIKIX_PLUGINS_COMMIT
VIKIX_PLUGINS_COMMIT=$(git -C "$repo" rev-parse HEAD)
pl() { bash "$here/bin/vikix-plugin" "$@" < /dev/null; }
list="$HOME/.config/vikix/plugins.list"
dir="$HOME/.local/share/vikix/plugins"

out=$(pl sync 2>&1)
check "sync without plugins should fetch nothing: $out" test ! -d "$dir"
out=$(pl list 2>&1)
check "list should show the plugins: $out" grep -qE '^demo +A demo$' <<<"$out"
check "list should have fetched the pinned commit" test "$(git -C "$dir" rev-parse HEAD)" = "$VIKIX_PLUGINS_COMMIT"

out=$(pl add demo 2>&1) && { echo "FAIL: add without a terminal or --yes should refuse"; fail=1; }
check "add should say what it changes, before asking: $out" grep -q "changes: leaves a mark" <<<"$out"
check "a refused add added nothing" test ! -e "$HOME/mark"
pl add nosuch >/dev/null 2>&1 && { echo "FAIL: add of a plugin that isn't there worked"; fail=1; }
out=$(pl add future --yes 2>&1) && { echo "FAIL: a plugin for a newer Vikix was added"; fail=1; }
check "a plugin for a newer Vikix should say so: $out" grep -q "needs Vikix 99.0.0" <<<"$out"
pl add broken --yes >/dev/null 2>&1 && { echo "FAIL: a plugin whose setup failed was added"; fail=1; }
check "a failed setup shouldn't name it in the list" bash -c "! grep -qx broken '$list' 2>/dev/null"

pl add demo --yes >/dev/null 2>&1
check "add should run its setup" test -e "$HOME/mark"
check "add should link its programs" test "$(readlink "$HOME/.local/bin/demo-tool")" = "$dir/demo/bin/demo-tool"
check "add should write its programs' man pages" grep -q '^demo\\-tool \\- a demo of a tool$' "$HOME/.local/share/man/man1/demo-tool.1"
check "add should leave Vikix's own man pages there" test -s "$HOME/.local/share/man/man1/vikix-plugin.1"
check "add should copy its settings" grep -qx "colour = blue" "$HOME/.config/vikix/plugins/demo/demo.conf"
check "add should name it in the list" grep -qx demo "$list"
echo "colour = red" > "$HOME/.config/vikix/plugins/demo/demo.conf"
pl add demo --yes >/dev/null 2>&1
check "adding again should keep your settings" grep -qx "colour = red" "$HOME/.config/vikix/plugins/demo/demo.conf"
check "adding again shouldn't list it twice" test "$(grep -cx demo "$list")" = 1
out=$(pl list)
check "list should mark yours: $out" grep -qE '^demo +added +A demo$' <<<"$out"

pl off demo >/dev/null 2>&1
check "off should keep it, switched off" grep -qx "#off demo" "$list"
check "off should keep its programs" test -L "$HOME/.local/bin/demo-tool"
check "off should keep their man pages" test -s "$HOME/.local/share/man/man1/demo-tool.1"
pl on demo >/dev/null 2>&1
check "on should bring it back" grep -qx demo "$list"
pl off demo >/dev/null 2>&1
out=$(pl status)
check "status should name an off plugin once: $out" grep -qx "yours      demo " <<<"$out"
pl on demo >/dev/null 2>&1
# A name is a name, never a pattern: 'd.*' once matched demo and took it
# off the list without its remove; '' matched a blank line.
pl remove 'd.*' >/dev/null 2>&1 && { echo "FAIL: remove of a pattern should refuse"; fail=1; }
pl off '' >/dev/null 2>&1 && { echo "FAIL: off without a name should refuse"; fail=1; }
check "a pattern or no name should leave the list as it was" test "$(grep -v '^#' "$list")" = demo

# What StumpWM loads: plugins.lisp reads the list the same way.
if command -v sbcl >/dev/null; then
  pl off demo >/dev/null 2>&1
  printf 'other\n' >> "$list"
  got=$(sbcl --script /dev/stdin <<LISP
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defvar *vikix-plugins-list* #p"$list")
$(sed -n '/^(defun vikix-plugin-names/,/^$/p' "$here/config/stumpwm/vikix/plugins.lisp")
(format t "~{~a~^ ~}" (vikix-plugin-names))
LISP
)
  check "StumpWM should load the plugins on, not those off: $got" test "$got" = other
  sed -i '/^other$/d' "$list"
  pl on demo >/dev/null 2>&1
fi

# A plugin's key over one of Vikix's: unloading puts Vikix's back, in the
# map and in the key card, and a key no one had goes. (It once left the
# key doing nothing until StumpWM loaded its config again.)
if command -v sbcl >/dev/null; then
  got=$(sbcl --script /dev/stdin <<LISP
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defvar *top-map* (make-hash-table :test #'equal))
(defvar *vikix-bind-later* nil)
(defvar *vikix-menu* '())
(defvar *vikix-plugin* nil)
(defun kbd (k) k)
(defun define-key (map key command) (setf (gethash key map) command))
(defun undefine-key (map key) (remhash key map))
(defun lookup-key (map key) (values (gethash key map)))
(defun vikix-bind (key command) (define-key *top-map* key command))
(defun vikix-plugin-menu-entry-p (e) (declare (ignore e)) nil)
(defvar *vikix-bindings* (list (list "s-M-c" "vikix-mine" "Mine" "Apps")))
(define-key *top-map* "s-M-c" "vikix-mine")
$(sed -n '/^(defvar \*vikix-key-clashes\*/,/^(vikix-binding-keys/p' "$here/config/stumpwm/vikix/keys.lisp" | sed '$d')
(defvar *vikix-plugin-keys* '())
(defvar *vikix-plugin-bars* '())
(defvar *vikix-plugins-loaded* '())
$(sed -n '/^(defun vikix-plugin-key/,/^$/p; /^(defun vikix-unload-plugins/,/^$/p' "$here/config/stumpwm/vikix/plugins.lisp")
(let ((*vikix-plugin* "one")) (vikix-plugin-key "s-M-c" "one-week" "Week") (vikix-plugin-key "s-M-q" "one-q" "Q"))
(let ((*vikix-plugin* "two")) (vikix-plugin-key "s-M-c" "two-c" "C"))
(format t "~a " (gethash "s-M-c" *top-map*))
(vikix-unload-plugins)
(format t "~a ~a ~a" (gethash "s-M-c" *top-map*) (gethash "s-M-q" *top-map* "none")
        (mapcar #'second *vikix-bindings*))
LISP
)
  check "a plugin's key should give back the one it took: $got" test "$got" = "two-c vikix-mine none (vikix-mine)"
fi

# Clashes: a plugin taking a key Vikix (or another plugin) has is noted,
# once each, and a reload forgets them; a new key is no clash.
if command -v sbcl >/dev/null; then
  got=$(sbcl --script /dev/stdin <<LISP
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defvar *top-map* (make-hash-table :test #'equal))
(defvar *vikix-bind-later* nil)
(defvar *vikix-menu* '())
(defvar *vikix-plugin* nil)
(defvar *vikix-plugin-keys* '())
(defvar *vikix-plugin-bars* '())
(defvar *vikix-plugins-loaded* '())
(defun kbd (k) k)
(defun define-key (map key command) (setf (gethash key map) command))
(defun undefine-key (map key) (remhash key map))
(defun lookup-key (map key) (values (gethash key map)))
(defun vikix-bind (key command) (define-key *top-map* key command))
(defun vikix-plugin-menu-entry-p (e) (declare (ignore e)) nil)
(defvar *vikix-bindings* (list (list "s-M-x" "exec vikix-esploro menu" "Esploro's commands")))
$(sed -n '/^(defvar \*vikix-key-clashes\*/,/^(vikix-binding-keys/p' "$here/config/stumpwm/vikix/keys.lisp" | sed '$d')
$(sed -n '/^(defun vikix-plugin-key/,/^$/p; /^(defun vikix-unload-plugins/,/^$/p' "$here/config/stumpwm/vikix/plugins.lisp")
(let ((*vikix-plugin* "one")) (vikix-plugin-key "s-M-x" "one-x" "X") (vikix-plugin-key "s-M-q" "one-q" "Q"))
(let ((*vikix-plugin* "two")) (vikix-plugin-key "s-M-x" "two-x" "X"))
(setf *print-pretty* nil)
(format t "~s|" (reverse *vikix-key-clashes*))
(vikix-unload-plugins)
(format t "~s" *vikix-key-clashes*)
LISP
)
  check "a plugin's key over another's should be noted, and forgotten on reload: $got" test "$got" = \
    '(("s-M-x" "Vikix: Esploro'"'"'s commands" "plugin one") ("s-M-x" "plugin one" "plugin two"))|NIL'
fi

# The plugins at Vikix's pin take no key Vikix has, nor one another's.
# Needs a copy of the plugins repository (the dev machine's, or
# VIKIX_TEST_PLUGINS_REPO); GitHub's runners have none, and say so.
plugins_repo=${VIKIX_TEST_PLUGINS_REPO:-$HOME_REAL/src/vikix-plugins}
pin=$(sed -n 's/^PLUGINS_COMMIT=\${VIKIX_PLUGINS_COMMIT:-\([0-9a-f]*\)}.*/\1/p' "$here/bin/vikix-plugin")
if [ -d "$plugins_repo/.git" ] && git -C "$plugins_repo" cat-file -e "$pin^{commit}" 2>/dev/null; then
  {
    sed -n 's/^ *("\([^"]*\)" .*/\1 Vikix/p' "$here/config/stumpwm/vikix/keys.lisp"
    for n in 1 2 3 4 5 6 7 8 9; do echo "s-$n Vikix"; done
    git -C "$plugins_repo" ls-tree --name-only -r "$pin" | grep '/plugin\.lisp$' | while read -r f; do
      git -C "$plugins_repo" show "$pin:$f" | grep -o '(vikix-plugin-key "[^"]*"' | sed "s/.*\"\(.*\)\"/\1 plugin ${f%%/*}/"
    done
  } > "$t/owners"
  clashes=$(awk '{n[$1]++; o[$1]=o[$1] " " $2 ($3 ? " " $3 : "")} END {for (k in n) if (n[k] > 1) print k ":" o[k]}' "$t/owners")
  check "no key should have two owners at the plugins' pin: $clashes" test -z "$clashes"
else
  echo "(the plugins' keys against Vikix's: no copy of the plugins repository here at the pin; skipped)"
fi

pl remove demo >/dev/null 2>&1
check "remove should run its remove" test ! -e "$HOME/mark"
check "remove should unlink its programs" test ! -e "$HOME/.local/bin/demo-tool"
check "remove should take away their man pages" test ! -e "$HOME/.local/share/man/man1/demo-tool.1"
check "remove should take it off the list" bash -c "! grep -q demo '$list'"
check "remove should keep your settings" test -e "$HOME/.config/vikix/plugins/demo/demo.conf"

pl safe >/dev/null 2>&1
check "safe should mark the next login" test -e "$HOME/.config/vikix/plugins-safe"

# A moved pin is fetched by sync, when there are plugins.
pl add demo --yes >/dev/null 2>&1
echo "# two" >> "$repo/demo/plugin.lisp"
git -C "$repo" -c user.name=t -c user.email=t@t commit -qam two
VIKIX_PLUGINS_COMMIT=$(git -C "$repo" rev-parse HEAD) pl sync >/dev/null 2>&1
check "sync should fetch a moved pin" grep -q "# two" "$dir/demo/plugin.lisp"

[ "$fail" = 0 ] && echo "plugin: list, add (asks, refuses, setup, settings once), off and on, remove, safe, sync to the pin"
exit "$fail"
