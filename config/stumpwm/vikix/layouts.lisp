;;;; layouts.lisp — saved layouts: a workspace's windows, where they stood.
;;;;
;;;;   vikix layout save writing    this workspace as it is now
;;;;   vikix layout writing         back as it was: the splits (or the strip's
;;;;                                columns) and which window sits in each
;;;;   vikix layout list | rm NAME
;;;;   (when-window ... (layout "writing"))   from a rule
;;;;
;;;; A layout is a file of plain Lisp, ~/.config/vikix/layouts/NAME.lisp, to
;;;; read, change by hand, copy to another machine or keep in a note. It
;;;; says how windows stand, not which X windows they were: each by its
;;;; class, instance and title, the splits as parts of the screen. So it
;;;; still fits a bigger screen, and windows opened again since.
;;;;
;;;; Restoring matches the windows on this workspace to the saved ones: the
;;;; same class (or instance) first, then the closest title. Windows it
;;;; doesn't mention stay, in the current split or at the strip's end;
;;;; saved windows that aren't open are named. A strip's layout makes the
;;;; workspace a strip, a tiled one tiles (viri.lisp).
;;;;
;;;; Tiles are saved with StumpWM's own dump-group and put back with its
;;;; restore-group (as Super+z does); this file only turns X window ids
;;;; into descriptions and pixels into parts of the screen, and back.

(in-package :stumpwm)

(defparameter *vikix-layouts-dir*
  (merge-pathnames ".config/vikix/layouts/" (user-homedir-pathname))
  "Where saved layouts are kept, one file each.")

(defun vikix-layout-name-p (name)
  (and (stringp name) (plusp (length name)) (<= (length name) 40)
       (every (lambda (c) (or (alphanumericp c) (find c "-_."))) name)
       (char/= (char name 0) #\.)))

(defun vikix-layout-file (name)
  (unless (vikix-layout-name-p name)
    (error "A layout's name is letters, digits, - _ and . (not first): ~s." name))
  (merge-pathnames (concatenate 'string name ".lisp") *vikix-layouts-dir*))

(defun vikix-layout-names ()
  (sort (mapcar #'pathname-name (directory (merge-pathnames "*.lisp" *vikix-layouts-dir*)))
        #'string<))

;;; --- Windows as descriptions ----------------------------------------------------

(defun vikix-layout-window (window)
  "WINDOW as a layout describes it: what it is, and how to start it again
(when that can be told)."
  (append (list :class (or (window-class window) "")
                :instance (or (window-res window) "")
                :title (or (window-title window) ""))
          (ignore-errors (vikix-layout-how window))))

;;; --- How a window was started, to start it again ------------------------------------
;;;
;;; Saved with each window: :command (the program and its arguments) and
;;; :directory. Read from the window's process (_NET_WM_PID, /proc), except:
;;; a terminal is started again in its shell's folder, with what runs in it
;;; when that isn't a shell (nvim notes.org); an Emacs frame belongs to the
;;; one Emacs, so it's the file it shows (emacsclient -c FILE), or Esploro's
;;; folder (esploro --new FOLDER).

(defparameter *vikix-layout-terminals*
  '("alacritty" "kitty" "foot" "xterm" "st" "urxvt" "wezterm" "wezterm-gui" "konsole" "xfce4-terminal")
  "Programs that are terminals: what runs inside them is what matters.")

(defparameter *vikix-layout-shells* '("bash" "zsh" "fish" "sh" "dash" "ksh" "tcsh" "nu")
  "A terminal running one of these was only a shell: its folder is enough.")

(defun vikix-window-pid (window)
  (let ((pid (first (ignore-errors (xlib:get-property (window-xwin window) :_net_wm_pid)))))
    (and (integerp pid) (plusp pid) pid)))

(defun vikix-proc-file (pid name)
  (format nil "/proc/~d/~a" pid name))

(defun vikix-proc-cmdline (pid)
  "PID's program and arguments, or NIL."
  (ignore-errors
   (with-open-file (in (vikix-proc-file pid "cmdline") :element-type '(unsigned-byte 8))
     (let* ((bytes (let ((v (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0)))
                     (loop for b = (read-byte in nil) while b do (vector-push-extend b v))
                     v))
            (text (sb-ext:octets-to-string (coerce bytes '(vector (unsigned-byte 8))) :external-format :utf-8)))
       (remove "" (split-seq text (string (code-char 0))) :test #'string=)))))

(defun vikix-proc-cwd (pid)
  (ignore-errors (sb-posix:readlink (vikix-proc-file pid "cwd"))))

(defun vikix-proc-child (pid)
  "PID's first child process, or NIL."
  (or (ignore-errors
       (with-open-file (in (format nil "/proc/~d/task/~d/children" pid pid))
         (let ((line (read-line in nil "")))
           (parse-integer line :junk-allowed t))))
      ;; Without CONFIG_PROC_CHILDREN: whose parent it is, from each process.
      (loop for dir in (directory "/proc/[0-9]*/")
            for child = (ignore-errors (parse-integer (car (last (pathname-directory dir)))))
            when (and child
                      (ignore-errors
                       (with-open-file (in (vikix-proc-file child "stat"))
                         (let* ((line (read-line in nil ""))
                                (rest (subseq line (1+ (position #\) line :from-end t))))
                                (fields (remove "" (split-seq rest " ") :test #'string=)))
                           (eql (parse-integer (second fields) :junk-allowed t) pid)))))
              minimize child)))

(defun vikix-layout-program (word)
  "A program's own name: /usr/bin/bash -> bash, -bash (a login shell) -> bash."
  (string-left-trim "-" (file-namestring word)))

(defun vikix-layout-how (window)
  "(:command (PROGRAM ARG...) :directory DIR) to start WINDOW again, or NIL."
  (if (equal (window-class window) "Emacs")
      (vikix-layout-emacs-how window)
      (let* ((pid (vikix-window-pid window))
             (cmd (and pid (vikix-proc-cmdline pid))))
        (when cmd
          (if (member (vikix-layout-program (first cmd)) *vikix-layout-terminals* :test #'string=)
              (let* ((child (vikix-proc-child pid))
                     (inner (and child (vikix-proc-cmdline child)))
                     (shell (or (null inner)
                                (member (vikix-layout-program (first inner)) *vikix-layout-shells* :test #'string=)))
                     ;; Started with -e already: its own command line says it all.
                     (own (or (member "-e" cmd :test #'string=) (member "--command" cmd :test #'string=))))
                (list :command (if (or own shell) cmd (append cmd (list "-e") inner))
                      :directory (or (and child (vikix-proc-cwd child)) (vikix-proc-cwd pid))))
              (list :command cmd :directory (vikix-proc-cwd pid)))))))

(defun vikix-layout-emacs-how (window)
  "An Emacs frame: the file it shows, or Esploro's folder, asked of Emacs."
  (let* ((elisp (format nil "(let ((f (seq-find (lambda (f) (equal (frame-parameter f 'outer-window-id) ~s)) (frame-list)))) (when f (let ((b (window-buffer (frame-selected-window f)))) (list (if (frame-parameter f 'esploro) \"esploro\" \"file\") (or (buffer-file-name b) (with-current-buffer b (expand-file-name default-directory)))))))"
                        (princ-to-string (window-id window))))
         (out (ignore-errors
               (with-output-to-string (s)
                 (sb-ext:run-program "timeout" (list "2" "emacsclient" "-e" elisp)
                                     :search t :input nil :output s :error nil :wait t))))
         (answer (and out (plusp (length out))
                      (ignore-errors (let ((*read-eval* nil)) (read-from-string out))))))
    (when (and (consp answer) (stringp (second answer)))
      (if (equal (first answer) "esploro")
          (list :command (list "esploro" "--new" (second answer)) :directory (second answer))
          (list :command (list "emacsclient" "-c" "-n" "-a" "" (second answer))
                :directory (directory-namestring (second answer)))))))

(defun vikix-layout-score (spec window)
  "How well WINDOW fits SPEC: nil when not at all (another program), else
more for the same instance and the same title."
  (let ((class (getf spec :class)) (instance (getf spec :instance)) (title (getf spec :title)))
    (when (or (and (plusp (length class)) (equal class (window-class window)))
              (and (plusp (length instance)) (equal instance (window-res window))))
      (+ 1
         (if (equal instance (window-res window)) 2 0)
         (cond ((equal title (window-title window)) 4)
               ((and (plusp (length title)) (window-title window)
                     (search title (window-title window) :test #'char-equal)) 1)
               (t 0))))))

(defun vikix-layout-match (specs windows)
  "Each saved window (SPECS, in order) given the open window that fits it
best, each open window used once: a list as long as SPECS, NIL where none
fits. The best fits are taken first, so two terminals find their own."
  (let ((pairs '()) (taken '()) (result (make-list (length specs))))
    (loop for spec in specs
          for i from 0
          do (dolist (w windows)
               (let ((score (vikix-layout-score spec w)))
                 (when score (push (list score i w) pairs)))))
    (dolist (p (stable-sort pairs #'> :key #'first) result)
      (destructuring-bind (score i w) p
        (declare (ignore score))
        (unless (or (nth i result) (member w taken))
          (setf (nth i result) w)
          (push w taken))))))

;;; --- Saving -----------------------------------------------------------------------

(defun vikix-layout-share (n whole)
  "N of WHOLE as a short decimal: 0.5, 0.667."
  (if (zerop whole) 0 (/ (round (* 1000 n) whole) 1000.0)))

(defun vikix-layout-head (group)
  "GROUP's screen as StumpWM measures frames: the whole of it, the bar's
strip included. (values x y width height)"
  (let ((head (group-current-head group)))
    (values (head-x head) (head-y head) (head-width head) (head-height head))))

(defun vikix-layout-of-tiles (group)
  (multiple-value-bind (hx hy hw hh) (vikix-layout-head group)
    (labels ((frame (fd)
               (list :frame (fdump-number fd)
                     :x (vikix-layout-share (- (fdump-x fd) hx) hw)
                     :y (vikix-layout-share (- (fdump-y fd) hy) hh)
                     :width (vikix-layout-share (fdump-width fd) hw)
                     :height (vikix-layout-share (fdump-height fd) hh)
                     :windows (remove nil (fdump-windows fd))
                     :shown (fdump-current fd)))
             (tree (node)
               (cond ((null node) nil)
                     ((fdump-p node) (frame node))
                     (t (mapcar #'tree node)))))
      ;; Floating windows (dialogs) have no frame: they aren't saved.
      (let ((dump (dump-group group (lambda (w) (and (typep w 'tile-window) (vikix-layout-window w))))))
        ;; A workspace kept in main and stack, or in a grid, says so, and
        ;; is kept so again when the layout is put back.
        (list* :kind :tiles
               (append (cond ((vikix-main-p group) (list :mode :main))
                             ((member group *vikix-grid-groups*) (list :mode :grid)))
                       (list :current (gdump-current dump)
                             :tree (tree (gdump-tree dump)))))))))

(defun vikix-layout-of-strip (group)
  (list :kind :strip
        :columns (loop for c in (viri-cols group)
                       collect (append (list :width (viri-col-width c))
                                       ;; The pinned column says so, and is again.
                                       (when (eq c (viri-pinned group)) (list :pinned t))
                                       (when (viri-tabbed-p c) (list :tabbed t))
                                       ;; Uneven heights: each window's weight, 1 an even share.
                                       (when (some (lambda (w) (/= (viri-weight w) 1)) (viri-col-windows c))
                                         (list :heights (mapcar #'viri-weight (viri-col-windows c))))
                                       (list :windows (mapcar #'vikix-layout-window (viri-col-windows c)))))))

(defun vikix-layout-save (name &optional (group (current-group)))
  "Save GROUP's layout as NAME; returns the file."
  (let ((file (vikix-layout-file name))
        (layout (cond ((viri-group-p group) (vikix-layout-of-strip group))
                      ((typep group 'tile-group) (vikix-layout-of-tiles group))
                      (t (error "Only tiled workspaces and strips have a layout to save.")))))
    (ensure-directories-exist file)
    (with-open-file (out file :direction :output :if-exists :supersede :external-format :utf-8)
      (with-standard-io-syntax
        (let ((*print-case* :downcase) (*print-pretty* t) (*print-right-margin* 100)
              (*print-readably* nil) (*package* (find-package :cl-user)))
          (format out ";; A Vikix layout (layouts.lisp): ~a, saved ~a from workspace ~a.~%~
;; Each window is matched by its class, then its title; a split's place
;; and size are parts of the screen. Change it as you like.~%~%"
                  name (vikix-layout-date) (group-name group))
          (prin1 (list* :layout name layout) out)
          (terpri out))))
    file))

(defun vikix-layout-date ()
  (multiple-value-bind (s mi h d mo y) (get-decoded-time)
    (declare (ignore s))
    (format nil "~d-~2,'0d-~2,'0d ~2,'0d:~2,'0d" y mo d h mi)))

;;; --- Restoring ----------------------------------------------------------------------

(defun vikix-layout-read (name)
  (let ((file (vikix-layout-file name)))
    (unless (probe-file file)
      (error "No layout ~a (vikix layout list)." name))
    (with-open-file (in file :external-format :utf-8)
      (with-standard-io-syntax
        ;; Data only: #. is never read, so nothing in the file runs.
        (let ((*read-eval* nil) (*package* (find-package :cl-user)))
          (let ((form (read in)))
            (unless (and (consp form) (eq (first form) :layout))
              (error "~a isn't a layout (it should start with (:layout ...))." (file-namestring file)))
            (rest (rest form))))))))

(defun vikix-layout-specs-of-tree (tree)
  "Every saved window of a tiles layout's TREE, in order."
  (cond ((null tree) nil)
        ((eq (first tree) :frame) (copy-list (getf (rest (rest tree)) :windows)))
        (t (mapcan #'vikix-layout-specs-of-tree tree))))

(defun vikix-layout-restore-tiles (group layout windows)
  "Put GROUP's tiles as LAYOUT says, with WINDOWS (those that aren't
dialogs) matched to its saved ones. Returns the saved windows not found."
  (let* ((specs (vikix-layout-specs-of-tree (getf layout :tree)))
         (found (vikix-layout-match specs windows))
         ;; Each saved window a token restore-group can compare (equal):
         ;; its place in the list; a window that matched none, one of its own.
         (token (make-hash-table :test 'eq)))
    (loop for w in found for i from 0 when w do (setf (gethash w token) i))
    (multiple-value-bind (hx hy hw hh) (vikix-layout-head group)
      (let ((i -1))
        (labels ((place (share base whole) (+ base (round (* share whole))))
                 (frame (f)
                   (let* ((p (rest (rest f)))
                          (ws (loop repeat (length (getf p :windows)) collect (incf i)))
                          (shown (position (getf p :shown) (getf p :windows) :test #'equal)))
                     (make-fdump :number (second f)
                                 :x (place (getf p :x) hx hw) :y (place (getf p :y) hy hh)
                                 :width (round (* (getf p :width) hw)) :height (round (* (getf p :height) hh))
                                 :windows ws
                                 :current (and shown (nth shown ws)))))
                 (tree (node)
                   (cond ((null node) nil)
                         ((eq (first node) :frame) (frame node))
                         (t (mapcar #'tree node)))))
          (let* ((dump (make-gdump :number (group-number group) :name (group-name group)
                                   :tree (tree (getf layout :tree))
                                   :current (getf layout :current)))
                 (all (group-windows group))
                 (floats (remove-if-not #'float-window-p all)))
            ;; restore-group gives every window it's handed a frame: the
            ;; floating ones (dialogs) are kept out, as Super+z does.
            (setf (group-windows group) (set-difference all floats))
            (unwind-protect
                 (restore-group group dump nil
                                (lambda (w) (gethash w token (list :unmatched (window-id w)))))
              (setf (group-windows group) all))))))
    (loop for spec in specs for w in found unless w collect spec)))

(defun vikix-layout-restore-strip (group layout windows)
  "Put GROUP's strip as LAYOUT says. Returns the saved windows not found."
  (let* ((columns (getf layout :columns))
         (specs (loop for c in columns append (copy-list (getf c :windows))))
         (found (vikix-layout-match specs windows))
         (cols '()) (k 0) (pinned nil))
    (dolist (c columns)
      (let ((ws (loop repeat (length (getf c :windows))
                      for i from 0
                      for w = (nth k found) do (incf k)
                      when w
                        collect w
                        ;; Its weight, when the layout gave the column uneven heights.
                        and do (let ((weight (nth i (getf c :heights))))
                                 (if (and (rationalp weight) (plusp weight) (/= weight 1))
                                     (setf (gethash w *viri-weights*) weight)
                                     (remhash w *viri-weights*))))))
        (when ws
          (push (make-viri-col ws (or (ignore-errors (viri-share (getf c :width))) *viri-default-width*)) cols)
          (when (getf c :pinned)
            (setf pinned (first cols)))
          (when (getf c :tabbed)
            (setf (gethash (first cols) *viri-tabbed*) t)))))
    ;; Windows the layout doesn't mention: a column each, at the end.
    (dolist (w windows)
      (unless (member w found)
        (push (make-viri-col (list w)) cols)))
    (setf (viri-cols group) (nreverse cols)
          (viri-offset group) 0)
    (if pinned
        (setf (gethash group *viri-pinned*) pinned)
        (remhash group *viri-pinned*))
    (when (group-current-window group)
      (viri-scroll-to group (group-current-window group)))
    (viri-layout group)
    (loop for spec in specs for w in found unless w collect spec)))

(defvar *vikix-layout-started* (make-hash-table :test 'equal)
  "Saved windows started lately, and when: not started again within
*vikix-layout-start-wait* seconds (a rule's layout would start them again as
each of them opens).")

(defparameter *vikix-layout-start-wait* 30
  "Seconds a started window is given to appear before it may be started again.")

(defun vikix-layout-start (spec)
  "Start the window SPEC describes, by its :command in its :directory. True
when it was started; NIL when it can't be (no command) or was just now."
  (let ((cmd (getf spec :command))
        (dir (getf spec :directory))
        (key (prin1-to-string (list (getf spec :class) (getf spec :command))))
        (now (get-universal-time)))
    (when (and (consp cmd) (every #'stringp cmd) (plusp (length (first cmd)))
               (< (+ (gethash key *vikix-layout-started* 0) *vikix-layout-start-wait*) now))
      (setf (gethash key *vikix-layout-started*) now)
      (sb-ext:run-program "setsid" (list* "-f" cmd)
                          :search t :input nil :output nil :error nil :wait t
                          :directory (and (stringp dir) (probe-file dir) dir))
      t)))

(defun vikix-layout-follow (name group started)
  "The windows STARTED come one by one: each second for a while, while the
workspace is NAME's still, put it back as NAME says again as more of them
are there (nothing started this time). Whole seconds: a fractional delay
once stopped StumpWM's timers."
  (let ((tries 0) (timer nil) (left (length started))
        ;; The folder the layout was read from: resume.lisp keeps its own.
        (dir *vikix-layouts-dir*))
    (setf timer
          (run-with-timer 1 1
                          (lambda ()
                            (incf tries)
                            (handler-case
                                (let* ((*vikix-layouts-dir* dir)
                                       (windows (remove-if #'viri-floats-p (group-windows group)))
                                       (still (count-if-not (lambda (s) (first (vikix-layout-match (list s) windows))) started)))
                                  (when (< still left)
                                    (setf left still)
                                    (vikix-layout-restore name group :start nil))
                                  (when (or (zerop still) (>= tries 20)
                                            (not (member group (screen-groups (group-screen group)))))
                                    (cancel-timer timer)))
                              (error () (cancel-timer timer))))))))

(defun vikix-layout-restore (name &optional (group (current-group)) &key (start t))
  "Put GROUP back as the layout NAME says; with START, start the saved
windows that aren't open (those it can), and place them as they come.
Returns the saved windows that aren't open, and as a second value those of
them being started."
  (let* ((layout (vikix-layout-read name))
         (kind (getf layout :kind)))
    (unless (member kind '(:tiles :strip))
      (error "~a's :kind is :tiles or :strip, not ~s." name kind))
    ;; The workspace becomes what the layout was: a strip, or tiles.
    (when (and (eq kind :strip) (not (viri-group-p group)))
      (setf group (viri-replace-group group 'viri-group)))
    (when (and (eq kind :tiles) (viri-group-p group))
      (setf group (viri-replace-group group 'tile-group)))
    ;; Tiles are as the layout says, not as a mode would keep them, unless
    ;; the layout was saved in that mode.
    (setf *vikix-grid-groups* (remove group *vikix-grid-groups*))
    (remhash group *vikix-main*)
    (let* ((windows (remove-if #'viri-floats-p (group-windows group)))
           (missing (if (eq kind :strip)
                        (vikix-layout-restore-strip group layout windows)
                        (vikix-layout-restore-tiles group layout windows)))
           (started (and start (remove-if-not #'vikix-layout-start missing))))
      (when (eq kind :tiles)
        (case (getf layout :mode)
          ;; The order and the main window's width are read from the frames.
          (:main (setf (gethash group *vikix-main*) (list (first *vikix-main-shares*)))
                 (vikix-main-retile group))
          (:grid (push group *vikix-grid-groups*))))
      (when started
        (vikix-layout-follow name group started))
      (values missing started))))

;;; --- Commands, and the rule verb ------------------------------------------------------

(defun vikix-layout-missing-text (missing)
  (format nil "~{~a~^, ~}"
          (mapcar (lambda (s)
                    (let ((title (getf s :title)))
                      (format nil "~a~@[ (~a)~]" (getf s :class)
                              (and (plusp (length title)) (subseq title 0 (min 30 (length title)))))))
                  missing)))

(defcommand vikix-layout-save-command (name) ((:string "Save this workspace's layout as: "))
  "Save this workspace's layout (its splits or its strip, and which window
is where) under NAME, in ~/.config/vikix/layouts/."
  (when (and name (plusp (length name)))
    (vikix-layout-save name)
    (message "Layout ~a saved: vikix layout ~a puts it back." name name)))

(defcommand vikix-layout-restore-command (&optional name) ((:string nil))
  "Put this workspace back as a saved layout says; without a name, pick one."
  (let ((name (or name
                  (let ((names (vikix-layout-names)))
                    (if names
                        (first (select-from-menu (current-screen) (mapcar #'list names) "Layout: "))
                        (progn (message "No layouts saved yet (Super+m, Save this workspace's layout).") nil))))))
    (when name
      (multiple-value-bind (missing started) (vikix-layout-restore name)
        (message "~a" (vikix-layout-said name missing started))))))

(defun vikix-layout-said (name missing started)
  "What putting NAME back did, in a line."
  (let ((not-started (set-difference missing started)))
    (format nil "Layout ~a~@[; starting: ~a~]~@[; not open: ~a~]." name
            (and started (vikix-layout-missing-text started))
            (and not-started (vikix-layout-missing-text not-started)))))

(define-rule-verb layout (name)
  "Put the window's workspace as the saved layout NAME says (vikix layout save NAME)."
  (let* ((win (rule-window))
         (group (window-group win)))
    (when (eq group (current-group))
      (vikix-layout-restore name group))
    win))

;;; --- Picking a layout (s-C-SPC) -------------------------------------------------------
;;;
;;; The ways a workspace can be laid out, in one menu: tiles you split
;;; yourself, main and stack, a grid, a strip; then the layouts you saved.

(defparameter *vikix-layout-kinds*
  '((:tiles "tiles" "Tiles: split it yourself")
    (:main  "main and stack" "Main and stack: one main window, the others in a column beside it")
    (:grid  "a grid" "Grid: every window, tiled again as they open and close")
    (:strip "a strip" "Strip: columns side by side that scroll sideways"))
  "Each kind of layout: what vikix-layout-pick calls it, how a sentence
does, and its line in the menu.")

(defun vikix-layout-now (&optional (group (current-group)))
  "How GROUP is laid out: :tiles, :main, :grid or :strip; nil for a
floating workspace."
  (cond ((viri-group-p group) :strip)
        ((not (typep group 'tile-group)) nil)
        ((vikix-main-p group) :main)
        ((member group *vikix-grid-groups*) :grid)
        (t :tiles)))

(defun vikix-layout-set (kind)
  "Lay the current workspace out as KIND, its windows staying."
  (let ((now (vikix-layout-now)))
    (cond ((null now)
           (message "A floating workspace has no layout to pick."))
          ((eq kind now)
           (message "This workspace is ~a already." (second (assoc kind *vikix-layout-kinds*))))
          (t
           ;; Off a strip first: it becomes a new group of tiles.
           (when (eq now :strip)
             (run-commands "vikix-viri off"))
           (let ((group (current-group)))
             (setf *vikix-grid-groups* (remove group *vikix-grid-groups*))
             (remhash group *vikix-main*)
             (ecase kind
               (:tiles (unless (eq now :strip)
                         (message "Tiles: the layout is yours again.")))
               (:main (run-commands "vikix-main on"))
               (:grid (run-commands "vikix-grid"))
               (:strip (run-commands "vikix-viri on"))))))))

(defcommand vikix-layout-pick (&optional kind) ((:string nil))
  "Pick how this workspace is laid out: tiles, main (main and stack), grid
or strip; without one, a menu of them and of the layouts you saved."
  (let ((now (vikix-layout-now))
        (asked (and kind (find kind *vikix-layout-kinds*
                               :key (lambda (k) (string-downcase (symbol-name (first k))))
                               :test #'string-equal))))
    (cond (asked (vikix-layout-set (first asked)))
          (kind (message "A layout is tiles, main, grid or strip; not ~a." kind))
          ((null now) (message "A floating workspace has no layout to pick."))
          (t
           (let ((choice (select-from-menu
                          (current-screen)
                          (append (mapcar (lambda (k) (list (third k) (first k))) *vikix-layout-kinds*)
                                  (mapcar (lambda (name) (list (format nil "Saved: ~a" name) name))
                                          (vikix-layout-names)))
                          (format nil "Layout (now ~a): " (second (assoc now *vikix-layout-kinds*)))
                          (or (position now *vikix-layout-kinds* :key #'first) 0))))
             (cond ((null choice))
                   ((keywordp (second choice)) (vikix-layout-set (second choice)))
                   (t (run-commands (format nil "vikix-layout-restore-command ~a" (second choice))))))))))

;;; --- Projects (vikix project open) ---------------------------------------------------
;;;
;;; A project opened with vikix project open has a workspace of its own: the
;;; first empty one, or the one it has still. Leaving that workspace saves
;;; its layout as project-NAME; the next open puts it back once the
;;; project's terminal and editor have come.

(defvar *vikix-project-groups* (make-hash-table :test 'eq :weakness :key)
  "Each workspace a project was opened on, and the project's name.")

(defun vikix-layout-project-name (project)
  "The layout a project's workspace is saved as: project-NAME, a / in a
collection's project as --."
  (concatenate 'string "project-"
               (with-output-to-string (o)
                 (loop for c across project
                       do (cond ((char= c #\/) (write-string "--" o))
                                ((or (alphanumericp c) (find c "-_.")) (write-char c o))
                                (t (write-char #\_ o)))))))

(defun vikix-project-group (project)
  "The workspace PROJECT is open on, while it has windows."
  (loop for g being the hash-keys of *vikix-project-groups* using (hash-value p)
        when (and (equal p project) (member g (screen-groups (current-screen))) (group-windows g))
          return g))

(defun vikix-project-claim (project)
  "Go to PROJECT's workspace: :existing when it's still open there, else
:new on the first empty workspace (or this one when none is empty)."
  (let ((g (vikix-project-group project)))
    (if g
        (progn (switch-to-group g) :existing)
        (let ((empty (or (find-if (lambda (g) (and (null (group-windows g))
                                                   (plusp (group-number g))))
                                  (sort-groups (current-screen)))
                         (current-group))))
          (switch-to-group empty)
          ;; This workspace is no other project's any more.
          (setf (gethash empty *vikix-project-groups*) project)
          :new))))

(defun vikix-project-save (project &optional (group (or (vikix-project-group project) (current-group))))
  (vikix-layout-save (vikix-layout-project-name project) group))

(defun vikix-project-left (new old)
  "Leaving a project's workspace saves its layout, so the next open puts it back."
  (declare (ignore new))
  (let ((project (and old (gethash old *vikix-project-groups*))))
    (when (and project (group-windows old)
               (or (viri-group-p old) (typep old 'tile-group)))
      (handler-case (vikix-project-save project old)
        (error (e) (message "^1Vikix: the layout of ~a wasn't saved:^n ~a" project e))))))

(remove-hook *focus-group-hook* 'vikix-project-left)
(add-hook *focus-group-hook* 'vikix-project-left)

;; A workspace made a strip (or tiles again) is a new group in its place:
;; it stays the project's.
(sb-int:unencapsulate 'viri-replace-group 'vikix-projects)
(sb-int:encapsulate 'viri-replace-group 'vikix-projects
                    (lambda (f group type)
                      (let ((project (gethash group *vikix-project-groups*))
                            (new (funcall f group type)))
                        (when project
                          (remhash group *vikix-project-groups*)
                          (setf (gethash new *vikix-project-groups*) project))
                        new)))
