;;;; help.lisp — finding your way: the keys, and every command.
;;;;
;;;; Two ways to see the keys, both from *vikix-bindings*. The card is for
;;;; a glance: every key at once, grouped, gone at the next key. The menus
;;;; are for searching: type to narrow the list, Enter to run the
;;;; highlighted entry, Escape to close. So that help is also a launcher —
;;;; you can do the thing from the list you looked it up in.
;;;;
;;;;   vikix-keys-card (s-/)   every Vikix key on one card, grouped
;;;;   vikix-keys      (s-F1)  every Vikix key, searchable; pick one to run it
;;;;   vikix-commands          every StumpWM command, with its description
;;;;   vikix-prefix-keys       StumpWM's own keys, after the prefix Ctrl+t
;;;;   describe-key      (StumpWM's own) press a key, see what it does
;;;;
;;;; And which-key-mode: after Ctrl+t, StumpWM shows the keys that can follow.

(in-package :stumpwm)

(defparameter *vikix-key-names*
  '(("RET" . "Return") ("TAB" . "Tab") ("ESC" . "Escape") ("Print" . "Print Screen")
    ("period" . ".") ("equal" . "=") ("slash" . "/") ("SPC" . "Space")
    ("grave" . "`") ("asciitilde" . "Shift+`") ("bracketleft" . "[") ("bracketright" . "]") ("backslash" . "\\")
    ("XF86AudioRaiseVolume"  . "Volume-up key")
    ("XF86AudioLowerVolume"  . "Volume-down key")
    ("XF86AudioMute"         . "Mute key")
    ("XF86AudioMicMute"      . "Mic-mute key")
    ("XF86MonBrightnessUp"   . "Brightness-up key")
    ("XF86MonBrightnessDown" . "Brightness-down key"))
  "Key names as StumpWM writes them, and as they are printed on the keyboard.")

(defun vikix-pretty-key (key)
  "\"s-C-RET\" -> \"Super+Ctrl+Return\". Modifiers are only read at the
front, so a name like Brightness-up is never mistaken for one."
  (let ((mods "") (rest key))
    (loop for (prefix . word) in '(("s-" . "Super+") ("C-" . "Ctrl+") ("M-" . "Alt+") ("S-" . "Shift+"))
          do (loop while (and (> (length rest) 2)
                              (string= prefix rest :end2 2))
                   do (setf mods (concatenate 'string mods word)
                            rest (subseq rest 2))))
    ;; A capital letter means Shift is held: "s-H" is Super+Shift+h.
    (when (and (= (length rest) 1) (upper-case-p (char rest 0)))
      (setf mods (concatenate 'string mods "Shift+")
            rest (string-downcase rest)))
    (concatenate 'string mods
                 (or (cdr (assoc rest *vikix-key-names* :test #'string=)) rest))))

;; Keys bound some other way than from *vikix-bindings* (the workspace
;; keys are bound in a loop in keys.lisp), as the help writes them.
(defparameter *vikix-extra-keys*
  '(("Super+1 ... Super+9" "Go to workspace 1-9" "grouplist")
    ("Super+Shift+1 ... 9" "Send window to workspace 1-9 (on a strip: its whole column)" "vikix-send")
    ("Ctrl+t then ?" "StumpWM's own keys (after the prefix)" "vikix-prefix-keys")
    ;; Not one of StumpWM's keys: rescue.lisp reads it on a connection of
    ;; its own, so it works when these don't.
    ("Super+Ctrl+Alt+Escape" "Free a stuck desktop (it works when no other key does)" "vikix-rescue"))
  "Each entry: the key as the help shows it, a description, the command.")

;;; Groups, for the card. A key's group comes from its command, so a new
;;; key lands in the right group without anyone listing it here: the
;;; program a command starts (exec firefox -> "firefox"), or the StumpWM
;;; command (move-focus left -> "move-focus"). An entry can also name its
;;; group itself, as a fourth element:
;;;   ("s-F12" "exec obsidian" "Obsidian" "Apps")
;;; Any other program started with exec is an app; anything else is Other.
(defparameter *vikix-key-groups*
  '(("Apps" "vikix-terminal" "rofi" "firefox" "pcmanfm" "spacefm"
     "emacsclient" "clipmenu" "vikix-rofi" "vikix-webapp" "vikix-esploro"
     "vikix-project")
    ("AI & voice" "vikix-agent" "vikix-ask" "vikix-dictate" "vikix-voice")
    ("Windows & frames" "delete" "fullscreen" "pull-hidden-other" "vikix-last-window" "next" "prev"
     "move-focus" "move-window" "vikix-focus" "vikix-move" "vikix-focus-end" "vikix-move-end" "vikix-pin" "vikix-viri" "vikix-width-or-remove" "vikix-height" "vikix-fill" "vikix-stack" "vikix-expose" "vikix-overview" "vikix-split" "hsplit" "vsplit" "remove" "expose" "vikix-grid" "vikix-main" "vikix-layout-pick" "vikix-solo"
     "toggle-gaps" "winner-undo" "winner-redo" "vikix-layout-undo" "vikix-layout-redo" "global-windowlist" "vikix-go-to-window"
     "global-pull-windowlist" "vikix-bring-window" "beckon" "vikix-pointer" "vikix-float" "vikix-remember" "vikix-titlebars" "vikix-title")
    ("Workspaces" "gselect" "gmove" "vikix-send" "grouplist")
    ("Notifications" "dunstctl" "vikix-notifications" "vikix-quiet")
    ("Screenshots & recording" "vikix-screenshot" "vikix-record" "vikix-capture")
    ("Sound & screen" "vikix-volume" "vikix-osd" "vikix-nightlight" "vikix-screens-pick" "vikix-bar")
    ("System" "vikix-menu" "vikix-keys" "vikix-rescue" "vikix-why" "vikix-docs" "vikix-keys-card" "vikix-prefix-keys" "vikix-pick-theme"
     "vikix-lock" "vikix-power" "vikix-awake" "vikix-drives"
     ;; The drawer is here, not with the windows: one key more there takes the
     ;; card to a fifth column, too wide for a 1366x768 laptop (tests/lisp.sh).
     "vikix-drawer"))
  "The card's groups, in the order it shows them: a name, then the programs
and commands whose keys go there. Keys that match none go in \"Apps\" when
they start a program, else in \"Other\", shown last.")

(defun vikix-command-word (command)
  "What a command is about: the program it starts, or the StumpWM command.
\"exec env CM_LAUNCHER=rofi clipmenu\" -> \"clipmenu\", \"move-focus left\" -> \"move-focus\"."
  (let ((words (loop with start = 0
                     for space = (position #\Space command :start start)
                     for word = (subseq command start space)
                     when (plusp (length word)) collect word
                     while space do (setf start (1+ space)))))
    (when (equal (first words) "exec")
      (pop words)
      (when (equal (first words) "env")
        (pop words)
        (loop while (and words (find #\= (first words))) do (pop words))))
    (or (first words) "")))

(defun vikix-key-group (command &optional group)
  "The card's group for a key running COMMAND. GROUP, when given, wins."
  (or group
      (let ((word (vikix-command-word command)))
        (car (find-if (lambda (g) (member word (rest g) :test #'string=))
                      *vikix-key-groups*)))
      (if (eql 0 (search "exec " command)) "Apps" "Other")))

;;; The rule for keys (keys.lisp has it in words): each modifier beside
;;; Super means one thing. This finds the keys that break it.

(defun vikix-key-layer (key)
  "The modifier KEY has beside Super: :ctrl, :alt, :shift or :super; nil
for a key without Super (Print, the laptop's own keys)."
  (when (eql 0 (search "s-" key))
    (let ((rest (subseq key 2)))
      (cond ((search "C-" rest :end2 (min 2 (length rest))) :ctrl)
            ((search "M-" rest :end2 (min 2 (length rest))) :alt)
            ((or (search "S-" rest :end2 (min 2 (length rest)))
                 (and (= (length rest) 1) (upper-case-p (char rest 0)))
                 (member rest '("asciitilde" "\"" "?") :test #'string=))
             :shift)
            (t :super)))))

(defun vikix-key-problem (key command &optional owner)
  "Why KEY running COMMAND breaks the rule for keys, in words; nil when it
keeps it. OWNER is :plugin or :webapp for a key of theirs."
  (let ((layer (vikix-key-layer key))
        (word (vikix-command-word command)))
    (flet ((is (list) (or (member command list :test #'string=)
                          (member word list :test #'string=))))
      (cond ((null layer) nil)
            ((is *vikix-key-switches*)
             (unless (eq layer :ctrl) "it switches something on the desktop, which is Super+Ctrl"))
            ((is *vikix-key-movers*)
             (unless (eq layer :shift) "it moves a window, which is Super+Shift"))
            (owner
             (unless (eq layer :alt)
               (format nil "a ~(~a~)'s key is Super+Alt" (if (eq owner :webapp) "web app" owner))))
            ((is *vikix-key-everyday*)
             (when (eq layer :ctrl) "Super+Ctrl is for switching something on the desktop"))
            ((eql 0 (search "exec " command))
             (unless (eq layer :alt)
               "it opens a program that isn't one of the six main apps, which is Super+Alt"))
            ;; Anything else is a command the rule doesn't know (one of
            ;; yours): it can't say.
            ))))

(defun vikix-key-problems (&optional (bindings *vikix-bindings*))
  "The keys of BINDINGS that break the rule: (KEY-AS-SAID DESCRIPTION WHY)."
  (loop for (key command description) in bindings
        for owner = (cond ((and (boundp '*vikix-plugin-keys*)
                                (find key (symbol-value '*vikix-plugin-keys*) :key #'second :test #'equal))
                           :plugin)
                          ((eql 0 (search "vikix-webapp " command)) :webapp))
        for why = (vikix-key-problem key command owner)
        when why collect (list (vikix-pretty-key key) description why)))

(defun vikix-key-entries ()
  "Every key the help shows, as (label description command group): the
entries of *vikix-bindings* (yours from user.lisp too), then the extras."
  (append
   (mapcar (lambda (b)
             (destructuring-bind (key command description &optional group) b
               (list (vikix-pretty-key key) description command
                     (vikix-key-group command group))))
           *vikix-bindings*)
   (mapcar (lambda (e)
             (destructuring-bind (label description command) e
               (list label description command (vikix-key-group command))))
           *vikix-extra-keys*)))

(defun vikix-keys-table ()
  "The rows of the key help: (label command). Built from *vikix-bindings*,
plus the workspace keys, which keys.lisp binds in a loop. The key column
is as wide as the longest key, so no key runs into its description."
  (let* ((rows (vikix-key-entries))
         (width (reduce #'max rows :key (lambda (row) (length (first row))))))
    (mapcar (lambda (row)
              (list (format nil "~va  ~a" width (first row) (second row))
                    (third row)))
            rows)))

(defcommand vikix-prefix-keys () ()
  "Show StumpWM's own keys: the ones pressed after the prefix key (Ctrl+t)."
  (display-bindings-for-keymaps (list *escape-key*) *root-map*))

(defcommand vikix-keys () ()
  "Show every Vikix key; pick one to run it."
  (let ((choice (select-from-menu (current-screen) (vikix-keys-table)
                                  "Keys (type to search): ")))
    (when choice
      (run-commands (second choice)))))

(defun vikix-first-line (string)
  (if string (subseq string 0 (or (position #\Newline string) (length string))) ""))

(defun vikix-commands-table ()
  "The rows of the command list: (label command-name), sorted by name."
  (let (rows)
    (maphash (lambda (symbol command)
               (declare (ignore command))
               (let ((name (string-downcase (symbol-name symbol))))
                 (push (list (format nil "~28a ~a" name
                                     (vikix-first-line
                                      (documentation symbol 'function)))
                             name)
                       rows)))
             *command-hash*)
    (sort rows #'string< :key #'second)))

(defcommand vikix-commands () ()
  "Show every StumpWM command with its description; pick one to run it."
  (let ((choice (select-from-menu (current-screen) (vikix-commands-table)
                                  "Commands (type to search): ")))
    (when choice
      (run-commands (second choice)))))

;;; The key card (s-/): every key at a glance.
;;;
;;; It is StumpWM's message window, so it has the theme's colours, the
;;; bar's font and the border, and sits in the middle of the monitor that
;;; has the focus. While it shows, Vikix holds the keyboard, and the next
;;; key closes it. A key that does something (Super+1, Ctrl+t, Print)
;;; also does it, so you can look and then go; Super+/ again, Escape and
;;; any other key only close it, and nothing is typed into the window
;;; underneath. Nothing waits for that key: the desktop carries on, and
;;; the card closes by itself after a minute.
;;;
;;; Not "hold Super for a second" too: StumpWM only hears a key it grabs,
;;; and grabbing Super alone would take every Super+key away from the
;;; programs (Emacs, the browser) while it's held, and leave the card to
;;; guess at timing from key-release events. Super+/ is one key, always.

(defparameter *vikix-card-description-width* 46
  "The longest description the card shows in full; longer ones are cut.")

(defparameter *vikix-card-timeout* 60
  "Seconds before the card closes by itself. Whole seconds: StumpWM's
timers break on a float.")

(defvar *vikix-card-open* nil "True while the key card shows.")
(defvar *vikix-card-timer* nil)
(defvar *vikix-card-old-handler* nil
  "The key handler there was before the card took the keys, given back after.")

(defun vikix-card-groups ()
  "The keys as (group-name . entries), in the card's order; empty groups
left out. A group an entry names that *vikix-key-groups* doesn't know
comes before Other."
  (let* ((entries (vikix-key-entries))
         (names (mapcar #'first *vikix-key-groups*)))
    (dolist (e entries)
      (unless (or (member (fourth e) names :test #'string=)
                  (string= (fourth e) "Other"))
        (setf names (append names (list (fourth e))))))
    (loop for name in (append names '("Other"))
          for rows = (remove-if-not (lambda (e) (string= (fourth e) name)) entries)
          when rows collect (cons name rows))))

(defun vikix-card-pack (groups height)
  "Lay GROUPS out in columns at most HEIGHT lines tall. A column is a list
of lines: (:heading NAME), (:key LABEL DESCRIPTION) or :blank. A group
stays in one column when it fits in one; a longer one carries on in the
next column, under its heading again."
  (let ((height (max 3 height)) (columns '()) (column '()) (used 0))
    (flet ((close-column ()
             (when column (push (nreverse column) columns))
             (setf column '() used 0))
           (add (line) (push line column) (incf used)))
      (dolist (group groups)
        (let ((size (1+ (length (rest group)))))
          ;; A new column, unless the group fits under what's there (after
          ;; a blank line), or is too long for any column anyway.
          (when (and column (> (+ used 1 size) height) (<= size height))
            (close-column))
          (when (and column (> (+ used 3) height))   ; no heading left alone
            (close-column))
          (when column (add :blank))
          (add (list :heading (first group)))
          (dolist (entry (rest group))
            (when (>= used height)
              (close-column)
              (add (list :heading (first group))))
            (add (list :key (first entry) (second entry))))))
      (close-column)
      (nreverse columns))))

(defun vikix-card-layout (groups rows chars)
  "Columns for GROUPS on a monitor ROWS lines tall and CHARS characters
wide: as short as they can be while still fitting side by side. Returns
the columns, the key width and the description width."
  (let* ((entries (loop for g in groups append (rest g)))
         (key-width (reduce #'max entries :key (lambda (e) (length (first e)))
                                          :initial-value 0))
         (desc-width (min *vikix-card-description-width*
                          (reduce #'max entries :key (lambda (e) (length (second e)))
                                                :initial-value 0)))
         (gap 4)
         (fit (max 1 (floor (+ chars gap) (+ key-width 2 desc-width gap))))
         (total (loop for g in groups sum (+ 2 (length (rest g)))))
         (columns (loop for h from (max 3 (ceiling total fit)) to (max 3 rows)
                        for packed = (vikix-card-pack groups h)
                        when (<= (length packed) fit) return packed
                        finally (return (vikix-card-pack groups rows)))))
    ;; More columns than fit side by side (a small screen): cut the
    ;; descriptions shorter, rather than run off the edge.
    (let ((room (- (floor (+ chars gap) (max 1 (length columns))) gap key-width 2)))
      (values columns key-width (max 12 (min desc-width room))))))

(defun vikix-card-cell (text width)
  "TEXT cut or padded to WIDTH characters, with StumpWM's ^ escaped."
  (let* ((cut (if (> (length text) width)
                  (concatenate 'string (subseq text 0 (max 0 (1- width))) "…")
                  text))
         (escaped (with-output-to-string (out)
                    (loop for c across cut
                          do (when (char= c #\^) (write-char #\^ out))
                             (write-char c out)))))
    (concatenate 'string escaped
                 (make-string (max 0 (- width (length cut))) :initial-element #\Space))))

(defun vikix-card-fg (&rest keys)
  "A colour code for the first of the theme's colours KEYS (:accent,
:color3 ...) that the theme has."
  (let ((colour (and (fboundp 'vikix-colour)
                     (some #'vikix-colour keys))))
    (if colour (format nil "^(:fg \"~a\")" colour) "")))

(defun vikix-card-strings (rows chars)
  "The card's lines, for a monitor ROWS lines tall and CHARS wide."
  (multiple-value-bind (columns key-width desc-width)
      (vikix-card-layout (vikix-card-groups) (- rows 5) chars)
    (let ((width (+ key-width 2 desc-width))
          (accent (vikix-card-fg :accent))
          ;; Group names in the terminal's yellow; hints in its comment
          ;; grey (the theme files say :dim is too faint for text).
          (heading (vikix-card-fg :color3 :fg))
          (hint (vikix-card-fg :color8 :subtle)))
      (flet ((line (item)
               (cond ((eq item :blank) (make-string width :initial-element #\Space))
                     ((eq (first item) :heading)
                      (concatenate 'string heading (vikix-card-cell (second item) width) "^n"))
                     (t (concatenate 'string accent (vikix-card-cell (second item) key-width) "^n  "
                                     (vikix-card-cell (third item) desc-width))))))
        (append
         (list (concatenate 'string accent "Vikix keys^n"
                            hint "   any key closes this; one that does something does it too^n")
               ;; The rule for keys, in a line (keys.lisp).
               (concatenate 'string hint "Super: everyday.  +Shift: move the window.  "
                            "+Alt: open something else.  +Ctrl: switch something.^n")
               "")
         (loop for i below (reduce #'max columns :key #'length :initial-value 0)
               collect (format nil "~{~a~^    ~}"
                               (mapcar (lambda (column)
                                         (let ((item (nth i column)))
                                           (if item (line item) (line :blank))))
                                       columns)))
         (list ""
               (concatenate 'string hint "Super+F1 searches these and runs one.  "
                            "Ctrl+t, then wait: StumpWM's own keys.^n")))))))

(defun vikix-card-size ()
  "How many lines and characters of the message font fit on the monitor
with the focus, inside the message window's border and padding."
  (let* ((screen (current-screen))
         (head (current-head))
         (font (screen-font screen))
         (border (* 2 (screen-msg-border-width screen)))
         (char-width (max 1 (/ (text-line-width font "MMMMMMMMMM") 10))))
    (values (floor (- (* (head-height head) 9/10) border (* 2 *message-window-y-padding*))
                   (max 1 (font-height font)))
            (floor (- (* (head-width head) 95/100) border (* 2 *message-window-padding*))
                   char-width))))

(defun vikix-card-opaque (on)
  "Make the message window solid (ON true) or as picom likes it again.
It never has the focus, so picom draws it at inactive-opacity, and the
windows behind show through the keys. Only while the card shows: other
messages stay as they were."
  (let ((win (screen-message-window (current-screen))))
    (if on
        (xlib:change-property win :_net_wm_window_opacity (list #xffffffff) :cardinal 32)
        (xlib:delete-property win :_net_wm_window_opacity))))

(defun vikix-keys-card-show ()
  "Draw the card. Only draws: the keyboard is left alone."
  (multiple-value-bind (rows chars) (vikix-card-size)
    (vikix-card-opaque t)
    (let ((*suppress-echo-timeout* t)
          (*record-last-msg-override* t))   ; not one of the last messages
      (echo-string-list (current-screen) (vikix-card-strings rows chars)))))

(defun vikix-keys-card-close ()
  "Close the card and give the keyboard back. Safe to call when it's closed."
  (when *vikix-card-open*
    (setf *vikix-card-open* nil)
    (when (eq *custom-key-event-handler* 'vikix-card-key)
      (setf *custom-key-event-handler* *vikix-card-old-handler*))
    (ungrab-keyboard)
    (when (timer-p *vikix-card-timer*)
      (cancel-timer *vikix-card-timer*))
    (setf *vikix-card-timer* nil)
    (unmap-message-window (current-screen))
    (vikix-card-opaque nil)
    (xlib:display-finish-output *display*)))

(defun vikix-card-key (code state)
  "The key handler while the card shows. True means the key is used up."
  (if (is-modifier code)
      t                                 ; Super going down for Super+1: stay open
      ;; The card closes whatever happens here: an error left alone would
      ;; keep the keyboard grabbed until the timeout.
      (let (command)
        (unwind-protect
             (ignore-errors
              (let ((key (code-state->key code state)))
                (setf command (find-if-not #'null
                                           (mapcar (lambda (map) (lookup-key map key))
                                                   (dereference-kmaps (top-maps)))))))
          (vikix-keys-card-close))
        ;; A key bound to something else goes on to StumpWM, which runs it.
        (not (and command
                  (not (equal command "vikix-keys-card")))))))

(defcommand vikix-keys-card () ()
  "Show every Vikix key on one card, grouped. The next key closes it."
  (if *vikix-card-open*
      (vikix-keys-card-close)
      (progn
        (vikix-keys-card-show)
        (setf *vikix-card-open* t
              *vikix-card-old-handler* *custom-key-event-handler*
              *custom-key-event-handler* 'vikix-card-key
              *vikix-card-timer* (run-with-timer *vikix-card-timeout* nil 'vikix-keys-card-close))
        (grab-keyboard (screen-key-window (current-screen))))))

;;; which-key-mode: press Ctrl+t and wait, and StumpWM lists the keys that
;;; can follow (in the theme's accent, from theme.lisp). StumpWM's command
;;; which-key-mode is a toggle, so calling it on every reload would switch
;;; it off every other time. This sets it instead. To have it off, put
;;; (vikix-which-key nil) in user.lisp.
(defun vikix-which-key (on)
  "Turn StumpWM's which-key-mode on (ON true) or off. Not a toggle."
  (if on
      (add-hook *key-press-hook* 'which-key-mode-key-press-hook)   ; adjoin: never twice
      (remove-hook *key-press-hook* 'which-key-mode-key-press-hook))
  (and on t))

(vikix-which-key t)
