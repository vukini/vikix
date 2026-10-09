;;;; socket.lisp — a door of Vikix's own beside Swank: a UNIX socket, served by a thread.
;;;;
;;;; Every `vikix eval` (the bar's clicks, the palette, vikix what, the MCP
;;;; server, an agent's shell) went over TCP to Swank at 127.0.0.1:4004 with
;;;; the password, and waited on the main thread: with a menu open, nothing
;;;; answered until the menu closed. This is the same door without the
;;;; detour: $XDG_RUNTIME_DIR/vikix.sock (VIKIX_SOCKET names another), made
;;;; 0600 in a folder that is yours alone, so the file's permission is the
;;;; authentication and no secret is sent; a thread of Vikix's accepts each
;;;; client and answers it in a thread of its own. Forms that only read Lisp
;;;; state (the windows, the workspaces, a key, the rules, the palette's
;;;; rows: the door's list less *vikix-socket-acts*) are given to the main
;;;; thread first, so the answer comes after whatever the desktop was
;;;; already doing, as it did over Swank: the key just pressed has been
;;;; handled. The wait is in slices (*vikix-socket-read-wait*): after a
;;;; slice without an answer, a main thread that used no processor time
;;;; in it is idle without answering, which is a menu or a prompt (or a
;;;; program it waits on), and the client's thread evaluates the read
;;;; itself; one that was working gets another slice, up to the deadline.
;;;; Anything else goes to the main thread as before, with its deadline
;;;; (*vikix-eval-timeout*), and a form given up on never runs later. An
;;;; agent's forms pass the door first (door.lisp), in the thread.
;;;;
;;;; The protocol is one request a connection: a line "eval KIND FROM..."
;;;; (KIND door or me), then the forms until the client shuts its writing
;;;; side; back comes a line with the status (ok, error, held, missing-door)
;;;; and what the forms printed, then the connection closes. bin/vikix-eval
;;;; tries this first and falls back to Swank, which stays for SLIME in Emacs
;;;; and vikix rescue. Swank's password and guard are untouched.
;;;;
;;;; Threads here: vikix-socket (accepting) and vikix-socket-client (one a
;;;; request). Neither touches X: an X request belongs to the main thread.

(in-package :stumpwm)

(defvar *vikix-socket* nil "The listening socket, while the server runs.")
(defvar *vikix-socket-thread* nil "The thread accepting clients.")
(defvar *vikix-socket-path* nil "Where the socket is, while the server runs.")

(defun vikix-socket-path ()
  "Where the socket goes: $VIKIX_SOCKET, else $XDG_RUNTIME_DIR/vikix.sock;
NIL when neither is set (a session without elogind: no socket, Swank alone).
A StumpWM started with VIKIX_SWANK_PORT set is a test's (every test sets it,
and the desktop's session never does): it serves VIKIX_SOCKET or nothing,
never the desktop's own path, which it would take from under the desktop."
  (let ((own (sb-posix:getenv "VIKIX_SOCKET"))
        (run (sb-posix:getenv "XDG_RUNTIME_DIR"))
        (test (sb-posix:getenv "VIKIX_SWANK_PORT")))
    (cond ((and own (plusp (length own))) own)
          ((and test (plusp (length test))) nil)
          ((and run (plusp (length run))) (concatenate 'string run "/vikix.sock"))
          (t nil))))

;;; --- What the thread may answer itself ------------------------------------------------------

(defparameter *vikix-socket-acts*
  '(;; drawing, or an X request
    "MESSAGE" "ECHO-STRING" "REFRESH" "REDISPLAY" "ECHO-WINDOWS" "WINDOWS" "TOGGLE-MODE-LINE"
    "LOADRC" "FULLSCREEN" "DESCRIBE" "APROPOS" "APROPOS-LIST"
    ;; moves and switches
    "GSELECT" "GNEXT" "GPREV" "GOTHER" "GMOVE" "FNEXT" "FPREV" "FOTHER" "MOVE-FOCUS" "MOVE-WINDOW"
    "FOCUS-WINDOW" "FOCUS-FRAME" "FOCUS-ALL" "PULL-WINDOW" "PULL-WINDOW-BY-NUMBER" "SELECT-WINDOW"
    "SELECT-WINDOW-BY-NUMBER" "NEXT" "PREV" "NEXT-IN-FRAME" "PREV-IN-FRAME" "OTHER-WINDOW"
    "OTHER-IN-FRAME" "HSPLIT" "VSPLIT" "REMOVE-SPLIT" "ONLY" "BALANCE-FRAMES"
    ;; Vikix's acts, and what changes its state
    "VIKIX-AGENT-RUN" "VIKIX-GATHER" "VIKIX-APPLY-THEME" "VIKIX-RULES-TICK" "VIKIX-RULES-LOOK"
    "VIKIX-RULE-PROPOSE" "VIKIX-DOOR-CLI"
    ;; destructive on a list that may be the desktop's own
    "SORT" "STABLE-SORT" "NREVERSE" "DELETE-DUPLICATES" "FILL" "NSUBSTITUTE" "CLRHASH" "REMHASH"
    "MAPCAN" "MAPCON")
  "Of the door's list, what the socket's thread never runs itself: it draws,
asks X, moves something, or changes a list that may be the desktop's. These
go to the main thread. Everything else on the door's list is a read.")

(defun vikix-socket-reads ()
  "The names a form may call and still be answered in the socket's thread."
  (set-difference *vikix-door-allowed* *vikix-socket-acts* :test #'string=))

(defparameter *vikix-socket-read-wait* 0.3
  "A slice of the wait for the main thread, in seconds: after one without
an answer in which the main thread used no processor time (a menu, a
prompt), the client's thread answers a read itself.")

(defun vikix-socket-in-main (text)
  "TEXT's forms in the main thread, or, when it is idle without answering,
here. The status and what was printed."
  (let ((done (sb-thread:make-semaphore))
        (output "") (status :error) (cancelled nil))
    (call-in-main-thread
     (lambda ()
       (unwind-protect
            (unless cancelled
              (setf output (with-output-to-string (*standard-output*)
                             (setf status (vikix-eval-forms text)))))
         (sb-thread:signal-semaphore done))))
    (loop with waited = 0
          for ticks = (vikix-main-ticks)
          do (when (sb-thread:wait-on-semaphore done :timeout *vikix-socket-read-wait*)
               (return (values status output)))
             (incf waited *vikix-socket-read-wait*)
             (when (or (>= waited *vikix-eval-timeout*)
                       (eql ticks (vikix-main-ticks)))   ; idle, not answering: a menu or a prompt
               (setf cancelled t)
               (return (values :thread
                               (with-output-to-string (*standard-output*)
                                 (setf status (vikix-eval-forms text)))
                               status))))))

(defun vikix-socket-read-only-p (forms)
  "Do FORMS only read Lisp state? Then the thread answers them itself. The
door's walker says, with the reads as its list and nothing else (not the
registry's commands, not the user's own names: those act)."
  (let ((*vikix-door-allowed* (vikix-socket-reads))
        (*vikix-door-no-extras* t))
    (every (lambda (form) (null (vikix-door-problem form))) forms)))

;;; --- One request ------------------------------------------------------------------------------

(defun vikix-socket-answer (text door from)
  "The status (a lowercase word) and what the forms of TEXT printed. With
DOOR the forms are an agent's (FROM says whose): the door first, here in
the thread. A read is answered here; anything else in the main thread."
  (let ((status :error)
        (output ""))
    (setf output
          (with-output-to-string (*standard-output*)
            (setf status
                  (handler-case
                      (let ((forms (vikix-door-read text)))
                        (cond ((and door (not (fboundp 'vikix-door-check))) :missing-door)
                              ((and door (vikix-eval-door forms text from)) :held)
                              ((vikix-socket-read-only-p forms)
                               (multiple-value-bind (where printed here) (vikix-socket-in-main text)
                                 (write-string printed)
                                 (if (eq where :thread) here where)))
                              (t (vikix-eval-for-agent text))))
                    (error (e)
                      (fresh-line)
                      (format t "error: ~a~%" e)
                      :error)))))
    (values (string-downcase (symbol-name status)) output)))

(defun vikix-socket-serve (client)
  "Read CLIENT's request, answer it, close. In a thread of its own, so a
slow client holds nobody up; an error here ends this client only."
  (sb-thread:make-thread
   (lambda ()
     (let ((stream nil))
       (unwind-protect
            (handler-case
                (progn
                  (setf stream (sb-bsd-sockets:socket-make-stream
                                client :input t :output t :external-format :utf-8 :buffering :full))
                  (let* ((header (or (read-line stream nil) ""))
                         (words (ppcre:split " " header :limit 3))
                         (text (with-output-to-string (out)
                                 (loop for line = (read-line stream nil)
                                       while line do (write-line line out)))))
                    (if (string= (or (first words) "") "eval")
                        (multiple-value-bind (status output)
                            (vikix-socket-answer text (string= (or (second words) "") "door") (third words))
                          (write-line status stream)
                          (write-string output stream))
                        (write-line "error: the first line should be: eval KIND FROM" stream))
                    (finish-output stream)))
              (error () nil))
         (ignore-errors (when stream (close stream)))
         (ignore-errors (sb-bsd-sockets:socket-close client)))))
   :name "vikix-socket-client"))

;;; --- The server -------------------------------------------------------------------------------

(defun vikix-socket-listen (path)
  "A listening socket at PATH, 0600, an old file there replaced."
  (ignore-errors (sb-posix:unlink path))
  (let ((sock (make-instance 'sb-bsd-sockets:local-socket :type :stream)))
    (sb-bsd-sockets:socket-bind sock path)
    (sb-posix:chmod path #o600)
    (sb-bsd-sockets:socket-listen sock 8)
    sock))

(defun vikix-socket-loop (sock)
  "Accept clients until the socket is closed under us."
  (loop
    (let ((client (handler-case (sb-bsd-sockets:socket-accept sock)
                    (error () (return)))))
      (if client
          (handler-case (vikix-socket-serve client)
            (error () (ignore-errors (sb-bsd-sockets:socket-close client))))
          (return)))))

(defun vikix-socket-stop ()
  "Close the socket, end its thread, remove the file."
  (let ((sock *vikix-socket*) (thread *vikix-socket-thread*) (path *vikix-socket-path*))
    (setf *vikix-socket* nil *vikix-socket-thread* nil *vikix-socket-path* nil)
    (when sock
      ;; shutdown wakes an accept() on Linux; close alone doesn't (as Swank's restart found).
      (ignore-errors (sb-bsd-sockets:socket-shutdown sock :direction :io))
      (ignore-errors (sb-bsd-sockets:socket-close sock)))
    (when (and thread (sb-thread:thread-alive-p thread) (not (eq thread sb-thread:*current-thread*)))
      (unless (sb-thread:join-thread thread :timeout 2 :default nil)
        (ignore-errors (sb-thread:terminate-thread thread))))
    (when path (ignore-errors (sb-posix:unlink path)))))

(defun vikix-socket-start ()
  "Serve the socket; a server already running is stopped first (a reload
brings this file's new code). Says, never errs, when it can't: Swank is
still there."
  (vikix-socket-stop)
  (let ((path (vikix-socket-path)))
    (when path
      (handler-case
          (let ((sock (vikix-socket-listen path)))
            (setf *vikix-socket* sock *vikix-socket-path* path)
            (setf *vikix-socket-thread*
                  (sb-thread:make-thread (lambda () (vikix-socket-loop sock)) :name "vikix-socket"))
            path)
        (error (e)
          (vikix-say "Vikix's socket couldn't start at ~a: ~a (vikix eval uses Swank)" path (vikix-one-line e))
          nil)))))

(defun vikix-socket-status ()
  "For vikix doctor and the tests: the path and whether the thread lives, or NIL."
  (and *vikix-socket-path* *vikix-socket-thread* (sb-thread:thread-alive-p *vikix-socket-thread*)
       *vikix-socket-path*))

(vikix-socket-start)
(add-hook *quit-hook* 'vikix-socket-stop)
