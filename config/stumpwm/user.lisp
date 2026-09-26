;;;; ~/.stumpwm.d/user.lisp — yours. Vikix never overwrites this file.
;;;;
;;;; It loads after all of Vikix's files, so anything here wins.
;;;; Some things you might do:
;;;;
;;;;   (setf *vikix-terminal* "xterm")             ; another terminal
;;;;   (vikix-bind "s-w" "exec firefox")           ; a new key
;;;;   (run-shell-command "nm-applet")               ; start a program with the session
;;;;
;;;; Reload after editing: s-m, then "Reload config".
;;;; Themes are chosen with `vikix theme NAME` (or s-m, Theme), not here.

(in-package :stumpwm)
