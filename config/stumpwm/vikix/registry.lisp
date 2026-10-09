;;;; registry.lisp — every Vikix command, written down once.
;;;;
;;;; A command was described by hand in three places: its key, in keys.lisp;
;;;; its entry in Super+m, in commands.lisp; and what agents may do, in
;;;; vikix-mcp, with the agents' skill a fourth copy. Each is now made from
;;;; one form:
;;;;
;;;;   (define-vikix-command quiet "Do not disturb on/off"
;;;;     :run "vikix-quiet" :key "s-C-d"
;;;;     :menu "Notifications" :agent t)
;;;;
;;;;   NAME    what agents, and this file, call it: one word, yours to choose
;;;;   words   what it does, as the key card (s-/), the key help (s-F1) and
;;;;           the menu say it
;;;;   :run    the StumpWM command it runs, as a key writes it ("exec firefox",
;;;;           "vikix-focus left"); or
;;;;   :do     a Lisp form, for what no command string can say (menu only)
;;;;   :key    its key ("s-C-d": keys.lisp says how keys are named, and the
;;;;           rule they keep)
;;;;   :map    a key inside a map ("layout m": the map's name, then the key
;;;;           in it), beside :key or instead of it. A map is a command
;;;;           whose :run is "vikix-map NAME" (help.lisp): its key opens
;;;;           it, single keys act in it until Escape or half a minute
;;;;           pass, and the card shows its keys under its entry
;;;;   :card   its group on the key card, when the command's own word doesn't
;;;;           say (help.lisp: *vikix-key-groups*)
;;;;   :menu   the section of Super+m it is in (*vikix-menu-groups*); none:
;;;;           not in the menu
;;;;   :label  the menu's words, when they differ from the key's
;;;;   :needs  a program on PATH, or a file ("~/..."): without it the menu
;;;;           leaves the entry out
;;;;   :agent  t when an agent may run it (vikix mcp: commands, run_command):
;;;;           only what is put back as easily as it is done, and never
;;;;           anything that asks a question or starts a program
;;;;
;;;; Each is kept with the file and line it was written at, for vikix-why.
;;;;
;;;; From these: *vikix-bindings* and the keys bound (keys.lisp), *vikix-menu*
;;;; (commands.lisp), the agents' list (the end of this file), and the keys in
;;;; the agents' skill and in the README's table (lib/skill-keys.sh). Those two lists are still lists,
;;;; in the shape they had: user.lisp, plugins and web apps add to them as
;;;; before. In user.lisp a command of your own is one form too: written
;;;; there, its key is bound and its menu entry added at once.
;;;;
;;;; Vikix's commands are in this file in the key card's order. Super+m
;;;; shows its sections in *vikix-menu-groups*' order, and inside a section
;;;; keeps this file's: so a command the menu alone has is written where its
;;;; section wants it, beside the keys it belongs with (Theme before the
;;;; bar's key, the saved layouts after the layout picker's). Each form's
;;;; :run and :key are on one line: scripts that only want Vikix's keys
;;;; (vikix-webapp, the tests) read them with grep.
;;;;
;;;; Plain Common Lisp until the end of the entries, so a script can load
;;;; this file without StumpWM (lib/skill-keys.sh, tests/lisp.sh).

(in-package :stumpwm)

(defparameter *vikix-menu-groups*
  '("Start" "Help" "Vikix" "AI" "Work" "Notifications" "Desktop" "Windows" "System" "Apps" "Power")
  "The sections of Super+m, in the order it shows them (commands.lisp:
vikix-menu-sections). Power is last: an Enter pressed by mistake never
lands on it. A section these don't name (a plugin's, Plugins, Yours) comes
just before it.")

(defparameter *vikix-commands* '()
  "Every command defined with define-vikix-command, in order: a list of
plists (:name :does :run :do :key :map :card :menu :label :needs :agent). Emptied
when this file loads, so a reload has each once.")

(defparameter *vikix-registry-live* nil
  "True once keys.lisp has bound the keys: a command defined after that
(yours, in user.lisp) is bound and put in the menu as it is defined.")

(defun vikix-command (name)
  "The command called NAME (a symbol or a string), or NIL."
  (find (string name) *vikix-commands*
        :key (lambda (c) (string (getf c :name))) :test #'string-equal))

(defun vikix-command-check (name does options)
  "Say what is wrong with a command's form, as an error, while it loads."
  (flet ((bad (control &rest args)
           (error "define-vikix-command ~(~a~): ~?" name control args)))
    (unless (and (symbolp name) name) (bad "its name should be a word, not ~s." name))
    (unless (stringp does) (bad "after its name come its words, a string; this is ~s." does))
    (unless (evenp (length options)) (bad "an option without a value: ~s." options))
    (loop for (key nil) on options by #'cddr
          unless (member key '(:run :do :key :map :card :menu :label :needs :agent))
            do (bad "~(~s~) is no option of a command: :run, :do, :key, :map, :card, :menu, :label, :needs, :agent." key))
    (let ((run (getf options :run)) (do (getf options :do)) (key (getf options :key))
          (map (getf options :map)) (menu (getf options :menu)))
      (unless (or run do) (bad "it does nothing: give it :run, a command, or :do, a form."))
      (when (and run do) (bad "both :run and :do: one says what it does."))
      (when (and run (not (stringp run))) (bad ":run is a command string, like \"exec firefox\"; this is ~s." run))
      (when (and key (not run)) (bad "a key runs a command: with :key it needs :run, not :do."))
      (when (and key (not (stringp key))) (bad ":key is a key's name, like \"s-C-d\"; this is ~s." key))
      (when (and key (find #\Space key)) (bad ":key is one key; a key inside a map is :map \"MAP KEY\"."))
      (when map
        (unless run (bad "a key runs a command: with :map it needs :run, not :do."))
        (unless (and (stringp map) (= 1 (count #\Space map)) (not (eql 0 (position #\Space map)))
                     (not (eql (1- (length map)) (position #\Space map))))
          (bad ":map is a map's name and the key in it, like \"layout m\"; this is ~s." map))
        (let* ((map-name (subseq map 0 (position #\Space map)))
               (opener (vikix-map-command map-name)))
          (unless opener
            (bad ":map ~s: no command opens a map called ~a (one with :run \"vikix-map ~a\" and a :key, defined before this one)."
                 map map-name map-name))
          (unless (getf opener :key)
            (bad ":map ~s: the command that opens the map ~a has no key, so nothing could reach this one." map map-name))))
      (when (and menu (not (member menu *vikix-menu-groups* :test #'equal)))
        (bad ":menu ~s is no part of the menu: ~{~s~^, ~}." menu *vikix-menu-groups*))
      (when (and (not menu) (or (getf options :label) (getf options :needs)))
        (bad ":label and :needs are the menu's: they want :menu too."))
      (unless (or key map menu (getf options :agent))
        (bad "it has no key, is in no menu and is not for agents: nothing would ever run it.")))))

;;; Maps: a command whose :run is "vikix-map NAME" opens the map NAME; a
;;; command with :map "NAME k" is the key k inside it. In *vikix-bindings*
;;; such a key is written as the two keys with a space between, "s-C-SPC m",
;;; the way StumpWM writes a key sequence; keys.lisp binds only the first
;;; (the opener), and the map reads the second itself (help.lisp).

(defun vikix-map-command (name)
  "The command that opens the map NAME (its :run is \"vikix-map NAME\"), or nil."
  (find (format nil "vikix-map ~(~a~)" name) *vikix-commands*
        :key (lambda (c) (getf c :run)) :test #'string-equal))

(defun vikix-map-enter-key (name)
  "The key that opens the map NAME, or nil."
  (getf (vikix-map-command name) :key))

(defun vikix-command-map-key (command)
  "The key COMMAND has inside a map, as *vikix-bindings* writes it
(\"s-C-SPC m\"), or nil: none, or the map has no opener with a key."
  (let ((map (getf command :map)))
    (when map
      (let* ((space (position #\Space map))
             (enter (vikix-map-enter-key (subseq map 0 space))))
        (and enter (format nil "~a ~a" enter (subseq map (1+ space))))))))

(defun vikix-command-keys (command)
  "Every key name COMMAND is bound under: its own, and the one in its map."
  (remove nil (list (getf command :key) (vikix-command-map-key command))))

(defun vikix-command-bindings (command)
  "COMMAND's entries of *vikix-bindings*, (KEY COMMAND WORDS [GROUP]): one
for its key, one for its key inside a map, none when it has neither."
  (loop for key in (vikix-command-keys command)
        collect (append (list key (getf command :run) (getf command :does))
                        (when (getf command :card) (list (getf command :card))))))

(defun vikix-command-action (command)
  "What the menu does for COMMAND, in *vikix-menu*'s own form: a command's
name, or a Lisp form. \"exec X\" is (run-shell-command \"X\"), as the menu
always wrote it."
  (let ((run (getf command :run)))
    (cond ((null run) (getf command :do))
          ((and (> (length run) 5) (string= "exec " run :end2 5))
           (list 'run-shell-command (subseq run 5)))
          ((find #\Space run) (list 'run-commands run))
          (t (intern (string-upcase run) :stumpwm)))))

(defun vikix-command-menu-entry (command)
  "COMMAND as an entry of *vikix-menu*: (LABEL ACTION NEEDS SECTION), NEEDS
nil when it needs nothing."
  (list (or (getf command :label) (getf command :does)) (vikix-command-action command)
        (getf command :needs) (getf command :menu)))

(defun vikix-registry-bindings ()
  "*vikix-bindings* as the registry has it: the commands with a key, in order."
  (loop for c in *vikix-commands* append (vikix-command-bindings c)))

(defun vikix-registry-menu ()
  "*vikix-menu* as the registry has it: the commands with a place in the
menu, its sections in *vikix-menu-groups*' order, each in the registry's."
  (loop for group in *vikix-menu-groups*
        append (loop for c in *vikix-commands*
                     when (equal (getf c :menu) group) collect (vikix-command-menu-entry c))))

(defun vikix-command-apply (command)
  "Bind COMMAND's key and put it in the menu now: for one defined after
Vikix's own were (user.lisp). Its key is taken from whatever had it; its
menu entry joins the list before the last one, Power, as a plugin's does,
and the menu shows it in its section."
  (dolist (binding (vikix-command-bindings command))
    (set '*vikix-bindings*
         (append (remove (first binding) (symbol-value '*vikix-bindings*) :key #'first :test #'equal)
                 (list binding)))
    (funcall 'vikix-bind (first binding) (second binding)))
  (when (and (getf command :menu) (boundp '*vikix-menu*))
    (let* ((entry (vikix-command-menu-entry command))
           (menu (remove (first entry) (symbol-value '*vikix-menu*) :key #'first :test #'equal)))
      (set '*vikix-menu* (append (butlast menu) (list entry) (last menu))))))

(defun vikix-register-command (name does options)
  "Add the command NAME to the registry, in place of one of that name."
  (vikix-command-check name does options)
  (let* ((command (list* :name name :does does
                         ;; Where it is written, for "why did that happen?" (why.lisp).
                         :file (and (or (and (boundp '*vikix-loading-file*) (symbol-value '*vikix-loading-file*)) *load-truename*) (ignore-errors (namestring (or (and (boundp '*vikix-loading-file*) (symbol-value '*vikix-loading-file*)) *load-truename*))))
                         :line (and (or (and (boundp '*vikix-loading-file*) (symbol-value '*vikix-loading-file*)) *load-truename*) (boundp '*vikix-load-line*) (symbol-value '*vikix-load-line*))
                         (copy-list options)))
         (old (position (string name) *vikix-commands*
                        :key (lambda (c) (string (getf c :name))) :test #'string-equal)))
    (if old
        (setf (nth old *vikix-commands*) command)
        (setf *vikix-commands* (append *vikix-commands* (list command))))
    (when *vikix-registry-live*
      (vikix-command-apply command))
    name))

(defmacro define-vikix-command (name does &rest options)
  "Define the command NAME: DOES is what it does, in the key card's words;
OPTIONS are :run or :do, :key, :card, :menu, :label, :needs, :agent (the head
of registry.lisp says what each is). A mistake is an error as the file loads."
  `(vikix-register-command ',name ,does ',options))

;;; --- Vikix's commands -------------------------------------------------------------------------

;;; Programs

(define-vikix-command terminal "Terminal"
  :run "vikix-terminal" :key "s-RET")
(define-vikix-command launcher "Launcher: start any program"
  :run "exec rofi -show drun" :key "s-d")
(define-vikix-command palette "Everything in one box: windows, commands, projects, web apps, layouts, programs; > @ # ? / search the menu, desks, docs, what, files"
  :run "exec vikix-palette" :key "s-SPC")
(define-vikix-command browser "Browser"
  :run "exec firefox" :key "s-w")
(define-vikix-command files "Files in Esploro: the one on this workspace, or a new one here (PCManFM without Esploro)"
  :run "vikix-esploro" :key "s-e")
(define-vikix-command spacefm "Files in SpaceFM: tabs and split panes"
  :run "exec spacefm" :key "s-M-s")
(define-vikix-command pcmanfm "Files in PCManFM"
  :run "exec pcmanfm" :key "s-M-e")
(define-vikix-command files-new "Files in a new Esploro window, beside the others"
  :run "exec esploro --new" :key "s-M-E")
(define-vikix-command files-reveal "Reveal the file behind this window, in Esploro"
  :run "exec esploro reveal" :key "s-M-r")
(define-vikix-command files-commands "Esploro's commands for the file behind this window, in rofi"
  :run "exec vikix-esploro menu" :key "s-M-x")
(define-vikix-command project "Projects: pick one; a terminal in its folder, its log in the editor"
  :run "exec vikix-project pick" :key "s-M-p"
  :menu "Work" :label "Projects: open one (a terminal there, its log in the editor)")
(define-vikix-command back "Where was I? The project you were on, its next step, what isn't saved"
  :run "exec vikix-back --card" :menu "Work"
  :label "Where was I? (the project, its next step, what isn't saved)")
(define-vikix-command day "My day: each project's time, entries and commits (kept in ~/journal)"
  :do (vikix-in-terminal "vikix day")
  :menu "Work")
(define-vikix-command passwords "Passwords (Bitwarden): pick a login, Enter types it (vikix add bitwarden)"
  :run "exec vikix-bitwarden pick" :key "s-M-v")
(define-vikix-command agent "AI agent: here in a terminal, or at a new desk of its own"
  :run "vikix-agent-choice" :key "s-a"
  :menu "AI" :label "AI agent: here, or at a new desk")
(define-vikix-command desks "Desk keys: n new, w a worker at one, r take up again, c close, h handoff, o the Office, t test, p pause or go, i a note, x dismiss"
  :run "vikix-map desks" :key "s-M-d" :card "AI & voice")
(define-vikix-command agent-desk "A new desk: pick a project and a topic; a worktree to itself, and a worker at it when you give it a task"
  :run "exec vikix-agents desk" :map "desks n"
  :menu "AI" :label "Agents: a new desk, with a worker when you give it a task")
(define-vikix-command agent-desk-worker "A worker at a desk: pick the desk, type the task; an agent on it there, on a workspace to itself"
  :run "exec vikix-agents worker --menu" :map "desks w"
  :menu "AI" :label "Agents: a worker at a desk (pick the desk, type the task)")
(define-vikix-command agent-desk-resume "Take a desk up again: pick one; its handoff shown, its agent's conversation resumed where it can be"
  :run "exec vikix-agents resume --menu" :map "desks r"
  :menu "AI" :label "Agents: take a desk up again (its handoff, the conversation resumed)")
(define-vikix-command agent-desk-close "Close an agent's desk whose work is in: pick one; its worktree and branch go"
  :run "exec vikix-agents close" :map "desks c"
  :menu "AI" :label "Agents: close a desk (its worktree and branch, once the work is in)")
(define-vikix-command agent-handoff "A desk's handoff: the task, what the agent did and left, its checks; pick a desk"
  :run "exec vikix-agents handoff --menu" :map "desks h"
  :menu "AI" :label "Agents: a desk's handoff (task, status, what is left)")
(define-vikix-command office "The Office: tasks, desks and agents; continue unfinished work"
  :run "exec vikix-agents office" :map "desks o"
  :menu "AI" :label "Office: tasks, desks and agents")
(define-vikix-command agent-desk-test "A desk's tests run (vikix agents test): pick one; the result goes into its handoff and its agent's inbox"
  :run "exec vikix-agents test --menu" :map "desks t"
  :menu "AI" :label "Agents: test a desk's work (the result into its handoff and inbox)")
(define-vikix-command agent-desk-pause "Pause a desk's agent at its next tool call, or let a paused one go: pick one"
  :run "exec vikix-agents pause --menu" :map "desks p"
  :menu "AI" :label "Agents: pause a desk's agent, or let it go")
(define-vikix-command agent-desk-tell "A note for a desk's agent, delivered at its next tool call: pick the desk, type the note"
  :run "exec vikix-agents tell --menu" :map "desks i"
  :menu "AI" :label "Agents: a note for a desk's agent")
(define-vikix-command agent-desk-dismiss "Dismiss a desk's agent, keeping the desk and its files: pick one"
  :run "exec vikix-agents dismiss --menu" :map "desks x"
  :menu "AI" :label "Agents: dismiss a desk's agent (the desk stays)")
(define-vikix-command agents "Agents: who is running, on what, and which waits for you; pick one to go to it"
  :run "vikix-agents-pick"
  :menu "AI" :label "Agents: who is running, and go to one")
(define-vikix-command dictate "Dictation: speak, then Super+F9 again types it"
  :run "exec vikix-dictate toggle" :key "s-F9"
  :menu "AI" :label "Dictation: start, or stop and type it" :needs "~/.local/opt/whisper.cpp/build/bin/whisper-cli")
(define-vikix-command dictate-cancel "Dictation: stop listening, type nothing"
  :run "exec vikix-dictate cancel" :key "s-S-F9")
(define-vikix-command voice-ask "Voice: speak, then Super+F10 again: the AI answers aloud"
  :run "exec vikix-dictate toggle ask" :key "s-F10"
  :menu "AI" :label "Voice: talk to the AI" :needs "~/.local/bin/piper")
(define-vikix-command voice-agent "Voice: speak, then Super+F11 again: it goes to the agent"
  :run "exec vikix-dictate toggle agent" :key "s-F11"
  :menu "AI" :label "Voice: talk to the agent" :needs "~/.local/bin/piper")
(define-vikix-command voice-quiet "Voice: stop the AI talking"
  :run "exec vikix-voice quiet" :key "s-S-F10"
  :menu "AI" :label "Voice: stop talking" :needs "~/.local/bin/piper")
(define-vikix-command voice-new "Voice: a new conversation"
  :run "exec vikix-voice new"
  :menu "AI" :needs "~/.local/bin/piper")
(define-vikix-command ask "AI on the selected text: ask, proofread, rewrite, translate, explain"
  :run "exec vikix-ask" :key "s-i"
  :menu "AI" :label "AI on the selected text")
(define-vikix-command local-ai-chat "Local AI: talk to a model"
  :run "exec vikix-local-ai chat --rofi"
  :menu "AI" :needs "~/.local/opt/ollama/bin/ollama")
(define-vikix-command local-ai-models "Local AI: choose a model"
  :run "exec vikix-local-ai models --rofi"
  :menu "AI" :needs "~/.local/opt/ollama/bin/ollama")
(define-vikix-command local-ai-stop "Local AI: unload the model"
  :run "exec vikix-local-ai stop --notify"
  :menu "AI" :needs "~/.local/opt/ollama/bin/ollama")
(define-vikix-command door "Door: the Lisp an agent sent that waits for your yes (run it as you, or drop it)"
  :run "vikix-door"
  :menu "AI")
(define-vikix-command emacs "Emacs: a new window"
  :run "exec emacsclient -c -a ''" :key "s-x")
(define-vikix-command clipboard "Clipboard history: pick to paste again"
  :run "exec env CM_LAUNCHER=rofi clipmenu" :key "s-c"
  :menu "Work" :label "Clipboard history")
(define-vikix-command emoji "Emoji: pick one to type it (Ctrl+c copies)"
  :run "exec vikix-rofi emoji" :key "s-period"
  :menu "Work" :label "Emoji")
(define-vikix-command calculator "Calculator: Enter copies the answer"
  :run "exec vikix-rofi calc" :key "s-equal"
  :menu "Work" :label "Calculator")
(define-vikix-command learn-c "Learn C: the lesson, and a shell beside it"
  :do (vikix-learn-open "c")
  :menu "Work")
(define-vikix-command jupyter "JupyterLab (in ~/dev)"
  :run "exec vikix-jupyter"
  :menu "Work" :needs "~/dev/python/.venv/bin/jupyter")

;;; Notifications

(define-vikix-command notification-last "Notifications: the last one again"
  :run "exec dunstctl history-pop" :key "s-n"
  :menu "Notifications")
(define-vikix-command notification-pick "Notifications: pick an earlier one"
  :run "exec vikix-notifications" :key "s-N"
  :menu "Notifications" :label "Notifications: earlier ones")
(define-vikix-command notifications-close "Notifications: close all"
  :run "exec dunstctl close-all" :key "s-C-n"
  :menu "Notifications")
(define-vikix-command quiet "Do not disturb on/off"
  :run "vikix-quiet" :key "s-C-d"
  :menu "Notifications" :agent t)
;; No key: the key card is full (vikix used never says which keys could go).
;; Super+F1 and Super+Space find it by "focus".
(define-vikix-command focus-time "Focus time: 25 minutes with do not disturb, then a break; again stops it"
  :run "vikix-focus-time"
  :menu "Notifications" :label "Focus time: 25 minutes with do not disturb, then a break" :agent t)
(define-vikix-command focus-time-long "Focus time: 50 minutes"
  :do (run-commands "vikix-focus-time 50")
  :menu "Notifications")

;;; Windows

(define-vikix-command close-window "Close window"
  :run "delete" :key "s-q")
(define-vikix-command fullscreen "Fullscreen on/off"
  :run "fullscreen" :key "s-f"
  :agent t)
(define-vikix-command last-window "The last window again: flips between two"
  :run "vikix-last-window" :key "s-TAB")
;; Super+` and Super+Shift+` go through every window on the workspace: to
;; its frame when it's showing, into this frame when it's hidden. Shift+` is
;; ~ on the keyboard, so StumpWM knows that key as asciitilde.
(define-vikix-command next-window "Next window on this workspace, through all of them"
  :run "next" :key "s-grave")
(define-vikix-command previous-window "Previous window on this workspace"
  :run "prev" :key "s-asciitilde")
(define-vikix-command focus-left "Focus left"
  :run "vikix-focus left" :key "s-h"
  :agent t)
(define-vikix-command focus-down "Focus down"
  :run "vikix-focus down" :key "s-j"
  :agent t)
(define-vikix-command focus-up "Focus up"
  :run "vikix-focus up" :key "s-k"
  :agent t)
(define-vikix-command focus-right "Focus right"
  :run "vikix-focus right" :key "s-l"
  :agent t)
(define-vikix-command move-left "Move window left"
  :run "vikix-move left" :key "s-H")
(define-vikix-command move-down "Move window down"
  :run "vikix-move down" :key "s-J")
(define-vikix-command move-up "Move window up"
  :run "vikix-move up" :key "s-K")
(define-vikix-command move-right "Move window right"
  :run "vikix-move right" :key "s-L")

;;; The arrows walk the workspaces, in the bar's order and round the ends; h j k l
;;; stay the windows' inside one. A workspace past the nine has no digit: the arrows
;;; reach it. Shift takes the window along, and you go with it. Up and Down are free:
;;; workspaces sit side by side. (The arrows did what h j k l do, before.)

(define-vikix-command workspace-left "Workspace on the left (round the ends)"
  :run "vikix-workspace-step left" :key "s-Left"
  :agent t)
(define-vikix-command workspace-right "Workspace on the right"
  :run "vikix-workspace-step right" :key "s-Right"
  :agent t)
(define-vikix-command carry-left "Take this window to the workspace on the left, and go with it (on a strip: its whole column)"
  :run "vikix-workspace-carry left" :key "s-S-Left")
(define-vikix-command carry-right "Take this window to the workspace on the right, and go with it"
  :run "vikix-workspace-carry right" :key "s-S-Right")

;;; Frames (StumpWM's splits), strips, layouts

(define-vikix-command layout "Layout keys: m main, s strip, g grid, t tiles, w width, h height, u undo, r redo, Space the menu"
  :run "vikix-map layout" :key "s-C-SPC" :card "Windows & frames")
(define-vikix-command split "Split: side by side (on a strip: this column fills the room the others leave)"
  :run "vikix-split" :key "s-b")
(define-vikix-command split-below "Split: one above the other (on a strip: this window taller in its column)"
  :run "vikix-split below" :key "s-v")
(define-vikix-command width-or-remove "Remove this split (on a strip: the column's width; in main and stack: the main window's)"
  :run "vikix-width-or-remove" :key "s-r" :map "layout w")
(define-vikix-command height "On a strip: this window taller in its column (a third, half, two thirds, then even again)"
  :run "vikix-height" :map "layout h")
(define-vikix-command strip-first "On a strip: the first column"
  :run "vikix-focus-end first" :key "s-Home")
(define-vikix-command strip-last "On a strip: the last column"
  :run "vikix-focus-end last" :key "s-End")
(define-vikix-command pin "On a strip: pin this column to the left edge, the others scroll beside it; again unpins"
  :run "vikix-pin" :key "s-backslash")
(define-vikix-command stack-left "On a strip: into the column on the left, or out of a shared one"
  :run "vikix-stack left" :key "s-bracketleft")
(define-vikix-command stack-right "On a strip: into the column on the right, or out of a shared one"
  :run "vikix-stack right" :key "s-bracketright")
(define-vikix-command overview "Every workspace drawn small, each window a box: pick one (g there: this workspace in a real grid)"
  :run "vikix-overview" :key "s-o"
  :menu "Windows" :label "Overview: every workspace, drawn small")
(define-vikix-command grid "Grid mode on/off: windows stay tiled in a grid as they open and close"
  :run "vikix-grid" :key "s-O" :map "layout g"
  :agent t)
(define-vikix-command main "Main and stack (master and stack) on/off: this window on the left, the rest in a column beside it"
  :run "vikix-main" :key "s-C-m" :map "layout m"
  :agent t)
(define-vikix-command tiles "Tiles: the plain layout, splits you make yourself"
  :run "vikix-layout-pick tiles" :map "layout t"
  :agent t)
(define-vikix-command layout-pick "Layout: pick this workspace's (tiles, main and stack, grid, strip, or one you saved)"
  :run "vikix-layout-pick" :map "layout SPC"
  :menu "Windows" :label "Layout: pick this workspace's (tiles, main and stack, grid, strip)")
(define-vikix-command layout-save "Layout: save this workspace's, by name"
  :run "vikix-layout-save-command"
  :menu "Windows")
(define-vikix-command layout-restore "Layout: put this workspace back as one you saved"
  :run "vikix-layout-restore-command"
  :menu "Windows")
(define-vikix-command viri "This workspace as a strip that scrolls sideways (Viri), or tiled again"
  :run "vikix-viri" :map "layout s"
  :menu "Windows" :label "Strip: this workspace scrolls sideways (Viri), or tiled again" :agent t)
(define-vikix-command solo "Focus: only this window; again puts the others back (on a strip: its column's windows as tabs)"
  :run "vikix-solo" :key "s-z"
  :agent t)
(define-vikix-command drawer "The drawer: a few everyday programs at the screen's edge, here; again puts it away"
  :run "vikix-drawer" :key "s-C-b"
  :agent t)

;;; Gaps, layout undo, finding windows, floating

(define-vikix-command gaps "Gaps around windows on/off"
  :run "toggle-gaps" :key "s-C-g"
  :menu "Windows" :agent t)
(define-vikix-command layout-undo "Undo the last layout change (splits, moves)"
  :run "vikix-layout-undo" :key "s-u" :map "layout u"
  :agent t)
(define-vikix-command layout-redo "Redo the layout change"
  :run "vikix-layout-redo" :key "s-U" :map "layout r"
  :agent t)
(define-vikix-command go-to-window "Go to any window, on any workspace"
  :run "vikix-go-to-window" :key "s-g"
  :menu "Windows" :label "Find a window, any workspace")
;; Super+0 is bound beside the digits in keys.lisp, so the key card keeps
;; its rows (it is full): here for the menu and the palette.
(define-vikix-command workspace "Go to a workspace by name; a new name makes one"
  :run "vikix-workspace"
  :menu "Windows" :label "Workspace: go to one by name, or make one")
(define-vikix-command bring-window "Bring any window here, from any workspace"
  :run "vikix-bring-window" :key "s-G")
(define-vikix-command gather "Bring every window of another workspace here, as ordinary windows: tiled, none floating"
  :run "vikix-gather"
  :menu "Windows" :label "Bring every window of another workspace here")
(define-vikix-command refile-workspaces "Refile the workspaces: from 2 on, each moves left into the empty ones, keeping its layout"
  :run "vikix-refile-workspaces"
  :menu "Windows" :label "Workspace: refile them, each moved left into an empty one")
(define-vikix-command pointer "Move the pointer to this window"
  :run "vikix-pointer" :key "s-p"
  :agent t)
(define-vikix-command float "Float this window, or tile it again (Super+drag moves it)"
  :run "vikix-float" :key "s-t")
(define-vikix-command remember "Remember this window here: the rule for where it is, written for you (shown first)"
  :run "vikix-remember" :key "s-T"
  :menu "Windows" :label "Remember this window here: write the rule for where it is")
(define-vikix-command rules "Rules: the list, one off or on, why this window is where it is"
  :run "vikix-rules"
  :menu "Windows")
(define-vikix-command resume "Bring my windows back, as they were before the restart"
  :run "vikix-resume"
  :menu "Windows")
(define-vikix-command titlebars "Title bars on/off"
  :run "vikix-titlebars" :key "s-C-y"
  :agent t)
(define-vikix-command title "Rename this window"
  :run "vikix-title" :key "s-\"")

;;; Vikix, and help

(define-vikix-command menu "Vikix menu"
  :run "vikix-menu" :key "s-m")
(define-vikix-command keys-card "Every key at a glance, grouped; any key closes it"
  :run "vikix-keys-card" :key "s-slash")
(define-vikix-command keys "Search the keys, and run one"
  :run "vikix-keys" :key "s-F1"
  :menu "Help" :label "Keyboard shortcuts")
(define-vikix-command describe-key "What does a key do?"
  :run "describe-key"
  :menu "Help")
(define-vikix-command commands "All commands"
  :run "vikix-commands"
  :menu "Help")
(define-vikix-command why "Why did that happen? The key, rule or command behind the last things: edit it, or take it back"
  :run "vikix-why" :key "s-?"
  :menu "Help" :label "Why did that happen? What the desktop just did, and what made it")
(define-vikix-command what "What is this? The field of the bar the pointer is on, or the window in front: what it is doing now, and where it is explained"
  :run "vikix-what" :key "s-M-?"
  :menu "Help" :label "What is this? The window in front, or the bar's field you point at")
(define-vikix-command used "What you use: the keys you press most, and those you never have"
  :do (vikix-in-terminal "vikix used")
  :menu "Help")
(define-vikix-command guide "Vikix guide"
  :do (run-shell-command (format nil "emacsclient -c -a '' -e '(info \"~~/.local/share/info/vikix.info\")' || ~a -e info -f ~~/.local/share/info/vikix.info" *vikix-terminal*))
  :menu "Help")
(define-vikix-command guide-browser "Vikix guide in the browser, with diagrams"
  :run "exec vikix-docs-open ~/.local/share/vikix/guide/index.html"
  :menu "Help" :needs "~/.local/share/vikix/guide/index.html")
(define-vikix-command docs "Search every document: Vikix's guides, your projects and notes, man pages"
  :run "exec vikix-docs pick" :key "s-F2"
  :menu "Help" :label "Search every document (guides, projects, notes, man pages)")
(define-vikix-command docs-page "Every document as a page in Nyxt"
  :run "exec vikix-docs page"
  :menu "Help" :needs "nyxt")
(define-vikix-command dev-docs "Programming docs (offline)"
  :run "exec vikix-docs-open ~/dev/index.html"
  :menu "Help" :needs "~/dev/index.html")
(define-vikix-command zeal "Zeal: search the docs"
  :run "exec zeal"
  :menu "Help" :needs "zeal")
(define-vikix-command lock "Lock the screen"
  :run "exec vikix-lock" :key "s-ESC")
(define-vikix-command power "Power: lock, suspend, log out, reboot, power off"
  :run "vikix-power" :key "s-S-ESC"
  :menu "Power")

;;; The desktop: its look, its bar, what it does by itself

(define-vikix-command theme "Theme"
  :run "vikix-pick-theme"
  :menu "Desktop")
(define-vikix-command wallpaper "Wallpaper"
  :run "exec vikix-wallpaper pick"
  :menu "Desktop")
(define-vikix-command bar "The bar on/off"
  :run "vikix-bar" :key "s-C-h"
  :menu "Desktop" :label "The bar on/off (hide it for the whole screen)" :agent t)
(define-vikix-command tray "Tray on/off: network and Bluetooth icons in the bar"
  :run "vikix-tray"
  :menu "Desktop" :agent t)
(define-vikix-command awake "Keep awake on/off: no lock, dark screen or suspend"
  :run "vikix-awake" :key "s-C-a"
  :menu "Desktop" :label "Keep awake on/off" :agent t)
(define-vikix-command nightlight "Night light on/off: a warmer screen in the evening"
  :run "vikix-nightlight" :key "s-C-l"
  :menu "Desktop" :label "Night light on/off" :agent t)

;;; The system: the network, sound, screens, printers, drives

(define-vikix-command wifi "Wi-Fi: pick a network (scans first)"
  :do (run-shell-command "vikix-wifi")
  :menu "System")
(define-vikix-command network "Network: everything else (nmtui)"
  :do (run-shell-command (format nil "~a -e nmtui" *vikix-terminal*))
  :menu "System")
(define-vikix-command network-use "Network use: which program is using it (nethogs)"
  :do (run-shell-command (format nil "~a -e sudo nethogs" *vikix-terminal*))
  :menu "System" :needs "nethogs")
(define-vikix-command firewall "Firewall: on or off, and what it lets in"
  :do (vikix-in-terminal "vikix firewall")
  :menu "System" :needs "ufw")
(define-vikix-command bluetooth "Bluetooth"
  :run "exec blueman-manager"
  :menu "System")
(define-vikix-command sound "Sound (pavucontrol)"
  :run "exec pavucontrol"
  :menu "System")
(define-vikix-command screens "Screens: extend, mirror, one only, arrange (a newly plugged one lights up by itself)"
  :run "vikix-screens-pick" :key "s-C-p"
  :menu "System" :label "Screens: extend, mirror, one only, arrange")
(define-vikix-command screens-arrange "Screens: arrange (arandr)"
  :run "exec arandr"
  :menu "System")
(define-vikix-command screens-save "Screens: save this layout"
  :run "vikix-screens-save"
  :menu "System")
(define-vikix-command printers "Printers"
  :run "exec system-config-printer"
  :menu "System" :needs "system-config-printer")
(define-vikix-command eject "Eject a USB drive: pick it, then pull it out safely"
  :run "exec vikix-drives eject" :key "s-C-e"
  :menu "System" :label "Eject a drive")
;; Then the keys that depend on the layout (Super+Shift+digit) again, a
;; moment later: StumpWM must hear of the new layout first.
(define-vikix-command keyboard "Apply keyboard settings"
  :do (progn (run-shell-command "vikix-keyboard") (run-with-timer 2 nil 'vikix-bind-workspace-keys))
  :menu "System")
(define-vikix-command firmware "Firmware updates"
  :do (run-shell-command (format nil "~a -e sh -c 'vikix firmware update; printf \"\\nEnter closes this window. \"; read x'" *vikix-terminal*))
  :menu "System")

;;; Screenshots: the modifier picks what, Shift keeps it in a file (~/Pictures/Screenshots)
;;; instead of the clipboard.

(define-vikix-command screenshot-area "Screenshot of an area, to the clipboard"
  :run "exec vikix-screenshot area clip" :key "Print")
(define-vikix-command screenshot-area-file "Screenshot of an area, to a file"
  :run "exec vikix-screenshot area file" :key "S-Print")
(define-vikix-command screenshot-window "Screenshot of this window, to the clipboard"
  :run "exec vikix-screenshot window clip" :key "C-Print")
(define-vikix-command screenshot-window-file "Screenshot of this window, to a file"
  :run "exec vikix-screenshot window file" :key "C-S-Print")
(define-vikix-command screenshot-screen "Screenshot of the whole screen, to the clipboard"
  :run "exec vikix-screenshot screen clip" :key "s-Print")
(define-vikix-command screenshot-screen-file "Screenshot of the whole screen, to a file"
  :run "exec vikix-screenshot screen file" :key "s-S-Print")
(define-vikix-command record "Record a video of an area or a window; again to stop"
  :run "vikix-record area" :key "s-C-v")
(define-vikix-command capture "Screenshot or record: all the choices"
  :run "vikix-capture" :key "s-C-Print"
  :menu "Desktop" :label "Screenshot or record the screen")

;;; The laptop's function keys. vikix-osd changes the level and shows a bar for it
;;; (bin/vikix-osd); the vikix-volume command also updates the volume in the mode line.

(define-vikix-command volume-up "Volume up"
  :run "vikix-volume up" :key "XF86AudioRaiseVolume")
(define-vikix-command volume-down "Volume down"
  :run "vikix-volume down" :key "XF86AudioLowerVolume")
(define-vikix-command mute "Mute"
  :run "vikix-volume mute" :key "XF86AudioMute")
(define-vikix-command mic-mute "Microphone mute"
  :run "vikix-volume mic" :key "XF86AudioMicMute")
(define-vikix-command brightness-up "Brightness up"
  :run "exec vikix-osd brightness up" :key "XF86MonBrightnessUp")
(define-vikix-command brightness-down "Brightness down"
  :run "exec vikix-osd brightness down" :key "XF86MonBrightnessDown")
(define-vikix-command screens-display-key "Screens: extend, mirror, one only (the laptop's display key)"
  :run "vikix-screens-pick" :key "XF86Display")

;;; Parts of Super+m that no key of Vikix's opens: Start, Vikix, Apps.

(define-vikix-command welcome "Welcome: first steps"
  :run "vikix-welcome"
  :menu "Start")
(define-vikix-command add-software "Add software: languages, editors, office ..."
  :run "vikix-add-software"
  :menu "Start")
(define-vikix-command install-program "Install a program"
  :do (vikix-in-terminal "vikix pkg add")
  :menu "Start")
(define-vikix-command remove-program "Remove a program"
  :do (vikix-in-terminal "vikix pkg drop")
  :menu "Start")
(define-vikix-command update "Update Vikix"
  :run "vikix-update"
  :menu "Vikix")
(define-vikix-command reload "Reload config"
  :run "vikix-reload"
  :menu "Vikix" :agent t)
(define-vikix-command backup "Backup now"
  :run "exec vikix-backup now --notify"
  :menu "Vikix")
(define-vikix-command undo "Undo: my files back one snapshot"
  :run "vikix-undo"
  :menu "Vikix")
(define-vikix-command memory "Memory: what uses it, and what's left over"
  :do (vikix-in-terminal "vikix memory")
  :menu "Vikix")
(define-vikix-command memory-clean "Memory: end the left-over programs"
  :do (vikix-in-terminal "vikix memory clean")
  :menu "Vikix")
(define-vikix-command diagnose "Something's wrong? Ask the agent"
  :do (vikix-in-terminal "vikix diagnose")
  :menu "Vikix")
(define-vikix-command debug "A report of what's going on (vikix debug)"
  :do (vikix-in-terminal "vikix debug")
  :menu "Vikix")
(define-vikix-command dropbox "Dropbox"
  :run "vikix-dropbox"
  :menu "Apps" :needs "dropbox")
(define-vikix-command cuis "Cuis Smalltalk: a live image, changeable while it runs"
  :run "exec cuis"
  :menu "Apps" :needs "~/.local/bin/cuis")
(define-vikix-command windows-vm "Windows (the VM)"
  :do (run-shell-command (format nil "vikix-windows open || ~a -e sh -c 'vikix windows status; printf \"\\nEnter closes this window. \"; read x'" *vikix-terminal*))
  :menu "Apps" :needs "virt-viewer")

;;; --- Running one, and what agents are offered -------------------------------------------------

(defun vikix-command-here-p (command)
  "True unless COMMAND names what it needs and that isn't on this machine
(the menu's own test: vikix-menu-entry-here-p, commands.lisp)."
  (or (null (getf command :needs))
      (not (fboundp 'vikix-menu-entry-here-p))
      (and (funcall 'vikix-menu-entry-here-p (list nil nil (getf command :needs))) t)))

(defun vikix-run-command (name)
  "Run the command called NAME, as its key or its menu entry would."
  (let ((command (or (vikix-command name)
                     (error "There is no command called ~a." name))))
    (if (getf command :run)
        (run-commands (getf command :run))
        (eval (getf command :do)))
    (getf command :name)))

(defun vikix-agent-commands ()
  "The commands an agent may run: those marked :agent whose needs are here."
  (remove-if-not (lambda (c) (and (getf c :agent) (vikix-command-here-p c))) *vikix-commands*))

(defun vikix-agent-run (name)
  "Run the command NAME for an agent, if it is one an agent may run: the
answer in words either way. Never an error: the agent reads the answer."
  (let ((command (vikix-command name)))
    (cond ((null command)
           (format nil "refused: there is no command called ~a (the commands tool lists them)" name))
          ((not (getf command :agent))
           (format nil "refused: ~(~a~) (~a) is not for agents to run; the user has it~@[ on ~a~]"
                   (getf command :name) (getf command :does)
                   (and (getf command :key) (fboundp 'vikix-pretty-key)
                        (funcall 'vikix-pretty-key (getf command :key)))))
          ((not (vikix-command-here-p command))
           (format nil "refused: ~(~a~) needs ~a, which isn't on this machine" (getf command :name) (getf command :needs)))
          (t (handler-case
                 (progn (when (fboundp 'vikix-why-agent-ran)   ; why.lisp: noted, with what it runs
                          (ignore-errors (funcall 'vikix-why-agent-ran command)))
                        (progv '(*vikix-why-cause*) '(:agent)
                          (vikix-run-command name))
                        (format nil "done: ~(~a~) (~a)" (getf command :name) (getf command :does)))
               (error (e) (format nil "failed: ~(~a~): ~a" (getf command :name) e)))))))
