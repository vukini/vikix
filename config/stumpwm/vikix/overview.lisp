;;;; overview.lisp — every workspace, drawn small on one card (s-o).
;;;;
;;;; A card over the screen with a small picture of each workspace that has
;;;; windows: tiles as their frames, where they are and as big as they are;
;;;; a strip (viri.lisp) as its columns, with a line around the part on the
;;;; screen. Each window is a box with the title bar it has (its number and
;;;; name, the focused one's in the accent) and under it what it is
;;;; (windows.lisp's vikix-window-about: a terminal's folder and what runs
;;;; in it). A frame's other windows, the ones behind the one it shows, are
;;;; listed in its box: they can be picked too.
;;;;
;;;;   arrows, h j k l   the frame to the window that way, on any workspace
;;;;   Enter, a click    go to the window in the frame
;;;;   a digit           the window with that number, on the workspace the
;;;;                     frame is on
;;;;   /                 the list of every window, to type in (s-g's)
;;;;   g                 this workspace's windows in a real grid (StumpWM's
;;;;                     expose, which Super+o was on tiles before)
;;;;   any other key     closes; one bound to something else does that too
;;;;
;;;; Nothing is moved until a window is picked: StumpWM's expose, which this
;;;; took Super+o from on tiles, puts the workspace into a grid to show it.
;;;;
;;;; Titles, not pictures: X has no picture to give of a window that isn't
;;;; on the screen, and a compositor's would be the work of another day.
;;;;
;;;; The card is a window of Vikix's own with the drawing as its background,
;;;; as a title bar is, so X repaints it. Its keys come through
;;;; *custom-key-event-handler* with the keyboard grabbed, as the key card's.

(in-package :stumpwm)

(defparameter *vikix-overview-scales* '(1/4 1/5 1/6 1/8 1/10 1/12 1/16)
  "How small the overview may draw the workspaces: the first of these at
which they all fit on the screen is taken.")

(defparameter *vikix-overview-timeout* 60
  "Seconds the overview stays open with no key pressed.")

(defparameter *vikix-overview-hint*
  "arrows or h j k l: move    Enter or a click: go there    a number: that window    /: type to find    g: a real grid    Esc: close")

(defvar *vikix-overview* nil
  "While the overview shows, a list: :screen, :card (its X window), :plan
(what is drawn where), :at (the window the frame is on), :pad, :line, :ox
and :oy (where the plan starts on the card), :handler (the key handler
before it) and :timer.")

;;; --- What is drawn where ---------------------------------------------------
;;;
;;; A plan is (:width W :height H :panels PANELS), sizes in pixels. A panel
;;; is a workspace: (:group G :x X :y Y :w W :h H :boxes BOXES :view RECT
;;; :empty RECTS :notes NOTES), its heading at X Y and its picture under it. A box is a
;;; window: (:window W :kind :shown or :hidden :x :y :w :h), and for a shown
;;; one :band (its title bar's height) and :about (lines of text). A hidden
;;; one is a line in its frame's box. All places are from the card's top
;;; left, inside its padding.

(defun vikix-overview-groups (screen)
  "The workspaces the overview shows: those with windows and the one you're
on, in order; never a hidden one (the drop-down terminal's)."
  (remove-if-not (lambda (g)
                   (and (not (char= (char (group-name g) 0) #\.))
                        (or (typep g 'tile-group) (viri-group-p g))
                        (or (eq g (screen-current-group screen))
                            (group-windows g))))
                 (sort-groups screen)))

(defun vikix-overview-about (window)
  "What WINDOW is, a part to a line: a terminal's folder, then what runs
in it (vikix-window-about puts two spaces between them)."
  (let* ((about (or (ignore-errors (vikix-window-about window)) ""))
         (cut (search "  " about)))
    (remove "" (if cut
                   (list (subseq about 0 cut) (string-left-trim " " (subseq about cut)))
                   (list about))
            :test #'string=)))

(defun vikix-overview-strip (group scale room line)
  "A strip's picture: its boxes from the picture's top left, the picture's
width and height, and the part on the screen as (X Y W H)."
  (multiple-value-bind (boxes pw ph vx vw) (viri-overview-boxes group room scale)
    (values (loop for (win x y w h) in boxes
                  collect (list :window win :kind :shown :x x :y y :w w :h h
                                :band (min line (max 1 (- h 4))) :about nil))
            pw ph
            (list vx 0 vw ph)
            nil)))

(defun vikix-overview-tiles (group scale line)
  "A tiled workspace's picture: a box for each frame's window where the
frame is, the frame's other windows as lines in it; then the picture's
width and height, no part marked, and the frames with no window."
  (let* ((frames (group-frames group))
         (x0 (reduce #'min frames :key #'frame-x))
         (y0 (reduce #'min frames :key #'frame-y))
         (x1 (reduce #'max frames :key (lambda (f) (+ (frame-x f) (frame-width f)))))
         (y1 (reduce #'max frames :key (lambda (f) (+ (frame-y f) (frame-height f)))))
         (boxes '())
         (notes '())
         (empty '()))
    (dolist (f frames)
      (let* ((x (round (* (- (frame-x f) x0) scale)))
             (y (round (* (- (frame-y f) y0) scale)))
             (w (max 1 (round (* (frame-width f) scale))))
             (h (max 1 (round (* (frame-height f) scale))))
             (shown (or (frame-window f) (first (frame-windows group f))))
             (hidden (remove shown (frame-windows group f)))
             (band (min line (max 1 (- h 4))))
             ;; The lines there's room for under the title bar.
             (rows (max 0 (floor (- h 4 band 2) line))))
        (if (null shown)
            (push (list x y w h) empty)
            (progn
              (push (list :window shown :kind :shown :x x :y y :w w :h h :band band
                          :about nil
                          ;; What it is gives way to the windows behind it.
                          :lines (max 0 (min 2 (- rows (length hidden)))))
                    boxes)
              ;; More behind it than there are lines for: the last line
              ;; says how many more (the list, /, has them all).
              (let* ((first (max 0 (min 2 (- rows (length hidden)))))
                     (room (- rows first))
                     (fit (if (> (length hidden) room) (max 0 (1- room)) (length hidden))))
                (loop for win in hidden
                      for k from first
                      repeat fit
                      do (push (list :window win :kind :hidden
                                     :x (+ x 2) :y (+ y 2 band 2 (* k line))
                                     :w (max 1 (- w 4)) :h line)
                               boxes))
                (when (and (< fit (length hidden)) (plusp room))
                  (push (list :more (- (length hidden) fit)
                              :x (+ x 2) :y (+ y 2 band 2 (* (+ first fit) line))
                              :w (max 1 (- w 4)) :h line)
                        notes)))))))
    (values (nreverse boxes)
            (round (* (- x1 x0) scale)) (round (* (- y1 y0) scale))
            nil
            (nreverse empty)
            notes)))

(defun vikix-overview-plan-at (screen scale room line gap)
  "The plan at SCALE for a card ROOM pixels wide inside: the workspaces
side by side, on to a new row when one won't fit."
  (let ((x 0) (y 0) (row 0) (width 0) (panels '()))
    (dolist (group (vikix-overview-groups screen))
      (multiple-value-bind (boxes pw ph view empty notes)
          (if (viri-group-p group)
              (vikix-overview-strip group scale room line)
              (vikix-overview-tiles group scale line))
        (let ((w (max pw (* 4 line)))
              (h (+ line 4 ph)))
          (when (and (plusp x) (> (+ x w) room))
            (setf x 0 y (+ y row gap) row 0))
          (let ((px x) (py (+ y line 4)))
            (flet ((moved (rect) (list (+ px (first rect)) (+ py (second rect)) (third rect) (fourth rect))))
              (push (list :group group :x x :y y :w w :h h
                          :boxes (mapcar (lambda (b)
                                           (let ((b (copy-list b)))
                                             (incf (getf b :x) px)
                                             (incf (getf b :y) py)
                                             b))
                                         boxes)
                          :view (and view (moved view))
                          :empty (mapcar #'moved empty)
                          :notes (mapcar (lambda (n)
                                           (list (getf n :more) (+ px (getf n :x)) (+ py (getf n :y)) (getf n :w)))
                                         notes))
                    panels)))
          (setf width (max width (+ x w))
                x (+ x w gap)
                row (max row h)))))
    (list :width width :height (+ y row) :scale scale :panels (nreverse panels))))

(defun vikix-overview-plan (screen room-w room-h line)
  "The plan at the largest scale at which every workspace fits in ROOM-W
by ROOM-H (the smallest, if none does), each shown window's lines of what
it is written in."
  (let* ((gap (* 2 line))
         (plan (or (loop for scale in *vikix-overview-scales*
                         for plan = (vikix-overview-plan-at screen scale room-w line gap)
                         when (<= (getf plan :height) room-h) return plan)
                   (vikix-overview-plan-at screen (car (last *vikix-overview-scales*))
                                           room-w line gap))))
    (dolist (panel (getf plan :panels))
      (dolist (box (getf panel :boxes))
        ;; Written into the box: :about is there already, empty.
        (when (eq (getf box :kind) :shown)
          (setf (getf box :about) (vikix-overview-about (getf box :window))))))
    plan))

(defun vikix-overview-boxes (&optional (plan (getf *vikix-overview* :plan)))
  "Every window's box in PLAN, panel by panel."
  (loop for panel in (getf plan :panels) append (getf panel :boxes)))

(defun vikix-overview-rect (box)
  "Where the frame goes for BOX, and what the arrows measure from: a shown
window's title bar, a hidden one's line. (values x y w h)"
  (values (getf box :x) (getf box :y) (getf box :w)
          (if (eq (getf box :kind) :shown) (getf box :band) (getf box :h))))

;;; --- Drawing ----------------------------------------------------------------

(defun vikix-overview-fit (text pixels char)
  "TEXT, or its start and an ellipsis, to fit PIXELS in a font whose
characters are CHAR wide."
  (let ((room (floor pixels (max 1 char))))
    (cond ((<= (length text) room) text)
          ((< room 2) "")
          (t (concat (subseq text 0 (1- room)) "…")))))

(defun vikix-overview-colour (screen &rest keys)
  "The pixel of the first of the theme's colours KEYS it has; the text
colour without one."
  (let ((name (and (fboundp 'vikix-colour) (some (lambda (k) (funcall 'vikix-colour k)) keys))))
    (or (and name (ignore-errors (alloc-color screen name)))
        (screen-fg-color screen))))

(defun vikix-overview-draw ()
  "Paint the card: the plan, the frame on the window chosen."
  (let* ((state *vikix-overview*)
         (screen (getf state :screen))
         (card (getf state :card))
         (plan (getf state :plan))
         (at (getf state :at))
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
         (dim (vikix-overview-colour screen :color8 :subtle))
         (here (screen-current-group screen))
         (focused (group-current-window here))
         ;; The plan in the card's middle, across.
         (ox (floor (- width (getf plan :width)) 2))
         (oy pad)
         (pm (xlib:create-pixmap :width width :height height :drawable card
                                 :depth (xlib:drawable-depth card)))
         (gc (xlib:create-gcontext :drawable pm :foreground bg :background bg)))
    (setf (getf *vikix-overview* :ox) ox (getf *vikix-overview* :oy) oy)
    (flet ((colours (f b) (setf (xlib:gcontext-foreground gc) f (xlib:gcontext-background gc) b))
           (text (x y string)
             (when (plusp (length string))
               (draw-image-glyphs pm gc font x (+ y 3 ascent) string
                                  :translate #'translate-id :size 16))))
      (unwind-protect
           (progn
             (colours bg bg)
             (xlib:draw-rectangle pm gc 0 0 width height t)
             (colours dim bg)
             (text pad (- height pad line)
                   (vikix-overview-fit *vikix-overview-hint* (- width pad pad) char))
             (dolist (panel (getf plan :panels))
               (let ((group (getf panel :group)))
                 ;; Its heading: the workspace's name, yours in the accent.
                 (colours (if (eq group here) accent fg) bg)
                 (text (+ ox (getf panel :x)) (+ oy (getf panel :y))
                       (vikix-overview-fit (format nil "~a~:[~;  (here)~]" (group-name group) (eq group here))
                                           (getf panel :w) char))
                 ;; What is on the screen now, of a strip: a line around it.
                 (when (getf panel :view)
                   (destructuring-bind (x y w h) (getf panel :view)
                     (colours fg bg)
                     (xlib:draw-rectangle pm gc (+ ox x -3) (+ oy y -4) (+ w 5) (+ h 7))))
                 (colours edge bg)
                 (dolist (rect (getf panel :empty))
                   (destructuring-bind (x y w h) rect
                     (xlib:draw-rectangle pm gc (+ ox x 2) (+ oy y 2) (max 1 (- w 5)) (max 1 (- h 5)))))
                 (dolist (box (getf panel :boxes))
                   (let* ((win (getf box :window))
                          (bx (+ ox (getf box :x))) (by (+ oy (getf box :y)))
                          (bw (getf box :w)) (bh (getf box :h)))
                     (if (eq (getf box :kind) :hidden)
                         ;; A window behind the one its frame shows: a line.
                         (progn
                           (colours fg bg)
                           (text (+ bx 4) by
                                 (vikix-overview-fit (format nil "~d ~a" (window-number win) (window-name win))
                                                     (- bw 8) char))
                           (when (eq win at)
                             (colours accent bg)
                             (xlib:draw-rectangle pm gc bx by (1- bw) (1- bh))))
                         (let* ((bx (+ bx 2)) (by (+ by 2))
                                (bw (max 1 (- bw 4))) (bh (max 1 (- bh 4)))
                                (band (getf box :band))
                                (lit (eq win focused)))
                           (colours bg bg)                                   ; over the line behind it
                           (xlib:draw-rectangle pm gc bx by bw bh t)
                           (colours (if lit accent edge) bg)
                           (xlib:draw-rectangle pm gc bx by bw band t)       ; its title bar
                           (xlib:draw-rectangle pm gc bx by (1- bw) (1- bh)) ; its edge
                           (when (>= band line)
                             (colours (if lit bg fg) (if lit accent edge))
                             (text (+ bx 4) by
                                   (vikix-overview-fit (format nil "~d ~a" (window-number win) (window-name win))
                                                       (- bw 8) char)))
                           ;; What it is, a part to a line, as far as there's room
                           ;; (on tiles: as far as the windows behind it leave).
                           (colours dim bg)
                           (loop for part in (getf box :about)
                                 for k from 0
                                 for ty from (+ by band 2) by line
                                 while (and (<= (+ ty line) (+ by bh))
                                            (< k (getf box :lines 9)))
                                 do (text (+ bx 4) ty (vikix-overview-fit part (- bw 8) char)))
                           (when (eq win at)
                             (colours accent bg)
                             (xlib:draw-rectangle pm gc (- bx 2) (- by 2) (+ bw 3) (+ bh 3))
                             (xlib:draw-rectangle pm gc (- bx 1) (- by 1) (+ bw 1) (+ bh 1)))))))))
             ;; Over the boxes: a frame with more windows behind than lines.
             (colours dim bg)
             (dolist (panel (getf plan :panels))
               (dolist (note (getf panel :notes))
                 (destructuring-bind (more x y w) note
                   (text (+ ox x 4) (+ oy y)
                         (vikix-overview-fit (format nil "+ ~d more" more) (- w 8) char))))))
        (xlib:free-gcontext gc))
      ;; X keeps the picture while it is the background.
      (setf (xlib:window-background card) pm)
      (vikix-free-drawn-pixmap pm)
      (xlib:clear-area card)
      (xlib:display-finish-output *display*))))

;;; --- Opening, closing, keys, the mouse ----------------------------------------

(defun vikix-overview-close (&rest ignore)
  "Close the overview and give the keyboard back. Safe when it's closed."
  (declare (ignore ignore))
  (let ((state *vikix-overview*))
    (when state
      (setf *vikix-overview* nil)
      (when (eq *custom-key-event-handler* 'vikix-overview-key)
        (setf *custom-key-event-handler* (getf state :handler)))
      (ungrab-keyboard)
      (when (timer-p (getf state :timer))
        (cancel-timer (getf state :timer)))
      (ignore-errors (xlib:destroy-window (getf state :card)))
      ;; The card gone, X says the pointer entered what was under it: not
      ;; a reason for the focus to move.
      (ignore-errors (viri-drop-enter-events)))))

(defun vikix-overview-move (dir)
  "The frame to the nearest window that way (:left :right :up :down), on
whichever workspace it is."
  (let* ((boxes (vikix-overview-boxes))
         (from (find (getf *vikix-overview* :at) boxes :key (lambda (b) (getf b :window)))))
    (when from
      (multiple-value-bind (fx fy fw fh) (vikix-overview-rect from)
        (let ((best nil) (best-cost nil))
          (dolist (box boxes)
            (unless (eq box from)
              (multiple-value-bind (x y w h) (vikix-overview-rect box)
                ;; How far that way, and how far off to the side (nothing,
                ;; when the two overlap that way on): the side counts double.
                (let* ((along (ecase dir
                                (:left (- (+ fx (floor fw 2)) (+ x (floor w 2))))
                                (:right (- (+ x (floor w 2)) (+ fx (floor fw 2))))
                                (:up (- (+ fy (floor fh 2)) (+ y (floor h 2))))
                                (:down (- (+ y (floor h 2)) (+ fy (floor fh 2))))))
                       (aside (if (member dir '(:left :right))
                                  (max 0 (- y (+ fy fh)) (- fy (+ y h)))
                                  (max 0 (- x (+ fx fw)) (- fx (+ x w)))))
                       (cost (+ along (* 2 aside))))
                  (when (and (plusp along) (or (null best-cost) (< cost best-cost)))
                    (setf best box best-cost cost))))))
          (when best
            (setf (getf *vikix-overview* :at) (getf best :window))
            (vikix-overview-draw)))))))

(defun vikix-overview-go (window)
  "Close the overview and go to WINDOW, when it's still there."
  (vikix-overview-close)
  (when (and window (member window (group-windows (window-group window))))
    (vikix-goto-window window)))

(defun vikix-overview-key (code state)
  "The key handler while the overview shows. True means the key is used up."
  (if (is-modifier code)
      t
      (let ((pass nil))
        (handler-case
            (let* ((key (code-state->key code state))
                   (name (print-key key))
                   (at (getf *vikix-overview* :at))
                   (digit (and (= (length name) 1) (digit-char-p (char name 0)))))
              (cond ((member name '("h" "Left") :test #'string=) (vikix-overview-move :left))
                    ((member name '("l" "Right") :test #'string=) (vikix-overview-move :right))
                    ((member name '("k" "Up") :test #'string=) (vikix-overview-move :up))
                    ((member name '("j" "Down") :test #'string=) (vikix-overview-move :down))
                    ((member name '("RET" "SPC") :test #'string=)
                     (vikix-overview-go at))
                    (digit
                     ;; On the workspace the frame is on: numbers start
                     ;; again on each.
                     (let ((window (and at (find digit (group-windows (window-group at))
                                                 :key #'window-number))))
                       (if window (vikix-overview-go window) (vikix-overview-close))))
                    ((string= name "/")
                     (vikix-overview-close)
                     (run-commands "vikix-go-to-window"))
                    ((string= name "g")
                     (vikix-overview-close)
                     (run-commands "vikix-expose"))
                    (t
                     ;; Any other key closes; one bound to something else
                     ;; goes on to StumpWM, which runs it.
                     (let ((command (find-if-not #'null
                                                 (mapcar (lambda (map) (lookup-key map key))
                                                         (dereference-kmaps (top-maps))))))
                       (setf pass (and command (not (equal command "vikix-overview")))))
                     (vikix-overview-close))))
          ;; Never left open with the keyboard grabbed.
          (error () (vikix-overview-close)))
        (not pass))))

(defun vikix-overview-open (screen)
  "Show the overview on SCREEN; keys pick a window (vikix-overview-key)."
  (vikix-overview-close)
  (let* ((font (screen-font screen))
         (head (current-head))
         (pad 16)
         (line (+ 6 (font-height font)))
         (char (max 1 (round (text-line-width font "MMMMMMMMMM" :translate #'translate-id) 10)))
         (room-w (- (floor (* (head-width head) 95/100)) (* 2 pad)))
         (room-h (- (floor (* (head-height head) 90/100)) (* 2 pad) line 10))
         (plan (vikix-overview-plan screen room-w room-h line))
         (boxes (vikix-overview-boxes plan))
         (width (min (head-width head)
                     (+ (* 2 pad) (max (getf plan :width)
                                       (min room-w (* char (length *vikix-overview-hint*)))))))
         (height (min (head-height head) (+ pad (getf plan :height) 10 line pad)))
         (here (group-current-window (screen-current-group screen)))
         (card (xlib:create-window
                :parent (screen-root screen)
                :x (+ (head-x head) (floor (- (head-width head) width) 2))
                :y (+ (head-y head) (floor (- (head-height head) height) 2))
                :width width :height height
                :override-redirect :on
                :background (screen-bg-color screen)
                :border (screen-focus-color screen) :border-width 1
                :event-mask '(:button-press))))
    ;; Solid, whatever picom makes of windows without the focus.
    (xlib:change-property card :_net_wm_window_opacity (list #xffffffff) :cardinal 32)
    (setf *vikix-overview*
          (list :screen screen :card card :plan plan
                ;; The frame starts on the window you're in.
                :at (getf (or (find here boxes :key (lambda (b) (getf b :window)))
                              (first boxes))
                          :window)
                :pad pad :line line :ox 0 :oy 0
                :handler *custom-key-event-handler*
                :timer (run-with-timer *vikix-overview-timeout* nil 'vikix-overview-close))
          *custom-key-event-handler* 'vikix-overview-key)
    (xlib:map-window card)
    (setf (xlib:window-priority card) :above)
    (grab-keyboard (screen-key-window screen))
    (handler-case (vikix-overview-draw)
      (error (e)
        (vikix-overview-close)
        (message "The overview couldn't be drawn (~a): the list instead." e)
        (run-commands "vikix-go-to-window")))))

;; The mouse on the card: a click on a box goes to its window, the wheel
;; moves the frame, a click anywhere else closes the card. StumpWM's click
;; hook runs for every button it hears of, the card's among them.
(defun vikix-overview-click (screen code x y)
  (declare (ignore screen x y))
  (when *vikix-overview*
    (handler-case
        (let* ((state *vikix-overview*)
               (card (getf state :card)))
          (multiple-value-bind (px py) (xlib:query-pointer card)
            (if (not (and (< -1 px (xlib:drawable-width card)) (< -1 py (xlib:drawable-height card))))
                (vikix-overview-close)
                (let* ((px (- px (getf state :ox 0)))
                       (py (- py (getf state :oy 0)))
                       (inside (lambda (b)
                                 (and (<= (getf b :x) px (+ (getf b :x) (getf b :w)))
                                      (<= (getf b :y) py (+ (getf b :y) (getf b :h))))))
                       (boxes (vikix-overview-boxes (getf state :plan)))
                       ;; A hidden window's line lies in its frame's box: it first.
                       (box (or (find-if (lambda (b) (and (eq (getf b :kind) :hidden) (funcall inside b))) boxes)
                                (find-if inside boxes))))
                  (cond ((member code '(4 5))
                         (vikix-overview-move (if (= code 4) :left :right)))
                        ((and box (= code 1))
                         (vikix-overview-go (getf box :window))))))))
      (error () (vikix-overview-close)))))

(add-hook *click-hook* 'vikix-overview-click)

;; The desktop changed under the card (a window came or went, another
;; workspace): the card would show what isn't so.
(defun vikix-overview-stale (&rest ignore)
  (declare (ignore ignore))
  (when *vikix-overview*
    (vikix-overview-close)))

(add-hook *new-window-hook* 'vikix-overview-stale)
(add-hook *destroy-window-hook* 'vikix-overview-stale)
(add-hook *focus-group-hook* 'vikix-overview-stale)

;; A desktop running since before 0.71.149 has the strip's own overview's
;; hooks still (it was in viri.lisp): let go at the reload.
(remove-hook *click-hook* 'viri-overview-click)
(remove-hook *new-window-hook* 'viri-overview-stale)
(remove-hook *destroy-window-hook* 'viri-overview-stale)
(remove-hook *focus-group-hook* 'viri-overview-stale)

(defcommand vikix-overview () ()
  "Every workspace drawn small on a card, each window a box: the arrows
move a frame, Enter goes to the window in it. Again closes it."
  (cond (*vikix-overview* (vikix-overview-close))
        ((notany #'group-windows (vikix-overview-groups (current-screen)))
         (message "No windows to show."))
        (t (vikix-overview-open (current-screen)))))

(defcommand vikix-expose () ()
  "This workspace's windows in a real grid, to pick one (StumpWM's expose):
it moves them, and Super+u puts them back. Tiles only."
  (cond ((viri-group-p)
         (message "A strip keeps its order: Super+o shows it, and every workspace, small."))
        (t (run-commands "expose"))))
