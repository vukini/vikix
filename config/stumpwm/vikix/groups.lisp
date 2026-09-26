;;;; groups.lisp — nine workspaces, named 1 to 9.
;;;;
;;;; StumpWM calls workspaces "groups". It starts with one called
;;;; "Default"; Vikix renames it to "1" and adds 2-9 in the background.
;;;; Safe to load twice: existing groups are left as they are.

(in-package :stumpwm)

(defparameter *vikix-group-names*
  '("1" "2" "3" "4" "5" "6" "7" "8" "9"))

(let ((screen (current-screen)))
  (when (find-group screen "Default")
    (grename (first *vikix-group-names*)))
  (dolist (name (rest *vikix-group-names*))
    (unless (find-group screen name)
      (add-group screen name :background t))))
