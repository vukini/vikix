;;;; modeline.lisp — the bar along the top of the screen.
;;;;
;;;; The format string is read left to right:
;;;;   %J   workspaces in use, the current one in bold
;;;;   %W   the current workspace's windows
;;;;   ^>   everything after this goes on the right
;;;;   %O   network: Wi-Fi name and signal, wired, or offline
;;;;   %V   volume (only when there is a sound server)
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

(defun vikix-mode-line-volume (ml)
  "The volume, from *vikix-volume* (commands.lisp); nothing without sound."
  (declare (ignore ml))
  (if (string= *vikix-volume* "")
      ""
      (format nil "vol ~a  " *vikix-volume*)))

(defun vikix-mode-line-net (ml)
  "The network link, from *vikix-net* (commands.lisp); nothing without
NetworkManager."
  (declare (ignore ml))
  (if (string= *vikix-net* "")
      ""
      (format nil "~a  " *vikix-net*)))

;; %J, %V and %O are free: neither StumpWM nor its contrib modules use them.
(add-screen-mode-line-formatter #\J 'vikix-mode-line-groups)
(add-screen-mode-line-formatter #\V 'vikix-mode-line-volume)
(add-screen-mode-line-formatter #\O 'vikix-mode-line-net)

(defun vikix-bar-refresh ()
  (vikix-volume-refresh)
  (vikix-net-refresh))

;; The volume keys update the bar at once (vikix-volume); this timer
;; catches everything else: pavucontrol, a new Wi-Fi network, a cable.
;; Cancel the old timer first, so reloading the config doesn't stack them.
(defvar *vikix-bar-timer* nil)
(when *vikix-bar-timer*
  (cancel-timer *vikix-bar-timer*))
(vikix-bar-refresh)
(setf *vikix-bar-timer* (run-with-timer 10 10 #'vikix-bar-refresh))

(setf *mode-line-timeout*    10          ; redraw every 10 seconds
      *mode-line-position*   :top
      *mode-line-pad-x*      8
      *mode-line-pad-y*      4
      *time-modeline-string* "%a %d %b  %H:%M"
      *screen-mode-line-format*
      (format nil "%J  %W^>%O%V~a  %d" (if *vikix-battery* "%B " "")))

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
