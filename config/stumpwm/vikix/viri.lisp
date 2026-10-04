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

;; Scrolling slides. When the strip is laid out at another place than it
;; was drawn at last, its windows first go there in a few steps, each a
;; little nearer and slower (only moved: nothing is resized on the way),
;; and then are laid out where they belong. The steps are made here, one
;; after the other with a short sleep between, in a tenth of a second or
;; so: never with a timer, which would want a fraction of a second for its
;; delay (and that stops StumpWM's loop).
;;
;; Only with a compositor (picom): without one every step would have each
;; program draw its window again, and the slide would flicker.

(defparameter *viri-animate* t
  "Whether the strip slides as it scrolls: t (when a compositor runs),
:always, or nil (it jumps, as before).")

(defparameter *viri-animate-frames* 8
  "How many steps a slide takes.")

(defparameter *viri-animate-seconds* 0.12
  "How long a slide takes, about.")

(defvar *viri-drawn* (make-hash-table :test 'eq :weakness :key)
  "Each strip as it was last laid out: (OFFSET . what stood where).")

(defun viri-compositor-p (screen)
  "True when a compositor runs on SCREEN: it owns the selection _NET_WM_CM_Sn."
  (ignore-errors
   (and (xlib:selection-owner *display*
                              (intern (format nil "_NET_WM_CM_S~d" (screen-id screen)) :keyword))
        t)))

(defun viri-animate-p (group)
  (and *viri-animate*
       (plusp *viri-animate-frames*)
       (eq group (current-group))
       (or (eq *viri-animate* :always) (viri-compositor-p (group-screen group)))))

(defun viri-slide-offsets (from to)
  "The places a slide from FROM to TO stops at on its way: quick at first,
slower as it nears TO; neither end is among them."
  (loop for i from 1 below *viri-animate-frames*
        for u = (/ i *viri-animate-frames*)
        collect (round (+ from (* (- to from) (- 1 (expt (- 1 u) 3)))))))

(defun viri-slide (group from to)
  "Move the strip's windows from where they stand at offset FROM towards
TO, a step at a time."
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ay))
    (let ((spans (viri-spans group aw))
          (pause (/ *viri-animate-seconds* *viri-animate-frames*)))
      (dolist (offset (viri-slide-offsets from to))
        (loop for c in (viri-cols group)
              for (x . nil) in spans
              do (dolist (w (viri-col-windows c))
                   (unless (window-fullscreen w)
                     (setf (xlib:drawable-x (window-parent w)) (+ ax (- x offset))))))
        (xlib:display-finish-output *display*)
        (sleep pause)))))

(defun viri-standing (group width)
  "What stands where on GROUP's strip: to tell whether only the scroll changed."
  (loop for c in (viri-cols group)
        for span in (viri-spans group width)
        collect (cons span (copy-list (viri-col-windows c)))))

(defun viri-layout (group)
  "Put every window where it belongs, sliding there when the strip has
scrolled since it was last laid out."
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ax ay))
    (viri-clamp-offset group aw)
    (let* ((to (viri-offset group))
           (standing (viri-standing group aw))
           (drawn (gethash group *viri-drawn*))
           (from (car drawn)))
      (when (and from (/= from to) (viri-animate-p group))
        ;; A window that came, went or changed its width takes its place
        ;; first, at the old scroll; then all of it slides.
        (unless (equal (cdr drawn) standing)
          (viri-place group from))
        (viri-slide group from to))
      (viri-place group to)
      (setf (gethash group *viri-drawn*) (cons to standing))))
  (viri-keep-pointer group)
  (update-all-mode-lines))

(defun viri-place (group offset)
  "Every window where it belongs with the strip scrolled by OFFSET: the
columns side by side from the strip's left end, those off the screen past
its edges; the windows of a column one above the other, sharing its height."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
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
                            (float-window-move-resize w :x (+ ax (- x offset)) :y wy
                                                        :width width
                                                        :height (max 1 (- wh border bar))
                                                        :border 0)
                            (if (plusp bar)
                                (funcall 'vikix-titlebar-show w width)
                                (when (fboundp 'vikix-titlebar-remove)
                                  (funcall 'vikix-titlebar-remove w)))))))))

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
                 ;; Its edges are part of it: a press on one (to drag the
                 ;; column wider) mustn't send the pointer to its middle.
                 (edge (* 2 (xlib:drawable-border-width p)))
                 (x (xlib:drawable-x p)) (y (xlib:drawable-y p))
                 (w (+ edge (xlib:drawable-width p))) (h (+ edge (xlib:drawable-height p))))
            (when (and (< ax px (+ ax aw)) (< ay py (+ ay ah))
                       (not (and (<= x px (+ x w)) (<= y py (+ y h)))))
              (warp-pointer (group-screen group) (+ x (floor w 2)) (+ y (floor h 2)))))))
      (viri-drop-enter-events))))

(defparameter *viri-centre* nil
  "True: the focused column is kept in the middle of the screen, as far as
the strip's ends allow. NIL: the strip scrolls only as far as it must.")

(defun viri-scroll-to (group window)
  "Scroll just far enough that WINDOW's column is wholly on the screen
(its left edge first, when it's wider than the screen), or with
*viri-centre* so that it's in the middle; true when it moved."
  (let ((i (position (viri-col-of group window) (viri-cols group))))
    (when i
      (multiple-value-bind (ax ay aw) (viri-area group)
        (declare (ignore ax ay))
        (destructuring-bind (x . w) (nth i (viri-spans group aw))
          (let ((old (viri-offset group)))
            (setf (viri-offset group)
                  (cond (*viri-centre* (- (+ x (floor w 2)) (floor aw 2)))
                        ((< x old) x)
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

;;; The mouse on a strip.
;;;
;;; A column is a floating window to StumpWM, which lets the mouse carry one
;;; anywhere and pull it to any size: on a strip that left a column lying
;;; over its neighbours until the next layout. Here the mouse does what a
;;; strip can keep:
;;;
;;;   Super + the wheel, over the strip    walk along it (so does the wheel
;;;                                        on the bar's window names)
;;;   drag a title bar, or Super + drag    carry the column along the strip:
;;;                                        it stays where you let it go
;;;   drag a column's side edge, or        its width, a twentieth of the
;;;     Super + drag with the right button screen at a time
;;;
;;; A click still focuses the window and reaches its program, as before. A
;;; dialog on a strip is StumpWM's to move and resize.

(defparameter *viri-width-step* 1/20
  "A column dragged wider or narrower goes by this much of the screen at a time.")

(defparameter *viri-width-least* 1/5
  "The narrowest a column can be dragged.")

(defun viri-drag (screen moving)
  "Follow the pointer until the button is let go, calling MOVING with its
place on the screen each time it moves. Gives up after 20 seconds with no
movement, so a button's release that never comes doesn't hold the desktop."
  (let ((last (get-universal-time)))
    (flet ((event (&rest slots &key event-key &allow-other-keys)
             (case event-key
               (:button-release :done)
               (:motion-notify
                (setf last (get-universal-time))
                (funcall moving (getf slots :root-x) (getf slots :root-y))
                t)
               ;; Eaten, or they'd all come in afterwards.
               ((:configure-notify :exposure) t)
               (t nil))))
      (xlib:grab-pointer (screen-root screen) '(:button-release :pointer-motion))
      (unwind-protect
           ;; A click, not a drag: the button is up again already, and its
           ;; release went by before the pointer was ours. Nothing to wait for.
           (when (intersection '(:button-1 :button-3)
                               (xlib:make-state-keys
                                (nth-value 4 (xlib:query-pointer (screen-root screen)))))
             ;; process-event gives NIL for an event that isn't the drag's
             ;; (the pointer "leaving" as it is grabbed) as well as for a
             ;; second gone by: the clock says which.
             (loop for ev = (xlib:process-event *display* :handler #'event :timeout 1 :discard-p t)
                   until (or (eq ev :done) (> (- (get-universal-time) last) 20))))
        (ungrab-pointer)))))

(defun viri-drag-width (group window)
  "WINDOW's column made as much wider or narrower as the pointer is taken
right or left, while the button is down."
  (let ((col (viri-col-of group window))
        (px0 (xlib:global-pointer-position *display*)))
    (multiple-value-bind (ax ay aw) (viri-area group)
      (declare (ignore ax ay))
      (let ((start (viri-col-width col)))
        (viri-drag (group-screen group)
                   (lambda (px py)
                     (declare (ignore py))
                     (let ((width (max *viri-width-least*
                                       (min 1 (* *viri-width-step*
                                                 (round (+ start (/ (- px px0) aw)) *viri-width-step*))))))
                       (unless (= width (viri-col-width col))
                         (setf (viri-col-width col) width)
                         (viri-clamp-offset group aw)
                         (viri-place group (viri-offset group))
                         (xlib:display-finish-output *display*)))))))
    (viri-scroll-to group window)
    (viri-layout group)))

(defun viri-drag-column (group window)
  "WINDOW's column carried along the strip with the pointer while the
button is down; let go, it takes the place it's over."
  (let* ((col (viri-col-of group window))
         (x0 (xlib:drawable-x (window-parent window)))
         (px0 (xlib:global-pointer-position *display*))
         (moved nil))
    (dolist (w (viri-col-windows col))
      (setf (xlib:window-priority (window-parent w)) :above))
    (viri-drag (group-screen group)
               (lambda (px py)
                 (declare (ignore py))
                 (setf moved t)
                 (dolist (w (viri-col-windows col))
                   (setf (xlib:drawable-x (window-parent w)) (+ x0 (- px px0))))
                 (xlib:display-finish-output *display*)))
    (when moved
      (multiple-value-bind (ax ay aw) (viri-area group)
        (declare (ignore ay))
        ;; Its new place: after every other column whose middle is left of
        ;; the pointer.
        (let* ((at (+ (- (xlib:global-pointer-position *display*) ax) (viri-offset group)))
               (before (loop for c in (viri-cols group)
                             for (x . w) in (viri-spans group aw)
                             unless (eq c col)
                               count (< (+ x (floor w 2)) at)))
               (others (remove col (viri-cols group))))
          (setf (viri-cols group)
                (append (subseq others 0 before) (list col) (nthcdr before others))))))
    (viri-scroll-to group window)
    (viri-layout group)))

(defmethod group-button-press ((group viri-group) button x y (window float-window))
  (declare (ignore x y))
  (if (not (viri-col-of group window))
      (call-next-method)               ; a dialog: StumpWM's own moving and resizing
      ;; Never signals: it runs from the event loop.
      (handler-case
          (let ((super (intersection (float-window-modifier) *button-state*)))
            (case button
              (:wheel-up (when super (viri-step :left nil)))
              (:wheel-down (when super (viri-step :right nil)))
              ((:left-button :right-button)
               (let ((parent (window-parent window)))
                 ;; Where in the window's frame the pointer is: beside the
                 ;; window (its side edge), or above it (its title bar).
                 ;; Asked before the window is focused, which may move it.
                 (multiple-value-bind (px py) (xlib:query-pointer parent)
                   (let ((beside (not (< -1 px (xlib:drawable-width parent))))
                         (above (< py (xlib:drawable-y (window-xwin window)))))
                     (group-focus-window group window)
                     (cond ((or (and super (eq button :right-button))
                                (and beside (eq button :left-button)))
                            (viri-drag-width group window))
                           ((and (eq button :left-button) (or super above))
                            (viri-drag-column group window)))))))))
        (error (e) (message "The strip: ~a" e)))))

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

(defun viri-ml-click (code id &rest rest)
  "A click on a window's name in the bar goes to it; the wheel there walks
along the strip, as Super+h and Super+l do. Never signals: it runs from
the event loop."
  (declare (ignore rest))
  (handler-case
      (let ((window (window-by-id id)))
        (cond ((and (member code '(4 5)) (viri-group-p))
               (viri-step (if (= code 4) :left :right) nil))
              (window (focus-all window))))
    (error (e) (message "The bar: ~a" e))))

(register-ml-on-click-id :viri-ml-window 'viri-ml-click)

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
                    :viri-ml-window (window-id w))))
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

;;; The strip in small, for the overview (overview.lisp draws it, Super+o).

(defun viri-overview-boxes (group room &optional (most 1/4))
  "The strip in small, to fit ROOM pixels across and at MOST that scale: a
list of (WINDOW X Y W H) from the picture's top left. More values: the
picture's width and height, and where the part on the screen starts and
how wide it is."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (declare (ignore ax ay))
    (let* ((spans (viri-spans group aw))
           (total (max aw (if spans (let ((l (car (last spans)))) (+ (car l) (cdr l))) 0)))
           (scale (min most (/ room total)))
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
