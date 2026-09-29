;;;; swank-guard.lisp — a wrong password must not take Swank (or StumpWM) down.
;;;;
;;;; Swank checks ~/.slime-secret (see swank.lisp) in the one thread that
;;;; accepts every connection, and signals an error when a client gets it
;;;; wrong. Nothing catches that error: the thread dies, so Swank stops
;;;; answering, and a Lisp without a debugger quits altogether. Anything
;;;; that reaches 127.0.0.1:4004 (the Windows VM, through passt) could do
;;;; that with one connection.
;;;;
;;;; The same thread waits for the password, and Swank's 20 s limit on that
;;;; wait does nothing on SBCL (its backend has no set-stream-timeout): a
;;;; client that connects and sends nothing keeps every other one out, for
;;;; as long as it stays connected.
;;;;
;;;; So, around Swank's own functions:
;;;;   authenticate-client  the password must come within
;;;;                        *vikix-swank-auth-seconds*; on a wrong or late
;;;;                        one, close that client, then signal an error
;;;;                        (so it's never served)
;;;;   accept-connections   the error ends this one client, and the loop
;;;;                        goes on to the next
;;;; Loaded before swank.lisp; wraps only once, however often it's loaded
;;;; (a StumpWM guarded by 0.41.2-0.57.0, without the time limit, gets it
;;;; at its next reload).

(in-package :stumpwm)

(defparameter *vikix-swank-auth-seconds* 5
  "Seconds a Swank client has to send the password. vikix eval and SLIME
send it at once.")

(defvar *vikix-swank-guarded* nil
  "NIL; T once Swank's accept loop is guarded (0.41.2-0.57.0); 2 once the
password also has a time limit.")

(defun vikix-guard-swank ()
  (let* ((swank (find-package :swank))
         (auth (and swank (find-symbol "AUTHENTICATE-CLIENT" swank)))
         (accept (and swank (find-symbol "ACCEPT-CONNECTIONS" swank))))
    (when (and auth accept (fboundp auth) (fboundp accept)
               (not (eql *vikix-swank-guarded* 2)))
      (let ((original-auth (fdefinition auth))   ; the old guard's, if it's there
            (original-accept (fdefinition accept)))
        (setf (fdefinition auth)
              (lambda (stream)
                ;; SERIOUS-CONDITION: a deadline passing isn't an ERROR,
                ;; and it's re-signalled as one, which the loop below and
                ;; Swank's own IGNORE-ERRORS catch.
                (handler-case
                    (sb-sys:with-deadline (:seconds *vikix-swank-auth-seconds*)
                      (funcall original-auth stream))
                  (serious-condition (e)
                    (ignore-errors (close stream :abort t))
                    (error "Swank client refused: ~a" e)))))
        (unless *vikix-swank-guarded*          ; the old guard did this part
          (setf (fdefinition accept)
                (lambda (&rest args)
                  (handler-case (apply original-accept args)
                    (error () nil)))))
        (setf *vikix-swank-guarded* 2)))))

(vikix-guard-swank)
