;;;; viri.lisp — a workspace that scrolls sideways (Viri, DESIGN-viri.md).
;;;;
;;;; Tiling's weak point is the fourth window: it makes the other three too
;;;; narrow. On a Viri workspace the windows stand in a strip of columns
;;;; wider than the screen, each half the screen wide, and the screen shows
;;;; two of them; moving the focus along the strip scrolls it. Nothing
;;;; shrinks when a window opens. Niri's idea, as a StumpWM group type.
;;;;
;;;;   vikix-viri        this workspace becomes a strip (its windows kept,
;;;;                     left to right as they were), or tiles again, split
;;;;                     as they were before it was a strip
;;;;   Super+h / l       focus along the strip (move-focus elsewhere)
;;;;   Super+Shift+h / l move the column along it (move-window elsewhere)
;;;;
;;;; Phase 0: one window a column, all half the screen, no overview. A
;;;; Viri workspace is a float group whose windows Viri places itself, so
;;;; StumpWM's own floating code (focus, raising, fullscreen, dialogs) does
;;;; the rest. Columns off the screen are moved past its edge, not hidden:
;;;; they keep drawing, and come back at once.

(in-package :stumpwm)

(defparameter *viri-visible-columns* 2
  "How many columns the screen shows at once: each is the screen's width
divided by this.")

(defvar *viri-appending* nil
  "True while a workspace becomes a strip: its windows go in at the end, in
the order they stood, not each beside the focused one.")

(define-swm-class viri-group (float-group)
  ((columns :initform '() :accessor viri-columns
            :documentation "The strip's windows, left to right, one a column.")
   (left :initform 0 :accessor viri-left
         :documentation "The first column the screen shows.")
   (head :initform nil :accessor viri-group-head
         :documentation "The screen the strip is on (one, for now).")
   (tiles :initform nil :accessor viri-tiles
          :documentation "The tiles' layout it was made from (dump-group), for
vikix-viri off to put back.")))

(defun viri-group-p (&optional (group (current-group)))
  (typep group 'viri-group))

(defun viri-floats-p (window)
  "A window that floats over the strip instead of taking a column: a dialog
(vikix-dialog-p, windows.lisp)."
  (and (fboundp 'vikix-dialog-p) (funcall 'vikix-dialog-p window)))

(defun viri-head (group)
  "The head the strip is on, or the screen's first when that one has gone."
  (let ((heads (screen-heads (group-screen group))))
    (if (member (viri-group-head group) heads) (viri-group-head group) (first heads))))

(defun viri-area (group)
  "The strip's part of the screen, below or above the bar: (values x y width height)."
  (let* ((head (viri-head group))
         (ml (head-mode-line head))
         (bar (if ml (mode-line-height ml) 0))
         (top (and ml (not (eq *mode-line-position* :bottom)))))
    (values (head-x head)
            (+ (head-y head) (if top bar 0))
            (head-width head)
            (- (head-height head) bar))))

(defun viri-border (window)
  "Give a column the tiles' border (the focused one in the accent colour,
as theme.lisp sets it), and say how wide it is."
  (let ((parent (window-parent window)))
    (unless (= (xlib:drawable-border-width parent) *normal-border-width*)
      (setf (xlib:drawable-border-width parent) *normal-border-width*))
    (update-decoration window)
    *normal-border-width*))

(defmethod update-decoration :around ((window float-window))
  ;; A column shows the focus as a tile does: by its border's colour. A
  ;; float group's own way (the parent's background) shows nothing here.
  (let ((group (window-group window)))
    (if (and (viri-group-p group) (member window (viri-columns group)))
        (let ((screen (group-screen group)))
          (setf (xlib:window-border (window-parent window))
                (if (eq (group-current-window group) window)
                    (screen-focus-color screen)
                    (screen-unfocus-color screen))))
        (call-next-method))))

(defun viri-layout (group)
  "Put every column where it belongs: those from LEFT on the screen, side
by side, the rest past its edges."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (let* ((cols (viri-columns group))
           (n (max 1 *viri-visible-columns*))
           (cw (floor aw n)))
      (setf (viri-left group) (max 0 (min (viri-left group) (- (length cols) n))))
      (loop for w in cols
            for i from 0
            for x = (+ ax (* (- i (viri-left group)) cw))
            ;; A strip shows every column: a window the tiles had hidden
            ;; (iconic) is shown again, now, or when the workspace is.
            when (window-hidden-p w)
              do (unhide-window w)
            unless (window-fullscreen w)
              do (let ((border (* 2 (viri-border w))))
                   (set-window-geometry w :x 0 :y 0)
                   (float-window-move-resize w :x x :y ay
                                               :width (max 1 (- cw border))
                                               :height (max 1 (- ah border))
                                               :border 0)))))
    (viri-keep-pointer group)
    (update-all-mode-lines))

(defun viri-drop-enter-events ()
  "Moving windows makes X say the pointer entered whichever lands under it,
and sloppy focus would act on that after the strip has chosen the focus.
So once X has done the moves (a round trip), those notes are dropped;
every other event stays queued."
  (xlib:display-finish-output *display*)
  (loop while (xlib:event-case (*display* :timeout 0 :discard-p nil)
                (:enter-notify () t)
                (t () nil))))

(defun viri-keep-pointer (group)
  "Focus follows the mouse (Vikix's is sloppy): when the strip moves under
a pointer that stays still, the window that lands under it would take the
focus. So a pointer over the strip goes along with the focused window."
  (let ((window (group-current-window group)))
    (when (and window (member window (viri-columns group))
               (eq group (screen-current-group (group-screen group))))
      (multiple-value-bind (px py) (xlib:global-pointer-position *display*)
        (multiple-value-bind (ax ay aw ah) (viri-area group)
          (let* ((p (window-parent window))
                 (x (xlib:drawable-x p)) (y (xlib:drawable-y p))
                 (w (xlib:drawable-width p)) (h (xlib:drawable-height p)))
            (when (and (< ax px (+ ax aw)) (< ay py (+ ay ah))
                       (not (and (<= x px (+ x w)) (<= y py (+ y h)))))
              (warp-pointer (group-screen group) (+ x (floor w 2)) (+ y (floor h 2)))))))
      (viri-drop-enter-events))))

(defun viri-scroll-to (group window)
  "Scroll so WINDOW's column is on the screen; true when it moved."
  (let ((i (position window (viri-columns group)))
        (n (max 1 *viri-visible-columns*))
        (left (viri-left group)))
    (when i
      (setf (viri-left group) (cond ((< i left) i)
                                    ((>= i (+ left n)) (1+ (- i n)))
                                    (t left)))
      (/= left (viri-left group)))))

;;; What StumpWM asks of a group, where a strip differs from a float group.

(defmethod group-add-window ((group viri-group) window &key &allow-other-keys)
  ;; Vikix's title bars are for tiles (windows.lisp); one left from the
  ;; tiles would cover the top of the window here.
  (when (fboundp 'vikix-titlebar-remove)
    (funcall 'vikix-titlebar-remove window))
  ;; A new column goes right of the focused one, the way you're working.
  (unless (or (viri-floats-p window) (member window (viri-columns group)))
    (let* ((cols (viri-columns group))
           (at (and (not *viri-appending*) (position (group-current-window group) cols))))
      (setf (viri-columns group)
            (if at
                (append (subseq cols 0 (1+ at)) (list window) (nthcdr (1+ at) cols))
                (append cols (list window))))))
  (call-next-method)
  (when (viri-floats-p window)
    (viri-centre window group))
  (viri-layout group))

(defun viri-centre (window group)
  "A dialog in the middle of the strip's part of the screen, at its own size."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (let* ((p (window-parent window))
           (w (xlib:drawable-width p))
           (h (xlib:drawable-height p)))
      (float-window-move-resize window :x (+ ax (max 0 (floor (- aw w) 2)))
                                       :y (+ ay (max 0 (floor (- ah h) 2)))))))

(defmethod group-delete-window ((group viri-group) (window float-window))
  (let* ((cols (viri-columns group))
         (i (position window cols)))
    (cond ((null i) (call-next-method))
          (t
           (setf (viri-columns group) (remove window cols))
           (let ((left (viri-columns group)))
             (viri-layout group)
             (if left
                 ;; The neighbour that took its place, or the last one.
                 (group-focus-window group (nth (min i (1- (length left))) left))
                 (call-next-method)))))))

(defmethod group-focus-window ((group viri-group) window)
  ;; Focused first, then scrolled to: the layout brings the pointer along
  ;; to the window that has the focus now.
  (call-next-method)
  (if (viri-scroll-to group window)
      (viri-layout group)
      ;; Not scrolled, but a new window first shows where it likes, over
      ;; the pointer, before it's put in its column: the pointer goes to it.
      (viri-keep-pointer group)))

(defmethod group-wake-up ((group viri-group))
  (viri-layout group)
  (call-next-method))

(defmethod group-current-head ((group viri-group))
  (viri-head group))

;; A column's place is the strip's: a window asking to move or resize
;; itself is put back. A floating dialog does as it asks.
(defmethod group-resize-request ((group viri-group) window width height)
  (if (member window (viri-columns group)) (viri-layout group) (call-next-method)))

(defmethod group-move-request ((group viri-group) window x y relative-to)
  (if (member window (viri-columns group)) (viri-layout group) (call-next-method)))

(defmethod group-after-resize-head ((group viri-group) head)
  (declare (ignore head))
  (viri-layout group))

(defmethod group-sync-all-heads ((group viri-group))
  (viri-layout group))

;;; Moving along the strip.

(defun viri-step (dir move)
  "Focus the column left or right of the focused one; with MOVE, take the
focused column there instead. Up and down do nothing yet (Phase 0 has
one window a column)."
  (let* ((group (current-group))
         (cols (viri-columns group))
         (window (group-current-window group))
         (i (position window cols))
         (j (and i (case dir (:left (1- i)) (:right (1+ i))))))
    (cond ((null cols))
          ((null i) (group-focus-window group (first cols)))   ; on a dialog: back to the strip
          ((or (null j) (< j 0) (>= j (length cols))))
          (move
           (rotatef (nth i (viri-columns group)) (nth j (viri-columns group)))
           (viri-scroll-to group window)
           (viri-layout group))
          (t (group-focus-window group (nth j cols))))))

(defcommand vikix-focus (dir) ((:direction "Direction: "))
  "Focus the window that way: along the strip on a Viri workspace, the
frame that way (move-focus) elsewhere."
  (if (viri-group-p)
      (viri-step dir nil)
      (run-commands (format nil "move-focus ~(~a~)" dir))))

(defcommand vikix-move (dir) ((:direction "Direction: "))
  "Move the window that way: its column along the strip on a Viri
workspace, into the frame that way (move-window) elsewhere."
  (if (viri-group-p)
      (viri-step dir t)
      (run-commands (format nil "move-window ~(~a~)" dir))))

;;; A workspace becomes a strip, and back.

(defun viri-left-to-right (group)
  "GROUP's windows in the order they stand: by frame, left to right and
then top to bottom, in a tile group; by column in a strip; dialogs last."
  (if (viri-group-p group)
      (append (viri-columns group)
              (remove-if (lambda (w) (member w (viri-columns group))) (group-windows group)))
      (stable-sort (copy-list (group-windows group)) #'<
                   :key (lambda (w)
                          (let ((f (ignore-errors (window-frame w))))
                            (if (and f (not (viri-floats-p w)))
                                (+ (* 100000 (frame-x f)) (frame-y f) (window-number w))
                                most-positive-fixnum))))))

(defun viri-replace-group (group type)
  "A group of TYPE in GROUP's place, with its name, its number and its
windows, in the order they stood. GROUP must be the current one."
  (let* ((screen (group-screen group))
         (windows (viri-left-to-right group))
         (focused (group-current-window group))
         (name (group-name group))
         (number (group-number group))
         (new (make-swm-class-instance type :screen screen :name (concat ".viri-" name)
                                            :number (find-free-hidden-group-number screen))))
    (when (typep new 'viri-group)
      (setf (viri-group-head new) (current-head)
            ;; The splits and which window was in each, to go back to.
            (viri-tiles new) (and (typep group 'tile-group) (ignore-errors (dump-group group)))))
    (setf (screen-groups screen) (append (screen-groups screen) (list new)))
    ;; Moved first, then shown: switching to it shows the windows it has.
    (let ((*viri-appending* t))
      (dolist (w windows)
        (move-window-to-group w new)))
    ;; Tiles again: the strip's windows were floating ones; they go into the
    ;; frames (a dialog stays afloat, as Vikix keeps dialogs).
    (when (typep new 'tile-group)
      (dolist (w (group-windows new))
        (when (and (float-window-p w) (not (viri-floats-p w)))
          (unfloat-window w new))))
    (switch-to-group new)
    (kill-group group new)
    ;; Off: the splits it had before it was a strip, each window back in its
    ;; frame (one opened on the strip joins the current frame).
    (when (and (typep new 'tile-group) (viri-group-p group) (viri-tiles group))
      (if (fboundp 'vikix-restore-layout)
          (funcall 'vikix-restore-layout new (viri-tiles group))
          (restore-group new (viri-tiles group))))
    (setf (group-name new) name
          (group-number new) number)
    (netwm-set-group-properties screen)
    (netwm-update-groups screen)
    (when (and focused (member focused (group-windows new)))
      (if (typep new 'tile-group) (focus-all focused) (group-focus-window new focused)))
    new))

(defcommand vikix-viri (&optional what) ((:string nil))
  "This workspace as a strip that scrolls sideways (Viri), or as tiles again
(off). Its windows stay, in the order they stood."
  (let* ((group (current-group))
         (on (cond ((member what '("on" "yes") :test #'equal) t)
                   ((member what '("off" "no") :test #'equal) nil)
                   (t (not (viri-group-p group))))))
    (cond ((eq on (viri-group-p group))
           (message "This workspace is ~:[tiled~;a strip~] already." on))
          (on (viri-replace-group group 'viri-group)
              (message "Workspace ~a is a strip: Super+h and Super+l move along it." (group-name (current-group))))
          (t (viri-replace-group group 'tile-group)
             (message "Workspace ~a is tiled again." (group-name (current-group)))))))
;;; Where you are: the bar's window list (%W) shows a strip as a strip.

(defun viri-mode-line-windows (ml)
  "On a strip, its windows in order, the two on the screen in [brackets]
and the focused one picked out, each a click away; elsewhere StumpWM's own
list. So you can see how far along the strip you are, and what's off it."
  (let ((group (mode-line-current-group ml)))
    (if (not (viri-group-p group))
        (fmt-head-window-list ml)
        (let* ((cols (viri-columns group))
               (left (viri-left group))
               (n (max 1 *viri-visible-columns*))
               (last (min (length cols) (+ left n)))
               (floats (remove-if (lambda (w) (member w cols)) (group-windows group))))
          (flet ((name (w)
                   (format-with-on-click-id
                    (let ((str (format-expand *window-formatters* *window-format* w)))
                      (if (eq w (group-current-window group)) (fmt-highlight str) str))
                    :ml-on-click-focus-window (window-id w))))
            (format nil "~{~a~^ ~}"
                    (append (loop for w in cols
                                  for i from 0
                                  collect (concatenate 'string
                                                       (if (= i left) "[" "")
                                                       (name w)
                                                       (if (= i (1- last)) "]" "")))
                            (mapcar #'name floats))))))))

(add-screen-mode-line-formatter #\W 'viri-mode-line-windows)
