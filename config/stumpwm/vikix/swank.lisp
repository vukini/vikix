;;;; swank.lisp — the door that lets Emacs into the running window manager.
;;;;
;;;; Swank is built into the StumpWM executable (see lib/build-stumpwm.lisp).
;;;; This starts its server once, on 127.0.0.1 port 4004 (4005 is left free
;;;; for your ordinary SLIME sessions). Then, from Emacs:
;;;;
;;;;   M-x slime-connect RET 127.0.0.1 RET 4004
;;;;
;;;; and you are at a REPL inside StumpWM: redefine a command, re-bind a
;;;; key, try a theme — it takes effect immediately, no restart.

(in-package :stumpwm)

(defparameter *vikix-swank-port* 4004)

(defvar *vikix-swank-started* nil
  "True once the server is running, so reloading the config never starts a second one.")

(defun vikix-start-swank ()
  (cond (*vikix-swank-started*)            ; already running: nothing to do
        ((not (find-package :swank))
         (message "Swank is not in this StumpWM build; run: vikix rebuild-wm"))
        (t
         ;; Swank's symbols are looked up at run time, so this file still
         ;; loads in a StumpWM built without Swank.
         (funcall (find-symbol "CREATE-SERVER" :swank)
                  :port *vikix-swank-port* :dont-close t)
         (setf *vikix-swank-started* t))))

(vikix-start-swank)

;;; The same door, for scripts: `vikix eval '(form)'` in a shell.
;;;
;;; bin/vikix-eval connects to the port above and asks Swank to call
;;; vikix-eval-for-agent with the text it was given. That is how an AI
;;; agent (or you, from a terminal) looks at and changes the running
;;; desktop without restarting it.
;;;
;;; Two things make it safe to call from a script:
;;;   - Errors never reach the debugger. A form that fails prints
;;;     "error: ..." and the call returns :ERROR. Without this, an error
;;;     would open Swank's debugger and the script would wait forever.
;;;   - The forms run in StumpWM's main thread, the one that owns the
;;;     X connection, not in Swank's worker thread. If the main thread
;;;     is busy (a menu or a prompt is open), the call gives up after
;;;     *vikix-eval-timeout* seconds instead of hanging.

(defparameter *vikix-eval-timeout* 10
  "Seconds `vikix eval` waits for StumpWM's main thread.")

(defun vikix-eval-forms (text)
  "Read every form in TEXT, in the STUMPWM package, and evaluate each.
Print whatever the forms print, then each form's values after \"=> \".
Return :OK, or :ERROR after printing the error."
  (let ((*package* (find-package :stumpwm))
        (*error-output* *standard-output*))   ; compiler warnings too
    (handler-case
        (with-input-from-string (in text)
          (loop with eof = (gensym "EOF")
                for form = (read in nil eof)
                until (eq form eof)
                do (let ((values (multiple-value-list (eval form))))
                     (fresh-line)
                     (if values
                         (format t "~{=> ~S~%~}" values)
                         (format t "=> ; no values~%"))))
          :ok)
      (error (e)
        (fresh-line)
        (format t "error: ~A~%" e)
        :error))))

(defun vikix-eval-for-agent (text)
  "Evaluate the forms in TEXT in StumpWM's main thread and return :OK or
:ERROR. What they print goes to *standard-output*, which Swank sends back."
  (if (in-main-thread-p)
      (vikix-eval-forms text)
      (let ((done (sb-thread:make-semaphore))
            (output "")
            (status :error))
        (call-in-main-thread
         (lambda ()
           (unwind-protect
                (setf output (with-output-to-string (*standard-output*)
                               (setf status (vikix-eval-forms text))))
             (sb-thread:signal-semaphore done))))
        (cond ((sb-thread:wait-on-semaphore done :timeout *vikix-eval-timeout*)
               (write-string output)
               status)
              (t
               (format t "error: StumpWM's main thread did not answer within ~a s.~%~
                          Is a menu or a prompt open? Close it and try again.~%"
                       *vikix-eval-timeout*)
               :error)))))
