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

(defcommand vikix-theme (name) ((:string "Theme (void, paper): "))
  "Switch to the theme called NAME."
  (vikix-apply-theme (intern (string-upcase name) :keyword))
  (message "Theme: ~a" name))

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
    ("Screenshot: an area, to a file" (run-shell-command "vikix-screenshot file"))
    ("Undo: my files back one snapshot" vikix-undo)
    ("Reload config"       vikix-reload)
    ("Theme: void (dark)"  (vikix-theme "void"))
    ("Theme: paper (light)" (vikix-theme "paper"))
    ("Apply keyboard settings" (run-shell-command "vikix-keyboard"))
    ("Network (nmtui)"     (run-shell-command
                            (format nil "~a -e nmtui" *vikix-terminal*)))
    ("Bluetooth"           (run-shell-command "blueman-manager"))
    ("Screens: arrange (arandr)" (run-shell-command "arandr"))
    ("Screens: save this layout" vikix-screens-save)
    ("Sound (pavucontrol)" (run-shell-command "pavucontrol"))
    ("Lock"                (run-shell-command "i3lock -c 1e1e2e"))
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

(defcommand vikix-volume (change) ((:string "Volume (up, down, mute, mic): "))
  "Change the volume with vikix-osd, which shows a bar for it, then show
the new level in the mode line."
  (run-shell-command (format nil "vikix-osd volume ~a" change))
  ;; vikix-osd runs in the background; read the level once it has finished.
  ;; A ratio, not 0.5: StumpWM's timers want rationals.
  (run-with-timer 1/2 nil #'vikix-volume-refresh))
