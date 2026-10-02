;;;; vikix.lisp — Vikix's part of Nyxt's config: Nyxt in the desktop's colours.
;;;;
;;;; Linked to ~/.local/share/vikix/nyxt/vikix.lisp; your
;;;; ~/.config/nyxt/config.lisp loads it (the starter Vikix copies there
;;;; does), so `vikix update` changes this file and never yours.
;;;;
;;;; The colours are the palette `vikix theme' writes for every program,
;;;; ~/.config/vikix/theme/palette (bg=#rrggbb lines). Nyxt reads it as it
;;;; starts, and `vikix theme NAME' asks a running Nyxt to read it again,
;;;; over Nyxt's socket ($XDG_RUNTIME_DIR/nyxt/nyxt.socket, yours alone):
;;;;   nyxt --remote --quit --eval '(nyxt-user::vikix-theme-apply)'
;;;; That needs remote execution, which is switched on here.
;;;;
;;;; To keep Nyxt's own colours, take the (load ...) line out of your
;;;; config.lisp; to change one, set it there after the load.

(in-package #:nyxt-user)

(defvar *vikix-palette-file*
  (merge-pathnames "vikix/theme/palette" (uiop:xdg-config-home))
  "The colours `vikix theme' writes.")

(defun vikix-colour-p (value)
  "Whether VALUE is a #rrggbb colour: nothing else from the file is used."
  (and (= (length value) 7)
       (char= (char value 0) #\#)
       (every (lambda (c) (digit-char-p c 16)) (subseq value 1))))

(defun vikix-palette (&optional (file *vikix-palette-file*))
  "The palette as an alist of (\"bg\" . \"#rrggbb\"); nil without the file."
  (with-open-file (in file :if-does-not-exist nil)
    (when in
      (loop for line = (read-line in nil)
            while line
            for = = (position #\= line)
            for key = (and = (string-trim " " (subseq line 0 =)))
            for value = (and = (string-trim " " (subseq line (1+ =))))
            when (and key (plusp (length key)) (char/= (char key 0) #\#)
                      (vikix-colour-p value))
              collect (cons key value)))))

(defun vikix-make-theme (palette)
  "A Nyxt theme from PALETTE, or nil when it lacks bg or fg. Nyxt works out
the lighter and darker variants, and the text on each colour, itself."
  (flet ((c (key &optional default)
           (or (cdr (assoc key palette :test #'string=)) default)))
    (let ((bg (c "bg")) (fg (c "fg")))
      (when (and bg fg)
        (make-instance 'theme:theme
                       :background-color bg
                       ;; Set, not worked out: Nyxt's own guess at the
                       ;; "more contrasting" shade of a dark background is
                       ;; near white, and it's what the current tab's label
                       ;; sits on, under light text.
                       :background-color+ bg
                       :background-color- (c "sel" bg)
                       :text-color fg
                       :text-color- (c "subtle" fg)
                       :text-color+ fg
                       ;; Text on colours too close to fg: the background.
                       :contrast-text-color bg
                       ;; The status bar and the prompt's frame.
                       :primary-color (c "dim" fg)
                       :secondary-color (c "sel" bg)
                       ;; The selected suggestion. Nyxt draws its text in
                       ;; the plain text colour whatever this is, so it's
                       ;; the palette's selection, made for text on it.
                       :action-color (c "sel" bg)
                       :highlight-color (c "color5" (c "accent" fg))
                       :success-color (c "color2" fg)
                       :warning-color (c "alert" fg)
                       :codeblock-color (c "sel" bg))))))

(defun vikix-fresh-style (object &optional (slot-name "STYLE"))
  "Compute OBJECT's style slot (SLOT-NAME, a slot of Nyxt's) again, from
the theme now in use: Nyxt computes it once, when the object is made."
  (let* ((name (find-symbol slot-name :nyxt))
         (slot (and name (find name (closer-mop:class-slots (class-of object))
                               :key #'closer-mop:slot-definition-name)))
         (init (and slot (closer-mop:slot-definition-initfunction slot))))
    (when init
      (setf (slot-value object name) (funcall init)))))

(defun vikix-theme-apply ()
  "Read the palette again and repaint the running Nyxt: the status bars
and the message line now; new buffers and prompts follow by themselves. Returns the theme, or
nil when the palette isn't usable (Nyxt is then left as it was)."
  (let ((theme (vikix-make-theme (vikix-palette))))
    (when (and theme *browser*)
      (setf (theme *browser*) theme)
      (dolist (window (window-list))
        ;; The line under the status bar, where messages show.
        (vikix-fresh-style window "MESSAGE-BUFFER-STYLE")
        (when (status-buffer window)
          (vikix-fresh-style (status-buffer window))
          (nyxt::print-status window))))
    theme))

;; As Nyxt starts. :after, so a customize-instance of your own (Nyxt's
;; auto-config writes one) still runs, and this comes after it.
(defmethod customize-instance :after ((browser browser) &key)
  (let ((theme (vikix-make-theme (vikix-palette))))
    (when theme (setf (theme browser) theme))))

;; So that `vikix theme' can reach a running Nyxt.
(define-configuration browser
  ((remote-execution-p t)))
