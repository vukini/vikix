#!/usr/bin/env bash
# tests/swank.sh — Swank's password, with a real Swank.
#
#   With ~/.slime-secret, Swank runs nothing for a client that doesn't send
#   it first: not a raw connection (what the Windows VM could make through
#   passt's gateway), not a wrong password. vikix eval sends it, and works.
#   40-config makes the file once (random, 600) and keeps one you have.
#   And the wrong clients don't take Swank down (swank-guard.lisp): after
#   them, vikix eval still gets in.
#
# A stand-in StumpWM: plain SBCL with Quicklisp's Swank and a
# vikix-eval-for-agent that writes a file when it runs, so "nothing ran"
# can be seen. Needs sbcl and Quicklisp (VIKIX_QUICKLISP, default ~/quicklisp).

set -euo pipefail
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}/setup.lisp
command -v sbcl >/dev/null && [ -f "$ql" ] || { echo "swank: needs sbcl and Quicklisp; skipped"; exit 0; }
t=$(mktemp -d)
server=
trap '[ -n "$server" ] && kill "$server" 2>/dev/null; rm -rf "$t"' EXIT
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
cat > "$t/server.lisp" <<EOF
(load "$ql")
(let ((*standard-output* (make-broadcast-stream))) (ql:quickload :swank :silent t))
(defpackage :stumpwm (:use :cl))
(load "$here/config/stumpwm/vikix/swank-guard.lisp")
(in-package :stumpwm)
(defun vikix-eval-for-agent (text)
  (with-open-file (o "$marker" :direction :output :if-exists :append :if-does-not-exist :create)
    (write-line text o))
  (format t "=> ran~%")
  :ok)
(setf swank::*log-output* (make-broadcast-stream))
(swank:create-server :port $port :dont-close t)
(loop (sleep 1))
EOF
# --non-interactive: no debugger, as a crash would be. A wrong password
# that took this Lisp down would leave vikix eval below with nothing to reach.
sbcl --non-interactive --no-userinit --load "$t/server.lisp" >"$t/server.log" 2>&1 &
server=$!
for _ in $(seq 100); do (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break; sleep 0.2; done

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

out=$(evalw '(+ 1 2)' 2>&1) || { echo "FAIL: vikix eval with the password didn't work: $out"; tail -5 "$t/server.log"; fail=1; }
check "vikix eval with the password didn't run the form" grep -qF '(+ 1 2)' "$marker"

[ "$fail" = 0 ] && echo "swank: without ~/.slime-secret's password nothing runs; vikix eval sends it; 40-config makes it once, 600"
exit "$fail"
