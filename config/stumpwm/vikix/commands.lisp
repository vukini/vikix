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
  "Open the AI agent in a terminal: Claude Code, or the one chosen with
`vikix agent --default NAME`. `vikix agent` snapshots your files first,
so whatever it changes can be undone with `vikix undo`."
  (run-shell-command (format nil "~a -e vikix agent" *vikix-terminal*)))

(defcommand vikix-welcome () ()
  "The welcome: add software, the keys that matter, a theme, the keyboard
layout, the guide (`vikix welcome`, in a terminal)."
  (run-shell-command (format nil "~a -e vikix welcome" *vikix-terminal*)))

(defcommand vikix-add-software () ()
  "Pick languages, editors, LibreOffice, Windows ... to add (`vikix welcome add`)."
  (run-shell-command (format nil "~a -e vikix welcome add" *vikix-terminal*)))

(defvar *vikix-welcome-checked* nil
  "Whether this StumpWM has looked yet for the first-login welcome; a
reload (loadrc) doesn't look again.")

;; The first login on a new desktop opens the welcome, once: vikix-welcome
;; writes ~/.local/state/vikix/welcome the moment it starts. A few seconds
;; later, so user.lisp (loaded after this file) can name another terminal.
(unless *vikix-welcome-checked*
  (setf *vikix-welcome-checked* t)
  (unless (probe-file (merge-pathnames ".local/state/vikix/welcome" (user-homedir-pathname)))
    (run-with-timer 3 nil (lambda () (vikix-welcome)))))

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
  '(("Welcome: first steps" vikix-welcome)
    ("Add software: languages, editors, office ..." vikix-add-software)
    ("Install a program"   (vikix-in-terminal "vikix pkg add"))
    ("Remove a program"    (vikix-in-terminal "vikix pkg drop"))
    ("Keyboard shortcuts"  vikix-keys)
    ("All commands"        vikix-commands)
    ("What does a key do?" describe-key)
    ("Vikix guide" (run-shell-command
                               (format nil "emacsclient -c -a '' -e '(info \"~~/.local/share/info/vikix.info\")' || ~a -e info -f ~~/.local/share/info/vikix.info"
                                       *vikix-terminal*)))
    ("Update Vikix"      vikix-update)
    ("AI agent"            vikix-agent)
    ("Something's wrong? Ask the agent" (vikix-in-terminal "vikix diagnose"))
    ("A report of what's going on (vikix debug)" (vikix-in-terminal "vikix debug"))
    ("AI on the selected text" (run-shell-command "vikix-ask"))
    ("JupyterLab (in ~/dev)" (run-shell-command "vikix-jupyter") "~/dev/python/.venv/bin/jupyter")
    ("Programming docs (offline)" (run-shell-command "xdg-open ~/dev/index.html") "~/dev/index.html")
    ("Zeal: search the docs" (run-shell-command "zeal") "zeal")
    ("Clipboard history"   (run-shell-command "env CM_LAUNCHER=rofi clipmenu"))
    ("Emoji"               (run-shell-command "vikix-rofi emoji"))
    ("Calculator"          (run-shell-command "vikix-rofi calc"))
    ("Notifications: the last one again" (run-shell-command "dunstctl history-pop"))
    ("Notifications: earlier ones" (run-shell-command "vikix-notifications"))
    ("Notifications: close all" (run-shell-command "dunstctl close-all"))
    ("Do not disturb on/off" vikix-quiet)
    ("Keep awake on/off"   vikix-awake)
    ("Night light on/off"  vikix-nightlight)
    ("Find a window, any workspace" global-windowlist)
    ("Gaps around windows on/off" toggle-gaps)
    ("Screenshot or record the screen" vikix-capture)
    ("Undo: my files back one snapshot" vikix-undo)
    ("Backup now"          (run-shell-command "vikix-backup now --notify"))
    ("Reload config"       vikix-reload)
    ("Theme"               vikix-pick-theme)
    ("Wallpaper"           (run-shell-command "vikix-wallpaper pick"))
    ("Apply keyboard settings" (run-shell-command "vikix-keyboard"))
    ("Network (nmtui)"     (run-shell-command
                            (format nil "~a -e nmtui" *vikix-terminal*)))
    ("Bluetooth"           (run-shell-command "blueman-manager"))
    ("Dropbox"             vikix-dropbox "dropbox")
    ("Printers"            (run-shell-command "system-config-printer") "system-config-printer")
    ("Windows (the VM)"    (run-shell-command
                            (format nil "vikix-windows open || ~a -e sh -c 'vikix windows status; printf \"\\nEnter closes this window. \"; read x'"
                                    *vikix-terminal*))
                           "virt-viewer")
    ("Eject a drive"       (run-shell-command "vikix-drives eject"))
    ("Local AI: talk to a model" (run-shell-command "vikix-local-ai chat --rofi") "~/.local/opt/ollama/bin/ollama")
    ("Local AI: choose a model" (run-shell-command "vikix-local-ai models --rofi") "~/.local/opt/ollama/bin/ollama")
    ("Local AI: unload the model" (run-shell-command "vikix-local-ai stop --notify") "~/.local/opt/ollama/bin/ollama")
    ("Dictation: start, or stop and type it" (run-shell-command "vikix-dictate toggle") "~/.local/opt/whisper.cpp/build/bin/whisper-cli")
    ("Firmware updates"    (run-shell-command
                            (format nil "~a -e sh -c 'vikix firmware update; printf \"\\nEnter closes this window. \"; read x'"
                                    *vikix-terminal*)))
    ("Screens: arrange (arandr)" (run-shell-command "arandr"))
    ("Screens: save this layout" vikix-screens-save)
    ("Sound (pavucontrol)" (run-shell-command "pavucontrol"))
    ("Power: lock, suspend, log out, reboot, power off" vikix-power))
  "Each entry: a label, then what to do — a command name, or a Lisp form —
and, for some, what it needs: a program on PATH, or a file (\"~/...\"). An
entry whose need isn't there is left out of the menu (vikix-menu-entry-here-p):
JupyterLab without the feature python, Printers without printing ...")

(defparameter *vikix-power-menu*
  ;; Lock first: the harmless one is where an Enter pressed by mistake lands.
  '(("Lock"                (run-shell-command "vikix-lock"))
    ;; Through elogind, so no sudo. xss-lock locks the screen before a suspend.
    ("Suspend"             (run-shell-command "loginctl suspend"))
    ("Log out"             quit)
    ;; A running Windows VM shuts down properly first (vikix-windows power
    ;; does nothing, quickly, when there isn't one).
    ("Reboot"              (run-shell-command "vikix-windows power; loginctl reboot"))
    ("Power off"           (run-shell-command "vikix-windows power; loginctl poweroff")))
  "The power menu (Super+Shift+Escape), in the same form as *vikix-menu*.")

(defun vikix-program-p (name)
  "True when a program called NAME is in a folder on PATH."
  (let ((path (or (uiop:getenv "PATH") "")))
    (loop for start = 0 then (1+ end)
          for end = (position #\: path :start start)
          for dir = (subseq path start end)
            thereis (and (plusp (length dir))
                         (probe-file (concatenate 'string dir "/" name)))
          while end)))

(defun vikix-menu-entry-here-p (entry)
  "True unless ENTRY names what it needs (its third element) and that isn't
here: a program on PATH, or a file when it starts with ~/."
  (let ((needs (third entry)))
    (or (not (stringp needs))
        (if (and (> (length needs) 1) (string= (subseq needs 0 2) "~/"))
            (probe-file (merge-pathnames (subseq needs 2) (user-homedir-pathname)))
            (vikix-program-p needs)))))

(defun vikix-run-menu (entries prompt)
  "Pick from ENTRIES, a menu like *vikix-menu*, and do what the choice says.
Entries whose program or file isn't here are left out."
  (let ((choice (select-from-menu (current-screen)
                                  (remove-if-not #'vikix-menu-entry-here-p entries)
                                  prompt)))
    (when choice
      (let ((action (second choice)))
        (if (symbolp action)
            (run-commands (string-downcase (symbol-name action)))
            (eval action))))))

(defcommand vikix-menu () ()
  "Pick from the Vikix menu."
  (vikix-run-menu *vikix-menu* "Vikix: "))

(defcommand vikix-power () ()
  "Lock, suspend, log out, reboot or power off."
  (vikix-run-menu *vikix-power-menu* "Power: "))

(defparameter *vikix-dropbox-menu*
  '(("Status"      (message "Dropbox:~%~a" (vikix-shell-line "timeout 3 dropbox status")))
    ("Open ~/Dropbox" (run-shell-command "xdg-open ~/Dropbox"))
    ;; Started by hand, not by the session: some want it running only
    ;; when they ask. The bar says dbx off meanwhile.
    ("Start"       (progn (run-shell-command "dropbox start") (message "Dropbox is starting")))
    ("Stop"        (progn (run-shell-command "dropbox stop") (message "Dropbox is stopping"))))
  "The Dropbox menu (Super+m, then Dropbox), in the same form as *vikix-menu*.")

(defcommand vikix-dropbox () ()
  "Dropbox: its status, the folder, start or stop it."
  (vikix-run-menu *vikix-dropbox-menu* "Dropbox: "))

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
  "The network link as bin/vikix-net puts it (\"wifi VID\", \"wired\",
\"offline\"), or \"\" when NetworkManager isn't running.")

(defvar *vikix-bt* ""
  "Bluetooth as bin/vikix-bt puts it (\"bt\", \"bt WH-1000XM4 80%\"), or \"\"
when there is none or it's off.")

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

(defvar *vikix-usb* ""
  "\"usb\" while a drive is mounted under /run/media (bin/vikix-drives), or \"\".")

(defun vikix-usb-refresh ()
  "Read whether a drive is mounted into *vikix-usb*, and redraw the bar if
it changed. vikix-drives also calls this when a drive comes or goes."
  (let ((new (vikix-shell-line "vikix-drives bar")))
    (unless (string= new *vikix-usb*)
      (setf *vikix-usb* new)
      (update-all-mode-lines))))

(defun vikix-bt-refresh ()
  "Read Bluetooth into *vikix-bt*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-bt")))
    (unless (string= new *vikix-bt*)
      (setf *vikix-bt* new)
      (update-all-mode-lines))))

(defvar *vikix-dropbox* ""
  "Dropbox as bin/vikix-dropbox puts it (\"dbx ↓1,204\", \"dbx off\"), or \"\"
when it's up to date, not installed, or never set up.")

(defun vikix-dropbox-refresh ()
  "Read Dropbox's state into *vikix-dropbox*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-dropbox")))
    (unless (string= new *vikix-dropbox*)
      (setf *vikix-dropbox* new)
      (update-all-mode-lines))))

(defvar *vikix-updates* ""
  "What `vikix update` would bring, for the bar: \"updates 12\", \"updates
12 + Vikix\", \"Vikix update\", or \"\" when there is nothing (or it
couldn't be checked).")

(defparameter *vikix-updates-file*
  (merge-pathnames ".local/state/vikix/updates" (user-homedir-pathname))
  "Where bin/vikix-updates saves its counts: \"PACKAGES COMMITS FIRMWARE\".")

(defun vikix-updates-text (packages commits &optional firmware)
  "The bar's words for PACKAGES, COMMITS and FIRMWARE (numbers, or NIL when
unknown): \"updates 12 + Vikix + firmware\", or any part of it."
  (let* ((p (and packages (plusp packages)))
         (c (and commits (plusp commits)))
         (f (and firmware (plusp firmware)))
         (text (cond ((and p c) (format nil "updates ~d + Vikix" packages))
                     (p (format nil "updates ~d" packages))
                     (c "Vikix update")
                     (t ""))))
    (cond ((not f) text)
          ((string= text "") "firmware")
          (t (concatenate 'string text " + firmware")))))

(defun vikix-updates-refresh ()
  "Read bin/vikix-updates' file into *vikix-updates*; redraw the bar if it
changed. Reading a small file is cheap, so this runs with the others."
  (let* ((line (ignore-errors
                (with-open-file (in *vikix-updates-file*) (read-line in nil ""))))
         (words (and line (split-string line " ")))
         (new (vikix-updates-text
               (ignore-errors (parse-integer (first words)))
               (ignore-errors (parse-integer (second words)))
               (ignore-errors (parse-integer (third words))))))
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

(defparameter *vikix-windows-pidfile*
  (concatenate 'string
               (or (uiop:getenv "XDG_RUNTIME_DIR")
                   (format nil "/run/user/~a" (sb-posix:getuid)))
               "/libvirt/qemu/run/windows.pid")
  "Present while the Windows VM runs: libvirt (qemu:///session) makes it.")

(defvar *vikix-windows* nil
  "True while the Windows VM (vikix windows) is running.")

(defun vikix-windows-refresh ()
  "Read whether Windows runs into *vikix-windows*; redraw the bar if it changed.
A file test, so no program starts every 10 seconds."
  (let ((new (and (probe-file *vikix-windows-pidfile*) t)))
    (unless (eq new *vikix-windows*)
      (setf *vikix-windows* new)
      (update-all-mode-lines))))

(defparameter *vikix-ai-file*
  (merge-pathnames ".local/state/vikix/ai-loaded" (user-homedir-pathname))
  "Present while a local model is loaded: vikix-local-ai serve writes it.")

(defvar *vikix-ai* nil
  "True while a local AI model (Ollama) is loaded in memory.")

(defun vikix-ai-refresh ()
  "Read whether a local model is loaded; redraw the bar if it changed."
  (let ((new (and (probe-file *vikix-ai-file*) t)))
    (unless (eq new *vikix-ai*)
      (setf *vikix-ai* new)
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

;;; The backup reminder (bin/vikix-backup), shown in the bar.

(defparameter *vikix-backup-file*
  (merge-pathnames ".local/state/vikix/backup" (user-homedir-pathname))
  "\"LAST DAYS\": when the last backup ran (Unix time, 0 for none yet) and
after how many days to remind. vikix-backup writes it; no file, no backups
set up.")

(defvar *vikix-backup* ""
  "The bar's reminder: \"backup 9d\", \"backup\" (set up, none yet), or \"\".")

(defun vikix-backup-text (last days now)
  "The reminder for a last backup at LAST, reminding after DAYS days, at
NOW (all Unix times but DAYS). NIL LAST means backups aren't set up."
  (cond ((null last) "")
        ((zerop last) "backup")
        (t (let ((age (floor (- now last) 86400)))
             (if (>= age days) (format nil "backup ~ad" age) "")))))

(defun vikix-backup-refresh ()
  "Read vikix-backup's file into *vikix-backup*; redraw the bar if it changed."
  (let* ((line (ignore-errors
                (with-open-file (in *vikix-backup-file*) (read-line in nil ""))))
         (words (and line (split-string line " ")))
         (last (ignore-errors (parse-integer (first words))))
         (days (or (ignore-errors (parse-integer (second words))) 7))
         ;; Lisp counts from 1900, Unix from 1970.
         (now (- (get-universal-time) 2208988800))
         (new (vikix-backup-text last days now)))
    (unless (string= new *vikix-backup*)
      (setf *vikix-backup* new)
      (update-all-mode-lines))))

;;; Recording the screen (bin/vikix-record), shown in the bar.

(defparameter *vikix-recording-file*
  (merge-pathnames ".local/state/vikix/recording" (user-homedir-pathname))
  "Holds ffmpeg's process id while vikix-record records.")

(defvar *vikix-recording* nil
  "True while the screen is being recorded.")

(defparameter *vikix-dictating-file*
  (merge-pathnames ".local/state/vikix/dictating" (user-homedir-pathname))
  "Holds the recorder's process id while vikix-dictate listens.")

(defvar *vikix-dictating* nil
  "True while vikix-dictate listens (the bar says mic).")

(defun vikix-recording-p (&optional (file *vikix-recording-file*))
  "True when FILE (the recording file) names a running process. A file
left behind by a crash names one that is gone."
  (handler-case
      (with-open-file (in file :if-does-not-exist nil)
        (let ((pid (and in (parse-integer (or (read-line in nil) "")
                                          :junk-allowed t))))
          (and pid (probe-file (format nil "/proc/~d/" pid)) t)))
    (error () nil)))

(defun vikix-record-refresh ()
  "Read the recording state into *vikix-recording*; redraw the bar if it
changed. vikix-record calls this when it starts and stops."
  (let ((new (vikix-recording-p))
        (mic (vikix-recording-p *vikix-dictating-file*)))
    (unless (and (eq new *vikix-recording*) (eq mic *vikix-dictating*))
      (setf *vikix-recording* new
            *vikix-dictating* mic)
      (update-all-mode-lines))))

(defcommand vikix-record (what) ((:string "Record (area, screen): "))
  "Start recording the screen, or stop if it is recording. WHAT is area
(drag one out, or click a window) or screen (the whole monitor). The bar
says rec while it records; the video goes to ~/Videos/Recordings."
  (run-shell-command (format nil "vikix-record toggle ~a" what)))

(defparameter *vikix-capture-menu*
  '(("Screenshot: an area, to a file"    "vikix-screenshot area file")
    ("Screenshot: this window, to a file" "vikix-screenshot window file")
    ("Screenshot: the whole screen, to a file" "vikix-screenshot screen file")
    ("Text from an area, to the clipboard (OCR)" "vikix-screenshot text")
    ("Pick a colour: its #rrggbb to the clipboard" "vikix-screenshot colour")
    ("Record an area or a window"        "vikix-record area")
    ("Record the whole screen"           "vikix-record screen"))
  "Each entry: a label and the shell command it runs.")

(defcommand vikix-capture () ()
  "Pick a screenshot or a recording. While recording, the only choice is
to stop."
  (vikix-record-refresh)
  (let ((choice (select-from-menu
                 (current-screen)
                 (if *vikix-recording*
                     '(("Stop recording" "vikix-record stop"))
                     *vikix-capture-menu*)
                 "Screenshot or record: ")))
    ;; The menu closes first, so it isn't in the picture.
    (when choice
      (run-shell-command (second choice)))))

;;; Night light (bin/vikix-nightlight, gammastep).

(defcommand vikix-nightlight () ()
  "Night light, on or off: a warmer screen in the evening. The times and
colours are in ~/.config/gammastep/config.ini. Switched off, it stays off
at the next login too, until you switch it on."
  (let ((said (string-trim '(#\Space #\Newline)
                           (run-shell-command "vikix-nightlight toggle 2>&1" t))))
    (message "~a" (if (string= said "") "Night light: no answer" said))))

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
