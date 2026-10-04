;;;; drawer.lisp — the drawer: a few everyday programs in a column at the
;;;; screen's edge, out and away with one key (s-C-b).
;;;;
;;;; A calculator, the files, a page of notes: wanted often, for a moment,
;;;; on whatever workspace you're on, and in the way the rest of the time.
;;;; The drawer keeps them running and out of sight. The key slides them in
;;;; from the edge, one above the other, over the windows (which stay as
;;;; they are); the key again slides them away, and each keeps what it had:
;;;; the calculator its sums, the files their folder.
;;;;
;;;; Yours to set, in user.lisp:
;;;;
;;;;   (setf *vikix-drawer-apps*
;;;;         '(("Calculator" "speedcrunch")
;;;;           ("Files" "esploro --new ~" :class "Emacs" :title "Esploro")
;;;;           ("Notes" "emacsclient -c -n -a '' -F '((name . \"Notes\"))' ~/notes.org"
;;;;            :class "Emacs" :title "Notes")))
;;;;   (setf *vikix-drawer-side* :left)
;;;;   (setf *vikix-drawer-width* "35%")
;;;;
;;;; A program is started the first time the drawer opens (and again when
;;;; you closed it). Its window is the drawer's whatever your rules say of
;;;; that program. It is known by the program that made it; one
;;;; whose window another program makes (an Emacs frame is the server's, a
;;;; second PCManFM the first one's) says how to know it, as a rule does:
;;;; :class, :instance, :title, :role. Away, the windows wait on a hidden
;;;; workspace, ".drawer", as the drop-down terminal's does. A window of the
;;;; drawer tiled with Super+t is an ordinary window from then on.

(in-package :stumpwm)

(defparameter *vikix-drawer-apps*
  (list (list "Terminal" (if (boundp '*vikix-terminal*) (symbol-value '*vikix-terminal*) "alacritty"))
        (list "Files" "pcmanfm" :class "Pcmanfm"))
  "The drawer's programs, top to bottom: (NAME COMMAND [MATCH...]). COMMAND
is a shell command; MATCH, as in a rule (:class \"Emacs\" :title \"Notes\"),
is for a program whose window comes from another process.")

(defparameter *vikix-drawer-side* :right
  "The edge the drawer is at: :right or :left.")

(defparameter *vikix-drawer-width* "30%"
  "How wide the drawer is: pixels, or a share of the monitor like \"30%\".")

(defparameter *vikix-drawer-wait* 30
  "Seconds a program started for the drawer is given to show its window.")

(defparameter *vikix-drawer-group-name* ".drawer"
  "The hidden workspace the drawer's windows wait on.")

(defvar *vikix-drawer-windows* (make-hash-table :test 'eq :weakness :key)
  "The drawer's windows, each with the name of its program.")

(defvar *vikix-drawer-pending* nil
  "Programs started whose window hasn't come: (NAME PID STARTED).")

(defvar *vikix-drawer-group* nil
  "The workspace the drawer was brought out on; nil when it is away. A
workspace made a strip, or tiles again, is a new one to StumpWM: where the
drawer is now is asked of its windows (vikix-drawer-home).")

(defvar *vikix-drawer-before* nil
  "The window that had the focus when the drawer came out.")

(defvar *vikix-drawer-matchers* (make-hash-table :test 'equal)
  "A program's MATCH as a function of a window, made once.")

;;; --- Whose window is it -------------------------------------------------------------------

(defun vikix-drawer-window-p (window)
  "True for a window of the drawer."
  (and (gethash window *vikix-drawer-windows*) t))

(defun vikix-drawer-mark (window name)
  "WINDOW is the drawer's, NAME's. Written on the window too, so a desktop
started again knows it."
  (setf (gethash window *vikix-drawer-windows*) name)
  (ignore-errors
   (xlib:change-property (window-xwin window) :_VIKIX_DRAWER
                         (sb-ext:string-to-octets name :external-format :utf-8)
                         :utf8_string 8)))

(defun vikix-drawer-unmark (window)
  (remhash window *vikix-drawer-windows*)
  (ignore-errors (xlib:delete-property (window-xwin window) :_VIKIX_DRAWER)))

(defun vikix-drawer-marked-name (window)
  "The program's name written on WINDOW, or nil."
  (ignore-errors
   (let ((octets (xlib:get-property (window-xwin window) :_VIKIX_DRAWER)))
     (and octets
          (sb-ext:octets-to-string (coerce octets '(vector (unsigned-byte 8)))
                                   :external-format :utf-8)))))

(defun vikix-drawer-windows ()
  "The drawer's windows that are open, top to bottom: in the order of
*vikix-drawer-apps*, then any whose program is no longer named there. One
that was tiled (Super+t) has left the drawer."
  (let ((open nil))
    (dolist (w (screen-windows (current-screen)))
      (when (vikix-drawer-window-p w)
        (if (typep w 'float-window)
            (push w open)
            (vikix-drawer-unmark w))))
    (flet ((place (w)
             (or (position (gethash w *vikix-drawer-windows*) *vikix-drawer-apps*
                           :key #'first :test #'equal)
                 (length *vikix-drawer-apps*))))
      (stable-sort (nreverse open) #'< :key #'place))))

(defun vikix-drawer-parent-pid (pid)
  "The process that started PID, from /proc; nil when it has gone."
  (ignore-errors
   (with-open-file (in (format nil "/proc/~d/stat" pid))
     ;; "PID (name) S PPID ...": the name may hold anything, so from its end.
     (let* ((line (read-line in))
            (end (position #\) line :from-end t)))
       (parse-integer line :start (+ end 4) :junk-allowed t)))))

(defun vikix-drawer-started-by-p (window pid)
  "Was WINDOW made by the process PID, or by one it started?"
  (let ((mine (ignore-errors (first (xlib:get-property (window-xwin window) :_NET_WM_PID)))))
    (and pid mine
         (loop repeat 8
               for p = mine then (vikix-drawer-parent-pid p)
               while (and p (> p 1))
                 thereis (= p pid)))))

(defun vikix-drawer-matches-p (match window)
  "Does WINDOW fit MATCH, a rule's matchers (rules.lisp)?"
  (let ((test (or (gethash match *vikix-drawer-matchers*)
                  (setf (gethash match *vikix-drawer-matchers*)
                        (compile nil `(lambda (w) ,(vikix-rule-match-code match 'w)))))))
    (and (funcall test window) t)))

(defun vikix-drawer-pending-for (window)
  "The program waiting for a window that WINDOW is: its entry in
*vikix-drawer-pending*, or nil. One that has waited too long waits no more."
  (let ((now (get-universal-time)))
    (setf *vikix-drawer-pending*
          (remove-if (lambda (p) (> (- now (third p)) *vikix-drawer-wait*)) *vikix-drawer-pending*))
    (and (not (window-transient-p window))
         (find-if (lambda (p)
                    (let ((match (cddr (assoc (first p) *vikix-drawer-apps* :test #'equal))))
                      (if match
                          (ignore-errors (vikix-drawer-matches-p match window))
                          (vikix-drawer-started-by-p window (second p)))))
                  *vikix-drawer-pending*))))

(defun vikix-drawer-wanted-p (window)
  "True for a window opening that the drawer started a program for."
  (and *vikix-drawer-pending*
       (not (vikix-drawer-window-p window))
       (vikix-drawer-pending-for window)
       t))

;;; --- Where it stands ----------------------------------------------------------------------

(defun vikix-drawer-park ()
  "The hidden workspace the drawer's windows wait on."
  (let ((screen (current-screen)))
    (or (find-group screen *vikix-drawer-group-name*)
        (add-group screen *vikix-drawer-group-name* :background t))))

;; As a floating window leaves a tiled workspace, StumpWM gives the focus to
;; another floating one there, and showing it is part of that: on the hidden
;; workspace it would put a window of the drawer on the screen while the
;; drawer is away. Nothing there needs the focus.
(defmethod group-delete-window :around ((group tile-group) (window float-window))
  (unless (equal (group-name group) *vikix-drawer-group-name*)
    (call-next-method)))

(defun vikix-drawer-spots (head n)
  "Where the drawer's N windows stand on HEAD, top to bottom: a list of
(x y width height), the whole of each window, sharing the height below
the bar."
  (multiple-value-bind (ax ay aw ah) (vikix-rule-area head)
    (let* ((w (max 120 (min aw (or (vikix-rule-length *vikix-drawer-width* aw "The drawer's width")
                                   (floor (* 30 aw) 100)))))
           (x (if (eq *vikix-drawer-side* :left) ax (+ ax (- aw w))))
           (each (floor ah (max 1 n))))
      (loop for i below n
            collect (list x (+ ay (* i each)) w (if (= i (1- n)) (- ah (* i each)) each))))))

(defun vikix-drawer-away-x (head width)
  "The x at which a window of the drawer is just off HEAD's edge."
  (if (eq *vikix-drawer-side* :left)
      (- (head-x head) width)
      (+ (head-x head) (head-width head))))

(defun vikix-drawer-put (window spot &optional x)
  "WINDOW at SPOT (x y width height), or at X instead of the spot's own.
The spot is the whole window's: StumpWM's strip at its top and its border
inside it, and the border X draws around it."
  (destructuring-bind (sx y w h) spot
    (let ((edge (* 2 (xlib:drawable-border-width (window-parent window)))))
      (float-window-move-resize window
                                :x (or x sx) :y y
                                :width (max 1 (- w edge (* 2 *float-window-border*)))
                                :height (max 1 (- h edge *float-window-title-height* *float-window-border*))))))

(defun vikix-drawer-raise (&optional (group (current-group)))
  "The drawer's windows on GROUP above the others, and a dialog above them."
  (let ((raised nil))
    (dolist (w (group-windows group))
      (when (and (vikix-drawer-window-p w) (typep w 'float-window) (window-visible-p w))
        (setf (xlib:window-priority (window-parent w)) :above
              raised t)))
    (when raised
      (dolist (w (group-windows group))
        (when (and (typep w 'float-window) (not (vikix-drawer-window-p w))
                   (fboundp 'vikix-dialog-p) (funcall 'vikix-dialog-p w)
                   (window-visible-p w))
          (setf (xlib:window-priority (window-parent w)) :above))))))

(defun vikix-drawer-slides-p (group)
  "Does the drawer slide (as a strip does, viri.lisp), or jump?"
  (and (fboundp 'viri-animate-p) (funcall 'viri-animate-p group)))

(defun vikix-drawer-slide (windows from-x to-x)
  "Carry WINDOWS sideways, a step at a time, from FROM-X to TO-X. Sleeps
between the steps, in the main thread, as a strip's slide does: never a timer."
  (let ((pause (/ (symbol-value '*viri-animate-seconds*) (symbol-value '*viri-animate-frames*))))
    (dolist (x (funcall 'viri-slide-offsets from-x to-x))
      (dolist (w windows)
        (setf (xlib:drawable-x (window-parent w)) x))
      (xlib:display-finish-output *display*)
      (sleep pause))))

(defun vikix-drawer-arrange (group &optional slide)
  "The drawer's windows on GROUP into their column, raised. With SLIDE they
come in from the edge."
  (let* ((windows (remove group (vikix-drawer-windows) :key #'window-group :test-not #'eq))
         (head (current-head group))
         (spots (vikix-drawer-spots head (length windows))))
    (when windows
      (let* ((width (third (first spots)))
             (away (vikix-drawer-away-x head width))
             (slides (and slide (eq group (current-group)) (vikix-drawer-slides-p group))))
        (loop for w in windows for spot in spots
              do (vikix-drawer-put w spot (and slides away))
                 (when (window-hidden-p w) (unhide-window w)))
        (vikix-drawer-raise group)
        (when slides
          (xlib:display-finish-output *display*)
          (vikix-drawer-slide windows away (first (first spots)))
          (loop for w in windows for spot in spots do (vikix-drawer-put w spot)))))
    windows))

;;; --- Starting its programs ----------------------------------------------------------------

(defun vikix-drawer-start (app)
  "Start APP's program and wait for its window."
  (destructuring-bind (name command &rest match) app
    (declare (ignore match))
    (let* ((process (ignore-errors (run-prog *shell-program* :args (list "-c" command) :wait nil)))
           (pid (and process (sb-ext:process-p process) (sb-ext:process-pid process))))
      (push (list name pid (get-universal-time)) *vikix-drawer-pending*))))

(defun vikix-drawer-missing ()
  "The programs with no window in the drawer, and none on its way."
  (let ((have (mapcar (lambda (w) (gethash w *vikix-drawer-windows*)) (vikix-drawer-windows)))
        (now (get-universal-time)))
    (setf *vikix-drawer-pending*
          (remove-if (lambda (p) (> (- now (third p)) *vikix-drawer-wait*)) *vikix-drawer-pending*))
    (remove-if (lambda (app)
                 (or (member (first app) have :test #'equal)
                     (member (first app) *vikix-drawer-pending* :key #'first :test #'equal)))
               *vikix-drawer-apps*)))

(defun vikix-drawer-take (window)
  "WINDOW has opened for the drawer: it floats, and joins the column where
the drawer is out, or waits with the others when it has been put away
meanwhile."
  (let ((p (vikix-drawer-pending-for window))
        (home (vikix-drawer-home)))     ; asked before WINDOW is one of them
    (when p
      (setf *vikix-drawer-pending* (remove p *vikix-drawer-pending*))
      (when (typep window 'tile-window)
        (vikix-rule-float-it window))
      (when (typep window 'float-window)
        (vikix-drawer-mark window (first p))
        (cond ((null home) (move-window-to-group window (vikix-drawer-park)))
              (t (unless (eq (window-group window) home)
                   (move-window-to-group window home))
                 (vikix-drawer-arrange home)
                 (when (eq home (current-group))
                   (group-focus-window home (first (vikix-drawer-windows)))
                   (vikix-drawer-raise home))))))))

;; A hook, not a rule. Vikix's rules run before yours, and a rule of yours
;; for the same program (SpeedCrunch on workspace 1, at this size) would then
;; take the drawer's window out of the drawer again. The drawer takes its
;; windows after every rule has had its say, and before a grid or main and
;; stack look at what opened (windows.lisp): they leave a floating window be.
(defun vikix-drawer-new-window (window)
  (handler-case
      (when (vikix-drawer-wanted-p window)
        (vikix-drawer-take window))
    (error (e) (message "The drawer: ~a" e))))

(setf *new-window-hook*
      (let* ((others (remove 'vikix-drawer-new-window *new-window-hook*))
             (rules (position 'vikix-rules-new-window others)))
        (if rules
            (append (subseq others 0 (1+ rules)) '(vikix-drawer-new-window) (nthcdr (1+ rules) others))
            (cons 'vikix-drawer-new-window others))))

;;; --- Out and away -------------------------------------------------------------------------

(defun vikix-drawer-home ()
  "The workspace the drawer is out on, or nil when it is away: where its
windows are, or, while its first programs are still starting, where the
key was pressed."
  (when *vikix-drawer-group*
    (if (member *vikix-drawer-group* (screen-groups (current-screen)))
        *vikix-drawer-group*
        ;; That workspace is a strip now, or tiles again: a new one, with
        ;; the windows the old one had.
        (let* ((park (find-group (current-screen) *vikix-drawer-group-name*))
               (out (remove park (vikix-drawer-windows) :key #'window-group)))
          (setf *vikix-drawer-group* (if out (window-group (first out)) (current-group)))))))

(defun vikix-drawer-out-p (&optional (group (current-group)))
  "Is the drawer out on GROUP, with every window it has?"
  (and (eq (vikix-drawer-home) group)
       (every (lambda (w) (eq (window-group w) group)) (vikix-drawer-windows))))

(defun vikix-drawer-show ()
  "The drawer out on the current workspace: its windows brought here, the
programs it lacks started."
  (let* ((group (current-group))
         (now (current-window))
         (windows (vikix-drawer-windows))
         (missing (vikix-drawer-missing)))
    (unless (and now (vikix-drawer-window-p now))
      (setf *vikix-drawer-before* now))
    (setf *vikix-drawer-group* group)
    (dolist (w windows)
      (unless (eq (window-group w) group)
        (move-window-to-group w group)))
    (vikix-drawer-arrange group t)
    (when windows
      (group-focus-window group (first windows))
      (vikix-drawer-raise group))
    (mapc #'vikix-drawer-start missing)
    (when missing
      (message "The drawer: starting ~{~a~^, ~}." (mapcar #'first missing)))))

(defun vikix-drawer-hide ()
  "The drawer away: its windows to the hidden workspace, the focus back
where it was."
  (let* ((group (vikix-drawer-home))
         (windows (and group (remove group (vikix-drawer-windows) :key #'window-group :test-not #'eq)))
         ;; The focus stays on a window of the workspace that has it; from
         ;; one of the drawer's it goes back to the one that had it before.
         (now (and group (group-current-window group)))
         (before (if (and now (not (vikix-drawer-window-p now))) now *vikix-drawer-before*)))
    (setf *vikix-drawer-group* nil
          *vikix-drawer-before* nil)
    (when windows
      (when (and (eq group (current-group)) (vikix-drawer-slides-p group))
        (let* ((head (current-head group))
               (parent (window-parent (first windows)))
               (x (xlib:drawable-x parent))
               (width (+ (xlib:drawable-width parent) (* 2 (xlib:drawable-border-width parent)))))
          (vikix-drawer-slide windows x (vikix-drawer-away-x head width))
          ;; Not left past the edge: a floating window that changes
          ;; workspace is fitted to the screen by StumpWM (float-window-align),
          ;; which fails on one with no part of it on the screen.
          (dolist (w windows)
            (hide-window w)
            (setf (xlib:drawable-x (window-parent w)) x))))
      (let ((park (vikix-drawer-park)))
        (dolist (w windows)
          (move-window-to-group w park)))
      ;; The focus goes back to the window that had it, or to what the
      ;; workspace shows.
      (when (eq group (current-group))
        (cond ((and before (member before (group-windows group)))
               (group-focus-window group before))
              ((typep group 'tile-group)
               (focus-frame group (tile-group-current-frame group)))
              ((group-windows group)
               (group-focus-window group (first (group-windows group)))))))))

(defcommand vikix-drawer (&optional what) ((:string nil))
  "The drawer (Super+Ctrl+b): a few everyday programs in a column at the
screen's edge, on whatever workspace you're on; again puts it away, the
programs still running. `vikix-drawer on` and `off` say which.
*vikix-drawer-apps* in user.lisp names the programs."
  (let ((out (vikix-drawer-out-p)))
    (cond ((null *vikix-drawer-apps*)
           (message "The drawer has no programs: *vikix-drawer-apps* in user.lisp names them."))
          ((equal what "off") (when (vikix-drawer-home) (vikix-drawer-hide)))
          ((equal what "on") (unless out (vikix-drawer-show)))
          (out (vikix-drawer-hide))
          (t (vikix-drawer-show)))))

;;; --- A desktop started again --------------------------------------------------------------

;; A reload leaves the windows as they are. A restart makes every window a
;; tile again and forgets which were the drawer's: the name written on each
;; says, and they go back to wait, floating, for the key.
(defun vikix-drawer-recover ()
  (dolist (w (screen-windows (current-screen)))
    (let ((name (and (not (vikix-drawer-window-p w)) (vikix-drawer-marked-name w))))
      (when name
        (setf (gethash w *vikix-drawer-windows*) name)
        (when (and (typep w 'tile-window) (vikix-rule-float-it w))
          (move-window-to-group w (vikix-drawer-park)))))))

(handler-case (vikix-drawer-recover)
  (error (e) (message "The drawer: ~a" e)))
