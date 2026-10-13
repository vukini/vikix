;;; office-ui.el --- Fixture tests -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "../config/emacs/vikix-office.el" (file-name-directory load-file-name)) nil t)
(defun office-test-data (&optional ids)
  `((version . 1) (at . 1791300000) (live_known . t) (errors . nil) (releases . nil) (releases_kept . :false)
    (desks . ,(mapcar (lambda (id)
                       `((id . ,id) (title . ,(concat "Task " id)) (group . "Needs you")
                         (desk . ((project . "Vikix") (worktree . "/tmp/a desk with spaces")))
                         (status . "review") (live_known . t) (exists . t) (kind . "desk")
                         (task . nil) (handoff . nil) (now . nil) (checks . nil) (sessions . nil)
                         (agents . nil) (workers . nil) (provider . "codex") (next_action . "Review changes")
                         (resume . ((codex . ((mode . "resumed") (session . ((id . "abc")))))))))
                     (or ids '("a" "b"))))))
(defmacro office-test-buffer (&rest body)
  `(let ((buffer (generate-new-buffer " *Office test*")))
     (unwind-protect
         (with-current-buffer buffer
           (vikix-office-mode)
           (setq vikix-office--data (copy-tree (office-test-data)))
           ,@body)
       (when (buffer-live-p buffer) (kill-buffer buffer)))))
(defun office-test-wait ()
  "Until the request's sentinel has run (it clears the slot, then calls
DONE), or twenty seconds. A process that has exited is not enough: its
sentinel, which delivers the output, runs a moment later, and under the
load of other sessions' tests that moment was missed (2026-10-08)."
  (let ((end (+ (float-time) 20)))
    (while (and (or vikix-office--process vikix-office--action) (< (float-time) end))
      (accept-process-output nil 0.03))))
(ert-deftest office-selection-and-focus ()
  (office-test-buffer
   (save-window-excursion
     (switch-to-buffer buffer)
     (vikix-office--render)
     (vikix-office-next 1)
     (should (equal vikix-office--selected "b"))
     (let ((window (selected-window)))
       (setq vikix-office--data (office-test-data '("b" "x" "a")))
       (vikix-office--render)
       (should (eq window (selected-window)))
       (should (equal (get-text-property (point) 'office-id) "b")))
     (setq vikix-office--data (office-test-data '("a")))
     (vikix-office--render)
     (should (equal vikix-office--selected "a")))))
(ert-deftest office-details-claims-and-missing ()
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office detail test*"))
   (unwind-protect
       (progn
         (setf (alist-get 'exists (car (alist-get 'desks vikix-office--data))) :false)
         (vikix-office--render)
         (with-current-buffer vikix-office--detail
           (should (string-match-p "What the agent says" (buffer-string)))
           (should (string-match-p "which Vikix doesn't check" (buffer-string)))
           ;; No task and no handoff: a line each says so, not a Not written a row.
           (should (string-match-p "No task given" (buffer-string)))
           (should (string-match-p "No handoff yet" (buffer-string)))
           (should-not (string-match-p "Not written" (buffer-string)))
           (should (string-match-p "Worktree removed" (buffer-string))))
         (should-error (vikix-office-continue) :type 'user-error))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-details-hand-in ()
  "The hand-in's fields on the page: the status with what it means and
its signature at the row's end, the estimate against the clock, the
criteria ticked, a decision, a defect open, a finding with where, what
changed and the commits."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office hand-in test*"))
   (unwind-protect
       (progn
         (setf (alist-get 'handoff (car (alist-get 'desks vikix-office--data)))
               '((status . ((value . "review") (by . "codex 1") (at . 1791300000)))
                 (estimate . ((text . "40 min, if the log needs no new test") (minutes . 40) (by . "codex 1") (at . 1791300000)))
                 (summary . ((text . "The chapters are sorted.") (by . "codex 1") (at . 1791300000)))
                 (acceptance . ((items . (((text . "chapters in order") (done . t) (done_by . "codex 1") (done_at . 1791300000))
                                          ((text . "the log says so") (done . :false))))
                                (by . "user") (at . 1791300000)))
                 (decisions . (((text . "kept the old order") (by . "codex 1") (at . 1791300000))))
                 (defects . (((text . "slow past 500") (open . t) (by . "codex 1") (at . 1791300000))))
                 (review . (((text . "the heading is stale") (where . "log.md:1") (open . :false) (by . "claude 2") (at . 1791300000))))
                 (changed . ((base . "abc1234567") (files . (((path . "log.md") (add . 2) (del . 0) (uncommitted . t))
                                                              ((path . "notes.md") (add . 0) (del . 0) (uncommitted . t) (new . t))))
                             (more . 0) (by . "vikix") (at . 1791300000)))
                 (commits . ((base . "abc1234567") (list . (((hash . "77aff7b") (subject . "add b")))) (more . 0)
                             (by . "vikix") (at . 1791300000)))))
         (setf (alist-get 'estimate (car (alist-get 'desks vikix-office--data))) "10 min over its 40 min")
         (vikix-office--render)
         (with-current-buffer vikix-office--detail
           (let ((page (buffer-string)))
             (dolist (want '("Status +review · the agent asks you to look at its work"
                             "Estimate +10 min over its 40 min, if the log needs no new test"
                             "Summary +The chapters are sorted. · codex 1 · 2026-10-06 [0-9:]+ +[│|]$"
                             "Acceptance +1 of 2 done, as the agent ticks them; the criteria are yours"
                             "• \\[x\\] chapters in order · codex 1" "• \\[ \\] the log says so"
                             "Decided +1 choice made by the agent" "• kept the old order · codex 1"
                             "Defects +1 open of 1 the agent knows of" "• open: slow past 500 · codex 1"
                             "Review +0 open of 1 finding from a review" "• addressed: log.md:1 the heading is stale"
                             "Changed *2 files against abc1234" "\\+2 -0 log.md (uncommitted)" "\\+0 -0 notes.md (new, uncommitted)"
                             "Commits *1 past abc1234" "77aff7b add b"))
               (should (string-match-p want page)))
             ;; The signature sits in the shade at the row's end when it fits there (the
             ;; summary's), else on a line of its own (the status's, in this narrow buffer).
             (should (string-match-p "^[│|] +codex 1 · 2026-10-06" page))
             (should (eq (get-text-property (string-match "codex 1 · 2026" page) 'face page) 'shadow)))))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-folder-row-is-not-a-desk ()
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office folder test*"))
   (unwind-protect
       (let ((r (car (alist-get 'desks vikix-office--data))))
         (setf (alist-get 'kind r) "folder"
               (alist-get 'title r) "~"
               (alist-get 'group r) "Working"
               (alist-get 'next_action r) "Go to agent"
               (alist-get 'resume r) nil
               (alist-get 'now r) nil
               (alist-get 'desk r) '((worktree . "/home/someone"))
               (alist-get 'agents r) '(((agent . "codex") (pid . 7598) (doing . "running") (window . "3")
                                        (workspace . "2") (process_start . "100"))))
         (vikix-office--render)
         ;; Its own rows: no handoff named (the other row, a desk, still has one).
         (should (string-match-p "^[│|] Not a desk · codex · workspace 2 +[│|]\n[│|] Live +running +[│|]\n[│|] Next +Go to agent +[│|]$" (buffer-string)))
         (with-current-buffer vikix-office--detail
           (should (string-match-p "^[│|] Agents running in ~ +[│|]$" (buffer-string)))
           (should (string-match-p "Go to agent" (buffer-string)))
           (should (string-match-p "Close agent" (buffer-string)))
           (should-not (string-match-p "Continue" (buffer-string)))
           (should-not (string-match-p "Observed Git state\\|What the agent says\\|Saved conversations" (buffer-string)))
           (should (string-match-p "codex 7598 +workspace 2 · running" (buffer-string))))
         (should-error (vikix-office-continue) :type 'user-error)
         ;; Without an agent left there is still no Continue: nothing to continue in a folder.
         (setf (alist-get 'agents r) nil)
         (vikix-office--render)
         (with-current-buffer vikix-office--detail
           (should-not (string-match-p "Continue" (buffer-string)))))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-agent-workspaces-in-list ()
  (office-test-buffer
   (let* ((r (car (alist-get 'desks vikix-office--data)))
          (agents '(((agent . "codex") (window . "3") (workspace . "2"))
                    ((agent . "claude") (window . "4") (workspace . "writing"))
                    ((agent . "aider") (window . "") (workspace . ""))
                    ((agent . "gemini") (window . "5")))))
     (setf (alist-get 'agents r) agents)
     (vikix-office--render)
     ;; Each name stays paired with its own location, including named workspaces.
     (dolist (label '("codex · workspace 2" "claude · workspace writing"
                      "aider · no desktop window" "gemini · workspace unknown"))
       (should (string-match-p
                (regexp-quote label)
                ;; The box can wrap a label across lines in a narrow pane.
                (replace-regexp-in-string "[ │|\n]+" " " (buffer-string)))))
     ;; A refresh follows the live workspace instead of the desk's first one.
     (setf (alist-get 'workspace (car agents)) "7")
     (vikix-office--render)
     (should (string-match-p "codex · workspace 7" (buffer-string)))
     (should-not (string-match-p "codex · workspace 2" (buffer-string))))))
(ert-deftest office-attention-colours-the-desk ()
  "A desk whose terminal needs you is drawn in the colour the desktop gives it:
its title and its Live row in the face for asks, gup or close, and in the
details the agent's line; a desk needing nothing is plain."
  (should (eq (vikix-office--attention-face "gup") 'vikix-office-released))
  (should (eq (vikix-office--attention-face "asks") 'vikix-office-asks))
  (should (eq (vikix-office--attention-face "close") 'vikix-office-pushed))
  (should-not (vikix-office--attention-face ""))
  (should-not (vikix-office--attention-face nil))
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office attention test*"))
   (unwind-protect
       (let ((r (car (alist-get 'desks vikix-office--data))))
         ;; A key the data lacks: put into the row itself (setf alist-get would only cons onto r).
         (setcdr r (cons (cons 'attention "gup") (cdr r)))
         (setf (alist-get 'group r) "Needs you"
               (alist-get 'agents r) '(((agent . "claude") (pid . 4242) (doing . "its desk is gone; main has commits to push: gup")
                                        (window . "3") (workspace . "2") (attention . "gup"))))
         (vikix-office--render)
         (goto-char (point-min))
         (search-forward "Task a")
         (let ((face (get-text-property (match-beginning 0) 'face)))
           (should (memq 'vikix-office-released (if (listp face) face (list face)))))
         (search-forward "Live")
         (search-forward "its desk is gone")
         (should (eq (get-text-property (match-beginning 0) 'face) 'vikix-office-released))
         ;; The other desk, needing nothing, is plain.
         (search-forward "Task b")
         (should-not (memq 'vikix-office-released (let ((f (get-text-property (match-beginning 0) 'face))) (if (listp f) f (list f)))))
         (with-current-buffer vikix-office--detail
           (goto-char (point-min))
           (search-forward "its desk is gone")
           (should (eq (get-text-property (match-beginning 0) 'face) 'vikix-office-released))))
     (kill-buffer vikix-office--detail))))
(defun office-test-box-lines ()
  "The lines of the current buffer that belong to a box, with their widths."
  (cl-remove-if-not (lambda (line) (string-match-p "\\`[┌├└│+|]" line))
                    (split-string (buffer-string) "\n")))
(ert-deftest office-boxes-fit-the-window-and-wrap-inside ()
  "Every line of a box is as wide as its edges, at most the window's width, a
long text is wrapped inside and a long path cut; a window made another width
is drawn again at that width."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office box test*"))
   (unwind-protect
       (save-window-excursion
         (switch-to-buffer buffer)
         (delete-other-windows)
         (let ((r (car (alist-get 'desks vikix-office--data))))
           (setf (alist-get 'title r) (make-string 200 ?t)
                 (alist-get 'next_action r) (mapconcat #'identity (make-list 60 "word") " ")
                 (alist-get 'task r) `((text . ,(mapconcat #'identity (make-list 80 "task") " ")) (by . "user") (at . 1791300000))
                 (alist-get 'desk r) `((project . "Vikix") (worktree . ,(concat "/" (make-string 300 ?p))))))
         (vikix-office--render)
         (dolist (b (list buffer vikix-office--detail))
           (with-current-buffer b
             (let* ((lines (office-test-box-lines)) (widths (mapcar #'string-width lines)))
               (should lines)
               (should (= 1 (length (delete-dups (copy-sequence widths)))))
               (should (<= (car widths) (window-body-width (get-buffer-window buffer)))))))
         (should truncate-lines)
         (should (string-match-p "task task task task +[│|]\n" (with-current-buffer vikix-office--detail (buffer-string))))
         (should (string-match-p "…" (buffer-string)))
         ;; Narrower: the boxes follow the window.
         (let ((before vikix-office--width))
           (split-window-right)
           (vikix-office--resized (get-buffer-window buffer))
           (should (< vikix-office--width before))
           (should (= (+ 4 vikix-office--width) (string-width (car (office-test-box-lines)))))))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-releases-box-and-the-desks-release ()
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office release test*"))
   (unwind-protect
       (progn
         (setf (alist-get 'releases vikix-office--data)
               '(((project . "vikix") (topic . "wifi") (state . "testing (quick)") (since . 1791300000) (kind . "") (summary . "the bar") (waiting . :false))
                 ((project . "vikix") (topic . "docs") (state . "waiting for its turn") (since . 1791300100) (kind . "no version") (summary . "a guide") (waiting . t))))
         (setf (alist-get 'release (car (alist-get 'desks vikix-office--data))) "testing (quick) · since 10:00")
         (vikix-office--render)
         (let ((text (buffer-string)))
           (should (string-match-p "Releases" text))
           (should (< (string-match "wifi" text) (string-match "docs" text)))
           (should (string-match-p "waiting for its turn · since [0-9][0-9]:[0-9][0-9] · no version" text))
           (should (string-match-p "vikix · a guide" text))
           (should (string-match-p "Release +testing (quick) · since 10:00" text)))
         ;; The archive view has no queue; the desk's details say it in the Git state.
         (vikix-office-toggle-archive)
         (should-not (string-match-p "Releases" (buffer-string)))
         (vikix-office-toggle-archive)
         (setq vikix-office--selected "a")
         (vikix-office--render)
         (should (string-match-p "Release +testing (quick)" (with-current-buffer vikix-office--detail (buffer-string))))
         ;; Nothing under way: a line when a repository has released before, nothing otherwise.
         (setf (alist-get 'releases vikix-office--data) nil)
         (setf (alist-get 'releases_kept vikix-office--data) t)
         (setf (alist-get 'release (car (alist-get 'desks vikix-office--data))) "")
         (vikix-office--render)
         (should (string-match-p "No release under way" (buffer-string)))
         (should-not (string-match-p "Releases" (buffer-string)))
         (setf (alist-get 'releases_kept vikix-office--data) :false)
         (vikix-office--render)
         (should-not (string-match-p "[Rr]elease" (buffer-string))))
     (kill-buffer vikix-office--detail))))

(ert-deftest office-plans-box-and-the-desks-plan ()
  ;; The plans the runner has: a box above the desks, a plan a group, a line
  ;; a desk, what needs you in the asks face; a desk of a plan says which.
  (office-test-buffer
   (setf (alist-get 'plans vikix-office--data)
         '(((id . "abc") (name . "book") (file . "/home/v/book.toml") (project . "book") (state . "running") (pid . 42)
            (paused . :false) (stopped . :false) (done . 0) (started . 1791300000) (gate . "me") (at_once . 2)
            (desks . (((topic . "part-one") (folder . "/home/v/src/book-part-one") (line . "released") (released . t) (tasks . nil))
                      ((topic . "index") (folder . "/home/v/src/book-index") (line . "index: claude 1002 at work, 3 min") (released . :false) (tasks . nil))))
            (needs . ("cover: its release failed; the log says why")) (error . ""))
           ((id . "def") (name . "lost") (file . "/home/v/lost.toml") (project . "book") (state . "not running") (pid . 0)
            (desks . nil) (needs . nil) (error . "/home/v/lost.toml: No such file or directory"))))
   (setf (alist-get 'plan (car (alist-get 'desks vikix-office--data))) "book: index (running)")
   (vikix-office--render)
   (let ((text (buffer-string)))
     (should (string-match-p "Plans" text))
     (should (< (string-match "Plans" text) (string-match "Needs you" text)))
     (should (string-match-p "book · book · running · 2 at once · your yes before a release" text))
     (should (string-match-p "part-one +released" text))
     (should (string-match-p "index +index: claude 1002 at work, 3 min" text))
     (should (string-match-p "Needs you +cover: its release failed" text))
     (should (string-match-p "lost · book · not running" text))
     (should (string-match-p "No such file or directory" text))
     (should (string-match-p "Plan +book: index (running)" text)))
   ;; A plan done (every desk released; the snapshot's plans_done) is the
   ;; Archive's: off the first page, on the Archive page in a box of its own
   ;; saying when, its desks released, with Edit and Log alone; the Archive
   ;; button counts it apart from the records.
   (setf (alist-get 'plans_done vikix-office--data)
         '(((id . "ghi") (name . "guide") (file . "/home/v/guide.toml") (project . "vikix") (state . "done") (pid . 0)
            (paused . :false) (stopped . :false) (done . 1791300000) (started . 1791200000) (gate . "me") (at_once . 1)
            (desks . (((topic . "guide") (folder . "/home/v/src/vikix-guide") (line . "released") (released . t) (tasks . nil))))
            (needs . nil) (error . ""))))
   (vikix-office--render)
   (let ((text (buffer-string)))
     (should-not (string-match-p "Plans done" text))
     (should-not (string-match-p "guide · vikix · done" text))
     (should (string-match-p "Archive (0, 1 plan)" text)))
   (vikix-office-show-page 'archive)
   (let ((text (buffer-string)))
     (should (string-match-p "Plans done" text))
     (should (string-match-p (concat "guide · vikix · done " (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time 1791300000))
                                     " · 1 at once · your yes before a release")
                             text))
     (should (string-match-p "guide +released" text))
     (should-not (string-match-p "book · book · running" text))
     (should (string-match-p "No archived desk records" text))
     (let (found)
       (save-excursion
         (goto-char (point-min))
         (search-forward "Plans done")
         (while (forward-button 1 nil nil t)
           (push (button-label (button-at (point))) found)))
       (should (equal (nreverse found) '("Edit" "Log")))))
   (vikix-office-show-page 'desks)
   ;; No plan has run: no box, and no Plan line on a desk.
   (setf (alist-get 'plans vikix-office--data) nil)
   (setf (alist-get 'plans_done vikix-office--data) nil)
   (setf (alist-get 'plan (car (alist-get 'desks vikix-office--data))) "")
   (vikix-office--render)
   (should-not (string-match-p "Plans" (buffer-string)))
   (should-not (string-match-p "Plan +" (buffer-string)))))

(ert-deftest office-empty ()
  (office-test-buffer
   (setq vikix-office--data '((desks . nil)))
   (vikix-office--render)
   (should (string-match-p "No desks yet" (buffer-string)))))

(ert-deftest office-archive-hides-actions-and-clears-removed-selection ()
  (office-test-buffer
   (let ((archived (copy-tree (car (alist-get 'desks vikix-office--data)))))
     (setf (alist-get 'id archived) "old"
           (alist-get 'title archived) "Old task"
           (alist-get 'archived archived) t
           (alist-get 'exists archived) :false
           (alist-get 'group archived) "Archived"
           (alist-get 'archive vikix-office--data) (list archived))
     (setq vikix-office--detail (generate-new-buffer " *Archive details*"))
     (vikix-office--render)
     (should-not (string-match-p "Old task" (buffer-string)))
     (vikix-office-toggle-archive)
     (should (equal vikix-office--selected "old"))
     (with-current-buffer vikix-office--detail
       (should (string-match-p "No action is needed" (buffer-string)))
       (should-not (next-button (point-min))))
     (setf (alist-get 'archive vikix-office--data) nil)
     (vikix-office--render)
     (should-not vikix-office--selected)
     (with-current-buffer vikix-office--detail
       (should-not (string-match-p "Old task" (buffer-string))))
     (vikix-office-toggle-archive)
     (should (equal vikix-office--selected "a")))))

(ert-deftest office-parked-and-closed-desks-have-a-page-of-their-own ()
  "The first page holds Needs you, Working and Finished; Parked and Closed are
on a page of their own, reached by its button or k, with Back to desks; the
Archive is the third. The buttons count the other pages' rows."
  (office-test-buffer
   (let ((parked (copy-tree (car (alist-get 'desks vikix-office--data))))
         (closed (copy-tree (car (alist-get 'desks vikix-office--data))))
         (finished (copy-tree (car (alist-get 'desks vikix-office--data)))))
     (setf (alist-get 'id parked) "park" (alist-get 'title parked) "Parked task" (alist-get 'group parked) "Parked"
           (alist-get 'id closed) "gone" (alist-get 'title closed) "Closed task" (alist-get 'group closed) "Closed"
           (alist-get 'exists closed) :false
           (alist-get 'id finished) "fin" (alist-get 'title finished) "Finished task" (alist-get 'group finished) "Finished"
           (alist-get 'desks vikix-office--data) (append (alist-get 'desks vikix-office--data) (list parked finished closed))
           (alist-get 'archive vikix-office--data) '(((id . "old") (title . "Old task") (group . "Archived") (archived . t) (exists . :false))))
     (setq vikix-office--detail (generate-new-buffer " *Pages details*"))
     (vikix-office--render)
     (let ((text (buffer-string)))
       ;; The first page: its three groups, the parked and closed desks not on it.
       (should (string-match-p "Finished task" text))
       (should-not (string-match-p "Parked task" text))
       (should-not (string-match-p "Closed task" text))
       (should-not (string-match-p "Back to desks" text))
       (should (string-match-p "Parked and closed (2)" text))
       (should (string-match-p "Archive (1)" text))
       (should (string-match-p "New desk…" text)))
     ;; k: the parked page, its first row selected, Closed after Parked, no New desk.
     (vikix-office-toggle-parked)
     (should (eq vikix-office--page 'parked))
     (should (equal vikix-office--selected "park"))
     (let ((text (buffer-string)))
       (should (string-match-p "Parked task" text))
       (should (string-match-p "Closed task" text))
       (should (< (string-match "Parked task" text) (string-match "Closed task" text)))
       (should-not (string-match-p "Finished task" text))
       (should-not (string-match-p "Task a" text))
       (should-not (string-match-p "New desk…" text))
       (should (string-match-p "Back to desks" text))
       (should (string-match-p "Archive (1)" text))
       (should-not (string-match-p "Parked and closed (" text)))
     ;; n moves within the page.
     (save-window-excursion
       (switch-to-buffer buffer)
       (vikix-office-next 1)
       (should (equal vikix-office--selected "gone"))
       (vikix-office-next 1)
       (should (equal vikix-office--selected "gone")))
     ;; A from the parked page goes to the Archive; A again back to the desks, not to the parked page.
     (vikix-office-toggle-archive)
     (should (eq vikix-office--page 'archive))
     (should (string-match-p "Parked and closed (2)" (buffer-string)))
     (vikix-office-toggle-archive)
     (should (eq vikix-office--page 'desks))
     (should (equal vikix-office--selected "a"))
     ;; k from the Archive goes to the parked page; k again back to the desks.
     (vikix-office-toggle-archive)
     (vikix-office-toggle-parked)
     (should (eq vikix-office--page 'parked))
     (vikix-office-toggle-parked)
     (should (eq vikix-office--page 'desks))
     ;; The desk pane has the same keys: k there changes the Office's page.
     (with-current-buffer vikix-office--detail
       (setq-local vikix-office--owner buffer)
       (vikix-office-toggle-parked))
     (should (eq vikix-office--page 'parked))
     (vikix-office-toggle-parked)
     ;; An empty first page says where the desks are; an empty parked page says so too.
     (setf (alist-get 'desks vikix-office--data) (list parked closed))
     (vikix-office--render)
     (should (string-match-p "on the Parked and closed page (k)" (buffer-string)))
     (setf (alist-get 'desks vikix-office--data) (list finished))
     (vikix-office-toggle-parked)
     (should (string-match-p "No parked or closed desks" (buffer-string)))
     (vikix-office-toggle-parked)
     (setf (alist-get 'desks vikix-office--data) nil)
     (vikix-office--render)
     (should (string-match-p "No desks yet" (buffer-string))))))

(ert-deftest office-closed-desk-has-a-box-and-can-be-forgotten ()
  (office-test-buffer
   (let ((closed (copy-tree (car (alist-get 'desks vikix-office--data)))))
     (setf (alist-get 'id closed) "gone"
           (alist-get 'title closed) "Closed task"
           (alist-get 'exists closed) :false
           (alist-get 'group closed) "Closed"
           (alist-get 'next_action closed) "Closed by release 1 h ago: nothing to do"
           (alist-get 'desk closed) '((id . "0123456789ab") (project . "Vikix") (worktree . "/tmp/a gone desk"))
           (alist-get 'desks vikix-office--data) (append (alist-get 'desks vikix-office--data) (list closed)))
     (push (cons 'closed '((at . 1791296400) (by . "release"))) (car (last (alist-get 'desks vikix-office--data))))
     (setq vikix-office--detail (generate-new-buffer " *Closed details*"))
     (vikix-office--render)
     ;; The Closed box is on the Parked and closed page, after Parked, with the desk in it.
     (should-not (string-match-p "Closed task" (buffer-string)))
     (vikix-office-toggle-parked)
     (should (string-match-p "Parked" (buffer-string)))
     (should (string-match-p "Closed task" (buffer-string)))
     (should (< (string-match "Parked" (buffer-string)) (string-match "Closed task" (buffer-string))))
     (setq vikix-office--selected "gone")
     (vikix-office--render-detail)
     (with-current-buffer vikix-office--detail
       (should (string-match-p "Desk closed by release" (buffer-string)))
       (should (string-match-p "No action is needed" (buffer-string)))
       ;; The one button is Forget: nothing acts on a desk that is gone.
       (let ((button (next-button (point-min))))
         (should button)
         (should (equal (button-label button) "Forget this record…"))
         (should-not (next-button (button-end button)))))
     ;; Forget takes a closed desk as it takes an archived one; a desk that stands is refused.
     (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
       (vikix-office-forget)   ; no user-error: the question was asked, and declined
       (setq vikix-office--selected "a")
       (should-error (vikix-office-forget) :type 'user-error)))))

(ert-deftest office-purge-needs-confirmation-and-refreshes ()
  (office-test-buffer
   (setf (alist-get 'archive vikix-office--data) '(((id . "old")))
         (alist-get 'archive_token vikix-office--data) "confirmed-version")
   (let (args refreshed)
     (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil))
               ((symbol-function 'vikix-office--request)
                (lambda (a _slot done &optional _input) (setq args a) (funcall done "Purged" nil)))
               ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
       (vikix-office-purge-archive)
       (should-not args)
       (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
         (vikix-office-purge-archive)
         (should (equal args '("office" "--purge-archive" "confirmed-version")))
         (should refreshed)))
     (setf (alist-get 'live_known vikix-office--data) :false)
     (should-error (vikix-office-purge-archive) :type 'user-error))))
(ert-deftest office-forget-needs-an-archived-desk-and-confirmation ()
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Forget details*"))
   (unwind-protect
       (progn
         (vikix-office--render)
         (should-error (vikix-office-forget) :type 'user-error)   ; a current desk is closed, not forgotten
         (let ((archived (copy-tree (car (alist-get 'desks vikix-office--data)))))
           (setf (alist-get 'id archived) "old"
                 (alist-get 'title archived) "Old task"
                 (alist-get 'archived archived) t
                 (alist-get 'exists archived) :false
                 (alist-get 'group archived) "Archived"
                 (alist-get 'desk archived) '((id . "0123456789ab") (project . "Vikix") (worktree . "/tmp/a gone desk"))
                 (alist-get 'archive vikix-office--data) (list archived))
           (vikix-office-toggle-archive)
           (should (equal vikix-office--selected "old"))
           (with-current-buffer vikix-office--detail
             (should (string-match-p "Forget this record" (buffer-string)))
             (should-not (string-match-p "Go to agent\\|Continue\\|Close agent" (buffer-string))))
           (let (args refreshed)
             (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil))
                       ((symbol-function 'vikix-office--request)
                        (lambda (a _slot done &optional _input) (setq args a) (funcall done "forgotten" nil)))
                       ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
               (vikix-office-forget)
               (should-not args)
               (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
                 (vikix-office-forget)
                 (should (equal args '("office" "--forget" "0123456789ab")))
                 (should refreshed))))
           (setf (alist-get 'live_known vikix-office--data) :false)
           (should-error (vikix-office-forget) :type 'user-error)))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-actions-safe-arguments ()
  (office-test-buffer
   (vikix-office--render)
   (let (args)
     (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "Resume codex · saved abc"))
               ((symbol-function 'vikix-office--act) (lambda (a) (setq args a))))
       (vikix-office-continue)
       (should (equal args '("resume" "/tmp/a desk with spaces" "--use" "codex" "--require-saved" "--expect-session" "abc"))))
     (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "Start fresh with aider"))
               ((symbol-function 'vikix-office--act) (lambda (a) (setq args a))))
       (vikix-office-continue)
       (should (equal args '("resume" "/tmp/a desk with spaces" "--use" "aider" "--fresh")))))
   (setf (alist-get 'agents (vikix-office--row)) '(((agent . "codex") (pid . 1) (window . ""))))
   (should-error (vikix-office-go) :type 'user-error)
   (should-error (vikix-office-continue) :type 'user-error)
   (setf (alist-get 'agents (vikix-office--row)) '(((agent . "codex") (pid . 1) (window . "3"))
                                                ((agent . "claude") (pid . 2) (window . "4"))))
   (let (args)
     (cl-letf (((symbol-function 'completing-read) (lambda (_prompt choices &rest _) (car (nth 1 choices))))
               ((symbol-function 'vikix-office--act) (lambda (a) (setq args a))))
       (vikix-office-go)
       (should (equal args '("office" "--go" "2")))))))
(ert-deftest office-delayed-no-overlap-and-cleanup ()
  (office-test-buffer
   (let ((vikix-office-command '("python3" "-c" "import time; time.sleep(2); print('{}')")))
     (vikix-office-refresh)
     (let ((p vikix-office--process))
       (vikix-office-refresh)
       (should (eq p vikix-office--process))
       (setq vikix-office--timer (run-at-time 60 60 #'ignore))
       (vikix-office--cleanup)
       (should-not (process-live-p p))
       (should-not vikix-office--timer)))))
(ert-deftest office-failure-and-timeout-retain-data ()
  (office-test-buffer
   (vikix-office--render)
   (let ((data vikix-office--data)
         (vikix-office-command '("python3" "-c" "import sys; sys.stderr.write('fixture failure'); sys.exit(1)")))
     (vikix-office-refresh) (office-test-wait)
     (should (eq data vikix-office--data))
     (should (string-match-p "Task a" (buffer-string)))
     (should (string-match-p "Live +unknown" (buffer-string)))
     (should (string-match-p "fixture failure" header-line-format)))
   (let ((vikix-office-command '("python3" "-c" "import time; time.sleep(5)"))
         (vikix-office-timeout 0.05))
     (vikix-office-refresh) (office-test-wait)
     (should (string-match-p "timed out" header-line-format)))))
(ert-deftest office-success-and-unknown ()
  (office-test-buffer
   (let ((vikix-office-command
          (list "python3" "-c" (concat "print(" (json-encode (json-encode (office-test-data '("z")))) ")"))))
     (vikix-office-refresh) (office-test-wait)
     (should (equal vikix-office--selected "z")))
   (let ((vikix-office-command '("python3" "-c" "print('{\"version\":1,\"desks\":[],\"errors\":[\"Live unknown\"]}')")))
     (vikix-office-refresh) (office-test-wait)
     (should (equal vikix-office--selected "z"))
     (should (eq (alist-get 'live_known vikix-office--data) :false))
     (should-error (vikix-office-go) :type 'user-error))))

(ert-deftest office-mouse-button-selects-its-desk ()
  (office-test-buffer
   (vikix-office--render)
   ;; The row begins with the box's border; its title, the button, follows.
   (let ((button (next-button (vikix-office--position (copy-sequence "b")))))
     (goto-char (point-min))
     (button-activate button)
     (should (equal vikix-office--selected "b")))))
(ert-deftest office-process-arguments-remain-data ()
  (office-test-buffer
   (let ((vikix-office-command '("python3" "-c" "import json,sys; print(json.dumps(sys.argv[1:]))"))
         output failure)
     (vikix-office--request '("resume" "/tmp/a desk;$(never run)" "--fresh") 'vikix-office--process
                            (lambda (text error) (setq output text failure error)))
     (office-test-wait)
     (should-not failure)
     (should (equal (json-parse-string output :array-type 'list)
                    '("resume" "/tmp/a desk;$(never run)" "--fresh"))))))

(ert-deftest office-testing-group-and-skip ()
  "A desk whose tests run is in the Testing group, between Needs you and
Working, its row saying what runs and since when with Skip tests on it; its
details have a Testing box with the release waited for, the log's tail and
Test log, and Skip tests where Test stood; s skips, and is refused where no
tests run."
  (office-test-buffer
   (let (args)
     (cl-letf (((symbol-function 'vikix-office--act) (lambda (a &optional then) (setq args (cons then a)))))
       (let ((testing (car (alist-get 'desks vikix-office--data))))
         (setf (alist-get 'group testing) "Testing")
         (nconc testing (list (cons 'testing 4242)
                              (cons 'tester '((pid . 4242) (at . 1791300000) (name . "tests/run.sh --changed abc1234")
                                              (log . "/tmp/never/x.log") (tail . ("=== lint (3s)" "all passed: lint"))
                                              (waiting . "wifi-fix"))))))
       (setq vikix-office--detail (generate-new-buffer " *Testing details*"))
       (unwind-protect
           (progn
             (vikix-office--render)
             (let ((text (buffer-string)))
               (should (< (string-match "Needs you" text) (string-match "Testing" text) (string-match "Working" text)))
               ;; The batch buffer is narrow: the line breaks after "the".
               (should (string-match-p "Tests +tests/run.sh --changed abc1234 · since [0-9:]+ · waiting for the" text))
               (should (string-match-p "release of wifi-fix" text))
               (should (string-match-p "Skip tests" text))
               ;; The row is in the Testing box, not Needs you's.
               (should (< (string-match "Testing" text) (string-match "Task a" text) (string-match "Working" text))))
             (setq vikix-office--selected "a")
             (vikix-office--render-detail)
             (with-current-buffer vikix-office--detail
               (let ((text (buffer-string))
                     (labels (let (labels) (save-excursion (goto-char (point-min))
                                                           (while (forward-button 1 nil nil t) (push (button-label (button-at (point))) labels)))
                               labels)))
                 (should (member "Skip tests" labels))
                 (should (member "Test log" labels))
                 (should-not (member "Test" labels))
                 (should (string-match-p "Waiting for the release of wifi-fix to finish its tests first" text))
                 (should (string-match-p "all passed: lint" text))))
             (vikix-office-skip-tests)
             (should (equal args '(vikix-office-refresh "office" "--skip" "a")))
             ;; The log that isn't there yet is said so; a desk with no tests running refuses both.
             (should-error (vikix-office-test-log) :type 'user-error)
             (setq vikix-office--selected "b")
             (should-error (vikix-office-skip-tests) :type 'user-error)
             (should-error (vikix-office-test-log) :type 'user-error)
             ;; A skipped check in the details says so.
             (let ((b (cadr (alist-get 'desks vikix-office--data))))
               (setf (alist-get 'checks b) '(((name . "tests/run.sh --changed abc1234") (ok . t) (skipped . t) (by . "user")
                                              (at . 1791300000) (commit . "abc1234") (dirty . 0) (freshness . "fresh")))))
             (vikix-office--render-detail)
             (with-current-buffer vikix-office--detail
               (should (string-match-p "skipped +tests/run.sh --changed abc1234" (buffer-string)))))
         (kill-buffer vikix-office--detail))))))

(ert-deftest office-worker-actions-and-marks ()
  (office-test-buffer
   (let (args)
     (cl-letf (((symbol-function 'vikix-office--act) (lambda (a &optional then) (setq args (cons then a))))
               ((symbol-function 'read-string) (lambda (&rest _) "  look at chapter two  ")))
       (vikix-office--render)
       ;; Each refreshes after its answer, so the row and the button say what stands now.
       (vikix-office-pause)
       (should (equal args '(vikix-office-refresh "office" "--pause" "a")))
       (vikix-office-test)
       (should (equal args '(vikix-office-refresh "office" "--test" "a")))
       (vikix-office-tell)
       (should (equal args '(vikix-office-refresh "office" "--tell" "a" "look at chapter two")))
       ;; Review by…: the reviewers the snapshot offers; one alone is taken without asking.
       (should-error (vikix-office-review) :type 'user-error)
       (nconc vikix-office--data (list (cons 'reviewers '("codex" "claude"))))
       (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "codex")))
         (vikix-office-review))
       (should (equal args '(vikix-office-refresh "office" "--review" "a" "codex")))
       (setf (alist-get 'reviewers vikix-office--data) '("claude"))
       (vikix-office-review)
       (should (equal args '(vikix-office-refresh "office" "--review" "a" "claude")))
       (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "   ")))
         (should-error (vikix-office-tell) :type 'user-error))
       ;; A paused desk with notes waiting and a tester at work says so in its row, and offers Go.
       (nconc (vikix-office--row)            ; keys the fixture lacks, added to the row in place
              (list (cons 'paused '((at . 1791300000) (by . "user") (hard . :false)))
                    (cons 'notes 2) (cons 'testing 4242)
                    (cons 'reviewing '((pid . 4243) (at . 1791300000) (provider . "codex") (worktree . "/tmp/r")))
                    (cons 'left '((reason . "dismissed") (by . "user") (at . 1791300000) (dirty . 3)))))
       (vikix-office--render)
       (dolist (words '("paused by user" "testing" "under review by codex" "2 notes waiting"))
         (should (string-match-p words (buffer-string))))
       (setq vikix-office--detail (generate-new-buffer " *Office test detail*"))
       (unwind-protect
           (progn
             (vikix-office--render-detail)
             (with-current-buffer vikix-office--detail
               (should (string-match-p "Last agent left: dismissed" (buffer-string)))
               (should (string-match-p "3 uncommitted then" (buffer-string)))
               (should (string-match-p "Notes waiting for its agent: 2" (buffer-string)))
               (should (cl-find "Go" (let (labels) (save-excursion (goto-char (point-min))
                                                                   (while (forward-button 1 nil nil t) (push (button-label (button-at (point))) labels)))
                                       labels) :test #'equal))))
         (kill-buffer vikix-office--detail))
       ;; The archive offers none of them.
       (nconc (vikix-office--row) (list (cons 'archived t)))
       (should-error (vikix-office-pause) :type 'user-error)))))

(ert-deftest office-action-answer-outlives-the-refresh ()
  ;; A button's answer (Go, Pause, Test, Tell) stays in the header line over the
  ;; refreshes that follow, so it is seen; g drops it; the next action replaces it.
  (office-test-buffer
   (let (refreshed)
     (cl-letf (((symbol-function 'vikix-office--request)
                (lambda (_args _slot done) (funcall done "~/src/book-a: let go, paused 3 min; claude 1001 goes on\n" nil))))
       (vikix-office--act '("office" "--pause" "a") (lambda () (setq refreshed t)))
       (should refreshed)
       (should (equal vikix-office--said "~/src/book-a: let go, paused 3 min; claude 1001 goes on"))
       (should (string-match-p "let go, paused 3 min" header-line-format)))
     (vikix-office--status "Updated 12:00 · g refresh")
     (should (string-match-p "let go, paused 3 min; claude 1001 goes on · Updated 12:00" header-line-format))
     (cl-letf (((symbol-function 'vikix-office--request)
                (lambda (_args _slot done) (funcall done "" "Backend failed: no"))))
       (vikix-office--act '("office" "--test" "a") (lambda () (setq refreshed 'again)))
       (should-not (eq refreshed 'again))
       (should-not vikix-office--said)
       (should (string-match-p "Backend failed: no" header-line-format)))
     (setq vikix-office--said "kept")
     (cl-letf (((symbol-function 'called-interactively-p) (lambda (&rest _) t))
               ((symbol-function 'vikix-office--request) (lambda (&rest _) nil)))
       (vikix-office-refresh)
       (should-not vikix-office--said)))))

(defun office-test-offer ()
  '((projects . (((name . "vikix") (path . "/home/x/src/vikix") (short . "~/src/vikix") (repo . t) (next . "n"))
                 ((name . "notes") (path . "/home/x/notes") (short . "~/notes") (repo . :false) (next . ""))))
    (agents . (((name . "claude") (yours . t) (installed . t) (about . "Anthropic") (local . :false))
               ((name . "codex") (yours . :false) (installed . t) (about . "OpenAI") (local . t))))
    (default . "claude") (display . t)))
(defun office-test-form-set (name value)
  (widget-value-set (alist-get name (plist-get vikix-office--form :widgets)) value)
  (widget-setup))
(defun office-test-task-set (i name value)
  "The New plan form's task I's field NAME set to VALUE."
  (widget-value-set (alist-get name (nth i (plist-get vikix-office--form :tasks))) value)
  (widget-setup))
(defun office-test-pick-template (name)
  "The New plan form's template picked, as a click does: the choice's notify, which draws the form again."
  (let ((w (alist-get 'template (plist-get vikix-office--form :widgets))))
    (widget-value-set w name)
    (widget-setup)
    (widget-apply w :notify w nil)))
(defun office-test-press (label)
  "The first button LABEL in this buffer pressed."
  (goto-char (point-min))
  (search-forward label)
  (let ((w (widget-at (- (point) 2))))
    (should w)
    (widget-apply w :notify w nil)))
(ert-deftest office-forms-new-desk-and-worker ()
  "The two forms: what each offers, the words each hands the backend, what
each refuses, and the way out; the buttons and keys that open them."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office form detail*"))
   (unwind-protect
       (save-window-excursion
         (switch-to-buffer buffer)
         (delete-other-windows)
         (set-window-buffer (split-window-right) vikix-office--detail)
         (vikix-office--render)
         (should (string-match-p "New desk…" (buffer-string)))
         (with-current-buffer vikix-office--detail (should (string-match-p "Worker…" (buffer-string))))
         ;; The new desk's form, in the desk pane's window: a project to pick, a topic for a repository.
         (let* ((owner buffer) (window (get-buffer-window vikix-office--detail))
                (form (vikix-office--form-draw owner nil (office-test-offer))))
           (should (eq (current-buffer) form))   ; the form is selected as it opens
           (set-buffer buffer)
           (should (eq (window-buffer window) form))
           (with-current-buffer form
             ;; The fixture's desk is of "Vikix", not a project of the offer: to pick, as a button.
             (should (string-match-p "Project: \\[pick one\\]" (buffer-string)))
             (should (string-match-p "Agent: \\[yours (claude)\\]" (buffer-string)))
             (should (string-match-p "codex can" (buffer-string)))
             (should-error (vikix-office--form-args) :type 'user-error)
             ;; What stands in the way is said in the form's own header line.
             (should (string-match-p "Pick the project" header-line-format))
             (office-test-form-set 'project "vikix")
             (should-error (vikix-office--form-args) :type 'user-error)
             (office-test-form-set 'topic " wifi fix ")
             (should (equal (vikix-office--form-args) '("office" "--desk" "vikix" "wifi fix")))
             (office-test-form-set 'task "fix the wifi")
             (office-test-form-set 'agent "codex")
             (office-test-form-set 'local t)
             (office-test-form-set 'push t)
             (office-test-form-set 'notests t)
             (should (equal (vikix-office--form-args)
                            '("office" "--desk" "vikix" "wifi fix" "--task" "fix the wifi" "--use" "codex" "--local" "--push" "--no-tests")))
             ;; A project that is no repository needs no topic.
             (office-test-form-set 'project "notes")
             (office-test-form-set 'topic "")
             (should (equal (nth 3 (vikix-office--form-args)) "--task"))
             ;; Cancel: the desk pane back in its window, the form gone.
             (vikix-office-form-cancel))
           (set-buffer buffer)
           (should-not (buffer-live-p form))
           (should (eq (window-buffer window) vikix-office--detail)))
         ;; A desk of a project the offer has selected: the project is still to pick, never guessed.
         (setf (alist-get 'project (alist-get 'desk (vikix-office--row))) "vikix")
         (let ((form (vikix-office--form-draw buffer nil (office-test-offer))))
           (set-buffer buffer)
           (with-current-buffer form
             (should (string-match-p "Project: \\[pick one\\]" (buffer-string)))
             (should (equal (vikix-office--form-value 'project) ""))
             (vikix-office-form-cancel))
           (set-buffer buffer))
         ;; The worker's form for the desk picked: its folder, the task and the boxes.
         (let ((form (vikix-office--form-draw buffer (vikix-office--row) (office-test-offer))))
           (set-buffer buffer)
           (with-current-buffer form
             (should (string-match-p "Worker at Task a" (buffer-string)))
             (should-not (string-match-p "Project:" (buffer-string)))
             (should (equal (vikix-office--form-args) '("office" "--worker" "/tmp/a desk with spaces")))
             (office-test-form-set 'task " sort them ")
             (office-test-form-set 'notests t)
             (should (equal (vikix-office--form-args) '("office" "--worker" "/tmp/a desk with spaces" "sort them" "--no-tests")))
             ;; Submitted: the backend's words as they are; on its error the form stays, on its answer it goes and the Office refreshes.
             (let (args refreshed)
               (cl-letf (((symbol-function 'vikix-office--request)
                          (lambda (a _slot done &optional _input) (setq args a) (funcall done "" "Backend failed: vikix agents: no")))
                         ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
                 (vikix-office-form-submit)
                 (should (equal args '("office" "--worker" "/tmp/a desk with spaces" "sort them" "--no-tests")))
                 (should-not refreshed)
                 (should (buffer-live-p form))
                 (should (string-match-p "no" (buffer-local-value 'header-line-format buffer)))
                 (should (string-match-p "vikix agents: no" (buffer-local-value 'header-line-format form))))
               (cl-letf (((symbol-function 'vikix-office--request)
                          (lambda (a _slot done &optional _input) (funcall done "a worker at ~/src/vikix-a, on workspace 3\n" nil)))
                         ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
                 (vikix-office-form-submit)
                 (should refreshed)
                 (should-not (buffer-live-p form))
                 (should (string-match-p "on workspace 3" (buffer-local-value 'header-line-format buffer))))))
           (set-buffer buffer))
         ;; The commands that open them ask the backend what to offer; a desk with an agent takes no worker.
         (let (args)
           (cl-letf (((symbol-function 'vikix-office--request) (lambda (a _slot _done &optional _input) (setq args a))))
             (vikix-office-new-desk)
             (should (equal args '("office" "--form")))
             (setq args nil)
             (vikix-office-worker)
             (should (equal args '("office" "--form")))
             (setf (alist-get 'agents (vikix-office--row)) '(((agent . "codex") (pid . 1) (window . "3"))))
             (should-error (vikix-office-worker) :type 'user-error)
             (setf (alist-get 'live_known vikix-office--data) :false)
             (should-error (vikix-office-new-desk) :type 'user-error)))
         ;; A desk whose tests are off says so in its row and its details.
         (setf (alist-get 'live_known vikix-office--data) t)
         (nconc (vikix-office--row) (list (cons 'tests_off t)))
         (vikix-office--render)
         (should (string-match-p "Handoff +review · tests off" (buffer-string)))
         (with-current-buffer vikix-office--detail
           (should (string-match-p "not run by themselves" (buffer-string))))
         ;; Closing the Office takes its forms with it.
         (let ((form (vikix-office--form-draw buffer nil (office-test-offer))))
           (set-buffer buffer)
           (vikix-office--cleanup)
           (should-not (buffer-live-p form))))
     (dolist (b (buffer-list))
       (when (string-match-p "\\`\\*Office \\(worker\\|new desk\\)\\*" (buffer-name b)) (kill-buffer b)))
     (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail)))))
(ert-deftest office-project-form ()
  "The New project form: what it shows of the offer, the words it hands the
backend for each Where, what it refuses, the longer wait for a push, and
the button and key that open it."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office form detail*"))
   (unwind-protect
       (save-window-excursion
         (switch-to-buffer buffer)
         (delete-other-windows)
         (set-window-buffer (split-window-right) vikix-office--detail)
         (vikix-office--render)
         (should (string-match-p "New project…" (buffer-string)))
         (should (eq (lookup-key vikix-office-mode-map (kbd "R")) #'vikix-office-new-project))
         (let* ((window (get-buffer-window vikix-office--detail))
                (offer (append (office-test-offer) '((root . "/home/x/src") (logs . "/home/x/src/project-logs") (gh . t) (github . "tester"))))
                (form (vikix-office--form-draw buffer 'project offer)))
           (should (eq (current-buffer) form))
           (set-buffer buffer)
           (should (eq (window-buffer window) form))
           (with-current-buffer form
             (should (string-match-p "Where: +\\[pick one\\]" (buffer-string)))
             (should (string-match-p "signed in as tester (gh), so the repository is github.com/tester/NAME" (buffer-string)))
             (should (string-match-p "/home/x/src/project-logs/NAME" (buffer-string)))
             ;; The name first, then where it goes: nothing is guessed.
             (should-error (vikix-office--form-args) :type 'user-error)
             (should (string-match-p "name is a word" header-line-format))
             (office-test-form-set 'name " my-book ")
             (should-error (vikix-office--form-args) :type 'user-error)
             (should (string-match-p "Pick where" header-line-format))
             (office-test-form-set 'where "public")
             (should (equal (vikix-office--form-args) '("office" "--project" "my-book" "--where" "public")))
             (office-test-form-set 'title " A Book ")
             (office-test-form-set 'description "A book.")
             (office-test-form-set 'next "an outline")
             (office-test-form-set 'log-apart t)
             (should (equal (vikix-office--form-args)
                            '("office" "--project" "my-book" "--where" "public" "--title" "A Book" "--next" "an outline"
                              "--description" "A book." "--log-apart")))
             ;; A folder alone has no README for a description and no repository for a log apart.
             (office-test-form-set 'where "folder")
             (should-error (vikix-office--form-args) :type 'user-error)
             (should (string-match-p "description goes into a README" header-line-format))
             (office-test-form-set 'description "")
             (should-error (vikix-office--form-args) :type 'user-error)
             (should (string-match-p "log kept apart is for a repository" header-line-format))
             (office-test-form-set 'log-apart nil)
             (should (equal (vikix-office--form-args) '("office" "--project" "my-book" "--where" "folder" "--title" "A Book" "--next" "an outline")))
             (office-test-form-set 'where "local")
             (should (equal (nth 4 (vikix-office--form-args)) "local"))
             ;; Submitted: the words as they are, the wait long enough for a push; the answer's last line in the Office's header.
             (office-test-form-set 'where "private")
             (let (args refreshed waited)
               (cl-letf (((symbol-function 'vikix-office--request)
                          (lambda (a _slot done &optional _input) (setq args a waited vikix-office-timeout)
                            (funcall done "made /home/x/src/my-book/log.md\non GitHub, private: https://github.com/tester/my-book (pushed; origin is set)\n" nil)))
                         ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
                 (vikix-office-form-submit)
                 (should (equal (seq-take args 5) '("office" "--project" "my-book" "--where" "private")))
                 (should (>= waited 150))
                 (should refreshed)
                 (should-not (buffer-live-p form))
                 (should (string-match-p "pushed; origin is set" (buffer-local-value 'header-line-format buffer)))))
             (set-buffer buffer)
             (should (eq (window-buffer window) vikix-office--detail)))
         ;; Without a GitHub account the two GitHub choices are refused, with why; a repository here is not.
         (let ((form (vikix-office--form-draw buffer 'project (append (office-test-offer) '((root . "/home/x/src") (gh . t) (github . nil))))))
           (set-buffer buffer)
           (with-current-buffer form
             (should (string-match-p "gh isn't signed in" (buffer-string)))
             (office-test-form-set 'name "my-book")
             (office-test-form-set 'where "public")
             (should-error (vikix-office--form-args) :type 'user-error)
             (should (string-match-p "gh auth login" header-line-format))
             (office-test-form-set 'where "local")
             (should (equal (vikix-office--form-args) '("office" "--project" "my-book" "--where" "local")))
             (vikix-office-form-cancel))
           (set-buffer buffer)
           (should-not (buffer-live-p form)))
         ;; The command asks the backend what to offer.
         (let (args)
           (cl-letf (((symbol-function 'vikix-office--request) (lambda (a _slot _done &optional _input) (setq args a))))
             (vikix-office-new-project)
             (should (equal args '("office" "--form")))))))
     (dolist (b (buffer-list))
       (when (string-match-p "\\`\\*Office new project\\*" (buffer-name b)) (kill-buffer b)))
     (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail)))))
(ert-deftest office-plan-form-box-acts-and-guide ()
  "The New plan form: what it offers (templates, repositories only), the
template's tasks as its fields once one is picked, the words it hands the
backend (the tasks as JSON on its stdin), what it refuses, Add a task and
Remove; a plan written opens its file in the desk pane. The Plans box: a draft's Run and Edit, a running plan's
Pause and Stop, each through vikix agents plan with the file the snapshot
names. The Guide: the manual's node in the desk pane, or why not."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office plan detail*"))
   (let ((tmp (make-temp-file "office-plan" t)) (acts nil))
     (unwind-protect
         (save-window-excursion
           (switch-to-buffer buffer)
           (delete-other-windows)
           (set-window-buffer (split-window-right) vikix-office--detail)
           (vikix-office--render)
           (should (string-match-p "New plan…" (buffer-string)))
           (should (string-match-p "Guide" (buffer-string)))
           ;; The form: templates and the repositories alone; a choice that makes something starts unpicked.
           (let* ((window (get-buffer-window vikix-office--detail))
                  (offer (append '((templates . (((name . "build-chain") (file . "/x/build-chain.toml") (about . "one desk, in turn") (yours . :false)
                                                  (at_once . 1) (gate . "me")
                                                  (tasks . (((name . "build") (text . "EDIT: what to build") (desk . "topic") (after . nil) (agent . "")
                                                             (local . :false) (push . :false) (no_tests . :false) (release . "") (mode . "") (acceptance . nil))
                                                            ((name . "tests") (text . "EDIT: the tests") (desk . "topic") (after . ("build")) (agent . "codex")
                                                             (local . t) (push . :false) (no_tests . :false) (release . "EDIT: the line") (mode . "")
                                                             (acceptance . ("a" "b"))))))
                                                 ((name . "mine") (file . "/y/mine.toml") (about . "my way") (yours . t) (at_once . 2) (gate . "none")
                                                  (tasks . (((name . "it") (text . "EDIT: mine") (desk . "topic") (after . nil) (agent . "")
                                                             (local . :false) (push . :false) (no_tests . :false) (release . "Mine") (mode . "supervised")
                                                             (acceptance . nil)))))))
                                   (plans_folder . "/home/x/.config/vikix/plans")
                                   (modes . ("supervised" "autonomous" "unrestricted")))
                                 (office-test-offer)))
                  (form (vikix-office--form-draw buffer 'plan offer)))
             (should (eq (current-buffer) form))
             (set-buffer buffer)
             (should (eq (window-buffer window) form))
             (with-current-buffer form
               (should (string-match-p "Template: \\[pick one\\]" (buffer-string)))
               (should (string-match-p "Project:  \\[pick one\\]" (buffer-string)))
               (should (string-match-p "NAME.toml; \"topic\" in a" (buffer-string)))
               (should-not (string-match-p "Task 1" (buffer-string)))
               (should-error (vikix-office--form-args) :type 'user-error)
               (should (string-match-p "Pick the template" header-line-format))
               ;; A template picked: the form drawn again with its tasks as fields, each
               ;; EDIT: line of the template a hint under an empty field, the rest filled.
               (office-test-pick-template "build-chain")
               (should (string-match-p "Task 1 [─-]+[┐+]\n  Name:  build .*Desk: topic .*After: " (buffer-string)))
               (should (string-match-p "Task 2 [─-]+[┐+]\n  Name:  tests .*After: build" (buffer-string)))
               ;; Each task is a box of its own: a top edge with its title, a rule
               ;; between its parts (who and where, the words, the release, the
               ;; acceptance, the agent), the bottom edge, the left side on every
               ;; line of it as an overlay's line-prefix, and the right side on
               ;; every line's end as an overlay's before-string, put again as the
               ;; fields' lines come and go; the text itself has no side.
               (let ((edges (lambda (re) (let ((n 0)) (goto-char (point-min))
                                             (while (re-search-forward re nil t) (setq n (1+ n))) n)))
                     (rights (lambda () (cl-count-if (lambda (o) (overlay-get o 'vikix-office-right))
                                                     (overlays-in (point-min) (point-max)))))
                     (lines (lambda () (let ((n 0))
                                         (dolist (o (overlays-in (point-min) (point-max)) n)
                                           (when (overlay-get o 'vikix-office-side)
                                             (setq n (+ n (count-lines (overlay-start o) (overlay-end o))))))))))
                 (should (equal (funcall edges "^[┌+][─-] Task [0-9]+ [─-]+[┐+]$") 2))
                 (should (equal (funcall edges "^[┌+][─-] Plan [─-]+[┐+]$") 1))
                 (should (equal (funcall edges "^[├+][─-]+[┤+]$") 11))
                 (should (equal (funcall edges "^[└+][─-]+[┘+]$") 3))
                 (should-not (string-match-p "^[│|]" (buffer-string)))
                 (goto-char (point-min)) (search-forward "Task 1 ")
                 (should-not (get-char-property (point) 'line-prefix))
                 (should (equal (get-char-property (widget-field-start (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))) 'line-prefix)
                                (get-char-property (widget-field-start (alist-get 'name (nth 1 (plist-get vikix-office--form :tasks)))) 'line-prefix)))
                 (should (member (get-char-property (widget-field-start (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))) 'line-prefix)
                                 '("│" "|")))
                 (goto-char (point-min)) (search-forward "Add a task")
                 (should-not (get-char-property (point) 'line-prefix))
                 (should (> (funcall rights) 20))
                 (should (equal (funcall rights) (funcall lines)))
                 (let ((before (funcall rights)))
                   (office-test-task-set 0 'task "one\ntwo\nthree")
                   (vikix-office--live-sides)
                   (should (equal (funcall rights) (+ before 2)))
                   (should (equal (funcall rights) (funcall lines)))
                   (goto-char (widget-field-end (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))))
                   (let ((o (cl-find-if (lambda (o) (overlay-get o 'vikix-office-right)) (overlays-at (point)))))
                     (should o)
                     (should (string-suffix-p (get-char-property (widget-field-start (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))) 'line-prefix)
                                              (substring-no-properties (overlay-get o 'before-string)))))
                   (office-test-task-set 0 'task "")))
               (should (string-match-p "what to build\n.*left empty, that line stays" (buffer-string)))
               (should (string-match-p "\\[codex\\]   \\[X\\] local model" (buffer-string)))
               (should (equal (length (plist-get vikix-office--form :tasks)) 2))
               (should (equal (widget-value (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))) ""))
               (should (equal (widget-value (alist-get 'acceptance (nth 1 (plist-get vikix-office--form :tasks)))) "a\nb"))
               ;; Another picked: its tasks instead, the rest of the form kept.
               (office-test-form-set 'name "kept")
               (office-test-pick-template "mine")
               (should (equal (length (plist-get vikix-office--form :tasks)) 1))
               (should (equal (vikix-office--form-value 'name) "kept"))
               (should (string-match-p "Mode: \\[supervised\\]" (buffer-string)))
               (office-test-form-set 'name "")
               (should-error (vikix-office--form-args) :type 'user-error)
               (should (string-match-p "Pick the project" header-line-format))
               ;; notes is no repository: not offered, so it can't be picked.
               (should-not (cl-find "notes" (widget-get (alist-get 'project (plist-get vikix-office--form :widgets)) :args)
                                    :key (lambda (w) (widget-get w :value)) :test #'equal))
               (office-test-form-set 'project "vikix")
               (should-error (vikix-office--form-args) :type 'user-error)
               (should (string-match-p "name is a word" header-line-format))
               (office-test-form-set 'name "Bad Name")
               (should-error (vikix-office--form-args) :type 'user-error)
               (office-test-form-set 'name " chapters ")
               (should (equal (vikix-office--form-args) '("office" "--plan" "mine" "chapters" "vikix" "--tasks")))
               (office-test-form-set 'at-once "two")
               (should-error (vikix-office--form-args) :type 'user-error)
               (office-test-form-set 'at-once " 2 ")
               (office-test-form-set 'gate "me")
               (should (equal (vikix-office--form-args) '("office" "--plan" "mine" "chapters" "vikix" "--at-once" "2" "--gate" "me" "--tasks")))
               ;; The tasks for the backend's stdin: words left empty keep the template's EDIT: line;
               ;; a name that isn't a word, or no words where the template gave no line, is refused.
               (should (equal (vikix-office--form-plan-input)
                              "[{\"name\":\"it\",\"desk\":\"topic\",\"task\":\"EDIT: mine\",\"release\":\"Mine\",\"mode\":\"supervised\"}]"))
               (office-test-task-set 0 'task " Do it.\nMy way. ")
               (office-test-task-set 0 'after "a, b")
               (office-test-task-set 0 'acceptance "one\n\n two ")
               (widget-value-set (alist-get 'push (nth 0 (plist-get vikix-office--form :tasks))) t)
               (should (equal (vikix-office--form-plan-input)
                              "[{\"name\":\"it\",\"desk\":\"topic\",\"after\":[\"a\",\"b\"],\"task\":\"Do it.\\nMy way.\",\"release\":\"Mine\",\"acceptance\":[\"one\",\"two\"],\"push\":true,\"mode\":\"supervised\"}]"))
               (office-test-task-set 0 'name "Bad Name")
               (should-error (vikix-office--form-plan-input) :type 'user-error)
               (should (string-match-p "Task 1's name is a word" header-line-format))
               (office-test-task-set 0 'name "it")
               ;; Add a task: an empty one after the rest, point at its name; Remove takes one out; the words typed stay.
               (office-test-press "Add a task")
               (should (equal (length (plist-get vikix-office--form :tasks)) 2))
               (should (string-match-p "Task 2 [─-]+[┐+]\n  Name:  " (buffer-string)))
               (should (equal (widget-value (alist-get 'task (nth 0 (plist-get vikix-office--form :tasks)))) " Do it.\nMy way. "))
               (should (eq (widget-at (point)) (alist-get 'name (nth 1 (plist-get vikix-office--form :tasks)))))
               (should-error (vikix-office--form-plan-input) :type 'user-error)
               (should (string-match-p "Task 2's name" header-line-format))
               (office-test-task-set 1 'name "more")
               (should (string-match-p "\"name\":\"more\",\"task\":\"EDIT: the worker's job" (vikix-office--form-plan-input)))
               (office-test-press "Remove this task")
               (should (equal (length (plist-get vikix-office--form :tasks)) 1))
               (should (equal (widget-value (alist-get 'name (nth 0 (plist-get vikix-office--form :tasks)))) "more"))
               (office-test-press "Add a task")
               (goto-char (point-min)) (search-forward "Remove this task" nil nil 2)
               (widget-apply (widget-at (- (point) 2)) :notify (widget-at (- (point) 2)) nil)
               (should (equal (widget-value (alist-get 'name (nth 0 (plist-get vikix-office--form :tasks)))) "more"))
               (office-test-task-set 0 'task "Do it.")
               ;; Submitted: the backend gets the words and answers with the file alone; the
               ;; form goes, the file opens in the pane, the Office refreshes and says Run is there.
               (let ((file (expand-file-name "chapters.toml" tmp)) args input refreshed)
                 (with-temp-file file (insert "project = \"vikix\"\n"))
                 (cl-letf (((symbol-function 'vikix-office--request)
                            (lambda (a _slot done &optional in) (setq args a input in) (funcall done (concat file "\n") nil)))
                           ((symbol-function 'vikix-office-refresh) (lambda () (setq refreshed t))))
                   (vikix-office-form-submit)
                   (should (equal args '("office" "--plan" "mine" "chapters" "vikix" "--at-once" "2" "--gate" "me" "--tasks")))
                   (should (equal input "[{\"name\":\"more\",\"task\":\"Do it.\"}]"))
                   (should refreshed)
                   (should-not (buffer-live-p form))
                   (should (equal (buffer-file-name (window-buffer window)) file))
                   (should (string-match-p "Plan written: .*chapters.toml. Run is in the Plans box" (buffer-local-value 'header-line-format buffer)))
                   (kill-buffer (window-buffer window)))))
             (set-buffer buffer)
             ;; An error keeps the form, as the desk forms do; words left to the template
             ;; are said so when the plan is written.
             (let ((form (vikix-office--form-draw buffer 'plan offer)))
               (set-buffer buffer)
               (with-current-buffer form
                 (office-test-pick-template "build-chain") (office-test-form-set 'project "vikix") (office-test-form-set 'name "x")
                 (cl-letf (((symbol-function 'vikix-office--request)
                            (lambda (_a _slot done &optional _input) (funcall done "" "Backend failed: x is there already"))))
                   (vikix-office-form-submit)
                   (should (buffer-live-p form))
                   (should (string-match-p "is there already" header-line-format)))
                 (let ((file (expand-file-name "x.toml" tmp)))
                   (with-temp-file file (insert "project = \"vikix\"\n"))
                   (cl-letf (((symbol-function 'vikix-office--request)
                              (lambda (_a _slot done &optional input)
                                (should (string-match-p "\"task\":\"EDIT: what to build\"" input))
                                (funcall done (concat file "\n") nil)))
                             ((symbol-function 'vikix-office-refresh) #'ignore))
                     (vikix-office-form-submit)
                     (should (string-match-p "Write its EDIT: lines" (buffer-local-value 'header-line-format buffer)))
                     (kill-buffer (window-buffer window)))))
               (set-buffer buffer))
             (let ((form (vikix-office--form-draw buffer 'plan offer)))
               (set-buffer buffer)
               (with-current-buffer form
                 (vikix-office-form-cancel))
               (set-buffer buffer)
               (should (eq (window-buffer window) vikix-office--detail)))
             ;; The command asks the backend what to offer, as the desk forms do.
             (let (args)
               (cl-letf (((symbol-function 'vikix-office--request) (lambda (a _slot _done &optional _input) (setq args a))))
                 (vikix-office-new-plan)
                 (should (equal args '("office" "--form"))))))
           ;; The Plans box: a draft with EDIT: lines has Edit and what it needs, no Run; one
           ;; written has Run; a running plan Pause, Stop and Log; a paused one Go on.
           (setf (alist-get 'plans vikix-office--data)
                 '(((id . "a") (name . "chapters") (file . "/home/x/.config/vikix/plans/chapters.toml") (project . "vikix")
                    (state . "draft") (pid . 0) (draft . t) (edit . ("build" "tests")) (gate . "me") (at_once . 1)
                    (desks . (((topic . "chapters") (folder . "/home/x/src/vikix-chapters") (line . "") (released . :false) (tasks . nil))))
                    (needs . ("still the template's words (EDIT: lines) at build, tests: write them first")) (error . ""))
                   ((id . "b") (name . "cover") (file . "/home/x/.config/vikix/plans/cover.toml") (project . "vikix")
                    (state . "draft") (pid . 0) (draft . t) (edit . nil) (gate . "none") (at_once . 2) (desks . nil) (needs . nil) (error . ""))
                   ((id . "c") (name . "book") (file . "/home/x/book.toml") (project . "book") (state . "running") (pid . 42)
                    (draft . :false) (edit . nil) (gate . "me") (at_once . 2) (desks . nil) (needs . nil) (error . ""))
                   ((id . "d") (name . "rest") (file . "/home/x/rest.toml") (project . "book") (state . "paused") (pid . 43)
                    (draft . :false) (edit . nil) (desks . nil) (needs . nil) (error . ""))))
           (vikix-office--render)
           (let ((text (buffer-string)))
             (should (string-match-p "chapters · vikix · draft" text))
             (should (string-match-p "Needs you +still the template's words" text))
             (should (string-match-p "cover · vikix · draft · 2 at once" text)))
           ;; The buttons of the box, in order: chapters' Edit alone, cover's Run and
           ;; Edit, book's Pause, Stop, Edit and Log, rest's Go on, Stop, Edit and Log.
           (let ((from (save-excursion (goto-char (point-min)) (search-forward "chapters · vikix")))
                 (to (save-excursion (goto-char (point-min)) (search-forward "Needs you" nil t 2)))
                 found)
             (save-excursion
               (goto-char from)
               (while (and (forward-button 1 nil nil t) (< (point) to))
                 (push (button-label (button-at (point))) found)))
             (should (equal (nreverse found)
                            '("Edit" "Run" "Edit" "Pause" "Stop" "Edit" "Log" "Go on" "Stop" "Edit" "Log"))))
           ;; The acts: the verb and the file the snapshot names, refreshed after; a file of anyone's is refused.
           (cl-letf (((symbol-function 'vikix-office--act) (lambda (args &optional _then) (push args acts))))
             (vikix-office-plan-act "run" "/home/x/.config/vikix/plans/cover.toml")
             (vikix-office-plan-act "pause" "/home/x/book.toml")
             (should (equal acts '(("plan" "pause" "/home/x/book.toml") ("plan" "run" "/home/x/.config/vikix/plans/cover.toml"))))
             (should-error (vikix-office-plan-act "run" "/etc/passwd") :type 'user-error)
             (should-error (vikix-office-plan-act "delete" "/home/x/book.toml") :type 'user-error)
             (should-error (vikix-office-show-file "/etc/passwd") :type 'user-error))
           ;; Edit: the plan's file in the desk pane's window.
           (let ((file (expand-file-name "cover.toml" tmp)))
             (with-temp-file file (insert "project = \"vikix\"\n"))
             (setf (alist-get 'file (nth 1 (alist-get 'plans vikix-office--data))) file)
             (vikix-office-show-file file)
             (should (equal (buffer-file-name (window-buffer (selected-window))) file))
             (kill-buffer (current-buffer)))
           ;; The guide: the manual's node in the pane, from the data folder; not installed, said.
           (let ((data (expand-file-name "data" tmp)) opened)
             (require 'info)   ; before the stand-in: loaded later, it would put the real one back
             (make-directory (expand-file-name "info" data) t)
             (with-environment-variables (("XDG_DATA_HOME" data))
               (should-error (vikix-office-guide) :type 'user-error)
               (with-temp-file (expand-file-name "info/vikix.info" data) (insert "x"))
               (cl-letf (((symbol-function 'info) (lambda (node &optional _b) (setq opened node))))
                 (vikix-office-guide)
                 (should (equal opened (format "(%s) The Office" (expand-file-name "info/vikix.info" data))))
                 (vikix-office-guide "A plan")
                 (should (string-suffix-p ") A plan" opened)))))
           ;; The keys.
           (should (eq (lookup-key vikix-office-mode-map (kbd "L")) #'vikix-office-new-plan))
           (should (eq (lookup-key vikix-office-mode-map (kbd "h")) #'vikix-office-guide)))
       (dolist (b (buffer-list))
         (when (string-match-p "\\`\\*Office \\(new plan\\|plan log\\)\\*" (buffer-name b)) (kill-buffer b)))
       (when (buffer-live-p vikix-office--detail) (kill-buffer vikix-office--detail))
       (delete-directory tmp t)))))
(defun office-test-buttons ()
  "The labels of the buttons in this buffer, in order."
  (let (labels)
    (save-excursion
      (goto-char (point-min))
      (while (forward-button 1 nil nil t) (push (button-label (button-at (point))) labels)))
    (nreverse labels)))
(ert-deftest office-rows-are-desks-with-their-workers ()
  "A row is a desk: its task under its name, the workers before newest first
(three in the row, all in the details), and a New worker button that opens
the worker's form for that row."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office rows detail*"))
   (unwind-protect
       (progn
         (vikix-office--render)
         ;; A desk with no task yet says so, and offers a worker all the same.
         (should (string-match-p "Task +none yet: New worker" (buffer-string)))
         (should (equal (cl-count "New worker…" (office-test-buttons) :test #'equal) 2))
         (let ((r (vikix-office--row)))
           (setf (alist-get 'task r) '((text . "Fix the picker, the wifi\none") (by . "user") (at . 1791300000)))
           (setf (alist-get 'workers r)
                 (mapcar (lambda (n) `((task . ,(format "task %d" n)) (status . ,(if (= n 4) "" "review"))
                                       (provider . "codex") (by . "user") (at . 1) (ended . 1791300000)
                                       (left . ,(if (= n 4) "dismissed" "")) (summary . ,(format "did %d" n))))
                         '(1 2 3 4))))
         (vikix-office--render)
         (should (string-match-p "Task +Fix the picker, the wifi one" (buffer-string)))
         ;; Wrapped inside the box, so in pieces: three in the row, the rest counted.
         (should (string-match-p "Before +review · codex · task 1; review · codex · task 2" (buffer-string)))
         (should (string-match-p "task 3; 1 more" (buffer-string)))
         (should-not (string-match-p "task 4" (buffer-string)))
         (with-current-buffer vikix-office--detail
           (should (string-match-p "Workers before this one · 4" (buffer-string)))
           (should (string-match-p "dismissed · codex · task 4" (buffer-string)))
           (should (string-match-p "user · ended .* · did 4" (buffer-string))))
         ;; The row's button selects its desk and asks the backend what the form offers.
         (let (args)
           (cl-letf (((symbol-function 'vikix-office--request) (lambda (a _slot _done &optional _input) (setq args a))))
             (vikix-office-next 1)
             (should (equal vikix-office--selected "b"))
             (goto-char (point-min))
             (search-forward "New worker…")
             (push-button (1- (point)))
             (should (equal vikix-office--selected "a"))
             (should (equal args '("office" "--form")))))
         ;; A desk with an agent at it, or one that is gone, offers none.
         (setf (alist-get 'agents (vikix-office--row)) '(((agent . "codex") (pid . 1) (window . "3") (doing . "working"))))
         (vikix-office--render)
         (should (equal (cl-count "New worker…" (office-test-buttons) :test #'equal) 1))
         (setf (alist-get 'agents (vikix-office--row)) nil
               (alist-get 'exists (vikix-office--row)) :false)
         (vikix-office--render)
         (should (equal (cl-count "New worker…" (office-test-buttons) :test #'equal) 1)))
     (kill-buffer vikix-office--detail))))
(ert-deftest office-close-agent-confirmation-and-selection ()
  (office-test-buffer
   (vikix-office--render)
   (should-error (vikix-office-close-agent) :type 'user-error)
   (setf (alist-get 'agents (vikix-office--row))
         '(((agent . "codex") (pid . 123) (process_start . "456"))
           ((agent . "claude") (pid . 789) (process_start . "999"))))
   (let (args)
     (cl-letf (((symbol-function 'completing-read)
                (lambda (_prompt choices &rest _) (car (nth 1 choices))))
               ((symbol-function 'yes-or-no-p) (lambda (&rest _) nil))
               ((symbol-function 'vikix-office--act) (lambda (a) (setq args a))))
       (vikix-office-close-agent)
       (should-not args)
       (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
         (vikix-office-close-agent)
         (should (equal args '("office" "--close-agent" "789" "999"))))))
   (setf (alist-get 'live_known vikix-office--data) :false)
   (should-error (vikix-office-close-agent) :type 'user-error)))

(ert-deftest office-keys-follow-a-reload ()
  "A key the file binds reaches an Office opened before the file was loaded
again: the map is bound at every load, and the desk pane's copy made again."
  (let ((file (symbol-file 'vikix-office-mode)))
    (office-test-buffer
     (setq vikix-office--detail (generate-new-buffer " *Office keys detail*"))
     (unwind-protect
         (progn
           (with-current-buffer vikix-office--detail (use-local-map (vikix-office--detail-map)))
           ;; As an Office from before: C and N unbound in the map and in the pane's copy.
           (define-key vikix-office-mode-map (kbd "C") nil)
           (define-key vikix-office-mode-map (kbd "N") nil)
           (with-current-buffer vikix-office--detail (local-set-key (kbd "C") nil))
           (should-not (lookup-key vikix-office-mode-map (kbd "C")))
           (load file nil t)
           (should (eq (lookup-key vikix-office-mode-map (kbd "C")) 'vikix-office-close-desk))
           (should (eq (lookup-key vikix-office-mode-map (kbd "N")) 'vikix-office-new-desk))
           (should (eq (lookup-key (current-local-map) (kbd "C")) 'vikix-office-close-desk))
           ;; The pane's copy is made again as the Office is opened again.
           (with-current-buffer vikix-office--detail (use-local-map (vikix-office--detail-map)))
           (with-current-buffer vikix-office--detail
             (should (eq (lookup-key (current-local-map) (kbd "C")) 'vikix-office-close-desk))
             (should (eq (lookup-key (current-local-map) (kbd "RET")) 'push-button))))
       (kill-buffer vikix-office--detail)))))

(ert-deftest office-close-desk-confirms-and-force-is-a-second-yes ()
  "Close desk: offered for a standing desk with nobody at it; one yes closes
a clean desk, files uncommitted want a yes of their own and go as --force;
refused with an agent at the desk, and in the archive."
  (office-test-buffer
   (setq vikix-office--detail (generate-new-buffer " *Office close desk*"))
   (unwind-protect
       (let (args asked)
         (vikix-office--render)   ; selects the first desk
         (setcdr (assq 'now (vikix-office--row)) '((dirty . 0) (branch . "a") (commit . "abc")))
         (vikix-office--render)
         (with-current-buffer vikix-office--detail (should (string-match-p "Close desk…" (buffer-string))))
         (cl-letf (((symbol-function 'yes-or-no-p) (lambda (q) (push q asked) nil))
                   ((symbol-function 'vikix-office--act) (lambda (a &rest _) (setq args a))))
           (should-error (vikix-office-close-desk) :type 'user-error)
           (should-not args))
         (cl-letf (((symbol-function 'yes-or-no-p) (lambda (q) (push q asked) t))
                   ((symbol-function 'vikix-office--act) (lambda (a &rest _) (setq args a))))
           (vikix-office-close-desk)
           (should (equal args '("office" "--close-desk" "/tmp/a desk with spaces")))
           ;; Files uncommitted: a question of their own, then --force.
           (setcdr (assq 'now (vikix-office--row)) '((dirty . 3) (branch . "a") (commit . "abc")))
           (setq asked nil)
           (vikix-office-close-desk)
           (should (equal args '("office" "--close-desk" "/tmp/a desk with spaces" "--force")))
           (should (= 2 (length asked)))
           (should (string-match-p "3 files uncommitted" (cadr asked))))
         ;; No to throwing the files away: nothing done.
         (setq args nil)
         (cl-letf (((symbol-function 'yes-or-no-p) (lambda (q) (not (string-match-p "uncommitted" q))))
                   ((symbol-function 'vikix-office--act) (lambda (a &rest _) (setq args a))))
           (should-error (vikix-office-close-desk) :type 'user-error)
           (should-not args))
         (setf (alist-get 'agents (vikix-office--row)) '(((agent . "codex") (pid . 1) (window . "3"))))
         (vikix-office--render)
         (with-current-buffer vikix-office--detail (should-not (string-match-p "Close desk…" (buffer-string))))
         (should-error (vikix-office-close-desk) :type 'user-error)
         (setf (alist-get 'agents (vikix-office--row)) nil)
         (nconc (vikix-office--row) (list (cons 'archived t)))
         (should-error (vikix-office-close-desk) :type 'user-error))
     (kill-buffer vikix-office--detail))))

(ert-deftest office-open-here-shares-the-setup-and-gives-the-frame-back ()
  "The terminal path builds the same two buffers in the selected frame
and q puts the windows back; the only frame is never deleted."
  (let ((vikix-office-command '("python3" "-c" "import time; time.sleep(20)"))
        (vikix-office-interval 60)
        (before (current-window-configuration))
        buffer detail timer process)
    (unwind-protect
        (progn
          (vikix-office-open-here)
          (setq buffer (get-buffer "*The Office*") detail (get-buffer "*Office desk*"))
          (should (buffer-live-p buffer))
          (should (buffer-live-p detail))
          (should (eq (frame-parameter nil 'vikix-office-buffer) buffer))
          (should (= 2 (length (window-list nil 'no-minibuf))))
          (should (eq (window-buffer (selected-window)) buffer))
          (should (get-buffer-window detail))
          (with-current-buffer detail (should truncate-lines))
          (with-current-buffer buffer
            (should (eq major-mode 'vikix-office-mode))
            (should (eq vikix-office--frame (selected-frame)))
            (should-not vikix-office--own-frame)
            (should (window-configuration-p vikix-office--windows))
            (should (timerp vikix-office--timer))
            (setq timer vikix-office--timer process vikix-office--process))
          (should (memq timer timer-list))
          (should (process-live-p process))
          (with-current-buffer detail (vikix-office-close))
          (should-not (buffer-live-p buffer))
          (should-not (buffer-live-p detail))
          (should-not (memq timer timer-list))
          (should-not (process-live-p process))
          (should (frame-live-p (selected-frame)))
          (should (= 1 (length (window-list nil 'no-minibuf))))
          ;; The frame's own, as the launcher asks (emacsclient -nw): q would
          ;; delete the frame, but never the only one there is.
          (vikix-office-open-here t)
          (setq buffer (get-buffer "*The Office*"))
          (with-current-buffer buffer
            (should vikix-office--own-frame)
            (should-not vikix-office--windows)
            (vikix-office-close))
          (should-not (buffer-live-p buffer))
          (should (frame-live-p (selected-frame))))
      (dolist (name '("*The Office*" "*Office desk*"))
        (when (get-buffer name) (kill-buffer name)))
      (set-window-configuration before))))

(ert-deftest office-test-progress-line ()
  (should (string-match-p
           "2/5 done, 3 remaining; running: lint"
           (vikix-office--tester-line
            '((name . "tests/run.sh")
              (progress . (((summary . "2/5 done, 3 remaining; running: lint; ETA unknown")))))))))

(ert-deftest office-test-progress-details ()
  (office-test-buffer
   (let ((row (car (alist-get 'desks vikix-office--data))))
     (nconc row
            '((testing . 4242)
              (tester . ((pid . 4242) (direct . t) (name . "tests/run.sh")
                         (progress . (((summary . "1/3 done, 2 remaining; running: lint; ETA unknown")
                                       (tests . (((line . "lint: running, 400s elapsed — suspected stalled (long runtime)") (stalled . t))
                                                 ((line . "office: queued, about 60s once started")))))))))))
     (setq vikix-office--detail (generate-new-buffer " *Progress details*"))
     (unwind-protect
         (progn
           (setq vikix-office--selected "a")
           (vikix-office--render-detail)
           (with-current-buffer vikix-office--detail
             (should (string-match-p "1/3 done, 2 remaining" (buffer-string)))
             (should (string-match-p "suspected stalled" (buffer-string)))
             (should (string-match-p "office: queued" (buffer-string)))
             (should-not (string-match-p "No test has ended yet" (buffer-string)))
             (let (labels)
               (save-excursion
                 (goto-char (point-min))
                 (while (forward-button 1 nil nil t)
                   (push (button-label (button-at (point))) labels)))
               (should-not (member "Skip tests" labels))
               (should-not (member "Test log" labels))))
           (should-error (vikix-office-skip-tests) :type 'user-error))
       (kill-buffer vikix-office--detail)))))
