;;; vikix-office.el --- Tasks and agents in their own frame, or your terminal -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'button)
(require 'subr-x)

(defvar vikix-office-command
  (list (expand-file-name "../../bin/vikix-agents"
                          (file-name-directory (or load-file-name buffer-file-name))))
  "Backend command, as an argument list; tests use a stand-in.")
(defvar vikix-office-interval 10)
(defvar vikix-office-timeout 45)
(defvar-local vikix-office--data nil)
(defvar-local vikix-office--selected nil)
(defvar-local vikix-office--detail nil)
(defvar-local vikix-office--owner nil)
(defvar-local vikix-office--frame nil)
(defvar-local vikix-office--own-frame nil)
(defvar-local vikix-office--windows nil)
(defvar-local vikix-office--timer nil)
(defvar-local vikix-office--process nil)
(defvar-local vikix-office--action nil)
(defvar-local vikix-office--closed nil)
(defvar-local vikix-office--archive nil)

(defun vikix-office--get (key object) (alist-get key object))
(defun vikix-office--text (value) (if (stringp value) value (format "%s" (or value "unknown"))))
(defun vikix-office--one-line (value)
  (replace-regexp-in-string "[\n\r\t]+" " " (vikix-office--text value)))
(defun vikix-office--time (value)
  (if (numberp value) (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time value)) "time unknown"))
(defun vikix-office--owner-buffer ()
  (if (buffer-live-p vikix-office--owner) vikix-office--owner (current-buffer)))
(defun vikix-office--rows ()
  (alist-get (if vikix-office--archive 'archive 'desks) vikix-office--data))
(defun vikix-office--row ()
  (cl-find vikix-office--selected (vikix-office--rows)
           :key (lambda (r) (alist-get 'id r)) :test #'equal))
(defun vikix-office--position (id)
  "Find ID by value: each JSON refresh creates new string objects."
  (let ((position (point-min)))
    (while (and (< position (point-max))
                (not (equal (get-text-property position 'office-id) id)))
      (setq position (next-single-property-change position 'office-id nil (point-max))))
    (and (< position (point-max)) position)))
(defun vikix-office--notice (text)
  (setq header-line-format (concat "  " (replace-regexp-in-string "%" "%%" text)))
  (force-mode-line-update))

(defun vikix-office--request (args slot done)
  "Run ARGS without a shell. DONE receives output or an error string."
  (let* ((owner (current-buffer)) (output (generate-new-buffer " *Office response*"))
         (stderr (generate-new-buffer " *Office error*")) process)
    (condition-case err
        (setq process
              (make-process
               :name "Office backend" :buffer output :stderr stderr :noquery t
               :connection-type 'pipe :command (append vikix-office-command args)
               :sentinel
               (lambda (p _event)
                 (when (memq (process-status p) '(exit signal))
                   (when-let* ((timer (process-get p 'timeout))) (cancel-timer timer))
                   (unwind-protect
                       (when (buffer-live-p owner)
                         (with-current-buffer owner
                           (when (eq (symbol-value slot) p) (set slot nil))
                           (unless vikix-office--closed
                             (funcall done
                                      (with-current-buffer output (buffer-string))
                                      (unless (and (eq (process-status p) 'exit) (= (process-exit-status p) 0))
                                        (if (process-get p 'timed-out) "Backend timed out"
                                          (concat "Backend failed: "
                                                  (with-current-buffer stderr (buffer-string)))))))))
                     (when (buffer-live-p output) (kill-buffer output))
                     (when (buffer-live-p stderr) (kill-buffer stderr)))))))
      (error (kill-buffer output) (kill-buffer stderr)
             (funcall done "" (error-message-string err))))
    (when process
      (set slot process)
      (process-put process 'timeout
                   (run-at-time vikix-office-timeout nil
                                (lambda ()
                                  (when (process-live-p process)
                                    (process-put process 'timed-out t)
                                    (delete-process process))))))
    process))

(defun vikix-office--failure (message)
  (when vikix-office--data
    (setf (alist-get 'live_known vikix-office--data) :false)
    (dolist (row (append (alist-get 'desks vikix-office--data) (alist-get 'archive vikix-office--data)))
      (setf (alist-get 'live_known row) :false))
    (vikix-office--render))
  (vikix-office--notice (concat message " — previous data retained; activity unknown")))

(defun vikix-office-refresh ()
  "Refresh asynchronously, keeping the last successful view on failure."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (or vikix-office--closed (process-live-p vikix-office--process)
                (process-live-p vikix-office--action))
      (vikix-office--notice "Refreshing…  g refresh · RET details · a go to agent · c continue · x close agent · q close Office")
      (vikix-office--request
       '("office" "--json") 'vikix-office--process
       (lambda (output error)
         (if error (vikix-office--failure error)
           (condition-case err
               (let* ((data (json-parse-string output :object-type 'alist :array-type 'list
                                               :null-object nil :false-object :false))
                      (errors (alist-get 'errors data)))
                 (unless (and (= (or (alist-get 'version data) 0) 1) (assq 'desks data))
                   (error "Invalid Office snapshot"))
                 ;; A partial observation must not erase useful previous agents
                 ;; or turn them into 'stopped'. Keep the view, labelled stale.
                 (if (and errors vikix-office--data)
                     (vikix-office--failure (string-join errors "; "))
                   (setq vikix-office--data data)
                   (vikix-office--render)
                   (vikix-office--notice
                    (if errors (string-join errors "; ")
                      (concat "Updated " (vikix-office--time (alist-get 'at data))
                              " · g refresh · RET details · a go to agent · c continue · x close agent · q close Office")))))
             (error (vikix-office--failure (error-message-string err))))))))))

(defun vikix-office--button (label action)
  (insert-text-button label 'follow-link t 'action (lambda (_) (funcall action)))
  (insert "  "))

(defun vikix-office--render ()
  (let* ((rows (vikix-office--rows))
         (owner (current-buffer))
         (old (point)) (column (current-column))
         (views (mapcar (lambda (w) (list w (window-start w) (window-hscroll w)))
                        (get-buffer-window-list (current-buffer) nil t))))
    (unless (vikix-office--row) (setq vikix-office--selected (alist-get 'id (car rows))))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (propertize "The Office\n" 'face '(:inherit variable-pitch :height 1.5 :weight bold)))
      (insert "Tasks first. Conversations stay in their agent terminals.\n\n")
      (vikix-office--button (if vikix-office--archive "Back to desks" (format "Archive (%d)" (length (alist-get 'archive vikix-office--data))))
                            (lambda () (with-current-buffer owner (vikix-office-toggle-archive))))
      (when (and vikix-office--archive rows (eq (alist-get 'live_known vikix-office--data) t)
                 (not (alist-get 'errors vikix-office--data)))
        (vikix-office--button "Purge archive…" (lambda () (with-current-buffer owner (vikix-office-purge-archive)))))
      (insert "\n\n")
      (if (null rows) (insert (if vikix-office--archive "Archive is empty.\n" "No desks yet. Start one with vikix agents desk PROJECT TOPIC.\n"))
        (dolist (group (if vikix-office--archive '("Archived") '("Needs you" "Working" "Parked" "Finished")))
          (insert (propertize (concat group "\n") 'face 'bold))
          (let ((members (cl-remove-if-not (lambda (r) (equal (alist-get 'group r) group)) rows)))
            (if (null members) (insert "  —\n")
              (dolist (r members)
                (let ((start (point)) (id (alist-get 'id r)))
                  (insert-text-button (concat "  " (truncate-string-to-width (vikix-office--one-line (alist-get 'title r)) 100 nil nil "…"))
                                      'follow-link t 'action
                                      (lambda (button)
                                        (goto-char (button-start button))
                                        (setq vikix-office--selected id)
                                        (vikix-office--render-detail)
                                        (vikix-office-details)))
                  (insert "\n    " (vikix-office--one-line (or (alist-get 'project (alist-get 'desk r)) "Project unrecorded"))
                          " · " (vikix-office--one-line (alist-get 'provider r))
                          "\n    Live: "
                          (if (eq (alist-get 'live_known r) :false) "unknown"
                            (if (alist-get 'agents r)
                                (string-join (mapcar (lambda (a) (vikix-office--one-line (alist-get 'doing a))) (alist-get 'agents r)) ", ")
                              "none observed"))
                          " · Handoff: " (vikix-office--one-line (alist-get 'status r))
                          "\n    Next: " (truncate-string-to-width (vikix-office--one-line (alist-get 'next_action r)) 110 nil nil "…") "\n")
                  (add-text-properties start (point) `(office-id ,id)))))
            (insert "\n")))))
    (let ((position (vikix-office--position vikix-office--selected)))
      (goto-char (or position (min old (point-max))))
      (when position (move-to-column column)))
    (dolist (view views)
      (when (window-live-p (car view))
        (set-window-start (car view) (min (nth 1 view) (point-max)) t)
        (set-window-hscroll (car view) (nth 2 view))
        (set-window-point (car view) (point))))
    (vikix-office--render-detail)))

(defun vikix-office--signed (label entry)
  (insert (propertize (concat label "\n") 'face 'bold)
          (vikix-office--text (or (alist-get 'text entry) (alist-get 'value entry) "Unrecorded")) "\n")
  (when entry (insert "  " (vikix-office--text (alist-get 'by entry)) " · "
                      (vikix-office--time (alist-get 'at entry)) "\n")))

(defun vikix-office--render-detail ()
  (when (buffer-live-p vikix-office--detail)
    (let ((r (vikix-office--row)) (owner (current-buffer)))
      (with-current-buffer vikix-office--detail
        (let ((inhibit-read-only t) (old (point))
              (views (mapcar (lambda (w) (cons w (window-start w)))
                             (get-buffer-window-list (current-buffer) nil t))))
          (erase-buffer)
          (if (not r) (insert "Select a desk to see its task and handoff.\n")
            (insert (propertize (vikix-office--text (alist-get 'title r)) 'face '(:inherit variable-pitch :height 1.3 :weight bold)) "\n\n")
            (if (eq (alist-get 'archived r) t)
                (progn
                  (insert "Archived — desk removed. No action is needed.\nHistorical handoff below; its next action may already be completed.\n")
                  (when (and (eq (alist-get 'live_known r) t) (alist-get 'id (alist-get 'desk r)))
                    (vikix-office--button "Forget this record…" (lambda () (with-current-buffer owner (vikix-office-forget))))))
              (when (eq (alist-get 'live_known r) t)
                (let ((agents (alist-get 'agents r)))
                  (when (cl-some (lambda (a) (not (member (alist-get 'window a) '(nil "")))) agents)
                    (vikix-office--button "Go to agent" (lambda () (with-current-buffer owner (vikix-office-go)))))
                  (when (and (not agents) (eq (alist-get 'exists r) t))
                    (vikix-office--button "Continue…" (lambda () (with-current-buffer owner (vikix-office-continue)))))
                  (when (cl-some (lambda (a) (alist-get 'process_start a)) agents)
                    (vikix-office--button "Close agent…" (lambda () (with-current-buffer owner (vikix-office-close-agent))))))))
            (insert "\n\n")
            (vikix-office--signed "User task" (alist-get 'task r))
            (insert "\nAgent claims — review does not mean merged\n")
            (dolist (pair '(("Status" . status) ("Summary and decisions" . summary) ("Next action" . next)))
              (vikix-office--signed (car pair) (alist-get (cdr pair) (alist-get 'handoff r))))
            (let ((now (alist-get 'now r)))
              (insert "\nObserved Git state · " (vikix-office--time (alist-get 'at now)) "\n"
                      (vikix-office--text (alist-get 'worktree (alist-get 'desk r))) "\n"
                      (if (eq (alist-get 'exists r) :false) "Worktree removed; record retained\n" "")
                      "Branch: " (vikix-office--text (alist-get 'branch now)) "\nCommit: "
                      (vikix-office--text (alist-get 'commit now)) "\nUncommitted files: "
                      (vikix-office--text (alist-get 'dirty now)) "\n"))
            (insert "\nReported checks — freshness compares code, not the truth of the report\n")
            (unless (alist-get 'checks r) (insert "No checks recorded\n"))
            (dolist (c (alist-get 'checks r))
              (insert (if (eq (alist-get 'ok c) t) "Reported passed: " "Reported failed: ")
                      (vikix-office--text (alist-get 'name c)) "\n  "
                      (vikix-office--text (alist-get 'freshness c)) " · "
                      (vikix-office--text (alist-get 'by c)) " · " (vikix-office--time (alist-get 'at c))
                      "\n  Tested commit: " (vikix-office--text (alist-get 'commit c))
                      " · dirty: " (vikix-office--text (alist-get 'dirty c)) "\n"))
            (insert "\nLive agents\n")
            (when (eq (alist-get 'live_known r) :false) (insert "Unknown — live discovery unavailable\n"))
            (dolist (a (alist-get 'agents r))
              (insert (format "%s %s · %s · workspace %s%s\n  %s\n"
                              (alist-get 'agent a) (alist-get 'pid a) (alist-get 'doing a)
                              (or (alist-get 'workspace a) "unknown")
                              ;; Its window's name on the desktop: the desk and the provider.
                              (if (member (alist-get 'desk_title a) '(nil ""))
                                  "" (concat " · " (vikix-office--one-line (alist-get 'desk_title a))))
                              (if (member (alist-get 'window a) '(nil "")) "No desktop window" (or (alist-get 'said a) "")))))
            (insert "\nSaved conversations (provider store availability)\n")
            (unless (alist-get 'sessions r)
              (insert (if (eq (alist-get 'archived r) t) "None recorded\n"
                        "None recorded; Continue offers an explicit fresh start\n")))
            (dolist (s (alist-get 'sessions r))
              (insert (format "%s · %s · %s\n  %s · %s\n" (alist-get 'provider s) (alist-get 'id s)
                              (pcase (alist-get 'available s) ('t "available") (:false "missing") (_ "unknown"))
                              (alist-get 'by s) (vikix-office--time (alist-get 'at s))))))
          (goto-char (min old (point-max)))
          (dolist (v views) (when (window-live-p (car v)) (set-window-start (car v) (min (cdr v) (point-max)) t))))))))

(defun vikix-office--track ()
  (when-let* ((id (get-text-property (point) 'office-id)))
    (unless (equal id vikix-office--selected)
      (setq vikix-office--selected id)
      (when (buffer-live-p vikix-office--detail)
        (with-current-buffer vikix-office--detail (goto-char (point-min))))
      (vikix-office--render-detail))))
(defun vikix-office-details ()
  (interactive)
  (vikix-office--track)
  (when-let* ((window (get-buffer-window vikix-office--detail vikix-office--frame))) (select-window window)))
(defun vikix-office-next (direction)
  (let* ((rows (vikix-office--rows))
         (ids (mapcar (lambda (r) (alist-get 'id r)) rows))
         (index (or (cl-position vikix-office--selected ids :test #'equal) 0))
         (id (nth (max 0 (min (1- (length ids)) (+ index direction))) ids)))
    (when id
      (goto-char (vikix-office--position id))
      (vikix-office--track))))

(defun vikix-office--act (args)
  (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
  (vikix-office--request args 'vikix-office--action
                         (lambda (output error)
                           (vikix-office--notice (or error (string-trim output) "Done")))))

(defun vikix-office-toggle-archive ()
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (setq vikix-office--archive (not vikix-office--archive)
          vikix-office--selected nil)
    (vikix-office--render)))

(defun vikix-office-purge-archive ()
  "Permanently remove the archived handoff records shown in this snapshot."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (and (eq (alist-get 'live_known vikix-office--data) t)
                 (not (alist-get 'errors vikix-office--data)))
      (user-error "Discovery unavailable; refresh before purging"))
    (let ((records (alist-get 'archive vikix-office--data))
          (token (alist-get 'archive_token vikix-office--data)))
      (unless records (user-error "Archive is empty"))
      (unless token (user-error "Refresh before purging"))
      (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
      (when (yes-or-no-p (format "Permanently purge %d archived desk records, including tasks, handoffs and checks? Project files and provider conversations stay. " (length records)))
        (vikix-office--request
         (list "office" "--purge-archive" token) 'vikix-office--action
         (lambda (output error)
           (if error (vikix-office--notice error)
             (message "%s" (string-trim output))
             (vikix-office-refresh))))))))
(defun vikix-office-forget ()
  "Remove the selected archived desk's record; files, branches and saved conversations stay."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--row)) (id (alist-get 'id (alist-get 'desk r))))
      (unless r (user-error "Select a desk first"))
      (unless (eq (alist-get 'archived r) t) (user-error "Only an archived desk's record can be forgotten"))
      (unless (eq (alist-get 'live_known vikix-office--data) t) (user-error "Live activity unknown; refresh first"))
      (unless (stringp id) (user-error "This desk has no record"))
      (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
      (when (yes-or-no-p (format "Forget the record of %s? Its task, handoff and checks go; files, branches and saved conversations stay. "
                                 (alist-get 'worktree (alist-get 'desk r))))
        (vikix-office--request
         (list "office" "--forget" id) 'vikix-office--action
         (lambda (output error)
           (if error (vikix-office--notice error)
             (message "%s" (string-trim output))
             (vikix-office-refresh))))))))
(defun vikix-office-go ()
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (when (eq (alist-get 'live_known vikix-office--data) :false) (user-error "Live activity unknown; refresh first"))
    (let* ((agents (alist-get 'agents (vikix-office--row)))
           (choices (mapcar (lambda (a) (cons (format "%s %s · workspace %s%s" (alist-get 'agent a) (alist-get 'pid a)
                                                      (alist-get 'workspace a)
                                                      (if (member (alist-get 'window a) '(nil "")) " · no window" "")) a)) agents))
           (a (if (= (length agents) 1) (car agents)
                (cdr (assoc (completing-read "Go to agent: " choices nil t) choices)))))
      (unless a (user-error "No live agent at this desk"))
      (when (member (alist-get 'window a) '(nil "")) (user-error "This agent has no desktop window"))
      (vikix-office--act (list "office" "--go" (number-to-string (alist-get 'pid a)))))))
(defun vikix-office-close-agent ()
  "Stop a selected agent, keeping its desk and files."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (eq (alist-get 'live_known vikix-office--data) t)
      (user-error "Live activity unknown; refresh first"))
    (let* ((r (vikix-office--row))
           (agents (alist-get 'agents r))
           (choices (mapcar (lambda (a)
                              (cons (format "%s %s · %s" (alist-get 'agent a)
                                            (alist-get 'pid a) (alist-get 'doing a)) a)) agents))
           (a (cond ((null agents) (user-error "No live agent at this desk"))
                    ((= (length agents) 1) (car agents))
                    (t (cdr (assoc (completing-read "Close agent: " choices nil t) choices))))))
      (unless (alist-get 'process_start a)
        (user-error "Agent identity unavailable; refresh first"))
      (when (yes-or-no-p (format "Close %s %s at %s? Running work will stop; desk and files stay. "
                                 (alist-get 'agent a) (alist-get 'pid a)
                                 (alist-get 'worktree (alist-get 'desk r))))
        (vikix-office--act (list "office" "--close-agent"
                                (number-to-string (alist-get 'pid a))
                                (alist-get 'process_start a)))))))

(defun vikix-office-continue ()
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--row)) (plans (alist-get 'resume r)) choices)
      (unless r (user-error "Select a desk first"))
      (when (eq (alist-get 'exists r) :false) (user-error "Worktree removed; the record is retained"))
      (when (eq (alist-get 'live_known vikix-office--data) :false) (user-error "Live activity unknown; refresh first"))
      (when (alist-get 'agents r) (user-error "An agent is already here; use Go to agent"))
      (dolist (entry plans)
        (let* ((provider (symbol-name (car entry))) (plan (cdr entry))
               (base (list "resume" (alist-get 'worktree (alist-get 'desk r)) "--use" provider)))
          (when (equal (alist-get 'mode plan) "resumed")
            (push (cons (format "Resume %s · saved %s" provider (alist-get 'id (alist-get 'session plan)))
                        (append base (list "--require-saved" "--expect-session" (alist-get 'id (alist-get 'session plan))))) choices))
          (push (cons (format "Start fresh with %s · %s" provider (alist-get 'why plan))
                      (append base '("--fresh"))) choices)))
      ;; Other providers are explicitly fresh; never choose an unrecorded session.
      (dolist (provider '("claude" "codex" "opencode" "gemini" "antigravity" "aider"))
        (unless (assq (intern provider) plans)
          (push (cons (concat "Start fresh with " provider)
                      (list "resume" (alist-get 'worktree (alist-get 'desk r)) "--use" provider "--fresh")) choices)))
      (let ((pick (completing-read "Continue (choose conversation or fresh start): " (reverse choices) nil t)))
        (vikix-office--act (cdr (assoc pick choices)))))))

(defun vikix-office--cleanup ()
  (setq vikix-office--closed t)
  (when (timerp vikix-office--timer) (cancel-timer vikix-office--timer))
  (setq vikix-office--timer nil)
  (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail))
  (dolist (p (list vikix-office--process vikix-office--action))
    (when (processp p)
      (when-let* ((timer (process-get p 'timeout))) (cancel-timer timer))
      (when (process-live-p p) (delete-process p)))))
(defun vikix-office--frame-deleted (frame)
  (when-let* ((buffer (frame-parameter frame 'vikix-office-buffer)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (vikix-office--cleanup)
        (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail)))
      (kill-buffer buffer))))
(add-hook 'delete-frame-functions #'vikix-office--frame-deleted)
(defun vikix-office-close ()
  "Leave the Office.
A frame the Office made for itself (`vikix-office-open', or the
terminal's client frame of `vikix agents office' in a terminal) is
deleted, so an emacsclient ends and the shell comes back; the only
frame there is never deleted.  Opened by hand in a frame of yours
(`vikix-office-open-here'), the frame's windows are put back as they
were."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((frame vikix-office--frame) (windows vikix-office--windows))
      (vikix-office--cleanup)
      (if (and vikix-office--own-frame (frame-live-p frame) (> (length (frame-list)) 1))
          (delete-frame frame)
        (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail))
        (kill-buffer (current-buffer))
        (when (and (window-configuration-p windows)
                   (frame-live-p (window-configuration-frame windows)))
          (set-window-configuration windows))))))
(defvar vikix-office-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "g") #'vikix-office-refresh)
    (define-key map (kbd "a") #'vikix-office-go)
    (define-key map (kbd "c") #'vikix-office-continue)
    (define-key map (kbd "x") #'vikix-office-close-agent)
    (define-key map (kbd "A") #'vikix-office-toggle-archive)
    (define-key map (kbd "q") #'vikix-office-close)
    (define-key map (kbd "RET") #'vikix-office-details)
    (define-key map (kbd "TAB") #'forward-button)
    (define-key map (kbd "<backtab>") #'backward-button)
    (define-key map (kbd "n") (lambda () (interactive) (vikix-office-next 1)))
    (define-key map (kbd "p") (lambda () (interactive) (vikix-office-next -1)))
    map))
(define-derived-mode vikix-office-mode special-mode "Office"
  "Tasks, handoffs and observed agent activity."
  (setq-local truncate-lines nil)
  (setq-local word-wrap t)
  (hl-line-mode 1)
  (add-hook 'post-command-hook #'vikix-office--track nil t)
  (add-hook 'kill-buffer-hook #'vikix-office--cleanup nil t))
;; The two ways in share one setup: an X frame of the Office's own on the
;; desktop, or the frame the call comes from, which is a terminal's when
;; `vikix agents office' runs with no display (emacsclient -nw).
(defun vikix-office--setup (frame own &optional windows)
  "Build the Office in FRAME: the desks on the left, the one picked on the right.
OWN says the frame is the Office's, deleted by q; WINDOWS is the frame's
window configuration to put back on q otherwise.  Returns the Office buffer."
  (let ((buffer (generate-new-buffer "*The Office*"))
        (detail (generate-new-buffer "*Office desk*")))
    (set-frame-parameter frame 'vikix-office-buffer buffer)
    (with-selected-frame frame
      (switch-to-buffer buffer)
      (delete-other-windows)
      (with-current-buffer detail
        (special-mode)
        (use-local-map (copy-keymap vikix-office-mode-map))
        (local-set-key (kbd "RET") #'push-button)
        (local-set-key (kbd "n") #'next-line)
        (local-set-key (kbd "p") #'previous-line)
        (setq-local vikix-office--owner buffer)
        (setq-local word-wrap t))
      ;; A terminal is often 80 columns: two columns of 40 would wrap every
      ;; line, so a narrow frame puts the desk below the list instead.
      (set-window-buffer (if (< (frame-width) 100)
                             (split-window-below (floor (* (window-height) 0.5)))
                           (split-window-right (floor (* (frame-width) 0.53))))
                         detail)
      (with-current-buffer buffer
        (vikix-office-mode)
        (setq vikix-office--frame frame vikix-office--detail detail
              vikix-office--own-frame own vikix-office--windows windows)
        (vikix-office--render)
        (vikix-office-refresh)
        (setq vikix-office--timer
              (run-at-time vikix-office-interval vikix-office-interval
                           (lambda () (when (buffer-live-p buffer) (with-current-buffer buffer (vikix-office-refresh))))))))
    buffer))
(defun vikix-office-open (&optional display)
  "Open the Office on X11 DISPLAY, inheriting Emacs's Vikix theme.
Interactively, the current graphical display or $DISPLAY."
  (interactive)
  (let ((existing (cl-find-if (lambda (f) (buffer-live-p (frame-parameter f 'vikix-office-buffer))) (frame-list))))
    (if existing (select-frame-set-input-focus existing)
      (setq display (or (and display (not (string-empty-p display)) display)
                        (and (display-graphic-p) (frame-parameter nil 'display))
                        (getenv "DISPLAY")))
      (unless (and display (not (string-empty-p display)))
        (user-error "The Office needs an X11 display; use vikix agents office --tty in a terminal"))
      (vikix-office--setup
       (make-frame `((window-system . x) (display . ,display)
                     (name . "The Office") (title . "The Office") (tool-bar-lines . 0) (menu-bar-lines . 0) (width . 150) (height . 44)))
       t))
    nil))
(defun vikix-office-open-here (&optional own)
  "Open the Office in the selected frame, a terminal's as well as a window's.
`vikix agents office' in a terminal (no display, or --tty) runs this
through emacsclient -nw with OWN non-nil: the client's frame is the
Office's, and q deletes it, which ends the client and gives the shell
back.  Called by hand, OWN is nil and q puts the frame's windows back."
  (interactive)
  (vikix-office--setup (selected-frame) own (unless own (current-window-configuration)))
  nil)
(provide 'vikix-office)
;;; vikix-office.el ends here
