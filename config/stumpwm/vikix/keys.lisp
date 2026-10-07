;;;; keys.lisp — Super-key bindings.
;;;;
;;;; StumpWM's own bindings stay as they are: press the prefix key
;;;; (Ctrl+t) and then a key. Vikix adds direct bindings on the Super
;;;; key in *top-map*, the map that is active without any prefix.
;;;; In key names "s-" means Super, "S-" Shift, "M-" Alt and "C-" Ctrl; a
;;;; capital letter is Shift and that letter ("s-H" is Super+Shift+h).
;;;;
;;;; Which key runs what is written in registry.lisp, with each command;
;;;; this file binds them, and holds what is about keys themselves.
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
;;;; A few keys open a map instead (Super+Ctrl+Space the layout's, Super+Alt+d
;;;; the desks'): single keys act in it until Escape or half a minute passes
;;;; (help.lisp, vikix-map). Such a key is written "s-C-SPC m" in
;;;; *vikix-bindings*, the two keys with a space between; this file binds the
;;;; first alone, and the rule judges it by that first key.
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
  '("vikix-terminal" "rofi" "vikix-palette" "firefox" "vikix-esploro" "emacsclient" "vikix-agent" "vikix-agent-choice"  ; the six main apps (the launcher twice)
    "vikix-ask" "clipmenu" "vikix-rofi" "vikix-dictate" "vikix-voice"
    "exec dunstctl history-pop" "vikix-notifications" "vikix-lock" "vikix-screenshot" "vikix-osd"
    "vikix-docs")
  "What may be opened with Super alone: the six main apps and the small
tools. Every other program a key starts is on Super+Alt.")

(defparameter *vikix-key-switches*
  '("toggle-gaps" "vikix-titlebars" "vikix-main" "vikix-layout-pick" "vikix-drawer" "vikix-awake" "vikix-nightlight" "vikix-quiet" "vikix-focus-time"
    "vikix-record" "vikix-capture" "vikix-pick-theme" "exec dunstctl close-all" "exec vikix-drives eject"
    "vikix-screens-pick" "vikix-bar")
  "What switches something on the desktop: on Super+Ctrl, and nothing else is.")

(defparameter *vikix-key-movers*
  '("vikix-move" "vikix-move-end" "move-window" "gmove" "vikix-send" "vikix-bring-window" "global-pull-windowlist")
  "What moves a window: on Super+Shift.")

(defvar *vikix-bind-later* nil
  "True inside vikix-binding-keys: X hears of the keys once, at its end.")

(defun vikix-bind (key command)
  "Bind KEY (a key name like \"s-RET\") to COMMAND (a command string). A
key inside a map (\"s-C-SPC m\") is only noted: the map reads it itself."
  ;; Where it was written, for "why did that happen?" (why.lisp).
  (when (and (or (and (boundp '*vikix-loading-file*) (symbol-value '*vikix-loading-file*)) *load-truename*) (boundp '*vikix-key-sources*))
    (setf (gethash key (symbol-value '*vikix-key-sources*))
          (cons (namestring (or (and (boundp '*vikix-loading-file*) (symbol-value '*vikix-loading-file*)) *load-truename*))
                (and (boundp '*vikix-load-line*) (symbol-value '*vikix-load-line*)))))
  (cond
    ((find #\Space key))
    (*vikix-bind-later*
     ;; define-key tells X when the map is *top-map*: not this time.
     (let ((map *top-map*))
       (let ((*top-map* nil))
         (define-key map (kbd key) command))))
    (t (define-key *top-map* (kbd key) command))))

(defmacro vikix-binding-keys (&body body)
  "Run BODY, which binds keys with vikix-bind, and tell X about them once.
Each change to *top-map* makes StumpWM grab every key again on every
window (sync-keys): 117 keys, one at a time, over a dozen windows took 10
of a reload's 15 seconds, and the desktop stood still meanwhile."
  `(unwind-protect (let ((*vikix-bind-later* t)) ,@body)
     (sync-keys)))

(defparameter *vikix-bindings* (vikix-registry-bindings)
  "Each entry: a key name, the StumpWM command it runs, and a description.
An optional fourth element names the group the key card (s-/) shows it
in; without one, help.lisp works the group out from the command.
The descriptions are what the key card (s-/) and the key help (s-F1)
show. Vikix's own are made from its commands (registry.lisp: a key is
written there, with what it runs); yours, a plugin's and a web app's are
added to this list.")

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
          do (vikix-bind key (format nil "vikix-send ~d" n)))
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
  ;; A key, then how its command began: Vikix's keys now are registry.lisp's.
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

;; From here on a command defined with define-vikix-command (yours, in
;; user.lisp) is bound and put in the menu as it is defined (registry.lisp).
(setf *vikix-registry-live* t)
