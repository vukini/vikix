;;;; windows.lisp — how windows are focused, spaced and found.
;;;;
;;;;   focus      follows the mouse (sloppy focus)
;;;;   gaps       space around windows, off at start (s-g toggles)
;;;;   undo       the last split or window move, per workspace (s-u, s-U)
;;;;   grid       every window in a grid: once (s-o), or kept so (s-O)
;;;;   find       any window on any workspace (s-A goes there, s-C-a pulls it here)
;;;;   beckon     the pointer jumps to the focused window (s-p)
;;;;   lazarus    the docked IDE tiles; its dialogs float
;;;;
;;;; Gaps, undo, find and beckon come from stumpwm-contrib, cloned into
;;;; ~/.stumpwm.d/modules by install/30-lisp. The keys are in keys.lisp.

(in-package :stumpwm)

;; Focus moves to the window under the mouse, without a click.
(setf *mouse-focus-policy* :sloppy)

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
;; plus gmove (s-C-<digit>). Left to itself it has two gaps, filled here:
;;   - it never records the layout before the first change, so that
;;     change can't be undone; it is recorded just before it instead
;;   - after an undo, a new change leaves the old redo steps in place;
;;     they are dropped, as in any editor
;; Named functions, so a reload doesn't add the hooks twice.

(defun vikix-layout-command-p (command)
  (or (member command (symbol-value (find-symbol "*DEFAULT-COMMANDS*" :winner-mode)))
      (member command '(gmove gmove-and-follow expose vikix-grid))))

(defun vikix-layout-ids (name)
  "winner-mode's table NAME: workspace number → layout step."
  (symbol-value (find-symbol name :winner-mode)))

(defun vikix-record-layout ()
  (let ((n (group-number (current-group))))
    (funcall (find-symbol "DUMP-GROUP-TO-FILE" :winner-mode))
    (setf (gethash n (vikix-layout-ids "*MAX-IDS*"))
          (gethash n (vikix-layout-ids "*CURRENT-IDS*")))))

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
           (push group *vikix-grid-groups*)
           (vikix-grid-retile group)
           (message "Grid mode on: windows re-tile as they open and close")))))

;;; Finding windows, and the pointer

(vikix-load-module "globalwindows")
(vikix-load-module "beckon")

;;; Lazarus

;; 65-languages builds Lazarus with its docked IDE (anchordockingdsgn and
;; dockedformeditor): menu, editor, object inspector and form designer
;; share one main window, which tiles like any other. Every other Lazarus
;; window (dialogs, the welcome screen, anything undocked) floats. Tiled,
;; StumpWM would stretch each to fill a frame, and fight Lazarus over its
;; size, which flickers.
(defun vikix-lazarus-window-p (win)
  (search "lazarus" (string-downcase (or (window-class win) ""))))

(defun vikix-lazarus-main-window-p (win)
  "The IDE's main window. Its title settles as \"Lazarus IDE v...\", but
StumpWM sees it before that: the Qt5 build (Void's) first calls it
\"Lazarus\", or \"MainIDE\" (its form's name) with the docked IDE."
  (let ((title (or (window-title win) "")))
    (or (member title '("Lazarus" "MainIDE") :test #'string=)
        (string= "Lazarus IDE v" title :end2 (min (length title) 13)))))

(defun vikix-float-lazarus-window (win)
  ;; Only a tiled window: floating one twice (another hook may do it too,
  ;; as an older user.lisp does) would be an error.
  (when (and (vikix-lazarus-window-p win)
             (not (vikix-lazarus-main-window-p win))
             (typep win 'tile-window)
             (typep (window-group win) 'tile-group))
    (float-window win (window-group win))))

(add-hook *new-window-hook* 'vikix-float-lazarus-window)
