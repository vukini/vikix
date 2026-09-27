;;;; modeline.lisp — the bar along the top of the screen.
;;;;
;;;; The format string is read left to right:
;;;;   %J   workspaces in use, the current one in [brackets]
;;;;   %W   the current workspace's windows, the focused one in the accent colour
;;;;   ^>   everything after this goes on the right
;;;;   %R   rec: the screen is being recorded (vikix-record)
;;;;   %K   awake: keep awake is on (no lock, dark screen or suspend)
;;;;   %Q   quiet: notifications paused (do not disturb), and how many wait
;;;;   %U   updates waiting (bin/vikix-updates checks every 6 hours)
;;;;   %A   backup 9d: the last backup is older than the reminder's days
;;;;   %O   network: Wi-Fi name and signal, wired, or offline
;;;;   %V   volume (only when there is a sound server)
;;;;   %E   battery: "bat 84%", "+" while charging; nothing when full on the charger
;;;;   %d   date and time
;;;;
;;;; Colour carries one meaning each: alert for something watching you
;;;; (rec), accent for something to act on (updates, backup), subtle for a mode you
;;;; switched on yourself (awake, quiet).

(in-package :stumpwm)

(defun vikix-battery-file (name)
  "The first line of sysfs file NAME of the first battery, or nil."
  (let ((battery (first (directory #p"/sys/class/power_supply/BAT*/"))))
    (and battery
         (ignore-errors
          (with-open-file (in (merge-pathnames name battery))
            (string-trim '(#\Space #\Newline) (read-line in nil "")))))))

(defun vikix-mode-line-battery (ml)
  "The battery's charge, labelled like vol; nothing without a battery, or
when it is full on the charger, since that isn't news."
  (declare (ignore ml))
  (let ((level (vikix-battery-file "capacity"))
        (status (vikix-battery-file "status")))
    (cond ((or (null level) (string= level "")) "")
          ((member status '("Full" "Not charging") :test #'string=) "")
          (t (format nil "bat ~a%~a  " level
                     (if (string= status "Charging") "+" ""))))))

(defun vikix-mode-line-groups (ml)
  "The workspaces that have windows, plus the current one, in order.
All nine always exist, so listing them all would say nothing."
  (let ((current (mode-line-current-group ml)))
    (format nil "~{~a~^ ~}"
            (loop for group in (sort-groups (mode-line-screen ml))
                  when (or (eq group current) (group-windows group))
                    collect (if (eq group current)
                                (format nil "[~a]" (group-name group))
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

(defun vikix-mode-line-backup (ml)
  "The backup reminder, from *vikix-backup* (commands.lisp), in the accent
colour; nothing while backups are recent, or not set up."
  (declare (ignore ml))
  (if (string= *vikix-backup* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
              (vikix-colour :accent) *vikix-backup*)))

(defun vikix-mode-line-quiet (ml)
  "\"quiet\" while notifications are paused, from *vikix-quiet* (commands.lisp)."
  (declare (ignore ml))
  (if (string= *vikix-quiet* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  " (vikix-colour :subtle) *vikix-quiet*)))

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
      (format nil "^(:push)^(:fg \"~a\")awake^(:pop)  " (vikix-colour :subtle))
      ""))

;; %J, %V, %O, %U, %A, %Q, %K, %R and %E are free: neither StumpWM nor its
;; contrib modules use them.
(add-screen-mode-line-formatter #\J 'vikix-mode-line-groups)
(add-screen-mode-line-formatter #\V 'vikix-mode-line-volume)
(add-screen-mode-line-formatter #\O 'vikix-mode-line-net)
(add-screen-mode-line-formatter #\U 'vikix-mode-line-updates)
(add-screen-mode-line-formatter #\A 'vikix-mode-line-backup)
(add-screen-mode-line-formatter #\Q 'vikix-mode-line-quiet)
(add-screen-mode-line-formatter #\K 'vikix-mode-line-awake)
(add-screen-mode-line-formatter #\R 'vikix-mode-line-recording)
(add-screen-mode-line-formatter #\E 'vikix-mode-line-battery)

(defun vikix-bar-refresh ()
  (vikix-volume-refresh)
  (vikix-net-refresh)
  (vikix-updates-refresh)
  (vikix-backup-refresh)
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
      ;; The window's number and title. StumpWM's default adds * + - marks,
      ;; which say again what the accent colour already shows.
      *window-format*        "%n %30t"
      *screen-mode-line-format* "%J  %W^>%R%K%Q%U%A%O%V%E%d")

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
