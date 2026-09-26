;;;; theme.lisp — every colour Vikix uses, from one palette.
;;;;
;;;; A palette is a property list of named colours. `vikix-apply-theme`
;;;; pushes one palette into StumpWM's settings. A new theme is only a new
;;;; palette: nothing else needs to know the colours.

(in-package :stumpwm)

(defparameter *vikix-themes*
  '(:void  (:bg "#1e1e2e" :fg "#cdd6f4" :dim "#585b70" :accent "#89b4fa" :alert "#f38ba8")
    :paper (:bg "#eff1f5" :fg "#4c4f69" :dim "#9ca0b0" :accent "#1e66f5" :alert "#d20f39"))
  "Named palettes. Keys: :bg :fg :dim :accent :alert.")

(defvar *vikix-theme* :void
  "The theme currently applied.")

(defun vikix-colour (key)
  "The colour KEY (e.g. :accent) in the current theme."
  (getf (getf *vikix-themes* *vikix-theme*) key))

(defun vikix-apply-theme (name)
  "Make NAME the current theme and repaint StumpWM with it."
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

;; On a reload, *vikix-theme* keeps its value (defvar), but a theme that
;; user.lisp added to *vikix-themes* is gone until user.lisp runs again.
;; Use :void until then; user.lisp re-applies its own theme after this.
(vikix-apply-theme (if (getf *vikix-themes* *vikix-theme*) *vikix-theme* :void))
