#!/usr/bin/env bash
# tests/nyxt.sh — Vikix's part of Nyxt, config/nyxt/vikix.lisp.
# The colours: it reads the palette `vikix theme` writes (only #rrggbb
# values, comments and junk left out), builds a theme from it (nil without
# bg or fg), and `vikix theme` asks a running Nyxt, and only a running one,
# to read it again. Swank: it starts only with a password in ~/.slime-secret,
# on 127.0.0.1, once, not when switched off, and a port that's taken doesn't
# stop Nyxt; a client that sends no password is refused after the time
# limit. The starter config.lisp loads the file from where 40-config and
# vikix lisp-apps setup link it.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY   # nothing here may open a window on the desktop
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# --- The Lisp, with stand-ins for the parts of Nyxt it uses ------------------
if command -v sbcl >/dev/null 2>&1; then
  cat > "$t/palette" <<'P'
# Written by `vikix theme`
bg=#1e1e2e
fg=#cdd6f4
dim=#585b70
sel=#45475a
accent=#89b4fa
alert=#f38ba8
color2=#a6e3a1
color5=#f5c2e7
subtle=not-a-colour
=#000000
#bg=#ffffff

P
  printf 'fg=#cdd6f4\n' > "$t/half"
  cat > "$t/stubs.lisp" <<'L'
(require :asdf)
(defpackage :theme (:use :cl) (:export #:theme))
(in-package :theme)
(defclass theme () ((initargs :initform nil :accessor initargs)))
(defmethod shared-initialize :around ((th theme) slots &rest args &key &allow-other-keys)
  (declare (ignore args)) (call-next-method th slots))
(defmethod initialize-instance :after ((th theme) &rest args &key &allow-other-keys) (setf (initargs th) args))
(defpackage :closer-mop (:use)
  (:import-from :sb-mop #:class-slots #:slot-definition-name #:slot-definition-initfunction)
  (:export #:class-slots #:slot-definition-name #:slot-definition-initfunction))
(defpackage :nyxt (:use :cl)
  (:export #:browser #:*browser* #:theme #:window-list #:status-buffer
           #:customize-instance #:define-configuration #:remote-execution-p))
(in-package :nyxt)
(defclass browser () ())
(defvar *browser* nil)
(defgeneric customize-instance (object &key))
(defmethod customize-instance ((object t) &key) nil)
(defmacro define-configuration (&rest r) (declare (ignore r)) nil)
(defun window-list () nil)
(defun status-buffer (w) (declare (ignore w)) nil)
(defun print-status (w) (declare (ignore w)) nil)
(defgeneric theme (b))
(defpackage :nyxt-user (:use :cl :nyxt))
;; Swank: create-server records how it was called; the password check
;; waits for ever, as Swank's does for a client that sends nothing.
(defpackage :swank (:use :cl) (:export #:create-server))
(in-package :swank)
(defvar *loopback-interface* "localhost")
(defvar *calls* nil)
(defvar *fail* nil)
(defun create-server (&rest args)
  (when *fail* (error "Address in use"))
  (push (list* :interface *loopback-interface* args) *calls*))
(defun authenticate-client (stream) (declare (ignore stream)) (sleep 30))
(defun accept-connections (&rest args) (declare (ignore args)) (error "boom"))
(defpackage :log (:use) (:export #:warn))
(defvar log::*said* nil)
(defmacro log:warn (fmt &rest args) `(push (format nil ,fmt ,@args) log::*said*))
L
  cat > "$t/check.lisp" <<L
(load "$t/stubs.lisp")
(load "$here/config/nyxt/vikix.lisp")
(in-package :nyxt-user)
(defun arg (th key) (getf (theme::initargs th) key))
(let* ((pal (vikix-palette #p"$t/palette"))
       (th (vikix-make-theme pal)))
  (format t "keys ~{~a~^ ~}~%" (mapcar #'car pal))
  (format t "bg ~a~%" (arg th :background-color))
  (format t "text ~a~%" (arg th :text-color))
  (format t "contrast ~a~%" (arg th :contrast-text-color))
  (format t "action ~a~%" (arg th :action-color))
  (format t "warning ~a~%" (arg th :warning-color))
  (format t "subtle ~a~%" (arg th :text-color-))
  (format t "half ~a~%" (vikix-make-theme (vikix-palette #p"$t/half")))
  (format t "none ~a~%" (vikix-palette #p"$t/no-such-file")))
;; Swank. HOME is $t/home, without .slime-secret at first.
(vikix-start-swank)
(format t "nosecret calls ~a~%" (length swank::*calls*))
(format t "nosecret warned ~a~%" (and (search "slime-secret" (first log::*said*)) t))
(with-open-file (o (merge-pathnames ".slime-secret" (user-homedir-pathname))
                   :direction :output :if-exists :supersede)
  (write-line "test-secret" o))
(vikix-start-swank)
(vikix-start-swank)
(format t "started calls ~a~%" (length swank::*calls*))
(format t "started args ~s~%" (first swank::*calls*))
(let ((start (get-internal-real-time)))
  (setf *vikix-swank-auth-seconds* 1)
  (format t "silent client ~a~%"
          (handler-case (progn (swank::authenticate-client (make-string-output-stream)) :let-in)
            (error () :refused)))
  (format t "silent seconds ~a~%" (round (- (get-internal-real-time) start) internal-time-units-per-second)))
(format t "accept loop survives ~a~%" (handler-case (progn (swank::accept-connections) :ok) (error () :died)))
(setf *vikix-swank-started* nil *vikix-swank-port* nil swank::*calls* nil)
(vikix-start-swank)
(format t "off calls ~a~%" (length swank::*calls*))
(setf *vikix-swank-port* 4006 swank::*fail* t)
(format t "taken port ~a~%" (handler-case (progn (vikix-start-swank) :nyxt-goes-on) (error () :crashed)))
(format t "taken warned ~a~%" (and (search "Address in use" (first log::*said*)) t))
L
  mkdir -p "$t/home"
  out=$(HOME="$t/home" sbcl --noinform --no-sysinit --no-userinit --non-interactive --load "$t/check.lisp" 2>&1) || {
    echo "FAIL: vikix.lisp doesn't load against the stand-ins:"; echo "$out" | grep -vE "^ *[0-9]+: |^;" | tail -15; fail=1; }
  check "only key=#rrggbb lines are read" grep -qx 'keys bg fg dim sel accent alert color2 color5' <<<"$out"
  check "the background is bg" grep -qx 'bg #1e1e2e' <<<"$out"
  check "the text is fg" grep -qx 'text #cdd6f4' <<<"$out"
  check "text on near-fg colours is bg" grep -qx 'contrast #1e1e2e' <<<"$out"
  check "the selected suggestion is sel (Nyxt keeps its text fg)" grep -qx 'action #45475a' <<<"$out"
  check "warnings are alert" grep -qx 'warning #f38ba8' <<<"$out"
  check "a colour that isn't one falls back to fg" grep -qx 'subtle #cdd6f4' <<<"$out"
  check "no theme without bg" grep -qx 'half NIL' <<<"$out"
  check "no palette without the file" grep -qx 'none NIL' <<<"$out"
  check "no Swank without ~/.slime-secret" grep -qx 'nosecret calls 0' <<<"$out"
  check "and Nyxt's log says why" grep -qx 'nosecret warned T' <<<"$out"
  check "Swank starts once with the password, however often it's asked" grep -qx 'started calls 1' <<<"$out"
  check "on 127.0.0.1, port 4006, kept open" grep -qx 'started args (:INTERFACE "127.0.0.1" :PORT 4006 :DONT-CLOSE T)' <<<"$out"
  check "a client that sends no password is refused" grep -qx 'silent client REFUSED' <<<"$out"
  check "after the time limit, not Swank's endless wait" grep -qx 'silent seconds 1' <<<"$out"
  check "a refused client doesn't end the accept loop" grep -qx 'accept loop survives OK' <<<"$out"
  check "(setf *vikix-swank-port* nil) means no Swank" grep -qx 'off calls 0' <<<"$out"
  check "a taken port doesn't stop Nyxt" grep -qx 'taken port NYXT-GOES-ON' <<<"$out"
  check "and is logged" grep -qx 'taken warned T' <<<"$out"
else
  echo "nyxt: no sbcl, the Lisp part skipped"
fi

# --- vikix theme asks a running Nyxt ----------------------------------------
mkdir -p "$t/bin"
printf '#!/bin/sh\nfor a in "$@"; do echo "$a"; done >> "%s/calls"\n' "$t" > "$t/bin/nyxt"
printf '#!/bin/sh\n[ -e "%s/running" ]\n' "$t" > "$t/bin/pgrep"
chmod +x "$t/bin/nyxt" "$t/bin/pgrep"
# Only the function: all of `vikix theme` would repaint the live desktop.
fn=$(sed -n '/^theme_nyxt() {/,/^}/p' "$here/bin/vikix")
check "bin/vikix has theme_nyxt" test -n "$fn"
check "vikix theme calls theme_nyxt" grep -q '^    theme_nyxt$' "$here/bin/vikix"
PATH="$t/bin:$PATH" bash -c "$fn; theme_nyxt"
check "no Nyxt running, nothing sent" test ! -e "$t/calls"
touch "$t/running"
PATH="$t/bin:$PATH" bash -c "$fn; theme_nyxt"
check "a running Nyxt is sent the call over its socket" grep -qx -- '--remote' "$t/calls"
check "and isn't left reading stdin" grep -qx -- '--quit' "$t/calls"
check "the call is vikix-theme-apply, only where it's defined" grep -q 'VIKIX-THEME-APPLY' "$t/calls"

# --- The starter loads it from where it's linked -----------------------------
check "40-config links vikix.lisp where config.lisp looks" grep -q 'vikix/nyxt/vikix.lisp"$' "$here/install/40-config.sh"
check "lisp-apps setup links it there too" grep -q 'vikix/nyxt/vikix.lisp"$' "$here/bin/vikix-lisp-apps"
check "the starter config.lisp loads it" grep -q '"vikix/nyxt/vikix.lisp" (uiop:xdg-data-home)' "$here/config/nyxt/config.lisp"
check "the snapshots keep your Nyxt config" grep -q '^\.config/nyxt/config.lisp' "$here/config/yours.list"

[ "$fail" = 0 ] && echo "nyxt: ok"
exit "$fail"
