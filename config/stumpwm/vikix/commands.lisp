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

;;; vikix learn: the lesson on one half of the screen, a shell in its folder
;; on the other. vikix-learn-open takes the first empty workspace, splits it
;; side by side and starts two terminals; as each window opens, a rule
;; (rules.lisp) has vikix-learn-place put it in its half by its class,
;; whichever comes first. q in the lesson pane runs vikix-learn-close: the shell goes, the
;; split with it, and you're back on the workspace you came from.

(defparameter *vikix-learn-command* "vikix-learn"
  "The program the two panes run: bin/vikix-learn, on PATH.")

(defvar *vikix-learn-panes* nil
  "While vikix learn is open: (GROUP LESSON-FRAME SHELL-FRAME FROM-GROUP).")

(defun vikix-learn-window-p (window name)
  (or (equal (window-class window) name) (equal (window-res window) name)))

(defun vikix-learn-place (window)
  "Put vikix learn's windows in their halves as they open."
  (destructuring-bind (&optional group lesson shell from) *vikix-learn-panes*
    (declare (ignore from))
    (when (and group (eq (window-group window) group))
      (let ((frame (cond ((vikix-learn-window-p window "vikix-learn-lesson") lesson)
                         ((vikix-learn-window-p window "vikix-learn-shell") shell))))
        (when (and frame (member frame (group-frames group)))
          (pull-window window frame)
          ;; The keys go to the lesson pane, whichever window opens last.
          ;; StumpWM focuses a new window after this hook, so it's done a
          ;; moment later (a whole second: a fractional delay in
          ;; run-with-timer has stopped StumpWM's event loop before).
          (run-with-timer 1 nil #'vikix-learn-focus-lesson))))))

(defun vikix-learn-focus-lesson ()
  (let ((w (vikix-learn-find-open)))
    (when (and w (eq (window-group w) (current-group)))
      (ignore-errors (focus-window w)))))

(defun vikix-learn-find-open ()
  "The lesson pane's window, on any workspace, if vikix learn is open."
  (find-if (lambda (w) (vikix-learn-window-p w "vikix-learn-lesson"))
           (screen-windows (current-screen))))

(defun vikix-learn-empty-group ()
  "The first workspace, by number, with no windows on it."
  (find-if (lambda (g) (and (typep g 'tile-group) (null (group-windows g))))
           (sort (copy-list (screen-groups (current-screen))) #'< :key #'group-number)))

(defcommand vikix-learn-open (&optional (course "c")) ((:string "Course: "))
  "vikix learn COURSE on a workspace of its own: the lesson on one half of
the screen, and a shell in its folder on the other."
  (let ((from (current-group))
        (open (vikix-learn-find-open)))
    (cond
      ((not (every (lambda (c) (or (alphanumericp c) (char= c #\-))) course))
       (message "No course called ~a" course))
      ;; Open already: go to it rather than open a second pair.
      (open
       (switch-to-group (window-group open))
       (focus-window open))
      (t
       (let ((group (or (vikix-learn-empty-group) from)))
         (unless (eq group from)
           (switch-to-group group))
         (if (not (typep group 'tile-group))
             (message "vikix learn needs a tiled workspace")
             (progn
               ;; On a workspace of your own windows (none was empty), the
               ;; split is a layout change Super+u undoes.
               (when (eq group from) (ignore-errors (vikix-record-layout)))
               (when (and (not (eq group from)) (cdr (group-frames group)))
                 (only))
               (let* ((lesson (tile-group-current-frame group))
                      (n (split-frame group :column)))
                 (if (null n)
                     (message "No room for two panes here")
                     (let ((shell (frame-by-number group n)))
                       (setf *vikix-learn-panes* (list group lesson shell from))
                       (flet ((term (class args)
                                (run-shell-command
                                 (format nil "~a --class ~a -e env VIKIX_LEARN_PANES=1 ~a ~a ~a"
                                         *vikix-terminal* class *vikix-learn-command* course args))))
                         (term "vikix-learn-lesson" "view")
                         (term "vikix-learn-shell" "shell"))))))))))))

(defcommand vikix-learn-close () ()
  "Go back to the workspace vikix learn was opened from, then close its
shell pane and the split it had."
  (destructuring-bind (&optional group lesson shell from) *vikix-learn-panes*
    (declare (ignore lesson))
    (setf *vikix-learn-panes* nil)
    (when group
      ;; Back first, while every window is still there: closing the shell
      ;; first left StumpWM touching a window that was gone, in the
      ;; middle of the switch (an X error, and you stayed behind).
      (when (and from (not (eq from group)) (member from (screen-groups (current-screen))))
        (ignore-errors (switch-to-group from)))
      (dolist (w (group-windows group))
        (when (vikix-learn-window-p w "vikix-learn-shell")
          (ignore-errors (delete-window w))))
      (when (and shell (member shell (group-frames group))
                 (> (length (group-frames group)) 1))
        (ignore-errors (remove-split group shell))))))

;; vikix-learn-place is called by a rule (rules.lisp, "Vikix's own rules").

(defcommand vikix-terminal () ()
  "Open a terminal: whichever program *vikix-terminal* names."
  (run-shell-command *vikix-terminal*))

;;; How long things take (vikix times): each measure a line of
;;; ~/.local/state/vikix/times.log, "2026-10-03T14:30:02 login 4.21".

(defun vikix-now ()
  "Seconds since 1970, to the microsecond."
  (multiple-value-bind (s us) (sb-ext:get-time-of-day)
    (+ s (/ us 1000000d0))))

(defun vikix-time-note (what seconds)
  (ignore-errors
   (let ((file (merge-pathnames ".local/state/vikix/times.log" (user-homedir-pathname))))
     (ensure-directories-exist file)
     (with-open-file (out file :direction :output :if-exists :append :if-does-not-exist :create)
       (multiple-value-bind (s mi h d mo y) (decode-universal-time (get-universal-time))
         (format out "~d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0d ~a ~,2f~%" y mo d h mi s what seconds))))))

(defun vikix-time-ready ()
  "The desktop is ready: how long since vikix-session started (it sets
VIKIX_SESSION_START), its config loaded."
  (let ((start (getenv "VIKIX_SESSION_START")))
    (when (and start (plusp (length start)))
      ;; Read as a double: a single float can't hold the seconds since 1970.
      (let* ((dot (or (position #\. start) (length start)))
             (whole (ignore-errors (parse-integer start :end dot)))
             (frac (subseq start (min (length start) (1+ dot))))
             (s (and whole (+ whole (if (plusp (length frac))
                                        (/ (or (ignore-errors (parse-integer frac)) 0)
                                           (expt 10d0 (length frac)))
                                        0d0)))))
        (when s (vikix-time-note "login" (- (vikix-now) s)))))))

(add-hook *start-hook* 'vikix-time-ready)

(defcommand vikix-reload () ()
  "Reload the whole configuration (Vikix's files and user.lisp)."
  ;; loadrc prints its own confirmation; init.lisp notes how long it took
  ;; (a reload from `vikix update` or `vikix eval` is one too).
  (loadrc))

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

;;; Screens plugged and unplugged. X doesn't light a new screen by itself:
;;; autorandr (its udev rule) puts back a layout saved for those screens,
;;; and Vikix's hook (vikix-screens) lays out ones it hasn't seen. StumpWM
;;; then has to notice the screens changed, and on this hardware it didn't:
;;; the root window's ConfigureNotify, its only way, never reached it
;;; (2026-09-10). RANDR's own events do, once asked for; one change sends
;;; several, and a passing one can have no screens at all, so a change is
;;; taken only when it differs and isn't empty.

(defun vikix-screens-refresh ()
  "The screens (heads) as X has them now, when they changed."
  (let* ((screen (current-screen))
         (new (make-screen-heads screen (screen-root screen))))
    (when (and new (not (equalp new (screen-heads screen))))
      (head-force-refresh screen new)
      (update-mode-lines screen)
      t)))

(setf (gethash :rr-screen-change-notify *event-fn-table*)
      (lambda (&rest slots &key &allow-other-keys)
        (declare (ignore slots))
        (handler-case (vikix-screens-refresh)
          (error (e) (message "^1Vikix: the screens changed, and:^n ~a" e)))))

(dolist (screen *screen-list*)
  (ignore-errors (xlib:rr-select-input (screen-root screen) '(:screen-change-notify-mask))))

(defcommand vikix-screens-pick () ()
  "Screens: extend, mirror, the other screen only, the laptop's only, arrange
or save (vikix screens pick)."
  (run-shell-command "vikix-screens pick"))

;; vikix-docs-open (bin/) opens guides and docs in Nyxt; when Nyxt is
;; already running, the page goes to its window, which may be on another
;; workspace, so it asks for this.
(defun vikix-raise-class (class)
  "Bring the first window of CLASS (\"Nyxt\") forward, from any workspace.
Returns the window, or nil when there's none."
  (let ((win (find class (screen-windows (current-screen))
                   :key 'window-class :test 'equal)))
    (when win (focus-all win))
    win))

(defparameter *vikix-menu* (vikix-registry-menu)
  "Each entry: a label, then what to do — a command name, or a Lisp form —
then, for some, what it needs: a program on PATH, or a file (\"~/...\"),
and the section of Super+m it is in (\"Work\"; one of *vikix-menu-groups*,
or a name of your own). An entry whose need isn't there is left out of
the menu (vikix-menu-entry-here-p): JupyterLab without the feature python,
Printers without printing ... One that names no section is in Yours.
Vikix's own are made from its commands (registry.lisp: a command with
:menu is in it, in that section); yours, a plugin's and a web app's are
added to this list. Its order is each section's order; the sections' own
is *vikix-menu-groups*'.")

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

(defun vikix-menu-entry-command (entry)
  "The StumpWM command ENTRY runs, as a key would write it, or NIL when it's
a form no key could be: vikix-quiet -> \"vikix-quiet\",
(run-shell-command \"vikix-ask\") -> \"exec vikix-ask\",
(vikix-webapp \"teams\") -> \"vikix-webapp teams\", (ai-usage) -> \"ai-usage\"."
  (let ((action (second entry)))
    (cond ((and action (symbolp action)) (string-downcase (symbol-name action)))
          ((atom action) nil)
          ((and (eq (first action) 'run-shell-command) (stringp (second action)) (null (cddr action)))
           (concatenate 'string "exec " (second action)))
          ((and (eq (first action) 'run-commands) (stringp (second action)) (null (cddr action)))
           (second action))
          ;; A command called as a function, as plugins and web apps write
          ;; theirs: its name, then what it is given.
          ((and (symbolp (first action))
                (every (lambda (a) (or (stringp a) (numberp a))) (rest action)))
           (format nil "~(~a~)~{ ~a~}" (first action) (rest action))))))

(defun vikix-menu-entry-key (entry)
  "The key that does what ENTRY does, as the key help writes it
(\"Super+Ctrl+d\"), or NIL: found in *vikix-bindings* when the menu opens,
and only when the key still runs that command, so a menu never names a
key that has moved."
  (let ((command (vikix-menu-entry-command entry)))
    (when (and command (boundp '*vikix-bindings*))
      (loop for binding in (symbol-value '*vikix-bindings*)
            for key = (first binding)
            when (and (equal (second binding) command)
                      (or (not (fboundp 'lookup-key)) (not (boundp '*top-map*))
                          (equal (ignore-errors (funcall 'lookup-key (symbol-value '*top-map*) (funcall 'kbd key)))
                                 command)))
              return (if (fboundp 'vikix-pretty-key) (funcall 'vikix-pretty-key key) key)))))

(defun vikix-menu-lines (entries)
  "ENTRIES as a menu shows them, (LINE ENTRY): each label, and its key in
a column when it has one, so the menu teaches the keys (and typing F10
finds what Super+F10 does). The column starts after the longest label
that has a key, so it is straight."
  (let* ((keys (mapcar #'vikix-menu-entry-key entries))
         (width (reduce #'max (loop for e in entries for k in keys
                                    when k collect (length (first e)))
                        :initial-value 0)))
    (loop for e in entries for k in keys
          collect (list (if k (format nil "~va  ~a" width (first e) k) (first e)) e))))

(defun vikix-menu-do (entry)
  "Do what ENTRY, picked from a menu, says."
  (let ((action (second entry)))
    ;; For "why did that happen?" (why.lisp): the entry is noted, and
    ;; the commands it runs are its doing, not noted again.
    (when (fboundp 'vikix-why-menu-picked)
      (ignore-errors (funcall 'vikix-why-menu-picked (first entry))))
    (progv '(*vikix-why-cause*) '(:menu)
      (if (symbolp action)
          (run-commands (string-downcase (symbol-name action)))
          (eval action)))))

(defun vikix-menu-typed-p (line typed)
  "Whether every word TYPED is somewhere in LINE, in any case. Plain
letters, not a pattern as StumpWM's menus take them: there \"ctrl+d\"
means c, t, r, some l's and a d, and finds no key."
  (loop with start = 0
        for end = (position #\Space typed :start start)
        always (search typed line :start1 start :end1 end :test #'char-equal)
        while end do (setf start (1+ end))))

(defun vikix-menu-choose (entries prompt &optional keymap)
  "Show ENTRIES, each with its key, and give back the one picked, or NIL."
  (when entries
    (second (select-from-menu (current-screen) (vikix-menu-lines entries) prompt 0 keymap
                              (lambda (line entry typed)
                                (declare (ignore entry))
                                (vikix-menu-typed-p line typed))))))

(defun vikix-run-menu (entries prompt)
  "Pick from ENTRIES, a menu like *vikix-menu*, and do what the choice says.
Entries whose program or file isn't here are left out; each shows its key."
  (let ((entry (vikix-menu-choose (remove-if-not #'vikix-menu-entry-here-p entries) prompt)))
    (when entry (vikix-menu-do entry))))

;;; Super+m itself is in sections: it opens on a dozen rows, one a section
;;; (Windows, System ...), and Enter on one shows what is in it. Typing
;;; there looks through every entry of every section at once, so
;;; "printers" or "F10" is still one step away. An entry says its section
;;; (its fourth element); a plugin's that doesn't is in Plugins, anything
;;; else in Yours.

(defun vikix-menu-entry-section (entry)
  "The section of Super+m ENTRY is in."
  (cond ((stringp (fourth entry)) (fourth entry))
        ((eq (third entry) :plugin) "Plugins")
        (t "Yours")))

(defun vikix-menu-head (label)
  "What a menu line is about, in a word or three: LABEL up to its colon,
question mark, bracket or comma, without \"on/off\". \"Layout: save ...\" ->
\"Layout\", \"Do not disturb on/off\" -> \"Do not disturb\". A section keeps
the lines of one head together, and its row at the top of Super+m is its
heads."
  (let* ((cuts (loop for (mark keep) in '((": " 0) ("? " 1) (" (" 0) (", " 0))
                     for at = (search mark label)
                     when at collect (+ at keep)))
         (head (subseq label 0 (reduce #'min cuts :initial-value (length label))))
         (switch (- (length head) (length " on/off"))))
    (if (and (plusp switch) (string= " on/off" head :start2 switch))
        (subseq head 0 switch)
        head)))

(defun vikix-menu-together (entries)
  "ENTRIES in their order, but each beside the earlier ones about the same
thing (vikix-menu-head): a plugin's \"Projects: ...\" goes under Vikix's."
  (let ((heads '()))
    (dolist (entry entries)
      (let* ((head (vikix-menu-head (first entry)))
             (cell (assoc head heads :test #'string-equal)))
        (if cell
            (push entry (rest cell))
            (push (list head entry) heads))))
    (loop for cell in (reverse heads) append (reverse (rest cell)))))

(defun vikix-menu-sections (entries)
  "ENTRIES by section, a list of (NAME ENTRY...): the sections Vikix names
in *vikix-menu-groups*' order, any other (a plugin's, Plugins, Yours) in
the order they come, and the last of Vikix's, Power, last."
  (let ((names '()) (table (make-hash-table :test #'equal))
        (known (symbol-value '*vikix-menu-groups*)))
    (dolist (entry entries)
      (let ((name (vikix-menu-entry-section entry)))
        (pushnew name names :test #'equal)
        (push entry (gethash name table))))
    (flet ((here (list) (remove-if-not (lambda (name) (member name names :test #'equal)) list)))
      (loop for name in (append (here (butlast known))
                                (remove-if (lambda (name) (member name known :test #'equal)) (reverse names))
                                (here (last known)))
            collect (cons name (vikix-menu-together (reverse (gethash name table))))))))

(defun vikix-menu-hint (entries &optional (room 60))
  "What a section holds, in a line of at most ROOM letters: its entries'
heads, each once, as many as fit whole, then \"...\" when there are more."
  (let ((heads (remove-duplicates (mapcar (lambda (entry) (vikix-menu-head (first entry))) entries)
                                  :test #'string-equal :from-end t))
        (line nil))
    (loop for (head . more) on heads
          for longer = (if line (concatenate 'string line ", " head) head)
          do (if (or (null line) (<= (length longer) (if more (- room 4) room)))
                 (setf line longer)
                 (return (concatenate 'string line " ...")))
          finally (return (or line "")))))

(defun vikix-menu-rows (sections)
  "The rows of Super+m, each (LINE KIND WHAT). A section is one row, its
name and what it holds (:section, WHAT the section); a section of one
entry is that entry (:single). After them, for typing, every entry with
its section before it (:found). vikix-menu-row-shown-p picks which show."
  (let* ((singles (vikix-menu-lines (loop for section in sections
                                          unless (cddr section) collect (second section))))
         (found (vikix-menu-lines (loop for section in sections append (rest section))))
         (width (lambda (list) (reduce #'max (mapcar (lambda (section) (length (first section))) list)
                                       :initial-value 0)))
         (wide (funcall width (remove-if-not #'cddr sections)))
         (widest (funcall width sections)))
    (append (loop for section in sections
                  collect (if (cddr section)
                              (list (format nil "~va  ~a" wide (first section) (vikix-menu-hint (rest section)))
                                    :section section)
                              (list (first (pop singles)) :single (second section))))
            (loop for section in sections
                  append (loop for entry in (rest section)
                               collect (list (format nil "~va  ~a" widest (first section) (first (pop found)))
                                             :found entry))))))

(defun vikix-menu-row-shown-p (line kind typed)
  "Whether Super+m shows a row: the sections while nothing is TYPED, then
the entries, of any section, that everything typed is found in."
  (if (zerop (length (string-trim " " typed)))
      (and (member kind '(:section :single)) t)
      (and (eq kind :found) (vikix-menu-typed-p line typed))))

(defun vikix-menu-open (menu)
  "Right, at the top of Super+m: into the section under the cursor, as
Enter goes. On any other row it does nothing."
  (when (eq (second (nth (menu-selected menu) (menu-table menu))) :section)
    (menu-finish menu)))

(defparameter *vikix-menu-top-map*
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "Right") 'vikix-menu-open)
    map)
  "Keys of Super+m's first list, beside StumpWM's own for menus.")

(defparameter *vikix-menu-section-map*
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "Left") 'menu-abort)
    map)
  "Keys inside a section of Super+m: Left goes back, as Escape does.")

(defun vikix-menu-pick (rows prompt &optional (selected 0))
  "StumpWM's menu over ROWS (vikix-menu-rows), opening on the row SELECTED:
the row picked, or NIL. select-from-menu shows every row until something
is typed; this one asks vikix-menu-row-shown-p from the start."
  (when rows
    (let ((menu (make-instance 'single-menu :table rows :selected 0 :prompt prompt
                                            :view-start 0 :view-end 0
                                            :additional-keymap *vikix-menu-top-map*
                                            :filter-pred #'vikix-menu-row-shown-p)))
      (typing-action menu nil)
      (setf (menu-selected menu) selected)
      (run-menu (current-screen) menu))))

(defun vikix-menu-everything ()
  "Every entry Super+m has: the apps that came with features
(*vikix-apps-menu*), in the section Apps, then *vikix-menu*."
  (append (loop for entry in (symbol-value '*vikix-apps-menu*)
                collect (list (first entry) (second entry) (third entry) "Apps"))
          *vikix-menu*))

(defun vikix-run-sections (entries prompt)
  "Pick from ENTRIES by section, and do what the choice says: the sections
first, then the one picked, from which Escape (or Left) comes back to the
sections. Typing among the sections finds an entry of any of them."
  (let* ((sections (vikix-menu-sections (remove-if-not #'vikix-menu-entry-here-p entries)))
         (rows (vikix-menu-rows sections))
         (at 0))
    (loop
      (let ((row (vikix-menu-pick rows prompt at)))
        (cond ((null row) (return nil))
              ((eq (second row) :section)
               (setf at (or (position row rows) 0))
               (let ((entry (vikix-menu-choose (rest (third row)) (format nil "~a: " (first (third row)))
                                               *vikix-menu-section-map*)))
                 (when entry (return (vikix-menu-do entry)))))
              (t (return (vikix-menu-do (third row)))))))))

(defcommand vikix-menu () ()
  "The Vikix menu, by section; typing finds an entry of any section."
  (vikix-run-sections (vikix-menu-everything) "Vikix: "))

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
  "The Dropbox menu (Super+m, Apps, Dropbox), in the same form as *vikix-menu*.")

(defcommand vikix-dropbox () ()
  "Dropbox: its status, the folder, start or stop it."
  (vikix-run-menu *vikix-dropbox-menu* "Dropbox: "))

(defparameter *vikix-apps-menu*
  '(("Video: edit (Shotcut)"        (run-shell-command "shotcut") "shotcut")
    ("Video: record with sound (OBS)" (run-shell-command "obs") "obs")
    ("Video: shrink or convert (HandBrake)" (run-shell-command "ghb") "ghb")
    ("Video: download one (yt-dlp, into ~/Videos/Downloads)"
     (vikix-in-terminal "mkdir -p ~/Videos/Downloads && cd ~/Videos/Downloads && printf \"Address: \" && read u && yt-dlp \"$u\"")
     "yt-dlp")
    ("Pictures: edit a photo (GIMP)" (run-shell-command "gimp") "gimp")
    ("Pictures: vector drawing (Inkscape)" (run-shell-command "inkscape") "inkscape")
    ("Pictures: paint (Krita)"      (run-shell-command "krita") "krita")
    ("Pictures: RAW photos (darktable)" (run-shell-command "darktable") "darktable")
    ("Pictures: a screenshot to mark up (Flameshot)" (run-shell-command "flameshot gui") "flameshot")
    ("3D (Blender)"                 (run-shell-command "blender") "blender")
    ("Study: flashcards (Anki)"     (run-shell-command "anki") "anki")
    ("Study: write on a PDF (Xournal++)" (run-shell-command "xournalpp") "xournalpp")
    ("Passwords (KeePassXC)"        (run-shell-command "keepassxc") "keepassxc")
    ("Passwords (Bitwarden): pick a login" (run-shell-command "vikix-bitwarden pick") "rbw")
    ;; In a terminal, so "no device" (USB debugging off, cable out) is seen.
    ("Phone: its screen in a window (scrcpy)" (vikix-in-terminal "scrcpy") "scrcpy")
    ("Disk: what fills my home (ncdu)" (vikix-in-terminal "ncdu ~") "ncdu")
    ("Files: Esploro, the Lisp file explorer" vikix-esploro "~/.local/bin/esploro"))
  "The apps of Super+m's section Apps, in the same form as *vikix-menu*: the
programs of the features video, graphics, blender, study, passwords, bitwarden, phone,
cli-extras and esploro. Each shows once its program is here.")

(defcommand vikix-esploro () ()
  "Esploro, the file explorer (Super+e): the one on this workspace, else a new
one here; PCManFM where Esploro isn't installed (vikix add esploro).
Each workspace can have its own (an Emacs frame titled Esploro); one on
another workspace is left there. The esploro command opens a new one
through Emacs's server, and asks StumpWM which workspace it's for."
  (if (probe-file (merge-pathnames ".local/bin/esploro" (user-homedir-pathname)))
      (let ((here (find "Esploro" (group-windows (current-group))
                        :key #'window-title :test #'string=)))
        (if here
            (group-focus-window (current-group) here)
            (run-shell-command "esploro")))
      ;; Without Esploro, Super+e is still the files.
      (run-shell-command "pcmanfm")))

(defcommand vikix-apps () ()
  "Video, pictures, study and other apps that come with features: what
Super+m's section Apps has of them, in a menu of their own."
  (if (some #'vikix-menu-entry-here-p *vikix-apps-menu*)
      (vikix-run-menu *vikix-apps-menu* "Apps: ")
      (message "No apps yet. Add some: Super+m, then Add software (video, graphics, study ...)")))

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

;;; The bar's words come from small programs (pamixer, vikix-net, vikix-bt,
;;; vikix-dropbox ...). Run every ten seconds in StumpWM's one thread, they
;;; held the whole desktop for as long as they took together: a quarter of
;;; a second as a rule, four seconds when one of them was slow (measured
;;; 2026-10-05), with every key waiting. So the round is made by a thread of
;;; its own (modeline.lisp); what it finds is put in these variables, and the
;;; bar is redrawn once, by the main thread, when something changed. A
;;; refresh asked for in the main thread (the volume keys) redraws at once.

(defvar *vikix-bar-in-worker* nil
  "True in the bar's own thread: nothing may be drawn from there.")
(defvar *vikix-bar-changed* nil
  "In the bar's thread: a refresher found something new this round.")

(defun vikix-bar-redraw ()
  "Redraw the bar for a value that changed: now, in the main thread; from
the bar's own thread, once its round is over."
  (if *vikix-bar-in-worker*
      (setf *vikix-bar-changed* t)
      (update-all-mode-lines)))

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
      (vikix-bar-redraw))))

(defun vikix-net-refresh ()
  "Read the network link into *vikix-net*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-net")))
    (unless (string= new *vikix-net*)
      (setf *vikix-net* new)
      (vikix-bar-redraw))))

(defvar *vikix-usb* ""
  "\"usb\" while a drive is mounted under /run/media (bin/vikix-drives), or \"\".")

(defun vikix-usb-refresh ()
  "Read whether a drive is mounted into *vikix-usb*, and redraw the bar if
it changed. vikix-drives also calls this when a drive comes or goes."
  (let ((new (vikix-shell-line "vikix-drives bar")))
    (unless (string= new *vikix-usb*)
      (setf *vikix-usb* new)
      (vikix-bar-redraw))))

(defun vikix-bt-refresh ()
  "Read Bluetooth into *vikix-bt*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-bt")))
    (unless (string= new *vikix-bt*)
      (setf *vikix-bt* new)
      (vikix-bar-redraw))))

(defvar *vikix-dropbox* ""
  "Dropbox as bin/vikix-dropbox puts it (\"dbx ↓1,204\", \"dbx off\"), or \"\"
when it's up to date, not installed, or never set up.")

(defun vikix-dropbox-refresh ()
  "Read Dropbox's state into *vikix-dropbox*, and redraw the bar if it changed."
  (let ((new (vikix-shell-line "vikix-dropbox")))
    (unless (string= new *vikix-dropbox*)
      (setf *vikix-dropbox* new)
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

(defparameter *vikix-windows-pidfile*
  (concatenate 'string
               (or (uiop:getenv "XDG_RUNTIME_DIR")
                   (format nil "/run/user/~a" (sb-posix:getuid)))
               "/libvirt/qemu/run/windows.pid")
  "Present while the Windows VM runs: libvirt (qemu:///session) makes it.")

(defvar *vikix-windows* nil
  "True while the Windows VM (vikix windows) is running.")

;;; Memory (bin/vikix-memory), shown in the bar when it runs low.

(defvar *vikix-memory* nil
  "What bin/vikix-memory's watcher last wrote, as (LEVEL USED LEFT TOLD):
LEVEL :low or :critical (NIL while there's enough), USED the percent of
memory in use, LEFT how many programs are left over, TOLD whether they've
piled up enough to be said.")

(defparameter *vikix-memory-file*
  (merge-pathnames ".local/state/vikix/memory" (user-homedir-pathname))
  "Where bin/vikix-memory's watcher writes: \"LEVEL USED% LEFT LEFT-MB TOLD\".")

(defun vikix-memory-read (line)
  "LINE of the watcher's file as (LEVEL USED LEFT TOLD); NIL when there's
nothing for the bar to say."
  (let* ((words (and line (split-string line " ")))
         (level (cond ((equal (first words) "low") :low)
                      ((equal (first words) "critical") :critical)))
         (used (ignore-errors (parse-integer (second words))))
         (left (or (ignore-errors (parse-integer (third words))) 0))
         (told (equal (fifth words) "1")))
    (and (or level (and told (plusp left)))
         (list level (or used 0) left told))))

(defun vikix-memory-refresh ()
  "Read the watcher's file into *vikix-memory*; redraw the bar if it changed.
A small file, so this runs with the others."
  (let ((new (vikix-memory-read
              (ignore-errors
               (with-open-file (in *vikix-memory-file*) (read-line in nil ""))))))
    (unless (equal new *vikix-memory*)
      (setf *vikix-memory* new)
      (vikix-bar-redraw))))

(defun vikix-windows-refresh ()
  "Read whether Windows runs into *vikix-windows*; redraw the bar if it changed.
A file test, so no program starts every 10 seconds."
  (let ((new (and (probe-file *vikix-windows-pidfile*) t)))
    (unless (eq new *vikix-windows*)
      (setf *vikix-windows* new)
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

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
      (vikix-bar-redraw))))

(defcommand vikix-quiet () ()
  "Do not disturb, on or off. While it is on, notifications wait (the bar
says quiet, and how many are waiting); switching it off shows them."
  (run-shell-command "dunstctl set-paused toggle" t)
  (vikix-quiet-refresh)
  (message (if (string= *vikix-quiet* "")
               "Notifications on"
               "Do not disturb: notifications wait until you switch it off")))

;;; Focus time (Super+m, Notifications; no key, the card is full): so many
;;; minutes with do not disturb on by itself, then a break, each said in
;;; the bar and at its end. A rule starts one too:
;;; (at "09:00" :weekdays (command "vikix-focus-time 50")).

(defparameter *vikix-focus-minutes* 25
  "How long focus time is when the key starts it (vikix-focus-time 50 for once).")
(defparameter *vikix-focus-break* nil
  "The break after focus time, in minutes; nil: a fifth of it, 5 at least.")
(defvar *vikix-focus* nil
  "What is on: (:focus END MINUTES QUIET-BEFORE) while you work (QUIET-BEFORE:
do not disturb was already on, so it stays on after), (:break END MINUTES)
while you rest, or nil. END is a universal time.")
(defvar *vikix-focus-timer* nil "Every 30 seconds while something is on.")
(defvar *vikix-focus-now* 'get-universal-time
  "The clock focus time reads: a function returning a universal time. Tests put their own here.")

(defun vikix-focus-left ()
  "Minutes left of what is on, 0 when nothing is."
  (if *vikix-focus*
      (max 0 (ceiling (- (second *vikix-focus*) (funcall *vikix-focus-now*)) 60))
      0))

(defun vikix-focus-notify (title body)
  (run-shell-command (format nil "notify-send -a Vikix -- ~a ~a"
                             (vikix-shell-quote title) (vikix-shell-quote body))))

(defun vikix-focus-quiet (on)
  "Do not disturb on or off, and the bar's word for it read again."
  (run-shell-command (format nil "dunstctl set-paused ~:[false~;true~]" on) t)
  (vikix-quiet-refresh))

(defun vikix-focus-break-minutes (minutes)
  (or *vikix-focus-break* (max 5 (round minutes 5))))

(defun vikix-focus-start (minutes)
  "Focus time for MINUTES: do not disturb on, the bar counting down."
  (let ((quiet-before (not (string= *vikix-quiet* ""))))
    (unless quiet-before (vikix-focus-quiet t))
    (setf *vikix-focus* (list :focus (+ (funcall *vikix-focus-now*) (* 60 minutes)) minutes quiet-before))
    (unless (and *vikix-focus-timer* (timer-p *vikix-focus-timer*))
      (setf *vikix-focus-timer* (run-with-timer 30 30 'vikix-focus-tick)))
    (vikix-bar-redraw)
    (message "Focus time: ~d minutes. Notifications wait; the same entry again stops it." minutes)))

(defun vikix-focus-stop (&optional (said t))
  "Whatever is on, off: do not disturb as it was before, the field gone."
  (let ((was *vikix-focus*))
    (when (and was (eq (first was) :focus) (not (fourth was)))
      (vikix-focus-quiet nil))
    (setf *vikix-focus* nil)
    (when (and *vikix-focus-timer* (timer-p *vikix-focus-timer*))
      (cancel-timer *vikix-focus-timer*))
    (setf *vikix-focus-timer* nil)
    (vikix-bar-redraw)
    (when (and was said)
      (message (if (eq (first was) :focus) "Focus time stopped." "Break over.")))))

(defun vikix-focus-tick ()
  "Every 30 seconds while something is on: the bar's minute, and the turn
from work to the break and from the break to nothing. Never an error."
  (ignore-errors
   (when *vikix-focus*
     (if (plusp (vikix-focus-left))
         (vikix-bar-redraw)
         (destructuring-bind (what end minutes &optional quiet-before) *vikix-focus*
           (declare (ignore end))
           (if (eq what :focus)
               (let ((break (vikix-focus-break-minutes minutes)))
                 (unless quiet-before (vikix-focus-quiet nil))
                 (setf *vikix-focus* (list :break (+ (funcall *vikix-focus-now*) (* 60 break)) break))
                 (vikix-focus-notify (format nil "Focus time over: ~d minutes" minutes)
                                     (format nil "A break of ~d. Notifications are back." break))
                 (vikix-bar-redraw))
               (progn
                 (vikix-focus-notify "Break over" "Focus time again: Super+m, Notifications.")
                 (vikix-focus-stop nil))))))))

(defcommand vikix-focus-time (&optional what) ((:string nil))
  "Focus time: so many minutes with do not disturb on, then a break, counted
down in the bar. Alone it starts *vikix-focus-minutes* (25), or stops what is
on; with a number (`vikix-focus-time 50`) it starts that many; `off` stops."
  (let ((what (and what (string-trim " " what))))
    (cond ((or (null what) (string= what ""))
           (if *vikix-focus* (vikix-focus-stop) (vikix-focus-start *vikix-focus-minutes*)))
          ((string-equal what "off") (vikix-focus-stop))
          ((and (every #'digit-char-p what) (< 0 (parse-integer what) 1000))
           (vikix-focus-start (parse-integer what)))
          (t (message "Focus time takes a number of minutes, or off; not ~a." what)))))

(defcommand vikix-volume (change) ((:string "Volume (up, down, mute, mic): "))
  "Change the volume with vikix-osd, which shows a bar for it, then show
the new level in the mode line."
  (run-shell-command (format nil "vikix-osd volume ~a" change))
  ;; vikix-osd runs in the background; read the level once it has finished.
  ;; A ratio, not 0.5: StumpWM's timers want rationals.
  (run-with-timer 1/2 nil #'vikix-volume-refresh))
