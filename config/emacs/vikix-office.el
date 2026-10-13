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
(defvar-local vikix-office--said nil
  "The last action's answer (Pause, Go, Test, Tell…), kept in the header line
over the refreshes that follow, so it is seen; g drops it.")

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

;; The Office's pages (2026-10-11: the first page was too long with every
;; desk on it). The first holds the desks with something to do at them: the
;; groups Needs you, Testing (the desks whose tests run, each with Skip tests:
;; 2026-10-12, they sat under Needs you with nothing to do but wait), Working
;; and Finished (a finished desk still stands, yours to release or close). The
;; second is Parked and Closed: the desks nobody
;; works at and the ones closed today. The third is the Archive, the records
;; of worktrees gone and the plans done. Each is drawn from the same snapshot; the parked page's
;; rows are the snapshot's desks of those two groups, the archive's its
;; archive list.
(defvar-local vikix-office--page 'desks
  "The page shown: `desks', `parked' or `archive'.")
(defconst vikix-office--page-groups
  '((desks . ("Needs you" "Testing" "Working" "Finished"))
    (parked . ("Parked" "Closed"))
    (archive . ("Archived")))
  "Each page's groups, in the order their boxes are drawn.")
(defun vikix-office--page-rows (page &optional data)
  "The rows of PAGE in DATA (the buffer's data when nil)."
  (let* ((data (or data vikix-office--data))
         (groups (alist-get page vikix-office--page-groups)))
    (if (eq page 'archive) (alist-get 'archive data)
      (cl-remove-if-not (lambda (r) (member (alist-get 'group r) groups)) (alist-get 'desks data)))))

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
  "The rows of the page shown."
  (vikix-office--page-rows vikix-office--page))
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
(defun vikix-office--status (text)
  "The refresh's notice: the last action's answer first, while one is kept."
  (vikix-office--notice (if vikix-office--said (concat vikix-office--said " · " text) text)))

(defun vikix-office--request (args slot done &optional input)
  "Run ARGS without a shell, INPUT on its stdin when given. DONE receives output or an error string."
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
      ;; The backend may end before it reads (a refusal): then the pipe is anyone's, and the sentinel says.
      (when input
        (ignore-errors (process-send-string process input) (process-send-eof process)))
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
    (when (called-interactively-p 'interactive) (setq vikix-office--said nil))
    (unless (or vikix-office--closed (process-live-p vikix-office--process)
                (process-live-p vikix-office--action))
      (vikix-office--status "Refreshing…  g refresh · RET details · N new desk · w worker · a go to agent · c continue · P pause/go · t test · i tell · x close agent · C close desk · q close Office")
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
                   (vikix-office--status
                    (if errors (string-join errors "; ")
                      (concat "Updated " (vikix-office--time (alist-get 'at data))
                              " · g refresh · RET details · N new desk · w worker · a go to agent · c continue · P pause/go · t test · i tell · x close agent · C close desk · q close Office")))))
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

(defun vikix-office--tester-line (tester)
  "The tester at work in a line: what runs, since when, waiting for a release."
  (let ((name (alist-get 'name tester)) (at (alist-get 'at tester)) (waiting (alist-get 'waiting tester)))
    (concat (mapconcat (lambda (run) (alist-get 'summary run)) (alist-get 'progress tester) " · ")
            (if (alist-get 'progress tester) " · " "")
            (if (member name '(nil "")) "running" (vikix-office--one-line name))
            (if (vikix-office--positive at) (concat " · since " (vikix-office--clock at)) "")
            (if (member waiting '(nil "")) "" (concat " · waiting for the release of " (vikix-office--one-line waiting))))))

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
(defun vikix-office--geometry (&optional window)
  "The inner width to draw at and the box's characters, for this buffer's
WINDOW, or the window given (a form drawn before it is placed)."
  (let ((window (or window (get-buffer-window (current-buffer) t))))
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
(defvar vikix-office--side nil
  "While a live box is drawn: where its lines' left side begins, and the side.")
(defvar-local vikix-office--live nil
  "The live boxes' inner width and side, for `vikix-office--live-sides'.")
(defun vikix-office--side-close ()
  "The left side over the live box's lines since it began: an overlay whose
`line-prefix' is the side, so a field that grows (the form's) keeps it."
  (let ((o (make-overlay (car vikix-office--side) (point))))
    (overlay-put o 'line-prefix (cdr vikix-office--side))
    (overlay-put o 'wrap-prefix (cdr vikix-office--side))
    (overlay-put o 'vikix-office-side t)))
(defun vikix-office--live-box (width chars title body)
  "A box whose lines are typed in (the New plan form's tasks): its top edge
with TITLE, BODY, a function that inserts its lines, and the bottom edge.
Every line of BODY gets the left side (`vikix-office--side-close'), and the
right side comes from `vikix-office--live-sides', put again after each
change, since a field's lines come and go as you type. BODY draws a rule
between its parts with `vikix-office--live-rule'."
  (vikix-office--box-top width chars title)
  (let ((vikix-office--side (cons (point) (propertize (string (aref chars 5)) 'face 'shadow))))
    (funcall body)
    (vikix-office--side-close))
  (vikix-office--edge chars 2 3 width nil))
(defun vikix-office--live-rule (width chars)
  "A rule across a live box, between two of its parts: the side ends above
it and begins again below."
  (vikix-office--side-close)
  (vikix-office--box-rule width chars)
  (setcar vikix-office--side (point)))
(defun vikix-office--live-sides (&rest _)
  "The right side of every line of this buffer's live boxes, put again: an
overlay on each line's end whose before-string reaches the box's edge (a
stretch aligned to its column: the fields' and buttons' faces have a box
of some pixels, so spaces would land beside it) and ends in the side; a
line inside a field reaches it in the field's face, so the field is grey
to the edge and no further. On `after-change-functions' once the form is
drawn, and after each command (the arguments are the hook's)."
  (when vikix-office--live
    (remove-overlays (point-min) (point-max) 'vikix-office-right t)
    (let ((width (car vikix-office--live)) (side (cdr vikix-office--live)))
      (dolist (o (overlays-in (point-min) (point-max)))
        (when (overlay-get o 'vikix-office-side)
          (save-excursion
            (goto-char (overlay-start o))
            (while (search-forward "\n" (overlay-end o) t)
              (let* ((at (1- (point)))
                     (field (cl-some (lambda (f)
                                       ;; A text field ends in a newline of its own, which widget
                                       ;; marks with a boundary overlay: its invisible after-string
                                       ;; makes the next line's stretch zero wide, and its face
                                       ;; paints a column past the side; neither is needed here.
                                       (when (eq (overlay-get f 'field) 'boundary)
                                         (overlay-put f 'after-string nil)
                                         (overlay-put f 'face nil))
                                       (overlay-get f 'field))
                                     (overlays-at at)))
                     ;; The left side is a column of the line that current-column doesn't count.
                     (full (>= (1+ (save-excursion (goto-char at) (current-column))) (+ width 3)))
                     (r (make-overlay at (point) nil t nil)))
                (overlay-put r 'vikix-office-right t)
                (overlay-put r 'before-string
                             ;; cursor: at the line's end point stands before the string,
                             ;; and the cursor is drawn on its first character, not after it.
                             (concat (propertize " " 'display `(space :align-to ,(+ width 3))
                                                 'cursor (not full) 'face (and field 'widget-field))
                                     (propertize side 'cursor full)))))))))))
(defun vikix-office--line (width chars content)
  "One line of a box: CONTENT, a string or a function that inserts it, padded."
  (let ((side (propertize (string (aref chars 5)) 'face 'shadow)))
    (insert side " ")
    (if (functionp content) (funcall content) (insert content))
    (let ((used (- (current-column) 2)))
      (when (< used width) (insert (make-string (- width used) ?\s))))
    (insert " " side "\n")))
(defun vikix-office--field-lines (width chars label-width label lines &optional face)
  "A box's row: LABEL in a column LABEL-WIDTH wide, LINES beside it, in FACE
unless a line carries faces of its own."
  (let ((first t))
    (dolist (line lines)
      (vikix-office--line width chars
                          (concat (truncate-string-to-width (if first (or label "") "") label-width nil ?\s)
                                  (if face (propertize line 'face face) line)))
      (setq first nil))))
(defun vikix-office--field (width chars label-width label text &optional face)
  "A box's row: LABEL in a column LABEL-WIDTH wide, TEXT filled beside it, in FACE."
  (vikix-office--field-lines width chars label-width label (vikix-office--fill text (- width label-width)) face))
(defun vikix-office--signed-lines (width label-width text by at)
  "TEXT filled beside a label LABEL-WIDTH wide, with who wrote it (BY) and
when (AT) in the shade at its end: on its last line when it fits there,
else on a line of its own. One row, however many hands the box has."
  (let* ((room (- width label-width))
         (lines (vikix-office--fill text room))
         (last (car (last lines)))
         (sig (concat (vikix-office--text by) " · " (vikix-office--time at))))
    (if (<= (+ (string-width last) 3 (string-width sig)) room)
        (append (butlast lines) (list (concat last (propertize (concat " · " sig) 'face 'shadow))))
      (append lines (list (propertize sig 'face 'shadow))))))
(defun vikix-office--bullet (label-width)
  "A list item's label: a bullet at the label column's end, so the item's
lines hang together under its first."
  (concat (make-string (max 0 (- label-width 2)) ?\s) "•"))
(defun vikix-office--signed-field (width chars label-width label text by at)
  "A box's row of TEXT, signed BY at AT (`vikix-office--signed-lines')."
  (vikix-office--field-lines width chars label-width label (vikix-office--signed-lines width label-width text by at)))
(defun vikix-office--note (width chars text)
  "A line of a box that says something about the box, in the shade."
  (vikix-office--field width chars 0 "" text 'shadow))
(defun vikix-office--agent-workspace (agent)
  "The live AGENT's workspace, without guessing for a windowless session."
  (let ((workspace (alist-get 'workspace agent)))
    (cond ((not (member workspace '(nil "")))
           (concat "workspace " (vikix-office--one-line workspace)))
          ((member (alist-get 'window agent) '(nil "")) "no desktop window")
          (t "workspace unknown"))))
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

(defun vikix-office--plans-box (width chars owner plans title)
  "The box TITLE of PLANS (the snapshot's plans or plans_done), a plan a
group of rows: its name, project and state (a done plan says when), then
a line a desk saying where that desk's chain stands, and what needs you
in the asks face. A plan not run yet (plan new, the New plan form;
~/.config/vikix/plans) is a draft among them, with its Run once its
EDIT: lines are written. Each plan ends with the acts its state takes:
Run, Pause, Stop, Edit, Log; a done plan has Edit and Log alone. Nothing
is drawn when PLANS is empty."
  (when plans
    (let ((label-width (vikix-office--label-width
                        (apply #'append (mapcar (lambda (p) (mapcar (lambda (d) (vikix-office--one-line (alist-get 'topic d)))
                                                                     (alist-get 'desks p)))
                                                plans))
                        8))
          (first t))
      (vikix-office--box-top width chars title)
      (dolist (p plans)
        (unless first (vikix-office--box-rule width chars))
        (setq first nil)
        (vikix-office--line width chars
                            (lambda ()
                              (insert (propertize (vikix-office--one-line (alist-get 'name p)) 'face 'bold)
                                      " · " (vikix-office--one-line (alist-get 'project p))
                                      " · " (vikix-office--one-line (alist-get 'state p))
                                      (let ((done (alist-get 'done p)))
                                        (if (and (equal (alist-get 'state p) "done") (numberp done) (> done 0))
                                            (concat " " (vikix-office--time done)) ""))
                                      (let ((n (alist-get 'at_once p)))
                                        (if (and n (not (eq n :null))) (format " · %s at once" n) ""))
                                      (if (equal (alist-get 'gate p) "me") " · your yes before a release" ""))))
        (let ((err (alist-get 'error p)))
          (if (not (member err '(nil "")))
              (vikix-office--field width chars label-width "" (vikix-office--one-line err) 'vikix-office-asks)
            (dolist (d (alist-get 'desks p))
              (vikix-office--field width chars label-width (vikix-office--one-line (alist-get 'topic d))
                                   (let ((line (vikix-office--one-line (alist-get 'line d))))
                                     (if (equal line "") "nothing yet" line))
                                   (and (eq (alist-get 'released d) t) 'shadow)))
            (dolist (n (alist-get 'needs p))
              (vikix-office--field width chars label-width "Needs you" (vikix-office--one-line n) 'vikix-office-asks))))
        (let ((file (alist-get 'file p)) (state (alist-get 'state p)) (err (alist-get 'error p))
              (edit (alist-get 'edit p)))
          (vikix-office--line
           width chars
           (lambda ()
             (when (and (member err '(nil "")) (null edit) (member state '("draft" "stopped" "not running")))
               (vikix-office--button (if (equal state "draft") "Run" "Run again")
                                     (lambda () (with-current-buffer owner (vikix-office-plan-act "run" file)))))
             (when (equal state "paused")
               (vikix-office--button "Go on" (lambda () (with-current-buffer owner (vikix-office-plan-act "run" file)))))
             (when (equal state "running")
               (vikix-office--button "Pause" (lambda () (with-current-buffer owner (vikix-office-plan-act "pause" file)))))
             (when (member state '("running" "paused"))
               (vikix-office--button "Stop" (lambda () (with-current-buffer owner (vikix-office-plan-act "stop" file)))))
             (vikix-office--button "Edit" (lambda () (with-current-buffer owner (vikix-office-show-file file))))
             (when (member state '("running" "paused" "stopped" "done"))
               (vikix-office--button "Log" (lambda () (with-current-buffer owner (vikix-office-plan-log file)))))))))
      (vikix-office--box-bottom width chars))))

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
      (when (eq vikix-office--page 'desks)
        (vikix-office--button "New desk…" (lambda () (with-current-buffer owner (vikix-office-new-desk))))
        (vikix-office--button "New plan…" (lambda () (with-current-buffer owner (vikix-office-new-plan))))
        (vikix-office--button "New project…" (lambda () (with-current-buffer owner (vikix-office-new-project)))))
      (vikix-office--button "Guide" (lambda () (with-current-buffer owner (vikix-office-guide))))
      ;; The other pages' buttons, each with its count; on another page the
      ;; first is Back to desks.
      (unless (eq vikix-office--page 'desks)
        (vikix-office--button "Back to desks" (lambda () (with-current-buffer owner (vikix-office-show-page 'desks)))))
      (unless (eq vikix-office--page 'parked)
        (vikix-office--button (format "Parked and closed (%d)" (length (vikix-office--page-rows 'parked)))
                              (lambda () (with-current-buffer owner (vikix-office-show-page 'parked)))))
      (unless (eq vikix-office--page 'archive)
        (vikix-office--button (let ((n (length (alist-get 'plans_done vikix-office--data))))
                                (format "Archive (%d%s)" (length (alist-get 'archive vikix-office--data))
                                        (cond ((= n 0) "") ((= n 1) ", 1 plan") (t (format ", %d plans" n)))))
                              (lambda () (with-current-buffer owner (vikix-office-show-page 'archive)))))
      (when (and (eq vikix-office--page 'archive) rows (eq (alist-get 'live_known vikix-office--data) t)
                 (not (alist-get 'errors vikix-office--data)))
        (vikix-office--button "Purge archive…" (lambda () (with-current-buffer owner (vikix-office-purge-archive)))))
      (insert "\n\n")
      ;; The releases under way (.claude/release's queue, as --queue shows
      ;; it): a box when there are any, the one whose turn it is first; a
      ;; line when a repository has released before and none is under way;
      ;; nothing on a machine that never released. Both boxes are the
      ;; first page's alone.
      (when (eq vikix-office--page 'desks)
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
                 (insert (propertize "No release under way.\n\n" 'face 'shadow)))))
        ;; The plans under way (vikix agents plan run): a box when any has run
        ;; or been written, drawn by vikix-office--plans-box. A plan done is the
        ;; Archive's box, not this one's.
        (vikix-office--plans-box width chars owner (alist-get 'plans vikix-office--data) "Plans"))
      ;; The Archive's plans: the ones done, every desk released (plans_done),
      ;; with Edit and Log alone, above the archived desks.
      (when (eq vikix-office--page 'archive)
        (vikix-office--plans-box width chars owner (alist-get 'plans_done vikix-office--data) "Plans done"))
      (if (null rows)
          (insert (pcase vikix-office--page
                    ('archive (if (alist-get 'plans_done vikix-office--data)
                                  "No archived desk records.\n"
                                "Archive is empty.\n"))
                    ('parked "No parked or closed desks.\n")
                    ;; An empty first page with desks on the parked one says where they are.
                    (_ (if (vikix-office--page-rows 'parked)
                           "Nothing needs you and nothing is at work: the desks are on the Parked and closed page (k).\n"
                         "No desks yet. vikix agents desk PROJECT TOPIC makes one, vikix agents worker TOPIC \"the task\" starts a worker at it.\n"))))
        ;; Closed last: the desks closed today, newest first, nothing to do at them.
        (dolist (group (alist-get vikix-office--page vikix-office--page-groups))
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
                                              " · "
                                              (if (alist-get 'agents r)
                                                  (mapconcat
                                                   (lambda (a)
                                                     (concat (vikix-office--one-line (alist-get 'agent a))
                                                             " · " (vikix-office--agent-workspace a)))
                                                   (alist-get 'agents r) "; ")
                                                (vikix-office--one-line (alist-get 'provider r)))))
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
                                        (let ((rv (alist-get 'reviewing r)))
                                          (if (and rv (alist-get 'provider rv))
                                              (concat " · under review by " (vikix-office--one-line (alist-get 'provider rv))) ""))
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
                        (vikix-office--field width chars label-width "Release" (vikix-office--one-line release))))
                    ;; The plan this desk is a part of (vikix agents plan), and where it has it.
                    (let ((plan (alist-get 'plan r)))
                      (unless (member plan '(nil ""))
                        (vikix-office--field width chars label-width "Plan" (vikix-office--one-line plan)))))
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
                  ;; A desk whose tests run (the Testing group): what runs and since when,
                  ;; and Skip tests on the row itself, so no desk has to be opened for it.
                  (when (and (vikix-office--worker-p r) (vikix-office--positive (alist-get 'testing r)))
                    (vikix-office--field width chars label-width "Tests" (vikix-office--tester-line (alist-get 'tester r)))
                    (vikix-office--line width chars
                                        (lambda ()
                                          (unless (eq (alist-get 'direct (alist-get 'tester r)) t)
                                            (vikix-office--button "Skip tests"
                                                                  (lambda () (with-current-buffer owner
                                                                               (setq vikix-office--selected id)
                                                                               (vikix-office-skip-tests))))))))
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

(defun vikix-office--signed (width chars label-width label entry &optional text)
  "A row of ENTRY's text (or TEXT, when given), with who recorded it and
when at its end; \"Not written\" for no ENTRY."
  (if entry
      (vikix-office--signed-field width chars label-width label
                                  (or text (vikix-office--text (or (alist-get 'text entry) (alist-get 'value entry))))
                                  (alist-get 'by entry) (alist-get 'at entry))
    (vikix-office--field width chars label-width label "Not written")))
(defvar vikix-office--status-words
  '(("working" . "the agent is on the task") ("waiting" . "the agent waits for you")
    ("review" . "the agent asks you to look at its work") ("finished" . "the agent says the task is done")
    ("parked" . "set aside, to be taken up later"))
  "What each status of a handoff means, for the desk page.")
(defun vikix-office--status-text (status)
  "STATUS's value with what it means: \"review · the agent asks you to look at its work\"."
  (let* ((value (vikix-office--text (alist-get 'value status)))
         (words (alist-get value vikix-office--status-words nil nil #'equal)))
    (if words (concat value " · " words) value)))
(defun vikix-office--estimate-text (estimate row)
  "The estimate's row: where the clock stands against it (ROW's line from
Vikix, \"12 min left of 30 min\"), with what the agent assumed after the
comma of its words; the words alone without a clock."
  (let* ((text (vikix-office--text (alist-get 'text estimate)))
         (clock (alist-get 'estimate row))
         (assumed (and (string-match "," text) (string-trim (substring text (match-end 0))))))
    (cond ((member clock '(nil "")) text)
          ((member assumed '(nil "")) clock)
          (t (concat clock ", " assumed)))))

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
            ;; A desk whose worktree is gone: closed today (the Closed group) or
            ;; archived. Nothing acts on it; its record can be forgotten.
            (if (vikix-office--gone-p r)
                (progn
                  (vikix-office--box-top width chars (if (alist-get 'closed r) "Closed" "Archived"))
                  (vikix-office--field width chars 0 ""
                                       (if (alist-get 'closed r)
                                           (let ((closed (alist-get 'closed r)))
                                             (concat "Desk closed"
                                                     (if (member (alist-get 'by closed) '(nil "")) ""
                                                       (concat " by " (vikix-office--text (alist-get 'by closed))))
                                                     " · " (vikix-office--time (alist-get 'at closed))
                                                     ". No action is needed; after a day it is in the Archive."))
                                         "Desk removed. No action is needed."))
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
                    (vikix-office--button "New worker…" (lambda () (with-current-buffer owner (vikix-office-worker))))
                    (unless (equal (alist-get 'status r) "parked")
                      (vikix-office--button "Park" (lambda () (with-current-buffer owner (vikix-office-park)))))
                    (vikix-office--button "Close desk…" (lambda () (with-current-buffer owner (vikix-office-close-desk)))))
                  (when (cl-some (lambda (a) (alist-get 'process_start a)) agents)
                    (vikix-office--button "Close agent…" (lambda () (with-current-buffer owner (vikix-office-close-agent)))))
                  (when (vikix-office--worker-p r)
                    (vikix-office--button (if (alist-get 'paused r) "Go" "Pause") (lambda () (with-current-buffer owner (vikix-office-pause))))
                    ;; While the tests run, Skip tests stands where Test did (the Testing box has the log).
                    (if (vikix-office--positive (alist-get 'testing r))
                        (unless (eq (alist-get 'direct (alist-get 'tester r)) t)
                          (vikix-office--button "Skip tests" (lambda () (with-current-buffer owner (vikix-office-skip-tests)))))
                      (vikix-office--button "Test" (lambda () (with-current-buffer owner (vikix-office-test)))))
                    (when (alist-get 'reviewers vikix-office--data)
                      (vikix-office--button "Review by…" (lambda () (with-current-buffer owner (vikix-office-review)))))
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
              (if (alist-get 'task r) (vikix-office--signed width chars 0 "" (alist-get 'task r))
                (vikix-office--field width chars 0 "" "No task given: the desk stands for a worker later (New worker… gives one)."))
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
              ;; The tester at work (vikix agents test): what runs, since when, the
              ;; release it waits for, and the log's tail, the tests ended so far;
              ;; Skip tests ends it and marks the check skipped, Test log shows the whole run.
              (when (vikix-office--positive (alist-get 'testing r))
                (let ((tester (alist-get 'tester r)))
                  (vikix-office--box-top width chars "Testing")
                  (vikix-office--field width chars 0 "" (vikix-office--tester-line tester))
                  (dolist (run (alist-get 'progress tester))
                    (dolist (test (alist-get 'tests run))
                      (vikix-office--field width chars 0 "" (alist-get 'line test)
                                           (if (eq (alist-get 'stalled test) t) 'warning 'shadow))))
                  (let ((waiting (alist-get 'waiting tester)))
                    (unless (member waiting '(nil ""))
                      (vikix-office--field width chars 0 ""
                                           (concat "Waiting for the release of " (vikix-office--one-line waiting)
                                                   " to finish its tests first; the run starts after")
                                           'shadow)))
                  (when (eq (alist-get 'direct tester) t)
                    (vikix-office--field width chars 0 "" "Started by the worker; output and stopping belong to its terminal" 'shadow))
                  (let ((tail (alist-get 'tail tester)))
                    (if (null tail)
                        (unless (or (alist-get 'progress tester) (and (alist-get 'waiting tester) (not (member (alist-get 'waiting tester) '(nil "")))))
                          (vikix-office--field width chars 0 "" "No test has ended yet" 'shadow))
                      (vikix-office--note width chars "The last lines of the run: each test's output comes whole when it ends.")
                      (dolist (line tail)
                        (vikix-office--field width chars 0 "" (vikix-office--one-line line) 'shadow))))
                  (vikix-office--line width chars
                                      (lambda ()
                                        (unless (eq (alist-get 'direct (alist-get 'tester r)) t)
                          (vikix-office--button "Skip tests" (lambda () (with-current-buffer owner (vikix-office-skip-tests)))))
                                        (unless (eq (alist-get 'direct tester) t)
                                          (vikix-office--button "Test log" (lambda () (with-current-buffer owner (vikix-office-test-log)))))))
                  (vikix-office--box-bottom width chars)))
              (vikix-office--box-top width chars "What the agent says")
              (vikix-office--note width chars "The agent's own account of its work, which Vikix doesn't check. A status of review asks you to look; nothing is merged by it.")
              (let ((handoff (alist-get 'handoff r)) (label-width 12))
                ;; Where the work stands, in the agent's words: the status with what it
                ;; means, the estimate against the clock, the summary and the next step;
                ;; each row signed at its end. Nothing of them yet is one line, not three.
                (if (not (or (alist-get 'status handoff) (alist-get 'summary handoff) (alist-get 'next handoff)))
                    (vikix-office--field width chars 0 "" "No handoff yet: the agent hasn't written where its work stands.")
                  (vikix-office--signed width chars label-width "Status" (alist-get 'status handoff)
                                        (vikix-office--status-text (alist-get 'status handoff)))
                  (let ((estimate (alist-get 'estimate handoff)))
                    (when estimate
                      (vikix-office--signed width chars label-width "Estimate" estimate (vikix-office--estimate-text estimate r))))
                  (vikix-office--signed width chars label-width "Summary" (alist-get 'summary handoff))
                  (vikix-office--signed width chars label-width "Next" (alist-get 'next handoff)))
                ;; The hand-in: the criteria with their ticks, the decisions, the
                ;; defects and the review findings, each item signed.
                (let ((acceptance (alist-get 'acceptance handoff)))
                  (when acceptance
                    (let* ((items (alist-get 'items acceptance))
                           (done (cl-count-if (lambda (i) (eq (alist-get 'done i) t)) items)))
                      (vikix-office--signed-field width chars label-width "Acceptance"
                                                  (format "%d of %d done, as the agent ticks them; the criteria are yours"
                                                          done (length items))
                                                  (alist-get 'by acceptance) (alist-get 'at acceptance))
                      (dolist (i items)
                        (let ((text (concat (if (eq (alist-get 'done i) t) "[x] " "[ ] ")
                                            (vikix-office--one-line (alist-get 'text i)))))
                          (if (eq (alist-get 'done i) t)
                              (vikix-office--signed-field width chars label-width (vikix-office--bullet label-width) text
                                                          (alist-get 'done_by i) (alist-get 'done_at i))
                            (vikix-office--field width chars label-width (vikix-office--bullet label-width) text)))))))
                ;; Each list under a line saying what it is and how it stands, its items signed.
                (dolist (list '((decisions "Decided" nil "%d choice%s made by the agent, which the next worker keeps to")
                                (defects "Defects" "closed" "%d open of %d the agent knows of")
                                (review "Review" "addressed" "%d open of %d finding%s from a review")))
                  (let ((items (alist-get (car list) handoff)))
                    (when items
                      (vikix-office--field width chars label-width (nth 1 list)
                                           (if (nth 2 list)
                                               (format (nth 3 list)
                                                       (cl-count-if (lambda (i) (eq (alist-get 'open i) t)) items) (length items)
                                                       (if (= (length items) 1) "" "s"))
                                             (format (nth 3 list) (length items) (if (= (length items) 1) "" "s"))))
                      (dolist (i items)
                        (vikix-office--signed-field width chars label-width (vikix-office--bullet label-width)
                                                    (concat (cond ((null (nth 2 list)) "")
                                                                  ((eq (alist-get 'open i) t) "open: ")
                                                                  (t (concat (nth 2 list) ": ")))
                                                            (let ((where (alist-get 'where i)))
                                                              (if (member where '(nil "")) "" (concat (vikix-office--text where) " ")))
                                                            (vikix-office--one-line (alist-get 'text i)))
                                                    (alist-get 'by i) (alist-get 'at i)))))))
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
                ;; What the branch changed against the base and the commits past it,
                ;; read from git into the handoff at its last write (signed vikix).
                (let* ((handoff (alist-get 'handoff r))
                       (changed (alist-get 'changed handoff)) (commits (alist-get 'commits handoff)))
                  (when changed
                    (let* ((files (alist-get 'files changed))
                           (more (or (alist-get 'more changed) 0))
                           (base (alist-get 'base changed)))
                      (vikix-office--field width chars label-width "Changed"
                                           (format "%d file%s%s · %s" (+ (length files) more) (if (= (+ (length files) more) 1) "" "s")
                                                   (if (member base '(nil "")) " (uncommitted only: no base)"
                                                     (concat " against " (substring base 0 (min 7 (length base)))))
                                                   (vikix-office--time (alist-get 'at changed))))
                      (dolist (f (seq-take files 20))
                        (vikix-office--field width chars label-width ""
                                             (format "+%s -%s %s%s" (or (alist-get 'add f) 0) (or (alist-get 'del f) 0)
                                                     (vikix-office--text (alist-get 'path f))
                                                     (cond ((eq (alist-get 'new f) t) " (new, uncommitted)")
                                                           ((eq (alist-get 'uncommitted f) t) " (uncommitted)")
                                                           (t "")))
                                             'shadow))
                      (when (> (+ (length files) more) 20)
                        (vikix-office--field width chars label-width "" (format "… and %d more" (- (+ (length files) more) 20)) 'shadow))))
                  (when (and commits (alist-get 'list commits))
                    (let* ((list (alist-get 'list commits)) (more (or (alist-get 'more commits) 0))
                           (base (vikix-office--text (alist-get 'base commits))))
                      (vikix-office--field width chars label-width "Commits"
                                           (format "%d past %s" (+ (length list) more) (substring base 0 (min 7 (length base)))))
                      (dolist (c (last list 10))
                        (vikix-office--field width chars label-width ""
                                             (concat (vikix-office--text (alist-get 'hash c)) " " (vikix-office--one-line (alist-get 'subject c)))
                                             'shadow)))))
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
                                       (cond ((eq (alist-get 'skipped c) t) (propertize "skipped" 'face 'warning))
                                             ((eq (alist-get 'ok c) t) (propertize "passed" 'face 'success))
                                             (t (propertize "failed" 'face 'error)))
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
                                              (format "%s · %s%s" (vikix-office--agent-workspace a)
                                                      (vikix-office--one-line (alist-get 'doing a))
                                                      ;; Its window's name on the desktop: the desk and the provider.
                                                      (if (member (alist-get 'desk_title a) '(nil ""))
                                                          "" (concat " · " (vikix-office--one-line (alist-get 'desk_title a))))
                                                      ;; Shells it left sleeping in a loop (vikix agents tidy).
                                                      (let ((idle (alist-get 'idle_shells a)))
                                                        (if (and idle (> (length idle) 0))
                                                            (format " · %d shell%s asleep in a loop (vikix agents tidy)"
                                                                    (length idle) (if (= (length idle) 1) "" "s"))
                                                          "")))
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
  "The desk pane, selected: back in its window when a file or the guide took it."
  (interactive)
  (vikix-office--track)
  (when-let* ((window (vikix-office--pane-window)))
    (unless (eq (window-buffer window) vikix-office--detail) (set-window-buffer window vikix-office--detail))
    (select-window window)))
(defun vikix-office-next (direction)
  (let* ((rows (vikix-office--rows))
         (ids (mapcar (lambda (r) (alist-get 'id r)) rows))
         (index (or (cl-position vikix-office--selected ids :test #'equal) 0))
         (id (nth (max 0 (min (1- (length ids)) (+ index direction))) ids)))
    (when id
      (goto-char (vikix-office--position id))
      (vikix-office--track))))

(defun vikix-office--act (args &optional then)
  "Run the backend with ARGS, its answer in the header line, where it stays
over the refreshes that follow; THEN, when given, after a success."
  (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
  (setq vikix-office--said nil)
  (vikix-office--request args 'vikix-office--action
                         (lambda (output error)
                           (setq vikix-office--said (and (not error) (string-trim output)))
                           (when (equal vikix-office--said "") (setq vikix-office--said nil))
                           (vikix-office--notice (or error vikix-office--said "Done"))
                           (when (and then (not error)) (funcall then)))))

(defun vikix-office-show-page (page)
  "Show PAGE (`desks', `parked' or `archive'), its first row selected."
  (with-current-buffer (vikix-office--owner-buffer)
    (setq vikix-office--page page
          vikix-office--selected nil)
    (vikix-office--render)))
(defun vikix-office--page-shown ()
  "The page the Office shows, asked of the Office's buffer (the desk pane has the same keys)."
  (buffer-local-value 'vikix-office--page (vikix-office--owner-buffer)))
(defun vikix-office-toggle-archive ()
  "The Archive, or back to the desks from any other page."
  (interactive)
  (vikix-office-show-page (if (eq (vikix-office--page-shown) 'archive) 'desks 'archive)))
(defun vikix-office-toggle-parked ()
  "The Parked and closed page, or back to the desks from any other page."
  (interactive)
  (vikix-office-show-page (if (eq (vikix-office--page-shown) 'parked) 'desks 'parked)))

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
(defun vikix-office--gone-p (r)
  "A desk whose worktree is gone: archived, or closed today (the Closed group)."
  (and r (or (eq (alist-get 'archived r) t) (alist-get 'closed r)) t))

(defun vikix-office-forget ()
  "Remove the selected removed desk's record (archived, or closed today).
Files, branches and saved conversations stay."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--row)) (id (alist-get 'id (alist-get 'desk r))))
      (unless r (user-error "Select a desk first"))
      (unless (vikix-office--gone-p r) (user-error "Only a removed desk's record can be forgotten: close a desk that stands"))
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
(defun vikix-office-park ()
  "Keep the selected desk aside, to be started later: its status parked
\(vikix agents park), so it is listed under Parked however its agent left it."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (when (alist-get 'agents r) (user-error "An agent is at this desk: it counts as working until it goes"))
      (vikix-office--act (list "office" "--park" (alist-get 'id r)) #'vikix-office-refresh))))

(defun vikix-office-pause ()
  "Pause the selected desk's agent at its next tool call, or let a paused one go."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (vikix-office--act (list "office" "--pause" (alist-get 'id r)) #'vikix-office-refresh))))
(defun vikix-office-test ()
  "Run the selected desk's tests; the result goes into its handoff and its agent's inbox."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (vikix-office--act (list "office" "--test" (alist-get 'id r)) #'vikix-office-refresh))))
(defun vikix-office-skip-tests ()
  "End the selected desk's tests, running, without waiting for them: the
check is marked skipped (a plan's chain goes on; the release runs its own)."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((r (vikix-office--worker-row)))
      (unless (vikix-office--positive (alist-get 'testing r)) (user-error "No tests run at this desk now"))
      (when (eq (alist-get 'direct (alist-get 'tester r)) t)
        (user-error "The worker started this run directly; its terminal owns stopping it"))
      (vikix-office--act (list "office" "--skip" (alist-get 'id r)) #'vikix-office-refresh))))
(defun vikix-office-test-log ()
  "The selected desk's test run, as it is so far, in the desk pane (read-only,
following the file as it grows); RET on a desk brings the pane back."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--worker-row))
           (log (alist-get 'log (alist-get 'tester r))))
      (when (member log '(nil "")) (user-error "No tests run at this desk now"))
      (unless (file-readable-p log) (user-error "The run has written nothing yet"))
      (let ((buffer (find-file-noselect log)))
        (with-current-buffer buffer
          (read-only-mode 1)
          (auto-revert-tail-mode 1))
        (vikix-office--show-buffer buffer)
        (goto-char (point-max))
        (message "The run so far; RET on a desk brings its pane back")))))
(defun vikix-office-review ()
  "Have another provider review the selected desk's last commit, read-only;
its findings go into the handoff and the agent's inbox."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--worker-row))
           (offered (mapcar #'identity (alist-get 'reviewers vikix-office--data))))
      (unless offered (user-error "No reviewer is installed here (codex or claude)"))
      (let ((who (if (cdr offered)
                     (completing-read (format "Review %s by: " (vikix-office--text (alist-get 'title r))) offered nil t)
                   (car offered))))
        (when (string-empty-p who) (user-error "Review by which? %s" (string-join offered ", ")))
        (vikix-office--act (list "office" "--review" (alist-get 'id r) who) #'vikix-office-refresh)))))
(defun vikix-office-tell ()
  "Leave the selected desk's agent a note, delivered at its next tool call."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--worker-row))
           (text (string-trim (read-string (format "Note for the agent at %s: " (vikix-office--text (alist-get 'title r)))))))
      (when (string-empty-p text) (user-error "A note needs words"))
      (vikix-office--act (list "office" "--tell" (alist-get 'id r) text) #'vikix-office-refresh))))

(defun vikix-office-close-desk ()
  "Close the selected desk: its worktree removed, its branch deleted when its work is in.
Offered for a desk with nobody at it; files uncommitted there are thrown
away only on a second, separate yes."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let* ((r (vikix-office--worker-row)) (folder (alist-get 'worktree (alist-get 'desk r)))
           (dirty (alist-get 'dirty (alist-get 'now r))) force)
      (when (alist-get 'agents r) (user-error "An agent is at this desk: Close agent first, or let it finish"))
      (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
      (when (and (numberp dirty) (> dirty 0))
        (unless (yes-or-no-p (format "%d file%s uncommitted in %s. Throw them away and close the desk? "
                                     dirty (if (= dirty 1) "" "s") folder))
          (user-error "Not closed: commit there first, or say yes to throw the files away"))
        (setq force t))
      (unless (yes-or-no-p (format "Close the desk %s? Its worktree is removed; its branch is deleted when its work is in%s. "
                                   folder (if force ", and thrown away otherwise" " and kept otherwise")))
        (user-error "Not closed"))
      (vikix-office--act (append (list "office" "--close-desk" folder) (and force '("--force"))) #'vikix-office-refresh))))

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
;; agent goes with it), no tests by themselves when it hands in, and a row
;; of three for the mode (how free a Codex worker is), the house default
;; shown as picked and sent only when another is chosen. The form is
;; widget.el's, drawn in the desk pane's window, so the terminal has it as
;; the frame does; what it offers (the projects, the agents) comes from the
;; backend's office --form, asked when the form opens, never kept.
(defun vikix-office--plan-file-p (file)
  "FILE is a plan's file the snapshot names, never a word of anyone's."
  (and (stringp file) (not (string-empty-p file))
       (cl-some (lambda (p) (equal (alist-get 'file p) file)) (alist-get 'plans vikix-office--data))))
(defun vikix-office-plan-act (verb file)
  "VERB (run, pause, stop) on the plan FILE, through vikix agents plan; the
answer in the header line, the Office refreshed. run starts a draft, or
carries a paused or stopped plan on, as the command does."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (member verb '("run" "pause" "stop")) (user-error "A plan is run, paused or stopped"))
    (unless (vikix-office--plan-file-p file) (user-error "Not a plan the Office knows"))
    (vikix-office--act (list "plan" verb file) #'vikix-office-refresh)))
(defun vikix-office-plan-log (file)
  "What the plan FILE's runner did, in the desk pane's window."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (vikix-office--plan-file-p file) (user-error "Not a plan the Office knows"))
    (let ((owner (current-buffer)))
      (vikix-office--request
       (list "plan" "log" file) 'vikix-office--action
       (lambda (output error)
         (if error (vikix-office--notice error)
           (let ((buffer (get-buffer-create "*Office plan log*")))
             (with-current-buffer buffer
               (let ((inhibit-read-only t)) (erase-buffer) (insert output))
               (special-mode)
               (goto-char (point-max)))
             (with-current-buffer owner (vikix-office--show-buffer buffer)))))))))
(defun vikix-office--pane-window ()
  "The desk pane's window in the Office's frame: the one showing it, else the
frame's other window (a plan's file, a log or the guide was shown there),
or nil."
  (when (buffer-live-p vikix-office--detail)
    (or (get-buffer-window vikix-office--detail vikix-office--frame)
        (let ((owner (current-buffer)))
          (cl-find-if (lambda (w) (not (eq (window-buffer w) owner)))
                      (window-list vikix-office--frame 'no-minibuf))))))
(defun vikix-office--show-buffer (buffer)
  "BUFFER in the desk pane's window (the pane comes back with RET on a desk), else another window."
  (let ((window (vikix-office--pane-window)))
    (if (window-live-p window)
        (progn (set-window-buffer window buffer) (select-window window))
      (pop-to-buffer buffer))))
(defun vikix-office-show-file (file)
  "Open the plan FILE to edit, in the desk pane's window: its EDIT: lines
are yours to write; saved, the Plans box offers its Run."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (unless (vikix-office--plan-file-p file) (user-error "Not a plan the Office knows"))
    (vikix-office--show-buffer (find-file-noselect file))
    (message "The plan's file: write its EDIT: lines in your words, save (C-x C-s); Run is in the Plans box")))
(defun vikix-office--guide-file ()
  "The Vikix manual as 40-config installs it (vikix update core writes it)."
  (expand-file-name "info/vikix.info" (or (getenv "XDG_DATA_HOME") "~/.local/share")))
(defun vikix-office-guide (&optional node)
  "The Office's chapter of the Vikix manual (info vikix), in the desk pane's
window; NODE names another node of it (\"A plan\" for the plans)."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (let ((file (vikix-office--guide-file)) (window (vikix-office--pane-window)))
      (unless (file-readable-p file)
        (user-error "The Vikix manual isn't installed here (%s): vikix update core writes it" (abbreviate-file-name file)))
      (require 'info)
      (if (window-live-p window)
          (with-selected-window window (info (format "(%s) %s" file (or node "The Office"))))
        (info (format "(%s) %s" file (or node "The Office")))))))

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
(defun vikix-office-new-plan ()
  "Write a plan from a template, for a project: a form. The file opens here
for its tasks' words, and the Plans box runs it."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (vikix-office--form-open 'plan)))
(defun vikix-office-new-project ()
  "Make a project: a folder under ~/src with a log, a repository, or one on GitHub pushed: a form."
  (interactive)
  (with-current-buffer (vikix-office--owner-buffer)
    (vikix-office--form-open 'project)))
(defun vikix-office--form-open (desk)
  "Ask the backend what the form offers, then draw it for DESK, a row, a new desk with nil, a plan with `plan', a project with `project'."
  (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
  (let ((owner (current-buffer)))
    (vikix-office--notice (concat (pcase desk ('plan "New plan") ('project "New project") ('nil "New desk") (_ "New worker"))
                                  (pcase desk
                                    ('plan ": asking which projects and templates there are…")
                                    ('project ": asking where a project goes, and your GitHub account…")
                                    (_ ": asking which projects and agents there are…"))))
    (vikix-office--request
     '("office" "--form") 'vikix-office--action
     (lambda (output error)
       (if error (vikix-office--notice error)
         (condition-case err
             (vikix-office--form-draw
              owner desk
              (json-parse-string output :object-type 'alist :array-type 'list :null-object nil :false-object :false))
           (error (vikix-office--notice (error-message-string err)))))))))
;; Bound at every load, as the Office's map is (see vikix-office--bind-keys).
(defvar vikix-office-form-map (make-sparse-keymap))
(set-keymap-parent vikix-office-form-map widget-keymap)
(define-key vikix-office-form-map (kbd "C-c C-c") #'vikix-office-form-submit)
(define-key vikix-office-form-map (kbd "C-c C-k") #'vikix-office-form-cancel)
(defun vikix-office--form-draw (owner desk offer)
  "Draw the form for DESK (nil: a new desk; `plan': a plan; `project': a project) with what the backend OFFERed, in OWNER's desk pane."
  (pcase desk
    ('plan (vikix-office--form-draw-plan owner offer))
    ('project (vikix-office--form-draw-project owner offer))
    (_ (vikix-office--form-draw-desk owner desk offer))))
(defun vikix-office--form-place (owner buffer)
  "Put the form BUFFER in OWNER's desk pane window, else another; that window, for the way back."
  (let ((window (with-current-buffer owner (vikix-office--pane-window))))
    (if (window-live-p window)
        (progn (set-window-buffer window buffer) (select-window window))
      (pop-to-buffer buffer))
    window))
(defun vikix-office--form-plan-task-from (task)
  "A template's TASK (the backend's, as read_plan reads it) as the form's
values: a line of the template beginning EDIT: is the field's hint, the
field itself empty, since those words are yours to write; any other words
are the field's, to edit."
  (let* ((text (or (alist-get 'text task) ""))
         (release (or (alist-get 'release task) ""))
         (edit (lambda (s) (and (string-prefix-p "EDIT:" s) (string-trim (substring s 5))))))
    (list (cons 'name (or (alist-get 'name task) ""))
          (cons 'desk (or (alist-get 'desk task) ""))
          (cons 'after (mapconcat #'identity (alist-get 'after task) ", "))
          (cons 'task (if (funcall edit text) "" text))
          (cons 'hint (funcall edit text))
          (cons 'release (if (funcall edit release) "" release))
          (cons 'release-hint (funcall edit release))
          (cons 'acceptance (mapconcat #'identity (alist-get 'acceptance task) "\n"))
          (cons 'agent (or (alist-get 'agent task) ""))
          (cons 'local (eq (alist-get 'local task) t))
          (cons 'push (eq (alist-get 'push task) t))
          (cons 'notests (eq (alist-get 'no_tests task) t))
          (cons 'mode (or (alist-get 'mode task) "")))))
(defun vikix-office--form-plan-template-tasks (offer template)
  "The tasks of TEMPLATE among what the backend OFFERed, as the form's values."
  (let ((tp (cl-find template (alist-get 'templates offer) :key (lambda (x) (alist-get 'name x)) :test #'equal)))
    (mapcar #'vikix-office--form-plan-task-from (alist-get 'tasks tp))))
(defun vikix-office--form-plan-empty-task ()
  "A task added by hand: nothing filled in."
  (vikix-office--form-plan-task-from '((name . "") (desk . "") (text . "EDIT: the worker's job, in your words") (release . ""))))
(defun vikix-office--form-note (width text &optional indent)
  "TEXT in the shade under a field, INDENT columns in (eight), its lines
broken to fit the box (WIDTH inside), a newline in it a new line."
  (let ((indent (or indent 8)))
    (dolist (part (split-string text "\n"))
      (dolist (line (vikix-office--fill part (- width indent 2)))
        (widget-insert (propertize (concat (make-string indent ?\s) line "\n") 'face 'shadow))))))
(defun vikix-office--form-hint (hint)
  "A template's HINT for a field, its example (after \"E.g.\") on a line of its own."
  (replace-regexp-in-string " E\\.g\\. " "\n        e.g. " hint))
(defun vikix-office--form-plan-state ()
  "The New plan form's values as they stand, for a redraw to put back:
a plist of the fields, and :tasks the tasks' values, a list of alists."
  (let ((tasks (plist-get vikix-office--form :tasks)))
    (list :template (vikix-office--form-value 'template)
          :project (vikix-office--form-value 'project)
          :name (vikix-office--form-value 'name)
          :at-once (vikix-office--form-value 'at-once)
          :gate (vikix-office--form-value 'gate)
          :tasks (mapcar (lambda (tw)
                           (mapcar (lambda (cell)
                                     (cons (car cell) (if (widgetp (cdr cell)) (widget-value (cdr cell)) (cdr cell))))
                                   tw))
                         tasks))))
(defun vikix-office--form-plan-redraw (state focus)
  "Draw this form again with STATE's values; point goes to FOCUS (a task's
index and a field's name, as (1 . task)) when it is there."
  (vikix-office--form-draw-plan (plist-get vikix-office--form :owner) (plist-get vikix-office--form :offer)
                                state (current-buffer) focus))
(defun vikix-office--form-draw-plan (owner offer &optional state buffer focus)
  "The New plan form: a template, the project, the plan's name, the two
settings every template has, and the template's tasks as fields, each with
the words the template asks for as its hint; Add a task and Remove reshape
it. What the backend OFFERed names them. STATE, the form's values as
`vikix-office--form-plan-state' gives them, is what a redraw (a template
picked, a task added or removed) puts back, into BUFFER, the form's; else a
new buffer is made and placed. FOCUS names where point goes on a redraw."
  (let* ((fresh (null buffer))
         (buffer (or buffer (generate-new-buffer "*Office new plan*")))
         (templates (alist-get 'templates offer))
         (projects (cl-remove-if-not (lambda (p) (eq (alist-get 'repo p) t)) (alist-get 'projects offer)))
         (agents (alist-get 'agents offer))
         (folder (or (alist-get 'plans_folder offer) "~/.config/vikix/plans"))
         (tasks (plist-get state :tasks))
         (window (plist-get vikix-office--form :window))
         ;; The width of the window the form is in, or will be placed in
         ;; (the owner's desk pane), as the Office's boxes measure it.
         (geometry (vikix-office--geometry
                    (let ((w (or (and (not fresh) (get-buffer-window buffer t))
                                 (with-current-buffer owner (vikix-office--pane-window)))))
                      (and (window-live-p w) w))))
         (width (car geometry)) (chars (cdr geometry))
         widgets task-widgets at)
    (with-current-buffer buffer
      (kill-all-local-variables)
      (let ((inhibit-read-only t)) (erase-buffer))
      (remove-overlays)
      (setq vikix-office--live (cons width (propertize (string (aref chars 5)) 'face 'shadow)))
      (face-remap-add-relative 'widget-field '(:extend nil))
      (widget-insert (propertize "New plan" 'face '(:inherit variable-pitch :height 1.3 :weight bold)) "\n")
      (widget-insert "A plan is tasks in order, each one worker's job at a desk, run for you (vikix agents plan). "
                     "Pick a template and its tasks come up below, each with what it asks you to write; "
                     "Write plan writes the file, with your words in, and the Plans box has its Run.\n\n")
      ;; The plan's own settings in a box like the tasks' (Vid, 2026-10-12), a
      ;; rule between: the template, the project, the name, how it runs.
      (vikix-office--live-box width chars "Plan" (lambda ()
      ;; A choice that makes something starts unpicked (Vid, 2026-10-10).
      (push (cons 'template
                  (apply #'widget-create 'menu-choice :tag "Template" :value (or (plist-get state :template) "")
                         :format "  %t: %[%v%]\n" :button-prefix "[" :button-suffix "]"
                         :help-echo "The plan's shape (vikix agents plan templates): a click or RET opens the list"
                         ;; Picked, the form is drawn again with that template's tasks; the rest stays as typed.
                         :notify (lambda (w &rest _)
                                   (let ((state (vikix-office--form-plan-state)))
                                     (vikix-office--form-plan-redraw
                                      (plist-put state :tasks (vikix-office--form-plan-template-tasks
                                                               (plist-get vikix-office--form :offer) (widget-value w)))
                                      '(0 . task))))
                         '(item :tag "pick one" :format "%t" :value "")
                         (mapcar (lambda (tp)
                                   (list 'item :tag (concat (alist-get 'name tp) "  " (or (alist-get 'about tp) "")
                                                            (if (eq (alist-get 'yours tp) t) "  (yours)" ""))
                                         :format "%t" :value (alist-get 'name tp)))
                                 templates)))
            widgets)
      (vikix-office--form-note width (concat "Vikix's, and your own from " (abbreviate-file-name folder) "/templates/") 12)
      (vikix-office--live-rule width chars)
      (push (cons 'project
                  (apply #'widget-create 'menu-choice :tag "Project" :value (or (plist-get state :project) "")
                         :format "  %t:  %[%v%]\n" :button-prefix "[" :button-suffix "]"
                         :help-echo "The project the plan is for: a repository, since its desks are worktrees"
                         '(item :tag "pick one" :format "%t" :value "")
                         (mapcar (lambda (p)
                                   (list 'item :tag (concat (alist-get 'name p) "  " (or (alist-get 'short p) ""))
                                         :format "%t" :value (alist-get 'name p)))
                                 projects)))
            widgets)
      (vikix-office--form-note width "a repository: a plan's desks are worktrees of it" 12)
      (vikix-office--live-rule width chars)
      (push (cons 'name (widget-create 'editable-field :size 30 :format "  Name:     %v\n"
                                       :help-echo "A word for the plan: its file's name, and its desks'"
                                       (or (plist-get state :name) "")))
            widgets)
      (vikix-office--form-note width (concat "a word (letters, digits, dashes): " (abbreviate-file-name folder)
                                             "/NAME.toml; \"topic\" in a desk's name becomes it")
                               12)
      (vikix-office--live-rule width chars)
      (push (cons 'at-once (widget-create 'editable-field :size 4 :format "  At once:  %v  workers running together, at most (empty: the template's)\n"
                                          :help-echo "How many workers run together, at most" (or (plist-get state :at-once) "")))
            widgets)
      (push (cons 'gate
                  (widget-create 'menu-choice :tag "Gate" :value (or (plist-get state :gate) "")
                                 :format "  %t:     %[%v%]\n" :button-prefix "[" :button-suffix "]"
                                 :help-echo "Whether a desk's release waits for your yes"
                                 '(item :tag "the template's" :format "%t" :value "")
                                 '(item :tag "me: a desk's release waits for your yes" :format "%t" :value "me")
                                 '(item :tag "none: a desk is released as its chain ends" :format "%t" :value "none")))
            widgets)))
      (widget-insert "\n")
      ;; The tasks: the template's, each a worker's job, as fields; a line the
      ;; template asks you to write (EDIT:) is a hint under an empty field.
      ;; Each task is a box of its own (2026-10-11: as prose, the tasks ran
      ;; into one another), closed on the right by vikix-office--live-sides
      ;; after each change since its fields grow, with a rule between its
      ;; parts: who and where, the words, the release, the acceptance, the
      ;; agent and its switches. A field's grey stops at the side: the face
      ;; doesn't extend past the line's end here.
      (when tasks
        (widget-insert (propertize "Tasks" 'face 'bold)
                       (propertize "  the template's, in order; tasks at one desk are a chain, at different desks they run side by side\n" 'face 'shadow))
        (let ((i 0))
          (dolist (task tasks)
            (let ((n i) tw)
              (widget-insert "\n")
              (vikix-office--live-box width chars (format "Task %d" (1+ n)) (lambda ()
              (push (cons 'name (widget-create 'editable-field :size 16 :format "  Name:  %v"
                                               :help-echo "A word: what after names" (alist-get 'name task)))
                    tw)
              (push (cons 'desk (widget-create 'editable-field :size 16 :format "   Desk: %v"
                                               :help-echo "The desk it works at: the worktree's ending and the branch; topic becomes the plan's name"
                                               (alist-get 'desk task)))
                    tw)
              (push (cons 'after (widget-create 'editable-field :size 20 :format "   After: %v\n"
                                                :help-echo "The tasks it waits for, by name, with commas" (alist-get 'after task)))
                    tw)
              (vikix-office--live-rule width chars)
              ;; A text field ends in a newline of its own: no "\n" after %v.
              (push (cons 'task (widget-create 'text :format "  Task:\n%v"
                                               :help-echo "The worker's job, in your words: its first prompt" (alist-get 'task task)))
                    tw)
              (when (equal (cons n 'task) focus) (setq at (cdr (car tw))))
              (when (alist-get 'hint task)
                (vikix-office--form-note width (concat (vikix-office--form-hint (alist-get 'hint task))
                                                       "\n(left empty, that line stays in the file as EDIT: for you to write there)")))
              (vikix-office--live-rule width chars)
              (push (cons 'release (widget-create 'editable-field :size 60 :format "  Release: %v\n"
                                                  :help-echo "One line, what the release brings: what its commit and tag say after the version"
                                                  (alist-get 'release task)))
                    tw)
              (vikix-office--form-note width "one line, what the release brings: the release's commit says it after the version (Vikix 0.72.44: that line); for the last task at a desk")
              (when (alist-get 'release-hint task)
                (vikix-office--form-note width (concat (vikix-office--form-hint (alist-get 'release-hint task)) " (left empty, it stays as EDIT:)")))
              (vikix-office--live-rule width chars)
              (push (cons 'acceptance (widget-create 'text :format "  Acceptance, a line each (what the work is judged by):\n%v"
                                                     :help-echo "The criteria the work is judged by, a line each; empty for none"
                                                     (alist-get 'acceptance task)))
                    tw)
              (vikix-office--live-rule width chars)
              (push (cons 'agent
                          (apply #'widget-create 'menu-choice :tag "  Agent" :value (alist-get 'agent task)
                                 :format "%t: %[%v%]" :button-prefix "[" :button-suffix "]"
                                 :help-echo "Which agent works the task: yours, or another"
                                 (list 'item :tag (concat "yours (" (or (alist-get 'default offer) "claude") ")") :format "%t" :value "")
                                 (mapcar (lambda (a) (list 'item :tag (alist-get 'name a) :format "%t" :value (alist-get 'name a))) agents)))
                    tw)
              (widget-insert "   ")
              (push (cons 'local (widget-create 'checkbox (alist-get 'local task))) tw)
              (widget-insert " local model  ")
              (push (cons 'push (widget-create 'checkbox (alist-get 'push task))) tw)
              (widget-insert " may push  ")
              (push (cons 'notests (widget-create 'checkbox (alist-get 'notests task))) tw)
              (widget-insert " no tests   ")
              (push (cons 'mode
                          (apply #'widget-create 'menu-choice :tag "Mode" :value (alist-get 'mode task)
                                 :format "%t: %[%v%]\n" :button-prefix "[" :button-suffix "]"
                                 :help-echo "How free the worker is (Codex's): the house default, supervised, autonomous or unrestricted"
                                 '(item :tag "the house default" :format "%t" :value "")
                                 (mapcar (lambda (m) (list 'item :tag m :format "%t" :value m))
                                         (or (alist-get 'modes offer) '("supervised" "autonomous" "unrestricted")))))
                    tw)
              (push (cons 'hint (alist-get 'hint task)) tw)
              (push (cons 'release-hint (alist-get 'release-hint task)) tw)
              (widget-insert "  ")
              (widget-create 'push-button
                             :notify (lambda (&rest _)
                                       (let ((state (vikix-office--form-plan-state)))
                                         (vikix-office--form-plan-redraw
                                          (plist-put state :tasks (append (seq-take (plist-get state :tasks) n)
                                                                          (seq-drop (plist-get state :tasks) (1+ n))))
                                          '(-1 . none))))
                             "Remove this task")
              (widget-insert "\n")))
              (push (nreverse tw) task-widgets)
              (setq i (1+ i)))))
        (widget-insert "\n")
        (widget-create 'push-button
                       :notify (lambda (&rest _)
                                 (let* ((state (vikix-office--form-plan-state))
                                        (n (length (plist-get state :tasks))))
                                   (vikix-office--form-plan-redraw
                                    (plist-put state :tasks (append (plist-get state :tasks) (list (vikix-office--form-plan-empty-task))))
                                    (cons n 'name))))
                       "Add a task")
        (widget-insert "\n"))
      (widget-insert "\n")
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-submit)) "Write plan")
      (widget-insert "  ")
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-cancel)) "Cancel")
      (widget-insert "\n\n"
                     (propertize "A click or RET on a [choice] opens its list; TAB moves between the fields; C-c C-c is the button, C-c C-k cancels. Nothing runs until you press Run in the Plans box."
                                 'face 'shadow))
      (use-local-map vikix-office-form-map)
      (widget-setup)
      (vikix-office--live-sides)
      (add-hook 'after-change-functions #'vikix-office--live-sides nil t)
      (add-hook 'post-command-hook #'vikix-office--live-sides nil t)
      (setq vikix-office--form (list :owner owner :desk 'plan :offer offer :widgets widgets
                                     :tasks (nreverse task-widgets) :window window))
      (when (and (null at) focus (>= (car focus) 0))
        (setq at (alist-get (cdr focus) (nth (car focus) (plist-get vikix-office--form :tasks)))))
      (if (widgetp at)
          (goto-char (widget-field-start at))
        (goto-char (point-min))
        (widget-forward 1)))
    (when fresh
      (let ((window (vikix-office--form-place owner buffer)))
        (with-current-buffer buffer (setq vikix-office--form (plist-put vikix-office--form :window window)))))
    buffer))
(defun vikix-office--form-draw-desk (owner desk offer)
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
      ;; The mode: Codex's for now (another agent with one picked is refused by the backend, with the words).
      (let ((default (or (alist-get 'mode offer) "autonomous")))
        (push (cons 'mode
                    (apply #'widget-create 'radio-button-choice :tag "Mode" :value default
                           :format "Mode (Codex): how free the worker is; the house default is %v"
                           :help-echo "supervised: its sandbox is the desk, every step out of it asks you; autonomous: a reviewer of Codex's own answers them; unrestricted: no sandbox, no approvals"
                           (mapcar (lambda (m)
                                     (list 'item :tag (concat m "  "
                                                              (pcase m
                                                                ("supervised" "its sandbox is the desk alone; every step out of it (a commit, the tests) asks you unless Vikix's rules allow it")
                                                                ("autonomous" "the same sandbox; a reviewer of Codex's own answers those steps, the network on")
                                                                ("unrestricted" "NO SANDBOX, NO APPROVALS: for a VM or a container; refused in a project's own folder, warned about, recorded")
                                                                (_ "")))
                                           :format "%t\n" :value m))
                                   (or (alist-get 'modes offer) '("supervised" "autonomous" "unrestricted")))))
              widgets))
      (widget-insert "\n")
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
(defconst vikix-office--project-wheres
  '(("public" "GitHub, public" "on GitHub for anyone to see, pushed once; origin set")
    ("private" "GitHub, private" "on GitHub for you alone, pushed once; origin set")
    ("local" "Here, a repository" "a git repository under the root alone, nothing on GitHub (push later, when you want)")
    ("folder" "A folder" "a folder with a log, no git"))
  "The New project form's Where: the backend's word, the label, what it means.")
(defun vikix-office--form-draw-project (owner offer)
  "The New project form: a name, where it goes (GitHub public or private,
a repository here, a folder), its title, description and first step, and
the log kept apart; with what the backend OFFERed (the root, the logs
folder, the GitHub account), in OWNER's desk pane."
  (let* ((buffer (generate-new-buffer "*Office new project*"))
         (window (with-current-buffer owner
                   (and (buffer-live-p vikix-office--detail)
                        (get-buffer-window vikix-office--detail vikix-office--frame))))
         (root (abbreviate-file-name (or (alist-get 'root offer) "~/src")))
         (logs (abbreviate-file-name (or (alist-get 'logs offer) "~/src/project-logs")))
         (github (alist-get 'github offer))
         widgets)
    (with-current-buffer buffer
      (kill-all-local-variables)
      (let ((inhibit-read-only t)) (erase-buffer))
      (remove-overlays)
      (widget-insert (propertize "New project" 'face '(:inherit variable-pitch :height 1.3 :weight bold)) "\n")
      (widget-insert "A folder under " root " with a log, which vikix project lists (vikix project new); as a repository, with a README and a first commit; on GitHub, made there and pushed once through gh's login. Then a desk at it: New desk.\n\n")
      (push (cons 'name (widget-create 'editable-field :size 30 :format "Name:         %v\n"
                                       :help-echo "A word: the folder's name under the root, and the repository's" ""))
            widgets)
      (widget-insert (propertize (concat "              a word (letters, digits, dots, dashes): " root "/NAME, and the repository's name\n") 'face 'shadow))
      (widget-insert "\n")
      ;; Where it goes is always picked (Vid, 2026-10-10: a choice that makes something starts unpicked).
      (push (cons 'where
                  (apply #'widget-create 'menu-choice :tag "Where" :value ""
                         :format "%t:        %[%v%]\n" :button-prefix "[" :button-suffix "]"
                         :help-echo "On GitHub, public or private; a repository here; or a folder with a log: a click or RET opens the list"
                         '(item :tag "pick one" :format "%t" :value "")
                         (mapcar (lambda (w) (list 'item :tag (concat (nth 1 w) "  " (nth 2 w)) :format "%t" :value (car w)))
                                 vikix-office--project-wheres)))
            widgets)
      (widget-insert (propertize (concat "              "
                                         (cond ((stringp github) (concat "GitHub: signed in as " github " (gh), so the repository is github.com/" github "/NAME"))
                                               ((eq (alist-get 'gh offer) t) "GitHub can't be asked: gh isn't signed in (gh auth login in a terminal), or GitHub is out of reach; the two GitHub choices are refused until it can")
                                               (t "GitHub is out of reach: gh (the package github-cli) isn't installed; the two GitHub choices are refused until it is"))
                                         "\n")
                                 'face 'shadow))
      (widget-insert "\n")
      (push (cons 'title (widget-create 'editable-field :size 50 :format "Title:        %v\n"
                                        :help-echo "The log's heading and the README's; empty: from the name" ""))
            widgets)
      (widget-insert (propertize "              the log's heading and the README's (empty: the name, as words)\n" 'face 'shadow))
      (push (cons 'description (widget-create 'editable-field :size 50 :format "Description:  %v\n"
                                              :help-echo "One line: the README's, and GitHub's About; for a repository" ""))
            widgets)
      (widget-insert (propertize "              one line: the README's second line, and GitHub's About (for a repository)\n" 'face 'shadow))
      (push (cons 'next (widget-create 'editable-field :size 50 :format "Next:         %v\n"
                                       :help-echo "The first step: the log's Next line, which the New desk form shows" ""))
            widgets)
      (widget-insert (propertize "              the first step: the log's Next line (empty: the first step)\n" 'face 'shadow))
      (widget-insert "\n")
      (push (cons 'log-apart (widget-create 'checkbox nil)) widgets)
      (widget-insert (concat " Log apart: the log in " logs "/NAME, out of the repository (for a public one whose log is yours; the log is never pushed then)\n\n"))
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-submit)) "Make project")
      (widget-insert "  ")
      (widget-create 'push-button :notify (lambda (&rest _) (vikix-office-form-cancel)) "Cancel")
      (widget-insert "\n\n"
                     (propertize "A click or RET on a [choice] opens its list; TAB moves between the fields; C-c C-c is the button, C-c C-k cancels. A push can take a while: the Office waits up to two and a half minutes."
                                 'face 'shadow))
      (use-local-map vikix-office-form-map)
      (widget-setup)
      (setq vikix-office--form (list :owner owner :desk 'project :offer offer :widgets widgets :window window))
      (goto-char (point-min))
      (widget-forward 1))
    (if (window-live-p window)
        (progn (set-window-buffer window buffer) (select-window window))
      (pop-to-buffer buffer))
    buffer))
(defun vikix-office--form-project-args ()
  "The backend's words for the New project form as it stands; a user error for what is missing."
  (let* ((offer (plist-get vikix-office--form :offer))
         (name (string-trim (or (vikix-office--form-value 'name) "")))
         (where (vikix-office--form-value 'where))
         (title (string-trim (or (vikix-office--form-value 'title) "")))
         (description (string-trim (or (vikix-office--form-value 'description) "")))
         (next (string-trim (or (vikix-office--form-value 'next) "")))
         (apart (vikix-office--form-value 'log-apart)))
    (unless (string-match-p "\\`[A-Za-z0-9][A-Za-z0-9._-]*\\'" name)
      (vikix-office--form-say "The project's name is a word: letters, digits, dots, dashes (my-book); it names the folder and the repository")
      (user-error "The project's name is a word: letters, digits, dots, dashes"))
    (when (member where '(nil ""))
      (vikix-office--form-say "Pick where it goes: a click or RET on [pick one] opens the list")
      (user-error "Pick where it goes"))
    (when (and (member where '("public" "private")) (not (stringp (alist-get 'github offer))))
      (vikix-office--form-say "GitHub can't be asked (gh not installed or not signed in: gh auth login); pick Here, a repository, and push later")
      (user-error "GitHub can't be asked: gh auth login first, or a repository here"))
    (when (and (equal where "folder") (not (string-empty-p description)))
      (vikix-office--form-say "A description goes into a README, which a folder with a log alone has not: pick a repository, or leave it empty")
      (user-error "A description is for a repository"))
    (when (and (equal where "folder") apart)
      (vikix-office--form-say "A log kept apart is for a repository: pick one, or untick Log apart")
      (user-error "A log kept apart is for a repository"))
    (append (list "office" "--project" name "--where" where)
            (unless (string-empty-p title) (list "--title" title))
            (unless (string-empty-p next) (list "--next" next))
            (unless (string-empty-p description) (list "--description" description))
            (and apart '("--log-apart")))))
(defun vikix-office--form-say (text)
  "TEXT in the form's own header line, where the eye is (the Office's is in the other pane)."
  (setq header-line-format (concat "  " (replace-regexp-in-string "%" "%%" text)))
  (force-mode-line-update))
(defun vikix-office--form-value (name)
  "The form's widget NAME's value in this buffer; nil without the widget."
  (let ((w (alist-get name (plist-get vikix-office--form :widgets))))
    (and w (widget-value w))))
(defun vikix-office--form-plan-args ()
  "The backend's words for the New plan form as it stands; a user error for what is missing."
  (let* ((template (vikix-office--form-value 'template))
         (project (vikix-office--form-value 'project))
         (name (string-trim (or (vikix-office--form-value 'name) "")))
         (at-once (string-trim (or (vikix-office--form-value 'at-once) "")))
         (gate (vikix-office--form-value 'gate)))
    (when (member template '(nil ""))
      (vikix-office--form-say "Pick the template: a click or RET on [pick one] opens the list")
      (user-error "Pick the template"))
    (when (member project '(nil ""))
      (vikix-office--form-say "Pick the project: a click or RET on [pick one] opens the list")
      (user-error "Pick the project"))
    (unless (string-match-p "\\`[a-z0-9][a-z0-9-]*\\'" name)
      (vikix-office--form-say "The plan's name is a word: letters, digits, dashes (wifi-fix); it names the file and the desks")
      (user-error "The plan's name is a word: letters, digits, dashes"))
    (unless (string-match-p "\\`[0-9]*\\'" at-once)
      (vikix-office--form-say "At once is a number of workers, or empty for the template's")
      (user-error "At once is a number of workers"))
    (append (list "office" "--plan" template name project)
            (unless (string-empty-p at-once) (list "--at-once" at-once))
            (unless (member gate '(nil "")) (list "--gate" gate))
            (and (plist-get vikix-office--form :tasks) '("--tasks")))))
(defun vikix-office--form-plan-input ()
  "The New plan form's tasks as the backend takes them on stdin: a JSON
list, a task each with its TOML keys; a user error for a task without a
name or words. Words left empty keep the template's line (EDIT:), for the
file later; a release left empty with none is no release."
  (let ((i 0) out)
    (dolist (tw (plist-get vikix-office--form :tasks))
      (setq i (1+ i))
      (let* ((value (lambda (k) (let ((w (alist-get k tw))) (if (widgetp w) (string-trim (or (widget-value w) "")) (or w "")))))
             (name (funcall value 'name)) (desk (funcall value 'desk)) (text (funcall value 'task))
             (release (funcall value 'release)) (agent (funcall value 'agent)) (mode (funcall value 'mode))
             (after (split-string (funcall value 'after) "[, ]+" t))
             (acceptance (split-string (funcall value 'acceptance) "\n" t "[ \t]+"))
             (hint (alist-get 'hint tw)) (release-hint (alist-get 'release-hint tw)))
        (unless (string-match-p "\\`[a-z0-9][a-z0-9-]*\\'" name)
          (vikix-office--form-say (format "Task %d's name is a word: letters, digits, dashes" i))
          (user-error "Task %d's name is a word: letters, digits, dashes" i))
        (when (and (string-empty-p text) (not hint))
          (vikix-office--form-say (format "Task %d (%s): the worker's job, in your words" i name))
          (user-error "Task %d (%s) has no words" i name))
        (push (append (list (cons 'name name))
                      (unless (string-empty-p desk) (list (cons 'desk desk)))
                      (when after (list (cons 'after (vconcat after))))
                      (list (cons 'task (if (string-empty-p text) (concat "EDIT: " hint) text)))
                      (cond ((not (string-empty-p release)) (list (cons 'release release)))
                            (release-hint (list (cons 'release (concat "EDIT: " release-hint)))))
                      (when acceptance (list (cons 'acceptance (vconcat acceptance))))
                      (unless (string-empty-p agent) (list (cons 'agent agent)))
                      (and (widget-value (alist-get 'local tw)) (list (cons 'local t)))
                      (and (widget-value (alist-get 'push tw)) (list (cons 'push t)))
                      (and (widget-value (alist-get 'notests tw)) (list (cons 'no-tests t)))
                      (unless (string-empty-p mode) (list (cons 'mode mode))))
              out)))
    (and out (json-serialize (vconcat (nreverse out))))))
(defun vikix-office--form-args ()
  "The backend's words for this form as it stands; a user error for what is missing."
  (unless vikix-office--form (user-error "Not a form"))
  (pcase (plist-get vikix-office--form :desk)
    ('plan (vikix-office--form-plan-args))
    ('project (vikix-office--form-project-args))
    (_ (vikix-office--form-desk-args))))
(defun vikix-office--form-desk-args ()
  "The desk and worker forms' words."
  (let* ((form vikix-office--form) (desk (plist-get form :desk))
         (task (string-trim (or (vikix-office--form-value 'task) "")))
         (agent (vikix-office--form-value 'agent))
         (mode (vikix-office--form-value 'mode))
         (options (append (unless (member agent '(nil "")) (list "--use" agent))
                          (and (vikix-office--form-value 'local) '("--local"))
                          (and (vikix-office--form-value 'push) '("--push"))
                          (and (vikix-office--form-value 'notests) '("--no-tests"))
                          ;; The house default is applied by the backend; only another choice is sent.
                          (and mode (not (equal mode (or (alist-get 'mode (plist-get form :offer)) "autonomous")))
                               (list "--mode" mode)))))
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
  "Make the desk, start the worker or write the plan, as the form says; the form closes once the backend has."
  (interactive)
  (let* ((args (vikix-office--form-args)) (owner (plist-get vikix-office--form :owner)) (buffer (current-buffer))
         (input (and (member "--tasks" args) (vikix-office--form-plan-input))))
    (unless (buffer-live-p owner) (user-error "The Office is closed"))
    (vikix-office--form-say (pcase (plist-get vikix-office--form :desk)
                              ('plan "Writing the plan…") ('project "Making the project…")
                              ('nil "Making the desk…") (_ "Starting the worker…")))
    (with-current-buffer owner
      (when (process-live-p vikix-office--action) (user-error "An Office action is still running"))
      ;; A project on GitHub is a push as well: the usual bound is for an answer in seconds.
      (let ((vikix-office-timeout (if (equal (nth 1 args) "--project") (max vikix-office-timeout 150) vikix-office-timeout)))
      (vikix-office--request
       args 'vikix-office--action
       (lambda (output error)
         (if error
             ;; The form stays, with what to fix said where the eye is.
             (progn (vikix-office--notice error)
                    (when (buffer-live-p buffer) (with-current-buffer buffer (vikix-office--form-say error)))
                    (message "%s" (string-trim error)))
           (let ((last (or (car (last (split-string (string-trim output) "\n" t))) "Done")))
             (when (buffer-live-p buffer) (with-current-buffer buffer (vikix-office-form-cancel)))
             ;; A plan written: the backend answers with its file alone, which
             ;; opens here for its tasks' words; the Plans box has it as a draft.
             (if (and (equal (nth 1 args) "--plan") (file-name-absolute-p last) (file-readable-p last))
                 (progn (vikix-office--notice (concat "Plan written: " (abbreviate-file-name last)
                                                      (if (and input (not (string-match-p "EDIT: " input)))
                                                          ". Run is in the Plans box."
                                                        ". Write its EDIT: lines, save; Run is in the Plans box.")))
                        (vikix-office--show-buffer (find-file-noselect last)))
               (vikix-office--notice last)))
           (vikix-office-refresh)))
       input)))))
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
;; The keys are bound at every load, not inside the defvar: a defvar keeps
;; its first value, so an Office opened before an update kept the old map
;; and a key the update brought did nothing there (C, 2026-10-10). The
;; Office's own buffer uses the map itself, so a reload reaches it; the
;; desk pane's copy is made again when the Office is opened again.
(defvar vikix-office-mode-map (make-sparse-keymap))
(defun vikix-office--bind-keys (map)
  "The Office's keys in MAP, as this file has them."
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "g") #'vikix-office-refresh)
    (define-key map (kbd "a") #'vikix-office-go)
    (define-key map (kbd "c") #'vikix-office-continue)
    (define-key map (kbd "x") #'vikix-office-close-agent)
    (define-key map (kbd "C") #'vikix-office-close-desk)
    (define-key map (kbd "P") #'vikix-office-pause)
    (define-key map (kbd "t") #'vikix-office-test)
    (define-key map (kbd "s") #'vikix-office-skip-tests)
    (define-key map (kbd "r") #'vikix-office-review)
    (define-key map (kbd "i") #'vikix-office-tell)
    (define-key map (kbd "N") #'vikix-office-new-desk)
    (define-key map (kbd "L") #'vikix-office-new-plan)
    (define-key map (kbd "R") #'vikix-office-new-project)
    (define-key map (kbd "h") #'vikix-office-guide)
    (define-key map (kbd "w") #'vikix-office-worker)
    (define-key map (kbd "A") #'vikix-office-toggle-archive)
    (define-key map (kbd "k") #'vikix-office-toggle-parked)
    (define-key map (kbd "q") #'vikix-office-close)
    (define-key map (kbd "RET") #'vikix-office-details)
    (define-key map (kbd "TAB") #'forward-button)
    (define-key map (kbd "<backtab>") #'backward-button)
    (define-key map (kbd "n") (lambda () (interactive) (vikix-office-next 1)))
    (define-key map (kbd "p") (lambda () (interactive) (vikix-office-next -1)))
    map)
(vikix-office--bind-keys vikix-office-mode-map)
(defun vikix-office--detail-map ()
  "The desk pane's map: the Office's keys, with RET pressing a button and n and p moving a line."
  (let ((map (copy-keymap vikix-office-mode-map)))
    (define-key map (kbd "RET") #'push-button)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
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
        (use-local-map (vikix-office--detail-map))
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
        (progn
          ;; Opened again after an update: the desk pane's copy of the keys is
          ;; made again, so the keys the update brought work there too.
          (let ((detail (buffer-local-value 'vikix-office--detail (frame-parameter existing 'vikix-office-buffer))))
            (when (buffer-live-p detail)
              (with-current-buffer detail (use-local-map (vikix-office--detail-map)))))
          (select-frame-set-input-focus existing)
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
