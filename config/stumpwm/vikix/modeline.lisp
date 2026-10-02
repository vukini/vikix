;;;; modeline.lisp — the bar along the top of the screen.
;;;;
;;;; The format string is read left to right:
;;;;   %J   workspaces in use, the current one in [brackets]
;;;;   %W   the current workspace's windows, the focused one in the accent colour
;;;;   ^>   everything after this goes on the right
;;;;   %P   the plugins' few words (plugins.lisp; vikix plugin add)
;;;;   %R   rec: the screen is being recorded (vikix-record); mic: dictation listens
;;;;   %K   awake: keep awake is on (no lock, dark screen or suspend)
;;;;   %X   win: the Windows VM is running (vikix windows); it uses memory and battery
;;;;   %Y   ai: a local AI model is loaded in memory (vikix ai); it unloads after 5 idle minutes
;;;;   %Q   quiet: notifications paused (do not disturb), and how many wait
;;;;   %U   updates waiting (bin/vikix-updates checks every 6 hours)
;;;;   %A   backup 9d: the last backup is older than the reminder's days
;;;;   %D   usb: a drive is mounted; eject it (Super+Ctrl+e) before pulling it out
;;;;   %Z   Dropbox: files left to sync, paused, off, or a problem (bin/vikix-dropbox)
;;;;   %O   network: Wi-Fi name and signal, wired, or offline
;;;;   %T   Bluetooth: bt when on, and the connected device (bin/vikix-bt)
;;;;   %V   volume (only when there is a sound server)
;;;;   %E   battery: "bat 84%", "+" while charging; nothing when full on the charger
;;;;   %d   date and time
;;;;
;;;; Colour carries one meaning each: alert for something watching you
;;;; (rec), accent for something to act on (updates, backup, usb, dbx off or !), subtle
;;;; for a mode you switched on yourself (awake, win, ai, quiet), or work under way
;;;; (dbx syncing).

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

;;; The mouse, for when a key doesn't come to mind: a workspace's number
;;; in the bar goes there, and volume, the network and Bluetooth open their
;;; settings (the wheel on volume turns it up and down). StumpWM draws the
;;; ^(:on-click ...) parts as areas of the bar and calls the function
;;; registered for the id with the button: 1 left, 2 middle, 3 right, 4
;;; and 5 the wheel.
(defun vikix-ml-clickable (id arg text)
  "TEXT in the bar, calling the function registered for ID with ARG when
clicked. The caller doubles any ^ in TEXT already, as the fields do."
  (format nil "^(:on-click ~s ~s)~a^(:on-click-end)" id arg text))

(defun vikix-ml-click (button what &rest rest)
  "A click on the volume, network or Bluetooth field. Never signals: it
runs from the event loop, where an error would reach the top level."
  (declare (ignore rest))
  (handler-case
      (ecase what
        (:volume (case button
                   (4 (run-commands "vikix-volume up"))
                   (5 (run-commands "vikix-volume down"))
                   (2 (run-commands "vikix-volume mute"))
                   ((1 3) (run-shell-command "pavucontrol"))))
        (:net (when (member button '(1 3))
                (run-shell-command (format nil "~a -e nmtui" *vikix-terminal*))))
        (:bt (when (member button '(1 3))
               (run-shell-command "blueman-manager"))))
    (error (e) (message "The bar: ~a" e))))

(register-ml-on-click-id :vikix-ml-click 'vikix-ml-click)
;; When the bar is full, the windows' titles run on under the fields on
;; the right, and StumpWM's dispatcher takes the first area that holds the
;; click: a click on volume focused a window. Here the narrowest one wins,
;; which is the field drawn on top.
(defun vikix-ml-click-dispatcher (ml code x y)
  "StumpWM's mode-line-click-dispatcher, with the narrowest area winning."
  (let ((best nil))
    (loop for area in (mode-line-on-click-bounds ml)
          for (xbeg xend ybeg yend) = area
          when (and (< xbeg x xend) (< ybeg y yend)
                    (or (null best) (< (- xend xbeg) (- (second best) (first best)))))
            do (setf best area))
    (when best
      (let ((fn (assoc (fifth best) *mode-line-on-click-functions*)))
        (when fn (apply (cdr fn) code (sixth best)))))))

(remove-hook *mode-line-click-hook* 'mode-line-click-dispatcher)
(add-hook *mode-line-click-hook* 'vikix-ml-click-dispatcher)

(defun vikix-mode-line-groups (ml)
  "The workspaces that have windows, plus the current one, in order.
All nine always exist, so listing them all would say nothing."
  (let ((current (mode-line-current-group ml)))
    (format nil "~{~a~^ ~}"
            (loop for group in (sort-groups (mode-line-screen ml))
                  when (or (eq group current) (group-windows group))
                    collect (vikix-ml-clickable
                             :ml-on-click-switch-to-group (group-name group)
                             (if (eq group current)
                                 (format nil "[~a]" (group-name group))
                                 (group-name group)))))))

(defun vikix-mode-line-volume (ml)
  "The volume, from *vikix-volume* (commands.lisp); nothing without sound."
  (declare (ignore ml))
  (if (string= *vikix-volume* "")
      ""
      (vikix-ml-clickable :vikix-ml-click :volume (format nil "vol ~a  " *vikix-volume*))))

(defun vikix-mode-line-net (ml)
  "The network link, from *vikix-net* (commands.lisp); nothing without
NetworkManager."
  (declare (ignore ml))
  (if (string= *vikix-net* "")
      ""
      (vikix-ml-clickable :vikix-ml-click :net (format nil "~a  " *vikix-net*))))

(defun vikix-mode-line-bt (ml)
  "Bluetooth, from *vikix-bt* (commands.lisp); nothing when it's off or absent."
  (declare (ignore ml))
  (if (string= *vikix-bt* "")
      ""
      (vikix-ml-clickable :vikix-ml-click :bt (format nil "~a  " *vikix-bt*))))

(defun vikix-mode-line-dropbox (ml)
  "Dropbox, from *vikix-dropbox* (commands.lisp): in the accent colour when
it's off or can't sync, something to do; quieter while it syncs."
  (declare (ignore ml))
  (if (string= *vikix-dropbox* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
              (vikix-colour (if (member *vikix-dropbox* '("dbx off" "dbx !") :test #'string=)
                                :accent
                                :subtle))
              *vikix-dropbox*)))

(defun vikix-mode-line-usb (ml)
  "\"usb\" in the accent colour while a drive is mounted: something to do
(eject it) before pulling it out. From *vikix-usb* (commands.lisp)."
  (declare (ignore ml))
  (if (string= *vikix-usb* "")
      ""
      (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  " (vikix-colour :accent) *vikix-usb*)))

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
  "\"rec\" while the screen is recorded, \"mic\" while dictation listens,
from *vikix-recording* and *vikix-dictating* (commands.lisp)."
  (declare (ignore ml))
  (format nil "~@[~a~]~@[~a~]"
          (and *vikix-recording*
               (format nil "^(:push)^(:fg \"~a\")rec^(:pop)  " (vikix-colour :alert)))
          (and *vikix-dictating*
               (format nil "^(:push)^(:fg \"~a\")mic^(:pop)  " (vikix-colour :alert)))))

(defun vikix-mode-line-awake (ml)
  "\"awake\" while keep awake is on, from *vikix-awake* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-awake*
      (format nil "^(:push)^(:fg \"~a\")awake^(:pop)  " (vikix-colour :subtle))
      ""))

(defun vikix-mode-line-windows (ml)
  "\"win\" while the Windows VM runs, from *vikix-windows* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-windows*
      (format nil "^(:push)^(:fg \"~a\")win^(:pop)  " (vikix-colour :subtle))
      ""))

(defun vikix-mode-line-ai (ml)
  "\"ai\" while a local model is loaded, from *vikix-ai* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-ai*
      (format nil "^(:push)^(:fg \"~a\")ai^(:pop)  " (vikix-colour :subtle))
      ""))

;; %J, %V, %O, %T, %U, %A, %D, %Q, %K, %X, %Y, %R, %E, %Z and %P (plugins.lisp) are free: neither StumpWM nor its
;; contrib modules use them.
(add-screen-mode-line-formatter #\J 'vikix-mode-line-groups)
(add-screen-mode-line-formatter #\V 'vikix-mode-line-volume)
(add-screen-mode-line-formatter #\O 'vikix-mode-line-net)
(add-screen-mode-line-formatter #\T 'vikix-mode-line-bt)
(add-screen-mode-line-formatter #\U 'vikix-mode-line-updates)
(add-screen-mode-line-formatter #\A 'vikix-mode-line-backup)
(add-screen-mode-line-formatter #\D 'vikix-mode-line-usb)
(add-screen-mode-line-formatter #\Z 'vikix-mode-line-dropbox)
(add-screen-mode-line-formatter #\Q 'vikix-mode-line-quiet)
(add-screen-mode-line-formatter #\K 'vikix-mode-line-awake)
(add-screen-mode-line-formatter #\X 'vikix-mode-line-windows)
(add-screen-mode-line-formatter #\Y 'vikix-mode-line-ai)
(add-screen-mode-line-formatter #\R 'vikix-mode-line-recording)
(add-screen-mode-line-formatter #\E 'vikix-mode-line-battery)

(defun vikix-bar-refresh ()
  (vikix-volume-refresh)
  (vikix-net-refresh)
  (vikix-bt-refresh)
  (vikix-dropbox-refresh)
  (vikix-updates-refresh)
  (vikix-backup-refresh)
  (vikix-usb-refresh)
  (vikix-quiet-refresh)
  (vikix-awake-refresh)
  (vikix-windows-refresh)
  (vikix-ai-refresh)
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
      *screen-mode-line-format* "%J  %W^>%P%R%K%X%Y%Q%U%A%D%Z%O%T%V%E%d")

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
