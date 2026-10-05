;;;; why.lisp — "why did that happen?" (s-?).
;;;;
;;;; A window jumped to another workspace, a key did something odd, the
;;;; layout changed under you. The desktop is a program, so it can say what
;;;; made it do that: the key you pressed and the command it ran, the rule
;;;; that ran and the window it ran for, the entry of Super+m, the agent or
;;;; the script that asked. Each with where it is written (user.lisp, line
;;;; 42), so you can go there, and what takes it back, where something does.
;;;;
;;;;   vikix-why (s-?)   the last things the desktop did, newest first; pick
;;;;                     one for what can be done about it: edit where it is
;;;;                     written, take it back, switch a rule off
;;;;   vikix why         the same list in a terminal (bin/vikix-why), and
;;;;                     for agents (vikix mcp: why)
;;;;
;;;; What is noted, in a ring of the last *vikix-why-size* (the same thing
;;;; again moves to the front, counted, so a rule that runs at every change
;;;; of focus is one line, not fifty):
;;;;
;;;;   a key       every key that runs a command, with the command, from
;;;;               StumpWM's *key-press-hook* and eval-command
;;;;   a rule      every run of a rule, with its window (rules.lisp calls
;;;;               vikix-why-rule-ran)
;;;;   the menu    an entry of Super+m picked (commands.lisp)
;;;;   an agent    a command an agent ran by name (registry.lisp)
;;;;   asked for   a command nothing above explains: a click on the bar, a
;;;;               script, vikix eval
;;;;
;;;; and, when the list is shown, the last notification, from dunst's own
;;;; history. Nothing is written to disk: the ring lasts until StumpWM
;;;; starts again.

(in-package :stumpwm)

(defparameter *vikix-why-size* 50
  "How many things the desktop did are kept for vikix-why.")

(defvar *vikix-why-ring* '()
  "What the desktop did lately, newest first: plists (:kind :id :what :does
:from :file :line :command :rule :window :at :count).")

(defvar *vikix-why-cause* nil
  "Bound while something already noted runs commands (the menu, an agent):
the commands it runs are its doing, and not noted again.")

(defvar *vikix-why-depth* 0
  "How deep in eval-command we are: a command a command runs is its own doing.")

(defvar *vikix-why-key* nil
  "The keys just pressed that run a command: (KEYS COMMAND TIME), the keys
as StumpWM has them, first pressed first.")

(defvar *vikix-key-sources* (make-hash-table :test 'equal)
  "Where each key was bound, by its name: (FILE . LINE). vikix-bind notes it
(keys.lisp) as a file loads.")

;;; --- Noting -------------------------------------------------------------------------------

(defun vikix-why-note (kind id &rest fields)
  "Note that something happened: KIND (:key :rule :menu :agent :asked), ID
what makes it the same thing next time, FIELDS the rest of its plist. One
with the same KIND and ID moves to the front, counted. Never an error.
Each is counted for `vikix used` too (used.lisp)."
  (when (fboundp 'vikix-used-note)
    (funcall 'vikix-used-note kind id))
  (ignore-errors
   (let* ((old (find-if (lambda (e) (and (eq (getf e :kind) kind) (equal (getf e :id) id)))
                        *vikix-why-ring*))
          (entry (list* :kind kind :id id :at (get-universal-time)
                        :count (1+ (if old (getf old :count 0) 0))
                        fields))
          (rest (remove old *vikix-why-ring*)))
     (setf *vikix-why-ring*
           (cons entry (if (>= (length rest) *vikix-why-size*)
                           (subseq rest 0 (1- *vikix-why-size*))
                           rest)))
     entry)))

(defun vikix-why-vikix-file-p (file)
  "Is FILE one of Vikix's own (its layer, a plugin), not for you to change?"
  (let ((file (namestring file)))
    (or (and (boundp '*vikix-dir*)
             (eql 0 (search (namestring (symbol-value '*vikix-dir*)) file)))
        (and (search "/vikix/" file)
             (or (search "/config/stumpwm/" file) (search "/plugins/" file)))
        (not (eql 0 (search (namestring (user-homedir-pathname)) file))))))

(defun vikix-why-place (file line)
  "FILE and LINE as said: \"user.lisp, line 42\"."
  (and file (format nil "~a~@[, line ~d~]" (file-namestring file) line)))

(defun vikix-why-key-source (key command)
  "Where KEY, running COMMAND, was written: (values WORDS FILE LINE). WORDS
says whose it is; FILE and LINE may be nil (a key of StumpWM's own)."
  (let* ((registered (and (boundp '*vikix-commands*)
                          (find-if (lambda (c) (and (equal (getf c :key) key) (equal (getf c :run) command)))
                                   (symbol-value '*vikix-commands*))))
         (bound (gethash key *vikix-key-sources*))
         (file (if registered (getf registered :file) (car bound)))
         (line (if registered (getf registered :line) (cdr bound)))
         (owner (and (fboundp 'vikix-key-had) (ignore-errors (funcall 'vikix-key-had key)))))
    (values (cond ((and owner (eql 0 (search "plugin " owner))) (format nil "the ~a's key" owner))
                  ((and owner (eql 0 (search "web app " owner)))
                   (format nil "the ~a's key (vikix webapp key ~a KEY moves it)" owner (subseq owner 8)))
                  ((null file) "a key of StumpWM's own")
                  ((vikix-why-vikix-file-p file) "Vikix's key")
                  (t "your key"))
            file line)))

(defun vikix-why-keys-said (keys)
  "KEYS, as StumpWM names them (\"C-t k\"), as the keyboard says them."
  (format nil "~{~a~^ then ~}"
          (mapcar (lambda (k) (if (fboundp 'vikix-pretty-key) (funcall 'vikix-pretty-key k) k))
                  (split-string keys " "))))

(defun vikix-why-command-words (command)
  "What COMMAND does, in the registry's words or its own description."
  (or (let ((c (and (boundp '*vikix-commands*)
                    (find command (symbol-value '*vikix-commands*)
                          :key (lambda (c) (getf c :run)) :test #'equal))))
        (and c (getf c :does)))
      (let ((b (and (boundp '*vikix-bindings*)
                    (find command (symbol-value '*vikix-bindings*) :key #'second :test #'equal))))
        (and b (third b)))
      (ignore-errors
       (let* ((word (subseq command 0 (position #\Space command)))
              (doc (documentation (intern (string-upcase word) :stumpwm) 'function)))
         ;; StumpWM's own descriptions are Texinfo (@var{string}): not said.
         (and doc (not (find #\@ doc))
              (vikix-one-line (subseq doc 0 (or (position #\Newline doc) (length doc))) 90))))))

(defun vikix-why-key-name (key)
  "KEY, as StumpWM has it, by the name it was bound under (\"s-C-y\"): the
one in *vikix-bindings* or among the keys vikix-bind noted, which may write
the same key another way than StumpWM prints it; else its modifiers in
Vikix's order."
  (flet ((same (name) (ignore-errors (equalp (kbd name) key))))
    (or (first (find-if #'same (and (boundp '*vikix-bindings*) (symbol-value '*vikix-bindings*)) :key #'first))
        (loop for name being the hash-keys of *vikix-key-sources* when (same name) return name)
        (format nil "~:[~;s-~]~:[~;C-~]~:[~;M-~]~:[~;S-~]~a"
                (key-super key) (key-control key) (key-meta key) (key-shift key)
                (keysym->stumpwm-name (key-keysym key))))))

(defun vikix-why-key-press (key key-seq command)
  "On *key-press-hook*: remember the keys that are about to run COMMAND,
as StumpWM has them, first pressed first."
  (declare (ignore key))
  (ignore-errors
   (setf *vikix-why-key*
         (and (stringp command)
              (list (reverse key-seq) command (get-universal-time))))))

(defun vikix-why-command (command interactivep)
  "A command is about to run, and no command is running it: note what made it."
  (let ((word (subseq command 0 (position #\Space command))))
    (cond ((equal word "vikix-why"))            ; asking why isn't a thing that happened
          (*vikix-why-cause*)                   ; the menu's or an agent's doing: noted there
          ((and (boundp '*vikix-rule-depth*) (plusp (symbol-value '*vikix-rule-depth*))))  ; a rule's
          ((and interactivep *vikix-why-key* (equal (second *vikix-why-key*) command))
           (let* ((names (mapcar #'vikix-why-key-name (first *vikix-why-key*)))
                  (keys (format nil "~{~a~^ ~}" names)))
             (setf *vikix-why-key* nil)
             (multiple-value-bind (whose file line)
                 (vikix-why-key-source (car (last names)) command)
               (vikix-why-note :key (list keys command)
                               :what (vikix-why-keys-said keys)
                               :does (format nil "ran ~a~@[ (~a)~]" command (vikix-why-command-words command))
                               :from (format nil "~a~@[: ~a~]" whose (vikix-why-place file line))
                               :file file :line line :command command))))
          (interactivep
           (vikix-why-note :asked (list :typed command)
                           :what "A command you typed"
                           :does (format nil "ran ~a~@[ (~a)~]" command (vikix-why-command-words command))
                           :from "after Ctrl+t ; or from a menu of commands"
                           :command command))
          (t
           (vikix-why-note :asked (list :outside command)
                           :what "Something asked for it"
                           :does (format nil "ran ~a~@[ (~a)~]" command (vikix-why-command-words command))
                           :from "not a key: a click on the bar, a script, vikix eval or an agent"
                           :command command)))))

(defun vikix-why-eval-command (function command &optional interactivep)
  "Around StumpWM's eval-command: note the command when nothing above it is
a command, then run it as ever."
  (when (and (zerop *vikix-why-depth*) (stringp command))
    (ignore-errors (vikix-why-command command interactivep)))
  (let ((*vikix-why-depth* (1+ *vikix-why-depth*)))
    (funcall function command interactivep)))

(defun vikix-why-rule-ran (rule window event)
  "From vikix-run-rule (rules.lisp): RULE has run, for WINDOW at EVENT."
  (ignore-errors
   (vikix-why-note :rule (vikix-rule-key rule)
                   :what (format nil "A rule~@[, ~a~]"
                                 (case event (:open "as a window opened") (:focus "as a window took the focus")
                                   (:close "as a window closed")
                                   (:idle "as you were away")
                                   (t (let ((thing (and (boundp '*vikix-rule-things*)
                                                        (assoc event (symbol-value '*vikix-rule-things*)))))
                                        (and thing
                                             (format nil "as ~a was ~a~@[ (~a)~]" (third thing) (fourth thing)
                                                     (symbol-value '*vikix-rule-thing*)))))))
                   :does (format nil "ran ~a" (vikix-one-line (vikix-rule-text rule) 110))
                   :from (format nil "~a~@[, for ~a~]"
                                 (vikix-rule-from rule)
                                 (and window
                                      (format nil "~a \"~a\"" (window-class window)
                                              (vikix-one-line (window-title window) 40))))
                   :file (vikix-rule-file rule) :line (vikix-rule-line rule)
                   :rule rule :window window)))

(defun vikix-why-menu-picked (label)
  "From vikix-run-menu (commands.lisp): the entry LABEL of a menu was picked."
  (let ((c (and (boundp '*vikix-commands*)
                (find label (symbol-value '*vikix-commands*)
                      :key (lambda (c) (or (getf c :label) (getf c :does))) :test #'equal))))
    (vikix-why-note :menu label
                    :what "The menu"
                    :does (format nil "did \"~a\"" label)
                    :from (if c
                              (format nil "an entry of Super+m~@[: ~a~]" (vikix-why-place (getf c :file) (getf c :line)))
                              "an entry of a menu (yours, a plugin's or a web app's)")
                    :file (and c (getf c :file)) :line (and c (getf c :line))
                    :command (and c (getf c :run)))))

(defun vikix-why-agent-ran (command)
  "From vikix-agent-run (registry.lisp): an agent ran COMMAND, a registry entry."
  (vikix-why-note :agent (getf command :name)
                  :what "An agent"
                  :does (format nil "ran ~(~a~) (~a)" (getf command :name) (getf command :does))
                  :from "through vikix mcp's run_command: a command marked for agents in the registry"
                  :file (getf command :file) :line (getf command :line)
                  :command (getf command :run)))

;; StumpWM runs a key's command, a typed one and one a program asks for
;; through eval-command: wrapped, as rules.lisp wraps get-window-placement.
(sb-int:unencapsulate 'eval-command 'vikix-why)
(sb-int:encapsulate 'eval-command 'vikix-why 'vikix-why-eval-command)
(remove-hook *key-press-hook* 'vikix-why-key-press)
(add-hook *key-press-hook* 'vikix-why-key-press)

;;; --- Saying it ----------------------------------------------------------------------------

(defun vikix-why-when (time)
  "TIME as the hour and minute it was, with the seconds: things come close together."
  (multiple-value-bind (s mi h) (decode-universal-time time)
    (format nil "~2,'0d:~2,'0d:~2,'0d" h mi s)))

(defun vikix-why-notification ()
  "The last notification, as an entry, or nil: dunst's own history says
which program sent it (vikix-notifications last: id, program, title, seconds)."
  (ignore-errors
   (let* ((line (string-trim '(#\Newline #\Space) (run-shell-command "timeout 2 vikix-notifications last 2>/dev/null" t)))
          (fields (split-string line (string #\Tab))))
     (when (= (length fields) 4)
       (destructuring-bind (id program title seconds) fields
         (list :kind :notification :id id
               :at (- (get-universal-time) (parse-integer seconds))
               :count 1
               :what "A notification"
               :does (format nil "\"~a\"" (vikix-one-line title 80))
               :from (format nil "sent by ~a" program)
               :notification id))))))

(defun vikix-why-entries (&optional (limit *vikix-why-size*))
  "What happened lately, newest first: the ring, and the last notification
in its place by the time it came."
  (let* ((notification (vikix-why-notification))
         (all (sort (append (and notification (list notification)) (copy-list *vikix-why-ring*))
                    #'> :key (lambda (e) (getf e :at)))))
    (subseq all 0 (min limit (length all)))))

(defun vikix-why-line (entry)
  "ENTRY in a line: when, what, what it did, where it is from."
  (format nil "~a  ~a ~a~@[  ×~d~]  ·  ~a"
          (vikix-why-when (getf entry :at))
          (getf entry :what) (getf entry :does)
          (and (> (getf entry :count 1) 1) (getf entry :count))
          (getf entry :from)))

(defun vikix-why-text (&optional (limit 20))
  "The list as text, for vikix why and for agents."
  (let ((entries (vikix-why-entries limit)))
    (if entries
        (format nil "~{~a~^~%~}" (mapcar #'vikix-why-line entries))
        "Nothing yet: no key, rule or command has run since the desktop started.")))

;;; --- What can be done about one -----------------------------------------------------------

(defun vikix-why-view-file (file line)
  "Show one of Vikix's own files in Emacs, to read: not to change."
  (run-shell-command
   (format nil "emacsclient -n -c -a '' -e ~a"
           (vikix-shell-quote
            (format nil "(progn (view-file ~s) (goto-char (point-min)) (forward-line ~d))"
                    (namestring file) (max 0 (1- (or line 1))))))))

(defun vikix-why-switch-p (command)
  "Is COMMAND a switch: run again, it is as it was?"
  (let ((word (subseq command 0 (position #\Space command))))
    (or (and (boundp '*vikix-key-switches*)
             (or (member command (symbol-value '*vikix-key-switches*) :test #'equal)
                 (member word (symbol-value '*vikix-key-switches*) :test #'equal)))
        (let ((words (vikix-why-command-words command)))
          (and words (search "on/off" words) t)))))

(defun vikix-why-choices (entry)
  "What can be done about ENTRY: a list of (LABEL FUNCTION)."
  (let* ((file (getf entry :file)) (line (getf entry :line))
         (command (getf entry :command))
         (rule (getf entry :rule)) (window (getf entry :window))
         (choices '()))
    (flet ((offer (label function) (setf choices (append choices (list (list label function))))))
      (when (and file (probe-file file))
        (if (vikix-why-vikix-file-p file)
            (offer (format nil "See where it is written: ~a (Vikix's own, to read: what you change goes in user.lisp)"
                           (vikix-why-place file line))
                   (lambda () (vikix-why-view-file file line)))
            (offer (format nil "Edit it: ~a, in Emacs" (vikix-why-place file line))
                   (lambda () (vikix-open-in-emacs file line)))))
      (when (and command (vikix-why-switch-p command))
        (offer (format nil "Take it back: run ~a again (it is a switch)" command)
               (lambda () (run-commands command))))
      (when (and command (fboundp 'vikix-layout-command-p)
                 (ignore-errors
                  (funcall 'vikix-layout-command-p
                           (intern (string-upcase (subseq command 0 (position #\Space command))) :stumpwm))))
        (offer "Take it back: the layout as it was before (Super+u)"
               (lambda () (run-commands "vikix-layout-undo"))))
      (when (and window (member window (screen-windows (current-screen)))
                 (not (eq (window-group window) (current-group))))
        (offer (format nil "Bring that window here (it is on workspace ~a)" (group-name (window-group window)))
               (lambda () (funcall 'vikix-bring-window-here window))))
      (when (and rule (member rule (symbol-value '*vikix-rules*)) (vikix-rule-on-p rule))
        (offer "Switch that rule off, until the next reload (vikix rules on brings it back)"
               (lambda ()
                 (vikix-rule-switch rule nil)
                 (message "Off until the next reload: ~a" (vikix-one-line (vikix-rule-text rule) 100)))))
      (when (getf entry :notification)
        (offer "Show that notification again"
               (lambda () (run-shell-command (format nil "dunstctl history-pop ~a" (getf entry :notification))))))
      choices)))

(defcommand vikix-why () ()
  "Why did that happen? The last things the desktop did, newest first: the
key and its command, the rule and its window, the menu's entry, what an
agent or a script asked for, each with where it is written. Pick one to
edit it there, take it back, or switch a rule off."
  (let ((entries (vikix-why-entries)))
    (if (null entries)
        (message "Nothing yet: no key, rule or command has run since the desktop started.")
        (let* ((picked (select-from-menu (current-screen)
                                         (mapcar (lambda (e) (list (vikix-why-line e) e)) entries)
                                         "Why did that happen? "))
               (entry (second picked)))
          (when entry
            (let* ((choices (vikix-why-choices entry))
                   (what (and choices
                              (select-from-menu (current-screen)
                                                (append (mapcar (lambda (c) (list (first c) (second c))) choices)
                                                        '(("Nothing" nil)))
                                                (format nil "~a ~a: " (getf entry :what)
                                                        (vikix-one-line (getf entry :does) 70))))))
              (cond ((null choices)
                     (message "~a ~a~%~a~%Nothing to edit or take back here." (getf entry :what) (getf entry :does)
                              (getf entry :from)))
                    ((second what) (funcall (second what))))))))))
