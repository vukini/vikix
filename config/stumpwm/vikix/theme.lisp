;;;; theme.lisp — every colour Vikix uses, from one palette.
;;;;
;;;; The palettes are the theme files: themes/NAME.theme in the checkout,
;;;; and your own in ~/.config/vikix/themes/. The same files give the
;;;; terminal, rofi, dunst and the lock screen their colours, through
;;;; `vikix theme NAME`, which also saves the choice. StumpWM starts with
;;;; the saved theme, so a choice survives a restart. `vikix-apply-theme`
;;;; pushes one palette into StumpWM's settings.

(in-package :stumpwm)

(defparameter *vikix-themes*
  '(:void (:bg "#1e1e2e" :fg "#cdd6f4" :dim "#585b70" :accent "#89b4fa" :alert "#f38ba8"))
  "Named palettes: NAME (a keyword) then its colours, :bg :fg :dim :accent
:alert and more. Filled from the theme files; this one is only a fallback.")

(defvar *vikix-theme* :void
  "The theme currently applied.")

(defparameter *vikix-saved-theme-file*
  (merge-pathnames ".config/vikix/theme/current" (user-homedir-pathname))
  "Where `vikix theme` saves the name of the chosen theme.")

(defun vikix-theme-dirs ()
  "Where theme files are: Vikix's, then yours, so yours win."
  (list ;; ~/.stumpwm.d/vikix is a link to config/stumpwm/vikix in the
        ;; checkout; the checkout's themes/ is three folders up from there.
        (merge-pathnames "../../../themes/" (truename *vikix-dir*))
        (merge-pathnames ".config/vikix/themes/" (user-homedir-pathname))))

(defun vikix-read-theme (file)
  "The palette in theme FILE: each NAME=#rrggbb line, as (:name \"#rrggbb\" ...)."
  (let ((palette '()))
    (with-open-file (in file)
      (loop for line = (read-line in nil)
            while line
            do (let* ((eq (position #\= line))
                      (key (and eq (string-trim '(#\Space #\Tab) (subseq line 0 eq))))
                      (value (and eq (string-left-trim '(#\Space #\Tab) (subseq line (1+ eq))))))
                 (when (and key (plusp (length key)) (char/= (char key 0) #\#)
                            (>= (length value) 7) (char= (char value 0) #\#))
                   (setf (getf palette (intern (string-upcase key) :keyword))
                         (subseq value 0 7))))))
    palette))

(defun vikix-load-themes ()
  "Read every theme file into *vikix-themes*. A broken file is skipped."
  (dolist (dir (vikix-theme-dirs))
    (dolist (file (ignore-errors (directory (merge-pathnames "*.theme" dir))))
      (handler-case
          (let ((palette (vikix-read-theme file)))
            (when (getf palette :bg)
              (setf (getf *vikix-themes* (intern (string-upcase (pathname-name file)) :keyword))
                    palette)))
        (error (e) (message "^1Vikix: theme ~a not read:^n ~a" file e)))))
  *vikix-themes*)

(defun vikix-saved-theme ()
  "The theme `vikix theme` saved, as a keyword; :void when there is none."
  (let ((name (ignore-errors
               (with-open-file (in *vikix-saved-theme-file*)
                 (string-trim '(#\Space #\Tab #\Newline) (read-line in nil ""))))))
    (if (and name (plusp (length name)))
        (intern (string-upcase name) :keyword)
        :void)))

(defun vikix-colour (key)
  "The colour KEY (e.g. :accent) in the current theme."
  (getf (getf *vikix-themes* *vikix-theme*) key))

(defun vikix-apply-theme (name)
  "Make NAME the current theme and repaint StumpWM with it."
  (unless (getf *vikix-themes* name)
    (vikix-load-themes))                 ; a theme file added since
  (unless (getf *vikix-themes* name)
    (error "No Vikix theme called ~s" name))
  (setf *vikix-theme* name)
  ;; Messages and the input prompt.
  (set-fg-color     (vikix-colour :fg))
  (set-bg-color     (vikix-colour :bg))
  (set-border-color (vikix-colour :accent))
  ;; Window borders: bright on the focused window, dim on the rest.
  (set-focus-color   (vikix-colour :accent))
  (set-unfocus-color (vikix-colour :dim))
  ;; The mode line (the bar).
  (setf *mode-line-background-color* (vikix-colour :bg)
        *mode-line-foreground-color* (vikix-colour :fg)
        *mode-line-border-color*     (vikix-colour :bg))
  ;; A mode line reads those three variables once, when it is created.
  ;; Bars that already exist have to be told to look again.
  (dolist (screen *screen-list*)
    (dolist (head (screen-heads screen))
      (when (head-mode-line head)
        (if (fboundp 'refresh-colors-for-modeline)
            (refresh-colors-for-modeline screen head)
            (progn (enable-mode-line screen head nil)   ; older StumpWM: off and on
                   (enable-mode-line screen head t))))))
  name)

;; Shape, not colour.
(setf *normal-border-width*    2
      *maxsize-border-width*   2
      *transient-border-width* 2
      *window-border-style*    :thin
      *message-window-gravity* :center
      *input-window-gravity*   :center
      *startup-message*        nil)

;; The saved theme, at startup and on every reload. (A theme applied from
;; user.lisp still wins: it runs after this.)
(vikix-load-themes)
(vikix-apply-theme (let ((saved (vikix-saved-theme)))
                     (if (getf *vikix-themes* saved) saved :void)))
