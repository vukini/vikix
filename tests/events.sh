#!/usr/bin/env bash
# tests/events.sh — rules for a screen, a network, a drive and being away.
#
#   Without a screen (needs sbcl and Quicklisp's StumpWM; skipped without):
#   a mistake in such a rule is found as it is read; at a login what is
#   there counts as arriving, once; a reload sets nothing off; leaving and
#   joining again run the -gone rule and the rule, each with the name;
#   what can't be told sets nothing off; names by pattern, list and :any;
#   a rule new in a reload runs for what is there; one switched off still
#   looks; a pause runs nothing; a failing rule isn't tried at every look;
#   when-idle once, and again after a key; the network's name out of the
#   bar's line; the drives out of the kernel's mounts; vikix rules now; an
#   agent may propose them.
#
#   In a real StumpWM on a hidden screen (skipped without Xvfb and Vikix's
#   StumpWM): the network the bar reads sets a rule off at login, with a
#   name that isn't ASCII; a reload doesn't run it again; going offline
#   runs the -gone rule; the screen there is a screen arriving; vikix rules
#   now names them; vikix why says what set the rule off; the look is a
#   whole-second timer.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}
t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
said=()

# --- Without a screen -----------------------------------------------------------------
no_screen() {
  command -v sbcl >/dev/null && [ -f "$ql/setup.lisp" ] || { echo "(the part without a screen needs sbcl and Quicklisp; skipped here)"; return 0; }
  sbcl --noinform --non-interactive --load "$ql/setup.lisp" --eval '(ql:quickload :stumpwm :silent t)' >/dev/null 2>&1 || { echo "(the part without a screen needs Quicklisp's StumpWM; skipped here)"; return 0; }
  mkdir -p "$t/home" "$t/state" "$t/media"
  printf '%s\n' 'proc /proc proc rw 0 0' '/dev/nvme0n1p2 / ext4 rw 0 0' \
    "/dev/sdb1 $t/media/BACK\\040UP vfat rw 0 0" "/dev/sdc1 $t/media/Kindle vfat rw 0 0" \
    "/dev/sdc2 $t/media/Kindle/inner ext4 rw 0 0" "/dev/sdd1 /mnt/other ext4 rw 0 0" > "$t/mounts"
  cat > "$t/events-test.lisp" <<'LISP'
(in-package :stumpwm)
(defvar *fails* 0)
(defmacro check (name form)
  `(unless (ignore-errors ,form) (incf *fails*) (format t "FAIL: ~a~%" ,name)))
(defvar *ran* '())
(defvar *there* '())                      ; (:network ("VID") :screen (...) :drive (...)); a kind left out: unknown
(defvar *idle* 0)
(defvar *idle-reads* 0)
(setf *vikix-rules-things* (lambda (kind) (getf *there* kind :unknown))
      *vikix-rules-idle* (lambda () (incf *idle-reads*) *idle*))
(defun there (&rest plist) (setf *there* plist))
(defun look () (setf *ran* '()) (vikix-rules-look) (reverse *ran*))
(defun rule-of (words) (find-if (lambda (r) (search words (vikix-rule-text r))) *vikix-rules*))
(defun refused-p (form) (handler-case (progn (macroexpand-1 form) nil) (error () t)))

;; Mistakes, each found as the rule is read
(check "a name that is a number" (refused-p '(when-network 5 (say "x"))))
(check "a keyword that isn't :any" (refused-p '(when-screen :all (say "x"))))
(check "a pattern that can't be read" (refused-p '(when-drive (:like "(") (say "x"))))
(check "a rule that does nothing" (refused-p '(when-drive "BACKUP")))
(check "idle for no minutes" (refused-p '(when-idle 0 (say "x"))))
(check "idle for half a minute" (refused-p '(when-idle 0.5 (say "x"))))
(check "a verb misspelt" (refused-p '(when-network "VID" (notfy "x"))))

(defun rules ()
  (eval '(when-network "VID" (push (list :vid (rule-thing)) *ran*)))
  (eval '(when-network-gone "VID" (push (list :vid-gone (rule-thing)) *ran*)))
  (eval '(when-screen (:has "hdmi") (push (list :hdmi (rule-thing)) *ran*)))
  (eval '(when-screen-gone ("HDMI-1" "DP-2") (push (list :ext-gone (rule-thing)) *ran*)))
  (eval '(when-drive :any (push (list :drive (rule-thing)) *ran*)))
  (eval '(when-drive-gone (:like "^BACK") (push (list :backup-gone (rule-thing)) *ran*))))
(rules)

;; A login
(there :network '("VID") :screen '("eDP1") :drive '())
(check "at a login, what is there counts as arriving" (equal (look) '((:vid "VID"))))
(check "once" (null (look)))
(check "a reload sets nothing off" (progn (rules) (null (look))))
(check "a screen plugged in, by part of its name in any case"
       (progn (there :network '("VID") :screen '("eDP1" "HDMI-1") :drive '()) (equal (look) '((:hdmi "HDMI-1")))))
(check "taken away: the -gone rule, with its name"
       (progn (there :network '("VID") :screen '("eDP1") :drive '()) (equal (look) '((:ext-gone "HDMI-1")))))
(check "the network left" (progn (there :network '() :screen '("eDP1") :drive '()) (equal (look) '((:vid-gone "VID")))))
(check "another network joined: not this rule" (progn (there :network '("Cafe") :screen '("eDP1") :drive '()) (null (look))))
(check "and joined again" (progn (there :network '("VID") :screen '("eDP1") :drive '()) (equal (look) '((:vid "VID")))))
(check "what can't be told sets nothing off"
       (progn (there :screen '("eDP1") :drive '()) (and (null (look)) (null (look)))))
(check "nor does it coming back as it was" (progn (there :network '("VID") :screen '("eDP1") :drive '()) (null (look))))
(check "two drives: :any runs for each, in order"
       (progn (there :network '("VID") :screen '("eDP1") :drive '("BACKUP" "Kindle"))
              (equal (look) '((:drive "BACKUP") (:drive "Kindle")))))
(check "one taken out: only the rule that names it"
       (progn (there :network '("VID") :screen '("eDP1") :drive '("BACKUP")) (null (look))))
(check "the other" (progn (there :network '("VID") :screen '("eDP1") :drive '()) (equal (look) '((:backup-gone "BACKUP")))))

;; New, off, paused, failing
(check "a rule new in a reload runs for what is there"
       (progn (eval '(when-screen "eDP1" (push :laptop *ran*))) (and (equal (look) '(:laptop)) (null (look)))))
(check "a -gone rule new in a reload doesn't"
       (progn (eval '(when-screen-gone :any (push :any-gone *ran*))) (null (look))))
(check "a rule switched off still looks, so switching it on sets nothing off"
       (progn (setf (vikix-rule-on-p (rule-of "(:has \"hdmi\")")) nil)
              (there :network '("VID") :screen '("eDP1" "HDMI-1") :drive '())
              (and (null (look))
                   (progn (setf (vikix-rule-on-p (rule-of "(:has \"hdmi\")")) t) (null (look))))))
(check "while the rules are paused nothing runs"
       (progn (setf *vikix-rules-paused* t) (there :network '() :screen '("eDP1") :drive '())
              (prog1 (null (look)) (setf *vikix-rules-paused* nil))))
(check "a rule that fails isn't tried at every look"
       (progn (eval '(when-network "Broken" (error "no")))
              (there :network '("Broken") :screen '("eDP1") :drive '())
              (look) (look) (look)
              (= 1 (vikix-rule-failures (rule-of "\"Broken\"")))))
(check "they are in the list with the others, each saying what sets it off"
       (subsetp '(:network :network-gone :screen :screen-gone :drive :drive-gone)
                (mapcar (lambda (r) (getf r :event)) (vikix-rules-list))))

;; Being away
(setf *idle-reads* 0)
(check "idle time isn't read while no rule asks" (progn (look) (zerop *idle-reads*)))
(eval '(when-idle 10 (push :idle *ran*)))
(check "not before its minutes" (progn (setf *idle* 599) (null (look))))
(check "at its minutes, once" (progn (setf *idle* 600) (and (equal (look) '(:idle)) (progn (setf *idle* 900) (null (look))))))
(check "after a key, again" (progn (setf *idle* 3) (look) (setf *idle* 700) (equal (look) '(:idle))))

;; What is there, read for real
(setf *vikix-rules-things* 'vikix-rules-read-things)
(defvar *vikix-net* "")
(flet ((net (line) (setf *vikix-net* line) (vikix-rules-read-things :network)))
  (check "the bar hasn't read the network yet: can't be told" (eq (net "") :unknown))
  (check "offline: no network" (null (net "offline")))
  (check "Wi-Fi: its name" (equal (net "wifi VID") '("VID")))
  (check "a weak signal's percent isn't its name" (equal (net "wifi My Net 42%") '("My Net")))
  (check "a cable" (equal (net "wired") '("wired"))))
(check "no screen: the screens can't be told" (eq (vikix-rules-read-things :screen) :unknown))
(setf *vikix-rules-mounts* (sb-posix:getenv "EVENTS_MOUNTS"))
(check "the drives: what is mounted straight under the folder, a space in a name read"
       (equal (vikix-rules-read-things :drive) '("BACK UP" "Kindle")))
(check "no list of mounts: can't be told"
       (progn (setf *vikix-rules-mounts* "/nonexistent/mounts") (eq (vikix-rules-read-things :drive) :unknown)))
(setf *vikix-rules-mounts* (sb-posix:getenv "EVENTS_MOUNTS") *vikix-net* "wifi VID")
(check "vikix rules now names them, as a rule writes them"
       (let ((text (with-output-to-string (*standard-output*) (vikix-rules-cli "now"))))
         (and (search "Network: \"VID\"" text) (search "Drives:  \"BACK UP\"  \"Kindle\"" text)
              (search "Screens: can't be told just now" text) (search "Idle:" text))))
(check "vikix rules verbs has them"
       (let ((text (vikix-rules-verbs-text)))
         (and (search "(when-network \"NAME\" VERB...)" text) (search "(when-idle 10 VERB...)" text))))

;; An agent may propose one, of verbs and plain values
(check "a proposal of one is let through"
       (handler-case (progn (vikix-rule-proposal-check '(when-network "VID" (notify "Home"))) t) (error () nil)))
(check "and one with Lisp in it is not"
       (handler-case (progn (vikix-rule-proposal-check '(when-drive :any (delete-file "x"))) nil) (error () t)))
(check "no look without a screen" (null *vikix-rules-look-timer*))
(format t "~a~%" (if (zerop *fails*) "events: ok" "events: failed"))
LISP
  local out
  out=$(HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_MEDIA="$t/media" EVENTS_MOUNTS="$t/mounts" DISPLAY='' sbcl --noinform --non-interactive --load "$ql/setup.lisp" \
    --eval '(ql:quickload :stumpwm :silent t)' \
    --eval '(in-package :stumpwm)' \
    --eval "(handler-bind ((warning #'muffle-warning)) (load \"$here/config/stumpwm/vikix/errors.lisp\") (load \"$here/config/stumpwm/vikix/rules.lisp\") (load \"$t/events-test.lisp\"))" 2>&1) || true
  if grep -q '^events: ok$' <<<"$out"; then
    said+=("mistakes found as read, arriving at a login once, nothing at a reload, gone and back with the name, patterns and :any, new, off, paused and failing rules, when-idle, the network, drives and mounts read, vikix rules now, proposals")
  else
    echo "$out" | grep -v '^;\|^$' | tail -25
    echo "FAIL: the rules for things, without a screen"
    fail=1
  fi
}
no_screen

# --- In a real StumpWM on a hidden screen ---------------------------------------------
on_screen() {
  local wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm} need
  for need in Xvfb xdpyinfo xprop; do
    command -v "$need" >/dev/null || { echo "(the part on a screen needs $need; skipped here)"; return 0; }
  done
  [ -x "$wm" ] || { echo "(the part on a screen needs Vikix's StumpWM; skipped here)"; return 0; }
  local n port home before=$fail
  n=$(( 3700 + RANDOM % 400 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  export DISPLAY=":$n"
  Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
  pids+=($!)
  home="$t/deskhome"
  mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix" "$t/path"
  cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
  cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
  sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
  cat > "$home/.stumpwm.d/rules.lisp" <<'LISP'
(in-package :stumpwm)
(defvar *ev-net* 0)
(defvar *ev-gone* nil)
(defvar *ev-screens* '())
(defvar *ev-idle* 0)
(when-network "Café ☕" (incf *ev-net*))
(when-network-gone :any (setf *ev-gone* (rule-thing)))
(when-screen :any (push (rule-thing) *ev-screens*))
(when-idle 1 (incf *ev-idle*))
LISP
  [ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
  echo "events-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
  touch "$home/.local/state/vikix/welcome"
  # The bar's thread asks vikix-net for the network: this one says what the test wrote.
  printf 'wifi Café ☕\n' > "$t/net"
  printf '#!/bin/sh\ncat "%s"\n' "$t/net" > "$t/path/vikix-net"
  printf '#!/bin/sh\nexit 0\n' > "$t/path/notify-send"; printf '#!/bin/sh\n[ "$1" = is-paused ] && echo false\nexit 0\n' > "$t/path/dunstctl"
  chmod +x "$t/path/"*
  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  PATH="$t/path:$PATH" HOME=$home VIKIX_MEDIA="$t/media" VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
  pids+=($!)
  ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
  local until=$((SECONDS + 60)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
  [ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start"; fail=1; return 0; }
  wait_for() {   # wait_for FORM WANTED: up to 30 seconds
    for _ in $(seq 1 60); do [ "$(ask "$1")" = "$2" ] && return 0; sleep 0.5; done
    return 1
  }
  local cafe="(67 97 102 233 32 9749)"   # "Café ☕", by its characters' numbers

  check "the look is a timer of whole seconds: $(ask '(princ (timer-p *vikix-rules-look-timer*))')" test "$(ask '(princ (timer-p *vikix-rules-look-timer*))')" = T
  wait_for '(princ *ev-net*)' 1 || true
  check "at login the network there, as the bar reads it, sets its rule off: ran $(ask '(princ *ev-net*)'), the bar has $(ask '(prin1 *vikix-net*)')" test "$(ask '(princ *ev-net*)')" = 1
  check "the name the rules see is the one written: $(ask '(prin1 (vikix-rules-read-things :network))')" \
    test "$(ask '(princ (map (quote list) (function char-code) (or (first (vikix-rules-read-things :network)) "")))')" = "$cafe"
  ask '(vikix-rules-look)' >/dev/null; ask '(vikix-rules-look)' >/dev/null
  check "another look doesn't run it again (the name is read back as it was noted)" test "$(ask '(princ *ev-net*)')" = 1
  check "what the rules saw is noted on X's root window" grep -q '_VIKIX_RULES_SEEN(STRING) = "(' <<<"$(xprop -root _VIKIX_RULES_SEEN 2>&1)"
  local heads; heads=$(ask '(prin1 (vikix-rules-read-things :screen))')
  if [ "$heads" != NIL ] && [ -n "$heads" ]; then
    check "the screen there counts as a screen arriving, by its name: $heads, ran for $(ask '(prin1 *ev-screens*)')" \
      test "$(ask '(prin1 *ev-screens*)')" = "$heads"
  else
    echo "(this X server names no screen; the screen's rule is checked without one)"
  fi
  ask '(loadrc)' >/dev/null; sleep 2
  wait_for '(princ 1)' 1 || true
  ask '(vikix-rules-look)' >/dev/null
  check "a reload sets nothing off: ran $(ask '(princ *ev-net*)'), screens $(ask '(princ (length *ev-screens*))')" \
    test "$(ask '(princ (list *ev-net* (<= (length *ev-screens*) 1)))')" = "(1 T)"
  local now; now=$(HOME=$home VIKIX_SWANK_PORT=$port bash "$here/bin/vikix-rules" now 2>&1)
  check "vikix rules now names the network and the screens: $(tr '\n' '|' <<<"$now" | cut -c1-120)" bash -c "grep -q '^Network: \"Caf' <<<\"\$1\" && grep -q '^Screens: ' <<<\"\$1\" && grep -q '^Idle: ' <<<\"\$1\"" _ "$now"

  echo offline > "$t/net"
  ask '(vikix-bar-kick)' >/dev/null
  wait_for '(princ (map (quote list) (function char-code) (or *ev-gone* "")))' "$cafe" || true
  check "going offline runs the -gone rule, with the network's name: $(ask '(prin1 *ev-gone*)')" \
    test "$(ask '(princ (map (quote list) (function char-code) (or *ev-gone* "")))')" = "$cafe"
  check "vikix why says what set it off: $(ask '(princ (vikix-why-text 10))' | grep -m1 'network' | cut -c1-100)" \
    grep -q 'A rule, as a network was left (Caf' <<<"$(ask '(princ (vikix-why-text 10))')"
  printf 'wifi Café ☕\n' > "$t/net"
  ask '(vikix-bar-kick)' >/dev/null
  wait_for '(princ *ev-net*)' 2 || true
  check "and joining it again runs the rule again: $(ask '(princ *ev-net*)')" test "$(ask '(princ *ev-net*)')" = 2

  check "idle time is read from the X server: $(ask '(princ (vikix-rules-read-idle))') s" test "$(ask '(princ (integerp (vikix-rules-read-idle)))')" = T
  ask '(setf *vikix-rules-idle* (lambda () 61))' >/dev/null; ask '(vikix-rules-look)' >/dev/null; ask '(vikix-rules-look)' >/dev/null
  check "a minute away runs when-idle 1, once: $(ask '(princ *ev-idle*)')" test "$(ask '(princ *ev-idle*)')" = 1
  check "nothing went wrong in the desktop meanwhile" test -z "$(ls "$home/.local/state/vikix/errors/" 2>/dev/null || true)"
  [ "$fail" = "$before" ] && said+=("on a screen: the bar's network sets a rule off at login and not at a reload, offline and back, the screen there, vikix rules now, vikix why, when-idle")
}
on_screen

[ "$fail" = 0 ] && echo "events: ${said[*]}"
exit "$fail"
