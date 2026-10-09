;;;; What is this? (Super+Alt+?, `vikix what`; the design is plans/DESIGN-what.md)
;;;;
;;;; The sibling of why.lisp: that one says what made a thing happen, this
;;;; one what a thing is. The key says what the pointer is on in the bar (a
;;;; field, a workspace's number, a window's title), else the window in
;;;; front, and hands it to `vikix what --card`, which reads the facts and
;;;; shows the card. The command never waits on a program.
;;;;
;;;; The rest answers bin/vikix-what's questions about what only the
;;;; desktop knows (a window, a workspace, a key, what a field shows now),
;;;; as lines of NAME<tab>VALUE. A window's title is said there and kept
;;;; nowhere.

(in-package :stumpwm)

(defparameter *vikix-what-click-kinds*
  '((:volume . "volume") (:net . "network") (:bt . "bluetooth") (:memory . "memory"))
  "The bar's fields with a click of their own (modeline.lisp's
vikix-ml-click), by the name vikix what knows each under.")

(defun vikix-what-area-thing (area)
  "What an area of the bar is, as (KIND NAME), or nil: AREA as
vikix-ml-area-at gives it."
  (destructuring-bind (&optional xbeg xend ybeg yend id args) area
    (declare (ignore xbeg xend ybeg yend))
    (let ((arg (first args)))
      (case id
        (:vikix-ml-what (and (stringp arg) (list arg)))
        (:vikix-ml-click (let ((kind (cdr (assoc arg *vikix-what-click-kinds*))))
                           (and kind (list kind))))
        (:ml-on-click-switch-to-group (and (stringp arg) (list "workspace" arg)))
        (:ml-on-click-focus-window (and (integerp arg) (list "window" arg)))))))

(defun vikix-what-bar-thing ()
  "What the pointer is on in a bar of this screen, as (KIND NAME), or nil
when it isn't on a field."
  (ignore-errors
   (loop for head in (screen-heads (current-screen))
         for ml = (head-mode-line head)
         when (and ml (not (eq (mode-line-mode ml) :hidden)))
           do (multiple-value-bind (x y same) (xlib:query-pointer (mode-line-window ml))
                (let ((thing (and same (vikix-what-area-thing (vikix-ml-area-at ml x y)))))
                  (when thing (return thing)))))))

(defun vikix-what-here ()
  "What \"this\" is now: the bar's field under the pointer, else the window
in front, else the workspace in view."
  (or (vikix-what-bar-thing)
      (let ((window (current-window)))
        (and window (list "window" (xlib:window-id (window-xwin window)))))
      (list "workspace" (group-name (current-group)))))

(defun vikix-what-show (thing)
  "The card for THING, (KIND NAME): bin/vikix-what makes it, and this
returns at once."
  (destructuring-bind (kind &optional name) thing
    (run-shell-command (format nil "exec vikix-what --card ~a~@[ ~a~]"
                               (vikix-shell-quote kind)
                               (and name (vikix-shell-quote (princ-to-string name)))))))

(defcommand vikix-what () ()
  "What is this? The field of the bar the pointer is on, or the window in
front: what it is doing now, a few lines on what such a thing is, and where
it is explained."
  (vikix-what-show (vikix-what-here)))

;;; --- What only the desktop knows, for bin/vikix-what ------------------------

(defun vikix-what-plain (text)
  "A field's TEXT as the bar shows it: without the colours and the areas."
  (string-trim " " (ppcre:regex-replace-all
                    "\\^(\\^)|\\^\\([^)]*\\)|\\^[^(^]"
                    (or text "") "\\1")))

(defun vikix-what-net-text (ml) (declare (ignore ml)) *vikix-net*)
(defun vikix-what-bt-text (ml) (declare (ignore ml)) *vikix-bt*)

(defparameter *vikix-what-fields*
  '(("battery" . vikix-mode-line-battery) ("network" . vikix-what-net-text)
    ("bluetooth" . vikix-what-bt-text) ("volume" . vikix-mode-line-volume)
    ("memory" . vikix-mode-line-memory) ("updates" . vikix-mode-line-updates)
    ("backup" . vikix-mode-line-backup) ("drive" . vikix-mode-line-usb)
    ("dropbox" . vikix-mode-line-dropbox) ("quiet" . vikix-mode-line-quiet)
    ("awake" . vikix-mode-line-awake) ("focus" . vikix-mode-line-focus) ("windows-vm" . vikix-mode-line-windows)
    ("ai" . vikix-mode-line-ai) ("clock" . vikix-mode-line-clock))
  "The bar's fields by name, each with what writes it. The network and
Bluetooth by their variables: their fields step aside for the tray's icons.")

(defun vikix-what-field-shows (kind)
  "What the bar's field KIND shows now, \"\" for nothing, or nil for a name
that is no field."
  (cond ((equal kind "recording") (if *vikix-recording* "rec" ""))
        ((equal kind "dictation") (if *vikix-dictating* "mic" ""))
        (t (let ((writer (cdr (assoc kind *vikix-what-fields* :test #'equal))))
             (and writer
                  (vikix-what-plain
                   (or (ignore-errors (funcall writer (head-mode-line (current-head)))) "")))))))

(defun vikix-what-window (id)
  "The window with X id ID on this screen; the one in front for nil."
  (if id
      (find id (screen-windows (current-screen))
            :key (lambda (w) (ignore-errors (xlib:window-id (window-xwin w)))))
      (current-window)))

(defun vikix-what-window-how (window)
  "How WINDOW is held, in words."
  (cond ((ignore-errors (window-fullscreen window)) "fullscreen")
        ((ignore-errors (vikix-strip-column-p window)) "a column of a strip")
        ((typep window 'float-window) "floating")
        (t "a tile")))

(defun vikix-what-window-job (window)
  "The process a terminal WINDOW is running in front (not its shell at a
prompt), or nil."
  (ignore-errors
   (let* ((pid (vikix-window-pid window))
          (cmd (and pid (vikix-proc-cmdline pid))))
     (when (and cmd (member (vikix-layout-program (first cmd)) *vikix-layout-terminals* :test #'string=))
       (let* ((inside (vikix-proc-child pid))
              (front (and inside (vikix-proc-foreground inside)))
              (job (and front (vikix-proc-cmdline front))))
         (and job
              (not (member (vikix-layout-program (first job)) *vikix-layout-shells* :test #'string=))
              front))))))

(defun vikix-what-key-binding (name)
  "The binding of the key written NAME (\"s-M-?\"): (NAME-AS-BOUND COMMAND),
or nil. A key of Vikix's, a plugin's or yours by the name it was bound
under; any other key of the top map by what StumpWM has for it."
  (let ((key (ignore-errors (kbd name))))
    (when key
      (let ((bound (and (boundp '*vikix-bindings*)
                        (find-if (lambda (b) (ignore-errors (equalp (kbd (first b)) key)))
                                 (symbol-value '*vikix-bindings*)))))
        (if bound
            (list (first bound) (second bound))
            (let ((command (ignore-errors (lookup-key *top-map* key))))
              (and (stringp command) (list name command))))))))

(defun vikix-what-key-count (name)
  "How often the key NAME was pressed, as `vikix used` counts it, or nil."
  (ignore-errors
   (when (and (boundp '*vikix-used*) (fboundp 'vikix-used-read))
     (funcall 'vikix-used-read)
     (let ((start (format nil "key~c~a~c" #\Tab name #\Tab)))
       (loop for what being the hash-keys of (symbol-value '*vikix-used*) using (hash-value counts)
             when (eql 0 (search start what)) sum (first counts))))))

(defun vikix-what-lines (kind &optional name)
  "What the desktop knows of a thing, for bin/vikix-what: lines of
NAME<tab>VALUE, in the order they are to be said; nothing for a thing that
isn't there. KIND is \"here\" (which thing the pointer or the focus is on),
\"window\" (NAME its X id, or nil for the one in front), \"workspace\",
\"key\" or a field of the bar."
  (with-output-to-string (out)
    (flet ((line (key value)
             (when (and value (not (equal value "")))
               (format out "~a~c~a~%" key #\Tab (vikix-one-line value 300)))))
      (ignore-errors
       (cond
         ((equal kind "here")
          (destructuring-bind (k &optional n) (vikix-what-here)
            (line "kind" k)
            (line "name" n)))
         ((equal kind "window")
          (let ((window (vikix-what-window name)))
            (when window
              (line "id" (xlib:window-id (window-xwin window)))
              (line "class" (window-class window))
              (line "title" (window-title window))
              (line "pid" (vikix-window-pid window))
              (line "job" (vikix-what-window-job window))
              (line "workspace" (group-name (window-group window)))
              (line "how" (vikix-what-window-how window))
              (line "front" (and (eq window (current-window)) "yes"))
              (when (fboundp 'vikix-rules-why)
                (dolist (entry (funcall 'vikix-rules-why window))
                  (let ((rule (third entry)))
                    (line "rule" (if rule
                                     (vikix-one-line (vikix-rule-text rule) 120)
                                     "a rule that isn't there any more"))))))))
         ((equal kind "workspace")
          (let ((group (or (and name (find-group (current-screen) (princ-to-string name)))
                           (and (null name) (current-group)))))
            (when group
              (line "name" (group-name group))
              (line "windows" (length (group-windows group)))
              (line "how" (cond ((and (fboundp 'viri-group-p) (funcall 'viri-group-p group)) "a strip")
                                ((typep group 'float-group) "floating windows")
                                (t "tiles")))
              (line "view" (and (eq group (current-group)) "yes")))))
         ((equal kind "key")
          (let ((binding (and (stringp name) (vikix-what-key-binding name))))
            (when binding
              (destructuring-bind (bound command) binding
                (line "key" bound)
                (line "said" (vikix-pretty-key bound))
                (line "runs" command)
                (line "does" (vikix-why-command-words command))
                (multiple-value-bind (whose file key-line) (vikix-why-key-source bound command)
                  (line "whose" whose)
                  (line "file" (and file (namestring file)))
                  (line "line" key-line))
                (line "pressed" (vikix-what-key-count bound))))))
         (t
          (let ((shows (vikix-what-field-shows kind)))
            (when shows
              (line "field" kind)
              (line "shows" shows)))))))))
