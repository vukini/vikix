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
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s|" "$@" >> "%s/notified"; echo >> "%s/notified"\n' "$t" "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/notify-send"
export PATH="$t/bin:$PATH"
wm_start

ev() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_SOCKET=$wm_socket VIKIX_EVAL_PARENT=1 python3 "$here/bin/vikix-eval" "$@" 2>&1; }   # VIKIX_EVAL_PARENT: the test may itself run under an agent
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
ev --socket '(progn (sleep 0.5) (princ :a))' > "$t/a" &
pa=$!
b=$(ev --socket '(princ :b)' | head -1)
wait "$pa"
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
