#!/usr/bin/env bash
# tests/door.sh — the door: an agent's Lisp is checked before it runs.
#
#   Without a desktop, door.lisp in plain SBCL: what an agent is told to
#   ask passes (reads of the desktop, moves and switches, the registry's
#   :agent commands, the user's own file, local variables set in a loop);
#   what runs a program, touches a file, evaluates text, reaches the system,
#   defines or changes code, sets a global or waits is held, with why, and
#   the forms that hide one (a quoted name to mapcar, a function in a
#   variable, a default in a lambda list, #.) are caught too. The held
#   forms queue: ten at most, run or dropped, a refused one reported.
#   vikix eval --whose: an agent above the shell is an agent's, a script of
#   Vikix's between is Vikix's, and the door only at the desktop's port.
#   bin/vikix-eval's list of agents is bin/vikix-agents'.
#
#   With a hidden StumpWM (Xvfb, Vikix's StumpWM; skipped without): vikix
#   eval --door holds a shell command (nothing runs, exit 3, the errors
#   folder has it, the desktop was told), runs a read; vikix door lists,
#   runs and drops; the MCP eval tool goes through the door and the other
#   tools don't; a desktop from before the door refuses an agent's form.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"       # check, fail, and the hidden desktop for the end
command -v sbcl >/dev/null || { echo "door: needs sbcl; skipped"; exit 0; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

# --- the two lists of agents are one ----------------------------------------------------
a=$(sed -n 's/^PROGRAMS = (\(.*\))$/\1/p' "$here/lib/agents/common.py" | tr -d ' "')
b=$(sed -n 's/^AGENTS = (\(.*\))$/\1/p' "$here/bin/vikix-eval" | tr -d ' "')
check "bin/vikix-eval's agents ($b) should be bin/vikix-agents' ($a)" test "$a" = "$b"

# --- the walker, without a desktop ------------------------------------------------------
home="$t/home"; mkdir -p "$home/.config/vikix" "$home/.local/state/vikix"
printf 'my-thing   # a function of my user.lisp\n' > "$home/.config/vikix/door"
cat > "$t/door-test.lisp" <<LISP
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
;; What errors.lisp and StumpWM give the file on the desktop.
(defvar *shell* '())
(defvar *reports* '())
(defmacro defcommand (name args interactive &body body) (declare (ignore interactive)) \`(defun ,name ,args ,@body))
(defun message (fmt &rest args) (apply #'format t fmt args))
(defun vikix-ask (q choices) (declare (ignore q choices)) nil)
(defun vikix-one-line (thing &optional (max 160))
  (let ((text (substitute #\\Space #\\Newline (princ-to-string thing))))
    (if (> (length text) max) (concatenate 'string (subseq text 0 (- max 3)) "...") text)))
(defun vikix-shell-quote (s) (format nil "'~a'" s))
(defun run-shell-command (cmd) (push cmd *shell*))
(defun vikix-error-report (condition where) (push (format nil "~a ~a" condition where) *reports*))
(defun vikix-agent-commands () '((:name titlebars :run "vikix-titlebars" :agent t) (:name gaps :run "vikix-gaps toggle" :agent t)))
(defun vikix-eval-forms (text) (format t "ran: ~a" text) :ok)
(defun run-shell-command-test () nil)
(sb-ext:unlock-package :cl)   ; the stand-ins above only
(load "$here/config/stumpwm/vikix/door.lisp")
(defvar *fails* 0)
(defun fail (fmt &rest args) (incf *fails*) (format t "FAIL: ~?~%" fmt args))
(defun passes (text)
  (let ((answer (vikix-door-check-text text)))
    (unless (and (>= (length answer) 2) (string= answer "ok" :end1 2))
      (fail "should pass: ~a~%      ~a" text answer))))
(defun held (text &rest words)
  (let ((answer (vikix-door-check-text text)))
    (when (and (>= (length answer) 2) (string= answer "ok" :end1 2))
      (fail "should be held: ~a" text))
    (dolist (word words)
      (unless (search word answer)
        (fail "~a: the reason should say ~s, says:~%      ~a" text word answer)))))

;; What an agent is told to ask.
(passes "(+ 1 2)")
(passes "(mapcar (function group-name) (screen-groups (current-screen)))")
(passes "(mapcar #'window-class (group-windows (current-group)))")
(passes "(lookup-key *top-map* (kbd \\"s-a\\"))")
(passes "(message \\"Hello\\")")
(passes "(loop for w in (group-windows (current-group)) collect (window-title w))")
(passes "(loop for x in (list 1 2) collect x into out finally (return out))")
(passes "(let ((n 0)) (dolist (w (group-windows (current-group))) (incf n)) n)")
(passes "(let ((x 1)) (setq x 2) (push 3 x) x)")
(passes "(gselect 2) (vikix-apply-theme :vikix-light)")
(passes "(vikix-titlebars)")                 ; the registry's :agent t
(passes "(vikix-gaps)")                      ; its first word
(passes "(my-thing 1)")                      ; ~/.config/vikix/door
(passes "(format nil \\"~a\\" (length (screen-windows (current-screen))))")
(passes "(cond ((null (current-window)) \\"none\\") (t (window-title (current-window))))")
(passes "(case 1 (1 \\"one\\") (t \\"more\\"))")
(passes "(handler-case (/ 1 0) (error (e) (princ-to-string e)))")
(passes "(multiple-value-bind (a b) (floor 7 2) (list a b))")
(passes "(destructuring-bind (a &optional (b 2)) '(1) (+ a b))")
(passes "(funcall #'gselect 1) (apply 'gselect '(1))")
(passes "((lambda (x) (* x 2)) 3)")
(passes "(loadrc)")
(passes "(vikix-rules-lines) (vikix-door-check-text \\"(+ 1 2)\\")")
(passes "(with-output-to-string (s) (princ 1 s))")
(passes "(do ((i 0 (1+ i))) ((= i 3) i))")
(passes "(block b (return-from b 1))")
(passes "'(run a program)")                  ; data: no such name
(passes "")

;; What is held, and the reason's words.
(held "(run-shell-command \\"ls\\")" "run-shell-command" "runs a program")
(held "(sb-ext:run-program \\"/bin/sh\\" nil)" "SB-EXT" "reaches the system")
(held "(sb-thread:make-thread (lambda ()))" "SB-THREAD")
(held "(with-open-file (f \\"~/.slime-secret\\") (read-line f))" "with-open-file" "touches a file")
(held "(open \\"/etc/passwd\\")" "open")
(held "(load \\"/tmp/x.lisp\\")" "load")
(held "(require :sb-posix)" "require")
(held "(eval (read-from-string \\"(+ 1 2)\\"))" "eval" "can't see")
(held "(funcall f 1)" "funcall" "can't see")
(held "(apply (first (list #'gselect)) (list 1))" "apply")
(held "(let ((f #'run-shell-command)) (funcall f \\"ls\\"))" "run-shell-command")
(held "(mapcar 'run-shell-command (list \\"ls\\"))" "run-shell-command")
(held "(mapcar #'run-shell-command (list \\"ls\\"))" "run-shell-command")
(held "(lambda (&key (x (run-shell-command \\"ls\\"))) x)" "run-shell-command")
(held "(dolist (c (list \\"a\\")) (run-shell-command c))" "run-shell-command")
(held "(progn (gselect 1) (run-shell-command \\"ls\\"))" "run-shell-command")
(held "(gselect 1) (run-shell-command \\"ls\\")" "run-shell-command")
(held "(quit)" "quit" "reaches the system")
(held "(vikix-swank-restart 4004)" "vikix-swank-restart")
(held "(vikix-door-run (first *vikix-door-held*))" "vikix-door-run")
(held "(defun move-window (&rest r) nil)" "defun" "defines or changes code")
(held "(add-hook *new-window-hook* 'foo)" "add-hook")
(held "(when-window (:class \\"x\\") (workspace 2))" "when-window")
(held "(setf *vikix-rules* nil)" "sets *vikix-rules*")
(held "(setf (symbol-function 'gselect) #'identity)" "changes (symbol-function ...)")
(held "(push 1 *things*)" "sets *things*")
(held "(incf *count*)" "sets *count*")
(held "(loop for x in (list 1) do (setf y x))" "sets y")
(held "(sleep 10)" "sleep" "waits")
(held "(read-line)" "read-line" "waits")
(held "(some-unknown-fn 1)" "some-unknown-fn" "isn't on the door's list")
(held "(flet ((f () (gselect 1))) (f))" "flet")
(held "(a . b)" "proper list")
(held "#.(run-shell-command \\"ls\\")" "can't be read")

;; The queue: held and told, ten at most, run or dropped, a refused one reported.
(setf *vikix-door-held* '() *vikix-door-count* 0)
(let ((id (vikix-door-hold "(run-shell-command \\"ls\\")" "it calls run-shell-command, which runs a program" :refused "claude 12")))
  (unless (eql id 1) (fail "the first held form should be 1, is ~a" id))
  (unless (= (length *shell*) 1) (fail "holding should tell the desktop (notify-send), told ~d" (length *shell*)))
  (unless (search "notify-send" (first *shell*)) (fail "the telling should be a notify-send: ~a" (first *shell*)))
  (unless (= (length *reports*) 1) (fail "a refused form should be reported to the errors folder"))
  (unless (search "claude 12" (first *reports*)) (fail "the report should name the agent: ~a" (first *reports*))))
(vikix-door-hold "(defun f () 1)" "it calls defun" :held "codex 13")
(unless (= (length *reports*) 1) (fail "a merely held form should not be reported"))
(let ((lines (vikix-door-lines)))
  (unless (and (search "claude 12" lines) (search "codex 13" lines) (= 2 (count #\\Newline (format nil "~a~%" lines))))
    (fail "vikix-door-lines should have the two: ~s" lines)))
(dotimes (i 8) (vikix-door-hold (format nil "(f ~d)" i) "why" :held "x"))
(unless (= (length *vikix-door-held*) 10) (fail "ten should wait, ~d do" (length *vikix-door-held*)))
(when (vikix-door-hold "(f 99)" "why" :held "x") (fail "an eleventh should be refused, not kept"))
(let ((again (vikix-door-hold "(defun f () 1)" "again" :held "codex 13")))
  (when again (fail "the same text again replaces its entry, so the door is still full")))
(let ((out (vikix-door-cli "run" "1")))
  (unless (search "ran: (run-shell-command" out) (fail "run 1 should run it as the user: ~a" out))
  (when (vikix-door-held 1) (fail "a run form should be forgotten")))
(let ((out (vikix-door-cli "drop" "2")))
  (unless (search "dropped 2" out) (fail "drop 2: ~a" out))
  (when (vikix-door-held 2) (fail "a dropped form should be forgotten")))
(unless (search "error: nothing is held as 7777" (vikix-door-cli "run" "7777")) (fail "run of nothing should say so"))
(let ((names (vikix-door-cli "allowed")))
  (dolist (name '("gselect" "window-title" "vikix-titlebars" "my-thing" "message"))
    (unless (search (format nil "~%~a~%" name) (format nil "~%~a~%" names)) (fail "allowed should list ~a" name)))
  (when (search "run-shell-command" names) (fail "allowed should not list run-shell-command")))
(vikix-door)   ; the command, with no screen: a message, no error
(format t "~d checks failed~%" *fails*)
(sb-ext:exit :code (if (zerop *fails*) 0 1))
LISP
out=$(cd "$t" && HOME=$home timeout --kill-after=5s 120s sbcl --non-interactive --no-userinit --load "$t/door-test.lisp" 2>&1) || { echo "$out" | grep -v '^; ' | tail -30; fail=1; }
echo "$out" | grep '^FAIL' && fail=1
echo "$out" | grep -q '^0 checks failed' || { echo "FAIL: the walker's checks didn't all pass"; echo "$out" | grep -v '^; ' | tail -15; fail=1; }

# --- whose: an agent above, a script of Vikix's between, the port ------------------------
mkdir -p "$t/bin"
cp /bin/sh "$t/bin/claude"; cp /bin/sh "$t/bin/vikix-theme"; cp /bin/sh "$t/bin/other"
# "; true" keeps each shell alive instead of exec'ing the next, so it is in the tree.
w=$("$t/bin/claude" -c "VIKIX_SWANK_PORT=4004 python3 '$here/bin/vikix-eval' --whose; true")
check "under claude, at the desktop's port: an agent's, the door stands ($w)" grep -q "^an agent's: claude [0-9]*; the door stands" <<<"$w"
w=$("$t/bin/claude" -c "VIKIX_SWANK_PORT=9 python3 '$here/bin/vikix-eval' --whose; true")
check "under claude, on a test's port: an agent's, the door off ($w)" grep -q "^an agent's: claude [0-9]*; the door is off" <<<"$w"
w=$("$t/bin/claude" -c "'$t/bin/vikix-theme' -c \"VIKIX_SWANK_PORT=4004 python3 '$here/bin/vikix-eval' --whose; true\"; true")
check "a script of Vikix's between: Vikix's own ($w)" grep -q "^yours (sent by vikix-theme)" <<<"$w"
w=$("$t/bin/claude" -c "'$t/bin/other' -c \"VIKIX_SWANK_PORT=4004 python3 '$here/bin/vikix-eval' --whose; true\"; true")
check "another program between: still the agent's ($w)" grep -q "^an agent's: claude" <<<"$w"
# This test may itself run under an agent: the walk is started at init for this one.
w=$(VIKIX_EVAL_PARENT=1 VIKIX_SWANK_PORT=4004 python3 "$here/bin/vikix-eval" --whose)
check "no agent above: yours ($w)" grep -q "^yours (no agent above" <<<"$w"

# --- the whole road, on a hidden desktop ------------------------------------------------------
if [ -n "${VIKIX_DOOR_NO_SCREEN:-}" ]; then
  [ "$fail" = 0 ] && echo "door: ok (no screen)"; exit "$fail"
fi
t0=$t
wm_setup door                   # a folder of its own, and the trap for it
trap 'wm_cleanup; rm -rf "$t0"' EXIT
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s|" "$@" >> "%s/notified"; echo >> "%s/notified"\n' "$t" "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/notify-send"
export PATH="$t/bin:$PATH"
wm_start
# VIKIX_EVAL_PARENT=1: this test may itself run under an agent, which --door would name as the sender.
agent() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_EVAL_PARENT=1 python3 "$here/bin/vikix-eval" --door "$1" 2>&1; }
door() { HOME=$home VIKIX_SWANK_PORT=$port bash "$here/bin/vikix-door" "$@" 2>&1; }

out=$(agent "(run-shell-command \"touch $t/ran\")") && st=0 || st=$?
check "a shell command from an agent is held, exit 3 (got $st: $out)" test "$st" = 3
check "and the agent is told why ($out)" grep -q "^held 1: (run-shell-command.*" <<<"$out"
check "with the reason" grep -q "because it calls run-shell-command, which runs a program" <<<"$out"
sleep 0.5
check "nothing of it ran" test ! -e "$t/ran"
check "the desktop was told (notify-send)" grep -q "sent Lisp the door held" "$t/notified"
check "the attempt is in the errors folder" grep -lq "door refused" "$home"/.local/state/vikix/errors/*.txt
out=$(agent "(princ (+ 1 2))") && st=0 || st=$?
check "a read from an agent runs (got $st: $out)" test "$st" = 0
check "and answers" grep -q '^3$' <<<"$out"
out=$(agent "(setf *vikix-rules* nil)") && st=0 || st=$?
check "setting a global is held (got $st)" test "$st" = 3
check "vikix eval refuses an agent's #. at reading" grep -q "can't be read\|error:" <<<"$(agent '#.(run-shell-command "ls")')"
out=$(door)
check "vikix door lists the held forms ($out)" grep -q "^1 .*a test" <<<"$out"
check "with the form" grep -q "run-shell-command" <<<"$out"
out=$(door run 1)
check "vikix door run 1 runs it as the user ($out)" grep -q "^ran 1:" <<<"$out"
for _ in $(seq 1 20); do [ -e "$t/ran" ] && break; sleep 0.25; done
check "and it ran" test -e "$t/ran"
out=$(door drop 2)
check "vikix door drop 2 ($out)" grep -q "^dropped 2" <<<"$out"
check "the list is empty again" grep -q "^Nothing waits" <<<"$(door)"
check "vikix door check says ok" grep -q "^ok" <<<"$(door check '(gselect 1)')"
door check '(run-shell-command "ls")' >/dev/null && st=0 || st=$?
check "vikix door check exits 3 for a held form (got $st)" test "$st" = 3
check "vikix door allowed lists gselect" grep -qx gselect <<<"$(door allowed)"

# The MCP server: eval goes through the door, the other tools don't.
call() {
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" |
    HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-mcp" serve --allow-eval |
    python3 -c 'import json,sys; r=json.loads(sys.stdin.readline())["result"]; print(("ERROR: " if r["isError"] else "") + r["content"][0]["text"])'
}
evalcall() { call eval "$(python3 -c 'import json,sys; print(json.dumps({"form": sys.argv[1]}))' "$1")"; }
out=$(evalcall "(run-shell-command \"touch $t/ran2\")")
check "the MCP eval tool's shell command is held ($out)" grep -q "^ERROR: held" <<<"$out"
check "and not run" test ! -e "$t/ran2"
out=$(evalcall '(+ 2 2)')
check "the MCP eval tool's sum runs ($out)" grep -q "=> 4" <<<"$out"
out=$(call desktop '{}')
check "the desktop tool still answers (its forms are Vikix's) ($out)" grep -qv "^ERROR" <<<"$out"

# A desktop from before the door: an agent's form isn't run unchecked.
ask "(fmakunbound 'vikix-door-check)" >/dev/null
out=$(agent "(princ 1)") && st=0 || st=$?
check "without the door, an agent's form is refused, exit 2 (got $st: $out)" test "$st" = 2
check "and told to reload" grep -q "before the door" <<<"$out"

wm_report door "the door: an agent's Lisp checked, held, run or dropped"
exit "$fail"
