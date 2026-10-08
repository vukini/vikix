;;;; resume.lisp — your windows back after a restart.
;;;;
;;;; Every few minutes, and when the desktop ends, each workspace is saved
;;;; as layouts.lisp saves one by name: which windows, where they stand,
;;;; and how each was started. At the next login they can come back: each
;;;; workspace in turn is put back as it was, its programs started again
;;;; in their folders, and you end on the workspace you were on.
;;;;
;;;;   vikix resume                    what is saved, and what happens at login
;;;;   vikix resume now                bring the windows back now
;;;;   vikix resume save               save now
;;;;   vikix resume ask|always|never   at login: ask first (as it starts),
;;;;                                   bring them back unasked, or leave it
;;;;
;;;; What comes back is what layouts.lisp can start again: a terminal in
;;;; its folder with the program that ran in it, a program by its command
;;;; line, a web app, an Emacs frame on its file. What a program had open
;;;; inside it is its own to bring back (Firefox does its tabs).
;;;;
;;;; The saved workspaces are layouts like any other, kept apart from yours
;;;; in ~/.local/state/vikix/resume/ (workspace-3.lisp ...), with index.lisp
;;;; saying when and which. Whether to ask is ~/.config/vikix/resume.

(in-package :stumpwm)

(defparameter *vikix-resume-dir*
  (merge-pathnames ".local/state/vikix/resume/" (user-homedir-pathname))
  "Where the workspaces are saved for coming back.")
(defparameter *vikix-resume-setting-file*
  (merge-pathnames ".config/vikix/resume" (user-homedir-pathname))
  "One word: ask, always or never.")
(defparameter *vikix-resume-every* 300
  "Seconds between saves by itself (a whole number: it is a timer's).")
(defparameter *vikix-resume-wait* 20
  "Seconds a workspace's programs are given to open their windows before
the next workspace has its turn.")

(defvar *vikix-resume-timer* nil)
(defvar *vikix-resume-decided* nil
  "True once this login's question is settled: before that nothing is
saved, or an empty desktop just logged in to would replace what was saved.")
(defvar *vikix-resume-run* nil
  "While windows are coming back: (:queue NUMBERS :number N :since TIME
:started SPECS :current N :asked COUNT :back COUNT), for the timer's steps.")
(defvar *vikix-resume-step-timer* nil)

;;; --- Saving ----------------------------------------------------------------------

(defun vikix-resume-name (number) (format nil "workspace-~d" number))

(defun vikix-resume-windows (group)
  "GROUP's windows that have a place in a layout: a strip's columns (every
window of a strip floats, to StumpWM), a tiled workspace's tiles; not the
dialogs and other windows floating over them."
  (remove-if (if (viri-group-p group)
                 #'viri-floats-p
                 (lambda (w) (typep w 'float-window)))
             (group-windows group)))

(defun vikix-resume-groups ()
  "The workspaces worth saving: yours (1 and up, not the hidden ones),
tiled or a strip, with a window."
  (remove-if-not (lambda (group)
                   (and (plusp (group-number group))
                        (char/= (char (group-name group) 0) #\.)
                        (or (viri-group-p group) (typep group 'tile-group))
                        (vikix-resume-windows group)))
                 (sort (copy-list (screen-groups (current-screen))) #'< :key #'group-number)))

(defun vikix-resume-index ()
  "What is saved: (:saved TIME :current NUMBER :workspaces ((NUMBER WINDOWS NAME) ...)), or nil.
NAME is the workspace's name: a named one (past the nine, groups.lisp) is
made again at login before its windows come back."
  (ignore-errors
   (with-open-file (in (merge-pathnames "index.lisp" *vikix-resume-dir*) :if-does-not-exist nil)
     (when in
       (with-standard-io-syntax
         (let ((*read-eval* nil) (*package* (find-package :cl-user)))
           (let ((index (read in nil nil)))
             (and (listp index) (getf index :workspaces) index))))))))

(defun vikix-resume-save ()
  "Save every workspace that has windows. Returns how many windows; with
none, what was saved before is left as it is."
  (let ((*vikix-layouts-dir* *vikix-resume-dir*)
        (saved '()))
    (dolist (group (vikix-resume-groups))
      (when (ignore-errors (vikix-layout-save (vikix-resume-name (group-number group)) group))
        (push (list (group-number group) (length (vikix-resume-windows group)) (group-name group)) saved)))
    (setf saved (nreverse saved))
    (when saved
      ;; The workspaces that have no windows any more.
      (dolist (file (directory (merge-pathnames "workspace-*.lisp" *vikix-resume-dir*)))
        (unless (member (pathname-name file) saved
                        :test (lambda (name entry) (string= name (vikix-resume-name (first entry)))))
          (ignore-errors (delete-file file))))
      (ignore-errors
       (with-open-file (out (merge-pathnames "index.lisp" *vikix-resume-dir*)
                            :direction :output :if-exists :supersede)
         (with-standard-io-syntax
           (let ((*package* (find-package :cl-user)) (*print-case* :downcase))
             (format out ";; Vikix: the workspaces saved for coming back after a restart (resume.lisp).~%")
             (prin1 (list :saved (get-universal-time)
                          :current (group-number (current-group))
                          :workspaces saved)
                    out)
             (terpri out))))))
    (reduce #'+ saved :key #'second)))

(defun vikix-resume-tick ()
  "The timer's save: once this login's question is settled, and not while
windows are still coming back."
  (when (and *vikix-resume-decided* (not *vikix-resume-run*))
    (ignore-errors (vikix-resume-save))))

(defun vikix-resume-at-quit ()
  (when (and *vikix-resume-decided* (not *vikix-resume-run*))
    (ignore-errors (vikix-resume-save))))

;;; --- In words ----------------------------------------------------------------------

(defun vikix-resume-setting ()
  "At login: :ask (when nothing says otherwise), :always or :never."
  (let ((word (ignore-errors
               (with-open-file (in *vikix-resume-setting-file* :if-does-not-exist nil)
                 (and in (string-trim '(#\Space #\Tab) (or (read-line in nil "") "")))))))
    (cond ((equal word "always") :always)
          ((equal word "never") :never)
          (t :ask))))

(defun vikix-resume-set (setting)
  (ensure-directories-exist *vikix-resume-setting-file*)
  (with-open-file (out *vikix-resume-setting-file* :direction :output :if-exists :supersede)
    (format out "~(~a~)~%" setting))
  setting)

(defun vikix-resume-when (time)
  "TIME as you'd say it: today at 09:12, yesterday at 18:40, 3 Oct at 09:12."
  (multiple-value-bind (s mi h d mo) (decode-universal-time time)
    (declare (ignore s))
    (multiple-value-bind (s2 mi2 h2 d2 mo2) (decode-universal-time (get-universal-time))
      (declare (ignore s2 mi2 h2))
      (multiple-value-bind (s3 mi3 h3 d3 mo3) (decode-universal-time (- (get-universal-time) 86400))
        (declare (ignore s3 mi3 h3))
        (format nil "~a at ~2,'0d:~2,'0d"
                (cond ((and (= d d2) (= mo mo2)) "today")
                      ((and (= d d3) (= mo mo3)) "yesterday")
                      (t (format nil "~d ~a" d (nth (1- mo) '("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")))))
                h mi)))))

(defun vikix-resume-summary (&optional (index (vikix-resume-index)))
  "What is saved, in a line; nil when nothing is."
  (when index
    (let ((workspaces (getf index :workspaces)))
      (format nil "~d window~:p on ~d workspace~:p, saved ~a"
              (reduce #'+ workspaces :key #'second)
              (length workspaces)
              (vikix-resume-when (getf index :saved))))))

;;; --- Bringing them back ------------------------------------------------------------
;;;
;;; A layout is put back on the workspace in view, and its programs' windows
;;; open there. So the workspaces take turns: go there, put it back, wait
;;; for its windows (or *vikix-resume-wait* seconds), then the next. A
;;; timer does the steps, a second apart: nothing here waits.

(defun vikix-resume-group (number &optional name)
  "The workspace saved as NUMBER (and NAME): by its name first, since a
named workspace made again at login may have another number; a named one
that is gone is made again (groups.lisp)."
  (let ((groups (screen-groups (current-screen))))
    (or (and name (find name groups :key #'group-name :test #'equal))
        (and (null name) (find number groups :key #'group-number))
        (and name (fboundp 'vikix-workspace-name-ok) (funcall 'vikix-workspace-name-ok name)
             (ignore-errors (funcall 'vikix-workspace-make name))))))

(defun vikix-resume-open (specs group)
  "How many of SPECS have a window in GROUP now."
  (let ((windows (vikix-resume-windows group)))
    (count-if (lambda (spec) (first (vikix-layout-match (list spec) windows))) specs)))

(defun vikix-resume-finish ()
  (let* ((run *vikix-resume-run*)
         (current (vikix-resume-group (getf run :current)))
         (asked (getf run :asked)) (back (getf run :back)))
    (when (timer-p *vikix-resume-step-timer*) (cancel-timer *vikix-resume-step-timer*))
    (setf *vikix-resume-step-timer* nil
          *vikix-resume-run* nil)
    (when current (ignore-errors (switch-to-group current)))
    (ignore-errors (vikix-resume-save))
    (message "Your windows are back~:[: ~d of ~d (the others can't be started again, or took too long)~;.~*~*~]"
             (>= back asked) back asked)))

(defun vikix-resume-step ()
  "One step: start the next workspace, or see whether this one's windows are there."
  (handler-case
      (let* ((run *vikix-resume-run*)
             (number (getf run :number))
             (group (and number (vikix-resume-group number (getf run :name)))))
        (cond
          ((null run))
          ;; Waiting for this workspace's windows.
          ((and number group
                (< (vikix-resume-open (getf run :started) group) (length (getf run :started)))
                (< (- (get-universal-time) (getf run :since)) *vikix-resume-wait*)))
          (t
           (when (and number group)
             ;; Once more, now that they're all there (or time is up).
             (let ((*vikix-layouts-dir* *vikix-resume-dir*))
               (ignore-errors (vikix-layout-restore (vikix-resume-name number) group :start nil)))
             (incf (getf *vikix-resume-run* :back)
                   (let ((layout-windows (getf run :wanted)))
                     (min layout-windows
                          (length (vikix-resume-windows (or (vikix-resume-group number (getf run :name)) group)))))))
           (let ((next (pop (getf *vikix-resume-run* :queue))))
             (if (null next)
                 (vikix-resume-finish)
                 (destructuring-bind (next-number wanted &optional next-name) next
                   (let ((next-group (vikix-resume-group next-number next-name)))
                     (setf (getf *vikix-resume-run* :number) next-number
                           (getf *vikix-resume-run* :name) next-name
                           (getf *vikix-resume-run* :wanted) wanted
                           (getf *vikix-resume-run* :since) (get-universal-time)
                           (getf *vikix-resume-run* :started) '())
                     (when next-group
                       (switch-to-group next-group)
                       (let ((*vikix-layouts-dir* *vikix-resume-dir*))
                         (multiple-value-bind (missing started)
                             (vikix-layout-restore (vikix-resume-name next-number) next-group :start t)
                           (declare (ignore missing))
                           (setf (getf *vikix-resume-run* :started) started)))))))))))
    (error (e)
      (vikix-say "^1Vikix: bringing your windows back stopped:^n ~a" (vikix-one-line e))
      (ignore-errors (vikix-resume-finish)))))

(defun vikix-resume-now ()
  "Bring back the windows saved before the restart. Returns the summary of
what was saved, or nil when there is nothing."
  (let ((index (vikix-resume-index)))
    (cond ((null index) nil)
          (*vikix-resume-run* (vikix-resume-summary index))
          (t
           (setf *vikix-resume-run*
                 (list :queue (copy-list (getf index :workspaces))
                       :number nil :name nil :wanted 0 :since 0 :started '()
                       :current (or (getf index :current) 1)
                       :asked (reduce #'+ (getf index :workspaces) :key #'second)
                       :back 0)
                 *vikix-resume-decided* t)
           (when (timer-p *vikix-resume-step-timer*) (cancel-timer *vikix-resume-step-timer*))
           (setf *vikix-resume-step-timer* (run-with-timer 1 1 'vikix-resume-step))
           (vikix-resume-summary index)))))

(defcommand vikix-resume () ()
  "Bring back the windows from before the restart: each workspace as it was, its programs started again."
  (let ((summary (vikix-resume-now)))
    (message "~:[Nothing is saved to bring back yet.~;Bringing back ~:*~a ...~]" summary)))

;;; --- At login -----------------------------------------------------------------------

(defun vikix-resume-new-login-p ()
  "True the first time it is asked in a login. The note is on X's root
window, which lasts as long as a login does: a reload, or StumpWM starting
again in the same login, finds it."
  (let ((root (screen-root (first *screen-list*))))
    (unless (xlib:get-property root :_VIKIX_RESUME)
      (xlib:change-property root :_VIKIX_RESUME '(1) :cardinal 32)
      t)))

(defun vikix-resume-at-login ()
  "Once the desktop is up: in a new login with windows saved, bring them
back, ask, or leave it, as ~/.config/vikix/resume says."
  (handler-case
      (let ((index (and (vikix-resume-new-login-p) (vikix-resume-index))))
        (when index
          (ecase (vikix-resume-setting)
            (:never)
            (:always (vikix-resume-now))
            (:ask
             (case (vikix-ask (format nil "Your windows from before: ~a. Bring them back?"
                                      (vikix-resume-summary index))
                              '(("Bring them back" :yes)
                                ("Not now (Super+m, Bring my windows back, does it later)" :no)
                                ("Always bring them back, without asking" :always)
                                ("Never, and don't ask" :never)))
               (:yes (vikix-resume-now))
               (:always (vikix-resume-set :always) (vikix-resume-now))
               (:never (vikix-resume-set :never)))))))
    (error (e) (vikix-say "^1Vikix: your windows from before:^n ~a" (vikix-one-line e))))
  (setf *vikix-resume-decided* t))

(remove-hook *quit-hook* 'vikix-resume-at-quit)
(add-hook *quit-hook* 'vikix-resume-at-quit)

(when (and (boundp '*screen-list*) *screen-list*)
  (when (timer-p *vikix-resume-timer*) (cancel-timer *vikix-resume-timer*))
  (setf *vikix-resume-timer* (run-with-timer *vikix-resume-every* *vikix-resume-every* 'vikix-resume-tick))
  ;; A moment after the files are loaded, so yours (user.lisp) are too.
  (unless *vikix-resume-decided*
    (run-with-timer 2 nil 'vikix-resume-at-login)))
