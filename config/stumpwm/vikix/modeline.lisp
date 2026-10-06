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
;;;;   %G   mem 91%: memory is low, or nearly full (bin/vikix-memory watches); left 5:
;;;;        programs nobody uses have piled up (vikix memory clean)
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
;;;; (rec) or about to stop you (mem, nearly full), accent for something to act on
;;;; (updates, backup, usb, dbx off or !, mem when low, left), subtle
;;;; for a mode you switched on yourself (awake, win, ai, quiet), or work under way
;;;; (dbx syncing).
;;;;
;;;; Every field is an area of the bar with a name (vikix-ml-what), so
;;;; Super+Alt+? can say which one the pointer is on (what.lisp).

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
          (t (vikix-ml-what "battery"
                            (format nil "bat ~a%~a  " level
                                    (if (string= status "Charging") "+" "")))))))

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
        ;; Wi-Fi: the picker, which scans first; a cable or nothing: nmtui.
        (:net (when (member button '(1 3))
                (if (and (stringp *vikix-net*) (string= *vikix-net* "wifi" :end1 (min 4 (length *vikix-net*))))
                    (run-shell-command "vikix-wifi")
                    (run-shell-command (format nil "~a -e nmtui" *vikix-terminal*)))))
        (:bt (when (member button '(1 3))
               (run-shell-command "blueman-manager")))
        (:memory (when (member button '(1 3))
                   (vikix-in-terminal "vikix memory"))))
    (error (e) (message "The bar: ~a" e))))

(register-ml-on-click-id :vikix-ml-click 'vikix-ml-click)

(defun vikix-ml-what (kind text)
  "TEXT as the bar's field KIND (\"battery\"): an area Super+Alt+? knows by
that name, and which a click explains (what.lisp). Nothing stays nothing.
For the fields that do nothing else when clicked; volume, the network,
Bluetooth and memory keep their own click, and what.lisp knows their names."
  (if (string= text "")
      ""
      (vikix-ml-clickable :vikix-ml-what kind text)))

(defun vikix-ml-what-click (button kind &rest rest)
  "A click on a field that has no click of its own: what is this? Never
signals, as vikix-ml-click."
  (declare (ignore rest))
  (ignore-errors
   (when (and (member button '(1 3)) (fboundp 'vikix-what-show))
     (funcall 'vikix-what-show (list kind)))))

(register-ml-on-click-id :vikix-ml-what 'vikix-ml-what-click)
;; When the bar is full, the windows' titles run on under the fields on
;; the right, and StumpWM's dispatcher takes the first area that holds the
;; click: a click on volume focused a window. Here the narrowest one wins,
;; which is the field drawn on top.
(defun vikix-ml-area-at (ml x y)
  "The bar's area that holds X, Y (the bar's own coordinates), the narrowest
when several do: (XBEG XEND YBEG YEND ID ARGS), or nil."
  (let ((best nil))
    (loop for area in (mode-line-on-click-bounds ml)
          for (xbeg xend ybeg yend) = area
          when (and (< xbeg x xend) (< ybeg y yend)
                    (or (null best) (< (- xend xbeg) (- (second best) (first best)))))
            do (setf best area))
    best))

(defun vikix-ml-click-dispatcher (ml code x y)
  "StumpWM's mode-line-click-dispatcher, with the narrowest area winning."
  (let ((best (vikix-ml-area-at ml x y)))
    (when best
      (let ((fn (assoc (fifth best) *mode-line-on-click-functions*)))
        (when fn (apply (cdr fn) code (sixth best)))))))

(remove-hook *mode-line-click-hook* 'mode-line-click-dispatcher)
(add-hook *mode-line-click-hook* 'vikix-ml-click-dispatcher)

(defun vikix-mode-line-groups (ml)
  "The workspaces that have windows, plus the current one, in order.
All nine always exist, so listing them all would say nothing. A hidden one
(\".drawer\", where the drawer's windows wait) is never listed."
  (let ((current (mode-line-current-group ml)))
    (format nil "~{~a~^ ~}"
            (loop for group in (non-hidden-groups (sort-groups (mode-line-screen ml)))
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
  (if (or (string= *vikix-net* "") (and (fboundp (quote vikix-tray-shows-p)) (vikix-tray-shows-p "nm-applet")))
      ""
      (vikix-ml-clickable :vikix-ml-click :net (format nil "~a  " *vikix-net*))))

(defun vikix-mode-line-bt (ml)
  "Bluetooth, from *vikix-bt* (commands.lisp); nothing when it's off or absent."
  (declare (ignore ml))
  (if (or (string= *vikix-bt* "") (and (fboundp (quote vikix-tray-shows-p)) (vikix-tray-shows-p "blueman-applet")))
      ""
      (vikix-ml-clickable :vikix-ml-click :bt (format nil "~a  " *vikix-bt*))))

(defun vikix-mode-line-dropbox (ml)
  "Dropbox, from *vikix-dropbox* (commands.lisp): in the accent colour when
it's off or can't sync, something to do; quieter while it syncs."
  (declare (ignore ml))
  (if (string= *vikix-dropbox* "")
      ""
      (vikix-ml-what "dropbox"
                     (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
                             (vikix-colour (if (member *vikix-dropbox* '("dbx off" "dbx !") :test #'string=)
                                               :accent
                                               :subtle))
                             *vikix-dropbox*))))

(defun vikix-mode-line-usb (ml)
  "\"usb\" in the accent colour while a drive is mounted: something to do
(eject it) before pulling it out. From *vikix-usb* (commands.lisp)."
  (declare (ignore ml))
  (if (string= *vikix-usb* "")
      ""
      (vikix-ml-what "drive" (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  " (vikix-colour :accent) *vikix-usb*))))

(defun vikix-mode-line-updates (ml)
  "Waiting updates, from *vikix-updates* (commands.lisp), in the accent
colour; nothing when there are none."
  (declare (ignore ml))
  (if (string= *vikix-updates* "")
      ""
      (vikix-ml-what "updates" (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
                                       (vikix-colour :accent) *vikix-updates*))))

(defun vikix-mode-line-backup (ml)
  "The backup reminder, from *vikix-backup* (commands.lisp), in the accent
colour; nothing while backups are recent, or not set up."
  (declare (ignore ml))
  (if (string= *vikix-backup* "")
      ""
      (vikix-ml-what "backup" (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  "
                                      (vikix-colour :accent) *vikix-backup*))))

(defun vikix-mode-line-quiet (ml)
  "\"quiet\" while notifications are paused, from *vikix-quiet* (commands.lisp)."
  (declare (ignore ml))
  (if (string= *vikix-quiet* "")
      ""
      (vikix-ml-what "quiet" (format nil "^(:push)^(:fg \"~a\")~a^(:pop)  " (vikix-colour :subtle) *vikix-quiet*))))

(defun vikix-mode-line-recording (ml)
  "\"rec\" while the screen is recorded, \"mic\" while dictation listens,
from *vikix-recording* and *vikix-dictating* (commands.lisp)."
  (declare (ignore ml))
  (format nil "~@[~a~]~@[~a~]"
          (and *vikix-recording*
               (vikix-ml-what "recording" (format nil "^(:push)^(:fg \"~a\")rec^(:pop)  " (vikix-colour :alert))))
          (and *vikix-dictating*
               (vikix-ml-what "dictation" (format nil "^(:push)^(:fg \"~a\")mic^(:pop)  " (vikix-colour :alert))))))

(defun vikix-mode-line-awake (ml)
  "\"awake\" while keep awake is on, from *vikix-awake* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-awake*
      (vikix-ml-what "awake" (format nil "^(:push)^(:fg \"~a\")awake^(:pop)  " (vikix-colour :subtle)))
      ""))

(defun vikix-mode-line-windows (ml)
  "\"win\" while the Windows VM runs, from *vikix-windows* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-windows*
      (vikix-ml-what "windows-vm" (format nil "^(:push)^(:fg \"~a\")win^(:pop)  " (vikix-colour :subtle)))
      ""))

(defun vikix-mode-line-memory (ml)
  "\"mem 91%\" while memory is low (accent) or nearly full (alert), and
\"left 5\" once left-over programs have piled up, from *vikix-memory*
(commands.lisp). A click opens vikix memory in a terminal."
  (declare (ignore ml))
  (destructuring-bind (&optional level (used 0) (left 0) told) *vikix-memory*
    (let ((text (format nil "~@[mem ~d%~]~:[~; ~]~@[left ~d~]"
                        (and level used) (and level told (plusp left)) (and told (plusp left) left))))
      (if (string= text "")
          ""
          (format nil "^(:push)^(:fg \"~a\")~a^(:pop)"
                  (vikix-colour (if (eq level :critical) :alert :accent))
                  (vikix-ml-clickable :vikix-ml-click :memory (concatenate 'string text "  ")))))))

(defun vikix-mode-line-ai (ml)
  "\"ai\" while a local model is loaded, from *vikix-ai* (commands.lisp)."
  (declare (ignore ml))
  (if *vikix-ai*
      (vikix-ml-what "ai" (format nil "^(:push)^(:fg \"~a\")ai^(:pop)  " (vikix-colour :subtle)))
      ""))

;; %J, %V, %O, %T, %U, %A, %D, %Q, %K, %X, %Y, %G, %R, %E, %Z and %P (plugins.lisp) are free: neither StumpWM nor its
;; contrib modules use them. %d is StumpWM's, taken over below to give the clock its area.
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
(add-screen-mode-line-formatter #\G 'vikix-mode-line-memory)
(add-screen-mode-line-formatter #\R 'vikix-mode-line-recording)
(add-screen-mode-line-formatter #\E 'vikix-mode-line-battery)

(defun vikix-mode-line-clock (ml)
  "The date and time, as StumpWM's own %d says them (*time-modeline-string*)."
  (vikix-ml-what "clock" (fmt-modeline-time ml)))
(add-screen-mode-line-formatter #\d 'vikix-mode-line-clock)

;;; The tray (vikix tray on): off unless switched on. StumpWM has none of
;;; its own, so the network and Bluetooth applets (nm-applet,
;;; blueman-applet) had nowhere to show; StumpWM's stumptray module puts
;;; their icons at the bar's right end. The module and its one library
;;; (xembed, from Quicklisp) load only when it's switched on. The bar
;;; leaves the icons room (%S): spaces as wide as the tray.

(defparameter *vikix-tray-file*
  (merge-pathnames ".config/vikix/tray" (user-homedir-pathname))
  "vikix tray's settings: on or off, and the applets it starts.")

(defun vikix-tray-settings ()
  "(ON-P APPLETS APPLETS-SET-P) from *vikix-tray-file*: a line `on`, and
`applets = ...` (which may name none)."
  (let ((on nil) (applets '()) (set nil))
    (with-open-file (in *vikix-tray-file* :if-does-not-exist nil)
      (when in
        (loop for line = (read-line in nil) while line
              for text = (string-trim " " (subseq line 0 (or (position #\# line) (length line))))
              do (cond ((string-equal text "on") (setf on t))
                       ((and (> (length text) 7) (string-equal (subseq text 0 7) "applets"))
                        (let ((eq (position #\= text)))
                          (when eq
                            (setf set t
                                  applets (remove "" (split-string (subseq text (1+ eq)) " ")
                                                  :test #'string=)))))))))
    (list on applets set)))

(defvar *vikix-tray-applets* '()
  "The applets the tray started, while it's on: their icons say what the
bar's own fields would (nm-applet the network, blueman-applet Bluetooth),
so those fields step aside.")

(defvar *vikix-tray-missing* '()
  "The tray's applets that aren't running, as the bar's thread last found
them. An applet can stop (nm-applet has, mid-session): its icon goes, and
with the field stepped aside the bar said nothing of the network at all.")
(defvar *vikix-tray-restarted* (make-hash-table :test 'equal)
  "When each applet was last started again (a universal time).")
(defparameter *vikix-tray-restart-after* 300
  "An applet that has stopped is started again, but not twice within this
many seconds: one that stops at once isn't started in a loop.")

(defvar *vikix-tray-wanted* nil
  "True while the tray is switched on (vikix tray on): it should be in the
bar whenever there is a bar.")
(defvar *vikix-tray-icons* '()
  "The icons in the tray now, by their windows' classes (\"Nm-applet\"),
as the main thread last found them.")
(defparameter *vikix-tray-icon-classes*
  '(("nm-applet" "nm-applet") ("blueman-applet" "blueman-tray" "blueman-applet"))
  "An applet, and the classes its icon's window may have, in any case.")

(defun vikix-tray-shows-p (applet)
  "Whether APPLET's icon is in the tray: the bar's own field steps aside
only while the icon is there to say the same. Not merely \"the tray is on
and starts it\": an applet stops, and a tray has been left behind in a bar
that was rebuilt, and each time the bar said nothing of the network."
  (and (member applet *vikix-tray-applets* :test #'string=)
       (some (lambda (class)
               (member class *vikix-tray-icons* :test #'string-equal))
             (or (rest (assoc applet *vikix-tray-icon-classes* :test #'string=)) (list applet)))
       t))

(defun vikix-tray-applet-name-p (applet)
  "A program's name and nothing else: it goes into a shell command."
  (and (plusp (length applet))
       (every (lambda (c) (or (alphanumericp c) (find c "-_."))) applet)))

(defun vikix-tray-refresh ()
  "One of the bar's rounds (its own thread): which of the tray's applets
aren't running; each is started again, once in five minutes at most. Then
the main thread is asked to tend the tray (vikix-tray-tend): this thread
never talks to the X server."
  (let ((missing (loop for a in *vikix-tray-applets*
                       when (and (vikix-tray-applet-name-p a)
                                 (string= (vikix-shell-line (format nil "pgrep -x ~a >/dev/null || echo gone" a))
                                          "gone"))
                         collect a)))
    (unless (equal missing *vikix-tray-missing*)
      (setf *vikix-tray-missing* missing)
      (vikix-bar-redraw))
    (dolist (a missing)
      (let ((now (get-universal-time)))
        (when (> (- now (gethash a *vikix-tray-restarted* 0)) *vikix-tray-restart-after*)
          (setf (gethash a *vikix-tray-restarted*) now)
          (ignore-errors (run-shell-command (format nil "pgrep -x ~a >/dev/null || exec ~a" a a))))))
    (when (and (or *vikix-tray-wanted* (vikix-tray-object))
               (or (in-main-thread-p) *request-channel*))
      (ignore-errors (call-in-main-thread 'vikix-tray-tend)))))

(defun vikix-tray-object ()
  "The screen's tray, when it's on."
  (let ((pkg (find-package :stumptray)))
    (and pkg (funcall (find-symbol "CURRENT-TRAY" pkg)))))

;;; The tray is a window inside the bar's. StumpWM makes the bar anew when
;;; it is hidden and shown (Super+Ctrl+h) and when a screen comes or goes,
;;; and the tray's window goes with the old one: stumptray then still has
;;; a tray, of windows that aren't there, and the applets have nowhere to
;;; put their icons. So: the tray is taken down properly as its bar goes,
;;; put up again in the new one, and the bar's rounds look for one left
;;; behind all the same.

(defun vikix-tray-bar ()
  "The bar the tray belongs in: the first head's, or nil while it's hidden."
  (ignore-errors (funcall (find-symbol "SCREEN-MODE-LINE" :stumptray) (current-screen))))

(defun vikix-tray-stale-p ()
  "True when there is a tray, but not in the bar that is showing. Lisp
only, no request to the X server: the bar's thread asks this."
  (let ((tray (vikix-tray-object)))
    (and tray
         (not (eq (vikix-tray-bar) (funcall (find-symbol "TRAY-MODE-LINE" :stumptray) tray)))
         t)))

(defun vikix-tray-forget ()
  "Let go of a tray whose windows went with its bar: nothing of it is
asked of the X server, where it no longer is."
  (let ((tray (vikix-tray-object)))
    (when tray
      (let ((handler (funcall (find-symbol "TRAY-EVENT-PROCESSING-FN" :stumptray) tray)))
        (when handler (remove-hook *event-processing-hook* handler)))
      (setf (gethash (current-screen) (symbol-value (find-symbol "*SCREEN-TRAY-TABLE*" :stumptray))) nil
            *vikix-tray-icons* '()))))

(defun vikix-tray-note-icons ()
  "In the main thread: which icons are in the tray, by class."
  (let ((classes (ignore-errors
                  (let ((tray (vikix-tray-object)))
                    (and tray (not (vikix-tray-stale-p))
                         (loop for socket in (funcall (find-symbol "TRAY-VICONS" :stumptray) tray)
                               for class = (ignore-errors (funcall (find-symbol "CLIENT-WM-CLASS" :stumptray) socket))
                               when (stringp class) collect class))))))
    (unless (equal classes *vikix-tray-icons*)
      (setf *vikix-tray-icons* classes)
      (vikix-bar-redraw))))

(defun vikix-tray-tend ()
  "In the main thread: the tray where it should be, and its icons noted.
One left behind in a bar that is gone is let go, and a tray that is
switched on is put into the bar that is showing. Never an error."
  (ignore-errors
   (let ((left-behind (vikix-tray-stale-p)))
     (when left-behind
       (vikix-tray-forget))
     (when (and *vikix-tray-wanted* (null (vikix-tray-object)) (vikix-tray-bar))
       (vikix-tray-start)
       (when left-behind
         (vikix-tray-restart-applets)))))
  (ignore-errors (vikix-tray-note-icons))
  nil)

(defun vikix-tray-restart-applets ()
  "After a tray was left behind: its applets' icons went with the old
bar's window, and an applet doesn't make itself another (nm-applet ends
some time later, blueman-applet stays, without one). So each is ended and
started again, into the new tray."
  (dolist (a *vikix-tray-applets*)
    (when (vikix-tray-applet-name-p a)
      (setf (gethash a *vikix-tray-restarted*) (get-universal-time))
      (ignore-errors (run-shell-command (format nil "pkill -x ~a; sleep 1; exec ~a" a a))))))

(defun vikix-tray-bar-gone (mode-line)
  "On *destroy-mode-line-hook*, before the bar's window goes: the tray in
it is taken down while its windows are still there."
  (ignore-errors
   (let ((tray (vikix-tray-object)))
     (when (and tray (eq mode-line (funcall (find-symbol "TRAY-MODE-LINE" :stumptray) tray)))
       (funcall (find-symbol "DESTROY-TRAY" :stumptray) tray)
       (setf *vikix-tray-icons* '())))))

(defun vikix-tray-bar-new (mode-line)
  "On *new-mode-line-hook*: a second later, once the bar is in place, the
tray into it. (A whole second: a timer's delay is never a fraction.)"
  (declare (ignore mode-line))
  (ignore-errors
   (when *vikix-tray-wanted*
     (run-with-timer 1 nil 'vikix-tray-tend))))

(remove-hook *destroy-mode-line-hook* 'vikix-tray-bar-gone)
(add-hook *destroy-mode-line-hook* 'vikix-tray-bar-gone)
(remove-hook *new-mode-line-hook* 'vikix-tray-bar-new)
(add-hook *new-mode-line-hook* 'vikix-tray-bar-new)

(defun vikix-tray-start ()
  "The tray on, in the bar, and its applets started (those not running)."
  (handler-case
      (progn
        (unless (find-package :stumptray)
          (funcall (find-symbol "QUICKLOAD" :ql) :xembed :silent t)
          (load-module "stumptray")
          ;; The module takes %T for a placeholder of its own as it loads;
          ;; %T is the bar's Bluetooth field, and %S the tray's room.
          (add-screen-mode-line-formatter #\T 'vikix-mode-line-bt))
        (setf *vikix-tray-wanted* t)
        (when (vikix-tray-stale-p)
          (vikix-tray-forget))
        (unless (vikix-tray-object)
          (run-commands "stumptray"))
        (setf *vikix-tray-applets* (second (vikix-tray-settings))
              *vikix-tray-missing* '())
        (dolist (a *vikix-tray-applets*)
          (when (vikix-tray-applet-name-p a)
            ;; Noted, so the bar's round doesn't start it a second time while it comes up.
            (setf (gethash a *vikix-tray-restarted*) (get-universal-time))
            (run-shell-command (format nil "pgrep -x ~a >/dev/null || exec ~a" a a))))
        t)
    (error (e)
      (message "^1Vikix: the tray didn't start:^n ~a" e)
      nil)))

(defun vikix-tray-stop ()
  "The tray off; its applets stopped, and the bar's own fields back."
  (setf *vikix-tray-applets* '()
        *vikix-tray-missing* '()
        *vikix-tray-icons* '()
        *vikix-tray-wanted* nil)
  (ignore-errors
   (cond ((vikix-tray-stale-p) (vikix-tray-forget))
         ((vikix-tray-object) (run-commands "stumptray"))))
  (dolist (a (second (vikix-tray-settings)))
    (when (vikix-tray-applet-name-p a)
      (run-shell-command (format nil "pkill -x ~a" a)))))

(defun vikix-mode-line-tray (ml)
  "Room for the tray's icons at the bar's end: spaces as wide as it is."
  (declare (ignore ml))
  (let ((tray (ignore-errors (vikix-tray-object))))
    (if (null tray)
        ""
        (let* ((width (or (ignore-errors (funcall (find-symbol "TRAY-WIDTH" :stumptray) tray)) 0))
               (space (max 1 (or (ignore-errors
                                  (ceiling (text-line-width (screen-font (current-screen)) "          ") 10))
                                 7))))
          (make-string (+ 1 (ceiling width space)) :initial-element #\Space)))))

(add-screen-mode-line-formatter #\S 'vikix-mode-line-tray)

(defun vikix-tray-set (on)
  "The tray on (ON true) or off, remembered for the next login."
  (let ((settings (vikix-tray-settings)))
    ;; The choice, kept in the file; the applets line as it was.
    (ensure-directories-exist *vikix-tray-file*)
    (with-open-file (out *vikix-tray-file* :direction :output :if-exists :supersede)
      (format out "# vikix tray's settings (yours; vikix tray on/off rewrites the first line).~%~a~%"
              (if on "on" "off"))
      (format out "# The programs started with the tray, whose icons show in it:~%applets = ~{~a~^ ~}~%"
              ;; The network's and Bluetooth's, unless you've named your own (or none).
              (if (third settings) (second settings) '("nm-applet" "blueman-applet"))))
    (if on (vikix-tray-start) (vikix-tray-stop))
    (message "Tray ~a" (if on "on" "off"))))

(defcommand vikix-tray () ()
  "The tray in the bar, for applets' icons (network, Bluetooth): on if it's
off, off if it's on, remembered for the next login."
  (vikix-tray-set (null (vikix-tray-object))))

(defcommand vikix-tray-on () ()
  "The tray in the bar, on (vikix tray on)."
  (vikix-tray-set t))

(defcommand vikix-tray-off () ()
  "The tray in the bar, off (vikix tray off)."
  (vikix-tray-set nil))

(defvar *vikix-workarea-last* nil
  "What _NET_WORKAREA was last set to, so it's written only when it changes.")

(defun vikix-workarea ()
  "The screen less the bar at its top, as (x y width height): what programs
may cover. The bar hidden, the whole screen."
  (let* ((screen (current-screen))
         (ml (ignore-errors (head-mode-line (current-head))))
         (bar (if (and ml (eq *mode-line-position* :top) (not (eq (mode-line-mode ml) :hidden)))
                  (mode-line-height ml)
                  0)))
    (list 0 bar (screen-width screen) (- (screen-height screen) bar))))

(defun vikix-publish-workarea ()
  "Say where the bar is, as other desktops do (_NET_WORKAREA, once per
workspace): FreeRDP reads it for Windows programs (/workarea), so Windows
sees a screen that starts below the bar and a maximized program's own title
bar isn't under ours. StumpWM doesn't set it."
  (ignore-errors
    (let* ((screen (current-screen))
           (area (vikix-workarea))
           (n (max 1 (length (screen-groups screen))))
           (key (cons n area)))
      (unless (equal key *vikix-workarea-last*)
        (setf *vikix-workarea-last* key)
        (xlib:change-property (screen-root screen) :_NET_WORKAREA
                              (loop repeat n append area) :cardinal 32)
        (xlib:display-force-output *display*)))))

(defcommand vikix-bar () ()
  "The bar on/off, on the screen in front."
  (toggle-mode-line (current-screen) (current-head))
  (vikix-publish-workarea))

(defparameter *vikix-bar-refreshers*
  '(vikix-volume-refresh vikix-net-refresh vikix-bt-refresh vikix-dropbox-refresh
    vikix-updates-refresh vikix-backup-refresh vikix-usb-refresh vikix-quiet-refresh
    vikix-awake-refresh vikix-windows-refresh vikix-ai-refresh vikix-memory-refresh
    vikix-record-refresh vikix-tray-refresh)
  "What a round of the bar reads, in order. Each asks a small program or
reads a file, and keeps what it found in a variable of its own.")

(defun vikix-bar-refresh ()
  "A whole round, here and now, in this thread. From the main thread it
holds the desktop while the programs answer: the bar's own thread is what
makes the rounds (vikix-bar-kick asks it for one)."
  (when (in-main-thread-p) (vikix-publish-workarea))
  (dolist (refresh *vikix-bar-refreshers*)
    (ignore-errors (funcall refresh))))

(defvar *vikix-bar-thread* nil)
(defvar *vikix-bar-wake* (sb-thread:make-semaphore :name "vikix-bar")
  "Signalled to have a round now, not at the next ten seconds.")
(defvar *vikix-bar-rounds* 0 "How many rounds the bar's thread has made.")

(defun vikix-bar-round ()
  "One round by the bar's thread: every refresher, then one redraw by the
main thread if anything changed."
  (let ((*vikix-bar-in-worker* t)
        (*vikix-bar-changed* nil))
    (dolist (refresh *vikix-bar-refreshers*)
      (ignore-errors (funcall refresh)))
    (incf *vikix-bar-rounds*)
    (when (and *vikix-bar-changed* *request-channel*)
      (ignore-errors (call-in-main-thread 'update-all-mode-lines)))))

(defun vikix-bar-loop ()
  ;; The round by name each time, so a reload's new one is used.
  (loop (ignore-errors (funcall 'vikix-bar-round))
        (sb-thread:wait-on-semaphore *vikix-bar-wake* :timeout 10)))

(defun vikix-bar-kick ()
  "Ask the bar's thread for a round now."
  (sb-thread:signal-semaphore *vikix-bar-wake*))

;; The volume keys update the bar at once (vikix-volume); the rounds catch
;; everything else: pavucontrol, a new Wi-Fi network, a cable. The timer
;; left in the main thread only tells programs where the bar is
;; (_NET_WORKAREA), which costs nothing. Cancel the old timer first, so
;; reloading the config doesn't stack them.
(defvar *vikix-bar-timer* nil)
(when *vikix-bar-timer*
  (cancel-timer *vikix-bar-timer*))
(setf *vikix-bar-timer* (run-with-timer 10 10 'vikix-publish-workarea))
(if (and (boundp '*screen-list*) *screen-list*)
    (progn
      (unless (and *vikix-bar-thread* (sb-thread:thread-alive-p *vikix-bar-thread*))
        (setf *vikix-bar-thread* (sb-thread:make-thread 'vikix-bar-loop :name "vikix-bar")))
      (vikix-bar-kick))
    (vikix-bar-refresh))

(setf *mode-line-timeout*    10          ; redraw every 10 seconds
      *mode-line-position*   :top
      *mode-line-pad-x*      8
      *mode-line-pad-y*      4
      *time-modeline-string* "%a %d %b  %H:%M"
      ;; The window's number and title. StumpWM's default adds * + - marks,
      ;; which say again what the accent colour already shows.
      *window-format*        "%n %30t"
      *screen-mode-line-format* "%J  %W^>%P%R%K%X%Y%G%Q%U%A%D%Z%O%T%V%E%d%S")

;; Turn the bar on for every screen and head (monitor).
(dolist (screen *screen-list*)
  (dolist (head (screen-heads screen))
    (enable-mode-line screen head t)))
(setf *vikix-workarea-last* nil)
(vikix-publish-workarea)

;; The tray, when you switched it on (vikix tray on): after the bar it sits in.
;; Already there (a reload), it's left as it is, its applets noted again.
(setf *vikix-tray-wanted* (and (first (vikix-tray-settings)) t))
(if (and (vikix-tray-object) (not (vikix-tray-stale-p)))
    (progn (setf *vikix-tray-applets* (second (vikix-tray-settings)))
           (ignore-errors (vikix-tray-note-icons)))
    (when *vikix-tray-wanted*
      (vikix-tray-start)))
