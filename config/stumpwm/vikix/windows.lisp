;;;; windows.lisp — how windows are focused, spaced and found.
;;;;
;;;;   focus      follows the mouse (sloppy focus)
;;;;   gaps       space around windows, off at start (s-C-g toggles)
;;;;   undo       the last split or window move, per workspace (s-u, s-U)
;;;;   grid       every window in a grid: once (s-o), or kept so (s-O)
;;;;   find       any window on any workspace (s-g goes there, s-G brings it here)
;;;;   beckon     the pointer jumps to the focused window (s-p)
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

(defun vikix-layout-command-p (command)
  (or (member command (symbol-value (find-symbol "*DEFAULT-COMMANDS*" :winner-mode)))
      (member command '(gmove gmove-and-follow expose vikix-grid))))

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
back as it was."
  (let ((group (current-group)))
    (cond ((not (typep group 'tile-group))
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

(defun vikix-dialog-p (win)
  "A window that asks something and waits: a dialog by its type, a modal
or transient one, one of *vikix-dialog-classes*, or one a rule made a
dialog of (rules.lisp, the verb dialog)."
  (or (window-transient-p win)
      (ignore-errors (window-modal-p win))
      (member (window-class win) *vikix-dialog-classes* :test #'equal)
      (and (boundp '*vikix-dialog-windows*)
           (gethash win (symbol-value '*vikix-dialog-windows*)))))

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
  "Put the current workspace's floating dialogs back above everything."
  (declare (ignore ignore))
  (ignore-errors
   (let ((group (current-group)))
     (when (typep group 'tile-group)
       (dolist (win (group-windows group))
         (when (and (typep win 'float-window) (vikix-dialog-p win) (window-visible-p win))
           (setf (xlib:window-priority (window-parent win)) :above)))))))

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

;; A strip at the top of each tiled window with its number and name, in the
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

(defun vikix-titlebar-height ()
  (+ 4 (font-height (screen-font (current-screen)))))

(defun vikix-titlebar-draw (win)
  "Paint WIN's title bar: its number and name."
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
        (unwind-protect
             (progn
               (xlib:draw-rectangle pm gc 0 0 w h t)
               (setf (xlib:gcontext-foreground gc) fg)
               (draw-image-glyphs pm gc font 6 (+ 2 (font-ascent font))
                                  (format nil "~d  ~a" (window-number win) (window-name win))
                                  :translate #'translate-id :size 16))
          (xlib:free-gcontext gc))
        ;; X keeps the picture while it is the background.
        (setf (xlib:window-background bar) pm)
        (xlib:free-pixmap pm)
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

(defun vikix-titlebar-place (win)
  "After StumpWM has laid WIN out: make room at its top and put its bar there."
  (let ((parent (window-parent win))
        (h (vikix-titlebar-height)))
    (if (vikix-titlebar-wants-p win (xlib:drawable-height parent))
        (let ((pw (xlib:drawable-width parent))
              (ph (xlib:drawable-height parent))
              (bar (gethash win *vikix-titlebar-windows*))
              (y (max h (xlib:drawable-y (window-xwin win)))))
          (set-window-geometry win :y y :height (vikix-titlebar-fit win (min (window-height win) (- ph y))))
          (unless bar
            ;; The screen's own visual, not the parent's: a terminal with
            ;; transparency gives its parent 32 bits, and smoothed text
            ;; then comes out with coloured fringes.
            (let ((root (screen-root (window-screen win))))
              (setf bar (xlib:create-window
                         :parent parent :x 0 :y 0 :width pw :height h
                         :depth (xlib:drawable-depth root)
                         :visual (xlib:window-visual-info root)
                         :colormap (xlib:screen-default-colormap
                                    (screen-number (window-screen win)))
                         :border 0 :border-width 0 :event-mask '())
                    (gethash win *vikix-titlebar-windows*) bar)))
          (xlib:with-state (bar)
            (setf (xlib:drawable-x bar) 0 (xlib:drawable-y bar) 0
                  (xlib:drawable-width bar) pw (xlib:drawable-height bar) h))
          (xlib:map-window bar)
          (vikix-titlebar-draw win)
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
        (maximize-window win)))))

(defcommand vikix-titlebars () ()
  "Title bars on tiled windows on or off."
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
