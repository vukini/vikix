;;;; modeline.lisp — the bar along the top of the screen.
;;;;
;;;; The format string is read left to right:
;;;;   %J   workspaces in use, the current one in bold
;;;;   %W   the current workspace's windows
;;;;   ^>   everything after this goes on the right
;;;;   %R   rec: the screen is being recorded (vikix-record)
;;;;   %K   awake: keep awake is on (no lock, dark screen or suspend)
;;;;   %Q   quiet: notifications paused (do not disturb), and how many wait
;;;;   %U   updates waiting (bin/vikix-updates checks every 6 hours)
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

(defun vikix-mode-line-updates (ml)
  "Waiting updates, from *vikix-updates* (commands.lisp), in the accent
colour; nothing when there are none."
  (declare (ignore ml))
  (if (string= *vikix-updates* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
              (vikix-colour :accent) *vikix-updates*)))

(defun vikix-mode-line-quiet (ml)
  "\"quiet\" while notifications are paused, from *vikix-quiet* (commands.lisp)."
  (declare (ignore ml))
  (if (string= *vikix-quiet* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  " (vikix-colour :alert) *vikix-quiet*)))

(defun vikix-mode-line-recording (ml)
  "\"rec\" while the screen is recorded, from *vikix-recording* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-recording*
      (format nil "^(:push)^(:fg \"~a\")rec^(:pop)  " (vikix-colour :alert))
      ""))

(defun vikix-mode-line-awake (ml)
  "\"awake\" while keep awake is on, from *vikix-awake* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-awake*
      (format nil "^(:push)^(:fg \"~a\")awake^(:pop)  " (vikix-colour :accent))
      ""))

;; %J, %V, %O, %U, %Q, %K and %R are free: neither StumpWM nor its contrib modules use them.
(add-screen-mode-line-formatter #\J 'vikix-mode-line-groups)
(add-screen-mode-line-formatter #\V 'vikix-mode-line-volume)
(add-screen-mode-line-formatter #\O 'vikix-mode-line-net)
(add-screen-mode-line-formatter #\U 'vikix-mode-line-updates)
(add-screen-mode-line-formatter #\Q 'vikix-mode-line-quiet)
(add-screen-mode-line-formatter #\K 'vikix-mode-line-awake)
(add-screen-mode-line-formatter #\R 'vikix-mode-line-recording)

(defun vikix-bar-refresh ()
  (vikix-volume-refresh)
  (vikix-net-refresh)
  (vikix-updates-refresh)
  (vikix-quiet-refresh)
  (vikix-awake-refresh)
  (vikix-record-refresh))

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
      (format nil "%J  %W^>%R%K%Q%U%O%V~a  %d" (if *vikix-battery* "%B " "")))

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
