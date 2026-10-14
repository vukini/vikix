#!/usr/bin/env bash
# tests/socket.sh — Vikix's own socket beside Swank (socket.lisp), on a hidden StumpWM.
#
#   The socket is made where VIKIX_SOCKET says, 0600; vikix eval goes
#   through it (--socket: no Swank), with the same output and exit status as
#   over Swank; a form that only reads is answered while Super+m's menu is
#   open, and one that acts is given up on within the deadline and never
#   runs later; an agent's form passes the door there (held, exit 3; a read
#   of an agent's answered too); a client that sends rubbish, or nothing,
#   and two clients at once don't stop the server; with the socket file
#   gone, vikix eval falls back to Swank, --socket says so, and a reload
#   makes the socket anew; a test's StumpWM (VIKIX_SWANK_PORT set) never
#   serves the desktop's own path, and a test's vikix eval never asks it.
#   A read waits for preceding work when the main thread is runnable or
#   its observations are unknown; a sleeping thread still answers through
#   the client. A read is claimed once, including at its deadline.
#
# Needs what tests/lib/wm.sh needs (Xvfb, xdotool, alacritty, Vikix's
# StumpWM); skipped without.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup socket
# Reap every process this test starts, including clients interrupted by a
# failed check or a timeout. The shared helper supplies the X/WM cleanup.
operation=
socket_cleanup() {
  local code=$? p
  if [ -n "$operation" ]; then
    kill "$operation" 2>/dev/null || true
    wait "$operation" 2>/dev/null || true
  fi
  wm_cleanup
  for p in "${pids[@]}"; do
    if kill -0 "$p" 2>/dev/null; then
      kill -KILL "$p" 2>/dev/null || true
    fi
    wait "$p" 2>/dev/null || true
    if kill -0 "$p" 2>/dev/null; then echo "FAIL: socket process $p remains"; code=1; fi
  done
  exit "$code"
}
trap socket_cleanup EXIT
trap 'exit 124' TERM INT
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s|" "$@" >> "%s/notified"; echo >> "%s/notified"\n' "$t" "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/notify-send"
export PATH="$t/bin:$PATH"
wm_start

ev() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_SOCKET=$wm_socket VIKIX_EVAL_PARENT=1 python3 "$here/bin/vikix-eval" "$@" 2>&1; }   # VIKIX_EVAL_PARENT: the test may itself run under an agent
ev_start() {   # A direct child, so cleanup can stop and reap it by PID.
  local output=$1
  shift
  HOME=$home VIKIX_SWANK_PORT=$port VIKIX_SOCKET=$wm_socket VIKIX_EVAL_PARENT=1 python3 "$here/bin/vikix-eval" "$@" >"$output" 2>&1 &
  operation=$!
}
secs() { python3 -c 'import sys; print(float(sys.argv[2]) - float(sys.argv[1]))' "$1" "$2"; }
now() { date +%s.%N; }

# --- there, yours alone, and the same answers --------------------------------------------
check "the socket is there" test -S "$wm_socket"
check "and 600, is $(stat -c %a "$wm_socket")" test "$(stat -c %a "$wm_socket")" = 600
check "the desktop says it serves it: $(ask '(princ (vikix-socket-status))')" test "$(ask '(princ (vikix-socket-status))')" = "$wm_socket"
out=$(ev --socket '(princ (+ 1 2))') && st=0 || st=$?
check "a read over the socket (exit $st): $out" test "$st" = 0 -a "$(head -1 <<<"$out")" = 3
check "with its value after it" grep -q '^=> 3$' <<<"$out"
out=$(ev --socket '(car nil nil)') && st=0 || st=$?
check "an error over the socket is error: ..., exit 1 (got $st): $out" test "$st" = 1 && grep -q '^error:' <<<"$out"
out=$(ev --socket '(message "over the socket")') && st=0 || st=$?
check "an act goes to the main thread and runs (exit $st)" test "$st" = 0
check "and did: $(ask '(princ (first (first (screen-last-msg (current-screen)))))')" test "$(ask '(princ (first (first (screen-last-msg (current-screen)))))')" = "over the socket"
check "a read is answered by the main thread when it is free, so it follows what the desktop was doing: $(ev --socket '(princ (if (in-main-thread-p) :main :thread))')" grep -q '^MAIN' <<<"$(ev --socket '(princ (if (in-main-thread-p) :main :thread))')"
check "a sort is: $(ev --socket '(princ (if (in-main-thread-p) :main :thread)) (sort (list 2 1) (function <))')" grep -q '^MAIN' <<<"$(ev --socket '(princ (if (in-main-thread-p) :main :thread)) (sort (list 2 1) (function <))')"
check "the same over Swank still: $(ev --swank '(princ (+ 2 2))' | head -1)" test "$(ev --swank '(princ (+ 2 2))' | head -1)" = 4
check "several forms from stdin" test "$(printf '(princ 1)\n(princ 2)\n' | ev --socket | grep -v '^=>' | tr -d '\n')" = 12
check "the real /proc reader returns ticks and the main thread's running state" \
  grep -q '^(T R)' <<<"$(ev --socket '(multiple-value-bind (ticks state) (vikix-main-ticks) (princ (list (integerp ticks) state)))')"

# A main thread that has not received CPU time looks just like a menu to
# a ticks-only observer. Hold it in a known operation and stand in for
# /proc's observations, so this regression does not depend on host load.
ev --socket '(defvar *socket-test-ticks* (symbol-function (quote vikix-main-ticks))) (defvar *socket-test-ready* nil) (defvar *socket-test-observations* 0)' >/dev/null
for observation in '(values 0 #\R)' '(values nil nil)' '(values 0 nil)' \
                   '(values (incf *socket-test-observations*) #\S)' \
                   '(values 0 (if (oddp (incf *socket-test-observations*)) #\R #\S))'; do
  ev --socket "(setf *socket-test-ready* nil *socket-test-observations* 0 (symbol-function 'vikix-main-ticks) (lambda () $observation))" >/dev/null
  rm -f "$t/reading"
  ev_start "$t/operation" --socket "(with-open-file (s \"$t/reading\" :direction :output) (write-line \"started\" s)) (sleep 2) (setf *socket-test-ready* t)"
  for _ in $(seq 1 100); do [ -f "$t/reading" ] && break; sleep 0.02; done
  check "the preceding operation started" test -f "$t/reading"
  out=$(ev --socket '(princ (list *socket-test-ready* (if (in-main-thread-p) :main :thread)))') && st=0 || st=$?
  wait "$operation"
  operation=
  check "a read waits for the preceding operation with $observation: $out" grep -q '^(T MAIN)' <<<"$out"
  check "the ordered read succeeds" test "$st" = 0
  ev --socket '(setf (symbol-function (quote vikix-main-ticks)) *socket-test-ticks*)' >/dev/null
done

# If a read has begun in the main thread, falling back would execute it
# twice. Delay just that read, leaving real socket dispatch in place.
ev --socket '(defvar *socket-test-eval* (symbol-function (quote vikix-eval-forms)))
  (defvar *socket-test-count* 0)
  (setf (symbol-function (quote vikix-eval-forms))
        (lambda (text &rest args)
          (when (string= (string-trim (list #\Space #\Newline #\Return) text)
                         "(princ :socket-test-slow-read)")
            (incf *socket-test-count*) (sleep 1.2))
          (when (string= (string-trim (list #\Space #\Newline #\Return) text)
                         "(princ :socket-test-menu-read)")
            (incf *socket-test-count*))
          (apply *socket-test-eval* text args)))' >/dev/null
out=$(ev --socket '(princ :socket-test-slow-read)') && st=0 || st=$?
check "a read already running finishes normally: $out" test "$st" = 0
check "the main thread and fallback did not both run it" test "$(ask '(princ *socket-test-count*)')" = 1
ev --socket '(setf *vikix-eval-timeout* 0.4 *socket-test-count* 0)' >/dev/null
t0=$(now); out=$(ev --socket '(princ :socket-test-slow-read)') && st=0 || st=$?; took=$(secs "$t0" "$(now)")
check "an executing read has a deadline too: $out" test "$st" = 1
check "the deadline is bounded (${took}s)" python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 1 else 1)' "$took"
# Let the read finish before restoring the ordinary deadline.
sleep 1.3
ev --socket '(setf *vikix-eval-timeout* 10)' >/dev/null
check "a timed-out running read was not repeated" test "$(ask '(princ *socket-test-count*)')" = 1

# Unknown observations wait to the deadline, then a still-queued read
# falls back once. Closing the menu must not execute its cancelled copy.
ev --socket '(setf *vikix-eval-timeout* 0.4 *socket-test-count* 0
                  (symbol-function (quote vikix-main-ticks)) (lambda () (values nil nil)))' >/dev/null
key super+m
t0=$(now); out=$(ev --socket '(princ :socket-test-menu-read)') && st=0 || st=$?; took=$(secs "$t0" "$(now)")
check "an unknown observation falls back at the deadline: $out" test "$st" = 0
check "unknown is not mistaken for sleeping (${took}s)" python3 -c 'import sys; sys.exit(0 if 0.35 <= float(sys.argv[1]) < 1.5 else 1)' "$took"
key Escape
ev --socket '(setf *vikix-eval-timeout* 10 (symbol-function (quote vikix-main-ticks)) *socket-test-ticks*)' >/dev/null
check "the cancelled callback did not execute after the menu closed" test "$(ask '(princ *socket-test-count*)')" = 1
ev --socket '(setf (symbol-function (quote vikix-eval-forms)) *socket-test-eval*)' >/dev/null

# --- a read answered while a menu is open; an act given up on -----------------------------
ask '(setf *vikix-eval-timeout* 2)' >/dev/null
key super+m
sleep 0.5
t0=$(now); out=$(ev --socket '(princ (length (screen-groups (current-screen))))') && st=0 || st=$?; took=$(secs "$t0" "$(now)")
check "a read is answered with the menu open, in ${took}s (exit $st): $out" test "$st" = 0
check "and quickly" python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 1.5 else 1)' "$took"
check "by the client's thread, since the main one is busy: $(ev --socket '(princ (if (in-main-thread-p) :main :thread))')" grep -q '^THREAD' <<<"$(ev --socket '(princ (if (in-main-thread-p) :main :thread))')"
t0=$(now); out=$(ev --socket '(message "late act")') && st=0 || st=$?; took=$(secs "$t0" "$(now)")
check "an act with the menu open is given up on within the deadline, in ${took}s (exit $st): $out" test "$st" = 1
check "and says so" grep -q "did not answer within" <<<"$out"
key Escape
sleep 1
check "a form given up on never runs later: $(ask '(princ (first (first (screen-last-msg (current-screen)))))')" bash -c "[ \"\$(HOME=$home VIKIX_SWANK_PORT=$port VIKIX_SOCKET=$wm_socket python3 '$here/bin/vikix-eval' '(princ (first (first (screen-last-msg (current-screen)))))' 2>&1 | head -1)\" != 'late act' ]"
ask '(setf *vikix-eval-timeout* 10)' >/dev/null

# --- the door, in the thread --------------------------------------------------------------------
out=$(ev --socket --door "(run-shell-command \"touch $t/ran\")") && st=0 || st=$?
check "an agent's shell command is held over the socket, exit 3 (got $st): $out" test "$st" = 3 && grep -q '^held 1:' <<<"$out"
sleep 0.5
check "nothing of it ran" test ! -e "$t/ran"
check "the desktop was told" grep -q "sent Lisp the door held" "$t/notified"
out=$(ev --socket --door '(princ (length (group-windows (current-group))))') && st=0 || st=$?
check "an agent's read is answered (exit $st): $out" test "$st" = 0
out=$(ev --socket --door '(princ (if (in-main-thread-p) :main :thread)) (gnext)') && st=0 || st=$?
check "an agent's switch runs, in the main thread (exit $st): $out" test "$st" = 0 && grep -q '^MAIN' <<<"$out"

# --- clients that misbehave ------------------------------------------------------------------
python3 - "$wm_socket" <<'PY'
import socket, sys
for data in (b"", b"rubbish\n", b"eval me x\n(princ", b"\xff\xfe\n"):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(10); s.connect(sys.argv[1])
    s.sendall(data); s.shutdown(socket.SHUT_WR)
    while s.recv(4096): pass
    s.close()
PY
check "after rubbish the server still answers: $(ev --socket '(princ 7)' | head -1)" test "$(ev --socket '(princ 7)' | head -1)" = 7
ev_start "$t/a" --socket '(progn (sleep 0.5) (princ :a))'
b=$(ev --socket '(princ :b)' | head -1)
wait "$operation"
operation=
check "two clients at once: $b, $(head -1 "$t/a")" test "$b" = B -a "$(head -1 "$t/a")" = A
check "the server's thread is still the one" test "$(ask '(princ (if (sb-thread:thread-alive-p *vikix-socket-thread*) 1 0))')" = 1

# --- without the socket: Swank; and a reload makes it anew -------------------------------------
mv "$wm_socket" "$wm_socket.away"
out=$(ev '(princ 5)') && st=0 || st=$?
check "with the socket gone, vikix eval falls back to Swank (exit $st): $out" test "$st" = 0 -a "$(head -1 <<<"$out")" = 5
out=$(ev --socket '(princ 5)') && st=0 || st=$?
check "--socket with the socket gone says so, exit 2 (got $st): $out" test "$st" = 2 && grep -q "didn't answer" <<<"$out"
rm -f "$wm_socket.away"
ask '(loadrc)' >/dev/null 2>&1 || true
for _ in $(seq 1 40); do [ -S "$wm_socket" ] && break; sleep 0.25; done
check "a reload makes the socket anew" test -S "$wm_socket"
check "and it answers: $(ev --socket '(princ 8)' | head -1)" test "$(ev --socket '(princ 8)' | head -1)" = 8
check "one accepting thread, not two: $(ask '(princ (count "vikix-socket" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal)))')" \
  test "$(ask '(princ (count "vikix-socket" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal)))')" = 1

# --- a test's StumpWM never takes the desktop's path --------------------------------------------
check "a StumpWM with VIKIX_SWANK_PORT set and no VIKIX_SOCKET serves nothing: $(ask '(princ (let ((*vikix-socket-path* nil)) (sb-posix:unsetenv "VIKIX_SOCKET") (prog1 (vikix-socket-path) (sb-posix:setenv "VIKIX_SOCKET" "'"$wm_socket"'" 1))))')" \
  test "$(ask '(princ (let ((*vikix-socket-path* nil)) (sb-posix:unsetenv "VIKIX_SOCKET") (prog1 (vikix-socket-path) (sb-posix:setenv "VIKIX_SOCKET" "'"$wm_socket"'" 1))))')" = NIL
out=$(env -u VIKIX_SOCKET XDG_RUNTIME_DIR="$t" VIKIX_SWANK_PORT=9 python3 "$here/bin/vikix-eval" --socket '(princ 1)' 2>&1) && st=0 || st=$?
check "a test's vikix eval (VIKIX_SWANK_PORT set) never asks the runtime dir's socket (exit $st): $out" test "$st" = 2 && grep -q "no socket" <<<"$out"

wm_report socket "Vikix's socket: reads answered in a thread, menu open or not, acts in the main thread with the deadline, the door on the way, Swank behind it"
exit "$fail"
