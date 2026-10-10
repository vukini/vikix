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
;;;; vikix-workspace-claim. A name you type is different: Super+0 opens
;;;; the named workspaces as a map (help.lisp's, made as it opens: a letter
;;;; each, the first of its name that is free, and / to type a name), and
;;;; the letter goes there; the name typed (vikix-workspace) makes a
;;;; workspace of that name when it is new, empty numbered ones or not
;;;; (:named t), since you asked for it by name. Super+Shift+0 is the same
;;;; map for sending the window (vikix-send-named, viri.lisp). A named
;;;; workspace is
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
  "Go to a workspace by name (Super+0, then /; Tab completes). A name there is no
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

;;; --- The map of the named workspaces: Super+0, a letter ------------------------------------
;;;
;;; Super+0 then a letter, where typing the name took a word: the map's
;;; keys are made as it opens (*vikix-map-live*, help.lisp), one a named
;;; workspace. Its command carries the letter, not the name
;;; (vikix-workspace-key o): the two keys are counted by vikix used with
;;; their command, and a workspace's name is the user's own word.

(defun vikix-workspace-named ()
  "The workspaces past the nine, in the bar's order: the named ones."
  (remove-if (lambda (name) (member name *vikix-group-names* :test #'equal))
             (vikix-workspace-names)))

(defun vikix-workspace-letters (&optional (names (vikix-workspace-named)))
  "A key for each of NAMES, as (KEY . NAME) in their order: the first
letter of the name that no earlier name took (office o, cuis c, a second
name in c- its u), else the first letter of the alphabet still free; a
name with nothing left goes without a key. Letters only: / types a name,
and the digits are the nine's."
  (let ((taken '()) (pairs '()))
    (dolist (name names (nreverse pairs))
      (let ((key (or (find-if (lambda (c) (and (alpha-char-p c) (< (char-code c) 128)
                                                (not (member c taken))))
                              (string-downcase name))
                     (find-if-not (lambda (c) (member c taken)) "abcdefghijklmnopqrstuvwxyz"))))
        (when key
          (push key taken)
          (push (cons (string key) name) pairs))))))

(defun vikix-workspace-map-entries (action)
  "The entries of the map of the named workspaces, for vikix-map-entries:
a letter a workspace, then / to type a name, each closing the map as it
runs. ACTION is :go (Super+0: go there) or :send (Super+Shift+0: send
the window there, staying here)."
  (let ((command (if (eq action :send) "vikix-send-key" "vikix-workspace-key"))
        (typed (if (eq action :send) "vikix-send-named" "vikix-workspace")))
    (append
     (loop for (key . name) in (vikix-workspace-letters)
           collect (list key (format nil "~a ~a" command key) name :close))
     (list (list "/" typed "a name to type: a new one makes a workspace of that name" :close)))))

(defun vikix-workspace-map-key () "s-0")

(defun vikix-workspace-send-map-key ()
  "The key that sends the window to a workspace by name: Shift+0 of this
keyboard, as keys.lisp bound it."
  (and (fboundp 'vikix-shift-digit-key) (funcall 'vikix-shift-digit-key 0)))

(defun vikix-workspace-of-key (key)
  "The named workspace the letter KEY stands for in the map now, or nil."
  (cdr (assoc key (vikix-workspace-letters) :test #'string-equal)))

(defcommand vikix-workspace-key (key) ((:string "Letter: "))
  "Go to the named workspace whose letter in Super+0's map is KEY."
  (let ((name (vikix-workspace-of-key key)))
    (if name
        (vikix-workspace name)
        (message "No named workspace has the letter ~a now." key))))

(defcommand vikix-send-key (key) ((:string "Letter: "))
  "Send this window to the named workspace whose letter in Super+Shift+0's
map is KEY, staying here (vikix-send-named, viri.lisp)."
  (let ((name (vikix-workspace-of-key key)))
    (if name
        (funcall 'vikix-send-named name)
        (message "No named workspace has the letter ~a now." key))))

;;; --- Refile: the workspaces move left into the empty ones -------------------------------

(defparameter *vikix-refile-from* 1
  "The first workspace a refile moves or fills: 1, so an empty workspace 1
takes the first workspace with windows. Set it to 2 in user.lisp to keep 1
as a home that is neither moved nor filled, however empty.")

(defun vikix-workspace-empty-p (group)
  (null (group-windows group)))

(defun vikix-refile-candidates ()
  "The numbered workspaces a refile may move or fill, in order: the nine
from *vikix-refile-from* on. A named workspace has no left to move to."
  (loop for group in (sort-groups (current-screen))
        when (and (member (group-name group) *vikix-group-names* :test #'equal)
                  (>= (group-number group) *vikix-refile-from*))
          collect group))

(defun vikix-winner-swap (a b)
  "winner-mode keeps a workspace's layout steps by its number, in two
tables and as files named for it: numbers A and B trade theirs, so Super+u
on a moved workspace still undoes its own changes."
  (let ((package (find-package :winner-mode)))
    (when package
      (let ((current (symbol-value (find-symbol "*CURRENT-IDS*" package)))
            (max (symbol-value (find-symbol "*MAX-IDS*" package)))
            (dump-name (find-symbol "DUMP-NAME" package)))
        (flet ((files (number)
                 (loop for id from 1 to (gethash number max 0)
                       for file = (funcall dump-name number id)
                       when (probe-file file) collect (cons id file))))
          (let ((a-files (files a)) (b-files (files b)))
            (ignore-errors
             ;; Each set to its new number through a number no workspace has (0),
             ;; so the two never meet half way.
             (loop for (id . file) in a-files do (rename-file file (funcall dump-name 0 id)))
             (loop for (id . file) in b-files do (rename-file file (funcall dump-name a id)))
             (loop for (id) in a-files do (rename-file (funcall dump-name 0 id) (funcall dump-name b id))))))
        (dolist (table (list current max))
          (let ((a-ids (gethash a table)) (b-ids (gethash b table)))
            (if b-ids (setf (gethash a table) b-ids) (remhash a table))
            (if a-ids (setf (gethash b table) a-ids) (remhash b table))))))))

(defun vikix-workspace-swap (a b)
  "Workspaces A and B trade names and numbers. Everything else is the
group's own and stays with it: the windows, the frames, what floats, a
strip and its columns, grid or main-and-stack mode, the solo layout; so
the workspace that moves keeps its layout entire. The keys, the bar and
the rules go by number and name, so each now reaches the other."
  (let ((a-name (group-name a)) (a-number (group-number a)))
    (setf (group-name a) (group-name b)
          (group-number a) (group-number b)
          (group-name b) a-name
          (group-number b) a-number)
    (vikix-winner-swap a-number (group-number a))))

(defun vikix-refile-moves ()
  "The moves a refile makes, as it makes them: a list of (FROM . TO), the
numbers' names, in order."
  (let ((moves '()))
    (loop
      (let* ((groups (vikix-refile-candidates))
             (empty (find-if #'vikix-workspace-empty-p groups))
             (full (and empty
                        (find-if (lambda (g) (and (not (vikix-workspace-empty-p g))
                                                  (> (group-number g) (group-number empty))))
                                 groups))))
        (unless full (return))
        (let ((from (group-name full)) (to (group-name empty)))
          (vikix-workspace-swap full empty)
          (setf moves (append moves (list (cons from to)))))))
    moves))

(defcommand vikix-refile-workspaces () ()
  "Refile the workspaces: from 1 on, each one with windows moves left into
the nearest empty one, as far as it can, keeping its layout, its order
among the others kept too (*vikix-refile-from* says where they start). The
named workspaces past the nine are left as they are. Says what moved."
  (let ((moves (vikix-refile-moves)))
    (update-all-mode-lines)
    (if moves
        (message "Refiled: ~{~a to ~a~^, ~}." (loop for (from . to) in moves collect from collect to))
        (message "Nothing to refile: no workspace has an empty one to its left."))))
