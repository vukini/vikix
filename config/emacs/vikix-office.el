;;; vikix-office.el --- Tasks and agents in their own frame, or your terminal -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'button)
(require 'subr-x)
(require 'seq)
(require 'widget)
(require 'wid-edit)

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

;; What a desk's terminal needs of you, in the desktop's three colours
;; (agents.lisp: the bar's window list and the title bar show the same):
;; the agent asks, its desk is released and the branch waits for gup, that
;; is pushed and the terminal can go. The colours are the theme's
;; (agent_asks, agent_released, agent_pushed in the palette `vikix theme'
;; writes, read at each draw so a theme change is followed); without a
;; palette, Emacs's own warning, success and constant faces, which every
;; theme sets for light and dark.
(defgroup vikix-office nil "The Office: tasks, desks and agents." :group 'applications)
(defface vikix-office-asks '((t :inherit warning))
  "A desk whose agent waits for you." :group 'vikix-office)
(defface vikix-office-released '((t :inherit success))
  "A desk released, its branch not pushed yet: gup." :group 'vikix-office)
(defface vikix-office-pushed '((t :inherit font-lock-constant-face))
  "A desk released and pushed: its terminal can be closed." :group 'vikix-office)
(defun vikix-office--attention-face (kind)
  "The face for KIND (\"asks\", \"gup\", \"close\"), or nil."
  (pcase kind ("asks" 'vikix-office-asks) ("gup" 'vikix-office-released) ("close" 'vikix-office-pushed)))
(defun vikix-office--attention-colours ()
  "Give the three faces the desktop's colours, from the theme's palette when
`vikix-theme-palette' (vikix-theme.el) is loaded and has them."
  (when (fboundp 'vikix-theme-palette)
    (let ((palette (ignore-errors (vikix-theme-palette))))
      (pcase-dolist (`(,face ,key ,fallback) '((vikix-office-asks "agent_asks" "color3")
                                               (vikix-office-released "agent_released" "color2")
                                               (vikix-office-pushed "agent_pushed" "color6")))
        (let ((colour (or (cdr (assoc key palette)) (cdr (assoc fallback palette)))))
          (when (and colour (not (equal colour (face-foreground face nil t))))
            (set-face-attribute face nil :foreground colour)))))))
(defvar-local vikix-office--archive nil)

(defun vikix-office--get (key object) (alist-get key object))
(defun vikix-office--text (value) (if (stringp value) value (format "%s" (or value "unknown"))))
(defun vikix-office--one-line (value)
  (replace-regexp-in-string "[\n\r\t]+" " " (vikix-office--text value)))
(defun vikix-office--time (value)
  (if (numberp value) (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time value)) "time unknown"))
(defun vikix-office--clock (value)
  (if (numberp value) (format-time-string "%H:%M" (seconds-to-time value)) "?"))
(defun vikix-office--owner-buffer ()
  (if (buffer-live-p vikix-office--owner) vikix-office--owner (current-buffer)))
(defun vikix-office--rows ()
  (alist-get (if vikix-office--archive 'archive 'desks) vikix-office--data))
(defun vikix-office--folder-p (row)
  "ROW is a plain folder agents run in (an agent started in ~), not a desk."
  (equal (alist-get 'kind row) "folder"))
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
      (vikix-office--notice "Refreshing…  g refresh · RET details · N new desk · w worker · a go to agent · c continue · P pause/go · t test · i tell · x close agent · q close Office")
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
                              " · g refresh · RET details · N new desk · w worker · a go to agent · c continue · P pause/go · t test · i tell · x close agent · q close Office")))))
             (error (vikix-office--failure (error-message-string err))))))))))

(defun vikix-office--positive (value) (and (numberp value) (> value 0)))
(defun vikix-office--worker-p (r)
  "A desk that stands, where the worker's actions make sense."
  (and r (not (vikix-office--folder-p r)) (eq (alist-get 'exists r) t) (not (eq (alist-get 'archived r) t))))

(defun vikix-office--worker-line (w)
  "One worker of a desk's history in a line: how it ended, who, its task."
  (concat (let ((status (alist-get 'status w)) (left (alist-get 'left w)))
            (cond ((not (member status '(nil ""))) (vikix-office--one-line status))
                  ((not (member left '(nil ""))) (vikix-office--one-line left))
                  (t "no status")))
          (let ((provider (alist-get 'provider w)))
            (if (member provider '(nil "")) "" (concat " · " (vikix-office--one-line provider))))
          " · " (vikix-office--one-line (or (alist-get 'task w) ""))))

(defun vikix-office--button (label action)
  (insert-text-button label 'follow-link t 'action (lambda (_) (funcall action)))
  (insert "  "))

;; The boxes. Each group of desks, and each section of a desk's details, is
;; drawn in one, a labelled row a line, so the two panes read as tables
;; and not as prose (2026-10-08: as prose the Office was a wall of text).
;; The width is the buffer's window's, measured at each drawing and again
;; when the window is resized; a terminal that can't show the box
;; characters gets ASCII ones.
(defvar-local vikix-office--width nil "The inner width the buffer was last drawn at.")
(defun vikix-office--geometry ()
  "The inner width to draw at and the box's characters, for this buffer's window."
  (let ((window (get-buffer-window (current-buffer) t)))
    (cons (max 40 (- (if window (window-body-width window) 80) 5))
          (if (with-selected-window (or window (selected-window)) (char-displayable-p ?│))
              "┌┐└┘─│├┤" "++++-|++"))))
(defun vikix-office--fill (text width)
  "TEXT as lines of at most WIDTH columns, broken at spaces."
  (let ((lines nil) (line ""))
    (dolist (word (split-string (vikix-office--one-line text) " +" t))
      ;; A word wider than a line (a path) is cut.
      (while (> (string-width word) width)
        (let ((head (truncate-string-to-width word width)))
          (when (string-empty-p head) (setq head (substring word 0 1)))
          (unless (string-empty-p line) (push line lines) (setq line ""))
          (push head lines)
          (setq word (substring word (length head)))))
      (cond ((string-empty-p line) (setq line word))
            ((<= (+ (string-width line) 1 (string-width word)) width)
             (setq line (concat line " " word)))
            (t (push line lines) (setq line word))))
    (nreverse (cons line lines))))
(defun vikix-office--edge (chars left right width title)
  "A box's horizontal edge, WIDTH wide inside, with TITLE in it when given.
LEFT and RIGHT index the corners, or the joins of a rule, in CHARS."
  (let* ((bar (aref chars 4))
         (label (if (member title '(nil "")) ""
                  (concat " " (truncate-string-to-width title (- width 2) nil nil "…") " "))))
    (insert (propertize (string (aref chars left) bar) 'face 'shadow)
            (propertize label 'face 'bold)
            (propertize (concat (make-string (- (1+ width) (string-width label)) bar)
                                (string (aref chars right)))
                        'face 'shadow)
            "\n")))
(defun vikix-office--box-top (width chars title) (vikix-office--edge chars 0 1 width title))
(defun vikix-office--box-bottom (width chars) (vikix-office--edge chars 2 3 width nil) (insert "\n"))
(defun vikix-office--box-rule (width chars) (vikix-office--edge chars 6 7 width nil))
(defun vikix-office--line (width chars content)
  "One line of a box: CONTENT, a string or a function that inserts it, padded."
  (let ((side (propertize (string (aref chars 5)) 'face 'shadow)))
    (insert side " ")
    (if (functionp content) (funcall content) (insert content))
    (let ((used (- (current-column) 2)))
      (when (< used width) (insert (make-string (- width used) ?\s))))
    (insert " " side "\n")))
(defun vikix-office--field (width chars label-width label text &optional face)
  "A box's row: LABEL in a column LABEL-WIDTH wide, TEXT filled beside it, in FACE."
  (let ((first t))
    (dolist (line (vikix-office--fill text (- width label-width)))
      (vikix-office--line width chars
                          (concat (truncate-string-to-width (if first (or label "") "") label-width nil ?\s)
                                  (if face (propertize line 'face face) line)))
      (setq first nil))))
(defun vikix-office--note (width chars text)
  "A line of a box that says something about the box, in the shade."
  (vikix-office--field width chars 0 "" text 'shadow))
(defun vikix-office--label-width (labels least)
  "A label column wide enough for LABELS, two spaces of air, and at least LEAST."
  (apply #'max least (mapcar (lambda (l) (+ 2 (string-width l))) labels)))
(defun vikix-office--resized (window)
  "Draw the buffer again when its WINDOW's width is not the one it was drawn at."
  (when (window-live-p window)
    (let ((owner (vikix-office--owner-buffer)))
      (when (and (buffer-live-p owner)
                 (not (buffer-local-value 'vikix-office--closed owner))
                 (not (equal vikix-office--width (car (vikix-office--geometry)))))
        (if (eq owner (current-buffer)) (vikix-office--render)
          (with-current-buffer owner (vikix-office--render-detail)))))))

(defun vikix-office--render ()
  (let* ((rows (vikix-office--rows))
         (owner (current-buffer))
         (old (point)) (column (current-column))
         (views (mapcar (lambda (w) (list w (window-start w) (window-hscroll w)))
                        (get-buffer-window-list (current-buffer) nil t)))
         (geometry (vikix-office--geometry)) (width (car geometry)) (chars (cdr geometry))
         (label-width 9))
    (unless (vikix-office--row) (setq vikix-office--selected (alist-get 'id (car rows))))
    (setq vikix-office--width width)
    (vikix-office--attention-colours)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (propertize "The Office\n" 'face '(:inherit variable-pitch :height 1.5 :weight bold)))
      (insert "A row a desk: its task, its workers before, under it. Conversations stay in their agent terminals.\n\n")
      (unless vikix-office--archive
        (vikix-office--button "New desk…" (lambda () (with-current-buffer owner (vikix-office-new-desk)))))
      (vikix-office--button (if vikix-office--archive "Back to desks" (format "Archive (%d)" (length (alist-get 'archive vikix-office--data))))
                            (lambda () (with-current-buffer owner (vikix-office-toggle-archive))))
      (when (and vikix-office--archive rows (eq (alist-get 'live_known vikix-office--data) t)
                 (not (alist-get 'errors vikix-office--data)))
        (vikix-office--button "Purge archive…" (lambda () (with-current-buffer owner (vikix-office-purge-archive)))))
      (insert "\n\n")
      ;; The releases under way (.claude/release's queue, as --queue shows
      ;; it): a box when there are any, the one whose turn it is first; a
      ;; line when a repository has released before and none is under way;
      ;; nothing on a machine that never released.
      (unless vikix-office--archive
        (let ((releases (alist-get 'releases vikix-office--data)))
          (cond (releases
                 (let ((label-width (vikix-office--label-width
                                     (mapcar (lambda (r) (vikix-office--one-line (alist-get 'topic r))) releases) 8)))
                   (vikix-office--box-top width chars "Releases")
                   (vikix-office--note width chars "The one whose turn it is first; the others wait for it.")
                   (dolist (r releases)
                     (vikix-office--field width chars label-width (vikix-office--one-line (alist-get 'topic r))
                                          (concat (vikix-office--one-line (alist-get 'state r))
                                                  " · since " (vikix-office--clock (alist-get 'since r))
                                                  (let ((kind (alist-get 'kind r)))
                                                    (if (member kind '(nil "")) "" (concat " · " (vikix-office--one-line kind))))))
                     (vikix-office--field width chars label-width ""
                                          (concat (vikix-office--one-line (alist-get 'project r)) " · "
                                                  (vikix-office--one-line (alist-get 'summary r)))
                                          'shadow))
                   (vikix-office--box-bottom width chars)))
                ((eq (alist-get 'releases_kept vikix-office--data) t)
                 (insert (propertize "No release under way.\n\n" 'face 'shadow))))))
      (if (null rows) (insert (if vikix-office--archive "Archive is empty.\n" "No desks yet. vikix agents desk PROJECT TOPIC makes one, vikix agents worker TOPIC \"the task\" starts a worker at it.\n"))
        (dolist (group (if vikix-office--archive '("Archived") '("Needs you" "Working" "Parked" "Finished")))
          (let ((members (cl-remove-if-not (lambda (r) (equal (alist-get 'group r) group)) rows))
                (first t))
            (vikix-office--box-top width chars group)
            (if (null members) (vikix-office--note width chars "none")
              (dolist (r members)
                (unless first (vikix-office--box-rule width chars))
                (setq first nil)
                (let* ((start (point)) (id (alist-get 'id r)) (folder (vikix-office--folder-p r))
                       ;; The desk's colour: what its terminal needs of you, as the desktop shows it.
                       (face (vikix-office--attention-face (alist-get 'attention r))))
                  (vikix-office--line
                   width chars
                   (lambda ()
                     (insert-text-button (truncate-string-to-width (vikix-office--one-line (alist-get 'title r)) width nil nil "…")
                                         'face (if face (list face 'button) 'button)
                                         'follow-link t 'action
                                         (lambda (button)
                                           (goto-char (button-start button))
                                           (setq vikix-office--selected id)
                                           (vikix-office--render-detail)
                                           (vikix-office-details)))))
                  (vikix-office--note width chars
                                      (concat (if folder "Not a desk"
                                                (vikix-office--one-line (or (alist-get 'project (alist-get 'desk r)) "Project unrecorded")))
                                              " · " (vikix-office--one-line (alist-get 'provider r))))
                  ;; The desk's task now, the user's words in a line; a desk with none
                  ;; stands for a worker later. A plain folder has no record to hold one.
                  (unless folder
                    (let ((task (alist-get 'text (alist-get 'task r))))
                      (vikix-office--field width chars label-width "Task"
                                           (if (member task '(nil "")) "none yet: New worker… gives it one"
                                             (truncate-string-to-width (vikix-office--one-line task)
                                                                       (* 2 (- width label-width)) nil nil "…"))
                                           (and (member task '(nil "")) 'shadow))))
                  (vikix-office--field width chars label-width "Live"
                                       (concat
                                        (if (eq (alist-get 'live_known r) :false) "unknown"
                                          (if (alist-get 'agents r)
                                              (string-join (mapcar (lambda (a) (vikix-office--one-line (alist-get 'doing a))) (alist-get 'agents r)) ", ")
                                            "none observed"))
                                        ;; A worker's state: paused (by whom), its tests running, notes waiting for it.
                                        (if (alist-get 'paused r) (concat " · paused by " (vikix-office--one-line (alist-get 'by (alist-get 'paused r)))) "")
                                        (if (vikix-office--positive (alist-get 'testing r)) " · testing" "")
                                        (if (vikix-office--positive (alist-get 'notes r))
                                            (format " · %d note%s waiting" (alist-get 'notes r) (if (= (alist-get 'notes r) 1) "" "s")) ""))
                                       face)
                  ;; A plain folder keeps no handoff: nothing to say of one. Where
                  ;; the work stands against the agent's estimate, while one stands.
                  (unless folder
                    (let ((estimate (alist-get 'estimate r)))
                      (vikix-office--field width chars label-width "Handoff"
                                           (concat (vikix-office--one-line (alist-get 'status r))
                                                   (if (member estimate '(nil "")) "" (concat " · " (vikix-office--one-line estimate)))
                                                   (if (eq (alist-get 'tests_off r) t) " · tests off" ""))))
                    ;; .claude/release at work on this desk's branch.
                    (let ((release (alist-get 'release r)))
                      (unless (member release '(nil ""))
                        (vikix-office--field width chars label-width "Release" (vikix-office--one-line release)))))
                  ;; Two lines of it at most here; the desk's details have it whole.
                  (vikix-office--field width chars label-width "Next"
                                       (truncate-string-to-width (vikix-office--one-line (alist-get 'next_action r))
                                                                 (* 2 (- width label-width)) nil nil "…"))
                  ;; The workers before this task, newest first, as the record's history
                  ;; keeps them: how each ended, who, and its task; three here, all in the details.
                  (let ((workers (alist-get 'workers r)))
                    (when workers
                      (vikix-office--field width chars label-width "Before"
                                           (truncate-string-to-width
                                            (concat (mapconcat #'vikix-office--worker-line (seq-take workers 3) "; ")
                                                    (if (> (length workers) 3) (format "; %d more" (- (length workers) 3)) ""))
                                            (* 2 (- width label-width)) nil nil "…")
                                           'shadow)))
                  ;; A standing desk with nobody at it takes a new worker: the form, for
                  ;; this row. With an agent there the button is not shown, as the
                  ;; details show only the buttons that can act (Tell speaks to it).
                  (when (and (vikix-office--worker-p r) (eq (alist-get 'live_known r) t) (not (alist-get 'agents r)))
                    (vikix-office--line width chars
                                        (lambda ()
                                          (vikix-office--button "New worker…"
                                                                (lambda () (with-current-buffer owner
                                                                             (setq vikix-office--selected id)
                                                                             (vikix-office-worker)))))))
                  (add-text-properties start (point) `(office-id ,id)))))
            (vikix-office--box-bottom width chars)))))
    (let ((position (vikix-office--position vikix-office--selected)))
      (goto-char (or position (min old (point-max))))
      (when position (move-to-column column)))
    (dolist (view views)
      (when (window-live-p (car view))
        (set-window-start (car view) (min (nth 1 view) (point-max)) t)
        (set-window-hscroll (car view) (nth 2 view))
        (set-window-point (car view) (point))))
    (vikix-office--render-detail)))

(defun vikix-office--signed (width chars label-width label entry)
  "A row of ENTRY's text, then who recorded it and when."
  (vikix-office--field width chars label-width label
                       (vikix-office--text (or (alist-get 'text entry) (alist-get 'value entry) "Unrecorded")))
  (when entry
    (vikix-office--field width chars label-width ""
                         (concat (vikix-office--text (alist-get 'by entry)) " · " (vikix-office--time (alist-get 'at entry)))
                         'shadow)))

(defun vikix-office--render-detail ()
  (when (buffer-live-p vikix-office--detail)
    (let ((r (vikix-office--row)) (owner (current-buffer)))
      (with-current-buffer vikix-office--detail
        (let* ((inhibit-read-only t) (old (point))
               (views (mapcar (lambda (w) (cons w (window-start w)))
                              (get-buffer-window-list (current-buffer) nil t)))
               (geometry (vikix-office--geometry)) (width (car geometry)) (chars (cdr geometry)))
          (setq vikix-office--width width)
          (erase-buffer)
          (if (not r) (insert "Select a desk to see its task and handoff.\n")
            (insert (propertize (vikix-office--text (alist-get 'title r)) 'face '(:inherit variable-pitch :height 1.3 :weight bold)) "\n\n")
            (if (eq (alist-get 'archived r) t)
                (progn
                  (vikix-office--box-top width chars "Archived")
                  (vikix-office--field width chars 0 "" "Desk removed. No action is needed.")
                  (vikix-office--note width chars "Historical handoff below; its next action may already be completed.")
                  (when (and (eq (alist-get 'live_known r) t) (alist-get 'id (alist-get 'desk r)))
                    (vikix-office--line width chars
                                        (lambda () (vikix-office--button "Forget this record…" (lambda () (with-current-buffer owner (vikix-office-forget)))))))
                  (vikix-office--box-bottom width chars))
              (when (eq (alist-get 'live_known r) t)
                (let ((agents (alist-get 'agents r)))
                  (when (cl-some (lambda (a) (not (member (alist-get 'window a) '(nil "")))) agents)
                    (vikix-office--button "Go to agent" (lambda () (with-current-buffer owner (vikix-office-go)))))
                  (when (and (not agents) (eq (alist-get 'exists r) t) (not (vikix-office--folder-p r)))
                    (vikix-office--button "Continue…" (lambda () (with-current-buffer owner (vikix-office-continue))))
                    (vikix-office--button "New worker…" (lambda () (with-current-buffer owner (vikix-office-worker)))))
                  (when (cl-some (lambda (a) (alist-get 'process_start a)) agents)
                    (vikix-office--button "Close agent…" (lambda () (with-current-buffer owner (vikix-office-close-agent)))))
                  (when (vikix-office--worker-p r)
                    (vikix-office--button (if (alist-get 'paused r) "Go" "Pause") (lambda () (with-current-buffer owner (vikix-office-pause))))
                    (vikix-office--button "Test" (lambda () (with-current-buffer owner (vikix-office-test))))
                    (vikix-office--button "Tell…" (lambda () (with-current-buffer owner (vikix-office-tell)))))))
              (insert "\n\n"))
            (if (vikix-office--folder-p r)
                ;; Not a desk: no task, no handoff, no Git state to observe. The
                ;; agents are listed below; Go to agent and Close agent work as on a desk.
                (progn
                  (vikix-office--box-top width chars "Not a desk")
                  (vikix-office--field width chars 0 "" (concat "Agents running in " (vikix-office--text (alist-get 'title r))))
                  (vikix-office--note width chars "An agent takes a desk with vikix agents sit PROJECT TOPIC from its own shell; vikix agents desk PROJECT TOPIC makes a desk, vikix agents worker TOPIC \"the task\" starts one at it.")
                  (vikix-office--box-bottom width chars))
              (vikix-office--box-top width chars "Task")
              (vikix-office--signed width chars 0 "" (alist-get 'task r))
              ;; How the last agent left (dismissed, exited, logged out), and the notes waiting for the next.
              (let ((gone (alist-get 'left r)))
                (when (and gone (alist-get 'reason gone))
                  (vikix-office--field width chars 0 ""
                                       (format "Last agent left: %s · %s · %s%s" (vikix-office--text (alist-get 'reason gone))
                                               (vikix-office--text (alist-get 'by gone)) (vikix-office--time (alist-get 'at gone))
                                               (if (numberp (alist-get 'dirty gone)) (format " · %d uncommitted then" (alist-get 'dirty gone)) ""))
                                       'shadow)))
              (when (vikix-office--positive (alist-get 'notes r))
                (vikix-office--field width chars 0 ""
                                     (format "Notes waiting for its agent: %d (delivered at its next tool call)" (alist-get 'notes r))))
              (when (eq (alist-get 'tests_off r) t)
                (vikix-office--field width chars 0 "" "Tests: not run by themselves when the worker hands in; Test runs them" 'shadow))
              (vikix-office--box-bottom width chars)
              (vikix-office--box-top width chars "Agent claims")
              (vikix-office--note width chars "The agent's own report: review does not mean merged.")
              (let ((handoff (alist-get 'handoff r)) (label-width 10))
                (vikix-office--signed width chars label-width "Status" (alist-get 'status handoff))
                ;; The estimate, when the agent gave one: its words, then the clock against it.
                (let ((estimate (alist-get 'estimate handoff)))
                  (when estimate
                    (vikix-office--signed width chars label-width "Estimate" estimate)
                    (vikix-office--field width chars label-width "" (vikix-office--text (alist-get 'estimate r)))))
                (vikix-office--signed width chars label-width "Summary" (alist-get 'summary handoff))
                (vikix-office--signed width chars label-width "Next" (alist-get 'next handoff)))
              (vikix-office--box-bottom width chars)
              ;; The desk's workers before this task, newest first: the record's history.
              (let ((workers (alist-get 'workers r)))
                (when workers
                  (vikix-office--box-top width chars (format "Workers before this one · %d" (length workers)))
                  (vikix-office--note width chars "Each task before, how it ended and the agent's last word on it.")
                  (dolist (w workers)
                    (vikix-office--field width chars 0 "" (vikix-office--worker-line w))
                    (vikix-office--field width chars 0 ""
                                         (concat (vikix-office--text (alist-get 'by w)) " · ended " (vikix-office--time (alist-get 'ended w))
                                                 (let ((summary (alist-get 'summary w)))
                                                   (if (member summary '(nil "")) "" (concat " · " (vikix-office--one-line summary)))))
                                         'shadow))
                  (vikix-office--box-bottom width chars)))
              (let ((now (alist-get 'now r)) (label-width 13))
                (vikix-office--box-top width chars (concat "Observed Git state · " (vikix-office--time (alist-get 'at now))))
                (vikix-office--field width chars label-width "Worktree" (vikix-office--text (alist-get 'worktree (alist-get 'desk r))))
                (when (eq (alist-get 'exists r) :false)
                  (vikix-office--field width chars label-width "" "Worktree removed; record retained" 'shadow))
                (vikix-office--field width chars label-width "Branch" (vikix-office--text (alist-get 'branch now)))
                (vikix-office--field width chars label-width "Commit" (vikix-office--text (alist-get 'commit now)))
                (vikix-office--field width chars label-width "Uncommitted" (vikix-office--text (alist-get 'dirty now)))
                (let ((release (alist-get 'release r)))
                  (unless (member release '(nil ""))
                    (vikix-office--field width chars label-width "Release" (vikix-office--one-line release))))
                (vikix-office--box-bottom width chars))
              (vikix-office--box-top width chars "Reported checks")
              (vikix-office--note width chars "Freshness compares code, not the truth of the report.")
              (unless (alist-get 'checks r) (vikix-office--field width chars 0 "" "No checks recorded"))
              (dolist (c (alist-get 'checks r))
                (let ((label-width 9))
                  (vikix-office--field width chars label-width
                                       (if (eq (alist-get 'ok c) t) (propertize "passed" 'face 'success) (propertize "failed" 'face 'error))
                                       (vikix-office--text (alist-get 'name c)))
                  (vikix-office--field width chars label-width ""
                                       (concat (vikix-office--text (alist-get 'freshness c)) " · "
                                               (vikix-office--text (alist-get 'by c)) " · " (vikix-office--time (alist-get 'at c)))
                                       'shadow)
                  (vikix-office--field width chars label-width ""
                                       (concat "tested " (vikix-office--text (alist-get 'commit c))
                                               " · dirty " (vikix-office--text (alist-get 'dirty c)))
                                       'shadow)))
              (vikix-office--box-bottom width chars))
            (vikix-office--box-top width chars "Live agents")
            (let* ((agents (alist-get 'agents r))
                   (labels (mapcar (lambda (a) (format "%s %s" (alist-get 'agent a) (alist-get 'pid a))) agents))
                   (label-width (vikix-office--label-width labels 8)))
              (cond ((eq (alist-get 'live_known r) :false)
                     (vikix-office--field width chars 0 "" "Unknown — live discovery unavailable"))
                    ((null agents) (vikix-office--field width chars 0 "" "None observed")))
              (cl-mapc (lambda (a label)
                         (vikix-office--field width chars label-width label
                                              (format "%s · workspace %s%s" (alist-get 'doing a)
                                                      (or (alist-get 'workspace a) "unknown")
                                                      ;; Its window's name on the desktop: the desk and the provider.
                                                      (if (member (alist-get 'desk_title a) '(nil ""))
                                                          "" (concat " · " (vikix-office--one-line (alist-get 'desk_title a)))))
                                              ;; In the colour its terminal has on the desktop.
                                              (vikix-office--attention-face (alist-get 'attention a)))
                         (let ((said (if (member (alist-get 'window a) '(nil "")) "No desktop window" (or (alist-get 'said a) ""))))
                           (unless (string-empty-p said)
                             (vikix-office--field width chars label-width "" said 'shadow))))
                       agents labels))
            (vikix-office--box-bottom width chars)
            (unless (vikix-office--folder-p r)
              (vikix-office--box-top width chars "Saved conversations")
              (vikix-office--note width chars "Whether each provider's store still has it.")
              (let* ((sessions (alist-get 'sessions r))
                     (labels (mapcar (lambda (s) (vikix-office--text (alist-get 'provider s))) sessions))
                     (label-width (vikix-office--label-width labels 8)))
                (unless sessions
                  (vikix-office--field width chars 0 ""
                                       (if (eq (alist-get 'archived r) t) "None recorded"
                                         "None recorded; Continue offers an explicit fresh start")))
                (cl-mapc (lambda (s label)
                           (vikix-office--field width chars label-width label
                                                (format "%s · %s" (alist-get 'id s)
                                                        (pcase (alist-get 'available s) ('t "available") (:false "missing") (_ "unknown"))))
                           (vikix-office--field width chars label-width ""
                                                (format "%s · %s" (alist-get 'by s) (vikix-office--time (alist-get 'at s)))
                                                'shadow))
                         sessions labels))
              (vikix-office--box-bottom width chars)))
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

(defun vikix-office--worker-row ()
  "The selected desk, for a worker's action; a user error otherwise."
  (let ((r (vikix-office--row)))
    (unless r (user-error "Select a desk first"))
    (unless (vikix-office--worker-p r) (user-error "Not a standing desk: nothing to do here"))
    (when (eq (alist-get 'live_known vikix-office--data) :false) (user-error "Live activity unknown; refresh first"))
    r))
(defun vikix-office-pause ()
  "Pause the selected desk's agent at its next tool call, or let a paused one go."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (vikix-office--act (list "office" "--pause" (alist-get 'id r))))))
(defun vikix-office-test ()
  "Run the selected desk's tests; the result goes into its handoff and its agent's inbox."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (vikix-office--act (list "office" "--test" (alist-get 'id r))))))
(defun vikix-office-tell ()
  "Leave the selected desk's agent a note, delivered at its next tool call."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--worker-row))
           (text (string-trim (read-string (format "Note for the agent at %s: " (vikix-office--text (alist-get 'title r)))))))
      (when (string-empty-p text) (user-error "A note needs words"))
      (vikix-office--act (list "office" "--tell" (alist-get 'id r) text)))))

(defun vikix-office-continue ()
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--row)) (plans (alist-get 'resume r)) choices)
      (unless r (user-error "Select a desk first"))
      (when (vikix-office--folder-p r) (user-error "Not a desk: nothing to continue in a plain folder (vikix agents sit PROJECT TOPIC seats an agent)"))
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


;; New desk and Worker: a form each. A desk is the place (vikix agents desk:
;; the project, a topic for its worktree and branch, and a task when a
;; worker is wanted at it at once); a worker is an agent on a task at a
;; desk that stands (vikix agents worker). The worker's words are boxes to
;; tick: which agent, on a model on this laptop, may push as you (your SSH
;; agent goes with it), no tests by themselves when it hands in. The form is
;; widget.el's, drawn in the desk pane's window, so the terminal has it as
;; the frame does; what it offers (the projects, the agents) comes from the
;; backend's office --form, asked when the form opens, never kept.
(defvar-local vikix-office--form nil
  "The open form: its owner, the desk it is for (nil for a new one), what the backend offered, its widgets by name, the window it took.")

(defun vikix-office-new-desk ()
  "Make a desk, and a worker at it when a task is given: a form."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (when (eq (alist-get 'live_known vikix-office--data) :false) (user-error "Live activity unknown; refresh first"))
    (vikix-office--form-open nil)))
(defun vikix-office-worker ()
  "Start a worker at the selected desk, on a task: a form."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (when (alist-get 'agents r)
        (user-error "An agent is at this desk already, and a desk takes its workers one at a time: Tell leaves it a note, Close agent ends it"))
      (vikix-office--form-open r))))
(defun vikix-office--form-open (desk)
  "Ask the backend what the form offers, then draw it for DESK, a row, or a new desk with nil."
  (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
  (let ((owner (current-buffer)))
    (vikix-office--notice (concat (if desk "New worker" "New desk") ": asking which projects and agents there are…"))
    (vikix-office--request
     '("office" "--form") 'vikix-office--action
     (lambda (output error)
       (if error (vikix-office--notice error)
         (condition-case err
             (vikix-office--form-draw
              owner desk
              (json-parse-string output :object-type 'alist :array-type 'list :null-object nil :false-object :false))
           (error (vikix-office--notice (error-message-string err)))))))))
(defvar vikix-office-form-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map widget-keymap)
    (define-key map (kbd "C-c C-c") #'vikix-office-form-submit)
    (define-key map (kbd "C-c C-k") #'vikix-office-form-cancel)
    map))
(defun vikix-office--form-draw (owner desk offer)
  "Draw the form for DESK (nil: a new desk) with what the backend OFFERed, in OWNER's desk pane."
  (let* ((buffer (generate-new-buffer (if desk "*Office worker*" "*Office new desk*")))
         (window (with-current-buffer owner
                   (and (buffer-live-p vikix-office--detail)
                        (get-buffer-window vikix-office--detail vikix-office--frame))))
         (agents (alist-get 'agents offer)) (projects (alist-get 'projects offer))
         widgets)
    (with-current-buffer buffer
      (kill-all-local-variables)
      (let ((inhibit-read-only t)) (erase-buffer))
      (remove-overlays)
      (widget-insert (propertize (if desk (concat "Worker at " (vikix-office--one-line (alist-get 'title desk))) "New desk")
                                 'face '(:inherit variable-pitch :height 1.3 :weight bold))
                     "\n")
      (widget-insert (if desk
                         "An agent on a task at this desk, on a workspace to itself. The task is its first prompt and goes into the desk's record; the task before it goes into the desk's history. Nothing typed is a session: an agent to talk with.\n\n"
                       "A worktree of the project beside it, on a branch named by the topic, and a record. With a task, a worker is started at it; without, the desk alone, for a worker later.\n\n"))
      (unless desk
        ;; The project is always picked, never guessed from the desk selected
        ;; (Vid, 2026-10-10): a desk in the wrong project is a worktree to undo.
        (push (cons 'project
                    (apply #'widget-create 'menu-choice :tag "Project" :value ""
                           :format "%t: %[%v%]\n" :button-prefix "[" :button-suffix "]"
                           :help-echo "The project the desk is for (vikix project list): a click or RET opens the list"
                           '(item :tag "pick one" :format "%t" :value "")
                           (mapcar (lambda (p)
                                     (list 'item :tag (concat (alist-get 'name p) "  " (or (alist-get 'short p) "")
                                                              (if (eq (alist-get 'repo p) t) "" "  (no repository: its own folder, no topic)"))
                                           :format "%t" :value (alist-get 'name p)))
                                   projects)))
              widgets)
        (widget-insert "\n")
        (push (cons 'topic (widget-create 'editable-field :size 40 :format "Topic:   %v\n"
                                          :help-echo "A word or two for the work: the worktree's ending and the branch" ""))
              widgets)
        (widget-insert (propertize "         a word or two for the work (wifi-fix, chapter-3): the folder's ending and the branch; needed for a repository\n" 'face 'shadow)))
      (widget-insert "\n")
      (push (cons 'task (widget-create 'text :format "Task:\n%v\n" :help-echo "The worker's task, in your words: its first prompt" ""))
            widgets)
      (widget-insert (propertize (if desk "         in your words; nothing for a session, the record left as it is\n"
                                   "         in your words; nothing for the desk alone\n")
                                 'face 'shadow))
      (widget-insert "\n")
      (push (cons 'agent
                  (apply #'widget-create 'menu-choice :tag "Agent"
                         :value "" :format "%t: %[%v%]\n" :button-prefix "[" :button-suffix "]"
                         :help-echo "Which agent: yours, or another (vikix agent --list): a click or RET opens the list"
                         (list 'item :tag (concat "yours (" (or (alist-get 'default offer) "claude") ")") :format "%t" :value "")
                         (mapcar (lambda (a)
                                   (list 'item
                                         :tag (concat (alist-get 'name a) "  " (or (alist-get 'about a) "")
                                                      (cond ((eq (alist-get 'yours a) t) "  (yours)")
                                                            ((eq (alist-get 'installed a) t) "")
                                                            (t "  (not installed yet: its installer is offered in the terminal)")))
                                         :format "%t" :value (alist-get 'name a)))
                                 agents)))
            widgets)
      (widget-insert "\n")
      (push (cons 'local (widget-create 'checkbox nil)) widgets)
      (widget-insert (concat " On a model on this laptop (Ollama), offline: "
                             (let ((names (mapcar (lambda (a) (alist-get 'name a))
                                                  (cl-remove-if-not (lambda (a) (eq (alist-get 'local a) t)) agents))))
                               (if names (concat (mapconcat #'identity names ", ") " can") "none installed can"))
                             "\n"))
      (push (cons 'push (widget-create 'checkbox nil)) widgets)
      (widget-insert " May push as you: your SSH agent goes with it, so git push works at the desk (no: it commits, you push)\n")
      (push (cons 'notests (widget-create 'checkbox nil)) widgets)
      (widget-insert " No tests by themselves when it hands in (the Test button runs them still)\n\n")
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-submit))
                     (if desk "Start worker" "Make desk"))
      (widget-insert "  ")
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-cancel)) "Cancel")
      (widget-insert "\n\n"
                     (propertize (concat "A click or RET on a [choice] opens its list; TAB moves between the fields; C-c C-c is the button, C-c C-k cancels."
                                         (if (eq (alist-get 'display offer) :false)
                                             " No display here: a worker's terminal can't open from this Office; a desk alone can be made."
                                           ""))
                                 'face 'shadow))
      (use-local-map vikix-office-form-map)
      (widget-setup)
      (setq vikix-office--form (list :owner owner :desk desk :offer offer :widgets widgets :window window))
      (goto-char (point-min))
      (widget-forward 1))
    (if (window-live-p window)
        (progn (set-window-buffer window buffer) (select-window window))
      (pop-to-buffer buffer))
    buffer))
(defun vikix-office--form-say (text)
  "TEXT in the form's own header line, where the eye is (the Office's is in the other pane)."
  (setq header-line-format (concat "  " (replace-regexp-in-string "%" "%%" text)))
  (force-mode-line-update))
(defun vikix-office--form-value (name)
  "The form's widget NAME's value in this buffer; nil without the widget."
  (let ((w (alist-get name (plist-get vikix-office--form :widgets))))
    (and w (widget-value w))))
(defun vikix-office--form-args ()
  "The backend's words for this form as it stands; a user error for what is missing."
  (let* ((form vikix-office--form) (desk (plist-get form :desk))
         (task (string-trim (or (vikix-office--form-value 'task) "")))
         (agent (vikix-office--form-value 'agent))
         (options (append (unless (member agent '(nil "")) (list "--use" agent))
                          (and (vikix-office--form-value 'local) '("--local"))
                          (and (vikix-office--form-value 'push) '("--push"))
                          (and (vikix-office--form-value 'notests) '("--no-tests")))))
    (unless form (user-error "Not a form"))
    (if desk
        (append (list "office" "--worker" (alist-get 'worktree (alist-get 'desk desk)))
                (unless (string-empty-p task) (list task))
                options)
      (let* ((project (vikix-office--form-value 'project))
             (topic (string-trim (or (vikix-office--form-value 'topic) "")))
             (offered (cl-find project (alist-get 'projects (plist-get form :offer))
                               :key (lambda (p) (alist-get 'name p)) :test #'equal)))
        (when (member project '(nil ""))
          (vikix-office--form-say "Pick the project: a click or RET on [pick one] opens the list")
          (user-error "Pick the project"))
        (when (and (eq (alist-get 'repo offered) t) (string-empty-p topic))
          (vikix-office--form-say "A repository's desk needs a topic: a word or two for the work")
          (user-error "A repository's desk needs a topic: a word or two for the work"))
        (append (list "office" "--desk" project)
                (unless (string-empty-p topic) (list topic))
                (unless (string-empty-p task) (list "--task" task))
                options)))))
(defun vikix-office-form-submit ()
  "Make the desk, or start the worker, as the form says; the form closes once the backend has."
  (interactive)
  (let* ((args (vikix-office--form-args)) (owner (plist-get vikix-office--form :owner)) (buffer (current-buffer)))
    (unless (buffer-live-p owner) (user-error "The Office is closed"))
    (vikix-office--form-say (if (plist-get vikix-office--form :desk) "Starting the worker…" "Making the desk…"))
    (with-current-buffer owner
      (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
      (vikix-office--request
       args 'vikix-office--action
       (lambda (output error)
         (if error
             ;; The form stays, with what to fix said where the eye is.
             (progn (vikix-office--notice error)
                    (when (buffer-live-p buffer) (with-current-buffer buffer (vikix-office--form-say error)))
                    (message "%s" (string-trim error)))
           (vikix-office--notice (or (car (last (split-string (string-trim output) "\n" t))) "Done"))
           (when (buffer-live-p buffer) (with-current-buffer buffer (vikix-office-form-cancel)))
           (vikix-office-refresh)))))))
(defun vikix-office-form-cancel ()
  "Close the form, the desk pane back in its window; nothing is started."
  (interactive)
  (let* ((form vikix-office--form) (owner (plist-get form :owner)) (window (plist-get form :window))
         (buffer (current-buffer)))
    (when (and (window-live-p window) (eq (window-buffer window) buffer) (buffer-live-p owner))
      (let ((detail (buffer-local-value 'vikix-office--detail owner)))
        (if (buffer-live-p detail) (set-window-buffer window detail) (delete-window window))))
    (kill-buffer buffer)))
(defun vikix-office--form-buffers ()
  "The form buffers open for this Office."
  (let ((owner (current-buffer)))
    (cl-remove-if-not (lambda (b) (eq (plist-get (buffer-local-value 'vikix-office--form b) :owner) owner))
                      (buffer-list))))

(defun vikix-office--cleanup ()
  (setq vikix-office--closed t)
  (dolist (b (vikix-office--form-buffers)) (kill-buffer b))
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
    (define-key map (kbd "P") #'vikix-office-pause)
    (define-key map (kbd "t") #'vikix-office-test)
    (define-key map (kbd "i") #'vikix-office-tell)
    (define-key map (kbd "N") #'vikix-office-new-desk)
    (define-key map (kbd "w") #'vikix-office-worker)
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
  ;; The boxes are drawn to the window's width: a line never wraps, and a
  ;; window made another width is drawn again.
  (setq-local truncate-lines t)
  (hl-line-mode 1)
  (add-hook 'window-size-change-functions #'vikix-office--resized nil t)
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
        (setq-local truncate-lines t)
        (add-hook 'window-size-change-functions #'vikix-office--resized nil t))
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
Interactively, the current graphical display or $DISPLAY.
Open already, the Office's frame is selected and its X window id is
returned (the outer window, the one the window manager holds), so
`vikix agents office' can ask the desktop to go to it: StumpWM takes no
notice of a frame asking for the focus from another workspace, or from
behind another window.  A frame made now returns nil: it takes the
focus as it opens."
  (interactive)
  (let ((existing (cl-find-if (lambda (f) (buffer-live-p (frame-parameter f 'vikix-office-buffer))) (frame-list))))
    (if existing
        (progn (select-frame-set-input-focus existing)
               (frame-parameter existing 'outer-window-id))
      (setq display (or (and display (not (string-empty-p display)) display)
                        (and (display-graphic-p) (frame-parameter nil 'display))
                        (getenv "DISPLAY")))
      (unless (and display (not (string-empty-p display)))
        (user-error "The Office needs an X11 display; use vikix agents office --tty in a terminal"))
      (vikix-office--setup
       (make-frame `((window-system . x) (display . ,display)
                     (name . "The Office") (title . "The Office") (tool-bar-lines . 0) (menu-bar-lines . 0) (width . 150) (height . 44)))
       t)
      nil)))
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
