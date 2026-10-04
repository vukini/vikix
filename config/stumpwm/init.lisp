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
  '("errors"     ; when something fails, ask what to do (loaded first, plainly)
    "theme"      ; colours and borders, as one palette
    "groups"     ; workspaces 1-9
    "commands"   ; Vikix's own commands (menu, key help, reload)
    "windows"    ; focus, gaps, layout undo, finding windows
    "rules"      ; rules that read like sentences: (when-window (:class "Firefox") (workspace 2))
    "viri"       ; a workspace that scrolls sideways (vikix-viri), and Super+h/l along it
    "drawer"     ; a few everyday programs at the screen's edge, out and away (Super+Ctrl+b)
    "layouts"    ; saved layouts: vikix layout save NAME, vikix layout NAME
    "overview"   ; every workspace drawn small on a card, to pick a window (Super+o)
    "day"        ; what had the screen, written down for vikix day
    "keys"       ; Super-key bindings
    "help"       ; the key card (s-/), key help (s-F1), all commands, which-key
    "webapps"    ; your web apps (vikix webapp): keys and Super+m
    "modeline"   ; the bar at the top
    "plugins"    ; the plugins you added (vikix plugin add), and their part of the bar
    "swank-guard" ; a wrong Swank password can't take Swank down
    "swank")     ; the door for Emacs, with a password
  "Loaded in this order. Each file only uses what the files before it define.")

(defun vikix-load-file (file name)
  "Load FILE. A mistake in it never leaves you with a dead desktop: with
errors.lisp loaded, the file goes a form at a time and you're asked what
to do about the one that failed (the rest still load); without it (a
mistake in errors.lisp itself), the error is shown and the next file loads."
  (if (and (fboundp 'vikix-load-forms) (not (equal name "errors.lisp")))
      (funcall 'vikix-load-forms file name)
      (handler-case (load file)
        (error (e)
          (message "^1Vikix: error in ~a:^n~%~a" name e)))))

(defun vikix-load (name)
  "Load one Vikix file."
  (vikix-load-file (merge-pathnames (concatenate 'string name ".lisp") *vikix-dir*)
                   (concatenate 'string name ".lisp")))

(mapc #'vikix-load *vikix-files*)

;; Your rules (rules.lisp, when you have one), then your file, last.
(let ((rules (merge-pathnames ".stumpwm.d/rules.lisp" (user-homedir-pathname)))
      (user (merge-pathnames ".stumpwm.d/user.lisp" (user-homedir-pathname))))
  (when (probe-file rules)
    (vikix-load-file rules "rules.lisp"))
  (when (probe-file user)
    (vikix-load-file user "user.lisp")))
