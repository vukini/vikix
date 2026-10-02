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
    ("s-SPC"  "exec rofi -show drun" "Launcher, the key other desktops use")
    ("s-w"    "exec firefox"      "Browser")
    ("s-e"    "vikix-esploro"     "Files in Esploro: the one on this workspace, or a new one here (PCManFM without Esploro)")
    ("s-E"    "exec spacefm"      "Files in SpaceFM: tabs and split panes")
    ("s-C-e"  "exec vikix-drives eject" "Eject a USB drive: pick it, then pull it out safely")
    ("s-M-e"  "exec pcmanfm"      "Files in PCManFM")
    ("s-M-E"  "exec esploro --new" "Files in a new Esploro window, beside the others")
    ("s-M-r"  "exec esploro reveal" "Reveal the file behind this window, in Esploro")
    ("s-P"    "exec vikix-project pick" "Projects: pick one; a terminal in its folder, its log in the editor")
    ("s-V"    "exec vikix-bitwarden pick" "Passwords (Bitwarden): pick a login, Enter types it (vikix add bitwarden)")
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
    ("s-M-n"  "vikix-quiet"                "Do not disturb on/off")
    ;; windows
    ("s-q"    "delete"            "Close window")
    ("s-f"    "fullscreen"        "Fullscreen on/off")
    ("s-TAB"  "pull-hidden-other" "The last window again: flips between two")
    ;; Super+` and Super+Shift+` go through every window on the workspace:
    ;; to its frame when it's showing, into this frame when it's hidden.
    ;; Shift+` is ~ on the keyboard, so StumpWM knows that key as asciitilde.
    ("s-grave"      "next" "Next window on this workspace, through all of them")
    ("s-asciitilde" "prev" "Previous window on this workspace")
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
    ("s-o"    "expose"            "Every window on this workspace in a grid; pick one (Super+u undoes it)")
    ("s-O"    "vikix-grid"        "Grid mode on/off: windows stay tiled in a grid as they open and close")
    ("s-z"    "vikix-solo"        "Focus: only this window; again puts the others back")
    ;; windows.lisp: gaps, layout undo, finding windows
    ("s-g"    "toggle-gaps"       "Gaps around windows on/off")
    ("s-u"    "winner-undo"       "Undo the last layout change (splits, moves)")
    ("s-U"    "winner-redo"       "Redo the layout change")
    ("s-A"    "global-windowlist" "Any window, on any workspace: go there")
    ("s-C-a"  "global-pull-windowlist" "Any window, on any workspace: bring it here")
    ("s-p"    "beckon"            "Move the pointer to this window")
    ("s-t"    "vikix-float"       "Float this window, or tile it again (Super+drag moves it)")
    ("s-y"    "vikix-titlebars"   "Title bars on/off")
    ("s-\""   "vikix-title"       "Rename this window")
    ;; Vikix
    ("s-m"    "vikix-menu"      "Vikix menu")
    ("s-slash" "vikix-keys-card" "Every key at a glance, grouped; any key closes it")
    ("s-F1"   "vikix-keys"      "Search the keys, and run one")
    ("s-ESC"  "exec vikix-lock"  "Lock the screen")
    ("s-S-ESC" "vikix-power"     "Power: lock, suspend, log out, reboot, power off")
    ("s-M-a"  "vikix-awake"      "Keep awake on/off: no lock, dark screen or suspend")
    ("s-M-l"  "vikix-nightlight" "Night light on/off: a warmer screen in the evening")
    ;; Screenshots: the modifier picks what, Shift keeps it in a file
    ;; (~/Pictures/Screenshots) instead of the clipboard.
    ("Print"     "exec vikix-screenshot area clip"   "Screenshot of an area, to the clipboard")
    ("S-Print"   "exec vikix-screenshot area file"   "Screenshot of an area, to a file")
    ("C-Print"   "exec vikix-screenshot window clip" "Screenshot of this window, to the clipboard")
    ("C-S-Print" "exec vikix-screenshot window file" "Screenshot of this window, to a file")
    ("s-Print"   "exec vikix-screenshot screen clip" "Screenshot of the whole screen, to the clipboard")
    ("s-S-Print" "exec vikix-screenshot screen file" "Screenshot of the whole screen, to a file")
    ("s-R"       "vikix-record area" "Record an area or a window; again to stop")
    ("s-C-Print" "vikix-capture"     "Screenshot or record: all the choices")
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
An optional fourth element names the group the key card (s-/) shows it
in; without one, help.lisp works the group out from the command.
The descriptions are what the key card (s-/) and the key help (s-F1)
show, so this list is the one place a key is written down.")

(dolist (binding *vikix-bindings*)
  (vikix-bind (first binding) (second binding)))

;; Workspaces: s-1 goes to workspace 1, s-C-1 sends the window there.
(loop for n from 1 to 9
      do (vikix-bind (format nil "s-~d" n)   (format nil "gselect ~d" n))
         (vikix-bind (format nil "s-C-~d" n) (format nil "gmove ~d" n)))
