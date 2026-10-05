;;;; errors.lisp — when something fails, the desktop asks instead of falling over.
;;;;
;;;; Lisp doesn't have to give up on an error: the code that signals one can
;;;; offer ways to go on (restarts), and whoever is told about it picks one.
;;;; Vikix shows them in a small menu:
;;;;
;;;;   A mistake in a file (user.lisp, a layer file)
;;;;       Files are loaded a form at a time, so one bad form doesn't take
;;;;       the rest of the file with it: skip it and load the rest, open the
;;;;       file at that line in Emacs, skip the rest of the file, or (for
;;;;       user.lisp) load your last snapshot of it instead, leaving your
;;;;       file as it is.
;;;;
;;;;   An error StumpWM itself doesn't catch (in a timer, an X event)
;;;;       StumpWM's answer is to restart: everything is set up again and
;;;;       every file reloaded (*top-level-error-action* :abort; :message is
;;;;       worse, it leaves the desktop frozen in the debugger). Vikix asks
;;;;       first: carry on (a fresh event loop, nothing reloaded), carry on
;;;;       and show the details in Emacs, or restart as StumpWM would.
;;;;
;;;; Every error is also written down in ~/.local/state/vikix/errors/,
;;;; with its backtrace, for `vikix debug` and for whoever fixes it.
;;;;
;;;; The menu is StumpWM's own (select-from-menu), not rofi: it needs no
;;;; other program and no keyboard grab of its own, so it still works when
;;;; things are going wrong. When even it can't be shown, or the same error
;;;; keeps coming back, Vikix does what it did before: report and go on (a
;;;; file), or restart (StumpWM).
;;;;
;;;; (setf *vikix-errors-ask* nil) in user.lisp turns the asking off.

(in-package :stumpwm)

(defvar *vikix-errors-ask* t
  "Ask what to do when something fails. NIL: report it and go on, as before.")

(defvar *vikix-asking* nil
  "True while the menu is open, so an error inside it isn't asked about.")

(defvar *vikix-loading-file* nil
  "The file being loaded, whichever way: from its text here, or from its
compiled copy (init.lisp), when *load-truename* is the copy's.")

;; init.lisp defines it; here for this file loaded by itself (the tests).
(unless (fboundp 'vikix-loading-file)
  (defun vikix-loading-file ()
    "The file a form being loaded is written in, or nil outside a load."
    (or *vikix-loading-file* *load-truename*)))

(defvar *vikix-load-line* nil
  "While a file loads a form at a time: the line the form being loaded
starts on. rules.lisp notes it, so each rule knows where it was written.")

(defparameter *vikix-errors-kept* 50
  "How many error reports to keep in ~/.local/state/vikix/errors/.")

;;; --- Writing it down -----------------------------------------------------------

(defun vikix-state-dir ()
  (let ((state (sb-posix:getenv "VIKIX_STATE")))
    (if (and state (plusp (length state)))
        (uiop:ensure-directory-pathname state)
        (merge-pathnames ".local/state/vikix/" (user-homedir-pathname)))))

(defun vikix-error-report (condition where &optional backtrace)
  "Write CONDITION, WHERE it happened and the BACKTRACE to a file of its own
in ~/.local/state/vikix/errors/; return the file, or NIL when it can't be
written. Old reports beyond *vikix-errors-kept* go."
  (ignore-errors
   (let* ((dir (merge-pathnames "errors/" (vikix-state-dir)))
          (stamp (multiple-value-bind (s m h d mo y) (get-decoded-time)
                   (format nil "~d~2,'0d~2,'0d-~2,'0d~2,'0d~2,'0d" y mo d h m s)))
          (file (loop for n from 0
                      ;; -00, -01...: the names sort in the order they happened.
                      for f = (merge-pathnames (format nil "~a-~2,'0d.txt" stamp n) dir)
                      unless (probe-file f) return f)))
     (ensure-directories-exist dir)
     (with-open-file (out file :direction :output :external-format :utf-8)
       (format out "Vikix: an error ~a~%~%~a~%~%(a ~(~s~))~%~%~@[Backtrace:~%~a~]"
               where condition (type-of condition) backtrace))
     (let ((old (sort (directory (merge-pathnames "*.txt" dir)) #'string> :key #'namestring)))
       (mapc #'delete-file (nthcdr *vikix-errors-kept* old)))
     file)))

(defun vikix-say (control &rest args)
  "MESSAGE, but never an error of its own (no screen yet, say)."
  (ignore-errors (apply #'message control args)))

(defun vikix-shell-quote (string)
  (format nil "'~a'" (ppcre:regex-replace-all "'" string "'\\\\''")))

(defun vikix-open-in-emacs (file &optional line)
  "Show FILE in Emacs (a new frame), at LINE."
  (run-shell-command
   (format nil "emacsclient -n -c -a '' ~@[+~d ~]~a" line (vikix-shell-quote (namestring file)))))

;;; --- Asking ----------------------------------------------------------------------

(defun vikix-one-line (thing &optional (max 160))
  (let ((text (substitute #\Space #\Newline (princ-to-string thing))))
    (if (> (length text) max) (concatenate 'string (subseq text 0 (- max 3)) "...") text)))

(defun vikix-ask (question choices)
  "Show QUESTION with CHOICES, a list of (LABEL VALUE), in StumpWM's menu.
The VALUE picked; NIL when the menu was closed (Escape) or couldn't be
shown at all."
  (unless *vikix-asking*
    (let ((*vikix-asking* t)
          ;; As StumpWM's own restarts menu does: an error in a hook while
          ;; the menu is open would come straight back here.
          (*hooks-enabled-p* nil))
      (ignore-errors
       ;; Shown once as a message first: at startup, a menu that's the first
       ;; thing on screen came out a line short (its last choice hidden
       ;; until a key was pressed).
       (vikix-say "~a" question)
       (second (select-from-menu (current-screen) choices question))))))

;;; --- Mistakes in files -------------------------------------------------------------

(defun vikix-line-at (text position)
  (1+ (count #\Newline text :end (min position (length text)))))

(defun vikix-skip-comments (stream)
  "Move STREAM past blanks and ; comments, so the line given for a form is
its own, not that of the comment above it."
  (loop for c = (peek-char t stream nil nil)
        while (eql c #\;)
        do (read-line stream nil nil)))

(defun vikix-snapshot-file (file)
  "The last snapshot of FILE (in your home) when it differs from FILE now:
(VALUES COPY DATE), COPY being a file in the state folder; NIL when there's
none (`vikix snapshot` keeps them, see `vikix history`)."
  (ignore-errors
   (let* ((home (namestring (user-homedir-pathname)))
          (path (namestring file))
          (relative (and (eql 0 (search home path)) (subseq path (length home))))
          (git (namestring (merge-pathnames "yours.git" (vikix-state-dir))))
          (copy (merge-pathnames "user-last-snapshot.lisp" (vikix-state-dir))))
     (when (and relative (probe-file git))
       (let ((text (run-shell-command
                    (format nil "git --git-dir=~a show HEAD:~a 2>/dev/null"
                            (vikix-shell-quote git) (vikix-shell-quote relative))
                    t))
             (date (string-trim '(#\Newline #\Space)
                                (run-shell-command
                                 (format nil "git --git-dir=~a log -1 --format=%cr 2>/dev/null"
                                         (vikix-shell-quote git))
                                 t))))
         (when (and (plusp (length text))
                    (string/= text (uiop:read-file-string file)))
           (with-open-file (out copy :direction :output :if-exists :supersede :external-format :utf-8)
             (write-string text out))
           (values copy date)))))))

(defvar *vikix-reading* nil
  "True while the loader reads a form (rather than running it): an error
then means the rest of the file can't be read either.")

(defun vikix-describe (condition)
  "CONDITION in words, the reader's own ones made plainer."
  (cond ((and *vikix-reading* (typep condition 'end-of-file))
         "a ( here is never closed: the file ends inside this part")
        ((typep condition 'reader-error)
         (format nil "it can't be read: ~a" (vikix-one-line condition 120)))
        (t (vikix-one-line condition))))

(defun vikix-ask-about-file (condition file name line)
  "Ask what to do about CONDITION, from the form at LINE of FILE, and do it
by invoking one of the loader's restarts."
  (let* ((reading *vikix-reading*)
         (snapshot (and (string= name "user.lisp")
                        (multiple-value-list (vikix-snapshot-file file))))
         (choice
           (vikix-ask
            (format nil "^1Vikix: ~a, line ~d:^n ~a" name line (vikix-describe condition))
            (remove nil
                    (list (unless reading
                            (list "Skip this part, and load the rest of the file" :skip-form))
                          (list (format nil "Open ~a at line ~d in Emacs~:[~;, and load the rest~]"
                                        name line (not reading))
                                :emacs)
                          (when (first snapshot)
                            (list (format nil "Load your last snapshot of ~a instead (~a); yours stays as it is"
                                          name (second snapshot))
                                  :snapshot))
                          (list (format nil "Skip the rest of ~a" name) :skip-file))))))
    (flet ((done (restart what &rest args)
             (vikix-say "^1Vikix: ~a, line ~d:^n ~a~%~a" name line (vikix-describe condition) what)
             (apply #'invoke-restart restart args)))
      (case choice
        (:emacs (vikix-open-in-emacs file line)
         (if reading
             (done 'vikix-skip-file (format nil "Opened in Emacs; the rest of ~a wasn't loaded." name))
             (done 'vikix-skip-form "Opened in Emacs; the rest was loaded.")))
        (:snapshot (done 'vikix-load-instead
                         (format nil "Your last snapshot of ~a was loaded instead; yours is as it was." name)
                         (first snapshot)))
        (:skip-file (done 'vikix-skip-file (format nil "The rest of ~a wasn't loaded." name)))
        ;; Skipping just this part, or the menu closed: go on with the rest.
        (t (if reading
               (done 'vikix-skip-file (format nil "The rest of ~a couldn't be read, so it wasn't loaded." name))
               (done 'vikix-skip-form "That part was skipped; the rest was loaded.")))))))

(defun vikix-eval-from (file form)
  "Evaluate FORM, read from FILE, so that what it defines is known to come
from FILE, as LOAD would record it (M-. in Emacs finds it)."
  (let ((source (find-symbol "*SOURCE-NAMESTRING*" "SB-C")))
    (if (and source (boundp source))
        (progv (list source) (list (namestring (truename file))) (eval form))
        (eval form))))

(defun vikix-load-forms (file &optional (name (file-namestring file)))
  "Load FILE a form at a time. When one fails, the rest still load; with
*vikix-errors-ask*, you're asked what to do (see the top of this file).
Every failure is shown as a message and written down. True when it all
loaded."
  (let* ((text (uiop:read-file-string file))
         (clean t)
         (*package* *package*)
         (*readtable* *readtable*)
         (*load-pathname* (pathname file))
         (*load-truename* (truename file))
         (*vikix-loading-file* (truename file)))
    (with-input-from-string (in text)
      (block file
        (loop
          (vikix-skip-comments in)
          (let* ((start (file-position in))
                 (line (vikix-line-at text start)))
            (restart-case
                (handler-bind
                    ((error (lambda (c)
                              (setf clean nil)
                              (vikix-error-report c (format nil "in ~a, line ~d" name line)
                                                  (backtrace-string))
                              (when *vikix-errors-ask*
                                (vikix-ask-about-file c file name line))
                              ;; Not asking: say so, and go on with the rest.
                              (vikix-say "^1Vikix: error in ~a, line ~d (skipped):^n~%~a" name line c)
                              (invoke-restart (if *vikix-reading* 'vikix-skip-file 'vikix-skip-form)))))
                  (let ((form (let ((*vikix-reading* t)) (read in nil in))))
                    (when (eq form in) (return-from file))
                    (let ((*vikix-load-line* line))
                      (vikix-eval-from file form))))
              (vikix-skip-form ()
                :report "Skip this form and load the rest"
                nil)
              (vikix-skip-file ()
                :report "Skip the rest of the file"
                (return-from file))
              (vikix-load-instead (other)
                :report "Load another file instead"
                (vikix-load-forms other (format nil "~a (your last snapshot)" name))
                (return-from file)))))))
    clean))

;;; --- Errors StumpWM doesn't catch ---------------------------------------------------

(defvar *vikix-recent-errors* '()
  "When the last top-level errors happened (internal real time), newest first.")

(defun vikix-error-storm-p ()
  "True when errors are coming back too often to ask about each: 3 in 20 s."
  (let ((now (get-internal-real-time))
        (window (* 20 internal-time-units-per-second)))
    (setf *vikix-recent-errors*
          (cons now (remove-if (lambda (time) (> (- now time) window)) *vikix-recent-errors*)))
    (>= (length *vikix-recent-errors*) 3)))

(defun vikix-repair-timers ()
  "Make every timer's time a whole number again. A delay given as a float
(run-with-timer 0.3 ...) makes it a float, and StumpWM's event loop fails
on every turn until it's gone: carrying on would just fail again."
  (ignore-errors
   (sb-thread:with-mutex (*timer-list-lock*)
     (dolist (timer *timer-list*)
       (unless (integerp (timer-time timer))
         (setf (timer-time timer) (round (timer-time timer))))))))

(defun vikix-failing-timer ()
  "The timer whose function failed, when the error came from one: found on
the stack, where StumpWM's event loop is running the timers that are due.
Call it while the error is being handled."
  (let ((execute (fdefinition 'execute-timer))
        (functions '())
        (due nil))
    (ignore-errors
     (sb-debug:map-backtrace
      (lambda (frame)
        (unless due
          (multiple-value-bind (name args) (sb-debug::frame-call frame)
            (declare (ignore name))
            (if (and (consp args) (eq (first args) execute) (listp (second args)))
                (setf due (second args))
                (let ((fun (ignore-errors (sb-di:debug-fun-fun (sb-di:frame-debug-fun frame)))))
                  (when fun (push fun functions)))))))))
    (flet ((underlying (f) (if (sb-kernel:closurep f) (sb-kernel:%closure-fun f) f)))
      (or (find-if (lambda (timer)
                     (let ((f (timer-function timer)))
                       (and (functionp f)
                            (member (underlying f) functions
                                    :test (lambda (a b) (or (eq a b) (eq a (underlying b))))))))
                   due)
          ;; Not told apart: the one due timer that repeats is the one that
          ;; would fail again.
          (let ((repeating (remove-if-not #'timer-repeat due)))
            (and (= (length repeating) 1) (first repeating)))))))

(defun vikix-error-hint (condition)
  "A plain word on errors whose message says little, or NIL."
  (when (and (typep condition 'type-error)
             (floatp (type-error-datum condition))
             (some #'timer-p *timer-list*)
             (notevery (lambda (timer) (integerp (timer-time timer))) *timer-list*))
    "A timer was given a delay with a decimal point (like 0.3): StumpWM wants 3/10. Carrying on rounds it."))

(defun vikix-cant-ask-p (condition)
  "Errors no menu can help with: X itself is gone."
  (or (typep condition 'xlib:closed-display)
      (typep condition 'end-of-file)
      (typep condition 'sb-int:broken-pipe)))

(defun vikix-forget-mode-lines ()
  "Take down the bars before StumpWM restarts after an error. Its restart
opens a new X connection and closes the old one, but keeps the bars made
on the old: the first redraw then fails on the closed connection, outside
anything that catches it, and the desktop dies instead of restarting.
(StumpWM's own restart-soft takes them down first; its error path doesn't.)
The layer makes the bars again as it loads."
  (ignore-errors (destroy-all-mode-lines))
  (setf *mode-lines* nil))

(defmethod handle-top-level-condition :around ((c serious-condition))
  ;; StumpWM's own method restarts the desktop (with :abort; :message leaves
  ;; it in the debugger). Ask first; anything but carrying on is that.
  (let ((carry-on (find-restart :new-io-loop)))
    (flet ((restart-desktop ()
             (when (eq *top-level-error-action* :abort)
               (vikix-forget-mode-lines))
             (call-next-method)))
      (if (or (not *vikix-errors-ask*)
              *vikix-asking*
              (not carry-on)
              (not (typep c 'error))
              (not (eq *top-level-error-action* :abort))
              (vikix-cant-ask-p c))
          (restart-desktop)
          (let* ((backtrace (backtrace-string))
                 (timer (vikix-failing-timer))
                 (stop-timer (and timer (timer-repeat timer)))
                 (hint (vikix-error-hint c))
                 (report (vikix-error-report c (format nil "StumpWM didn't catch~@[ (~a)~]" hint) backtrace))
                 (storm (vikix-error-storm-p))
                 (choice (unless storm
                           (vikix-ask
                            (format nil "^1Vikix: something failed:^n ~a~@[~%~a~]" (vikix-one-line c) hint)
                            `((,(if stop-timer
                                    "Carry on, stopping the timer that failed (it would fail again)"
                                    "Carry on (your windows and settings stay as they are)")
                               :carry-on)
                              ,@(when report
                                  '(("Carry on, and show what happened in Emacs" :emacs)))
                              ("Restart the desktop: set everything up again, reloading your files"
                               :restart))))))
            (cond (storm
                   (vikix-say "^1Vikix: errors keep coming: restarting the desktop.^n~@[~%Details: ~a~]"
                              (and report (namestring report)))
                   (restart-desktop))
                  ((eq choice :restart)
                   (restart-desktop))
                  (t
                   ;; Carrying on, or the menu closed (Escape): a fresh
                   ;; event loop, nothing reloaded.
                   (when (eq choice :emacs) (vikix-open-in-emacs report))
                   (when stop-timer (ignore-errors (cancel-timer timer)))
                   (vikix-repair-timers)
                   (vikix-say "^1Vikix:^n carried on after: ~a~@[~%Details: ~a~]"
                              (vikix-one-line c) (and report (namestring report)))
                   (invoke-restart carry-on))))))))
