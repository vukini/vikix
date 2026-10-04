#!/usr/bin/env bash
# lib/skill-keys.sh — the agents' skill's list of keys and the README's
# table of them, made from the keys themselves, so neither can go stale as
# the hand-written ones could.
#
#   lib/skill-keys.sh            print the three blocks: Vikix's keys (from
#                                its commands, config/stumpwm/vikix/registry.lisp,
#                                grouped as the key card groups them), the
#                                commands an agent may run (the same file's
#                                :agent ones) and the plugins' keys (from the
#                                plugins repository at Vikix's pin)
#   lib/skill-keys.sh --write    put them into config/claude/skills/vikix/SKILL.md,
#                                between the <!-- keys -->, <!-- commands -->
#                                and <!-- plugin-keys --> markers; and Vikix's
#                                keys as a table, a row a key, into README.md
#                                between its <!-- readme-keys --> markers
#   lib/skill-keys.sh --check    exit 1 when SKILL.md's blocks or README.md's
#                                table aren't what they'd be now
#                                (tests/agents.sh runs it);
#                                the plugins' block only where a copy of the
#                                plugins repository is at hand
#
# The plugins repository: VIKIX_PLUGINS_REPO, else ~/src/vikix-plugins.
# Needs sbcl, which reads the key names and groups with help.lisp's own code.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
skill="$root/config/claude/skills/vikix/SKILL.md"
readme="$root/README.md"
registry="$root/config/stumpwm/vikix/registry.lisp"
help="$root/config/stumpwm/vikix/help.lisp"
repo=${VIKIX_PLUGINS_REPO:-$HOME/src/vikix-plugins}
pin=$(sed -n 's/^PLUGINS_COMMIT=\${VIKIX_PLUGINS_COMMIT:-\([0-9a-f]*\)}.*/\1/p' "$root/bin/vikix-plugin")
command -v sbcl >/dev/null || { echo "skill-keys: needs sbcl" >&2; exit 2; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

have_plugins() { [ -d "$repo/.git" ] && git -C "$repo" cat-file -e "$pin^{commit}" 2>/dev/null; }

# The plugins' keys, as Lisp: (("KEY" "description" "plugin") ...).
plugin_keys() {
  echo "("
  if have_plugins; then
    git -C "$repo" ls-tree --name-only -r "$pin" | grep '/plugin\.lisp$' | sort | while read -r f; do
      git -C "$repo" show "$pin:$f" | tr '\n' ' ' |
        grep -oE '\(vikix-plugin-key +"[^"]+" +"[^"]*" +"[^"]*"' |
        sed -E "s/\(vikix-plugin-key +(\"[^\"]+\") +\"[^\"]*\" +(\"[^\"]*\")/(\1 \2 \"${f%%/*}\")/"
    done
  fi
  echo ")"
}

# The forms needed, cut from the files as tests/menu.sh and tests/lisp.sh do
# (help.lisp as a whole needs StumpWM's packages).
{
  echo '(defpackage :stumpwm (:use :cl)) (in-package :stumpwm)'
  echo "(load \"$registry\")"
  echo '(defparameter *vikix-bindings* (vikix-registry-bindings))'
  awk '/^\(defparameter \*vikix-key-names\*/,/^$/; /^\(defun vikix-pretty-key/,/^$/;
       /^\(defparameter \*vikix-extra-keys\*/,/^$/; /^\(defparameter \*vikix-key-groups\*/,/^$/;
       /^\(defun vikix-command-word/,/^$/; /^\(defun vikix-key-group/,/^$/' "$help"
  echo "(defparameter *plugin-keys* '$(plugin_keys))"
  cat <<'LISP'
(defun line (label description)
  (format nil "~a: ~a" label (string-right-trim "." description)))
(let ((groups '()))
  (dolist (b *vikix-bindings*)
    (destructuring-bind (key command description &optional group) b
      (let ((g (vikix-key-group command group)))
        (unless (assoc g groups :test #'string=) (setf groups (append groups (list (list g)))))
        (push (line (vikix-pretty-key key) description) (cdr (assoc g groups :test #'string=))))))
  (dolist (e *vikix-extra-keys*)
    (destructuring-bind (label description command) e
      (let ((g (vikix-key-group command)))
        (unless (assoc g groups :test #'string=) (setf groups (append groups (list (list g)))))
        (push (line label description) (cdr (assoc g groups :test #'string=))))))
  ;; In the key card's order of groups, Other last.
  (let ((order (append (mapcar #'first *vikix-key-groups*) '("Apps" "Other"))))
    (setf groups (sort groups #'< :key (lambda (g) (or (position (first g) order :test #'string=) 99)))))
  (format t "<!-- keys: made by lib/skill-keys.sh from registry.lisp; don't edit, run it with --write -->~%")
  (format t "Every Vikix key, as installed (Super+/ shows them on one card, Super+F1 searches them and runs one):~%~%")
  (dolist (g groups)
    (format t "- **~a:** ~{~a~^; ~}.~%" (first g) (reverse (rest g))))
  (format t "<!-- /keys -->~%")
  (format t "~%<!-- commands: made by lib/skill-keys.sh from registry.lisp; don't edit, run it with --write -->~%")
  (format t "The commands an agent may run without Lisp, by name (the MCP tool run_command; commands lists them, with the user's own): ~{~a~^; ~}.~%"
          (loop for c in *vikix-commands*
                when (getf c :agent)
                  collect (format nil "`~(~a~)`: ~a" (getf c :name) (string-right-trim "." (getf c :does)))))
  (format t "<!-- /commands -->~%")
  (format t "~%<!-- plugin-keys: made by lib/skill-keys.sh from the plugins at Vikix's pin -->~%")
  (format t "The plugins' keys, there only when the plugin is added (vikix plugin list): ~{~a~^; ~}.~%"
          (mapcar (lambda (k) (format nil "~a: ~a (~a)" (vikix-pretty-key (first k))
                                      (string-right-trim "." (second k)) (third k)))
                  *plugin-keys*))
  (format t "<!-- /plugin-keys -->~%")
  ;; The README's table: a row a key, under its group. A cell's | ` * and _
  ;; are Markdown's, so they are escaped.
  (flet ((cell (text)
           (with-output-to-string (out)
             (loop for c across text
                   do (when (find c "|`*_") (write-char #\\ out))
                      (write-char c out)))))
    (format t "~%<!-- readme-keys: made by lib/skill-keys.sh from registry.lisp; don't edit, run it with --write -->~%")
    (format t "| Key | What it does |~%|---|---|~%")
    (dolist (g groups)
      (format t "| **~a** | |~%" (cell (first g)))
      (dolist (row (reverse (rest g)))
        ;; Each line was made as "KEY: words" above; a key's name has no ": ".
        (let ((colon (search ": " row)))
          (format t "| ~a | ~a |~%" (cell (subseq row 0 colon)) (cell (subseq row (+ colon 2)))))))
    (format t "<!-- /readme-keys -->~%")))
LISP
} > "$t/make.lisp"
sbcl --script "$t/make.lisp" > "$t/blocks" || { echo "skill-keys: sbcl failed" >&2; exit 2; }

block() {   # block NAME FILE: the lines from <!-- NAME... to <!-- /NAME -->
  awk -v n="$1" 'index($0, "<!-- " n ":") == 1 {on=1} on {print} index($0, "<!-- /" n " -->") == 1 {on=0}' "$2"
}

case ${1:-} in
  "") cat "$t/blocks" ;;
  --write)
    have_plugins || { echo "skill-keys: no copy of the plugins repository at the pin ($repo, ${pin:0:7}): the plugins' keys would be lost" >&2; exit 2; }
    python3 - "$skill" "$t/blocks" <<'PY'
import re, sys
skill, blocks = sys.argv[1], open(sys.argv[2]).read()
s = open(skill).read()
for name in ("keys", "commands", "plugin-keys"):
    new = re.search(r"<!-- %s:.*?<!-- /%s -->\n" % (name, name), blocks, re.S).group(0)
    pat = re.compile(r"<!-- %s:.*?<!-- /%s -->\n" % (name, name), re.S)
    if not pat.search(s):
        sys.exit(f"skill-keys: SKILL.md has no <!-- {name}: ... <!-- /{name} --> block to fill")
    s = pat.sub(lambda m: new, s, count=1)
open(skill, "w").write(s)
PY
    python3 - "$readme" "$t/blocks" <<'PY'
import re, sys
readme, blocks = sys.argv[1], open(sys.argv[2]).read()
pat = re.compile(r"<!-- readme-keys:.*?<!-- /readme-keys -->\n", re.S)
new = pat.search(blocks).group(0)
s = open(readme).read()
if not pat.search(s):
    sys.exit("skill-keys: README.md has no <!-- readme-keys: ... <!-- /readme-keys --> block to fill")
open(readme, "w").write(pat.sub(lambda m: new, s, count=1))
PY
    ;;
  --check)
    fail=0
    diff <(block keys "$skill") <(block keys "$t/blocks") >/dev/null ||
      { echo "SKILL.md's keys aren't registry.lisp's: lib/skill-keys.sh --write"; fail=1; }
    diff <(block commands "$skill") <(block commands "$t/blocks") >/dev/null ||
      { echo "SKILL.md's commands for agents aren't registry.lisp's: lib/skill-keys.sh --write"; fail=1; }
    diff <(block readme-keys "$readme") <(block readme-keys "$t/blocks") >/dev/null ||
      { echo "README.md's table of keys isn't registry.lisp's: lib/skill-keys.sh --write"; fail=1; }
    if have_plugins; then
      diff <(block plugin-keys "$skill") <(block plugin-keys "$t/blocks") >/dev/null ||
        { echo "SKILL.md's plugin keys aren't the plugins' at the pin: lib/skill-keys.sh --write"; fail=1; }
    fi
    exit "$fail" ;;
  *) echo "usage: lib/skill-keys.sh [--write|--check]" >&2; exit 2 ;;
esac
