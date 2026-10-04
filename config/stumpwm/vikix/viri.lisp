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
;;;;   Super+r           the column's width: a third, a half, two thirds,
;;;;                     the whole screen (remove a split elsewhere)
;;;;   Super+[ / ]       the window joins the column left / right of it, or,
;;;;                     sharing one, leaves it for a column of its own
;;;;   Super+j / k       up and down a column; with Shift, move the window
;;;;   Super+o           every window on the strip in a menu, to go to one
;;;;
;;;; A column holds its windows top to bottom, sharing its height, and has
;;;; a width of its own; the strip scrolls just far enough to show
;;;; the focused column whole. A
;;;; Viri workspace is a float group whose windows Viri places itself, so
;;;; StumpWM's own floating code (focus, raising, fullscreen, dialogs) does
;;;; the rest. Columns off the screen are moved past its edge, not hidden:
;;;; they keep drawing, and come back at once.

(in-package :stumpwm)

;;; How wide a column is: a part of the screen. Super+r goes through these.
(defparameter *viri-widths* '(1/3 1/2 2/3 1)
  "The widths a column can have, as parts of the screen's width.")

(defparameter *viri-default-width* 1/2
  "A new column's width.")

(defvar *viri-appending* nil
  "True while a workspace becomes a strip: its windows go in at the end, in
the order they stood, not each beside the focused one.")

(defstruct (viri-col (:constructor make-viri-col (windows &optional (width *viri-default-width*))))
  (windows '())   ; top to bottom
  (width 1/2)     ; a part of the screen's width
  (focus nil))    ; the one of its windows focused last

(define-swm-class viri-group (float-group)
  ((cols :initform '() :accessor viri-cols
         :documentation "The strip's columns, left to right (viri-col).")
   (offset :initform 0 :accessor viri-offset
           :documentation "How far the strip is scrolled, in pixels from its left end.")
   (head :initform nil :accessor viri-group-head
         :documentation "The screen the strip is on (one, for now).")
   (tiles :initform nil :accessor viri-tiles
          :documentation "The tiles' layout it was made from (dump-group), for
vikix-viri off to put back.")))

(defun viri-columns (group)
  "The strip's windows in order: column by column, each top to bottom."
  (loop for c in (viri-cols group) append (copy-list (viri-col-windows c))))

(defun viri-col-of (group window)
  (find-if (lambda (c) (member window (viri-col-windows c))) (viri-cols group)))

(defun viri-group-p (&optional (group (current-group)))
  (typep group 'viri-group))

(defun viri-floats-p (window)
  "A window that floats over the strip instead of taking a column: a dialog
(vikix-dialog-p, windows.lisp), or one a rule floats (rules.lisp)."
  (or (and (fboundp 'vikix-dialog-p) (funcall 'vikix-dialog-p window))
      (and (fboundp 'vikix-rules-float-p)
           (ignore-errors (funcall 'vikix-rules-float-p window)))))

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

(defun viri-titlebar-height (window slot)
  "The room WINDOW's title bar takes at the top of a SLOT pixels high: none
with the bars off (Super+Ctrl+y), or in a slot too low for one."
  (if (and (fboundp 'vikix-titlebar-height)
           (boundp '*vikix-titlebars*) (symbol-value '*vikix-titlebars*)
           (not (window-fullscreen window)))
      (let ((h (funcall 'vikix-titlebar-height)))
        (if (> slot (* 3 h)) h 0))
      0))

;; Fullscreen is StumpWM's own, as for any floating window. Going into it,
;; a column's title bar goes (it would lie over the top of the picture);
;; coming out, StumpWM puts the window back as a floating one, so the strip
;; lays its columns out again.
(defmethod (setf window-fullscreen) :around (val (window float-window))
  (prog1 (call-next-method)
    (let ((group (and (slot-boundp window 'group) (window-group window))))
      (when (and group (viri-group-p group) (viri-col-of group window))
        (cond (val (when (fboundp 'vikix-titlebar-remove)
                     (funcall 'vikix-titlebar-remove window)))
              ((eq group (current-group)) (viri-layout group)))))))

(defun viri-spans (group width)
  "Each column's place along the strip: a list of (x . w) in pixels from its
left end, for a screen WIDTH wide."
  (let ((x 0))
    (loop for c in (viri-cols group)
          for w = (max 1 (floor (* (viri-col-width c) width)))
          collect (prog1 (cons x w) (incf x w)))))

(defun viri-clamp-offset (group width)
  "Never scrolled past the strip's ends."
  (let* ((spans (viri-spans group width))
         (total (if spans (let ((l (car (last spans)))) (+ (car l) (cdr l))) 0)))
    (setf (viri-offset group) (max 0 (min (viri-offset group) (- total width))))))

(defun viri-left (group)
  "The first column wholly on the screen."
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ax ay))
    (or (position-if (lambda (span) (>= (car span) (viri-offset group))) (viri-spans group aw)) 0)))

(defun viri-visible (group)
  "The columns wholly on the screen, as their positions in the strip."
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ax ay))
    (let ((off (viri-offset group)))
      (loop for span in (viri-spans group aw)
            for i from 0
            when (and (>= (car span) off) (<= (+ (car span) (cdr span)) (+ off aw)))
              collect i))))

(defun viri-layout (group)
  "Put every window where it belongs: the columns side by side from the
strip's left end, scrolled by OFFSET, those off the screen past its edges;
the windows of a column one above the other, sharing its height."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (viri-clamp-offset group aw)
    (loop for c in (viri-cols group)
          for (x . cw) in (viri-spans group aw)
          for n = (max 1 (length (viri-col-windows c)))
          for each = (floor ah n)
          do (loop for w in (viri-col-windows c)
                   for k from 0
                   for wy = (+ ay (* k each))
                   for wh = (if (= k (1- n)) (- ah (* k each)) each)
                   ;; A strip shows every column: a window the tiles had hidden
                   ;; (iconic) is shown again, now, or when the workspace is.
                   when (window-hidden-p w)
                     do (unhide-window w)
                   ;; A column's window has the tiles' title bar (windows.lisp):
                   ;; the window sits below it in its parent, the bar a child
                   ;; in the room above. None on a fullscreen window.
                   do (if (window-fullscreen w)
                          (when (fboundp 'vikix-titlebar-remove)
                            (funcall 'vikix-titlebar-remove w))
                          (let* ((border (* 2 (viri-border w)))
                                 (width (max 1 (- cw border)))
                                 (bar (viri-titlebar-height w (- wh border))))
                            (set-window-geometry w :x 0 :y bar)
                            (float-window-move-resize w :x (+ ax (- x (viri-offset group))) :y wy
                                                        :width width
                                                        :height (max 1 (- wh border bar))
                                                        :border 0)
                            (if (plusp bar)
                                (funcall 'vikix-titlebar-show w width)
                                (when (fboundp 'vikix-titlebar-remove)
                                  (funcall 'vikix-titlebar-remove w))))))))
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
  "Scroll just far enough that WINDOW's column is wholly on the screen
(its left edge first, when it's wider than the screen); true when it moved."
  (let ((i (position (viri-col-of group window) (viri-cols group))))
    (when i
      (multiple-value-bind (ax ay aw) (viri-area group)
        (declare (ignore ax ay))
        (destructuring-bind (x . w) (nth i (viri-spans group aw))
          (let ((old (viri-offset group)))
            (setf (viri-offset group)
                  (cond ((< x old) x)
                        ((> (+ x w) (+ old aw)) (- (+ x w) aw))
                        (t old)))
            (viri-clamp-offset group aw)
            (/= old (viri-offset group))))))))

;;; What StumpWM asks of a group, where a strip differs from a float group.

(defmethod group-add-window ((group viri-group) window &key &allow-other-keys)
  ;; A title bar left from the tiles would cover the top of a dialog here;
  ;; a column gets its own again as the strip is laid out.
  (when (fboundp 'vikix-titlebar-remove)
    (funcall 'vikix-titlebar-remove window))
  ;; A new column goes right of the focused one, the way you're working.
  (unless (or (viri-floats-p window) (viri-col-of group window))
    (let* ((cols (viri-cols group))
           (new (make-viri-col (list window)))
           (at (and (not *viri-appending*)
                    (position (viri-col-of group (group-current-window group)) cols))))
      (setf (viri-cols group)
            (if at
                (append (subseq cols 0 (1+ at)) (list new) (nthcdr (1+ at) cols))
                (append cols (list new))))))
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

;; A column that leaves the strip for a tiled workspace (Super+Shift+digit,
;; Super+Shift+g there) is tiled there: it floated only because a strip's
;; windows do. Noted as it leaves, tiled as it arrives.
(defvar *viri-leaving* (make-hash-table :test 'eq :weakness :key)
  "Windows that have just left a strip as one of its columns.")

(defmethod group-add-window :after ((group tile-group) (window float-window) &key &allow-other-keys)
  (when (gethash window *viri-leaving*)
    (remhash window *viri-leaving*)
    ;; Into the frame the workspace is on, which stays the current one.
    (let ((frame (tile-group-current-frame group)))
      (unfloat-window window group)
      (pull-window window frame nil)
      (setf (tile-group-current-frame group) frame))))

(defmethod group-delete-window :before ((group viri-group) (window float-window))
  (when (viri-col-of group window)
    (setf (gethash window *viri-leaving*) t)))

(defmethod group-delete-window ((group viri-group) (window float-window))
  (let* ((col (viri-col-of group window))
         (i (and col (position col (viri-cols group))))
         (k (and col (position window (viri-col-windows col)))))
    (cond ((null col) (call-next-method))
          (t
           (setf (viri-col-windows col) (remove window (viri-col-windows col)))
           (when (eq (viri-col-focus col) window)
             (setf (viri-col-focus col) nil))
           (unless (viri-col-windows col)
             (setf (viri-cols group) (remove col (viri-cols group))))
           (viri-layout group)
           (let ((cols (viri-cols group)))
             (cond ((viri-col-windows col)
                    ;; Its column's next window, or the one above.
                    (group-focus-window group (nth (min k (1- (length (viri-col-windows col))))
                                                   (viri-col-windows col))))
                   (cols
                    ;; The column that took its place, or the last one.
                    (group-focus-window group (viri-col-window (nth (min i (1- (length cols))) cols))))
                   (t (call-next-method))))))))

(defun viri-col-window (col)
  "The window to focus in COL: the one focused there last, else its first."
  (let ((f (viri-col-focus col)))
    (if (member f (viri-col-windows col)) f (first (viri-col-windows col)))))

(defmethod group-focus-window ((group viri-group) window)
  ;; Focused first, then scrolled to: the layout brings the pointer along
  ;; to the window that has the focus now.
  (let ((col (viri-col-of group window)))
    (when col (setf (viri-col-focus col) window)))
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
  "Focus the column left or right of the focused one, or the window above
or below in its column; with MOVE, take the focused column (or window)
there instead."
  (let* ((group (current-group))
         (cols (viri-cols group))
         (window (group-current-window group))
         (col (viri-col-of group window))
         (i (and col (position col cols))))
    (cond ((null cols))
          ((null col) (group-focus-window group (viri-col-window (first cols))))   ; on a dialog: back to the strip
          ((member dir '(:up :down))
           (let* ((ws (viri-col-windows col))
                  (k (position window ws))
                  (m (if (eq dir :up) (1- k) (1+ k))))
             (when (< -1 m (length ws))
               (if move
                   (progn (rotatef (nth k (viri-col-windows col)) (nth m (viri-col-windows col)))
                          (viri-layout group))
                   (group-focus-window group (nth m ws))))))
          (t
           (let ((j (if (eq dir :left) (1- i) (1+ i))))
             (when (< -1 j (length cols))
               (if move
                   (progn (rotatef (nth i (viri-cols group)) (nth j (viri-cols group)))
                          (viri-scroll-to group window)
                          (viri-layout group))
                   (group-focus-window group (viri-col-window (nth j cols))))))))))

(defun viri-stack (group dir &key (window (group-current-window group)) join-only)
  "Take WINDOW (the focused one) into the column on the DIR side (:left or
:right), at its bottom; or, when it shares its column already, out of it
into a column of its own on that side (not with JOIN-ONLY). Niri's
consume-or-expel."
  (let* ((col (viri-col-of group window))
         (cols (viri-cols group))
         (i (and col (position col cols))))
    (when col
      (cond ((and join-only (rest (viri-col-windows col)))
             (return-from viri-stack nil))
            ((rest (viri-col-windows col))
             ;; Out, into a new column beside, as wide as the one it left.
             (setf (viri-col-windows col) (remove window (viri-col-windows col)))
             (let ((new (make-viri-col (list window) (viri-col-width col)))
                   (at (if (eq dir :left) i (1+ i))))
               (setf (viri-cols group) (append (subseq cols 0 at) (list new) (nthcdr at cols)))))
            (t
             (let ((j (if (eq dir :left) (1- i) (1+ i))))
               (if (not (< -1 j (length cols)))
                   (return-from viri-stack (message "No column that side to join."))
                   (let ((target (nth j cols)))
                     (setf (viri-col-windows target) (append (viri-col-windows target) (list window))
                           (viri-cols group) (remove col cols)))))))
      (let ((target (viri-col-of group window)))
        (setf (viri-col-focus target) window))
      (when (eq window (group-current-window group))
        (viri-scroll-to group window))
      (viri-layout group)
      t)))

(defcommand vikix-stack (dir) ((:direction "Direction: "))
  "On a strip: the window joins the column that way, below its windows; one
that shares a column leaves it, for a column of its own that way."
  (if (viri-group-p)
      (viri-stack (current-group) dir)
      (message "Stacking is for strips (vikix viri).")))

(defun viri-cycle-width (group)
  "The focused column one step wider in *viri-widths*, and from the widest
back to the narrowest."
  (let ((col (viri-col-of group (group-current-window group))))
    (when col
      (let ((next (or (find-if (lambda (w) (> w (viri-col-width col))) *viri-widths*)
                      (first *viri-widths*))))
        (setf (viri-col-width col) next)
        (viri-scroll-to group (group-current-window group))
        (viri-layout group)
        (message "Column: ~a of the screen" (case next (1 "all") (1/2 "half") (1/3 "a third") (2/3 "two thirds") (t next)))))))

(defcommand vikix-width-or-remove () ()
  "On a strip, the focused column's width: a third, a half, two thirds, the
whole screen, and round again. In main and stack mode, the main window's
width. On other tiles, remove this split (remove)."
  (cond ((viri-group-p) (viri-cycle-width (current-group)))
        ((vikix-main-p) (vikix-main-cycle-share (current-group)))
        (t (run-commands "remove"))))

(defcommand vikix-last-window () ()
  "The window you were in before this one: on a strip the focus goes back
to it; on tiles it comes into this frame (pull-hidden-other)."
  (if (viri-group-p)
      (let* ((group (current-group))
             (now (group-current-window group))
             ;; A group's windows are kept last focused first.
             (last (find-if (lambda (w) (and (not (eq w now)) (viri-col-of group w)))
                            (group-windows group))))
        (if last
            (group-focus-window group last)
            (message "No other window on this strip.")))
      (run-commands "pull-hidden-other")))

(defcommand vikix-split (&optional how) ((:string nil))
  "Split this frame in two: side by side, or with \"below\" one above the
other. A strip has no splits to make."
  (cond ((viri-group-p)
         (message "A strip has no splits: a new window opens beside this one, and Super+[ or Super+] puts a window under its neighbour."))
        ((equal how "below") (run-commands "vsplit"))
        (t (run-commands "hsplit"))))

(defcommand vikix-focus (dir) ((:direction "Direction: "))
  "Focus the window that way: along the strip on a Viri workspace, the
frame that way (move-focus) elsewhere."
  (if (viri-group-p)
      (viri-step dir nil)
      (run-commands (format nil "move-focus ~(~a~)" dir))))

(defcommand vikix-move (dir) ((:direction "Direction: "))
  "Move the window that way: its column along the strip on a Viri
workspace; in main and stack mode it changes places with the window that
way (exchange-direction); into the frame that way (move-window) elsewhere."
  (cond ((viri-group-p) (viri-step dir t))
        ((vikix-main-p) (run-commands (format nil "exchange-direction ~(~a~)" dir)))
        (t (run-commands (format nil "move-window ~(~a~)" dir)))))

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
        (let* ((cols (viri-cols group))
               (shown (viri-visible group))
               (floats (remove-if (lambda (w) (viri-col-of group w)) (group-windows group))))
          (flet ((name (w)
                   (format-with-on-click-id
                    (let ((str (format-expand *window-formatters* *window-format* w)))
                      (if (eq w (group-current-window group)) (fmt-highlight str) str))
                    :ml-on-click-focus-window (window-id w))))
            (format nil "~{~a~^ ~}"
                    (append (loop for c in cols
                                  for i from 0
                                  ;; A column of several windows: joined by /.
                                  collect (concatenate 'string
                                                       (if (eql i (first shown)) "[" "")
                                                       (format nil "~{~a~^/~}" (mapcar #'name (viri-col-windows c)))
                                                       (if (eql i (car (last shown))) "]" "")))
                            (mapcar #'name floats))))))))

(add-screen-mode-line-formatter #\W 'viri-mode-line-windows)

;;; The overview: every window on the strip in a menu (Super+o on a strip).

(defun viri-overview-lines (group)
  "The strip's windows as the menu shows them, in order, (LINE WINDOW):
the column's place, the window, and whether it's on the screen now."
  (let ((shown (viri-visible group)))
    (loop for c in (viri-cols group)
          for i from 0
          append (loop for w in (viri-col-windows c)
                       for k from 0
                       collect (list (format nil "~a ~2d~a  ~a~a"
                                             (if (eq w (group-current-window group)) "*" " ")
                                             (1+ i)
                                             (if (rest (viri-col-windows c)) (format nil ".~d" (1+ k)) "  ")
                                             (window-name w)
                                             (if (member i shown) "   (on the screen)" ""))
                                     w)))))

(defun viri-overview-menu (group)
  "Pick a window of the strip from a menu (type to narrow it); the strip
goes there."
  (let* ((lines (viri-overview-lines group))
         (here (or (position (group-current-window group) lines :key #'second) 0))
         (choice (select-from-menu (group-screen group) lines
                                   (format nil "Strip ~a (type to search): " (group-name group))
                                   here)))
    (when choice
      (group-focus-window group (second choice)))))

;;; The overview, drawn (s-o on a strip).
;;;
;;; The whole strip in small, on a card over the screen: each column a box
;;; as wide as its share of the strip, its windows one above the other, each
;;; with the title bar it has (its number and name, the focused one's in the
;;; accent) and under it what it is (windows.lisp's vikix-window-about: a
;;; terminal's folder and what runs in it); a line around the part that is
;;; on the screen now. The arrows or h/j/k/l move a frame from window to
;;; window, Enter goes to it, a digit goes straight to the window with that
;;; number, / opens the list to type in, any other key closes.
;;;
;;; Titles, not pictures: X has no picture to give of a window past the
;;; screen's edge, and a compositor's would be the work of another day.
;;;
;;; The card is a window of Vikix's own with the drawing as its background,
;;; as a title bar is, so X repaints it. Its keys come through
;;; *custom-key-event-handler* with the keyboard grabbed, as the key card's.

(defparameter *viri-overview-scale* 1/4
  "How small the overview draws the strip, at most: a strip too long for
the screen at that is drawn smaller still.")

(defparameter *viri-overview-timeout* 60
  "Seconds the overview stays open with no key pressed.")

(defvar *viri-overview* nil
  "While the overview shows, a list: :group, :card (its X window), :at (the
window the frame is on), :room, :pad, :line, :handler (the key handler
before it) and :timer.")

(defun viri-overview-boxes (group room)
  "The strip in small, to fit ROOM pixels across: a list of (WINDOW X Y W H)
from the picture's top left. More values: the picture's width and height,
and where the part on the screen starts and how wide it is."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (declare (ignore ax ay))
    (let* ((spans (viri-spans group aw))
           (total (max aw (if spans (let ((l (car (last spans)))) (+ (car l) (cdr l))) 0)))
           (scale (min *viri-overview-scale* (/ room total)))
           (height (max 1 (round (* ah scale)))))
      (values
       (loop for c in (viri-cols group)
             for (x . w) in spans
             for n = (max 1 (length (viri-col-windows c)))
             append (loop for win in (viri-col-windows c)
                          for k from 0
                          collect (list win
                                        (round (* x scale)) (round (* k (/ height n)))
                                        (max 1 (round (* w scale))) (max 1 (round (/ height n))))))
       (round (* total scale)) height
       (round (* (viri-offset group) scale)) (round (* aw scale))))))

(defun viri-overview-fit (text pixels char)
  "TEXT, or its start and an ellipsis, to fit PIXELS in a font whose
characters are CHAR wide."
  (let ((room (floor pixels (max 1 char))))
    (cond ((<= (length text) room) text)
          ((< room 2) "")
          (t (concat (subseq text 0 (1- room)) "…")))))

(defun viri-overview-about (window)
  "What WINDOW is, a part to a line: a terminal's folder, then what runs
in it (vikix-window-about puts two spaces between them)."
  (let* ((about (if (fboundp 'vikix-window-about)
                    (funcall 'vikix-window-about window)
                    (or (window-class window) "")))
         (cut (search "  " about)))
    (remove "" (if cut
                   (list (subseq about 0 cut) (string-left-trim " " (subseq about cut)))
                   (list about))
            :test #'string=)))

(defparameter *viri-overview-hint*
  "arrows or h j k l: move    Enter: go there    a number: that window    /: type to find    Esc: close")

(defun viri-overview-colour (screen &rest keys)
  "The pixel of the first of the theme's colours KEYS it has; the text
colour without one."
  (let ((name (and (fboundp 'vikix-colour) (some (lambda (k) (funcall 'vikix-colour k)) keys))))
    (or (and name (ignore-errors (alloc-color screen name)))
        (screen-fg-color screen))))

(defun viri-overview-draw ()
  "Paint the card: the strip as it is now, the frame on the window chosen."
  (let* ((state *viri-overview*)
         (group (getf state :group))
         (card (getf state :card))
         (screen (group-screen group))
         (font (screen-font screen))
         (pad (getf state :pad))
         (line (getf state :line))
         (char (max 1 (round (text-line-width font "MMMMMMMMMM" :translate #'translate-id) 10)))
         (ascent (font-ascent font))
         (width (xlib:drawable-width card))
         (height (xlib:drawable-height card))
         (bg (screen-bg-color screen))
         (fg (screen-fg-color screen))
         (accent (screen-focus-color screen))
         (edge (screen-unfocus-color screen))
         (dim (viri-overview-colour screen :color8 :subtle))
         (focused (group-current-window group))
         (pm (xlib:create-pixmap :width width :height height :drawable card
                                 :depth (xlib:drawable-depth card)))
         (gc (xlib:create-gcontext :drawable pm :foreground bg :background bg)))
    (multiple-value-bind (boxes pw ph vx vw) (viri-overview-boxes group (getf state :room))
      (let ((x0 (floor (- width pw) 2))
            (y0 (+ pad line 10)))
        (flet ((colours (f b) (setf (xlib:gcontext-foreground gc) f (xlib:gcontext-background gc) b))
               (text (x y string)
                 (when (plusp (length string))
                   (draw-image-glyphs pm gc font x (+ y 3 ascent) string
                                      :translate #'translate-id :size 16))))
          (unwind-protect
               (progn
                 (colours bg bg)
                 (xlib:draw-rectangle pm gc 0 0 width height t)
                 (colours accent bg)
                 (text pad pad (viri-overview-fit
                                (format nil "Strip ~a: ~d window~:p" (group-name group) (length boxes))
                                (- width pad pad) char))
                 (colours dim bg)
                 (text pad (+ y0 ph 10) (viri-overview-fit *viri-overview-hint* (- width pad pad) char))
                 ;; What is on the screen now: a line around that part.
                 (colours fg bg)
                 (xlib:draw-rectangle pm gc (+ x0 vx -3) (- y0 4) (+ vw 5) (+ ph 7))
                 (loop for (win x y w h) in boxes
                       for bx = (+ x0 x 2) for by = (+ y0 y 2)
                       for bw = (max 1 (- w 4)) for bh = (max 1 (- h 4))
                       for band = (min bh line)
                       for here = (eq win focused)
                       do (colours bg bg)                                   ; over the line behind it
                          (xlib:draw-rectangle pm gc bx by bw bh t)
                          (colours (if here accent edge) bg)
                          (xlib:draw-rectangle pm gc bx by bw band t)       ; its title bar
                          (xlib:draw-rectangle pm gc bx by (1- bw) (1- bh)) ; its edge
                          (when (>= band line)
                            (colours (if here bg fg) (if here accent edge))
                            (text (+ bx 4) by
                                  (viri-overview-fit (format nil "~d ~a" (window-number win) (window-name win))
                                                     (- bw 8) char)))
                          ;; What it is, a part to a line, as far as there's room.
                          (colours dim bg)
                          (loop for part in (viri-overview-about win)
                                for ty from (+ by band 2) by line
                                while (<= (+ ty line) (+ by bh))
                                do (text (+ bx 4) ty (viri-overview-fit part (- bw 8) char)))
                          (when (eq win (getf state :at))
                            (colours accent bg)
                            (xlib:draw-rectangle pm gc (- bx 2) (- by 2) (+ bw 3) (+ bh 3))
                            (xlib:draw-rectangle pm gc (- bx 1) (- by 1) (+ bw 1) (+ bh 1)))))
            (xlib:free-gcontext gc))
          ;; X keeps the picture while it is the background.
          (setf (xlib:window-background card) pm)
          (xlib:free-pixmap pm)
          (xlib:clear-area card)
          (xlib:display-finish-output *display*))))))

(defun viri-overview-close (&rest ignore)
  "Close the overview and give the keyboard back. Safe when it's closed."
  (declare (ignore ignore))
  (let ((state *viri-overview*))
    (when state
      (setf *viri-overview* nil)
      (when (eq *custom-key-event-handler* 'viri-overview-key)
        (setf *custom-key-event-handler* (getf state :handler)))
      (ungrab-keyboard)
      (when (timer-p (getf state :timer))
        (cancel-timer (getf state :timer)))
      (ignore-errors (xlib:destroy-window (getf state :card)))
      ;; The card gone, X says the pointer entered what was under it: not
      ;; a reason for the focus to move.
      (ignore-errors (viri-drop-enter-events)))))

(defun viri-overview-move (dir)
  "The frame to the window that way: along the columns, or up and down one."
  (let* ((state *viri-overview*)
         (group (getf state :group))
         (cols (viri-cols group))
         (at (getf state :at))
         (col (or (viri-col-of group at) (first cols)))
         (i (or (position col cols) 0))
         (k (or (position at (viri-col-windows col)) 0))
         (to (ecase dir
               (:left (viri-col-window (nth (max 0 (1- i)) cols)))
               (:right (viri-col-window (nth (min (1- (length cols)) (1+ i)) cols)))
               (:up (nth (max 0 (1- k)) (viri-col-windows col)))
               (:down (nth (min (1- (length (viri-col-windows col))) (1+ k)) (viri-col-windows col))))))
    (when to
      (setf (getf *viri-overview* :at) to)
      (viri-overview-draw))))

(defun viri-overview-go (window)
  "Close the overview; the strip goes to WINDOW, when it's still there."
  (let ((group (getf *viri-overview* :group)))
    (viri-overview-close)
    (when (and window (member window (group-windows group)))
      (group-focus-window group window))))

(defun viri-overview-key (code state)
  "The key handler while the overview shows. True means the key is used up."
  (if (is-modifier code)
      t
      (let ((pass nil))
        (handler-case
            (let* ((key (code-state->key code state))
                   (name (print-key key))
                   (group (getf *viri-overview* :group))
                   (digit (and (= (length name) 1) (digit-char-p (char name 0)))))
              (cond ((member name '("h" "Left") :test #'string=) (viri-overview-move :left))
                    ((member name '("l" "Right") :test #'string=) (viri-overview-move :right))
                    ((member name '("k" "Up") :test #'string=) (viri-overview-move :up))
                    ((member name '("j" "Down") :test #'string=) (viri-overview-move :down))
                    ((member name '("RET" "SPC") :test #'string=)
                     (viri-overview-go (getf *viri-overview* :at)))
                    (digit
                     (let ((window (find digit (viri-columns group) :key #'window-number)))
                       (if window (viri-overview-go window) (viri-overview-close))))
                    ((string= name "/")
                     (viri-overview-close)
                     (viri-overview-menu group))
                    (t
                     ;; Any other key closes; one bound to something else
                     ;; goes on to StumpWM, which runs it.
                     (let ((command (find-if-not #'null
                                                 (mapcar (lambda (map) (lookup-key map key))
                                                         (dereference-kmaps (top-maps))))))
                       (setf pass (and command (not (equal command "vikix-expose")))))
                     (viri-overview-close))))
          ;; Never left open with the keyboard grabbed.
          (error () (viri-overview-close)))
        (not pass))))

(defun viri-overview (group)
  "Show GROUP's strip in small; keys pick a window (viri-overview-key)."
  (viri-overview-close)
  (let* ((screen (group-screen group))
         (font (screen-font screen))
         (pad 16)
         (line (+ 6 (font-height font)))
         (char (max 1 (round (text-line-width font "MMMMMMMMMM" :translate #'translate-id) 10))))
    (multiple-value-bind (ax ay aw ah) (viri-area group)
      (let ((room (- (floor (* aw 95/100)) (* 2 pad))))
        (multiple-value-bind (boxes pw ph) (viri-overview-boxes group room)
          (declare (ignore boxes))
          (let* ((width (min aw (+ (* 2 pad) (max pw (min room (* char (length *viri-overview-hint*)))))))
                 (height (min ah (+ pad line 10 ph 10 line pad)))
                 (card (xlib:create-window
                        :parent (screen-root screen)
                        :x (+ ax (floor (- aw width) 2)) :y (+ ay (floor (- ah height) 2))
                        :width width :height height
                        :override-redirect :on
                        :background (screen-bg-color screen)
                        :border (screen-focus-color screen) :border-width 1
                        :event-mask '())))
            ;; Solid, whatever picom makes of windows without the focus.
            (xlib:change-property card :_net_wm_window_opacity (list #xffffffff) :cardinal 32)
            (setf *viri-overview*
                  (list :group group :card card
                        :at (or (group-current-window group) (first (viri-columns group)))
                        :room room :pad pad :line line
                        :handler *custom-key-event-handler*
                        :timer (run-with-timer *viri-overview-timeout* nil 'viri-overview-close))
                  *custom-key-event-handler* 'viri-overview-key)
            (xlib:map-window card)
            (setf (xlib:window-priority card) :above)
            (grab-keyboard (screen-key-window screen))
            (handler-case (viri-overview-draw)
              (error (e)
                (viri-overview-close)
                (message "The overview couldn't be drawn (~a): the list instead." e)
                (viri-overview-menu group)))))))))

;; The strip changed under the card (a window came or went), or you're on
;; another workspace: the card would show what isn't so.
(defun viri-overview-stale (&rest ignore)
  (declare (ignore ignore))
  (when *viri-overview*
    (viri-overview-close)))

(add-hook *new-window-hook* 'viri-overview-stale)
(add-hook *destroy-window-hook* 'viri-overview-stale)
(add-hook *focus-group-hook* 'viri-overview-stale)

(defcommand vikix-expose () ()
  "Every window on this workspace, to pick one: on a strip, the strip drawn
small (again closes it); on tiles, StumpWM's grid (expose)."
  (cond ((and *viri-overview* (eq (getf *viri-overview* :group) (current-group)))
         (viri-overview-close))
        ((viri-group-p)
         (if (viri-columns (current-group))
             (viri-overview (current-group))
             (message "No windows on this strip.")))
        (t (run-commands "expose"))))

;;; Rules for strips (rules.lisp loads first): two verbs.
;;;
;;;   (when-window (:class "firefox") (width 2/3))
;;;   (when-window (:class "Alacritty" :title (:has "build")) (join :left))
;;;
;;; Off a strip they do nothing, so a rule can say how a window stands on
;;; a strip and still hold everywhere.

(defun viri-share (share)
  "SHARE as a part of the screen: 1/3, 2/3, 0.4, or \"40%\"."
  (let ((value (cond ((and (realp share) (< 0 share) (<= share 1)) share)
                     ((and (stringp share) (ppcre:scan "^\\s*\\d+(\\.\\d+)?\\s*%\\s*$" share))
                      (/ (let ((*read-eval* nil)) (read-from-string (string-trim " %" share))) 100)))))
    (unless (and value (< 0 value) (<= value 1))
      (error "A width is a part of the screen: 1/3, 1/2, 2/3, 1, or \"40%\"; this is ~s." share))
    (rational value)))

(define-rule-verb width (share)
  "On a strip, the window's column is SHARE of the screen wide: 1/3, 1/2, 2/3, 1, or \"40%\". Off a strip, nothing."
  (let* ((win (rule-window))
         (group (window-group win))
         (col (and (viri-group-p group) (viri-col-of group win)))
         (share (viri-share share)))
    (when col
      (setf (viri-col-width col) share)
      (when (eq win (group-current-window group))
        (viri-scroll-to group win))
      (viri-layout group))
    win))

(define-rule-verb join (side)
  "On a strip, the window goes into the column on SIDE (:left or :right), below its windows, as Super+[ and Super+] do. Off a strip, nothing."
  (unless (member side '(:left :right))
    (error "join's side is :left or :right; this is ~s." side))
  (let* ((win (rule-window))
         (group (window-group win)))
    (when (and (viri-group-p group) (viri-col-of group win))
      (viri-stack group side :window win :join-only t))
    win))
