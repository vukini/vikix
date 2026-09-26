;;;; ~/.stumpwm.d/init.lisp — managed by Vikix (a symlink into the checkout).
;;;;
;;;; StumpWM runs this file when it starts. It does only two things:
;;;;   1. load Vikix's layer, one small file per concern
;;;;   2. load ~/.stumpwm.d/user.lisp — yours — last, so your settings win
;;;;
;;;; Don't edit this file: `vikix update` replaces it. Edit user.lisp.

(in-package :stumpwm)

(defparameter *vikix-dir*
  (merge-pathnames ".stumpwm.d/vikix/" (user-homedir-pathname))
  "Where Vikix's StumpWM files live.")

(defparameter *vikix-files*
  '("theme"      ; colours and borders, as one palette
    "groups"     ; workspaces 1-9
    "commands"   ; Vikix's own commands (menu, key help, reload)
    "keys"       ; Super-key bindings
    "help"       ; key help (s-F1) and the list of all commands
    "modeline"   ; the bar at the top
    "swank")     ; the door for Emacs
  "Loaded in this order. Each file only uses what the files before it define.")

(defun vikix-load (name)
  "Load one Vikix file. A mistake in one file is reported on screen and
the rest still load, so a typo never leaves you with a dead desktop."
  (let ((file (merge-pathnames (concatenate 'string name ".lisp") *vikix-dir*)))
    (handler-case (load file)
      (error (e)
        (message "^1Vikix: error in ~a.lisp:^n~%~a" name e)))))

(mapc #'vikix-load *vikix-files*)

;; Your file, last.
(let ((user (merge-pathnames ".stumpwm.d/user.lisp" (user-homedir-pathname))))
  (when (probe-file user)
    (handler-case (load user)
      (error (e)
        (message "^1Vikix: error in user.lisp:^n~%~a" e)))))
