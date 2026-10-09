;;;; viri.lisp — a workspace that scrolls sideways (Viri, plans/DESIGN-viri.md).
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

(defvar *viri-arriving* nil
  "While a whole column is sent to another strip: the column made for it
there, which its windows join as they arrive.")

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
(vikix-dialog-p, windows.lisp), one a rule floats (rules.lisp), or one of
the drawer's (drawer.lisp)."
  (or (and (fboundp 'vikix-dialog-p) (funcall 'vikix-dialog-p window))
      (and (fboundp 'vikix-drawer-window-p)
           (or (funcall 'vikix-drawer-window-p window)
               (ignore-errors (funcall 'vikix-drawer-wanted-p window))))
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

;; A pinned column (s-\) stays at the screen's left edge while the rest of
;; the strip scrolls beside it: a chat, a page you're reading from, a
;; terminal with a log. It is the strip's first column, and the others
;; start where it ends; only where it is drawn differs, always at the edge.
;; One a strip. Kept in a table by the strip, not in the strip itself, so a
;; desktop that is running needn't learn a new slot.

;; A column's windows stand one above the other, sharing its height, or as
;; tabs (s-z): one of them shown, as high as the column, the others behind
;; it, each a tab in its title bar. The others are hidden as a tile's
;; windows behind the one it shows are, so nothing shows through a window
;; that isn't solid. Which columns are tabbed is kept in a table by the
;; column, not in the column: viri-col is a structure, and a structure
;; that changes asks questions of a desktop that is running.

(defvar *viri-tabbed* (make-hash-table :test 'eq :weakness :key)
  "The columns whose windows are tabs.")

(defun viri-tabbed-p (col)
  (and col (gethash col *viri-tabbed*) t))

(defun viri-titlebar-tabs (window)
  "The windows to draw as tabs in WINDOW's title bar: its column's, when
that is tabbed and has more than one; else NIL."
  (let* ((group (window-group window))
         (col (and (viri-group-p group) (viri-col-of group window))))
    (and (viri-tabbed-p col) (rest (viri-col-windows col))
         (viri-col-windows col))))

;; A column's stacked windows share its height evenly, unless one was given
;; more or less (s-v, or the edge between two dragged). A window's weight is
;; its share against 1 for an even one, kept in a table by the window and
;; only for those given another: a window that joins a column takes an
;; even share of it.

(defvar *viri-weights* (make-hash-table :test 'eq :weakness :key)
  "A window's share of its column's height, against 1 for an even share.")

(defparameter *viri-height-shares* '(1/3 1/2 2/3)
  "The shares of its column's height Super+v gives a window, each
larger than the last; after the largest, all are even again.")

(defparameter *viri-height-least* 1/10
  "The least of its column's height a window can be given.")

(defun viri-weight (window)
  (gethash window *viri-weights* 1))

(defun viri-height-share (col window)
  "WINDOW's part of COL's height, of 1."
  (/ (viri-weight window) (reduce #'+ (viri-col-windows col) :key #'viri-weight)))

(defun viri-heights (col total)
  "The pixels of TOTAL each of COL's windows gets, top to bottom: by their
weights, the last one taking what's left."
  (let ((sum (reduce #'+ (viri-col-windows col) :key #'viri-weight))
        (used 0))
    (loop for (w . more) on (viri-col-windows col)
          for h = (if more (round (* total (/ (viri-weight w) sum))) (- total used))
          collect (max 1 h)
          do (incf used h))))

(defun viri-set-share (col window share)
  "Give WINDOW SHARE of COL's height (of 1, kept within what leaves the
others *viri-height-least* each); the others keep their proportions in
the rest. Weights are kept so that an even share is 1."
  (let* ((windows (viri-col-windows col))
         (n (length windows)))
    (when (> n 1)
      (let* ((share (max *viri-height-least*
                         (min share (- 1 (* (1- n) *viri-height-least*)))))
             (old (viri-height-share col window))
             (shares (mapcar (lambda (w)
                               (if (eq w window)
                                   share
                                   (* (viri-height-share col w) (/ (- 1 share) (- 1 old)))))
                             windows)))
        (loop for w in windows
              for s in shares
              do (setf (gethash w *viri-weights*) (* s n)))))))

(defun viri-even-heights (col)
  (dolist (w (viri-col-windows col))
    (remhash w *viri-weights*)))

(defvar *viri-pinned* (make-hash-table :test 'eq :weakness :key)
  "Each strip's pinned column, when it has one.")

(defun viri-pinned (group)
  "GROUP's pinned column, or NIL: forgotten once it has left the strip."
  (let ((col (gethash group *viri-pinned*)))
    (cond ((null col) nil)
          ((member col (viri-cols group)) col)
          (t (remhash group *viri-pinned*) nil))))

(defun viri-pin-width (group width)
  "The pixels GROUP's pinned column takes of a screen WIDTH wide: none
without one, and never more than two thirds, so the strip has room."
  (let ((col (viri-pinned group)))
    (if col
        (min (max 1 (floor (* (viri-col-width col) width))) (floor (* width 2/3)))
        0)))

(defun viri-spans (group width &optional (offset (viri-offset group)))
  "Each column's place along the strip: a list of (x . w) in pixels from its
left end, for a screen WIDTH wide. The pinned column's is where the screen
starts with the strip scrolled by OFFSET; the others begin after it."
  (let* ((pinned (viri-pinned group))
         (x (viri-pin-width group width)))
    (loop for c in (viri-cols group)
          collect (if (eq c pinned)
                      (cons offset (viri-pin-width group width))
                      (let ((w (max 1 (floor (* (viri-col-width c) width)))))
                        (prog1 (cons x w) (incf x w)))))))

(defun viri-length (group width)
  "The strip's whole length in pixels: the pinned column, then the rest."
  (let ((pinned (viri-pinned group)))
    (loop for c in (viri-cols group)
          for (x . w) in (viri-spans group width 0)
          unless (eq c pinned) maximize (+ x w) into end
          finally (return (max (or end 0) (viri-pin-width group width))))))

(defun viri-clamp-offset (group width)
  "Never scrolled past the strip's ends."
  (setf (viri-offset group)
        (max 0 (min (viri-offset group) (- (viri-length group width) width)))))

(defun viri-left (group)
  "The first column wholly on the screen, of those that scroll."
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ax ay))
    (let ((from (+ (viri-offset group) (viri-pin-width group aw))))
      (or (position-if (lambda (span) (>= (car span) from)) (viri-spans group aw)) 0))))

(defun viri-visible (group)
  "The columns wholly on the screen, of those that scroll, as their
positions in the strip. (The pinned one always is.)"
  (multiple-value-bind (ax ay aw) (viri-area group)
    (declare (ignore ax ay))
    (let* ((off (viri-offset group))
           (from (+ off (viri-pin-width group aw))))
      (loop for span in (viri-spans group aw)
            for i from 0
            when (and (>= (car span) from) (<= (+ (car span) (cdr span)) (+ off aw)))
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
          (pinned (viri-pinned group))
          (pause (/ *viri-animate-seconds* *viri-animate-frames*)))
      (dolist (offset (viri-slide-offsets from to))
        (loop for c in (viri-cols group)
              for (x . nil) in spans
              unless (eq c pinned)    ; it stays where it is
                do (dolist (w (viri-col-windows c))
                     (unless (window-fullscreen w)
                       (setf (xlib:drawable-x (window-parent w)) (+ ax (- x offset))))))
        (xlib:display-finish-output *display*)
        (sleep pause)))))

(defun viri-standing (group width)
  "What stands where on GROUP's strip: to tell whether only the scroll changed."
  (loop for c in (viri-cols group)
        for span in (viri-spans group width 0)
        collect (cons span (copy-list (viri-col-windows c)))))

(defun viri-layout (group)
  "Put every window where it belongs, sliding there when the strip has
scrolled since it was last laid out."
  ;; The pinned column is the first: put back there if it was moved.
  (let ((pinned (viri-pinned group)))
    (when (and pinned (not (eq pinned (first (viri-cols group)))))
      (setf (viri-cols group) (cons pinned (remove pinned (viri-cols group))))))
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
its edges; the windows of a column one above the other, sharing its height
(viri-heights), or as tabs."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (loop for c in (viri-cols group)
          for (x . cw) in (viri-spans group aw offset)
          for tabbed = (viri-tabbed-p c)
          for shown = (viri-col-window c)
          do (loop for w in (viri-col-windows c)
                   for height in (viri-heights c ah)
                   for top = 0 then (+ top above)
                   for above = height
                   ;; Tabs each have the whole column; stacked windows share
                   ;; it, evenly or by the weights they were given.
                   for wy = (if tabbed ay (+ ay top))
                   for wh = (if tabbed ah height)
                   ;; A strip shows every column: a window the tiles had hidden
                   ;; (iconic) is shown again, now, or when the workspace is.
                   ;; But for a tabbed column's windows behind the one it shows.
                   when (and (window-hidden-p w) (or (not tabbed) (eq w shown)))
                     do (unhide-window w)
                   when (and tabbed (not (eq w shown)) (not (window-hidden-p w)))
                     do (hide-window w)
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
                                  (funcall 'vikix-titlebar-remove w))))))))
  ;; The pinned column over the ones that scroll under it, and a dialog
  ;; over that.
  (let ((pinned (viri-pinned group)))
    (when pinned
      (dolist (w (viri-col-windows pinned))
        (setf (xlib:window-priority (window-parent w)) :above))
      (dolist (w (group-windows group))
        (unless (viri-col-of group w)
          (setf (xlib:window-priority (window-parent w)) :above))))))

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

(defparameter *viri-peek* 24
  "Pixels of the next column kept in sight at the screen's edge, on each
side that has one, when the strip scrolls to a column: a sliver that says
there is more that way. 0: none, and two half columns fill the screen
exactly whatever stands beyond them.")

(defun viri-scroll-to (group window)
  "Scroll just far enough that WINDOW's column is wholly on the screen
with a sliver of its neighbours beside it (*viri-peek*), its left edge
first when it's wider than the room there is; or with *viri-centre* so
that it's in the middle (of what the pinned column leaves). True when the
strip moved."
  (let* ((col (viri-col-of group window))
         (cols (viri-cols group))
         (i (position col cols))
         (pinned (viri-pinned group)))
    ;; The pinned column is on the screen wherever the strip is.
    (when (and i (not (eq col pinned)))
      (multiple-value-bind (ax ay aw) (viri-area group)
        (declare (ignore ax ay))
        (destructuring-bind (x . w) (nth i (viri-spans group aw))
          (let* ((old (viri-offset group))
                 ;; The others have the screen from where the pinned one ends.
                 (pin (viri-pin-width group aw))
                 ;; A sliver on each side that has a column to show.
                 (before (if (> i (if pinned 1 0)) *viri-peek* 0))
                 (after (if (< i (1- (length cols))) *viri-peek* 0))
                 ;; The scrolls that show it whole: no less than LOW, no
                 ;; more than HIGH; with the slivers, a little within those.
                 (low (- (+ x w) aw))
                 (high (- x pin)))
            (setf (viri-offset group)
                  (cond (*viri-centre* (- (+ x (floor w 2)) pin (floor (- aw pin) 2)))
                        ;; Wider than the room there is (beside a wide pinned
                        ;; column): its left edge where the room starts,
                        ;; always. Brought into view an edge at a time, it
                        ;; went from one to the other at every change of
                        ;; focus in it.
                        ((> low high) high)
                        ;; Room for it and the slivers: as little as moves it there.
                        ((<= (+ low after) (- high before))
                         (max (+ low after) (min old (- high before))))
                        ;; Room for it alone.
                        (t (max low (min old high)))))
            (viri-clamp-offset group aw)
            (/= old (viri-offset group))))))))

;;; What StumpWM asks of a group, where a strip differs from a float group.

(defmethod group-add-window ((group viri-group) window &key &allow-other-keys)
  ;; A title bar left from the tiles would cover the top of a dialog here;
  ;; a column gets its own again as the strip is laid out.
  (when (fboundp 'vikix-titlebar-remove)
    (funcall 'vikix-titlebar-remove window))
  ;; A new column goes right of the focused one, the way you're working.
  ;; The windows of a column sent here whole (viri-send-column) go into
  ;; the one column made for them, each under the last.
  (unless (or (viri-floats-p window) (viri-col-of group window))
    (let* ((cols (viri-cols group))
           (arriving (and *viri-arriving* (member *viri-arriving* cols) *viri-arriving*))
           (new (or *viri-arriving* (make-viri-col (list window))))
           (at (and (not *viri-appending*)
                    (position (viri-col-of group (group-current-window group)) cols))))
      (if arriving
          (setf (viri-col-windows arriving) (append (viri-col-windows arriving) (list window)))
          (progn
            (when *viri-arriving*
              (setf (viri-col-windows new) (list window)))
            (setf (viri-cols group)
                  (if at
                      (append (subseq cols 0 (1+ at)) (list new) (nthcdr (1+ at) cols))
                      (append cols (list new))))))))
  (call-next-method)
  ;; A dialog in the middle; the drawer's windows have their own place.
  (when (and (viri-floats-p window)
             (not (and (fboundp 'vikix-drawer-window-p) (funcall 'vikix-drawer-window-p window))))
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
    (when col
      (setf (viri-col-focus col) window)
      ;; A tab that was behind: it's the one its column shows now.
      (when (and (viri-tabbed-p col) (window-hidden-p window)
                 (eq group (current-group)))
        (viri-place group (viri-offset group)))))
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

;; The bar hidden or shown (Super+Ctrl+h): StumpWM tells every workspace
;; with group-sync-head, which does nothing for a floating one, so a strip
;; kept the bar's room empty at its top. The strip in view is laid out
;; again now; another is when it is gone to (group-wake-up).
(defmethod group-sync-head ((group viri-group) head)
  (declare (ignore head))
  (when (eq group (current-group))
    (viri-layout group)))

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
           (let* ((pinned (viri-pinned group))
                  (j (cond ((eq dir :left) (1- i))
                           ;; From the pinned column: the one standing beside
                           ;; it on the screen, not the strip's first.
                           ((and (eq col pinned) (not move)) (max 1 (viri-left group)))
                           (t (1+ i)))))
             (when (< -1 j (length cols))
               (cond ((not move)
                      (group-focus-window group (viri-col-window (nth j cols))))
                     ((or (eq col pinned) (eq (nth j cols) pinned))
                      (message "The pinned column stays at the edge (Super+\\ unpins it)."))
                     (t
                      (rotatef (nth i (viri-cols group)) (nth j (viri-cols group)))
                      (viri-scroll-to group window)
                      (viri-layout group)))))))))

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
other. A strip has no splits to make: there \"below\" makes this window
taller in its column (vikix-height), and side by side makes its column as
wide as the others on the screen leave room for (vikix-fill)."
  (cond ((and (viri-group-p) (equal how "below"))
         ;; The key for one above the other: on a strip, where windows stand
         ;; so in a column, it is how much of the column this one has.
         (viri-cycle-height (current-group)))
        ((viri-group-p)
         ;; And the key for side by side, where columns stand so: how much of
         ;; the screen this one has beside the others on it.
         (viri-fill (current-group)))
        ((equal how "below") (run-commands "vsplit"))
        (t (run-commands "hsplit"))))

(defun viri-send-column (group col to)
  "COL of GROUP's strip to the workspace TO, with all its windows: on a
strip, one column there as it was here (its width, tabs or stack, the
heights); on tiles, each window tiled (as any window from a strip is)."
  (let ((windows (copy-list (viri-col-windows col)))
        (shown (viri-col-window col))
        (*viri-arriving* (and (viri-group-p to)
                              (make-viri-col '() (viri-col-width col)))))
    (when (and *viri-arriving* (viri-tabbed-p col))
      (setf (gethash *viri-arriving* *viri-tabbed*) t))
    (dolist (w windows)
      (move-window-to-group w to))
    (when *viri-arriving*
      (setf (viri-col-focus *viri-arriving*) shown))
    (length windows)))

(defcommand vikix-send (to-group) ((:group "To workspace: "))
  "Send this window to another workspace (StumpWM's gmove); on a strip, the
whole column it is in, which stays a column there."
  (let* ((group (current-group))
         (window (current-window))
         (col (and window (viri-group-p group) (viri-col-of group window))))
    (cond ((or (null to-group) (null window)))
          ((eq to-group group)
           (message "It is on workspace ~a already." (group-name group)))
          ((and col (rest (viri-col-windows col)))
           (let ((n (viri-send-column group col to-group)))
             (message "The column's ~d windows are on workspace ~a." n (group-name to-group))))
          (t (move-window-to-group window to-group)))))

(defcommand vikix-send-named (name) ((:vikix-workspace "To workspace: "))
  "Send this window to a workspace by name (Super+Shift+0; Tab completes),
staying where you are. A name there is no workspace of gets a new
workspace of that name, as Super+0 gives it (groups.lisp), whether or not
one of the nine is empty. On a strip, the whole column goes, as vikix-send
sends it."
  (let* ((name (string-trim " " (or name "")))
         (window (current-window))
         (there (and (plusp (length name)) (find-group (current-screen) name))))
    (cond ((zerop (length name)))
          ((null window) (message "No window here to send."))
          ((not (or there (vikix-workspace-name-ok name)))
           (message "~s is no name for a workspace: a word or two, not a number." name))
          (t (let ((group (or there (vikix-workspace-claim name :go nil :named t))))
               (vikix-send group)
               (unless there
                 (message "Workspace ~a, new: the window is there (Super+0 ~a goes to it)." name name)))))))

(defun viri-fill (group)
  "The focused column as wide as the room the other columns wholly on the
screen leave: with it they fill the screen exactly, and none is cut."
  (let* ((window (group-current-window group))
         (col (viri-col-of group window)))
    (cond ((null col)
           (message "No column here."))
          ((eq col (viri-pinned group))
           (message "The pinned column keeps the width you gave it: Super+r changes it."))
          (t
           (multiple-value-bind (ax ay aw) (viri-area group)
             (declare (ignore ax ay))
             (let* ((pin (viri-pin-width group aw))
                    (i (position col (viri-cols group)))
                    (spans (viri-spans group aw))
                    ;; The others wholly on the screen keep their widths.
                    (others (remove i (viri-visible group)))
                    (room (- aw pin (loop for j in others sum (cdr (nth j spans)))))
                    (width (/ room aw)))
               (cond ((< width *viri-width-least*)
                      (message "The other columns on the screen leave no room: Super+r makes one of them narrower."))
                     ((= room (cdr (nth i spans)))
                      (message "This column has the room there is already."))
                     (t
                      (setf (viri-col-width col) width)
                      ;; Scrolled so that the first of them stands at the
                      ;; screen's edge (or the pinned column's): then they fit.
                      (let ((first (reduce #'min (cons i others))))
                        (setf (viri-offset group)
                              (- (car (nth first (viri-spans group aw))) pin)))
                      (viri-layout group)
                      (message "This column fills the room the others leave: ~d% of the screen"
                               (round (* 100 width)))))))))))

(defcommand vikix-fill () ()
  "On a strip: this column as wide as the room the other columns on the
screen leave, so that together they fill it."
  (if (viri-group-p)
      (viri-fill (current-group))
      (message "Filling the screen beside the other columns is a strip's (vikix viri).")))

(defun viri-cycle-height (group)
  "The focused window taller in its column: the next of *viri-height-shares*
above what it has; from the largest, every window of the column even again."
  (let* ((window (group-current-window group))
         (col (viri-col-of group window)))
    (cond ((null col)
           (message "No column here."))
          ((null (rest (viri-col-windows col)))
           (message "This window has its column to itself: Super+[ or Super+] brings another in."))
          ((viri-tabbed-p col)
           (message "Tabs each have the whole column: Super+z stacks them again."))
          (t
           (let* ((now (viri-height-share col window))
                  ;; Not past what leaves the others their least.
                  (most (- 1 (* (1- (length (viri-col-windows col))) *viri-height-least*)))
                  (next (find-if (lambda (s) (and (> s now) (<= s most))) *viri-height-shares*)))
             (if next
                 (viri-set-share col window next)
                 (viri-even-heights col))
             (viri-layout group)
             (message "~:[The column's windows share its height evenly again~;This window: ~:*~a of its column's height~]"
                      (and next (case next (1/3 "a third") (1/2 "half") (2/3 "two thirds") (t next)))))))))

(defcommand vikix-height () ()
  "On a strip: this window taller in its column, a third of it, half, two
thirds, then every window of the column even again."
  (if (viri-group-p)
      (viri-cycle-height (current-group))
      (message "A window's height in its column is a strip's (vikix viri).")))

(defun viri-toggle-tabs (group)
  "The focused column's windows as tabs, or stacked again (Super+z on a strip)."
  (let ((col (viri-col-of group (group-current-window group))))
    (cond ((null col)
           (message "No column here."))
          ((viri-tabbed-p col)
           (remhash col *viri-tabbed*)
           (viri-layout group)
           (message "Stacked again: the column's windows one above the other."))
          ((null (rest (viri-col-windows col)))
           (message "One window in this column: Super+[ or Super+] brings another in, then Super+z makes them tabs."))
          (t
           (setf (gethash col *viri-tabbed*) t)
           (viri-layout group)
           (message "Tabs: one window at a time, as high as the column. Super+j and Super+k go between them.")))))

(defun viri-pin (group col)
  "Make COL GROUP's pinned column (NIL: none), and lay the strip out."
  (if col
      (setf (gethash group *viri-pinned*) col)
      (remhash group *viri-pinned*))
  (when (group-current-window group)
    (viri-scroll-to group (group-current-window group)))
  (viri-layout group))

(defcommand vikix-pin (&optional what) ((:string nil))
  "On a strip: pin this column to the screen's left edge, where it stays
while the others scroll beside it; on the pinned column (or with \"off\"),
unpin it. One column is pinned at a time."
  (let* ((group (current-group))
         (col (and (viri-group-p group) (viri-col-of group (group-current-window group))))
         (pinned (and (viri-group-p group) (viri-pinned group))))
    (cond ((not (viri-group-p group))
           (message "Pinning is for strips (vikix viri)."))
          ((equal what "off")
           (viri-pin group nil)
           (message "No column is pinned."))
          ((null col)
           (message "No column here to pin."))
          ((and (eq col pinned) (not (equal what "on")))
           (viri-pin group nil)
           (message "Unpinned: it scrolls with the others again."))
          ((null (rest (viri-cols group)))
           (message "One column has nothing to stay beside."))
          (t
           (viri-pin group col)
           (message "Pinned at the left edge: the others scroll beside it. Super+\\ here unpins it.")))))

(defun viri-scrolling (group)
  "GROUP's columns but the pinned one."
  (remove (viri-pinned group) (viri-cols group)))

(defcommand vikix-focus-end (which) ((:string "first or last: "))
  "On a strip: go to its first column, or its last (of those that scroll)."
  (let ((group (current-group)))
    (if (not (viri-group-p group))
        (message "The first and the last column are a strip's (vikix viri).")
        (let ((cols (or (viri-scrolling group) (viri-cols group))))
          (when cols
            (group-focus-window group (viri-col-window (if (equal which "last")
                                                           (first (last cols))
                                                           (first cols)))))))))

(defcommand vikix-move-end (which) ((:string "first or last: "))
  "On a strip: move this column to the start, or to the end."
  (let* ((group (current-group))
         (window (and (viri-group-p group) (group-current-window group)))
         (col (and window (viri-col-of group window))))
    (cond ((not (viri-group-p group))
           (message "Moving a column to the start or the end is a strip's (vikix viri)."))
          ((null col))
          ((eq col (viri-pinned group))
           (message "The pinned column stays at the edge (Super+\\ unpins it)."))
          (t
           (let ((others (remove col (viri-cols group))))
             ;; viri-layout puts the pinned column back in front of it.
             (setf (viri-cols group)
                   (if (equal which "last") (append others (list col)) (cons col others))))
           (viri-scroll-to group window)
           (viri-layout group)))))

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

;;; The arrows: the workspace beside this one (Super+Left, Super+Right), and
;;; the window taken along (Super+Shift+Left, Super+Shift+Right). The order is
;;; the bar's, StumpWM's by number, round the ends, hidden workspaces (the
;;; drawer's) left out; a strip counts as any other.

(defun vikix-workspace-beside (dir)
  "The workspace left or right of this one, round the ends; nil when there
is no other, or when DIR is up or down: workspaces sit side by side."
  (when (or (string-equal dir "left") (string-equal dir "right"))
    (let ((groups (non-hidden-groups (sort-groups (current-screen)))))
      (next-group (current-group) (if (string-equal dir "left") (reverse groups) groups)))))

(defcommand vikix-workspace-step (dir) ((:direction "Direction: "))
  "Go to the workspace on the left or the right, round the ends."
  (let ((there (vikix-workspace-beside dir)))
    (cond (there (switch-to-group there))
          ((or (string-equal dir "up") (string-equal dir "down"))
           (message "Workspaces sit side by side: left or right."))
          (t (message "No other workspace.")))))

(defcommand vikix-workspace-carry (dir) ((:direction "Direction: "))
  "Take this window to the workspace on the left or the right and go with
it; on a strip, the whole column it is in, as vikix-send sends it."
  (let ((there (vikix-workspace-beside dir))
        (window (current-window)))
    (cond ((null there) (vikix-workspace-step dir))
          ((null window) (message "No window here to take along."))
          (t (vikix-send there)
             (switch-to-group there)
             (when (member window (group-windows there))
               (group-focus-window there window))))))

;;; The mouse on a strip.
;;;
;;; A column is a floating window to StumpWM, which lets the mouse carry one
;;; anywhere and pull it to any size: on a strip that left a column lying
;;; over its neighbours until the next layout. Here the mouse does what a
;;; strip can keep:
;;;
;;;   Super + the wheel, over the strip    walk along it (so does the wheel
;;;                                        on the bar's window names)
;;;   two fingers swept sideways           the same: the touchpad's sideways
;;;                                        scrolling, which a strip takes
;;;                                        for itself (*viri-scroll-walks*)
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

(defparameter *viri-scroll-walks* t
  "True: scrolling sideways over a strip (two fingers swept left or right on
a touchpad, a mouse's tilting wheel) walks along it. NIL: it is left to the
program under the pointer, as off a strip.")

(defparameter *viri-scroll-clicks* 6
  "How many clicks of sideways scrolling are a step along the strip: fewer
is quicker. A touchpad sends one every little way the fingers go.")

(defvar *viri-scrolled* (list nil 0 0 0 0)
  "The sweep of scrolling so far: which way sideways, the clicks toward the
next step, all its clicks sideways, all up and down, and when the last came.")

(defun viri-scroll-walk (button)
  "A click of scrolling over a strip. Sideways, every *viri-scroll-clicks*
of them one way without a pause is a step along the strip that way (the way
the view would scroll, so as the touchpad is set); up and down they are only
counted, so that a page scrolled by fingers that drift a little sideways
doesn't walk the strip: the sweep has to be twice as much sideways."
  (destructuring-bind (was count across along at) *viri-scrolled*
    (let ((now (get-internal-real-time))
          (dir (case button (:wheel-left :left) (:wheel-right :right))))
      ;; A pause: a new sweep.
      (when (> (- now at) (floor (* 4 internal-time-units-per-second) 10))
        (setf was nil count 0 across 0 along 0))
      (cond ((null dir) (incf along))
            (t (unless (eq dir was) (setf count 0))
               (incf count)
               (incf across)
               (when (and (>= count (max 1 *viri-scroll-clicks*))
                          (>= across (* 2 along)))
                 (setf count 0)
                 (viri-step dir nil))
               (setf was dir)))
      (setf *viri-scrolled* (list was count across along (get-internal-real-time)))
      (when dir
        ;; Let go without passing it on: a program that takes its scrolling
        ;; as wheel clicks doesn't scroll sideways as well. (StumpWM would
        ;; replay the click to it after this.)
        (ignore-errors (xlib:allow-events *display* :async-pointer))))))

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
    (when (and moved (not (eq col (viri-pinned group))))
      (multiple-value-bind (ax ay aw) (viri-area group)
        (declare (ignore ay))
        ;; Its new place: after every other column whose middle is left of
        ;; the pointer. (The pinned one, let go, is laid out where it was.)
        (let* ((at (+ (- (xlib:global-pointer-position *display*) ax) (viri-offset group)))
               (before (loop for c in (viri-cols group)
                             for (x . w) in (viri-spans group aw)
                             unless (eq c col)
                               count (< (+ x (floor w 2)) at)))
               (others (remove col (viri-cols group))))
          (setf (viri-cols group)
                (append (subseq others 0 before) (list col) (nthcdr before others))))))
    (viri-scroll-to group window)
    (viri-layout group)
    moved))

(defun viri-tab-click (group window px)
  "A click on WINDOW's title bar PX pixels from its left: on a tabbed
column, go to the tab there."
  (let ((tabs (viri-titlebar-tabs window)))
    (when tabs
      (let* ((width (max 1 (xlib:drawable-width (window-parent window))))
             (tab (nth (max 0 (min (1- (length tabs)) (floor (* px (length tabs)) width))) tabs)))
        (unless (eq tab window)
          (group-focus-window group tab))))))

(defun viri-drag-height (group upper lower)
  "The edge between UPPER and LOWER, two windows one above the other in a
column, taken up or down with the pointer while the button is down: what
one gains the other gives, a twentieth of the column at a time."
  (let* ((col (viri-col-of group upper))
         (py0 (nth-value 1 (xlib:global-pointer-position *display*)))
         (sum (reduce #'+ (viri-col-windows col) :key #'viri-weight))
         (both (+ (viri-weight upper) (viri-weight lower)))
         (start (/ (viri-weight upper) sum))
         (least *viri-height-least*)
         (most (- (/ both sum) least)))
    (multiple-value-bind (ax ay aw ah) (viri-area group)
      (declare (ignore ax ay aw))
      (viri-drag (group-screen group)
                 (lambda (px py)
                   (declare (ignore px))
                   (let* ((share (max least
                                      (min most (* *viri-width-step*
                                                   (round (+ start (/ (- py py0) ah)) *viri-width-step*)))))
                          (weight (* share sum)))
                     (unless (= weight (viri-weight upper))
                       (setf (gethash upper *viri-weights*) weight
                             (gethash lower *viri-weights*) (- both weight))
                       (viri-place group (viri-offset group))
                       (xlib:display-finish-output *display*))))))
    (viri-layout group)))

(defmethod group-button-press ((group viri-group) button x y (window float-window))
  (declare (ignore x y))
  (if (not (viri-col-of group window))
      (call-next-method)               ; a dialog: StumpWM's own moving and resizing
      ;; Never signals: it runs from the event loop.
      (handler-case
          (let ((super (intersection (float-window-modifier) *button-state*)))
            (case button
              ((:wheel-up :wheel-down)
               (if super
                   (viri-step (if (eq button :wheel-up) :left :right) nil)
                   (viri-scroll-walk button)))
              ((:wheel-left :wheel-right)
               (when *viri-scroll-walks* (viri-scroll-walk button)))
              ((:left-button :right-button)
               (let ((parent (window-parent window)))
                 ;; Where in the window's frame the pointer is: beside the
                 ;; window (its side edge), or above it (its title bar).
                 ;; Asked before the window is focused, which may move it.
                 (multiple-value-bind (px py) (xlib:query-pointer parent)
                   (let* ((beside (not (< -1 px (xlib:drawable-width parent))))
                          (above (< py (xlib:drawable-y (window-xwin window))))
                          ;; On its top or bottom edge, with a window of its
                          ;; column the other side of it: the two that edge parts.
                          (col (viri-col-of group window))
                          (k (position window (viri-col-windows col)))
                          (parted (and (eq button :left-button) (not super) (not beside)
                                       (not (viri-tabbed-p col))
                                       (cond ((and (< py 0) (plusp k))
                                              (list (nth (1- k) (viri-col-windows col)) window))
                                             ((and (>= py (xlib:drawable-height parent))
                                                   (nth (1+ k) (viri-col-windows col)))
                                              (list window (nth (1+ k) (viri-col-windows col))))))))
                     (group-focus-window group window)
                     (cond (parted
                            (viri-drag-height group (first parted) (second parted)))
                           ((or (and super (eq button :right-button))
                                (and beside (eq button :left-button)))
                            (viri-drag-width group window))
                           ((and (eq button :left-button) (or super above))
                            ;; Not carried anywhere: a click, on a tab perhaps.
                            (unless (viri-drag-column group window)
                              (when above
                                (viri-tab-click group window px)))))))))))
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

(defun viri-window-entry (w current)
  "W's entry in the bar's window list: *window-format* filled in, then in
the colour of what its agent's terminal needs of you (vikix-window-list-entry,
agents.lisp: asks, gup, close), else highlighted when W is CURRENT."
  (let ((str (format-expand *window-formatters* *window-format* w)))
    (if (fboundp 'vikix-window-list-entry)
        (funcall 'vikix-window-list-entry w str (eq w current))
        (if (eq w current) (fmt-highlight str) str))))

(defun viri-mode-line-windows (ml)
  "On a strip, its windows in order, the two on the screen in [brackets]
and the focused one picked out, each a click away; elsewhere StumpWM's own
list (fmt-head-window-list, with the agents' colours). So you can see how
far along the strip you are, and what's off it."
  (let ((group (mode-line-current-group ml)))
    (if (not (viri-group-p group))
        (format nil "~{~a~^ ~}"
                (mapcar (lambda (w)
                          (format-with-on-click-id (viri-window-entry w (current-window))
                                                   :ml-on-click-focus-window (window-id w)))
                        (sort1 (head-windows group (mode-line-head ml)) #'< :key #'window-number)))
        (let* ((cols (viri-cols group))
               (shown (viri-visible group))
               (floats (remove-if (lambda (w) (viri-col-of group w)) (group-windows group))))
          (flet ((name (w)
                   (format-with-on-click-id (viri-window-entry w (group-current-window group))
                                            :viri-ml-window (window-id w))))
            (format nil "~{~a~^ ~}"
                    (append (loop for c in cols
                                  for i from 0
                                  ;; A column of several windows: joined by /.
                                  collect (concatenate 'string
                                                       (if (eql i (first shown)) "[" "")
                                                       ;; Stacked windows joined by /, tabs by +.
                                                       (format nil (if (viri-tabbed-p c) "~{~a~^+~}" "~{~a~^/~}")
                                                               (mapcar #'name (viri-col-windows c)))
                                                       (if (eql i (car (last shown))) "]" "")
                                                       ;; The pinned column: a bar after it.
                                                       (if (eq c (viri-pinned group)) " |" "")))
                            (mapcar #'name floats))))))))

(add-screen-mode-line-formatter #\W 'viri-mode-line-windows)

;;; The overview: every window on the strip in a menu (Super+o on a strip).

;;; The strip in small, for the overview (overview.lisp draws it, Super+o).

(defun viri-overview-boxes (group room &optional (most 1/4))
  "The strip in small, to fit ROOM pixels across and at MOST that scale: a
list of (WINDOW X Y W H) from the picture's top left. More values: the
picture's width and height, and where the part on the screen starts and
how wide it is (of the columns that scroll: the pinned one, drawn first,
is always on it)."
  (multiple-value-bind (ax ay aw ah) (viri-area group)
    (declare (ignore ax ay))
    (let* ((spans (viri-spans group aw 0))
           (pin (viri-pin-width group aw))
           (total (max aw (viri-length group aw)))
           (scale (min most (/ room total)))
           (height (max 1 (round (* ah scale)))))
      (values
       (loop for c in (viri-cols group)
             for (x . w) in spans
             append (loop for win in (viri-col-windows c)
                          for h in (viri-heights c height)
                          for y = 0 then (+ y above)
                          for above = h
                          collect (list win
                                        (round (* x scale)) y
                                        (max 1 (round (* w scale))) h)))
       (round (* total scale)) height
       (round (* (+ (viri-offset group) pin) scale)) (round (* (- aw pin) scale))))))

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
