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
;;;; works, a star when it is at its prompt). A window with an agent in it
;;;; carries the agent's name (_VIKIX_AGENT), for whatever wants to know.
;;;;
;;;; These are the first steps of NOVEL.md's "An office for agents": seeing
;;;; them, and a desk each (vikix agents desk: a workspace to itself and a
;;;; git worktree of its project; bin/vikix-agents makes it, this file only
;;;; finds the workspace). The house rules come after.

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

(defun vikix-agents ()
  "The agents running in this desktop's terminals: a plist each (see
vikix-window-agent), by workspace and then by window; one in a window that
is put away (the drop-down terminal's, on its hidden workspace) comes last.
Each one's window is marked with its name as it is found."
  (flet ((hidden-p (group) (char= (char (group-name group) 0) #\.)))
    (loop for group in (let ((groups (sort-groups (current-screen))))
                         (append (remove-if #'hidden-p groups) (remove-if-not #'hidden-p groups)))
          append (loop for window in (sort (copy-list (group-windows group)) #'< :key #'window-number)
                       for agent = (vikix-window-agent window)
                       do (vikix-agent-mark window (getf agent :name))
                       when agent collect agent))))

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
the window's title. Tabs and line ends inside a field are spaces."
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
                                              (getf a :words) (getf a :said) (window-title w))))))
                    (vikix-agents)))))

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
