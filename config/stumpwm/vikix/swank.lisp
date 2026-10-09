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
;;;;
;;;; Swank runs whatever it's sent, as you, and 127.0.0.1 isn't only yours
;;;; (the Windows VM reaches it through passt's gateway address). So it has
;;;; a password: Swank itself reads ~/.slime-secret (40-config makes it) at
;;;; each connection, and lets in only a client that sends its first line.
;;;; Emacs's SLIME and vikix eval send it by themselves.

(in-package :stumpwm)

(defparameter *vikix-swank-port* 4004)

(defvar *vikix-swank-started* nil
  "Non-nil once the server is running, so reloading the config never starts
a second one: :GUARDED when swank-guard.lisp was in place at its start.")

(defun vikix-swank-call (name &rest args)
  "Call Swank's NAME. Its symbols are looked up at run time, so this file
still loads in a StumpWM built without Swank."
  (apply (find-symbol name :swank) args))

(defun vikix-swank-restart (port)
  "Stop Swank's server on PORT and start it again on the same port.
Stopping closes the listening socket, but its accept thread is still in
accept() on it, and Linux keeps the port bound until that thread is
interrupted: on a busy machine the new server's bind then failed with
EADDRINUSE (tests/swank.sh, about one run in three under load; Swank's own
restart-server just sleeps 5 s). So wait for the old thread to end, then
try the bind for up to 5 s."
  (let ((old-thread (third (find port (symbol-value (find-symbol "*SERVERS*" :swank))
                                 :key #'second))))
    (ignore-errors (vikix-swank-call "STOP-SERVER" port))
    (when (and old-thread (not (eq old-thread sb-thread:*current-thread*)))
      (sb-thread:join-thread old-thread :timeout 5 :default nil))
    (loop for tries from 1
          do (handler-case
                 (return (vikix-swank-call "CREATE-SERVER" :port port :dont-close t))
               (error (e)
                 (when (>= tries 50) (error e))
                 (sleep 0.1))))))

(defun vikix-start-swank ()
  (cond ((not (find-package :swank))
         (message "Swank is not in this StumpWM build; run: vikix rebuild-wm"))
        ((eq *vikix-swank-started* :guarded))   ; running, and guarded: nothing to do
        (*vikix-swank-started*
         ;; Started before swank-guard.lisp existed (a StumpWM from before
         ;; 0.41.2, now reloading the new files). A wrong password may
         ;; already have left its accept thread stuck in the debugger, which
         ;; no wrapper can undo: so start it again, once, guarded. A request
         ;; that is running now (this reload, if vikix eval sent it) goes on;
         ;; only the listening part is replaced.
         (vikix-swank-restart *vikix-swank-port*)
         (setf *vikix-swank-started* :guarded))
        (t
         (vikix-swank-call "CREATE-SERVER" :port *vikix-swank-port* :dont-close t)
         (setf *vikix-swank-started* (if *vikix-swank-guarded* :guarded t)))))

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

(defun vikix-eval-door (forms text from)
  "The door for an agent's FORMS (read from TEXT, FROM says whose): when one
of them calls what the door doesn't let an agent call, the whole text is
held for the user, why is printed for the agent, and :HELD is returned;
NIL when every form may run. Shared with socket.lisp, which asks it in a
thread of its own."
  (dolist (form forms nil)
    (multiple-value-bind (ok why kind) (vikix-door-check form)
      (unless ok
        (let ((id (vikix-door-hold text why kind from)))
          (fresh-line)
          (if id
              (format t "held ~d: ~a~%  because ~a.~%  The door lets an agent's Lisp through only when every function it calls is on its list (vikix door allowed). The user can run this as they are, from Super+m, Door, or vikix door run ~d, or drop it; nothing of it ran.~%"
                      id (vikix-door-print form) why id)
              (format t "refused: ~a~%  because ~a; and ~d forms wait at the door already, so this one isn't kept. Ask the user to look at them (Super+m, Door).~%"
                      (vikix-door-print form) why *vikix-door-most*))
          (return :held))))))

(defun vikix-eval-forms (text &key door from)
  "Read every form in TEXT, in the STUMPWM package, and evaluate each.
Print whatever the forms print, then each form's values after \"=> \".
Return :OK, or :ERROR after printing the error. With DOOR (an agent's
forms, FROM saying whose) each form is first walked by door.lisp, and the
whole text is held for the user, with :HELD returned and why printed,
when one of them calls what the door doesn't let an agent call."
  (let ((*package* (find-package :stumpwm))
        (*error-output* *standard-output*))   ; compiler warnings too
    (handler-case
        (let ((forms (let ((*read-eval* nil))   ; #. would run at reading, before any check
                       (with-input-from-string (in text)
                         (loop with eof = (gensym "EOF")
                               for form = (read in nil eof)
                               until (eq form eof)
                               collect form)))))
          (when (and door (vikix-eval-door forms text from))
            (return-from vikix-eval-forms :held))
          (dolist (form forms)
            (let ((values (multiple-value-list (eval form))))
              (fresh-line)
              (if values
                  (format t "~{=> ~S~%~}" values)
                  (format t "=> ; no values~%"))))
          :ok)
      (error (e)
        (fresh-line)
        (format t "error: ~A~%" e)
        :error))))

(defun vikix-eval-for-agent (text &key door from)
  "Evaluate the forms in TEXT in StumpWM's main thread and return :OK,
:ERROR, :HELD when DOOR is set and the door kept them for the user, or
:BUSY when the main thread didn't answer within *vikix-eval-timeout* (the
forms won't run later). What they print goes to *standard-output*, which
Swank sends back."
  (cond
    ((in-main-thread-p)
     (vikix-eval-forms text :door door :from from))
    ;; StumpWM hands work to its main thread through a channel it makes when
    ;; its loop starts, after this file is loaded and the windows already
    ;; there are taken in. Asked before that, call-in-main-thread fails in
    ;; this thread; Swank shows the client its debugger, the client leaves,
    ;; and Swank's thread for it dies on the closed socket and takes the
    ;; next askers with it (found by tests/rules.sh starting StumpWM again).
    ((null *request-channel*)
     (format t "error: StumpWM is still starting. Try again in a moment.~%")
     :error)
    (t
      (let ((done (sb-thread:make-semaphore))
            (output "")
            (status :error)
            ;; A form given up on must not run later: once a menu closes,
            ;; every retry an agent made would run at once.
            (cancelled nil))
        (call-in-main-thread
         (lambda ()
           (unwind-protect
                (unless cancelled
                  (setf output (with-output-to-string (*standard-output*)
                                 (setf status (vikix-eval-forms text :door door :from from)))))
             (sb-thread:signal-semaphore done))))
        (cond ((sb-thread:wait-on-semaphore done :timeout *vikix-eval-timeout*)
               (write-string output)
               status)
              (t
               (setf cancelled t)
               (format t "error: StumpWM's main thread did not answer within ~a s.~%~
                          Is a menu or a prompt open? Close it and try again (nothing will run later).~%"
                       *vikix-eval-timeout*)
               :busy))))))
