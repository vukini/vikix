#!/usr/bin/env bash
# tests/webapp.sh — `vikix webapp`: websites as programs of their own.
#
#   add      a preset (superhuman) gets its address and, as the first mail
#            web app, Super+Shift+m; the next mail one gets no key unless
#            asked; a launcher entry with its window class; opts in to
#            Chromium (installed by 10-packages only when missing). Refused:
#            a bad name, an address that isn't https (but localhost), one of
#            Vikix's own keys, a key another web app has, a non-Super key
#   open     without StumpWM to ask, starts Chromium as an app window with
#            its own class and profile (700)
#   remove   takes the line and launcher entry away and keeps the logins;
#            --forget deletes them
#   Lisp     webapps.lisp reads the list, binds the keys, adds key help and
#            Super+m entries (before Power), and on a second load drops what
#            was removed without doubling anything
#
# A made-up home; chromium is a stand-in that notes its arguments.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME" "$t/bin"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
printf '#!/bin/sh\necho "chromium $*" >> %q\n' "$t/calls" > "$t/bin/chromium"; chmod +x "$t/bin/chromium"
export PATH="$t/bin:$PATH"
wa() { bash "$here/bin/vikix-webapp" "$@"; }
list="$HOME/.config/vikix/webapps"
apps="$HOME/.local/share/applications"

# --- add ------------------------------------------------------------------------------
out=$(wa add superhuman 2>&1) || { echo "FAIL: add superhuman failed: $out"; fail=1; }
check "superhuman should be on the list with its address and s-M: $(cat "$list")" grep -qx 'superhuman https://mail.superhuman.com/ s-M' "$list"
check "no launcher entry for superhuman" test -f "$apps/vikix-webapp-superhuman.desktop"
check "the launcher entry should open it and name its window class" \
  grep -q '^Exec=vikix-webapp open superhuman$' "$apps/vikix-webapp-superhuman.desktop"
check "the launcher entry's window class" grep -q '^StartupWMClass=vikix-superhuman$' "$apps/vikix-webapp-superhuman.desktop"
check "the launcher entry should be called Superhuman" grep -q '^Name=Superhuman$' "$apps/vikix-webapp-superhuman.desktop"
check "add didn't opt in to Chromium (so updates keep it)" grep -qx webapps "$HOME/.config/vikix/optional"
wa add fastmail >/dev/null 2>&1
check "a second mail web app took s-M too: $(cat "$list")" grep -qx 'fastmail https://app.fastmail.com/' "$list"
wa add fastmail --key s-F >/dev/null 2>&1
check "fastmail --key s-F should give it that key, once: $(cat "$list")" test "$(grep -c '^fastmail ' "$list")-$(grep '^fastmail ' "$list")" = "1-fastmail https://app.fastmail.com/ s-F"
wa add crm https://crm.example.com >/dev/null 2>&1
check "an app of your own should be kept with no key" grep -qx 'crm https://crm.example.com' "$list"
wa add dev http://localhost:3000/ >/dev/null 2>&1
check "http://localhost should be allowed" grep -qx 'dev http://localhost:3000/' "$list"

refuse() { local why=$1; shift; out=$(wa add "$@" 2>&1) && { echo "FAIL: add $* was accepted ($why)"; fail=1; }; true; }
refuse "not https" site http://example.com
refuse "a bad name" 'My App' https://example.com
refuse "not a preset, no address" nosuchthing
refuse "Vikix's own key" gmail --key s-A
refuse "another web app's key" gmail --key s-F
refuse "not a Super key" gmail --key C-g
check "a refused add changed the list" bash -c "! grep -q '^gmail\\|^site\\|^nosuchthing' '$list'"

# --- open, list, remove -------------------------------------------------------------------
: > "$t/calls"
wa open superhuman >/dev/null 2>&1
check "open should start Chromium as an app window with its own class and profile: $(cat "$t/calls")" \
  grep -qx "chromium --user-data-dir=$HOME/.local/share/vikix/webapps/superhuman --class=vikix-superhuman --no-first-run --no-default-browser-check --app=https://mail.superhuman.com/" "$t/calls"
check "the profile should be 700" test "$(stat -c %a "$HOME/.local/share/vikix/webapps/superhuman")" = 700
wa open nosuchthing >/dev/null 2>&1 && { echo "FAIL: open of a web app that isn't there worked"; fail=1; }
out=$(wa list)
check "list should show superhuman and its key: $out" grep -qE '^superhuman +https://mail.superhuman.com/ +s-M$' <<<"$out"
touch "$HOME/.local/share/vikix/webapps/superhuman/Cookies"
wa remove superhuman >/dev/null 2>&1
check "remove left superhuman on the list" bash -c "! grep -q '^superhuman ' '$list'"
check "remove left the launcher entry" test ! -e "$apps/vikix-webapp-superhuman.desktop"
check "remove without --forget deleted the logins" test -e "$HOME/.local/share/vikix/webapps/superhuman/Cookies"
wa add superhuman >/dev/null 2>&1
wa remove superhuman --forget >/dev/null 2>&1
check "remove --forget kept the logins" test ! -e "$HOME/.local/share/vikix/webapps/superhuman"

# --- webapps.lisp -------------------------------------------------------------------------
if command -v sbcl >/dev/null; then
  printf '# mine\nsuperhuman https://mail.superhuman.com/ s-M\nfastmail https://app.fastmail.com/\n' > "$list"
  cat > "$t/check.lisp" <<EOF
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
;; Stand-ins for the StumpWM the file runs in.
(defvar *top-map* (make-hash-table :test 'equal))
(defun kbd (k) k)
(defun undefine-key (map k) (remhash k map))
(defun vikix-bind (k command) (setf (gethash k *top-map*) command))
(defun split-string (s sep)
  (loop with out and start = 0
        for pos = (position (char sep 0) s :start start)
        do (push (subseq s start pos) out)
           (if pos (setf start (1+ pos)) (return (remove "" (nreverse out) :test #'string=)))))
(defmacro defcommand (name args prompts &body body)
  (declare (ignore prompts))
  \`(defun ,name ,args ,@(if (stringp (first body)) (rest body) body)))
(defun run-or-raise (&rest args) args)
(defvar *vikix-bindings* (list (list "s-RET" "vikix-terminal" "Terminal")))
(defvar *vikix-menu* (list (list "Theme" 'vikix-pick-theme) (list "Power" 'vikix-power)))
(load "$here/config/stumpwm/vikix/webapps.lisp")
(defun show ()
  (format t "keys ~s~%help ~s~%menu ~s~%"
          (sort (loop for k being the hash-keys of *top-map* using (hash-value v) collect (list k v)) #'string< :key #'first)
          (mapcar #'first *vikix-bindings*)
          (mapcar #'first *vikix-menu*)))
(show)
(with-open-file (o *vikix-webapps-file* :direction :output :if-exists :supersede)
  (write-line "fastmail https://app.fastmail.com/ s-F" o))
(vikix-load-webapps)
(show)
(format t "run ~s~%" (vikix-webapp "fastmail"))
EOF
  out=$(HOME="$HOME" sbcl --script "$t/check.lisp" 2>&1) || { echo "FAIL: webapps.lisp didn't load: $out"; fail=1; }
  first=$(sed -n 1,3p <<<"$out"); second=$(sed -n 4,6p <<<"$out")
  check "webapps.lisp should bind s-M to superhuman: $first" grep -qF 'keys (("s-M" "vikix-webapp superhuman"))' <<<"$first"
  check "the key help should list s-M after Vikix's own: $first" grep -qF 'help ("s-RET" "s-M")' <<<"$first"
  check "Super+m should list both, before Power: $first" grep -qF 'menu ("Theme" "Web app: Superhuman" "Web app: Fastmail" "Power")' <<<"$first"
  check "a reload should drop superhuman's key and add fastmail's: $second" grep -qF 'keys (("s-F" "vikix-webapp fastmail"))' <<<"$second"
  check "a reload doubled or kept key help: $second" grep -qF 'help ("s-RET" "s-F")' <<<"$second"
  check "a reload doubled or kept menu entries: $second" grep -qF 'menu ("Theme" "Web app: Fastmail" "Power")' <<<"$second"
  check "the key should run-or-raise by the window class vikix-fastmail: $out" \
    grep -qF 'run ("vikix-webapp launch fastmail" (:CLASS "vikix-fastmail"))' <<<"$out"
else
  echo "(webapps.lisp part needs sbcl; skipped here)"
fi

[ "$fail" = 0 ] && echo "webapp: presets, keys, launcher entries, Chromium app windows with their own profiles, and StumpWM's keys and menu"
exit "$fail"
