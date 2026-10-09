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
  '(:vikix-dark (:bg "#1e1e2e" :fg "#cdd6f4" :subtle "#a6adc8" :dim "#585b70"
          :accent "#89b4fa" :alert "#f38ba8" :sel "#45475a"))
  "Named palettes: NAME (a keyword) then its colours, :bg :fg :dim :accent
:alert and more. Filled from the theme files; this one is only a fallback.")

(defvar *vikix-theme* :vikix-dark
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

(defparameter *vikix-theme-old-names*
  '((:void . :vikix-dark) (:paper . :vikix-light) (:contrast . :contrast-dark)
    (:gruvbox . :gruvbox-dark) (:nord . :nord-dark) (:tokyo-night . :tokyo-night-dark))
  "The built-in themes' names before 0.72.4, when every theme's name got its
-light or -dark. A saved choice or a form of yours may still say one; it
stands for the new name while no theme file of yours has the old one.")

(defun vikix-theme-name (name)
  "The theme NAME (a keyword) names: itself, or what an old name is now."
  (let ((new (cdr (assoc name *vikix-theme-old-names*))))
    (if (and new (not (getf *vikix-themes* name))) new name)))

(defun vikix-saved-theme ()
  "The theme `vikix theme` saved, as a keyword; :vikix-dark when there is none."
  (let ((name (ignore-errors
               (with-open-file (in *vikix-saved-theme-file*)
                 (string-trim '(#\Space #\Tab #\Newline) (read-line in nil ""))))))
    (if (and name (plusp (length name)))
        (vikix-theme-name (intern (string-upcase name) :keyword))
        :vikix-dark)))

(defun vikix-colour (key)
  "The colour KEY (e.g. :accent) in the current theme."
  (getf (getf *vikix-themes* *vikix-theme*) key))

(defun vikix-apply-theme (name)
  "Make NAME the current theme and repaint StumpWM with it. An old name
(:void, :paper ...) is the new one's."
  (unless (getf *vikix-themes* name)
    (vikix-load-themes))                 ; a theme file added since
  (setf name (vikix-theme-name name))
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
        *mode-line-border-color*     (vikix-colour :bg)
        ;; The focused window's title in the accent colour. StumpWM's
        ;; default swaps fg and bg, a bright block that glares at night.
        *mode-line-highlight-template*
        (format nil "^(:push)^(:fg \"~a\")~~A^(:pop)" (vikix-colour :accent))
        ;; The keys which-key-mode lists after Ctrl+t (help.lisp turns it on).
        *which-key-format*
        (format nil "^(:fg \"~a\")~~5a^n ~~a" (vikix-colour :accent)))
  ;; A mode line reads those three variables once, when it is created.
  ;; Bars that already exist have to be told to look again.
  (dolist (screen *screen-list*)
    (dolist (head (screen-heads screen))
      (when (head-mode-line head)
        (if (fboundp 'refresh-colors-for-modeline)
            (refresh-colors-for-modeline screen head)
            (progn (enable-mode-line screen head nil)   ; older StumpWM: off and on
                   (enable-mode-line screen head t))))))
  ;; The title bars (windows.lisp) take the new colours.
  (when (fboundp 'vikix-titlebars-relayout)
    (funcall 'vikix-titlebars-relayout))
  name)

;; Shape, not colour.
(setf *normal-border-width*    2
      *maxsize-border-width*   2
      *transient-border-width* 2
      *window-border-style*    :thin
      *message-window-gravity* :center
      *input-window-gravity*   :center
      *startup-message*        nil)

;; The font: Iosevka, like the terminal, rofi and dunst.
;;
;; StumpWM itself draws only X bitmap fonts (9x15 unless told otherwise),
;; which look nothing like the rest and show "?" for anything beyond
;; Latin-1. The contrib module ttf-fonts draws TrueType fonts through
;; clx-truetype, which 30-lisp builds into the StumpWM image. It reads
;; single .ttf files, so bin/vikix-font makes one: Iosevka Regular taken
;; out of Void's collection, or Noto Sans Mono until Iosevka is installed.
;; If any of that is missing, the bitmap font stays and nothing else breaks.
(defparameter *vikix-font-size* 11
  "Point size of the bar, menus and messages.")

(defun vikix-set-font ()
  "Draw StumpWM's text in the font bin/vikix-font provides."
  (let ((file (string-trim '(#\Space #\Newline)
                           (run-shell-command "vikix-font" t))))
    (unless (probe-file file)
      (error "vikix-font gave no font file"))
    (load-module "ttf-fonts")
    ;; The xft package only exists once the module is loaded, so its
    ;; symbols are looked up now rather than read with the file.
    (flet ((xft (name) (find-symbol name :xft)))
      ;; Only our folder: caching every font on the system takes minutes
      ;; and would stop the desktop meanwhile.
      (setf (symbol-value (xft "*FONT-DIRS*"))
            (list (directory-namestring file)))
      (funcall (xft "CACHE-FONTS"))
      (let ((family (first (funcall (xft "GET-FONT-FAMILIES")))))
        (unless family
          (error "~a is not a font clx-truetype can read" file))
        (set-font (make-instance (xft "FONT")
                                 :family family :subfamily "Regular"
                                 :size *vikix-font-size* :antialias t))
        ;; The message window measures a message with its drawing context's
        ;; font, which set-font leaves as it was (9x15) until the first
        ;; message has been drawn: the first menu after a start came out
        ;; with 15 pixels a row where Iosevka has 19, its last rows cut off.
        (dolist (screen *screen-list*)
          (ignore-errors (reset-color-context (screen-message-cc screen))))
        family))))

(handler-case (vikix-set-font)
  (error (e) (message "^1Vikix: bar font not loaded, keeping 9x15:^n ~a" e)))

;; Menus (the key help, the Vikix menu, the window lists) scroll instead of
;; running off the screen: at most as many rows as fit on the smallest
;; monitor in this font, leaving room for the prompt and the border.
;; StumpWM's default is no limit at all.
(defun vikix-fit-menus (&rest ignore)
  (declare (ignore ignore))
  (let ((line (max 1 (font-height (screen-font (current-screen)))))
        (height (reduce #'min (mapcar #'head-height (screen-heads (current-screen))))))
    (setf *menu-maximum-height* (max 5 (- (floor (* height 9/10) line) 2)))))

(vikix-fit-menus)
(add-hook *new-head-hook* 'vikix-fit-menus)   ; a monitor plugged in

;; The saved theme, at startup and on every reload. (A theme applied from
;; user.lisp still wins: it runs after this.)
(vikix-load-themes)
(vikix-apply-theme (let ((saved (vikix-saved-theme)))
                     (if (getf *vikix-themes* saved) saved :vikix-dark)))
