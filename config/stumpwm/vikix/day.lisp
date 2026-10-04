;;;; day.lisp — what had the screen, written down for `vikix day`.
;;;;
;;;; The desktop is the one witness to the day: which workspace and which
;;;; program were in front, and for how long. Every 30 seconds (the rules'
;;;; ticker, never a hook on the focus: nothing here runs while a window
;;;; changes) this looks at the focused window and writes a line when it
;;;; isn't the one written last, into
;;;; ~/.local/state/vikix/day/screen-YYYY-MM.log (yours alone, 600):
;;;;
;;;;   TIME  focus  WORKSPACE  PROJECT  CLASS  FOLDER
;;;;   TIME  away   SECONDS    nobody at the keyboard for that long already
;;;;   TIME  beat              the same window still, five minutes on
;;;;   TIME  start             StumpWM started
;;;;   TIME  rule   NAME       a rule ran
;;;;
;;;; TIME is seconds since 1970, the fields are apart by tabs. PROJECT is
;;;; the project the workspace was opened for (vikix project open), FOLDER
;;;; the folder the window's program is in (a terminal's shell's). Never a
;;;; window's title: a title is a page's name, a file's, a message's.
;;;;
;;;; `vikix day` adds the lines up. A line every five minutes at least says
;;;; the desktop was running, so a gap longer than that (a suspend, a power
;;;; cut) is counted as time away, not as time on the last window.
;;;;
;;;; To keep nothing: (setf *vikix-day-on* nil) in user.lisp.

(in-package :stumpwm)

(defvar *vikix-day-on* t
  "NIL: nothing about the screen is written down.")

(defparameter *vikix-day-idle* 300
  "Seconds without a key or the pointer after which you're away.")

(defparameter *vikix-day-beat* 300
  "A line at least this often, in seconds, while the desktop runs.")

(defvar *vikix-day-last* nil
  "What the last focus line said, so the same window isn't written twice.")

(defvar *vikix-day-written* 0
  "When the last line was written (universal time).")

(defvar *vikix-day-away* nil
  "True from the away line until somebody is back.")

(defvar *vikix-back-after* 600
  "Back after at least this many seconds away (a break, a lock, a meeting),
the desktop shows where you were: vikix back --card. NIL: never.")

(defvar *vikix-day-away-since* nil
  "When the time away began (universal time), for vikix back.")

(defvar *vikix-day-started* nil
  "True once this StumpWM has written its start line: a reload writes no second one.")

(defun vikix-day-unix (time)
  (- time 2208988800))   ; universal time counts from 1900

(defun vikix-day-file (time)
  "The log of TIME's month."
  (multiple-value-bind (s mi h d month year) (decode-universal-time time)
    (declare (ignore s mi h d))
    (merge-pathnames (format nil "day/screen-~4,'0d-~2,'0d.log" year month)
                     (vikix-state-dir))))

(defun vikix-day-field (value)
  "VALUE as one field: no tab or new line in it."
  (substitute-if #\Space (lambda (c) (member c '(#\Tab #\Newline #\Return)))
                 (if (stringp value) value (format nil "~@[~a~]" value))))

(defun vikix-day-write (time kind &rest fields)
  "One line. Never an error: this runs in StumpWM's timer."
  (ignore-errors
   (let* ((file (vikix-day-file time))
          (new (not (probe-file file))))
     (ensure-directories-exist file)
     (with-open-file (out file :direction :output :if-exists :append
                               :if-does-not-exist :create :external-format :utf-8)
       (format out "~d~c~a~{~c~a~}~%" (vikix-day-unix time) #\Tab kind
               (loop for f in fields collect #\Tab collect (vikix-day-field f))))
     (when new
       (ignore-errors (sb-posix:chmod (namestring file) #o600)))
     (setf *vikix-day-written* time)
     t)))

(defun vikix-day-folder (window)
  "The folder WINDOW's program is in: three processes down at most, so a
terminal's shell, and what runs in the shell. The one Emacs is in no
folder of its window's."
  (let ((pid (and (not (equal (window-class window) "Emacs")) (vikix-window-pid window))))
    (when pid
      (loop repeat 3
            for child = (ignore-errors
                         (with-open-file (in (format nil "/proc/~d/task/~d/children" pid pid))
                           (parse-integer (read-line in nil "") :junk-allowed t)))
            while child do (setf pid child))
      (vikix-proc-cwd pid))))

(defun vikix-day-now ()
  "What has the screen: (WORKSPACE PROJECT CLASS FOLDER), strings all."
  (let* ((group (current-group))
         (window (group-current-window group)))
    (list (or (group-name group) "")
          (or (gethash group *vikix-project-groups*) "")
          (or (and window (window-class window)) "")
          (or (and window (ignore-errors (vikix-day-folder window))) ""))))

(defun vikix-day-idle-seconds ()
  (or (ignore-errors (floor (idle-time (current-screen)))) 0))

(defun vikix-day-tick (&optional (time (get-universal-time)) (idle (vikix-day-idle-seconds)))
  "Write down what has the screen, when it changed. Called by the rules'
ticker; TIME and IDLE are arguments for the tests."
  (when *vikix-day-on*
    (unless *vikix-day-started*
      (setf *vikix-day-started* t)
      (vikix-day-write time "start"))
    (if (>= idle *vikix-day-idle*)
        (unless *vikix-day-away*
          (setf *vikix-day-away* t
                *vikix-day-away-since* (- time idle)
                *vikix-day-last* nil)
          (vikix-day-write time "away" idle))
        (let ((now (vikix-day-now)))
          (when (and *vikix-day-away* *vikix-back-after* *vikix-day-away-since*
                     (>= (- time *vikix-day-away-since*) *vikix-back-after*))
            (vikix-back-card))
          (cond ((or *vikix-day-away* (not (equal now *vikix-day-last*)))
                 (setf *vikix-day-away* nil
                       *vikix-day-last* now)
                 (apply #'vikix-day-write time "focus" now))
                ((>= (- time *vikix-day-written*) *vikix-day-beat*)
                 (vikix-day-write time "beat")))))))

(defun vikix-back-card ()
  "Where you were, as a notification: you're back after a while away."
  (ignore-errors (run-shell-command "vikix back --card")))

(defun vikix-day-rule-ran (rule)
  "A rule ran: its name, or the start of its text. Called by vikix-run-rule."
  (when *vikix-day-on*
    (let ((text (or (vikix-rule-name rule) (vikix-one-line (or (vikix-rule-text rule) "")))))
      (vikix-day-write (get-universal-time) "rule"
                       (subseq text 0 (min 80 (length text)))))))
