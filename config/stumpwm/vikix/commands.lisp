;;;; commands.lisp — Vikix's own StumpWM commands.
;;;;
;;;; A command (defcommand) is a function you can bind to a key or run
;;;; by name with the prefix key followed by ";".

(in-package :stumpwm)

(defparameter *vikix-terminal* "alacritty"
  "The terminal Vikix opens. Change it in user.lisp.")

(defun vikix-in-terminal (shell-command)
  "Run SHELL-COMMAND in a new terminal that waits for Enter before closing.
SHELL-COMMAND is wrapped in single quotes, so it must not contain one."
  (run-shell-command
   (format nil "~a -e sh -c '~a; echo; echo Press Enter to close.; read x'"
           *vikix-terminal* shell-command)))

(defcommand vikix-terminal () ()
  "Open a terminal: whichever program *vikix-terminal* names."
  (run-shell-command *vikix-terminal*))

(defcommand vikix-reload () ()
  "Reload the whole configuration (Vikix's files and user.lisp)."
  (loadrc))   ; loadrc prints its own confirmation

(defcommand vikix-theme (name) ((:string "Theme: "))
  "Switch to the theme called NAME everywhere: StumpWM, the terminals,
rofi, notifications and the lock screen (`vikix theme NAME`, which also
saves the choice for the next start)."
  (if (every (lambda (c) (or (alphanumericp c) (find c "-_"))) name)
      (run-shell-command (format nil "vikix theme ~a" (string-downcase name)))
      (message "No theme called ~a" name)))

(defcommand vikix-pick-theme () ()
  "Pick a theme from the list of theme files."
  (vikix-load-themes)
  (let* ((names (loop for (name nil) on *vikix-themes* by #'cddr
                      collect (string-downcase (symbol-name name))))
         (choice (select-from-menu (current-screen) (sort names #'string<)
                                   (format nil "Theme (now ~(~a~)): " *vikix-theme*))))
    (when choice
      (vikix-theme (if (consp choice) (first choice) choice)))))

(defcommand vikix-update () ()
  "Run `vikix update` in a terminal."
  (vikix-in-terminal "vikix update"))

(defcommand vikix-agent () ()
  "Open Claude Code in a terminal. `vikix agent` snapshots your files
first, so whatever it changes can be undone with `vikix undo`."
  (run-shell-command (format nil "~a -e vikix agent" *vikix-terminal*)))

(defcommand vikix-undo () ()
  "Put your files back as they were one snapshot ago, in a terminal
that shows what happened. Reload afterwards to use the old settings."
  (vikix-in-terminal "vikix undo"))

(defcommand vikix-screens-save (name) ((:string "Save this screen layout as: "))
  "Save the current monitor layout under NAME; autorandr re-applies it when
the same monitors are plugged in again. Use \"default\" for the usual one."
  (run-shell-command (format nil "autorandr --save ~a --force" name))
  (message "Screen layout saved as ~a" name))

(defparameter *vikix-menu*
  '(("Keyboard shortcuts"  vikix-keys)
    ("All commands"        vikix-commands)
    ("What does a key do?" describe-key)
    ("Update Vikix"      vikix-update)
    ("AI agent (Claude Code)" vikix-agent)
    ("JupyterLab (in ~/dev)" (run-shell-command "vikix-jupyter"))
    ("Programming docs (offline)" (run-shell-command "xdg-open ~/dev/index.html"))
    ("Zeal: search the docs" (run-shell-command "zeal"))
    ("Clipboard history"   (run-shell-command "env CM_LAUNCHER=rofi clipmenu"))
    ("Notifications: the last one again" (run-shell-command "dunstctl history-pop"))
    ("Notifications: earlier ones" (run-shell-command "vikix-notifications"))
    ("Notifications: close all" (run-shell-command "dunstctl close-all"))
    ("Do not disturb on/off" vikix-quiet)
    ("Keep awake on/off"   vikix-awake)
    ("Find a window, any workspace" global-windowlist)
    ("Gaps around windows on/off" toggle-gaps)
    ("Screenshot: an area, to a file" (run-shell-command "vikix-screenshot file"))
    ("Undo: my files back one snapshot" vikix-undo)
    ("Reload config"       vikix-reload)
    ("Theme"               vikix-pick-theme)
    ("Apply keyboard settings" (run-shell-command "vikix-keyboard"))
    ("Network (nmtui)"     (run-shell-command
                            (format nil "~a -e nmtui" *vikix-terminal*)))
    ("Bluetooth"           (run-shell-command "blueman-manager"))
    ("Screens: arrange (arandr)" (run-shell-command "arandr"))
    ("Screens: save this layout" vikix-screens-save)
    ("Sound (pavucontrol)" (run-shell-command "pavucontrol"))
    ("Lock"                (run-shell-command "vikix-lock"))
    ;; Through elogind, so no sudo. xss-lock locks the screen before a suspend.
    ("Suspend"             (run-shell-command "loginctl suspend"))
    ("Log out"             quit)
    ("Reboot"              (run-shell-command "loginctl reboot"))
    ("Power off"           (run-shell-command "loginctl poweroff")))
  "Each entry: a label, then what to do — a command name, or a Lisp form.")

(defcommand vikix-menu () ()
  "Pick from the Vikix menu."
  (let ((choice (select-from-menu (current-screen) *vikix-menu* "Vikix: ")))
    (when choice
      (let ((action (second choice)))
        (if (symbolp action)
            (run-commands (string-downcase (symbol-name action)))
            (eval action))))))

;;; Volume and network, for the bar (modeline.lisp). Each is read into a
;;; variable by a timer rather than on every redraw, because reading it
;;; runs a program and the window manager waits while it does.

(defun vikix-shell-line (command)
  "The output of COMMAND without its trailing newline, with ^ doubled so
the mode line shows it as it is. \"\" on any error. Never signals: it runs
from a timer, where an error would reach the top level of the window
manager."
  (handler-case
      (let ((out (string-trim '(#\Space #\Newline)
                              (run-shell-command (format nil "~a 2>/dev/null" command) t))))
        (with-output-to-string (s)
          (loop for c across out
                do (write-char c s)
                   (when (char= c #\^) (write-char c s)))))
    (error () "")))

(defvar *vikix-volume* ""
  "The volume as pamixer puts it (\"40%\" or \"muted\"), or \"\" when
there is no sound server to ask.")

(defvar *vikix-net* ""
  "The network link as bin/vikix-net puts it (\"VID 62%\", \"wired\",
\"offline\"), or \"\" when NetworkManager isn't running.")

(defun vikix-volume-refresh ()
  "Read the volume into *vikix-volume*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "pamixer --get-volume-human")))
    (unless (string= new *vikix-volume*)
      (setf *vikix-volume* new)
      (update-all-mode-lines))))

(defun vikix-net-refresh ()
  "Read the network link into *vikix-net*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-net")))
    (unless (string= new *vikix-net*)
      (setf *vikix-net* new)
      (update-all-mode-lines))))

(defvar *vikix-updates* ""
  "What `vikix update` would bring, for the bar: \"updates 12\", \"updates
12 + Vikix\", \"Vikix update\", or \"\" when there is nothing (or it
couldn't be checked).")

(defparameter *vikix-updates-file*
  (merge-pathnames ".local/state/vikix/updates" (user-homedir-pathname))
  "Where bin/vikix-updates saves its counts: \"PACKAGES COMMITS\".")

(defun vikix-updates-text (packages commits)
  "The bar's words for PACKAGES and COMMITS (numbers, or NIL when unknown)."
  (let ((p (and packages (plusp packages)))
        (c (and commits (plusp commits))))
    (cond ((and p c) (format nil "updates ~d + Vikix" packages))
          (p (format nil "updates ~d" packages))
          (c "Vikix update")
          (t ""))))

(defun vikix-updates-refresh ()
  "Read bin/vikix-updates' file into *vikix-updates*; redraw the bar if it
changed. Reading a small file is cheap, so this runs with the others."
  (let* ((line (ignore-errors
                (with-open-file (in *vikix-updates-file*) (read-line in nil ""))))
         (words (and line (split-string line " ")))
         (new (vikix-updates-text
               (ignore-errors (parse-integer (first words)))
               (ignore-errors (parse-integer (second words))))))
    (unless (string= new *vikix-updates*)
      (setf *vikix-updates* new)
      (update-all-mode-lines))))

;;; Keep awake (bin/vikix-idle), shown in the bar.

(defparameter *vikix-awake-file*
  (merge-pathnames ".local/state/vikix/awake" (user-homedir-pathname))
  "Present while keep awake is on; vikix-idle makes and removes it.")

(defvar *vikix-awake* nil
  "True while keep awake is on: no lock, no dark screen, no suspend.")

(defun vikix-awake-refresh ()
  "Read keep awake into *vikix-awake*; redraw the bar if it changed."
  (let ((new (and (probe-file *vikix-awake-file*) t)))
    (unless (eq new *vikix-awake*)
      (setf *vikix-awake* new)
      (update-all-mode-lines))))

(defcommand vikix-awake () ()
  "Keep awake, on or off: while on, the screen doesn't lock or go dark and
the computer doesn't suspend by itself (the bar says awake). For a film or
a talk. Every login starts with it off."
  (run-shell-command "vikix-idle awake toggle" t)
  (vikix-awake-refresh)
  (message (if *vikix-awake*
               "Keep awake: on, until you switch it off"
               "Keep awake: off")))

;;; Notifications (dunst): do not disturb, shown in the bar.

(defvar *vikix-quiet* ""
  "\"\" while notifications show; while they are paused (do not disturb),
\"quiet\", or \"quiet 3\" with three waiting.")

(defun vikix-quiet-refresh ()
  "Read dunst's pause into *vikix-quiet*; redraw the bar if it changed."
  (let ((new (if (string= (vikix-shell-line "dunstctl is-paused") "true")
                 (let ((waiting (vikix-shell-line "dunstctl count waiting")))
                   (if (member waiting '("" "0") :test #'string=)
                       "quiet"
                       (format nil "quiet ~a" waiting)))
                 "")))
    (unless (string= new *vikix-quiet*)
      (setf *vikix-quiet* new)
      (update-all-mode-lines))))

(defcommand vikix-quiet () ()
  "Do not disturb, on or off. While it is on, notifications wait (the bar
says quiet, and how many are waiting); switching it off shows them."
  (run-shell-command "dunstctl set-paused toggle" t)
  (vikix-quiet-refresh)
  (message (if (string= *vikix-quiet* "")
               "Notifications on"
               "Do not disturb: notifications wait until you switch it off")))

(defcommand vikix-volume (change) ((:string "Volume (up, down, mute, mic): "))
  "Change the volume with vikix-osd, which shows a bar for it, then show
the new level in the mode line."
  (run-shell-command (format nil "vikix-osd volume ~a" change))
  ;; vikix-osd runs in the background; read the level once it has finished.
  ;; A ratio, not 0.5: StumpWM's timers want rationals.
  (run-with-timer 1/2 nil #'vikix-volume-refresh))
