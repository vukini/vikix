;;;; swank-guard.lisp — a wrong password must not take Swank (or StumpWM) down.
;;;;
;;;; Swank checks ~/.slime-secret (see swank.lisp) in the one thread that
;;;; accepts every connection, and signals an error when a client gets it
;;;; wrong. Nothing catches that error: the thread dies, so Swank stops
;;;; answering, and a Lisp without a debugger quits altogether. Anything
;;;; that reaches 127.0.0.1:4004 (the Windows VM, through passt) could do
;;;; that with one connection.
;;;;
;;;; So, around Swank's own functions:
;;;;   authenticate-client  on a wrong password, close that client, then
;;;;                        let the error go on (so it's never served)
;;;;   accept-connections   the error ends this one client, and the loop
;;;;                        goes on to the next
;;;; Loaded before swank.lisp; wraps only once, however often it's loaded.

(in-package :stumpwm)

(defvar *vikix-swank-guarded* nil
  "True once Swank's accept loop is guarded.")

(defun vikix-guard-swank ()
  (let* ((swank (find-package :swank))
         (auth (and swank (find-symbol "AUTHENTICATE-CLIENT" swank)))
         (accept (and swank (find-symbol "ACCEPT-CONNECTIONS" swank))))
    (when (and auth accept (fboundp auth) (fboundp accept)
               (not *vikix-swank-guarded*))
      (let ((original-auth (fdefinition auth))
            (original-accept (fdefinition accept)))
        (setf (fdefinition auth)
              (lambda (stream)
                (handler-case (funcall original-auth stream)
                  (error (e)
                    (ignore-errors (close stream :abort t))
                    (error e)))))
        (setf (fdefinition accept)
              (lambda (&rest args)
                (handler-case (apply original-accept args)
                  (error () nil))))
        (setf *vikix-swank-guarded* t)))))

(vikix-guard-swank)
