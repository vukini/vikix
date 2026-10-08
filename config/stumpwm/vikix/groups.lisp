;;;; groups.lisp — nine workspaces, named 1 to 9, and more by name when
;;;; those are full.
;;;;
;;;; StumpWM calls workspaces "groups". It starts with one called
;;;; "Default"; Vikix renames it to "1" and adds 2-9 in the background.
;;;; Safe to load twice: existing groups are left as they are.
;;;;
;;;; The nine always exist. A desk (vikix agents desk) and a project (vikix
;;;; project open) each want a workspace to themselves, and take the first
;;;; empty one of the nine; only when every one of the nine has windows is
;;;; a tenth made, named for what it is for ("wifi-fix", "novel"), through
;;;; vikix-workspace-claim. A name you type is different: Super+0
;;;; (vikix-workspace) goes to a workspace by name and makes one of that
;;;; name when it is new, empty numbered ones or not (:named t), since you
;;;; asked for it by name; Super+Shift+0 (vikix-send-named, viri.lisp)
;;;; sends the window to one the same way. A named workspace is
;;;; Vikix's to take away again: left with no windows on it, it goes (a
;;;; hook on leaving a workspace), so the bar never fills with empty names.
;;;; Workspaces you make yourself (gnewbg in user.lisp) are never touched.
;;;; resume.lisp makes a named workspace again at login, before putting its
;;;; windows back.

(in-package :stumpwm)

(defparameter *vikix-group-names*
  '("1" "2" "3" "4" "5" "6" "7" "8" "9"))

(let ((screen (current-screen)))
  (when (find-group screen "Default")
    (grename (first *vikix-group-names*)))
  (dolist (name (rest *vikix-group-names*))
    (unless (find-group screen name)
      (add-group screen name :background t))))

;;; --- Named workspaces, made as needed ---------------------------------------------------

(defvar *vikix-workspaces-made* (make-hash-table :test #'equal)
  "The workspaces Vikix made beyond the nine, by name, each with the time
it was made. Only these go away when left empty.")

(defparameter *vikix-workspace-grace* 60
  "Seconds a workspace Vikix made is kept though empty: a desk's terminal
takes a moment to open on it, and leaving in between must not take the
workspace from under it.")

(defun vikix-workspace-names ()
  "Your workspaces' names, in order: the nine, then the named ones."
  (loop for group in (sort-groups (current-screen))
        when (and (plusp (group-number group))
                  (plusp (length (group-name group)))
                  (char/= (char (group-name group) 0) #\.))
          collect (group-name group)))

(defun vikix-workspace-name-ok (name)
  "NAME as a workspace's name, or nil: a word or two, not a number's, not
hidden (a dot first), no tab or newline (the bar and the palette part
their fields with them)."
  (let ((name (string-trim '(#\Space #\Tab #\Newline) (or name ""))))
    (and (plusp (length name))
         (<= (length name) 40)
         (char/= (char name 0) #\.)
         (not (every #'digit-char-p name))
         (notany (lambda (c) (member c '(#\Tab #\Newline))) name)
         name)))

(defun vikix-workspace-make (name)
  "Make the workspace NAME, in the background, and note it as Vikix's own
to take away again. The one of that name already there is returned instead."
  (let* ((screen (current-screen))
         (name (or (vikix-workspace-name-ok name) (error "~s is no name for a workspace." name)))
         (group (or (find-group screen name)
                    (add-group screen name :background t))))
    (setf (gethash name *vikix-workspaces-made*) (get-universal-time))
    group))

(defun vikix-workspace-claim (&optional name &key (go t) named)
  "A workspace for NAME (a desk's topic, a project), gone to unless GO is
nil: the one of that name when it exists; else the first of the nine with
no window; else, all nine being in use, a new one named NAME (this
workspace when no name is given). With NAMED, a name the user typed, the
empty ones of the nine are passed over: a new name is a new workspace of
that name at once. The group."
  (let* ((screen (current-screen))
         (name (vikix-workspace-name-ok name))
         (group (or (and name (find-group screen name))
                    (and (not (and named name))
                         (find-if (lambda (g) (and (null (group-windows g))
                                                   (member (group-name g) *vikix-group-names* :test #'equal)))
                                  (sort-groups screen)))
                    (and name (vikix-workspace-make name))
                    (current-group))))
    (when (and go (not (eq group (current-group))))
      (switch-to-group group))
    group))

(defun vikix-workspace-left (new old)
  "On leaving a workspace: one Vikix made, left with no window and past its
first minute, is taken away. Not when it is being made anew (a strip on or
off is a new group in the old one's place, hidden as \".viri-NAME\" while
the windows move over, then given the name): going to a hidden workspace
is never you leaving."
  (ignore-errors
   (when (and old new (not (eq old new))
              (plusp (length (group-name new)))
              (char/= (char (group-name new) 0) #\.)
              (not (equal (group-name old) (group-name new)))
              (null (group-windows old))
              (find old (screen-groups (group-screen old))))
     (let ((born (gethash (group-name old) *vikix-workspaces-made*)))
       (when (and born (>= (- (get-universal-time) born) *vikix-workspace-grace*))
         (remhash (group-name old) *vikix-workspaces-made*)
         (kill-group old new))))))

(add-hook *focus-group-hook* 'vikix-workspace-left)

(define-stumpwm-type :vikix-workspace (input prompt)
  (or (argument-pop-rest input)
      (completing-read (current-screen) prompt (vikix-workspace-names))))

(defcommand vikix-workspace (name) ((:vikix-workspace "Workspace: "))
  "Go to a workspace by name (Super+0; Tab completes). A name there is no
workspace of gets a new workspace of that name, whether or not one of the
nine is empty: you named it."
  (let* ((screen (current-screen))
         (name (string-trim " " (or name "")))
         (there (and (plusp (length name)) (find-group screen name))))
    (cond ((zerop (length name)))
          (there (switch-to-group there))
          ((not (vikix-workspace-name-ok name))
           (message "~s is no name for a workspace: a word or two, not a number." name))
          (t (vikix-workspace-claim name :named t)
             (message "Workspace ~a, new." name)))))
