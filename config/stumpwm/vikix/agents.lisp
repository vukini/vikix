;;;; agents.lisp — the office: the agents at work on this desktop, in one place.
;;;;
;;;; Several agents run here at once, each in a terminal of its own, and
;;;; nothing on the desktop knew an agent from a terminal: which of the five
;;;; windows called "Alacritty" is the one working on the books, which has
;;;; been waiting an hour for a yes. The desktop starts them (vikix agent),
;;;; so it can say.
;;;;
;;;;   vikix-agents     the agents running, each with its folder, its
;;;;                    workspace, how long it has run and what it is doing;
;;;;                    pick one to go to it (Super+m, AI)
;;;;   vikix agents     the same in a terminal, with what each has left
;;;;                    uncommitted in its folder (bin/vikix-agents), and for
;;;;                    agents (vikix mcp: agents)
;;;;
;;;; An agent is a program of *vikix-agent-programs* running in a terminal
;;;; window: started there by vikix agent, or by hand at a shell. What it is
;;;; doing is read, not asked: the agent-waiting plugin's note for its
;;;; window when there is one (a dialog open, a question, finished), else
;;;; what Claude Code writes in its window's title (a turning mark while it
;;;; works, a star when it is at its prompt); and when a release or tests
;;;; hold its shell, the notes those leave (vikix-agents-held: waiting for
;;;; a release, waiting for a test slot). A window with an agent in it
;;;; carries the agent's name (_VIKIX_AGENT), for whatever wants to know.
;;;;
;;;; These are the first steps of NOVEL.md's "An office for agents": seeing
;;;; them, and a desk each (vikix agents desk: a workspace to itself and a
;;;; git worktree of its project; bin/vikix-agents makes it, this file only
;;;; finds the workspace, and names the agent's window for the desk:
;;;; "office-ui · Claude", the last section). The house rules come after.

(in-package :stumpwm)

(defparameter *vikix-agent-programs* '("claude" "codex" "opencode" "gemini" "aider" "agy")
  "The programs that are agents, by name: the ones vikix agent starts. One
of your own: (push \"my-agent\" *vikix-agent-programs*) in user.lisp.")

(defparameter *vikix-agent-names* '(("agy" . "antigravity"))
  "A program whose name isn't its agent's: Antigravity CLI's program is agy.
The agent is named as vikix agent names it, everywhere it is shown.")

(defvar *vikix-agent-notes-dir*
  (merge-pathnames ".local/state/vikix/agents/" (user-homedir-pathname))
  "Where the agent-waiting plugin keeps a note a window (named by the X
window's id): its state and time, its folder, a line of what it said.")

;;; --- Which window has an agent -------------------------------------------------------------

(defun vikix-agent-name (pid)
  "The agent PID is, by name, or nil. An agent that is a script shows as its
interpreter first (node .../gemini), so the first two words are looked at."
  (let ((words (vikix-proc-cmdline pid)))
    (loop for word in (subseq words 0 (min 2 (length words)))
          for program = (vikix-layout-program word)
          when (member program *vikix-agent-programs* :test #'string=)
            return (or (cdr (assoc program *vikix-agent-names* :test #'string=)) program))))

(defun vikix-proc-children (pid)
  "PID's child processes, by number."
  (ignore-errors
   (with-open-file (in (format nil "/proc/~d/task/~d/children" pid pid))
     (let ((line (read-line in nil "")))
       (loop for word in (split-string line " ")
             for child = (parse-integer word :junk-allowed t)
             when child collect child)))))

(defun vikix-agent-under (pid &optional (depth 4))
  "The agent among PID and what it started, nearest first, down to DEPTH
generations: its process number, or nil. A terminal runs its agent itself
(vikix agent), or a shell that runs it, or a script that does."
  (loop with row = (list pid)
        repeat (1+ depth)
        while row
        do (let ((found (find-if #'vikix-agent-name row)))
             (when found (return found)))
           (setf row (loop for p in row append (vikix-proc-children p)))))

(defun vikix-proc-seconds (pid)
  "How long PID has been running, in seconds, or nil: its start, field 22
of /proc/PID/stat in hundredths since boot, against /proc/uptime."
  (ignore-errors
   (let* ((line (with-open-file (in (vikix-proc-file pid "stat")) (read-line in)))
          (fields (remove "" (split-seq (subseq line (1+ (position #\) line :from-end t))) " ")
                          :test #'string=))
          (started (/ (parse-integer (nth 19 fields)) 100))
          (up (with-open-file (in "/proc/uptime")
                (let ((*read-default-float-format* 'double-float) (*read-eval* nil))
                  (read in)))))
     (max 0 (round (- up started))))))

(defun vikix-agent-note (window)
  "The agent-waiting plugin's note for WINDOW: (STATE TIME FOLDER LINE), or
nil. Only read: the plugin clears its own."
  (ignore-errors
   (let ((file (merge-pathnames (format nil "~d" (xlib:window-id (window-xwin window)))
                                *vikix-agent-notes-dir*)))
     (when (probe-file file)
       (with-open-file (in file :external-format :utf-8)
         (let* ((words (split-string (or (read-line in nil) "") " "))
                (folder (read-line in nil))
                (line (read-line in nil)))
           (when (member (first words) '("ask" "reply" "done") :test #'string=)
             (list (first words) (or (ignore-errors (parse-integer (second words))) 0)
                   (or folder "") (or line "")))))))))

(defun vikix-agent-state (window)
  "What the agent in WINDOW is doing: (values STATE WORDS SAID). STATE is
:asks (it waits for you), :done, :idle (at its prompt), :working or
:running (nothing says); SAID a line of its own, when the plugin kept one."
  (let* ((note (vikix-agent-note window))
         (title (or (window-title window) ""))
         (mark (and (plusp (length title)) (char title 0))))
    (cond ((equal (first note) "ask") (values :asks "waits for your yes" (fourth note)))
          ((equal (first note) "reply") (values :asks "asked you something" (fourth note)))
          ((equal (first note) "done") (values :done "finished its turn" (fourth note)))
          ;; Claude Code's own mark at the front of the title: a star at its
          ;; prompt; while it works, one that turns (a circle's quarters, or
          ;; Braille dots).
          ((eql mark #\✳) (values :idle "at its prompt" nil))
          ((and mark (or (find mark "◐◑◒◓◴◵◶◷") (<= #x2800 (char-code mark) #x28FF)))
           (values :working "working" nil))
          (t (values :running "running" nil)))))

(defun vikix-window-agent (window)
  "The agent running in WINDOW, a terminal, as a plist (:name :pid :window
:folder :seconds :state :words :said), or nil."
  (ignore-errors
   (let* ((pid (vikix-window-pid window))
          (own (and pid (vikix-proc-cmdline pid))))
     (when (and own (member (vikix-layout-program (first own)) *vikix-layout-terminals* :test #'string=))
       (let* ((inside (vikix-proc-child pid))
              (front (and inside (vikix-proc-foreground inside)))
              ;; The job in front at its shell, else whatever the terminal
              ;; started that is one (a shell's script, a wrapper).
              (agent (or (and front (vikix-agent-name front) front)
                         (and inside (vikix-agent-under inside)))))
         (when agent
           (multiple-value-bind (state words said) (vikix-agent-state window)
             (list :name (vikix-agent-name agent) :pid agent :window window
                   :folder (or (vikix-proc-cwd agent) "")
                   :seconds (or (vikix-proc-seconds agent) 0)
                   :state state :words words :said said))))))))

(defun vikix-agent-mark (window name)
  "Write NAME on WINDOW as the agent in it (_VIKIX_AGENT), or take the mark
off when NAME is nil and it had one."
  (ignore-errors
   (let ((xwin (window-xwin window)))
     (cond (name
            (xlib:change-property xwin :_VIKIX_AGENT
                                  (sb-ext:string-to-octets name :external-format :utf-8)
                                  :utf8_string 8))
           ((xlib:get-property xwin :_VIKIX_AGENT)
            (xlib:delete-property xwin :_VIKIX_AGENT))))))

(defun vikix-agents (&optional (held t))
  "The agents running in this desktop's terminals: a plist each (see
vikix-window-agent), by workspace and then by window; one in a window that
is put away (the drop-down terminal's, on its hidden workspace) comes last.
Each one's window is marked with its name as it is found. With HELD, one
whose shell a release or tests hold says so (vikix-agents-held); nil for
bin/vikix-agents, which asks the notes itself."
  (let ((agents
          (flet ((hidden-p (group) (char= (char (group-name group) 0) #\.)))
            (loop for group in (let ((groups (sort-groups (current-screen))))
                                 (append (remove-if #'hidden-p groups) (remove-if-not #'hidden-p groups)))
                  append (loop for window in (sort (copy-list (group-windows group)) #'< :key #'window-number)
                               for agent = (vikix-window-agent window)
                               do (vikix-agent-mark window (getf agent :name))
                               when agent collect agent)))))
    ;; Each one's window named for its desk, the others unnamed (below).
    (ignore-errors (vikix-agent-titles-name (all-windows) agents))
    (if held (vikix-agents-held agents) agents)))

(defun vikix-agents-held (agents)
  "AGENTS, with what holds the shell of one that works, runs or sits at its
prompt said in its :words instead: waiting for a release (its turn in
.claude/release's queue), releasing, waiting for a test slot (tests/run.sh's
slots, other runs testing), testing. The words are bin/vikix-agents's own
(vikix-agents --waits PID...), from the notes the release and the tests
leave. Never signals: without the program, or on any error, AGENTS as they
are."
  (when agents
    (handler-case
        (let ((out (run-shell-command (format nil "vikix-agents --waits ~{~d~^ ~} 2>/dev/null"
                                              (mapcar (lambda (a) (getf a :pid)) agents))
                                      t)))
          (dolist (line (split-string out (string #\Newline)))
            (let* ((parts (split-string line (string #\Tab)))
                   (pid (ignore-errors (parse-integer (first parts))))
                   (agent (find pid agents :key (lambda (a) (getf a :pid)))))
              (when (and agent (second parts) (member (getf agent :state) '(:working :running :idle)))
                (setf (getf agent :words) (second parts))))))
      (error () nil)))
  agents)

(defun vikix-agent-away-p (agent)
  "Is AGENT's window put away, on a hidden workspace (the drop-down terminal)?"
  (char= (char (group-name (window-group (getf agent :window))) 0) #\.))

;;; --- Saying it ----------------------------------------------------------------------------

(defun vikix-agent-for (seconds)
  "SECONDS as a person says a while: \"40 s\", \"12 min\", \"2 h 10 min\", \"3 d\"."
  (cond ((< seconds 60) (format nil "~d s" seconds))
        ((< seconds 3600) (format nil "~d min" (floor seconds 60)))
        ((< seconds 86400) (format nil "~d h ~d min" (floor seconds 3600) (floor (mod seconds 3600) 60)))
        (t (format nil "~d d" (floor seconds 86400)))))

(defun vikix-agent-line (agent)
  "AGENT in a line: its name, folder, workspace, how long, what it's doing,
and its window's title or what it last said."
  (let ((window (getf agent :window)))
    (format nil "~8a ~30a  ~13a ~11a  ~19a  ~a"
            (getf agent :name)
            (let ((folder (vikix-short-path (getf agent :folder))))
              (if (> (length folder) 30) (concat "..." (subseq folder (- (length folder) 27))) folder))
            (if (vikix-agent-away-p agent)
                "put away"
                (format nil "workspace ~a" (group-name (window-group window))))
            (vikix-agent-for (getf agent :seconds))
            (getf agent :words)
            (vikix-one-line (or (and (eq (getf agent :state) :asks) (getf agent :said))
                                (window-title window))
                            60))))

(defun vikix-agents-tsv ()
  "The agents, a line each, tab-separated, for bin/vikix-agents: name, pid,
folder, workspace, window number, seconds, state, its words, what it said,
the window's title, and the window's name for its desk (\"office-ui ·
Claude\"; empty off a desk). Tabs and line ends inside a field are spaces."
  (flet ((field (x) (substitute-if #\Space (lambda (c) (member c '(#\Tab #\Newline #\Return)))
                                   (princ-to-string (or x "")))))
    (format nil "~{~a~^~%~}"
            (mapcar (lambda (a)
                      (let ((w (getf a :window)))
                        (format nil "~{~a~^	~}"
                                (mapcar #'field
                                        (list (getf a :name) (getf a :pid) (getf a :folder)
                                              (group-name (window-group w)) (window-number w)
                                              (getf a :seconds) (string-downcase (getf a :state))
                                              (getf a :words) (getf a :said) (window-title w)
                                              (vikix-agent-desk-mark w))))))
                    (vikix-agents nil)))))

(defcommand vikix-agents-pick () ()
  "The agents running on this desktop: each with its folder, its workspace,
how long it has run and what it is doing (working, at its prompt, waiting
for you). Pick one to go to its window. `vikix agents` in a terminal adds
what each has left uncommitted."
  (let ((agents (vikix-agents)))
    (if (null agents)
        (message "No agent is running in a terminal here. Super+a starts one.")
        (let ((picked (second (select-from-menu (current-screen)
                                                (mapcar (lambda (a) (list (vikix-agent-line a) a)) agents)
                                                (format nil "~d agent~:p. Go to: " (length agents))))))
          (cond ((null picked))
                ;; Its window is put away: brought here, as Super+Shift+g brings one.
                ((vikix-agent-away-p picked)
                 (vikix-bring-window-here (getf picked :window)))
                (t (vikix-goto-window (getf picked :window))))))))

;;; --- A desk --------------------------------------------------------------------------------

(defun vikix-agent-desk-claim ()
  "Go to a workspace an agent can have to itself: the first with no window
(this one, when none is empty). Its name. For vikix agents desk, which
then opens the agent's terminal there."
  (let ((empty (find-if (lambda (g) (and (null (group-windows g)) (plusp (group-number g))))
                        (sort-groups (current-screen)))))
    (when (and empty (not (eq empty (current-group))))
      (switch-to-group empty))
    (group-name (current-group))))

;;; --- The desk's name on the window --------------------------------------------------------
;;;
;;; A terminal with an agent at a desk is named for the desk, "office-ui ·
;;; Claude": the name is StumpWM's own user title for the window (what the
;;; title bar, the window list, the overview and the palette show through
;;; window-name), so the X title the agent keeps writing (window-title: the
;;; mark Claude Code turns while it works) stays as it is, and what the agent
;;; is doing is still read from it. The name is written on the window too
;;; (_VIKIX_DESK), so a restarted desktop, which starts with no user titles,
;;; finds it and the number it held. The desk is found without git: a desk is
;;; a worktree, whose .git is a file naming the repository's .git/worktrees/
;;; (the project's own folder has a .git folder), and its topic is the
;;; folder's ending after the repository's name and a dash; an agent that sat
;;; down elsewhere (vikix agents sit) is at the seat's folder, from the seats
;;; file bin/vikix-agents keeps. Two of one provider at one desk are "Claude
;;; 1" and "Claude 2": each keeps its number while it runs, a new one takes
;;; the lowest free. A terminal with no agent at a desk is left alone, and
;;; one whose agent has gone (a shell again, or another agent now) is named
;;; again or unnamed at the next pass. A pass runs at a title change (once a
;;; second at most: a provider's title turns several times a second, so the
;;; rest wait for one pass two seconds on), a few seconds after a terminal
;;; opens, at the rules' ticker, at every vikix-agents, and when sit asks;
;;; it reads /proc and Lisp state only, and names a window only when its
;;; name changes, so nothing goes round: a user title makes no X event.

(defparameter *vikix-agent-shown-names*
  '(("claude" . "Claude") ("codex" . "Codex") ("opencode" . "OpenCode") ("gemini" . "Gemini")
    ("antigravity" . "Antigravity") ("aider" . "Aider"))
  "Each agent's name as the window's name writes it.")

(defun vikix-agent-shown-name (name)
  (or (cdr (assoc name *vikix-agent-shown-names* :test #'string=)) (string-capitalize name)))

(defun vikix-agent-basename (path)
  (let ((path (string-right-trim "/" path)))
    (subseq path (1+ (or (position #\/ path :from-end t) -1)))))

(defun vikix-agent-desk (folder)
  "The desk FOLDER is in: (values DESK TOPIC), or nil. A desk is a git
worktree: the nearest .git up from FOLDER is a file, \"gitdir: REPO/.git/
worktrees/NAME\"; the project's own folder, whose .git is a folder, is no
desk, nor is a folder outside any repository. The topic is the worktree
folder's name after the repository's and a dash (vikix-office-agent at a
worktree of vikix: office-agent), else the whole name."
  (let ((dir (string-right-trim "/" (or folder ""))))
    (loop while (plusp (length dir))
          do (let* ((git (concatenate 'string dir "/.git"))
                    (st (ignore-errors (sb-posix:stat git))))
               (when st
                 (return
                   (unless (sb-posix:s-isdir (sb-posix:stat-mode st))
                     (let* ((line (ignore-errors
                                   (with-open-file (in git :external-format :utf-8) (read-line in nil))))
                            (gitdir (and line (eql 0 (search "gitdir:" line)) (string-trim " " (subseq line 7))))
                            (at (and gitdir (search "/.git/worktrees/" gitdir))))
                       (when at
                         (let* ((prefix (concatenate 'string (vikix-agent-basename (subseq gitdir 0 at)) "-"))
                                (name (vikix-agent-basename dir)))
                           (values dir (if (and (> (length name) (length prefix))
                                                (string= prefix name :end2 (length prefix)))
                                           (subseq name (length prefix))
                                           name))))))))
               (let ((slash (position #\/ dir :from-end t)))
                 (setf dir (if slash (subseq dir 0 slash) "")))))))

(defun vikix-json-field (line key)
  "KEY's value in LINE, one JSON object as Python writes it: a string with
its escapes undone, or an integer; nil without it."
  (let* ((mark (format nil "\"~a\":" key))
         (at (search mark line))
         (i (and at (+ at (length mark)))))
    (when i
      (loop while (and (< i (length line)) (char= (char line i) #\Space)) do (incf i))
      (cond ((>= i (length line)) nil)
            ((char/= (char line i) #\") (parse-integer line :start i :junk-allowed t))
            (t (with-output-to-string (out)
                 (loop with j = (1+ i)
                       while (< j (length line))
                       do (let ((c (char line j)))
                            (cond ((char= c #\") (return))
                                  ((char= c #\\)
                                   (incf j)
                                   (when (< j (length line))
                                     (case (char line j)
                                       (#\n (write-char #\Newline out))
                                       (#\t (write-char #\Tab out))
                                       (#\r (write-char #\Return out))
                                       (#\b (write-char #\Backspace out))
                                       (#\f (write-char #\Page out))
                                       (#\u (let ((code (ignore-errors
                                                         (parse-integer line :start (1+ j) :end (min (length line) (+ j 5))
                                                                             :radix 16))))
                                              (when code (write-char (code-char code) out))
                                              (incf j 4)))
                                       (t (write-char (char line j) out)))))
                                  (t (write-char c out))))
                          (incf j))))))))

(defvar *vikix-agent-seats* (cons nil nil)
  "The seats file as last read: ((MTIME . SIZE) . ((PID . FOLDER) ...)).")

(defun vikix-agent-seats-file ()
  "Where bin/vikix-agents keeps the seats (XDG_STATE_HOME honoured, as there)."
  (let ((xdg (sb-posix:getenv "XDG_STATE_HOME")))
    (if (and xdg (plusp (length xdg)))
        (format nil "~a/vikix/office/seats.jsonl" xdg)
        (namestring (merge-pathnames ".local/state/vikix/office/seats.jsonl" (user-homedir-pathname))))))

(defun vikix-agent-seats ()
  "The seats taken with vikix agents sit, (PID . FOLDER) each; read again
only when the file changed. Only read: bin/vikix-agents keeps it."
  (let* ((file (vikix-agent-seats-file))
         (st (ignore-errors (sb-posix:stat file)))
         (stamp (and st (cons (sb-posix:stat-mtime st) (sb-posix:stat-size st)))))
    (cond ((null st) nil)
          ((equal stamp (car *vikix-agent-seats*)) (cdr *vikix-agent-seats*))
          (t (let ((seats (ignore-errors
                           (with-open-file (in file :external-format :utf-8)
                             (loop for line = (read-line in nil)
                                   while line
                                   for pid = (vikix-json-field line "pid")
                                   for folder = (vikix-json-field line "folder")
                                   when (and (integerp pid) (stringp folder)) collect (cons pid folder))))))
               (setf *vikix-agent-seats* (cons stamp seats))
               seats)))))

(defun vikix-agent-desk-of (agent)
  "(values DESK TOPIC) of AGENT's desk: the seat it took (vikix agents
sit), else the desk its folder is in; nil off one."
  (vikix-agent-desk (or (cdr (assoc (getf agent :pid) (vikix-agent-seats))) (getf agent :folder))))

(defvar *vikix-agent-desk-numbers* (make-hash-table :test 'eql)
  "Each agent, by process number, and the number it holds at its desk:
(DESK PROVIDER N). An agent that is gone loses its entry at the next pass.")

(defvar *vikix-agent-marks* (make-hash-table :test 'eq)
  "Each window and the name written on it (_VIKIX_DESK; \"\" for none), as
read once or written here, so a pass asks the X server nothing.")

(defun vikix-agent-desk-mark (window)
  "The name written on WINDOW (_VIKIX_DESK), or nil."
  (let ((known (gethash window *vikix-agent-marks*)))
    (when (null known)
      (setf known (or (ignore-errors
                       (let ((bytes (xlib:get-property (window-xwin window) :_VIKIX_DESK)))
                         (and bytes (sb-ext:octets-to-string (coerce bytes '(vector (unsigned-byte 8)))
                                                             :external-format :utf-8))))
                      ""))
      (setf (gethash window *vikix-agent-marks*) known))
    (and (plusp (length known)) known)))

(defun vikix-agent-titles (agents)
  "What to name the window of each of AGENTS (vikix-window-agent's plists)
that is at a desk: (AGENT . \"TOPIC · Provider\"), with a number after the
provider when more of that provider are at the desk, or when the number
isn't 1 (the first may have gone). One that holds a number keeps it; the
rest take the lowest free, the longest-running first, or the number its
window was marked with before a restart when that is free."
  (let ((at '()) (taken (make-hash-table :test 'equal)))
    (dolist (a agents)
      (multiple-value-bind (desk topic) (vikix-agent-desk-of a)
        (when desk (push (list a desk topic (vikix-agent-shown-name (getf a :name))) at))))
    (setf at (nreverse at))
    ;; The numbers of agents gone are anyone's tomorrow.
    (let ((live (mapcar (lambda (row) (getf (first row) :pid)) at)))
      (maphash (lambda (pid held) (declare (ignore held))
                 (unless (member pid live) (remhash pid *vikix-agent-desk-numbers*)))
               *vikix-agent-desk-numbers*))
    (dolist (row at)
      (destructuring-bind (a desk topic provider) row
        (declare (ignore topic))
        (let ((held (gethash (getf a :pid) *vikix-agent-desk-numbers*)))
          (if (and held (equal (first held) desk) (equal (second held) provider))
              (push (third held) (gethash (cons desk provider) taken))
              (remhash (getf a :pid) *vikix-agent-desk-numbers*)))))
    (dolist (row (stable-sort (copy-list at) #'> :key (lambda (row) (getf (first row) :seconds))))
      (destructuring-bind (a desk topic provider) row
        (unless (gethash (getf a :pid) *vikix-agent-desk-numbers*)
          (let* ((have (gethash (cons desk provider) taken))
                 (mark (vikix-agent-desk-mark (getf a :window)))
                 (head (format nil "~a · ~a " topic provider))
                 (kept (and mark (eql 0 (search head mark))
                            (ignore-errors (parse-integer mark :start (length head) :junk-allowed t))))
                 (n (if (and kept (plusp kept) (not (member kept have)))
                        kept
                        (loop for n from 1 unless (member n have) return n))))
            (setf (gethash (getf a :pid) *vikix-agent-desk-numbers*) (list desk provider n))
            (push n (gethash (cons desk provider) taken))))))
    (mapcar (lambda (row)
              (destructuring-bind (a desk topic provider) row
                (let ((n (third (gethash (getf a :pid) *vikix-agent-desk-numbers*)))
                      (shared (rest (gethash (cons desk provider) taken))))
                  (cons a (format nil "~a · ~a~@[ ~d~]" topic provider (and (or (> n 1) shared) n))))))
            at)))

(defvar *vikix-agent-title-sets* 0
  "How many times a window was named or unnamed: the tests watch it stay
still while a provider's title turns.")

(defun vikix-agent-title-apply (window title)
  "Name WINDOW TITLE (its user title, and the mark _VIKIX_DESK), or with
no TITLE take off the name this gave it. A name the user gave since, with
StumpWM's title command (one that is neither the mark nor nothing), is
theirs and stays. Nothing is done when nothing changes. True when the
name shown changed."
  (ignore-errors
   (let ((mark (vikix-agent-desk-mark window))
         (shown (window-user-title window)))
     (flet ((write-mark (text)
              (xlib:change-property (window-xwin window) :_VIKIX_DESK
                                    (sb-ext:string-to-octets text :external-format :utf-8) :utf8_string 8)
              (setf (gethash window *vikix-agent-marks*) text)))
       (cond ((and title shown mark (not (equal shown mark)) (not (equal shown title)))
              nil)
             ((and title (not (equal shown title)))
              (setf (window-user-title window) title)
              (write-mark title)
              (incf *vikix-agent-title-sets*)
              t)
             ((and title (not (equal mark title)))   ; named already (the user did); the mark says so now
              (write-mark title)
              nil)
             ((and (null title) mark)
              (xlib:delete-property (window-xwin window) :_VIKIX_DESK)
              (setf (gethash window *vikix-agent-marks*) "")
              (when (equal (window-user-title window) mark)
                (setf (window-user-title window) nil)
                (incf *vikix-agent-title-sets*)
                t)))))))

(defvar *vikix-agent-titles-at* 0 "When the last pass ran (universal time).")
(defvar *vikix-agent-titles-timer* nil "The pass waiting to run, when one is.")

(defun vikix-agent-titles-name (windows agents)
  "Name each of WINDOWS for the desk of its agent among AGENTS (the ones
found in them), and unname the rest of them that were named. Redraws
what shows names when one changed."
  (let ((titles (vikix-agent-titles agents))
        (changed nil))
    (dolist (w windows)
      (let ((row (find w titles :key (lambda (r) (getf (car r) :window)))))
        (when (vikix-agent-title-apply w (cdr row))
          (setf changed t)
          (when (fboundp 'vikix-titlebar-redraw) (ignore-errors (funcall 'vikix-titlebar-redraw w))))))
    (setf *vikix-agent-titles-at* (get-universal-time))
    (when changed (ignore-errors (update-all-mode-lines)))
    changed))

(defun vikix-agent-titles-refresh ()
  "A pass over every window: the terminals with an agent at a desk named
for it, the others left or unnamed. Reads /proc and Lisp state only; never
an error."
  (ignore-errors
   (let* ((windows (all-windows))
          (agents (loop for w in windows for a = (vikix-window-agent w) when a collect a)))
     (vikix-agent-titles-name windows agents)))
  nil)

(defun vikix-agent-titles-soon ()
  "A pass now, unless one ran this second: then one in two seconds, once,
however many title changes come meanwhile."
  (cond ((> (get-universal-time) *vikix-agent-titles-at*) (vikix-agent-titles-refresh))
        ((null *vikix-agent-titles-timer*)
         (setf *vikix-agent-titles-timer*
               (run-with-timer 2 nil (lambda ()
                                       (setf *vikix-agent-titles-timer* nil)
                                       (vikix-agent-titles-refresh)))))))

(defun vikix-agent-titles-tick ()
  "The rules' ticker's call (every 30 seconds): the pass that catches an
agent that never writes a title, and a terminal that is a shell again."
  (vikix-agent-titles-refresh))

(defun vikix-agent-title-new-window (window)
  "A terminal opened: a pass in three seconds, when vikix agent has
started the agent in it (one that writes no title would wait for the
ticker)."
  (ignore-errors
   (let* ((pid (vikix-window-pid window))
          (own (and pid (vikix-proc-cmdline pid))))
     (when (and own (member (vikix-layout-program (first own)) *vikix-layout-terminals* :test #'string=))
       (run-with-timer 3 nil (lambda () (ignore-errors (vikix-agent-titles-soon))))))))

(defun vikix-agent-title-forget (window)
  (remhash window *vikix-agent-marks*))

(remove-hook *new-window-hook* 'vikix-agent-title-new-window)
(add-hook *new-window-hook* 'vikix-agent-title-new-window)
(remove-hook *destroy-window-hook* 'vikix-agent-title-forget)
(add-hook *destroy-window-hook* 'vikix-agent-title-forget)

;; A title the agent writes (Claude Code's turning mark): the pass, once a
;; second at most. The encapsulation is by name, so a reload replaces it.
(sb-int:unencapsulate 'update-window-properties 'vikix-agent-title)
(sb-int:encapsulate 'update-window-properties 'vikix-agent-title
                    (lambda (f window atom)
                      (prog1 (funcall f window atom)
                        (when (eq atom :wm_name)
                          (ignore-errors (vikix-agent-titles-soon))))))
