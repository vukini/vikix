#!/usr/bin/env bash
# tests/swank.sh — Swank's password, with a real Swank.
#
#   With ~/.slime-secret, Swank runs nothing for a client that doesn't send
#   it first: not a raw connection (what the Windows VM could make through
#   passt's gateway), not a wrong password. vikix eval sends it, and works.
#   40-config makes the file once (random, 600) and keeps one you have.
#   And the wrong clients don't take Swank down (swank-guard.lisp): after
#   them, vikix eval still gets in. A Swank started before the guard (an
#   older StumpWM) is restarted, guarded, by the next reload of swank.lisp.
#
# A stand-in StumpWM: plain SBCL with Quicklisp's Swank and a
# vikix-eval-for-agent that writes a file when it runs, so "nothing ran"
# can be seen. Needs sbcl and Quicklisp (VIKIX_QUICKLISP, default ~/quicklisp).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}/setup.lisp
command -v sbcl >/dev/null && [ -f "$ql" ] || { echo "swank: needs sbcl and Quicklisp; skipped"; exit 0; }
t=$(mktemp -d)
server=
# SBCL with Swank's threads can outlive a TERM: KILL after it, or the
# server stays on after the test (one did, for minutes).
trap '[ -n "$server" ] && { kill "$server"; sleep 0.2; kill -9 "$server"; } 2>/dev/null || true; rm -rf "$t"' EXIT
export HOME="$t/home"
mkdir -p "$HOME"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# --- 40-config makes the password, once --------------------------------------------
bash "$here/install/40-config.sh" >/dev/null 2>&1 || true
check "40-config didn't make ~/.slime-secret" test -s "$HOME/.slime-secret"
check "the password file should be 600, is $(stat -c %a "$HOME/.slime-secret" 2>/dev/null)" test "$(stat -c %a "$HOME/.slime-secret" 2>/dev/null)" = 600
first=$(sha1sum < "$HOME/.slime-secret")
bash "$here/install/40-config.sh" >/dev/null 2>&1 || true
check "a second 40-config changed the password" test "$(sha1sum < "$HOME/.slime-secret")" = "$first"

# --- a real Swank that asks for it ---------------------------------------------------
port=$((40000 + RANDOM % 20000))
marker="$t/ran"
# The real swank.lisp, on this test's port (never 4004, the desktop's).
sed "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" \
  "$here/config/stumpwm/vikix/swank.lisp" > "$t/swank.lisp"
grep -q "vikix-swank-port\* $port" "$t/swank.lisp" || { echo "FAIL: couldn't move swank.lisp off port 4004"; exit 1; }
cat > "$t/server.lisp" <<EOF
(load "$ql")
(let ((*standard-output* (make-broadcast-stream))) (ql:quickload :swank :silent t))
(setf swank::*log-output* (make-broadcast-stream))
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defun message (&rest args) (declare (ignore args)))
;; An old StumpWM: its Swank started before swank-guard.lisp existed.
(swank:create-server :port $port :dont-close t)
(defvar *vikix-swank-started* t)
(defvar *listener-before* (third (first swank::*servers*)))
;; Then a reload loads the new files: the guard, and swank.lisp.
(load "$here/config/stumpwm/vikix/swank-guard.lisp")
(load "$t/swank.lisp")
;; A stand-in for the evaluator: it notes the text, and runs it.
(defun vikix-eval-for-agent (text)
  (with-open-file (o "$marker" :direction :output :if-exists :append :if-does-not-exist :create)
    (write-line text o))
  (format t "=> ~s~%" (eval (read-from-string text)))
  :ok)
(with-open-file (o "$t/ready" :direction :output :if-exists :supersede) (write-line "ready" o))
(loop (sleep 1))
EOF
# --non-interactive: no debugger, as a crash would be. A wrong password
# that took this Lisp down would leave vikix eval below with nothing to reach.
sbcl --non-interactive --no-userinit --load "$t/server.lisp" >"$t/server.log" 2>&1 &
server=$!
# Ready once all of server.lisp has run, not when the port first answers:
# that's the old server, whose accept thread the no-password client below
# stops (the bug the guard is for); on a busy machine, swank.lisp hadn't
# replaced it yet, and vikix eval timed out on it.
for _ in $(seq 300); do [ -e "$t/ready" ] && break; kill -0 "$server" 2>/dev/null || break; sleep 0.2; done
[ -e "$t/ready" ] || { echo "FAIL: the test's Swank didn't start:"; tail -20 "$t/server.log"; exit 1; }

evalw() { VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "$@"; }

# A raw client, as from the VM: a request with no password first.
python3 - "$port" <<'PY' || true
import socket, sys
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=5)
msg = b'(:emacs-rex (swank:eval-and-grab-output "(stumpwm::vikix-eval-for-agent \\"(from the vm)\\")") "STUMPWM" t 1)'
s.sendall(b"%06x" % len(msg) + msg)
try: s.recv(100)
except Exception: pass
s.close()
PY
sleep 0.5
check "a client without the password got code run" test ! -e "$marker"

# A client with a password of its own (its own home: the server reads the
# real one from $HOME at each connection).
mkdir -p "$t/other"
echo wrong > "$t/other/.slime-secret"
HOME="$t/other" evalw '(+ 1 2)' >/dev/null 2>&1 && { echo "FAIL: vikix eval with a wrong password worked"; fail=1; }
check "a wrong password got code run" test ! -e "$marker"

# A client that connects and says nothing, and stays: Swank reads the
# password in its one accept thread, so without a time limit on that
# (SBCL has none of its own) nobody else got in until it left.
python3 - "$port" <<'PY' &
import socket, sys, time
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
time.sleep(30)
PY
silent=$!
sleep 0.5
start=$SECONDS
out=$(timeout 20 bash -c "$(declare -f evalw); here='$here' port=$port evalw '(+ 1 2)'" 2>&1) \
  || { echo "FAIL: a silent client kept vikix eval out: $out"; fail=1; }
check "vikix eval waited $((SECONDS - start)) s behind a silent client" test $((SECONDS - start)) -le 10
kill "$silent" 2>/dev/null || true
rm -f "$marker"

out=$(evalw '(+ 1 2)' 2>&1) || { echo "FAIL: vikix eval with the password didn't work: $out"; tail -5 "$t/server.log"; fail=1; }
check "vikix eval with the password didn't run the form" grep -qF '(+ 1 2)' "$marker"
# The reload restarted the old, unguarded server once: a stuck accept
# thread (a wrong password before the guard) is replaced.
out=$(evalw '(list *vikix-swank-started* (eq (third (first swank::*servers*)) *listener-before*))' 2>&1)
check "a reload should restart an unguarded Swank once, guarded: $out" grep -q '=> (:GUARDED NIL)' <<<"$out"

[ "$fail" = 0 ] && echo "swank: without ~/.slime-secret's password nothing runs; vikix eval sends it; 40-config makes it once, 600"
exit "$fail"
