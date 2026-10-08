;;; office-ui.el --- Fixture tests -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "../config/emacs/vikix-office.el" (file-name-directory load-file-name)) nil t)
(defun office-test-data (&optional ids)
  `((version . 1) (at . 1791300000) (live_known . t) (errors . nil) (releases . nil) (releases_kept . :false)
    (desks . ,(mapcar (lambda (id)
                       `((id . ,id) (title . ,(concat "Task " id)) (group . "Parked")
                         (desk . ((project . "Vikix") (worktree . "/tmp/a desk with spaces")))
                         (status . "review") (live_known . t) (exists . t) (kind . "desk")
                         (task . nil) (handoff . nil) (now . nil) (checks . nil) (sessions . nil)
                         (agents . nil) (provider . "codex") (next_action . "Review changes")
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
           (should (string-match-p "review does not mean merged" (buffer-string)))
           (should (string-match-p "Worktree removed" (buffer-string))))
         (should-error (vikix-office-continue) :type 'user-error))
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
         (should (string-match-p "^[│|] Not a desk · codex +[│|]\n[│|] Live +running +[│|]\n[│|] Next +Go to agent +[│|]$" (buffer-string)))
         (with-current-buffer vikix-office--detail
           (should (string-match-p "^[│|] Agents running in ~ +[│|]$" (buffer-string)))
           (should (string-match-p "Go to agent" (buffer-string)))
           (should (string-match-p "Close agent" (buffer-string)))
           (should-not (string-match-p "Continue" (buffer-string)))
           (should-not (string-match-p "Observed Git state\\|review does not mean merged\\|Saved conversations" (buffer-string)))
           (should (string-match-p "codex 7598 +running · workspace 2" (buffer-string))))
         (should-error (vikix-office-continue) :type 'user-error)
         ;; Without an agent left there is still no Continue: nothing to continue in a folder.
         (setf (alist-get 'agents r) nil)
         (vikix-office--render)
         (with-current-buffer vikix-office--detail
           (should-not (string-match-p "Continue" (buffer-string)))))
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

(ert-deftest office-purge-needs-confirmation-and-refreshes ()
  (office-test-buffer
   (setf (alist-get 'archive vikix-office--data) '(((id . "old")))
         (alist-get 'archive_token vikix-office--data) "confirmed-version")
   (let (args refreshed)
     (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil))
               ((symbol-function 'vikix-office--request)
                (lambda (a _slot done) (setq args a) (funcall done "Purged" nil)))
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
                        (lambda (a _slot done) (setq args a) (funcall done "forgotten" nil)))
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

(ert-deftest office-worker-actions-and-marks ()
  (office-test-buffer
   (let (args)
     (cl-letf (((symbol-function 'vikix-office--act) (lambda (a) (setq args a)))
               ((symbol-function 'read-string) (lambda (&rest _) "  look at chapter two  ")))
       (vikix-office--render)
       (vikix-office-pause)
       (should (equal args '("office" "--pause" "a")))
       (vikix-office-test)
       (should (equal args '("office" "--test" "a")))
       (vikix-office-tell)
       (should (equal args '("office" "--tell" "a" "look at chapter two")))
       (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "   ")))
         (should-error (vikix-office-tell) :type 'user-error))
       ;; A paused desk with notes waiting and a tester at work says so in its row, and offers Go.
       (nconc (vikix-office--row)            ; keys the fixture lacks, added to the row in place
              (list (cons 'paused '((at . 1791300000) (by . "user") (hard . :false)))
                    (cons 'notes 2) (cons 'testing 4242)
                    (cons 'left '((reason . "dismissed") (by . "user") (at . 1791300000) (dirty . 3)))))
       (vikix-office--render)
       (dolist (words '("paused by user" "testing" "2 notes waiting"))
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
