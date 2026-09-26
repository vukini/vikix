;;;; modeline.lisp — the bar along the top of the screen.
;;;;
;;;; The format string is read left to right:
;;;;   %J   workspaces in use, the current one in bold
;;;;   %W   the current workspace's windows
;;;;   ^>   everything after this goes on the right
;;;;   %B   battery (only if the contrib module loaded)
;;;;   %d   date and time

(in-package :stumpwm)

(defvar *vikix-battery*
  ;; Only on machines that have a battery, and only if the module loads.
  (and (directory #p"/sys/class/power_supply/BAT*")
       (handler-case (progn (load-module "battery-portable") t)
         (error () nil)))
  "True when this machine has a battery and the contrib module loaded.")

(defun vikix-mode-line-groups (ml)
  "The workspaces that have windows, plus the current one, in order.
All nine always exist, so listing them all would say nothing."
  (let ((current (mode-line-current-group ml)))
    (format nil "~{~a~^ ~}"
            (loop for group in (sort-groups (mode-line-screen ml))
                  when (or (eq group current) (group-windows group))
                    collect (if (eq group current)
                                (format nil "^B[~a]^b" (group-name group))
                                (group-name group))))))

;; %J is free: StumpWM's own formatters don't use it.
(add-screen-mode-line-formatter #\J 'vikix-mode-line-groups)

(setf *mode-line-timeout*    10          ; redraw every 10 seconds
      *mode-line-position*   :top
      *mode-line-pad-x*      8
      *mode-line-pad-y*      4
      *time-modeline-string* "%a %d %b  %H:%M"
      *screen-mode-line-format*
      (format nil "%J  %W^>~a  %d" (if *vikix-battery* "%B " "")))

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
