;;;; windows.lisp — how windows are focused, spaced and found.
;;;;
;;;;   focus      follows the mouse (sloppy focus)
;;;;   gaps       space around windows, off at start (s-C-g toggles)
;;;;   undo       the last split or window move, per workspace (s-u, s-U)
;;;;   grid       every window in a grid: once (s-o), or kept so (s-O)
;;;;   main       a main window and a stack beside it, kept so (s-C-m)
;;;;   find       any window on any workspace (s-g goes there, s-G brings it here)
;;;;   pointer    the pointer jumps to the focused window (s-p)
;;;;   lazarus    the docked IDE tiles; its dialogs float
;;;;   solo       only this window, then the layout back (s-z)
;;;;   dialogs    float, centred, and stay in front of the tiles
;;;;   dragging   files dragged out of Emacs reach the program under the pointer
;;;;   titles     a title bar on each tiled window (s-C-y), renaming (s-"),
;;;;              and floating a window or tiling it again (s-t)
;;;;
;;;; Gaps, undo, find and beckon come from stumpwm-contrib, cloned into
;;;; ~/.stumpwm.d/modules by install/30-lisp. The keys are in keys.lisp.

(in-package :stumpwm)

;; Focus moves to the window under the mouse, without a click.
(setf *mouse-focus-policy* :sloppy)

;; StumpWM's own handler, but for two things.
;;
;; The pointer "entering" the window that has the focus already does
;; nothing. X says the pointer entered a window whenever what covered it
;; goes (a menu closing over the pointer), and StumpWM's focus-all takes any
;; message off the screen: the answer of "What does a key do?", picked from
;; the menu, was gone as it came.
;;
;; And an EnterNotify with the pointer where it was when the focus last
;; changed changes nothing either: the mouse didn't move, windows did (one
;; raised over another under a still pointer). Acting on those froze the
;; desktop: a floating window over a tile, the pointer on both, and two such
;; events waiting out of step. Each gave the focus to its window, which
;; raised it, which made the next event for the other one, for ever, with
;; StumpWM's one thread never free again. It also means a window you go to
;; with a key keeps the focus while the pointer rests on another. An
;; EnterNotify anywhere else shows the mouse has moved since, whether or not
;; it changes the focus, and the place is forgotten: the pointer back on the
;; same spot later is the mouse again.

(defvar *vikix-pointer-at-focus* nil
  "Where the pointer was, as (X . Y) on the root window, when the focus last
changed; nil once the mouse has moved since.")

(defun vikix-note-pointer-at-focus (&rest ignore)
  "Note where the pointer is now: the focus has just changed."
  (declare (ignore ignore))
  (setf *vikix-pointer-at-focus*
        (ignore-errors
         (multiple-value-bind (x y) (xlib:global-pointer-position *display*)
           (cons x y)))))

(remove-hook *focus-window-hook* 'vikix-note-pointer-at-focus)
(add-hook *focus-window-hook* 'vikix-note-pointer-at-focus)

(define-stump-event-handler :enter-notify (window mode root-x root-y)
  (when (and window (eq mode :normal) (eq *mouse-focus-policy* :sloppy))
    (unless (equal (cons root-x root-y) *vikix-pointer-at-focus*)
      (setf *vikix-pointer-at-focus* nil)
      (let ((win (find-window window)))
        (when (and win (find win (top-windows)) (not (eq win (current-window))))
          (focus-all win)
          (update-all-mode-lines))))))

(defun vikix-load-module (name)
  "Load contrib module NAME. True if it loaded. A missing module is
reported and skipped, so the rest of this file still works."
  (handler-case (progn (load-module name) t)
    (error (e)
      (message "^1Vikix: module ~a not loaded:^n~%~a" name e)
      nil)))

;;; Gaps

(defvar *vikix-gaps* (vikix-load-module "swm-gaps")
  "True when the swm-gaps module loaded.")

(defun vikix-gaps (name &rest args)
  "Call swm-gaps' internal function NAME. Looked up at run time, because
the package doesn't exist when the module failed to load."
  (apply (find-symbol name :swm-gaps) args))

(when *vikix-gaps*
  ;; The inner gap is on every side of every window, so two windows are
  ;; 2 x 5 = 10px apart; at the screen edge it's 5 + 4 = 9px.
  (setf (symbol-value (find-symbol "*HEAD-GAPS-SIZE*"  :swm-gaps)) 0    ; along the monitor edges
        (symbol-value (find-symbol "*INNER-GAPS-SIZE*" :swm-gaps)) 5    ; around every window
        (symbol-value (find-symbol "*OUTER-GAPS-SIZE*" :swm-gaps)) 4))  ; extra at the screen edge

(defun vikix-maximize-window (win)
  "swm-gaps' gaps-aware maximize-window, with the sizes it sets clamped.
The module's own version can compute a width, height or frame extent
below zero for a small window, and X then kills the window manager."
  (multiple-value-bind (x y wx wy width height border stick)
      (geometry-hints win)
    (let ((ox 0) (oy 0) (ow 0) (oh 0)
          (frame (window-frame win)))
      (when (vikix-gaps "APPLY-GAPS-P" win)
        (multiple-value-setq (ox oy ow oh) (vikix-gaps "GAPS-OFFSETS" win)))
      (when (and (< ow width)
                 (>= width (- (frame-display-width (window-group win) frame) ow)))
        (setf width (- width ow)))
      (when (and (< oh height)
                 (>= height (- (frame-display-height (window-group win) frame) oh)))
        (setf height (- height oh)))
      (setf x (+ x ox)
            y (+ y oy))
      ;; The title bar's room, taken here, in the one layout: made after it,
      ;; the window was set to the full height and then to the shorter one
      ;; each time, and a terminal sizing itself in whole rows (xterm)
      ;; answered each change with new size hints, which lay it out again:
      ;; round and round, the main thread never resting.
      (let ((ph (- (frame-display-height (window-group win) frame) (* 2 border) oh)))
        (when (and (not stick) (fboundp 'vikix-titlebar-wants-p)
                   (funcall 'vikix-titlebar-wants-p win ph))
          (let ((h (funcall 'vikix-titlebar-height)))
            (setf wy (max h wy)
                  height (funcall 'vikix-titlebar-fit win (min height (- ph wy)))))))
      (set-window-geometry win :x wx :y wy :width width :height height :border-width 0)
      (xlib:with-state ((window-parent win))
        (setf (xlib:drawable-x (window-parent win)) x
              (xlib:drawable-y (window-parent win)) y
              (xlib:drawable-border-width (window-parent win)) border)
        (if (or stick (find *window-border-style* '(:tight :none)))
            (setf (xlib:drawable-width (window-parent win)) (max 1 (window-width win))
                  (xlib:drawable-height (window-parent win)) (max 1 (window-height win)))
            (setf (xlib:drawable-width (window-parent win))
                  (max 1 (- (frame-display-width (window-group win) frame)
                            (* 2 (xlib:drawable-border-width (window-parent win)))
                            ow))
                  (xlib:drawable-height (window-parent win))
                  (max 1 (- (frame-display-height (window-group win) frame)
                            (* 2 (xlib:drawable-border-width (window-parent win)))
                            oh))))
        (xlib:change-property (window-xwin win) :_NET_FRAME_EXTENTS
                              (list (max 0 wx)
                                    (max 0 (- (xlib:drawable-width (window-parent win)) width wx))
                                    (max 0 wy)
                                    (max 0 (- (xlib:drawable-height (window-parent win)) height wy)))
                              :cardinal 32))
      (update-decoration win)
      (update-configuration win))))

;; swm-gaps replaces maximize-window when it loads; this replaces it again.
(when *vikix-gaps*
  (setf (symbol-function 'maximize-window) #'vikix-maximize-window))

;;; Layout undo

;; winner-mode only records a layout when told to. It is told after each
;; command that changes one: its own list of StumpWM's layout commands,
;; plus gmove (Super+Shift+<digit>). Left to itself it has two gaps, filled here:
;;   - it never records the layout before the first change, so that
;;     change can't be undone; it is recorded just before it instead
;;   - after an undo, a new change leaves the old redo steps in place;
;;     they are dropped, as in any editor
;; Named functions, so a reload doesn't add the hooks twice.

;; On s-u and s-U: winner-mode puts a layout back with restore-group, which
;; gives every window a frame, so a floating one (a dialog, a window
;; floated with s-t) was an error; they're kept out of it, as s-z does.
;; A strip has no frames to go back to, and says so.
(defun vikix-layout-step (command)
  (let ((group (current-group)))
    (if (not (typep group 'tile-group))
        (message "Layout undo is for tiled workspaces: a strip keeps its order.")
        (let* ((all (group-windows group))
               (floats (remove-if-not #'float-window-p all)))
          (setf (group-windows group) (set-difference all floats))
          (unwind-protect (run-commands command)
            (setf (group-windows group) all))))))

(defcommand vikix-layout-undo () ()
  "Undo the last layout change on this workspace (splits, moves)."
  (vikix-layout-step "winner-undo"))

(defcommand vikix-layout-redo () ()
  "Redo the layout change just undone."
  (vikix-layout-step "winner-redo"))

(defun vikix-layout-command-p (command)
  (or (member command (symbol-value (find-symbol "*DEFAULT-COMMANDS*" :winner-mode)))
      (member command '(gmove gmove-and-follow vikix-send vikix-workspace-carry expose vikix-grid vikix-main))))

(defun vikix-layout-ids (name)
  "winner-mode's table NAME: workspace number → layout step."
  (symbol-value (find-symbol name :winner-mode)))

(defun vikix-record-layout ()
  ;; Only tiles have frames to save: winner-mode's dump-group fails on any
  ;; other workspace (a strip, vikix-viri), and the failure asked after
  ;; every command there.
  (when (typep (current-group) 'tile-group)
    (let ((n (group-number (current-group))))
      (funcall (find-symbol "DUMP-GROUP-TO-FILE" :winner-mode))
      (setf (gethash n (vikix-layout-ids "*MAX-IDS*"))
            (gethash n (vikix-layout-ids "*CURRENT-IDS*"))))))

(defun vikix-record-first-layout (command)
  (when (and (vikix-layout-command-p command)
             (zerop (gethash (group-number (current-group))
                             (vikix-layout-ids "*CURRENT-IDS*") 0)))
    (vikix-record-layout)))

(defun vikix-record-changed-layout (command)
  (when (vikix-layout-command-p command)
    (vikix-record-layout)))

(when (vikix-load-module "winner-mode")
  (add-hook *pre-command-hook*  'vikix-record-first-layout)
  (add-hook *post-command-hook* 'vikix-record-changed-layout))

;;; Grid

;; s-o is StumpWM's expose: every window in a grid, then pick one.
;; s-O is grid mode: the workspace's windows are tiled into the same grid,
;; with nothing to pick, and again by themselves when a window opens or
;; closes there (or, if that happened while you were elsewhere, when you
;; come back). Off, the layout stays as it is and is yours again. s-u goes
;; back a layout, but the next window opened re-tiles while grid mode is
;; on. Floating windows and dialogs are left out of the grid.

(defvar *vikix-grid-groups* nil "Workspaces in grid mode.")

(defun vikix-grid-windows (group)
  (remove-if (lambda (w) (typep w 'float-window)) (group-windows group)))

(defun vikix-grid-retile (group &optional focus)
  "Tile GROUP's windows into a grid if it is in grid mode, current, and
not tiled already; then focus FOCUS, or the window that had focus."
  (when (and (member group *vikix-grid-groups*)
             (eq group (current-group))
             (typep group 'tile-group))
    (let ((n (min *expose-n-max* (length (vikix-grid-windows group))))
          (win (or focus (group-current-window group))))
      (unless (and (= n (length (group-frames group)))
                   (every #'frame-window (group-frames group)))
        (handler-case
            (progn
              (only)
              ;; The focused window may be the one that just closed.
              (unless (frame-window (tile-group-current-frame group))
                (pull-hidden-next))
              (recursive-tile n group)
              (when (and win (window-frame win)
                         (eq (window-group win) group))
                (focus-frame group (window-frame win))))
          (error (e) (message "Grid: ~a" e)))))))

(defun vikix-grid-new-window (window)
  (unless (or (window-transient-p window) (typep window 'float-window))
    (vikix-grid-retile (window-group window) window)))

(defun vikix-grid-destroy-window (window)
  (vikix-grid-retile (window-group window)))

(defun vikix-grid-focus-group (new old)
  (declare (ignore old))
  (vikix-grid-retile new))

(add-hook *new-window-hook* 'vikix-grid-new-window)
(add-hook *destroy-window-hook* 'vikix-grid-destroy-window)
(add-hook *focus-group-hook* 'vikix-grid-focus-group)

(defcommand vikix-grid () ()
  "Grid mode on/off: keep this workspace's windows tiled in a grid."
  (let ((group (current-group)))
    (cond ((not (typep group 'tile-group))
           (message "Grid mode is for tiling workspaces"))
          ((member group *vikix-grid-groups*)
           (setf *vikix-grid-groups* (remove group *vikix-grid-groups*))
           (message "Grid mode off"))
          (t
           (remhash group *vikix-main*)   ; one mode a workspace
           (push group *vikix-grid-groups*)
           (vikix-grid-retile group)
           (message "Grid mode on: windows re-tile as they open and close")))))

;;; Finding windows, and the pointer

;; The module globalwindows' goto-window only knew a window in a frame: one
;; on a strip, or floating, was an error. Vikix's takes its place, as
;; maximize-window's does above, for s-g and for the module's own command.
(defun vikix-goto-window (window)
  "Go to WINDOW wherever it is: in a frame, floating, or on a strip."
  (let ((group (window-group window)))
    (when (and (typep group 'tile-group) (typep window 'tile-window))
      (frame-raise-window group (window-frame window) window))
    (focus-all window)))

(when (vikix-load-module "globalwindows")
  (setf (symbol-function (find-symbol "GOTO-WINDOW" :globalwindows)) #'vikix-goto-window))

;; The list itself (s-g, s-G). The module's showed a number and a title, and
;; sorted by title: seven idle terminals were seven lines of "Alacritty",
;; none saying which workspace it was on. Each line here has the workspace,
;; the title, and what the window is: a terminal's folder and what runs in
;; it, any other window's program. Typing narrows it by any of those.
;; Windows on a hidden workspace (the drop-down terminal's) are left out.

(defun vikix-short-path (path)
  "PATH with the home folder as ~ and no slash at its end."
  (let* ((home (string-right-trim "/" (namestring (user-homedir-pathname))))
         (path (if (> (length path) 1) (string-right-trim "/" path) path)))
    (if (and (>= (length path) (length home)) (string= home path :end2 (length home)))
        (concat "~" (subseq path (length home)))
        path)))

(defun vikix-proc-foreground (pid)
  "The process in front on PID's terminal (the job its shell is running),
or NIL: field 8 of /proc/PID/stat, counted after the name's bracket."
  (ignore-errors
   (with-open-file (in (format nil "/proc/~d/stat" pid))
     (let* ((line (read-line in))
            (fields (remove "" (split-seq (subseq line (1+ (position #\) line :from-end t))) " ")
                            :test #'string=))
            (front (parse-integer (nth 5 fields))))
       (and (plusp front) front)))))

(defun vikix-window-about (window)
  "A few words on what WINDOW is, beyond its title: a terminal's folder and
what runs in it (nothing for a shell at its prompt), any other window's
class. The reading of /proc is layouts.lisp's."
  (or (ignore-errors
       (let* ((pid (vikix-window-pid window))
              (cmd (and pid (vikix-proc-cmdline pid))))
         (when (and cmd (member (vikix-layout-program (first cmd)) *vikix-layout-terminals*
                                :test #'string=))
           (let* ((inside (vikix-proc-child pid))
                  (front (and inside (or (vikix-proc-foreground inside) inside)))
                  (job (and front (or (vikix-proc-cmdline front) (vikix-proc-cmdline inside))))
                  (program (and job (vikix-layout-program (first job))))
                  (folder (and inside (vikix-proc-cwd inside)))
                  (words (and program
                              (not (member program *vikix-layout-shells* :test #'string=))
                              (format nil "~a~{ ~a~}" program (rest job)))))
             (format nil "~@[~a~]~:[~;  ~]~@[~a~]"
                     ;; A long path keeps its end, which says most.
                     (and folder
                          (let ((short (vikix-short-path folder)))
                            (if (> (length short) 36)
                                (concat "..." (subseq short (- (length short) 33)))
                                short)))
                     (and folder words)
                     (and words (subseq words 0 (min 40 (length words)))))))))
      (window-class window)
      ""))

(defun vikix-window-lines (windows)
  "A menu line for each of WINDOWS: workspace, title, what it is."
  (let ((wide (min 40 (reduce #'max windows :key (lambda (w) (length (window-name w)))
                                            :initial-value 0))))
    (mapcar (lambda (w)
              (let ((name (window-name w)))
                (list (format nil "~3a ~va  ~a"
                              (group-name (window-group w))
                              wide (subseq name 0 (min wide (length name)))
                              (vikix-window-about w))
                      w)))
            windows)))

(defun vikix-other-windows ()
  "Every window but the focused one, by workspace and then by number; none
from a hidden workspace."
  (remove (current-window)
          (loop for g in (sort-groups (current-screen))
                unless (char= (char (group-name g) 0) #\.)
                  append (sort (copy-list (group-windows g)) #'< :key #'window-number))))

(defun vikix-pick-window (prompt)
  "Pick one of the other windows from the list, or NIL."
  (let ((windows (vikix-other-windows)))
    (if (null windows)
        (progn (message "No other window.") nil)
        (second (select-from-menu (current-screen) (vikix-window-lines windows) prompt)))))

(defcommand vikix-go-to-window () ()
  "Go to any window, on any workspace: pick it from the list."
  (let ((window (vikix-pick-window "Go to: ")))
    (when window
      (vikix-goto-window window))))

(defun vikix-bring-window-here (window)
  "WINDOW comes to the current workspace and takes the focus: into the
current frame on tiles, as a column on a strip."
  (let ((group (current-group)))
    (unless (eq (window-group window) group)
      (move-window-to-group window group))
    (when (and (typep group 'tile-group) (typep window 'tile-window))
      (pull-window window))
    (group-focus-window group window)))

(defun vikix-show-window (window)
  "WINDOW comes to the front wherever it is: gone to on its own workspace,
brought here from a hidden one (a dot workspace: the drop-down terminal,
the drawer), where nothing can be gone to."
  (if (char= (char (group-name (window-group window)) 0) #\.)
      (vikix-bring-window-here window)
      (vikix-goto-window window)))

(defun vikix-show-window-id (id)
  "Show the window whose X id is ID, a number, as `vikix-show-window' does;
nil when no window of the desktop has it. For a program that opened a
window of its own earlier and is asked for it again (the Office's Emacs
frame): a client asking for the focus itself is not heard from another
workspace."
  (let ((window (find id (screen-windows (current-screen)) :key #'window-id)))
    (when window
      (vikix-show-window window)
      t)))

(defcommand vikix-bring-window () ()
  "Bring any window here, from any workspace: pick it from the list."
  (let ((window (vikix-pick-window "Bring here: ")))
    (when window
      (vikix-bring-window-here window))))

;;; A whole workspace's windows, brought here.
;;;
;;; StumpWM's own gmerge moves them as they are, and a strip's windows are
;;; floating ones: so are a window floated by hand and one a rule called a
;;; dialog. Brought here they are ordinary windows first: tiles on a tiled
;;; workspace, columns on a strip. What stays afloat is what was made to: a
;;; dialog by what it is, and a window a rule floats as it opens.

(defun vikix-gather-keeps-floating-p (window)
  "Does WINDOW float by what it is, or by a rule for it: not just because
it stood on a strip, was floated by hand, or was called a dialog as it took
the focus?"
  (or (vikix-born-dialog-p window)
      (and (fboundp 'vikix-rules-float-p) (ignore-errors (funcall 'vikix-rules-float-p window)))))

(defun vikix-gather-windows (from &optional (to (current-group)))
  "Every window of workspace FROM comes to TO, the one that had the focus
there last, so it is in front; the drawer's stay where the drawer is.
Returns the windows brought."
  (let* ((drawer (lambda (w) (and (fboundp 'vikix-drawer-window-p) (funcall 'vikix-drawer-window-p w))))
         (focused (group-current-window from))
         (windows (remove-if drawer (reverse (group-windows from))))
         (windows (if (member focused windows) (append (remove focused windows) (list focused)) windows)))
    (dolist (w windows)
      (let ((plain (not (vikix-gather-keeps-floating-p w))))
        ;; A rule's word that it is a dialog ends here: or a strip would
        ;; leave it afloat, taking it for one.
        (when (and plain (boundp '*vikix-dialog-windows*))
          (remhash w (symbol-value '*vikix-dialog-windows*)))
        (move-window-to-group w to)
        ;; On tiles a strip's column is tiled as it arrives (viri.lisp); a
        ;; window that floated for another reason is tiled here.
        (when (and plain (typep to 'tile-group) (typep w 'float-window))
          (when (fboundp 'vikix-titlebar-remove) (funcall 'vikix-titlebar-remove w))
          (let ((frame (tile-group-current-frame to)))
            (unfloat-window w to)
            (pull-window w frame nil)
            (setf (tile-group-current-frame to) frame)))))
    (when windows
      (group-focus-window to (car (last windows))))
    windows))

(defun vikix-gather-choices ()
  "The other workspaces that have windows, as menu lines: (LINE GROUP)."
  (loop for g in (sort-groups (current-screen))
        for windows = (group-windows g)
        unless (or (eq g (current-group)) (null windows) (char= (char (group-name g) 0) #\.))
          collect (list (format nil "~a  ~d window~:p: ~a" (group-name g) (length windows)
                                (vikix-one-line (format nil "~{~a~^, ~}" (mapcar #'window-title windows)) 90))
                        g)))

(defcommand vikix-gather (&optional from) ((:string nil))
  "Bring every window of another workspace here: pick the workspace, or
name it (`vikix-gather 2`). They arrive as ordinary windows, tiled here
(as columns, on a strip): a strip's windows, and ones that floated, no
longer float. Dialogs, and windows a rule floats, stay as they are."
  (let* ((choices (vikix-gather-choices))
         (group (cond ((null from)
                       (and choices
                            (second (select-from-menu (current-screen) choices
                                                      "Bring every window here from workspace: "))))
                      (t (or (second (find from choices :key (lambda (c) (group-name (second c))) :test #'equal))
                             (progn (message "No other workspace called ~a has windows." from) nil))))))
    (cond ((and (null from) (null choices))
           (message "No other workspace has windows."))
          (group
           (let ((brought (vikix-gather-windows group)))
             (message "~d window~:p from workspace ~a ~:[are~;is~] here.~@[ ~a~]"
                      (length brought) (group-name group) (= 1 (length brought))
                      (and (typep (current-group) 'tile-group) (> (length brought) 1)
                           "Super+Ctrl+Space lays them out.")))))))

(defcommand vikix-pointer () ()
  "Move the pointer to the middle of this window, tiled, floating or on a strip."
  (let ((win (current-window)))
    (if (null win)
        (message "No window here.")
        (let ((p (window-parent win)))
          (warp-pointer (window-screen win)
                        (+ (xlib:drawable-x p) (floor (xlib:drawable-width p) 2))
                        (+ (xlib:drawable-y p) (floor (xlib:drawable-height p) 2)))))))

;;; Lazarus

;; 65-languages builds Lazarus with its docked IDE (anchordockingdsgn and
;; dockedformeditor): menu, editor, object inspector and form designer
;; share one main window, which tiles like any other. Every other Lazarus
;; window (dialogs, the welcome screen, anything undocked) floats. Tiled,
;; StumpWM would stretch each to fill a frame, and fight Lazarus over its
;; size, which flickers.
(defun vikix-lazarus-window-p (win)
  (search "lazarus" (string-downcase (or (window-class win) ""))))

;; The floating is a rule (rules.lisp, "Vikix's own rules"): every Lazarus
;; window but the main one, at its own size.

;;; Focus on one window (s-z)

;; Super+z keeps only the focused window on its workspace, the bar still
;; there; Super+z again puts the workspace's layout back as it was, however
;; the splits were changed in between (windows opened meanwhile join the
;; frame that's current then). Each workspace keeps its own. Unlike
;; Super+u, which steps back through every change, this goes straight back.
;; StumpWM's dump-group / restore-group do the saving.

(defvar *vikix-solo-layouts* (make-hash-table :test 'eq :weakness :key)
  "Each workspace in focus mode, and the layout it had before.")

(defun vikix-solo-p (&optional (group (current-group)))
  (and (gethash group *vikix-solo-layouts*) t))

(defun vikix-restore-layout (group dump)
  ;; restore-group gives every window of the group a frame, and hides those
  ;; it doesn't show: floating windows (dialogs) are kept out of it, and
  ;; stay as they were.
  (let* ((all (group-windows group))
         (floats (remove-if-not (lambda (w) (typep w 'float-window)) all)))
    (setf (group-windows group) (set-difference all floats))
    (unwind-protect (restore-group group dump)
      (setf (group-windows group) all))))

(defcommand vikix-solo () ()
  "Keep only the focused window on this workspace; again, put the layout
back as it was. On a strip: this column's windows as tabs, and stacked again."
  (let ((group (current-group)))
    (cond ((and (fboundp 'viri-group-p) (funcall 'viri-group-p group))
           ;; On a strip, only this window of its column: the others are tabs.
           (funcall 'viri-toggle-tabs group))
          ((not (typep group 'tile-group))
           (message "Focus mode is for tiled workspaces."))
          ((vikix-solo-p group)
           (let ((dump (gethash group *vikix-solo-layouts*))
                 (win (current-window)))
             (remhash group *vikix-solo-layouts*)
             (vikix-restore-layout group dump)
             ;; Back to the window you were in, wherever it is now.
             (when (and win (member win (group-windows group)) (typep win 'tile-window))
               (focus-all win))
             (vikix-raise-dialogs)
             (message "The other windows are back.")))
          ((null (rest (group-frames group)))
           (message "This window has the workspace already. (Super+f fills the whole screen.)"))
          (t
           (setf (gethash group *vikix-solo-layouts*) (dump-group group))
           (only)
           (message "Focus: only this window. Super+z puts the others back.")))))

;;; Main and stack (s-C-m)

;; What dwm and xmonad call master and stack: one main window down the left
;; of the screen, the others in a column on its right, sharing its height.
;; The workspace is kept so as windows open and close, like grid mode (a
;; workspace is in one of the two, never both). The window you were in when
;; you switched it on is the main one; a new window opens at the top of the
;; stack and takes the focus. Super+Shift+h/j/k/l swap the window with the
;; one that way, so Super+Shift+h from the stack makes it the main one.
;; Super+r goes through the main window's widths. Splits you make yourself
;; are put back at once: the mode owns the layout until it's off. Each
;; screen of the workspace has its own main window and stack. Floating
;; windows and dialogs are left out.
;;
;; The frames are made as a saved layout is put back (restore-group): one
;; tree of them per screen, built here.

(defparameter *vikix-main-shares* '(3/5 2/3 1/2)
  "The main window's share of the screen's width: a workspace starts with
the first, and Super+r goes through them.")

(defparameter *vikix-main-stack-max* 4
  "The most windows the stack shows; any more wait behind the last (Super+`).")

(defparameter *vikix-main-new* :stack
  "Where a new window opens: :stack (the top of the stack) or :main (it
becomes the main window, as in dwm).")

(defvar *vikix-main* (make-hash-table :test 'eq :weakness :key)
  "Each workspace in main and stack mode: (SHARE . WINDOWS), the main
window first.")

(defun vikix-main-p (&optional (group (current-group)))
  (and (gethash group *vikix-main*) t))

(defun vikix-main-windows (group)
  "GROUP's tiled windows in the mode's order: those it knows, then any it
hasn't met."
  (let* ((tiled (remove-if-not (lambda (w) (typep w 'tile-window)) (group-windows group)))
         (known (remove-if-not (lambda (w) (member w tiled)) (rest (gethash group *vikix-main*)))))
    (append known (remove-if (lambda (w) (member w known)) tiled))))

(defun vikix-main-head (window group)
  (or (ignore-errors (window-head window)) (group-current-head group)))

(defun vikix-main-standing (group)
  "GROUP's tiled windows as they stand: the one each frame shows, the
frames left to right and top to bottom, then the hidden ones."
  (let* ((frames (sort (copy-list (group-frames group))
                       (lambda (a b)
                         (or (< (frame-x a) (frame-x b))
                             (and (= (frame-x a) (frame-x b)) (< (frame-y a) (frame-y b)))))))
         (shown (remove nil (mapcar #'frame-window frames))))
    (append shown (remove-if (lambda (w) (member w shown)) (vikix-main-windows group)))))

(defun vikix-main-frame (group head)
  "HEAD's main frame: the one at its left edge."
  (let ((x (tree-x (tile-group-frame-head group head))))
    (find x (head-frames group head) :key #'frame-x)))

(defun vikix-main-in-shape-p (group)
  "True when every screen of GROUP stands as the mode lays it: a window in
every frame, one frame the screen's height on the left, the rest in one
column beside it."
  (let ((order (vikix-main-windows group)))
    (every (lambda (head)
             (let* ((tree (tile-group-frame-head group head))
                    (frames (head-frames group head))
                    (n (count head order :key (lambda (w) (vikix-main-head w group))))
                    (main (vikix-main-frame group head))
                    (stack (remove main frames)))
               (and (= (length frames) (max 1 (min n (1+ *vikix-main-stack-max*))))
                    (or (zerop n) (every #'frame-window frames))
                    main
                    (= (frame-height main) (tree-height tree))
                    (every (lambda (f)
                             (and (= (frame-x f) (+ (frame-x main) (frame-width main)))
                                  (= (frame-width f) (frame-width (first stack)))))
                           stack))))
           (group-heads group))))

(defun vikix-main-note (group)
  "Remember GROUP as it stands, when it stands in shape: two windows may
have been swapped, or the main one resized."
  (let* ((entry (gethash group *vikix-main*))
         (head (group-current-head group))
         (width (tree-width (tile-group-frame-head group head)))
         (main (vikix-main-frame group head)))
    (let ((standing (vikix-main-standing group)))
      ;; Two windows swapped (Super+Shift+h): the pointer goes with the one moved.
      (unless (equal standing (rest entry))
        (setf (rest entry) standing)
        (vikix-main-keep-pointer group)))
    ;; Only a width the share doesn't give already: 2/3 of 1280 is 853
    ;; points, and 853/1280 read back would be a share nobody chose.
    (when (and main (rest (head-frames group head))
               (/= (frame-width main) (round (* (first entry) width))))
      (setf (first entry) (/ (frame-width main) width)))))

(defun vikix-main-keep-pointer (group)
  "Focus follows the mouse: when windows move under a pointer that stays
still, the one that lands under it would take the focus the mode has just
given. So a pointer on the focused window's screen goes along with it, and
what X said of the moves is dropped (a strip does the same, viri.lisp)."
  (let ((window (group-current-window group)))
    (when (and window (typep window 'tile-window) (window-frame window))
      (let* ((f (window-frame window))
             (head (frame-head group f))
             (x (frame-x f)) (y (frame-y f)) (w (frame-width f)) (h (frame-height f)))
        (multiple-value-bind (px py) (xlib:global-pointer-position *display*)
          (when (and head
                     (<= (head-x head) px (+ (head-x head) (head-width head)))
                     (<= (head-y head) py (+ (head-y head) (head-height head)))
                     (not (and (<= x px (+ x w)) (<= y py (+ y h)))))
            (warp-pointer (group-screen group) (+ x (floor w 2)) (+ y (floor h 2)))))))
    (viri-drop-enter-events)))

(defun vikix-main-lay (group &optional focus)
  "Put GROUP's screens into main and stack, the windows in the mode's
order; FOCUS, or the window that had the focus, keeps it."
  (let* ((share (first (gethash group *vikix-main*)))
         (order (vikix-main-windows group))
         (focus (or focus (group-current-window group)))
         (number -1) (current nil) (fallback 0))
    (labels ((frame (x y w h windows)
               (let ((n (incf number))
                     (shown (if (member focus windows) focus (first windows))))
                 (when (member focus windows) (setf current n))
                 (make-fdump :number n :x x :y y :width w :height h
                             :windows (mapcar #'window-id windows)
                             :current (and shown (window-id shown)))))
             (stack (x y w h parts)     ; PARTS: each frame's windows
               (if (rest parts)
                   (let ((fh (floor h (length parts))))
                     (list (frame x y w fh (first parts))
                           (stack x (+ y fh) w (- h fh) (rest parts))))
                   (frame x y w h (first parts))))
             (screen (head)
               (let* ((old (tile-group-frame-head group head))
                      (x (tree-x old)) (y (tree-y old))
                      (w (tree-width old)) (h (tree-height old))
                      (windows (remove-if-not (lambda (win) (eq (vikix-main-head win group) head))
                                              order))
                      (others (rest windows))
                      (k (min (length others) *vikix-main-stack-max*)))
                 (when (eq head (group-current-head group))
                   (setf fallback (1+ number)))
                 (if (zerop k)
                     (frame x y w h windows)
                     (let ((mw (round (* share w))))
                       (list (frame x y mw h (list (first windows)))
                             (stack (+ x mw) y (- w mw) h
                                    (append (mapcar #'list (subseq others 0 (1- k)))
                                            (list (subseq others (1- k)))))))))))
      (let ((tree (mapcar #'screen (group-heads group))))
        (vikix-restore-layout
         group (make-gdump :number (group-number group) :name (group-name group)
                           :tree tree :current (or current fallback)))
        ;; A dialog that had the focus keeps it: the frames took it.
        (when (and focus (typep focus 'float-window) (member focus (group-windows group)))
          (group-focus-window group focus))
        (vikix-raise-dialogs)
        (vikix-main-keep-pointer group)))))

(defun vikix-main-retile (group &optional focus force)
  "Keep GROUP in main and stack, if it is in that mode, current, and not
in focus mode (Super+z): laid out again when it has lost the shape (or
FORCE), remembered as it stands when it hasn't."
  (when (and (vikix-main-p group)
             (eq group (current-group))
             (typep group 'tile-group)
             (not (vikix-solo-p group)))
    (handler-case
        (if (and (not force) (vikix-main-in-shape-p group))
            (vikix-main-note group)
            (vikix-main-lay group focus))
      (error (e) (message "Main and stack: ~a" e)))))

(defun vikix-main-new-window (window)
  (let* ((group (window-group window))
         (entry (gethash group *vikix-main*)))
    (cond ((not entry))
          ;; A dialog, floated out of the frame it opened in: the frame
          ;; is filled again.
          ((not (typep window 'tile-window))
           (vikix-main-retile group))
          (t
           (let* ((order (remove window (vikix-main-windows group)))
                  (head (vikix-main-head window group))
                  ;; Its own screen's main window: the new one goes after it.
                  (main (find head order :key (lambda (w) (vikix-main-head w group)))))
             (setf (rest entry)
                   (if (or (eq *vikix-main-new* :main) (null main))
                       (cons window order)
                       (loop for w in order
                             collect w
                             when (eq w main) collect window)))
             (vikix-main-retile group window t))))))

(defun vikix-main-destroy-window (window)
  (vikix-main-retile (window-group window)))

(defun vikix-main-focus-group (new old)
  (declare (ignore old))
  (vikix-main-retile new))

(defun vikix-main-after-command (command)
  ;; A split, a window floated or sent to another workspace, Super+z over:
  ;; whatever the command did, the workspace is in shape after it.
  (declare (ignore command))
  (vikix-main-retile (current-group)))

;; Last of the new-window hooks, after those that float a window (dialogs,
;; Lazarus, a rule): a window they take out of the tiles never gets a frame.
(setf *new-window-hook*
      (append (remove 'vikix-main-new-window *new-window-hook*) '(vikix-main-new-window)))
(add-hook *destroy-window-hook* 'vikix-main-destroy-window)
(add-hook *focus-group-hook* 'vikix-main-focus-group)
(add-hook *post-command-hook* 'vikix-main-after-command)

(defun vikix-main-cycle-share (group)
  "The main window's next width (Super+r)."
  (let* ((entry (gethash group *vikix-main*))
         (next (or (second (member (first entry) *vikix-main-shares*))
                   (first *vikix-main-shares*))))
    (setf (first entry) next)
    (vikix-main-retile group nil t)
    (message "Main window: ~a of the screen" next)))

(defcommand vikix-main (&optional how) ((:string nil))
  "Main and stack mode on/off (\"on\" or \"off\" to say which): this window
down the left of the screen, the others in a column on its right, kept so
as windows open and close."
  (let* ((group (current-group))
         (on (cond ((equal how "on") t)
                   ((equal how "off") nil)
                   (t (not (vikix-main-p group))))))
    (cond ((not (typep group 'tile-group))
           (message "Main and stack mode is for tiling workspaces"))
          ((and on (vikix-main-p group)))
          (on
           (setf *vikix-grid-groups* (remove group *vikix-grid-groups*))
           (remhash group *vikix-solo-layouts*)
           (let ((win (group-current-window group))
                 (standing (vikix-main-standing group)))
             (setf (gethash group *vikix-main*)
                   (cons (first *vikix-main-shares*)
                         (if (member win standing) (cons win (remove win standing)) standing))))
           (vikix-main-retile group nil t)
           (message "Main and stack mode on: Super+Shift+h makes a window the main one, Super+r its width"))
          ((vikix-main-p group)
           (remhash group *vikix-main*)
           (message "Main and stack mode off")))))

;;; Dialogs stay in front

;; A dialog nobody is waiting on can't be found: tiled, it takes its frame
;; like any window, and the next window focused or raised goes over it (a
;; sudo password box from a terminal, polkit's, a file chooser). So
;; dialogs float, centred on their screen, and stay above the tiles: each
;; time another window takes the focus, they're raised again. Clicking
;; elsewhere leaves a dialog unfocused but in sight. Super+t tiles one
;; that should be an ordinary window after all.

(defparameter *vikix-dialog-classes*
  '("zenity" "Zenity" "yad" "Yad" "Ssh-askpass" "ssh-askpass" "Gcr-prompter"
    "Pinentry" "pinentry" "Pinentry-gtk-2" "Polkit-gnome-authentication-agent-1"
    "Polkit-mate-authentication-agent-1" "Lxpolkit")
  "Window classes that are always dialogs, whatever their window type says
(zenity calls its boxes normal windows). Add your own in user.lisp:
(push \"Class\" *vikix-dialog-classes*); `xprop WM_CLASS` gives a
window's class, its second word.")

(defun vikix-born-dialog-p (win)
  "A dialog by what it is: its type, modal or transient, or one of
*vikix-dialog-classes*. Not one a rule only called a dialog."
  (and (or (window-transient-p win)
           (ignore-errors (window-modal-p win))
           (member (window-class win) *vikix-dialog-classes* :test #'equal))
       t))

(defun vikix-strip-column-p (win)
  "Is WIN a column of a strip (viri.lisp)? Such a window is a floating one
to StumpWM, and is no more a dialog for it than a tile is."
  (let ((group (window-group win)))
    (and (fboundp 'viri-group-p) (funcall 'viri-group-p group)
         (funcall 'viri-col-of group win)
         t)))

(defun vikix-dialog-p (win)
  "A window that asks something and waits: a dialog by its type, a modal
or transient one, one of *vikix-dialog-classes*, or one a rule made a
dialog of (rules.lisp, the verb dialog) that floats still. A rule's word
lasts only while the window floats over the others: tiled, or a column of
a strip, it is an ordinary window again. (A rule for every floating window
that takes the focus called each column of a strip a dialog, and a
workspace made tiles and a strip again left them all afloat.)"
  (or (vikix-born-dialog-p win)
      (and (boundp '*vikix-dialog-windows*)
           (gethash win (symbol-value '*vikix-dialog-windows*))
           (typep win 'float-window)
           (not (vikix-strip-column-p win)))))

(defun vikix-dialog-size (win head)
  "The size a dialog asked for. Tiled first, it was stretched to its frame
and its own size is lost, but its smallest size (WM_NORMAL_HINTS) is what
GTK and Qt dialogs are drawn at; without one, a modest box."
  (let* ((hints (window-normal-hints win))
         (w (and hints (xlib:wm-size-hints-min-width hints)))
         (h (and hints (xlib:wm-size-hints-min-height hints))))
    (values (min (if (and w (> w 50)) w 480) (- (head-width head) 40))
            (min (if (and h (> h 50)) h 240) (- (head-height head) 40)))))

(defun vikix-centre-window (win)
  "Give a floating dialog its own size, in the middle of its screen."
  (let ((head (window-head win)))
    (when head
      (multiple-value-bind (w h) (vikix-dialog-size win head)
        (float-window-move-resize
         win
         :width w :height h
         :x (+ (head-x head) (max 0 (floor (- (head-width head) w) 2)))
         :y (+ (head-y head) (max 0 (floor (- (head-height head) h) 2))))))))

(defun vikix-raise-dialogs (&rest ignore)
  "Put the current workspace's floating dialogs back above everything, and
the drawer (drawer.lisp) when it is out here, under them."
  (declare (ignore ignore))
  (ignore-errors
   (let ((group (current-group)))
     (when (fboundp 'vikix-drawer-raise)
       (funcall 'vikix-drawer-raise group))
     (when (typep group 'tile-group)
       (dolist (win (group-windows group))
         (when (and (typep win 'float-window) (vikix-dialog-p win) (window-visible-p win))
           (setf (xlib:window-priority (window-parent win)) :above)))))))

;; A window's WM_HINTS can't always be read: one program wrote the letters
;; "calc" where its icon's id belongs, CLX refused the number (an X id has
;; 29 bits), and StumpWM, which reads the hints at every raise and every
;; change of them (is the window urgent? does it take the keyboard?), met an
;; error it doesn't catch. Read forgivingly: when the hints can't be
;; decoded, the icon, the state and the group are left out, and what
;; StumpWM asks for is kept, the keyboard and the urgency.
(defun vikix-wm-hints (original window)
  "WINDOW's WM_HINTS as ORIGINAL (xlib:wm-hints) reads them, or, when it
can't, only their input and urgency; nil when even that can't be read."
  (handler-case (funcall original window)
    (error ()
      (ignore-errors
       (let ((raw (xlib:get-property window :WM_HINTS :type :WM_HINTS :result-type 'vector)))
         (when (and raw (plusp (length raw)))
           (let ((kept (copy-seq raw))
                 (input (and (> (length raw) 1) (member (aref raw 1) '(0 1)))))
             (setf (aref kept 0) (logand (aref raw 0) (if input #b100000001 #b100000000)))
             (xlib::decode-wm-hints kept (xlib:window-display window)))))))))

(sb-int:unencapsulate 'xlib:wm-hints 'vikix)
(sb-int:encapsulate 'xlib:wm-hints 'vikix 'vikix-wm-hints)

;; StumpWM hides a window that goes to a workspace not in view, and shows a
;; tile again when its frame does; nothing shows a floating one. So a
;; floating window sent to another workspace (Super+Shift+digit), or one a
;; rule opened there, was never seen again. Gone to, a workspace shows them,
;; in front and with the focus: they are what's new there.
(defun vikix-show-floats (new &rest ignore)
  "Show the floating windows of workspace NEW that arrived while it wasn't in view."
  (declare (ignore ignore))
  (ignore-errors
   (when (typep new 'tile-group)
     (dolist (win (reverse (group-windows new)))
       (when (and (typep win 'float-window)
                  (not (eql (window-state win) +normal-state+)))
         (unhide-window win)
         (focus-window win))))))

(remove-hook *focus-group-hook* 'vikix-show-floats)
(add-hook *focus-group-hook* 'vikix-show-floats)

(defun vikix-float-dialog (win)
  ;; Lazarus floats its own windows (above); never float one twice.
  (when (and (vikix-dialog-p win)
             (not (vikix-lazarus-window-p win))
             (typep win 'tile-window)
             (typep (window-group win) 'tile-group))
    (float-window win (window-group win))
    (vikix-centre-window win)
    (focus-window win)
    (vikix-raise-dialogs)))

(add-hook *new-window-hook* 'vikix-float-dialog)
(add-hook *focus-window-hook* 'vikix-raise-dialogs)
(add-hook *focus-group-hook* 'vikix-raise-dialogs)

;;; Dragging files between programs

;; Emacs, dragging a file out (dired, Esploro), finds the window under the
;; pointer from the window manager's _NET_CLIENT_LIST_STACKING when the
;; manager says it keeps one, and counts every listed window whose own X
;; window is mapped. StumpWM hides a window (another workspace, another in
;; the same frame) by unmapping the frame around it, not the window, so
;; Emacs took hidden windows, often one of its own frames, for what was
;; under the pointer: the drop came back to Emacs ("dropped in"), and the
;; program meant to get it got nothing. Not offered, Emacs asks the X
;; server what's under the pointer, as GTK does, and the drop arrives.
;; StumpWM still keeps the list; only Emacs's drag reads the offer. An
;; Emacs started before this sees it after a restart (it remembers the
;; offer until the window manager changes).

(defun vikix-hide-stacking-offer ()
  "Take _NET_CLIENT_LIST_STACKING out of the root window's _NET_SUPPORTED."
  (let ((stacking (xlib:find-atom *display* :_NET_CLIENT_LIST_STACKING)))
    (when stacking
      (dolist (screen *screen-list*)
        (let* ((root (screen-root screen))
               (supported (xlib:get-property root :_NET_SUPPORTED)))
          (when (member stacking supported)
            (xlib:change-property root :_NET_SUPPORTED (remove stacking supported)
                                  :atom 32)))))))

(handler-case (vikix-hide-stacking-offer)
  (error (e) (message "^1Vikix: the drag-and-drop fix:^n ~a" e)))

;;; Title bars, and floating

;; A strip at the top of each tiled window, and of each column's window on
;; a Viri workspace, with its number and name, in the
;; theme's accent when focused. StumpWM draws none of its own: after it lays
;; a window out, the window is moved down inside its frame (StumpWM's
;; "parent" X window) and the bar is a child window in the space above it.
;; The bar's text is its background picture, so X redraws it whenever it is
;; uncovered; StumpWM, which ignores exposure of windows not its own, never
;; has to. Floating windows have StumpWM's own title strip; fullscreen ones
;; and dialogs StumpWM keeps at their own size go without. s-C-y turns the
;; bars off and on, remembered in ~/.config/vikix/titlebars-off.

(defvar *vikix-titlebars-off-file*
  (merge-pathnames ".config/vikix/titlebars-off" (user-homedir-pathname)))

(defvar *vikix-titlebars* (not (probe-file *vikix-titlebars-off-file*))
  "True while tiled windows have title bars.")
(defvar *vikix-titlebar-windows* (make-hash-table :test 'eq)
  "Each StumpWM window's title bar (an X window), while it has one.")
(defvar *vikix-plain-maximize-window* nil
  "The maximize-window the title bars wrap: StumpWM's, or the gaps-safe one above.")

(defun vikix-free-drawn-pixmap (pixmap)
  "Free PIXMAP, and with it what the font renderer keeps for anything text
was drawn on: clx-truetype leaves two pictures and a 1x1 pen pixmap in the
drawable's plist and never frees them, and a picture keeps its pixmap alive
in the X server after free-pixmap. A title bar's picture a second (a
terminal's title changing) was a gigabyte an hour in Xorg."
  (let ((plist (xlib:drawable-plist pixmap)))
    (dolist (key '(:ttf-surface :ttf-pen))
      (let ((picture (getf plist key)))
        (when picture (ignore-errors (xlib:render-free-picture picture)))))
    (let ((pen (getf plist :ttf-pen-surface)))
      (when pen (ignore-errors (xlib:free-pixmap pen))))
    (setf (xlib:drawable-plist pixmap) nil))
  (xlib:free-pixmap pixmap))

(defun vikix-titlebar-height ()
  (+ 4 (font-height (screen-font (current-screen)))))

(defvar *vikix-titlebar-pixels* (make-hash-table :test 'equal)
  "Each colour a title bar was painted in (\"#rrggbb\"), and its pixel.")

(defun vikix-titlebar-attention (screen win)
  "The background and text colours (pixels) of WIN's title bar when its
agent's terminal needs you (vikix-window-attention, agents.lisp: asks, gup,
close), in the theme's colour for it; nil otherwise."
  (let ((kind (and (fboundp 'vikix-window-attention) (ignore-errors (funcall 'vikix-window-attention win)))))
    (when kind
      (let ((colour (funcall 'vikix-attention-colour kind)))
        (values (or (gethash colour *vikix-titlebar-pixels*)
                    (setf (gethash colour *vikix-titlebar-pixels*) (alloc-color screen colour)))
                (screen-bg-color screen))))))

(defun vikix-titlebar-draw (win)
  "Paint WIN's title bar: its number and name. Focused, in the focus colour;
in the colour of what its agent needs of you, when it needs something."
  (let ((bar (gethash win *vikix-titlebar-windows*)))
    (when bar
      (let* ((screen (window-screen win))
             (font (screen-font screen))
             (focused (eq win (screen-focus screen)))
             (bg (if focused (screen-focus-color screen) (screen-unfocus-color screen)))
             (fg (if focused (screen-bg-color screen) (screen-fg-color screen)))
             (w (max 1 (xlib:drawable-width bar)))
             (h (max 1 (xlib:drawable-height bar)))
             (pm (xlib:create-pixmap :width w :height h :drawable bar
                                     :depth (xlib:drawable-depth bar)))
             (gc (xlib:create-gcontext :drawable pm :foreground bg :background bg)))
        (multiple-value-bind (needs-bg needs-fg) (vikix-titlebar-attention screen win)
          (when needs-bg
            (setf bg needs-bg fg needs-fg (xlib:gcontext-foreground gc) bg (xlib:gcontext-background gc) bg)))
        (unwind-protect
             (let ((tabs (and (fboundp 'viri-titlebar-tabs) (funcall 'viri-titlebar-tabs win))))
               (xlib:draw-rectangle pm gc 0 0 w h t)
               (if (null tabs)
                   (progn
                     (setf (xlib:gcontext-foreground gc) fg)
                     (draw-image-glyphs pm gc font 6 (+ 2 (font-ascent font))
                                        (format nil "~d  ~a" (window-number win) (window-name win))
                                        :translate #'translate-id :size 16))
                   ;; A tabbed column on a strip (viri.lisp): a cell for each
                   ;; of its windows, this one's as a title bar is, the
                   ;; others' in the screen's own colours.
                   (let ((cell (floor w (length tabs)))
                         (char (max 1 (round (text-line-width font "MMMMMMMMMM" :translate #'translate-id) 10))))
                     (loop for tab in tabs
                           for i from 0
                           for x = (* i cell)
                           for cw = (if (= i (1- (length tabs))) (- w x) cell)
                           for mine = (eq tab win)
                           for needs = (and (not mine) (vikix-titlebar-attention screen tab))
                           for cell-bg = (cond (mine bg) (needs needs) (t (screen-bg-color screen)))
                           for cell-fg = (cond (mine fg) (needs (screen-bg-color screen)) (t (screen-fg-color screen)))
                           for text = (format nil "~d  ~a" (window-number tab) (window-name tab))
                           for room = (max 0 (floor (- cw 12) char))
                           do (setf (xlib:gcontext-foreground gc) cell-bg
                                    (xlib:gcontext-background gc) cell-bg)
                              (xlib:draw-rectangle pm gc x 0 cw h t)
                              (setf (xlib:gcontext-foreground gc) cell-fg)
                              (draw-image-glyphs pm gc font (+ x 6) (+ 2 (font-ascent font))
                                                 (if (> (length text) room) (subseq text 0 room) text)
                                                 :translate #'translate-id :size 16)))))
          (xlib:free-gcontext gc))
        ;; X keeps the picture while it is the background.
        (setf (xlib:window-background bar) pm)
        (vikix-free-drawn-pixmap pm)
        (xlib:clear-area bar)))))

(defun vikix-titlebar-remove (win)
  (let ((bar (gethash win *vikix-titlebar-windows*)))
    (when bar
      (remhash win *vikix-titlebar-windows*)
      (ignore-errors (xlib:destroy-window bar)))))

(defun vikix-titlebar-fit (win height)
  "HEIGHT, or less, so that it's a height WIN asks for. A terminal (xterm,
Emacs) asks for whole rows: a base and a step (WM_NORMAL_HINTS). Given a
height between two, it fits itself to a row and says so again in its
hints; StumpWM lays it out again on that, the bar takes its room again,
and round it goes, the main thread never resting (bugs.md, 2026-10-02)."
  (let* ((hints (window-normal-hints win))
         (inc (and hints (xlib:wm-size-hints-height-inc hints)))
         (base (and hints (or (xlib:wm-size-hints-base-height hints)
                              (xlib:wm-size-hints-min-height hints)
                              0))))
    (max 1 (if (and inc (> inc 1) base (> height base))
               (+ base (* inc (floor (- height base) inc)))
               height))))

(defun vikix-titlebar-wants-p (win parent-height)
  "Whether WIN, its frame PARENT-HEIGHT high, has a title bar."
  (and *vikix-titlebars*
       (typep win 'tile-window)
       (not (window-fullscreen win))
       ;; :tight and :none fit the parent to the window: no room.
       (not (find *window-border-style* '(:tight :none)))
       (not (nth-value 7 (geometry-hints win)))   ; kept at its own size
       (> parent-height (* 3 (vikix-titlebar-height)))))

(defun vikix-titlebar-show (win &optional (width (xlib:drawable-width (window-parent win))))
  "WIN's bar across the top of its parent, WIDTH wide: made if it has none,
and painted. The caller has left it room above the window."
  (let ((parent (window-parent win))
        (h (vikix-titlebar-height))
        (bar (gethash win *vikix-titlebar-windows*)))
    (unless bar
      ;; The screen's own visual, not the parent's: a terminal with
      ;; transparency gives its parent 32 bits, and smoothed text
      ;; then comes out with coloured fringes.
      (let ((root (screen-root (window-screen win))))
        (setf bar (xlib:create-window
                   :parent parent :x 0 :y 0 :width width :height h
                   :depth (xlib:drawable-depth root)
                   :visual (xlib:window-visual-info root)
                   :colormap (xlib:screen-default-colormap
                              (screen-number (window-screen win)))
                   :border 0 :border-width 0 :event-mask '())
              (gethash win *vikix-titlebar-windows*) bar)))
    (xlib:with-state (bar)
      (setf (xlib:drawable-x bar) 0 (xlib:drawable-y bar) 0
            (xlib:drawable-width bar) width (xlib:drawable-height bar) h))
    (xlib:map-window bar)
    (vikix-titlebar-draw win)))

(defun vikix-titlebar-place (win)
  "After StumpWM has laid WIN out: make room at its top and put its bar there."
  (let ((parent (window-parent win))
        (h (vikix-titlebar-height)))
    (if (vikix-titlebar-wants-p win (xlib:drawable-height parent))
        (let ((ph (xlib:drawable-height parent))
              (y (max h (xlib:drawable-y (window-xwin win)))))
          (set-window-geometry win :y y :height (vikix-titlebar-fit win (min (window-height win) (- ph y))))
          (vikix-titlebar-show win)
          (update-configuration win))
        (vikix-titlebar-remove win))))

(defun vikix-titled-maximize-window (win)
  "maximize-window, then the title bar. A fault in the bar never stops the layout."
  (funcall *vikix-plain-maximize-window* win)
  (handler-case (vikix-titlebar-place win)
    (error (e) (message "^1Vikix: title bar:^n ~a" e))))

;; Wrap whatever maximize-window is now (the gaps section set its own). On
;; a reload that section sets it again, and this wraps that, never itself.
(let ((current (symbol-function 'maximize-window)))
  (unless (eq (sb-kernel:%fun-name current) 'vikix-titled-maximize-window)
    (setf *vikix-plain-maximize-window* current))
  (setf (symbol-function 'maximize-window) #'vikix-titled-maximize-window))

(defun vikix-titlebar-redraw (&rest windows)
  (dolist (w windows)
    (when w (ignore-errors (vikix-titlebar-draw w)))))

(defun vikix-titlebar-forget (win)
  ;; X destroys the bar with the window's parent; only forget it here.
  (remhash win *vikix-titlebar-windows*))

(remove-hook *focus-window-hook* 'vikix-titlebar-redraw)
(add-hook *focus-window-hook* 'vikix-titlebar-redraw)
(remove-hook *destroy-window-hook* 'vikix-titlebar-forget)
(add-hook *destroy-window-hook* 'vikix-titlebar-forget)

;; A window that renames itself (a terminal's title following its directory).
(sb-int:unencapsulate 'update-window-properties 'vikix-titlebar)
(sb-int:encapsulate 'update-window-properties 'vikix-titlebar
                    (lambda (f window atom)
                      (prog1 (funcall f window atom)
                        (when (eq atom :wm_name)
                          (vikix-titlebar-redraw window)))))

(defun vikix-titlebars-relayout ()
  "Lay every tiled window out again, so each gets, loses or repaints its bar.
theme.lisp calls it after a theme change."
  (dolist (screen *screen-list*)
    (dolist (win (screen-windows screen))
      (when (typep win 'tile-window)
        (maximize-window win))))
  ;; A strip on the screen now (viri.lisp, loaded later); one on another
  ;; workspace is laid out as you come to it.
  (when (and (fboundp 'viri-group-p) (funcall 'viri-group-p (current-group)))
    (funcall 'viri-layout (current-group))))

(defcommand vikix-titlebars () ()
  "Title bars on tiled windows and a strip's columns, on or off."
  (setf *vikix-titlebars* (not *vikix-titlebars*))
  (handler-case
      (if *vikix-titlebars*
          (when (probe-file *vikix-titlebars-off-file*)
            (delete-file *vikix-titlebars-off-file*))
          (progn (ensure-directories-exist *vikix-titlebars-off-file*)
                 (with-open-file (out *vikix-titlebars-off-file* :direction :output
                                                                  :if-exists :supersede)
                   (write-line "Title bars off (Super+Ctrl+y turns them on)." out))))
    (error () nil))   ; not remembered, but still switched
  (vikix-titlebars-relayout)
  (message "Title bars ~:[off~;on~]" *vikix-titlebars*))

(defcommand vikix-title (title) ((:rest "Name this window: "))
  "Rename the focused window; its title bar and the bar show the new name."
  (let ((win (current-window)))
    (if win
        (progn (setf (window-user-title win) title)
               (vikix-titlebar-redraw win)
               (update-all-mode-lines))
        (message "No window to name."))))

(defcommand vikix-float () ()
  "Float the focused window, or put a floating one back in the tiles."
  (let ((win (current-window)))
    (cond ((null win) (message "No window to float."))
          ((typep win 'float-window) (unfloat-this))
          (t (vikix-titlebar-remove win)
             (float-this)))))

(vikix-titlebars-relayout)

;;; The desktop as data: what vikix mcp's desktop tool answers with, and
;;; what VikixDesktop in Cuis draws (cuis/VikixDesktop.pck.st, once a
;;; second through Swank). One function, so the two never drift: the
;;; workspaces in order with their windows (number, title, class, which has
;;; the focus), a strip's columns (viri.lisp, which loads after this file,
;;; so asked by name), and the screens. A title is another program's text,
;;; cut at 200 characters and escaped as JSON; nothing here runs a program.
(defun vikix-json-escape (s)
  "S (anything, printed) as the inside of a JSON string."
  (with-output-to-string (o)
    (loop for c across (princ-to-string (or s ""))
          do (case c
               (#\" (write-string "\\\"" o))
               (#\\ (write-string "\\\\" o))
               (t (if (< (char-code c) 32)
                      (format o "\\u~4,'0x" (char-code c))
                      (write-char c o)))))))

(defun vikix-desktop-json ()
  "The desktop now, as a JSON text: workspaces (name, number, current, kind,
strip, windows) and screens."
  (labels ((str (s) (format nil "\"~a\"" (vikix-json-escape s)))
           (short (s) (let ((s (princ-to-string (or s "")))) (subseq s 0 (min 200 (length s)))))
           (bool (x) (if x "true" "false"))
           (strip-p (g) (and (fboundp 'viri-group-p) (funcall 'viri-group-p g))))
    (let ((cw (current-window)))
      (format nil "{\"workspaces\":[~{~a~^,~}],\"screens\":[~{~a~^,~}]}"
              (mapcar (lambda (g)
                        (format nil "{\"name\":~a,\"number\":~d,\"current\":~a,\"kind\":~a,\"strip\":~a,\"windows\":[~{~a~^,~}]}"
                                (str (short (group-name g))) (group-number g) (bool (eq g (current-group)))
                                ;; tiles, a strip (its columns left to right, each its
                                ;; share of the screen, its windows top to bottom by
                                ;; number, and whether it's wholly on the screen), or floating.
                                (str (cond ((strip-p g) "strip")
                                           ((typep g 'tile-group) "tiles")
                                           (t "floating")))
                                (if (strip-p g)
                                    (let ((shown (ignore-errors (funcall 'viri-visible g))))
                                      (format nil "{\"columns\":[~{~a~^,~}]}"
                                              (loop for c in (funcall 'viri-cols g)
                                                    for i from 0
                                                    collect (format nil "{\"width\":~a,\"on_screen\":~a,\"windows\":[~{~d~^,~}]}"
                                                                    (str (funcall 'viri-col-width c)) (bool (member i shown))
                                                                    (mapcar #'window-number (funcall 'viri-col-windows c))))))
                                    "null")
                                (mapcar (lambda (w)
                                          (format nil "{\"number\":~d,\"title\":~a,\"class\":~a,\"focused\":~a}"
                                                  (window-number w) (str (short (window-title w)))
                                                  (str (short (window-class w))) (bool (eq w cw))))
                                        (group-windows g))))
                      (sort (copy-list (screen-groups (current-screen))) #'< :key #'group-number))
              (mapcar (lambda (h)
                        (format nil "{\"number\":~d,\"x\":~d,\"y\":~d,\"width\":~d,\"height\":~d}"
                                (head-number h) (head-x h) (head-y h) (head-width h) (head-height h)))
                      (screen-heads (current-screen)))))))
