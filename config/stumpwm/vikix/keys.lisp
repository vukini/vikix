;;;; keys.lisp — Super-key bindings.
;;;;
;;;; StumpWM's own bindings stay as they are: press the prefix key
;;;; (Ctrl+t) and then a key. Vikix adds direct bindings on the Super
;;;; key in *top-map*, the map that is active without any prefix.
;;;; In key names "s-" means Super, "S-" Shift, "M-" Alt and "C-" Ctrl; a
;;;; capital letter is Shift and that letter ("s-H" is Super+Shift+h).
;;;;
;;;; The rule for keys: each modifier means one thing, for Vikix's keys,
;;;; a plugin's and a web app's alike (docs/customize.md, "The rule for keys").
;;;;
;;;;   Super          everyday: the six main apps (terminal, launcher,
;;;;                  browser, files, editor, agent), the small tools,
;;;;                  focus, and what is done to the window you're in
;;;;   Super+Shift    the same key, moving the window: move it, send it to
;;;;                  a workspace, bring one here; or the key's other way
;;;;                  (redo, previous, the bigger version)
;;;;   Super+Alt      open something else: every other app, web app and
;;;;                  plugin
;;;;   Super+Ctrl     switch something on the desktop: keep awake, night
;;;;                  light, do not disturb, gaps, title bars, recording
;;;;
;;;; Keys without Super keep their own ways: Print (Shift keeps a file,
;;;; Ctrl is the window, Super the screen) and the laptop's own keys.
;;;; vikix-key-problems (help.lisp) finds a key that breaks the rule, and
;;;; tests/lisp.sh fails on one of Vikix's.
;;;;
;;;; Sending a window to a workspace is Super+Shift+<digit>. Shift+digit is
;;;; a different key on every keyboard layout (! on US, " on UK for 2 ...),
;;;; so the key's name is asked of the keyboard as it is laid out now
;;;; (vikix-bind-workspace-keys, below), not written down here.

(in-package :stumpwm)

;;; What the rule goes by (vikix-key-problems, help.lisp, reads these). An
;;; entry is a whole command ("exec dunstctl close-all") or what a command
;;; is about (the program it starts, or the StumpWM command: "vikix-move").

(defparameter *vikix-key-everyday*
  '("vikix-terminal" "rofi" "firefox" "vikix-esploro" "emacsclient" "vikix-agent"  ; the six main apps
    "vikix-ask" "clipmenu" "vikix-rofi" "vikix-dictate" "vikix-voice"
    "exec dunstctl history-pop" "vikix-notifications" "vikix-lock" "vikix-screenshot" "vikix-osd"
    "vikix-docs")
  "What may be opened with Super alone: the six main apps and the small
tools. Every other program a key starts is on Super+Alt.")

(defparameter *vikix-key-switches*
  '("toggle-gaps" "vikix-titlebars" "vikix-main" "vikix-layout-pick" "vikix-drawer" "vikix-awake" "vikix-nightlight" "vikix-quiet"
    "vikix-record" "vikix-capture" "vikix-pick-theme" "exec dunstctl close-all" "exec vikix-drives eject"
    "vikix-screens-pick")
  "What switches something on the desktop: on Super+Ctrl, and nothing else is.")

(defparameter *vikix-key-movers*
  '("vikix-move" "vikix-move-end" "move-window" "gmove" "vikix-bring-window" "global-pull-windowlist")
  "What moves a window: on Super+Shift.")

(defvar *vikix-bind-later* nil
  "True inside vikix-binding-keys: X hears of the keys once, at its end.")

(defun vikix-bind (key command)
  "Bind KEY (a key name like \"s-RET\") to COMMAND (a command string)."
  (if *vikix-bind-later*
      ;; define-key tells X when the map is *top-map*: not this time.
      (let ((map *top-map*))
        (let ((*top-map* nil))
          (define-key map (kbd key) command)))
      (define-key *top-map* (kbd key) command)))

(defmacro vikix-binding-keys (&body body)
  "Run BODY, which binds keys with vikix-bind, and tell X about them once.
Each change to *top-map* makes StumpWM grab every key again on every
window (sync-keys): 117 keys, one at a time, over a dozen windows took 10
of a reload's 15 seconds, and the desktop stood still meanwhile."
  `(unwind-protect (let ((*vikix-bind-later* t)) ,@body)
     (sync-keys)))

(defparameter *vikix-bindings*
  '(;; programs
    ("s-RET"  "vikix-terminal"  "Terminal")
    ("s-d"    "exec rofi -show drun" "Launcher: start any program")
    ("s-SPC"  "exec rofi -show drun" "Launcher, the key other desktops use")
    ("s-w"    "exec firefox"      "Browser")
    ("s-e"    "vikix-esploro"     "Files in Esploro: the one on this workspace, or a new one here (PCManFM without Esploro)")
    ("s-M-s"  "exec spacefm"      "Files in SpaceFM: tabs and split panes")
    ("s-C-e"  "exec vikix-drives eject" "Eject a USB drive: pick it, then pull it out safely")
    ("s-M-e"  "exec pcmanfm"      "Files in PCManFM")
    ("s-M-E"  "exec esploro --new" "Files in a new Esploro window, beside the others")
    ("s-M-r"  "exec esploro reveal" "Reveal the file behind this window, in Esploro")
    ("s-M-x"  "exec vikix-esploro menu" "Esploro's commands for the file behind this window, in rofi")
    ("s-M-p"  "exec vikix-project pick" "Projects: pick one; a terminal in its folder, its log in the editor")
    ("s-M-v"  "exec vikix-bitwarden pick" "Passwords (Bitwarden): pick a login, Enter types it (vikix add bitwarden)")
    ("s-a"    "vikix-agent"       "AI agent in a terminal: Claude Code, or the one you chose")
    ("s-F9"   "exec vikix-dictate toggle" "Dictation: speak, then Super+F9 again types it")
    ("s-S-F9" "exec vikix-dictate cancel" "Dictation: stop listening, type nothing")
    ("s-F10"  "exec vikix-dictate toggle ask"   "Voice: speak, then Super+F10 again: the AI answers aloud")
    ("s-F11"  "exec vikix-dictate toggle agent" "Voice: speak, then Super+F11 again: it goes to the agent")
    ("s-S-F10" "exec vikix-voice quiet"         "Voice: stop the AI talking")
    ("s-i"    "exec vikix-ask"    "AI on the selected text: ask, proofread, rewrite, translate, explain")
    ("s-x"    "exec emacsclient -c -a ''" "Emacs: a new window")
    ("s-c"    "exec env CM_LAUNCHER=rofi clipmenu" "Clipboard history: pick to paste again")
    ("s-period" "exec vikix-rofi emoji" "Emoji: pick one to type it (Ctrl+c copies)")
    ("s-equal"  "exec vikix-rofi calc"  "Calculator: Enter copies the answer")
    ;; notifications
    ("s-n"    "exec dunstctl history-pop"  "Notifications: the last one again")
    ("s-N"    "exec vikix-notifications"   "Notifications: pick an earlier one")
    ("s-C-n"  "exec dunstctl close-all"    "Notifications: close all")
    ("s-C-d"  "vikix-quiet"                "Do not disturb on/off")
    ;; windows
    ("s-q"    "delete"            "Close window")
    ("s-f"    "fullscreen"        "Fullscreen on/off")
    ("s-TAB"  "vikix-last-window" "The last window again: flips between two")
    ;; Super+` and Super+Shift+` go through every window on the workspace:
    ;; to its frame when it's showing, into this frame when it's hidden.
    ;; Shift+` is ~ on the keyboard, so StumpWM knows that key as asciitilde.
    ("s-grave"      "next" "Next window on this workspace, through all of them")
    ("s-asciitilde" "prev" "Previous window on this workspace")
    ("s-h"    "vikix-focus left"   "Focus left")
    ("s-j"    "vikix-focus down"   "Focus down")
    ("s-k"    "vikix-focus up"     "Focus up")
    ("s-l"    "vikix-focus right"  "Focus right")
    ("s-H"    "vikix-move left"  "Move window left")
    ("s-J"    "vikix-move down"  "Move window down")
    ("s-K"    "vikix-move up"    "Move window up")
    ("s-L"    "vikix-move right" "Move window right")
    ;; The same four directions on the arrow keys. In a VirtualBox VM on
    ;; Windows, Super+L never reaches the guest (the host locks its screen
    ;; instead), so s-l and s-L are dead there; the arrows always work.
    ("s-Left"    "vikix-focus left"   "Focus left (arrow)")
    ("s-Down"    "vikix-focus down"   "Focus down (arrow)")
    ("s-Up"      "vikix-focus up"     "Focus up (arrow)")
    ("s-Right"   "vikix-focus right"  "Focus right (arrow)")
    ("s-S-Left"  "vikix-move left"  "Move window left (arrow)")
    ("s-S-Down"  "vikix-move down"  "Move window down (arrow)")
    ("s-S-Up"    "vikix-move up"    "Move window up (arrow)")
    ("s-S-Right" "vikix-move right" "Move window right (arrow)")
    ;; frames (StumpWM's splits)
    ("s-b"    "vikix-split"       "Split: side by side")
    ("s-v"    "vikix-split below" "Split: one above the other")
    ("s-r"    "vikix-width-or-remove" "Remove this split (on a strip: the column's width; in main and stack: the main window's)")
    ("s-Home"   "vikix-focus-end first" "On a strip: the first column")
    ("s-End"    "vikix-focus-end last"  "On a strip: the last column")
    ("s-backslash" "vikix-pin" "On a strip: pin this column to the left edge, the others scroll beside it; again unpins")
    ("s-bracketleft"  "vikix-stack left"  "On a strip: into the column on the left, or out of a shared one")
    ("s-bracketright" "vikix-stack right" "On a strip: into the column on the right, or out of a shared one")
    ("s-o"    "vikix-overview"    "Every workspace drawn small, each window a box: pick one (g there: this workspace in a real grid)")
    ("s-O"    "vikix-grid"        "Grid mode on/off: windows stay tiled in a grid as they open and close")
    ("s-C-m"  "vikix-main"        "Main and stack (master and stack) on/off: this window on the left, the rest in a column beside it")
    ("s-C-SPC" "vikix-layout-pick" "Layout: pick this workspace's (tiles, main and stack, grid, strip, or one you saved)")
    ("s-z"    "vikix-solo"        "Focus: only this window; again puts the others back (on a strip: its column's windows as tabs)")
    ;; drawer.lisp
    ("s-C-b"  "vikix-drawer"      "The drawer: a few everyday programs at the screen's edge, here; again puts it away")
    ;; windows.lisp: gaps, layout undo, finding windows
    ("s-C-g"  "toggle-gaps"       "Gaps around windows on/off")
    ("s-u"    "vikix-layout-undo" "Undo the last layout change (splits, moves)")
    ("s-U"    "vikix-layout-redo" "Redo the layout change")
    ("s-g"    "vikix-go-to-window" "Go to any window, on any workspace")
    ("s-G"    "vikix-bring-window" "Bring any window here, from any workspace")
    ("s-p"    "vikix-pointer"     "Move the pointer to this window")
    ("s-t"    "vikix-float"       "Float this window, or tile it again (Super+drag moves it)")
    ("s-T"    "vikix-remember"    "Remember this window here: the rule for where it is, written for you (shown first)")
    ("s-C-y"  "vikix-titlebars"   "Title bars on/off")
    ("s-\""   "vikix-title"       "Rename this window")
    ;; Vikix
    ("s-m"    "vikix-menu"      "Vikix menu")
    ("s-slash" "vikix-keys-card" "Every key at a glance, grouped; any key closes it")
    ("s-F1"   "vikix-keys"      "Search the keys, and run one")
    ("s-F2"   "exec vikix-docs pick" "Search every document: Vikix's guides, your projects and notes, man pages")
    ("s-ESC"  "exec vikix-lock"  "Lock the screen")
    ("s-S-ESC" "vikix-power"     "Power: lock, suspend, log out, reboot, power off")
    ("s-C-a"  "vikix-awake"      "Keep awake on/off: no lock, dark screen or suspend")
    ("s-C-l"  "vikix-nightlight" "Night light on/off: a warmer screen in the evening")
    ("s-C-p"  "vikix-screens-pick" "Screens: extend, mirror, one only, arrange (a newly plugged one lights up by itself)")
    ;; Screenshots: the modifier picks what, Shift keeps it in a file
    ;; (~/Pictures/Screenshots) instead of the clipboard.
    ("Print"     "exec vikix-screenshot area clip"   "Screenshot of an area, to the clipboard")
    ("S-Print"   "exec vikix-screenshot area file"   "Screenshot of an area, to a file")
    ("C-Print"   "exec vikix-screenshot window clip" "Screenshot of this window, to the clipboard")
    ("C-S-Print" "exec vikix-screenshot window file" "Screenshot of this window, to a file")
    ("s-Print"   "exec vikix-screenshot screen clip" "Screenshot of the whole screen, to the clipboard")
    ("s-S-Print" "exec vikix-screenshot screen file" "Screenshot of the whole screen, to a file")
    ("s-C-v"     "vikix-record area" "Record a video of an area or a window; again to stop")
    ("s-C-Print" "vikix-capture"     "Screenshot or record: all the choices")
    ;; the laptop's function keys
    ;; vikix-osd changes the level and shows a bar for it (bin/vikix-osd);
    ;; the vikix-volume command also updates the volume in the mode line.
    ("XF86AudioRaiseVolume"  "vikix-volume up"               "Volume up")
    ("XF86AudioLowerVolume"  "vikix-volume down"             "Volume down")
    ("XF86AudioMute"         "vikix-volume mute"             "Mute")
    ("XF86AudioMicMute"      "vikix-volume mic"              "Microphone mute")
    ("XF86MonBrightnessUp"   "exec vikix-osd brightness up"  "Brightness up")
    ("XF86MonBrightnessDown" "exec vikix-osd brightness down" "Brightness down")
    ("XF86Display"           "vikix-screens-pick"            "Screens: extend, mirror, one only (the laptop's display key)"))
  "Each entry: a key name, the StumpWM command it runs, and a description.
An optional fourth element names the group the key card (s-/) shows it
in; without one, help.lisp works the group out from the command.
The descriptions are what the key card (s-/) and the key help (s-F1)
show, so this list is the one place a key is written down.")

;;; Super+Shift+<digit>: send the window to that workspace. StumpWM knows a
;;; key by what it types, and Shift+1 types ! on a US keyboard, something
;;; else on others. So the keyboard is asked what each Shift+digit is, now
;;; and again when its layout changes (Super+m, Apply keyboard settings).

(defparameter *vikix-us-shifted-digits*
  '("exclam" "at" "numbersign" "dollar" "percent" "asciicircum" "ampersand" "asterisk" "parenleft")
  "Shift+1 ... Shift+9 on a US keyboard, as StumpWM names those keys: used
when the keyboard can't be asked (no screen yet).")

(defvar *vikix-workspace-send-keys* '()
  "The keys bound to send a window to workspaces 1 to 9, as bound last.")

(defun vikix-shift-digit-key (n)
  "The name of the key Super+Shift+N on the keyboard as it is laid out now.
Where the digit itself needs Shift (French), Super+Ctrl+N instead."
  (or (ignore-errors
       (let* ((digit (+ (char-code #\0) n))
              (code (first (multiple-value-list (xlib:keysym->keycodes *display* digit))))
              (plain (and code (xlib:keycode->keysym *display* code 0)))
              (shifted (and code (xlib:keycode->keysym *display* code 1)))
              (name (and shifted (plusp shifted) (keysym->keysym-name shifted))))
         (cond ((null code) nil)
               ((/= plain digit) (format nil "s-C-~d" n))
               ((or (null name) (= shifted digit)) (format nil "s-S-~d" n))
               (t (format nil "s-~a" name)))))
      (format nil "s-~a" (nth (1- n) *vikix-us-shifted-digits*))))

(defun vikix-bind-workspace-keys ()
  "Bind Super+Shift+1 ... 9 to send the window to that workspace, for the
keyboard as it is now; the keys bound for another layout are let go."
  (let ((keys (loop for n from 1 to 9 collect (vikix-shift-digit-key n))))
    (dolist (old *vikix-workspace-send-keys*)
      (unless (member old keys :test #'equal)
        (ignore-errors (undefine-key *top-map* (kbd old)))))
    (loop for key in keys
          for n from 1
          do (vikix-bind key (format nil "gmove ~d" n)))
    (setf *vikix-workspace-send-keys* keys)))

;;; Clashes: a plugin or a web app taking a key something else has. The
;;; newer one wins (it's bound last), so the older one is left with no key
;;; and nothing said: Super+Alt+c was Esploro's commands and next-meeting's
;;; week at once (0.71.68). Now each is noted, said once, and listed by
;;; vikix doctor.
(defvar *vikix-key-clashes* '()
  "Keys two owners wanted: (KEY HAD TAKEN-BY), HAD and TAKEN-BY in words
(\"Vikix: Esploro's commands\", \"plugin next-meeting\"), newest first.")

(defun vikix-key-had (key)
  "Who has KEY now, in words, or NIL when no one: a plugin, a web app, or
Vikix (yours from user.lisp count as Vikix's here: they load after)."
  (let ((binding (find key *vikix-bindings* :key #'first :test #'equal))
        (plugin (and (boundp '*vikix-plugin-keys*)
                     (find key (symbol-value '*vikix-plugin-keys*) :key #'second :test #'equal))))
    (cond (plugin (format nil "plugin ~a" (first plugin)))
          ((null binding) nil)
          ((eql 0 (search "vikix-webapp " (second binding)))
           (format nil "web app ~a" (subseq (second binding) (length "vikix-webapp "))))
          (t (format nil "Vikix: ~a" (third binding))))))

(defun vikix-note-clash (key taken-by)
  "Note that TAKEN-BY is taking KEY from whoever has it. True when it was a clash."
  (let ((had (vikix-key-had key)))
    (when (and had (string/= had taken-by))
      (push (list key had taken-by) *vikix-key-clashes*)
      t)))

(defun vikix-forget-clashes (taken-by-prefix)
  "Forget the clashes made by owners whose name starts so (\"plugin \"): they're loading again."
  (setf *vikix-key-clashes*
        (remove-if (lambda (c) (eql 0 (search taken-by-prefix (third c)))) *vikix-key-clashes*)))

(defun vikix-say-clashes (taken-by-prefix)
  "One message for the clashes those owners made, if any."
  (let ((mine (remove-if-not (lambda (c) (eql 0 (search taken-by-prefix (third c)))) *vikix-key-clashes*)))
    (when mine
      (message "^1Vikix: a key with two owners^n~{~%~a~}~%The second has it; give one another key (vikix doctor lists them)."
               (mapcar (lambda (c) (format nil "~a: ~a, and ~a"
                                           (if (fboundp 'vikix-pretty-key) (funcall 'vikix-pretty-key (first c)) (first c))
                                           (second c) (third c)))
                       (reverse mine))))))

;;; Keys Vikix had before the rule (0.71.116). A desktop that is running
;;; keeps a key until StumpWM starts again, so a reload lets these go: each
;;; only while it still runs what Vikix bound it to, never one you, a
;;; plugin or a web app have since given something else.
(defparameter *vikix-retired-keys*
  ;; Written flat, a key then its command: lines that begin ("s- are read
  ;; as Vikix's keys by the scripts that list them (vikix-webapp, the tests).
  '("s-E" "exec spacefm"   "s-P" "exec vikix-project pick"   "s-V" "exec vikix-bitwarden pick"
    "s-M" "vikix-webapp "  "s-M-n" "vikix-quiet"             "s-A" "global-windowlist"
    "s-y" "vikix-titlebars" "s-M-a" "vikix-awake"            "s-M-l" "vikix-nightlight"
    "s-R" "vikix-record area"
    "s-C-Left" "vikix-move" "s-C-Down" "vikix-move" "s-C-Up" "vikix-move" "s-C-Right" "vikix-move"
    "s-C-1" "gmove" "s-C-2" "gmove" "s-C-3" "gmove" "s-C-4" "gmove" "s-C-5" "gmove"
    "s-C-6" "gmove" "s-C-7" "gmove" "s-C-8" "gmove" "s-C-9" "gmove")
  "A key, then how the command Vikix had on it began; and so on.")

(defun vikix-retire-keys ()
  "Let go of the keys Vikix no longer has, where they still run its command."
  (loop for (key command) on *vikix-retired-keys* by #'cddr
        do (let ((now (ignore-errors (lookup-key *top-map* (kbd key)))))
             (when (and (stringp now) (eql 0 (search command now))
                        (not (find key *vikix-bindings* :key #'first :test #'equal)))
               (ignore-errors (undefine-key *top-map* (kbd key)))))))

(vikix-binding-keys
  (vikix-retire-keys)
  (dolist (binding *vikix-bindings*)
    (vikix-bind (first binding) (second binding)))

  ;; Workspaces: s-1 goes to workspace 1; Super+Shift+1 sends the window there.
  (loop for n from 1 to 9
        do (vikix-bind (format nil "s-~d" n) (format nil "gselect ~d" n)))
  (vikix-bind-workspace-keys))
