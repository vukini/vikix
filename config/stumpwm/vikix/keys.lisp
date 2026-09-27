;;;; keys.lisp — Super-key bindings.
;;;;
;;;; StumpWM's own bindings stay as they are: press the prefix key
;;;; (Ctrl+t) and then a key. Vikix adds direct bindings on the Super
;;;; key in *top-map*, the map that is active without any prefix.
;;;; In key names "s-" means Super and "C-" means Ctrl.
;;;;
;;;; Moving a window to a workspace is s-C-<digit>, not Super+Shift+<digit>:
;;;; Shift+digit is a different key on every keyboard layout (! on US,
;;;; " on UK for 2 ...), while Ctrl+digit is the same everywhere.

(in-package :stumpwm)

(defun vikix-bind (key command)
  "Bind KEY (a key name like \"s-RET\") to COMMAND (a command string)."
  (define-key *top-map* (kbd key) command))

(defparameter *vikix-bindings*
  '(;; programs
    ("s-RET"  "vikix-terminal"  "Terminal")
    ("s-d"    "exec rofi -show drun" "Launcher: start any program")
    ("s-w"    "exec firefox"      "Browser")
    ("s-e"    "exec pcmanfm"      "Files")
    ("s-E"    "exec spacefm"      "Files in SpaceFM: tabs and split panes")
    ("s-a"    "vikix-agent"       "AI agent: Claude Code in a terminal")
    ("s-x"    "exec emacsclient -c -a ''" "Emacs: a new window")
    ("s-c"    "exec env CM_LAUNCHER=rofi clipmenu" "Clipboard history: pick to paste again")
    ;; notifications
    ("s-n"    "exec dunstctl history-pop"  "Notifications: the last one again")
    ("s-N"    "exec vikix-notifications"   "Notifications: pick an earlier one")
    ("s-C-n"  "exec dunstctl close-all"    "Notifications: close all")
    ("s-M-n"  "vikix-quiet"                "Do not disturb on/off")
    ;; windows
    ("s-q"    "delete"            "Close window")
    ("s-f"    "fullscreen"        "Fullscreen on/off")
    ("s-TAB"  "pull-hidden-other" "Previous window")
    ("s-h"    "move-focus left"   "Focus left")
    ("s-j"    "move-focus down"   "Focus down")
    ("s-k"    "move-focus up"     "Focus up")
    ("s-l"    "move-focus right"  "Focus right")
    ("s-H"    "move-window left"  "Move window left")
    ("s-J"    "move-window down"  "Move window down")
    ("s-K"    "move-window up"    "Move window up")
    ("s-L"    "move-window right" "Move window right")
    ;; The same four directions on the arrow keys. In a VirtualBox VM on
    ;; Windows, Super+L never reaches the guest (the host locks its screen
    ;; instead), so s-l and s-L are dead there; the arrows always work.
    ("s-Left"    "move-focus left"   "Focus left (arrow)")
    ("s-Down"    "move-focus down"   "Focus down (arrow)")
    ("s-Up"      "move-focus up"     "Focus up (arrow)")
    ("s-Right"   "move-focus right"  "Focus right (arrow)")
    ("s-C-Left"  "move-window left"  "Move window left (arrow)")
    ("s-C-Down"  "move-window down"  "Move window down (arrow)")
    ("s-C-Up"    "move-window up"    "Move window up (arrow)")
    ("s-C-Right" "move-window right" "Move window right (arrow)")
    ;; frames (StumpWM's splits)
    ("s-b"    "hsplit"            "Split: side by side")
    ("s-v"    "vsplit"            "Split: one above the other")
    ("s-r"    "remove"            "Remove this split")
    ;; windows.lisp: gaps, layout undo, finding windows
    ("s-g"    "toggle-gaps"       "Gaps around windows on/off")
    ("s-u"    "winner-undo"       "Undo the last layout change (splits, moves)")
    ("s-U"    "winner-redo"       "Redo the layout change")
    ("s-A"    "global-windowlist" "Any window, on any workspace: go there")
    ("s-C-a"  "global-pull-windowlist" "Any window, on any workspace: bring it here")
    ("s-p"    "beckon"            "Move the pointer to this window")
    ;; Vikix
    ("s-m"    "vikix-menu"      "Vikix menu")
    ("s-F1"   "vikix-keys"      "These keys")
    ("s-ESC"  "exec vikix-lock"  "Lock the screen")
    ("s-M-a"  "vikix-awake"      "Keep awake on/off: no lock, dark screen or suspend")
    ("Print"   "exec vikix-screenshot clip" "Screenshot of an area, to the clipboard")
    ("S-Print" "exec vikix-screenshot file" "Screenshot of an area, to ~/Pictures/Screenshots")
    ;; the laptop's function keys
    ;; vikix-osd changes the level and shows a bar for it (bin/vikix-osd);
    ;; the vikix-volume command also updates the volume in the mode line.
    ("XF86AudioRaiseVolume"  "vikix-volume up"               "Volume up")
    ("XF86AudioLowerVolume"  "vikix-volume down"             "Volume down")
    ("XF86AudioMute"         "vikix-volume mute"             "Mute")
    ("XF86AudioMicMute"      "vikix-volume mic"              "Microphone mute")
    ("XF86MonBrightnessUp"   "exec vikix-osd brightness up"  "Brightness up")
    ("XF86MonBrightnessDown" "exec vikix-osd brightness down" "Brightness down"))
  "Each entry: a key name, the StumpWM command it runs, and a description.
The descriptions are what the key help (s-F1) shows, so this list is the
one place a key is written down.")

(dolist (binding *vikix-bindings*)
  (vikix-bind (first binding) (second binding)))

;; Workspaces: s-1 goes to workspace 1, s-C-1 sends the window there.
(loop for n from 1 to 9
      do (vikix-bind (format nil "s-~d" n)   (format nil "gselect ~d" n))
         (vikix-bind (format nil "s-C-~d" n) (format nil "gmove ~d" n)))
