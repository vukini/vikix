;;;; rules.lisp — rules for the desktop that read like sentences.
;;;;
;;;;   (when-window (:class "Firefox") (workspace 2))
;;;;   (when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
;;;;   (when-window (:class "mpv" :title (:has "picture in picture"))
;;;;     (float :corner :bottom-right :width "30%" :height "30%") (sticky))
;;;;
;;;; Before, each of these was a function and a hook written by hand, with
;;;; the same guards every time and the same traps: floating a window twice
;;;; is an error, a tiled window kept on every workspace ends the desktop,
;;;; a title given to StumpWM's own rules matches anywhere in the title.
;;;; Here the guards are in one place, and a rule is data: its own text is
;;;; kept, so the desktop can list its rules (the command vikix-rules).
;;;;
;;;; Write them in ~/.stumpwm.d/rules.lisp (loaded just before user.lisp)
;;;; or in user.lisp; a plugin's Lisp may use them too.
;;;;
;;;; Rules without a window, further down, with the same verbs (those that
;;;; need no window) and the same care:
;;;;
;;;;   (at "09:00" :weekdays (open-project "vikix"))
;;;;   (each 30 :minutes (run "vikix-wallpaper next"))
;;;;   (when-battery-below 20 (notify "Battery at 20%: charger?"))
;;;;   (when-charging ...)  (when-on-battery ...)
;;;;   (at-login (run "syncthing --no-browser"))
;;;;   (when-workspace 3 (command "vikix-grid"))
;;;;
;;;; (when-window (MATCH...) [OPTION...] VERB...)
;;;;
;;;;   MATCH   :class :instance :title :role  a string: exactly that;
;;;;                        (:has "text"): contains it, in any case;
;;;;                        (:like "^regex$"): a pattern; a list: any of them;
;;;;                        a variable: its value, read when a window comes
;;;;           :type        :normal, :dialog ... (or a list of them)
;;;;           :workspace   where it opened: a number or a name (or a list)
;;;;           :not (MATCH...)   none of that
;;;;           :where FUNCTION   anything else: called with the window
;;;;   OPTION  :name "..."  what the rule is known by (else: its own text)
;;;;           :on :open (the default), :focus or :close
;;;;           :once t      only the first window that matches
;;;;   VERB    one of the verbs below, (workspace 2), or any Lisp of your
;;;;           own, in which (window) is the window. Only the rule's own
;;;;           forms are read as verbs, not what is inside them.
;;;;
;;;; The verbs are kept in a table, not as functions of those names: float
;;;; is Common Lisp's and fullscreen and title are StumpWM's commands. So a
;;;; misspelt verb or matcher is an error when the file loads, with its
;;;; line, not when the window opens three days later.
;;;;
;;;; A rule that fails never asks: rules run while StumpWM handles an X
;;;; event, where an error let out means the errors menu at best and a
;;;; restart at worst, for every window that opens. The error is written
;;;; down as any other (~/.local/state/vikix/errors/), a message names the
;;;; rule, and the third failure switches it off until the next reload.
;;;;
;;;; A reload gives exactly what the files say: the table is emptied here,
;;;; and a rule defined twice (a reload, C-x C-e in Emacs) replaces itself.
;;;; Windows already open aren't moved by a reload.

(in-package :stumpwm)

(defstruct (vikix-rule (:conc-name vikix-rule-))
  key                 ; what it is known by: its :name, or its text
  name                ; its :name, or nil
  (on :open)          ; :open, :focus or :close
  match               ; the matcher, as written
  test                ; the matcher, compiled: a function of the window
  body                ; the verbs, compiled: a function of nothing
  verbs               ; the names of the verbs it uses ("FLOAT" "STICKY")
  place               ; for a rule with (workspace ...): its arguments, as a function
  text                ; the rule, as written
  file line           ; where it was written
  owner               ; "Vikix", "plugin NAME", "rules.lisp", "user.lisp", "live"
  once                ; only the first window that matches
  (on-p t)            ; switched on
  (runs 0) last-run
  (failures 0) last-error)

(defvar *vikix-rules* '()
  "The desktop's rules, in the order they were defined.")
;; Emptied at every load of the layer: the files that follow fill it again.
(setf *vikix-rules* '())

(defvar *vikix-rule-verbs* (make-hash-table :test 'equal)
  "The verbs: a name (\"FLOAT\") to (FUNCTION DESCRIPTION ARGUMENTS).")

(defvar *vikix-rule-window* nil "The window a rule is running for.")
(defvar *vikix-rule-event* nil "What set the running rule off: :open, :focus, :close.")
(defvar *vikix-rule-depth* 0 "Rules running inside rules: a loop is stopped.")

(defparameter *vikix-rule-max-failures* 3
  "A rule that has failed this often is switched off until the next reload.")

(defvar *vikix-rules-once-done* (make-hash-table :test 'equal)
  "The :once rules that have had their window, by key. Kept over a reload.")
(defvar *vikix-rule-opened-in* (make-hash-table :test 'eq :weakness :key)
  "Each window, and the workspace that was in view when it opened.")
(defvar *vikix-rule-floaters* (make-hash-table :test 'eq :weakness :key)
  "Each window asked about, and whether a rule floats it (:yes or :no).")
(defvar *vikix-rule-notes* (make-hash-table :test 'eq :weakness :key)
  "Each window, and the rules that ran for it (their keys, newest first).")
(defvar *vikix-dialog-windows* (make-hash-table :test 'eq :weakness :key)
  "Windows a rule made dialogs of (the verb dialog): kept in front as
*vikix-dialog-classes*' are. windows.lisp's vikix-dialog-p reads it.")

;;; --- The window, for Lisp of your own ---------------------------------------------

(defun rule-window ()
  "The window the running rule is about."
  (or *vikix-rule-window*
      (error "This verb needs a window, and this rule has none (it isn't a when-window rule).")))

(unless (fboundp 'window)
  (defun window ()
    "Inside a rule: the window the rule is about."
    (rule-window)))

;;; --- Matching --------------------------------------------------------------------------

(defun vikix-rule-pattern-p (pattern)
  "Is PATTERN a way to match text? A string, (:has \"..\"), (:like \"..\"),
a list of those, or a variable."
  (cond ((stringp pattern) t)
        ((and (symbolp pattern) pattern (not (keywordp pattern)) (not (eq pattern t))) t)
        ((not (consp pattern)) nil)
        ((member (first pattern) '(:has :like))
         (and (stringp (second pattern)) (null (cddr pattern))))
        (t (and (listp (cdr (last pattern)))
                (every #'vikix-rule-pattern-p pattern)))))

(defun vikix-rule-check-pattern (key pattern)
  (unless (vikix-rule-pattern-p pattern)
    (error "A rule's ~(~s~) is ~s. It takes a string (exactly that), (:has \"text\"), (:like \"^regex$\"), a list of those, or a variable."
           key pattern))
  (labels ((patterns (p)
             (cond ((and (consp p) (eq (first p) :like)) (list (second p)))
                   ((and (consp p) (not (eq (first p) :has))) (mapcan #'patterns p)))))
    (dolist (regex (patterns pattern))
      (handler-case (ppcre:create-scanner regex)
        (error (e) (error "A rule's ~(~s~) has a pattern that can't be read, ~s: ~a" key regex e))))))

(defun vikix-rule-check-match (match)
  "Signal an error for a matcher that can't work; called when the rule is read."
  (unless (and (listp match) (evenp (length match)))
    (error "A rule's matcher is a list of pairs, like (:class \"Firefox\"); this is ~s." match))
  (loop for (key value) on match by #'cddr
        do (case key
             ((:class :instance :title :role) (vikix-rule-check-pattern key value))
             (:type (unless (or (keywordp value) (and (consp value) (every #'keywordp value)))
                      (error "A rule's :type is a keyword such as :dialog or :normal, or a list of them; this is ~s." value)))
             (:workspace (unless (or (integerp value) (stringp value)
                                     (and (consp value) (every (lambda (v) (or (integerp v) (stringp v))) value)))
                           (error "A rule's :workspace is a number, a name, or a list of them; this is ~s." value)))
             (:not (vikix-rule-check-match value))
             (:where (when (or (null value) (stringp value) (numberp value))
                       (error "A rule's :where is a function of the window, like #'my-test; this is ~s." value)))
             (t (error "~s isn't something a rule can match. It can match :class, :instance, :title, :role, :type, :workspace, :not and :where." key)))))

(defun vikix-rule-text-p (text pattern)
  "Does TEXT (a window's class, title ...) match PATTERN?"
  (let ((text (or text "")))
    (cond ((stringp pattern) (string= text pattern))
          ((not (consp pattern)) nil)
          ((eq (first pattern) :has)
           (and (search (second pattern) text :test #'char-equal) t))
          ((eq (first pattern) :like)
           (and (ppcre:scan (second pattern) text) t))
          (t (and (some (lambda (p) (vikix-rule-text-p text p)) pattern) t)))))

(defun vikix-rule-type-p (window types)
  (let ((type (ignore-errors (window-type window))))
    (and (if (listp types) (member type types) (eq type types)) t)))

(defun vikix-rule-workspace-p (window wanted)
  "Is WINDOW on a workspace of WANTED (a number, a name, a list)? For a
window that is opening: the workspace in view when it opened, which a rule
may already have moved it from."
  (let ((group (or (and (eq *vikix-rule-event* :open)
                        (gethash window *vikix-rule-opened-in*))
                   (ignore-errors (window-group window)))))
    (and group
         (some (lambda (w)
                 (if (integerp w)
                     (eql w (group-number group))
                     (equal w (group-name group))))
               (if (listp wanted) wanted (list wanted)))
         t)))

(defun vikix-rule-slot (reader window)
  "A window's class, title ...; nil when it has none."
  (ignore-errors (funcall reader window)))

(defun vikix-rule-match-code (match w)
  "The Lisp that tests window W (a symbol) against MATCH."
  (flet ((pattern (value) (if (symbolp value) value `',value)))
    `(and ,@(loop for (key value) on match by #'cddr
                  collect (ecase key
                            (:class    `(vikix-rule-text-p (vikix-rule-slot 'window-class ,w) ,(pattern value)))
                            (:instance `(vikix-rule-text-p (vikix-rule-slot 'window-res ,w) ,(pattern value)))
                            (:title    `(vikix-rule-text-p (vikix-rule-slot 'window-title ,w) ,(pattern value)))
                            (:role     `(vikix-rule-text-p (vikix-rule-slot 'window-role ,w) ,(pattern value)))
                            (:type     `(vikix-rule-type-p ,w ',value))
                            (:workspace `(vikix-rule-workspace-p ,w ',value))
                            (:not      `(not ,(vikix-rule-match-code value w)))
                            (:where    `(and (funcall ,value ,w) t))))
           t)))

;;; --- Verbs ---------------------------------------------------------------------------------

(defmacro define-rule-verb (name (&rest args) description &body body)
  "A verb for rules: (NAME ARGS...) as a form of a rule runs BODY, in which
(rule-window) is the window. DESCRIPTION is its one line in the list of verbs."
  (check-type description string)
  (let ((function (intern (format nil "VIKIX-VERB-~a" (symbol-name name)) :stumpwm)))
    `(progn
       (defun ,function ,args ,description ,@body)
       (setf (gethash ,(symbol-name name) *vikix-rule-verbs*)
             (list ',function ,description ',args))
       ',name)))

(defun vikix-rule-verb-names ()
  (sort (loop for name being the hash-keys of *vikix-rule-verbs* collect (string-downcase name))
        #'string<))

(defun vikix-rule-form-verb (form)
  "The verb FORM calls (its name, as in the table), or nil."
  (and (consp form) (symbolp (first form))
       (gethash (symbol-name (first form)) *vikix-rule-verbs*)
       (symbol-name (first form))))

(defun vikix-rule-rewrite (form)
  "FORM of a rule's body, as Lisp to run: a verb becomes a call to its
function; anything else is yours, and stays. A word that is neither a verb
nor anything Lisp knows is an error now, while the file loads."
  (let ((verb (vikix-rule-form-verb form)))
    (cond (verb (cons (first (gethash verb *vikix-rule-verbs*)) (rest form)))
          ((and (consp form) (symbolp (first form))
                (not (fboundp (first form)))
                (not (special-operator-p (first form))))
           (error "~(~a~) isn't a verb, nor a function defined before this rule. The verbs: ~{~a~^, ~}."
                  (first form) (vikix-rule-verb-names)))
          (t form))))

;;; --- Defining rules ------------------------------------------------------------------------

(defun vikix-rule-options (body allowed)
  "Split a rule's BODY into its options (the keyword and value pairs it
starts with) and its forms: (values OPTIONS FORMS)."
  (let ((options '()))
    (loop while (keywordp (first body))
          do (let ((key (pop body)))
               (unless (member key allowed)
                 (error "~s isn't an option of a rule. The options: ~{~s~^, ~}." key allowed))
               (when (null body)
                 (error "The option ~s of a rule has no value." key))
               (setf options (append options (list key (pop body))))))
    (values options body)))

(defun vikix-rules-print (form)
  "FORM as it would be written."
  (let ((*package* (find-package :stumpwm))
        (*print-case* :downcase)
        (*print-pretty* nil)
        (*print-length* nil) (*print-level* nil))
    (prin1-to-string form)))

(defun vikix-rules-owner (file)
  "Whose rule it is, from where it was written."
  (let ((plugin (and (boundp '*vikix-plugin*) (symbol-value '*vikix-plugin*))))
    (cond (plugin (format nil "plugin ~a" plugin))
          ((null file) "live")
          ((and (boundp '*vikix-dir*)
                (eql 0 (search (namestring (symbol-value '*vikix-dir*)) (namestring file))))
           "Vikix")
          (t (file-namestring file)))))

(defun vikix-add-rule (&rest fields &key name text &allow-other-keys)
  "Add a rule, or replace the one known by the same name (or text)."
  (let* ((file (and *load-truename* (ignore-errors (namestring *load-truename*))))
         (rule (apply #'make-vikix-rule
                      :key (or name text)
                      :file file
                      :line (and file *vikix-load-line*)
                      :owner (vikix-rules-owner (and *load-truename* file))
                      fields))
         (old (member (vikix-rule-key rule) *vikix-rules* :key #'vikix-rule-key :test #'equal)))
    (if old
        (setf (first old) rule)
        (setf *vikix-rules* (append *vikix-rules* (list rule))))
    (clrhash *vikix-rule-floaters*)   ; who floats may have changed
    rule))

(defmacro when-window (&whole whole match &body body)
  "A rule for windows. See the top of rules.lisp:
(when-window (:class \"Firefox\") (workspace 2))."
  (vikix-rule-check-match match)
  (multiple-value-bind (options forms) (vikix-rule-options body '(:name :on :once))
    (let ((on (getf options :on :open))
          (name (getf options :name)))
      (unless (member on '(:open :focus :close))
        (error "A rule's :on is :open (a window appears), :focus or :close; this is ~s." on))
      (unless (or (null name) (stringp name))
        (error "A rule's :name is a string; this is ~s." name))
      (when (null forms)
        (error "This rule does nothing: after the matcher come its verbs, like (workspace 2)."))
      ;; The last (workspace ...) of a rule is where its window ends up.
      (let ((place (find "WORKSPACE" forms :key #'vikix-rule-form-verb :test #'equal :from-end t)))
        `(vikix-add-rule
          :name ,name
          :on ,on
          :once (and ,(getf options :once) t)
          :match ',match
          :test (lambda (w) (declare (ignorable w)) ,(vikix-rule-match-code match 'w))
          :body (lambda () ,@(mapcar #'vikix-rule-rewrite forms))
          :verbs ',(remove nil (mapcar #'vikix-rule-form-verb forms))
          ;; A window that opens is put on its workspace before it shows
          ;; (vikix-rules-placement), so the verb's arguments are needed early.
          :place ,(and place (eq on :open) `(lambda () (list ,@(rest place))))
          :text ,(vikix-rules-print whole))))))

(defun vikix-remove-rules (&key owner-prefix key)
  "Take rules out: those whose owner starts with OWNER-PREFIX (\"plugin \"),
or the one known by KEY. Returns how many went."
  (let ((before (length *vikix-rules*)))
    (setf *vikix-rules*
          (remove-if (lambda (rule)
                       (or (and owner-prefix (eql 0 (search owner-prefix (vikix-rule-owner rule))))
                           (and key (equal key (vikix-rule-key rule)))))
                     *vikix-rules*))
    (clrhash *vikix-rule-floaters*)
    (- before (length *vikix-rules*))))

;;; --- Running them ----------------------------------------------------------------------------

(defun vikix-rule-matches-p (rule window)
  "Does WINDOW match RULE? An error in the matcher (a :where of yours) is
the rule's failure, and no match."
  (handler-case (and (funcall (vikix-rule-test rule) window) t)
    (error (c) (vikix-rule-failed rule c) nil)))

(defun vikix-rule-failed (rule condition &optional backtrace)
  "Write the failure down, say so, and switch the rule off at the third."
  (incf (vikix-rule-failures rule))
  (setf (vikix-rule-last-error rule) (vikix-one-line condition))
  (vikix-error-report condition (format nil "in the rule ~a" (vikix-rule-text rule)) backtrace)
  (let ((off (>= (vikix-rule-failures rule) *vikix-rule-max-failures*)))
    (when off (setf (vikix-rule-on-p rule) nil))
    (vikix-say "^1Vikix: a rule failed~:[~; and is switched off until the next reload~]:^n~%~a~%~a"
               off (vikix-one-line (vikix-rule-text rule) 120) (vikix-one-line condition)))
  nil)

(defun vikix-run-rule (rule window event)
  "Run RULE's verbs for WINDOW. True when they all ran. Never an error."
  (if (> *vikix-rule-depth* 8)
      (vikix-rule-failed rule (make-condition 'simple-error
                                              :format-control "Rules setting each other off, more than eight deep: stopped here."
                                              :format-arguments '()))
      (let ((*vikix-rule-window* window)
            (*vikix-rule-event* event)
            (*vikix-rule-depth* (1+ *vikix-rule-depth*))
            (backtrace nil))
        (block run
          (handler-bind ((error (lambda (c)
                                  (setf backtrace (ignore-errors (backtrace-string)))
                                  (vikix-rule-failed rule c backtrace)
                                  (return-from run nil))))
            (funcall (vikix-rule-body rule))
            (incf (vikix-rule-runs rule))
            (setf (vikix-rule-last-run rule) (get-universal-time))
            (when window
              (push (vikix-rule-key rule) (gethash window *vikix-rule-notes*)))
            (when (vikix-rule-once rule)
              (setf (gethash (vikix-rule-key rule) *vikix-rules-once-done*) t))
            t)))))

(defun vikix-rule-ready-p (rule event)
  (and (vikix-rule-on-p rule)
       (eq (vikix-rule-on rule) event)
       (not (and (vikix-rule-once rule)
                 (gethash (vikix-rule-key rule) *vikix-rules-once-done*)))))

(defun vikix-rules-for (window event)
  "Run every rule that EVENT sets off and WINDOW matches, in order."
  (let ((*vikix-rule-event* event))
    ;; A copy: a rule may define or remove rules.
    (dolist (rule (copy-list *vikix-rules*))
      (when (and (vikix-rule-ready-p rule event)
                 (vikix-rule-matches-p rule window))
        (vikix-run-rule rule window event)))))

;; One named function a hook, each going through the table: never a hook a
;; rule. Named, so a reload doesn't add them twice. Windows that were there
;; before StumpWM started (a restart) are left where they are.

(defun vikix-rules-new-window (window)
  (unless *processing-existing-windows*
    (ignore-errors (vikix-rules-for window :open))))

(defun vikix-rules-focus-window (new old)
  (declare (ignore old))
  (when new
    (ignore-errors (vikix-rules-for new :focus))))

(defun vikix-rules-destroy-window (window)
  (ignore-errors (vikix-rules-for window :close)))

(remove-hook *new-window-hook* 'vikix-rules-new-window)
(add-hook *new-window-hook* 'vikix-rules-new-window)
(remove-hook *focus-window-hook* 'vikix-rules-focus-window)
(add-hook *focus-window-hook* 'vikix-rules-focus-window)
(remove-hook *destroy-window-hook* 'vikix-rules-destroy-window)
(add-hook *destroy-window-hook* 'vikix-rules-destroy-window)

;;; --- A window on its workspace before it shows ------------------------------------------------

;; StumpWM chooses a new window's workspace before showing it
;; (get-window-placement, from its own placement rules) and runs
;; *new-window-hook* afterwards. Moved from the hook, a window shows where
;; you are for a moment first. So a rule with (workspace ...) is asked here
;; too: StumpWM then opens the window there. The verb still runs from the
;; hook, and finds nothing left to do. StumpWM's own rules
;; (define-frame-preference) come first.

(defun vikix-rule-find-workspace (target)
  "The workspace TARGET names (a number or a name), or nil."
  (let ((groups (screen-groups (current-screen))))
    (cond ((integerp target) (find target groups :key #'group-number))
          ((stringp target) (find target groups :key #'group-name :test #'equal)))))

(defun vikix-rules-placement (window)
  "Where a rule sends WINDOW as it opens: (values WORKSPACE FOLLOW), or nil."
  (let ((*vikix-rule-event* :open)
        (*vikix-rule-window* window))
    (dolist (rule *vikix-rules*)
      (when (and (vikix-rule-place rule)
                 (vikix-rule-ready-p rule :open)
                 (ignore-errors (funcall (vikix-rule-test rule) window)))
        (destructuring-bind (target &key follow) (funcall (vikix-rule-place rule))
          (let ((group (vikix-rule-find-workspace target)))
            ;; The last rule to act wins, as it does from the hook.
            (when group
              (return-from vikix-rules-placement
                (let ((later (ignore-errors (vikix-rules-placement-after rule window))))
                  (if (first later)
                      (values (first later) (second later))
                      (values group follow)))))))))))

(defun vikix-rules-placement-after (rule window)
  "The same, among the rules after RULE: (WORKSPACE FOLLOW) or nil."
  (let ((*vikix-rules* (rest (member rule *vikix-rules*))))
    (multiple-value-list (vikix-rules-placement window))))

(defun vikix-rules-get-window-placement (original screen window)
  (multiple-value-bind (group frame raise) (funcall original screen window)
    (ignore-errors
     (unless (gethash window *vikix-rule-opened-in*)
       (setf (gethash window *vikix-rule-opened-in*) (screen-current-group screen))))
    (if (or group *processing-existing-windows*)
        (values group frame raise)
        (multiple-value-bind (to follow)
            (ignore-errors (vikix-rules-placement window))
          (if (and to (not (eq to (screen-current-group screen))))
              (values to nil (and follow t))
              (values group frame raise))))))

(sb-int:unencapsulate 'get-window-placement 'vikix-rules)
(sb-int:encapsulate 'get-window-placement 'vikix-rules 'vikix-rules-get-window-placement)

;;; --- Does a rule float this window? (for Viri) -----------------------------------------------

(defun vikix-rules-float-p (window)
  "True when a rule floats WINDOW as it opens (float, sticky, dialog). Asked
before the window is placed (viri.lisp: such a window isn't a column), and
answered the same for the window's whole life."
  (let ((known (gethash window *vikix-rule-floaters*)))
    (if known
        (eq known :yes)
        (let* ((*vikix-rule-event* :open)
               (floats (and (some (lambda (rule)
                                    (and (vikix-rule-ready-p rule :open)
                                         (intersection '("FLOAT" "STICKY" "DIALOG") (vikix-rule-verbs rule)
                                                       :test #'equal)
                                         (ignore-errors (funcall (vikix-rule-test rule) window))))
                                  *vikix-rules*)
                            t)))
          (setf (gethash window *vikix-rule-floaters*) (if floats :yes :no))
          floats))))

;;; --- The first verbs ---------------------------------------------------------------------------
;;; Each is safe to run twice, and checks before it acts.

(defun vikix-rule-length (value whole what)
  "VALUE as pixels: a whole number is pixels, \"65%\" a share of WHOLE."
  (cond ((null value) nil)
        ((integerp value) value)
        ((and (stringp value)
              (ppcre:scan "^\\s*\\d+(\\.\\d+)?\\s*%\\s*$" value))
         (let ((share (let ((*read-default-float-format* 'double-float) (*read-eval* nil))
                        (read-from-string (string-trim " %" value)))))
           (floor (* share whole) 100)))
        (t (error "~a is ~s. A size or a place is a whole number of pixels, or a share of the monitor like \"65%\"." what value))))

(defun vikix-rule-float-it (win)
  "Make WIN float if it is a tile; true when it floats afterwards."
  (let ((group (window-group win)))
    (when (and (typep win 'tile-window) (typep group 'tile-group))
      (when (fboundp 'vikix-titlebar-remove)
        (funcall 'vikix-titlebar-remove win))
      (float-window win group))
    (typep win 'float-window)))

(define-rule-verb workspace (target &key follow)
  "Send the window to a workspace, by number or name; :follow t goes along."
  (let* ((win (rule-window))
         (group (or (vikix-rule-find-workspace target)
                    (error "There is no workspace ~s." target))))
    (unless (eq (window-group win) group)
      (move-window-to-group win group))
    (when (and follow (not (eq (current-group) group)))
      (switch-to-group group)
      (group-focus-window group win))
    group))

(defun vikix-rule-area (head)
  "HEAD's part of the screen that windows have, without the bar:
(values x y width height)."
  (let* ((ml (head-mode-line head))
         (bar (if ml (mode-line-height ml) 0))
         (top (and ml (not (eq *mode-line-position* :bottom)))))
    (values (head-x head)
            (+ (head-y head) (if top bar 0))
            (head-width head)
            (- (head-height head) bar))))

(defparameter *vikix-rule-float-gap* 8
  "The space, in pixels, between a floating window put at an edge or a
corner and that edge.")

(define-rule-verb float (&key width height x y corner)
  "Float the window: :width and :height (pixels, or \"65%\" of the monitor below the bar; 60% when not given), in the middle, or at a :corner, or at :x and :y."
  (let ((win (rule-window)))
    (unless (member corner '(nil :centre :center :top-left :top-right :bottom-left :bottom-right
                             :top :bottom :left :right))
      (error "A float's :corner is one of :top-left, :top-right, :bottom-left, :bottom-right, :top, :bottom, :left, :right, :centre; this is ~s." corner))
    (when (vikix-rule-float-it win)
      (multiple-value-bind (ax ay aw ah) (vikix-rule-area (window-head win))
        ;; The sizes are the whole window's, StumpWM's strip at its top
        ;; and its border included.
        (let* ((w (min aw (max 60 (or (vikix-rule-length width aw "A float's :width") (floor (* 60 aw) 100)))))
               (h (min ah (max 60 (or (vikix-rule-length height ah "A float's :height") (floor (* 60 ah) 100)))))
               (px (vikix-rule-length x aw "A float's :x"))
               (py (vikix-rule-length y ah "A float's :y"))
               (gap *vikix-rule-float-gap*)
               (fx (or px (ecase corner
                            ((nil :centre :center :top :bottom) (floor (- aw w) 2))
                            ((:top-left :bottom-left :left) gap)
                            ((:top-right :bottom-right :right) (- aw w gap)))))
               (fy (or py (ecase corner
                            ((nil :centre :center :left :right) (floor (- ah h) 2))
                            ((:top-left :top-right :top) gap)
                            ((:bottom-left :bottom-right :bottom) (- ah h gap))))))
          (float-window-move-resize win
                                    :x (+ ax (max 0 fx))
                                    :y (+ ay (max 0 fy))
                                    :width (max 1 (- w (* 2 *float-window-border*)))
                                    :height (max 1 (- h *float-window-title-height* *float-window-border*))))))
    win))

(define-rule-verb tile ()
  "Put a floating window back in the tiles."
  (let* ((win (rule-window))
         (group (window-group win)))
    (when (and (typep win 'float-window) (typep group 'tile-group))
      (remhash win *vikix-dialog-windows*)
      (unfloat-window win group))
    win))

(define-rule-verb fullscreen ()
  "Make the window fill the whole screen."
  (let ((win (rule-window)))
    (unless (window-fullscreen win)
      (update-fullscreen win 1))
    win))

(define-rule-verb sticky ()
  "Keep the window on every workspace. It floats: a tiled window kept everywhere ends the desktop at the next change of workspace."
  (let ((win (rule-window)))
    (unless (member win *always-show-windows*)
      (unless (eq (window-group win) (current-group))
        (error "sticky: the window isn't on the workspace in view (put sticky before workspace, or leave workspace out)."))
      (unless (vikix-rule-float-it win)
        (error "sticky: the window can't float on this workspace."))
      (always-show-window win (window-screen win)))
    win))

(define-rule-verb dialog ()
  "Treat the window as a dialog: floating, in the middle, kept in front of the tiles."
  (let ((win (rule-window)))
    (setf (gethash win *vikix-dialog-windows*) t)
    (let ((was-tile (typep win 'tile-window)))
      (when (and (vikix-rule-float-it win) was-tile)
        (when (fboundp 'vikix-centre-window) (funcall 'vikix-centre-window win))
        (focus-window win)))
    (when (fboundp 'vikix-raise-dialogs) (funcall 'vikix-raise-dialogs))
    win))

(define-rule-verb title (name)
  "Name the window: its title bar and the bar show that instead of its own title."
  (let ((win (rule-window)))
    (unless (equal (window-user-title win) name)
      (setf (window-user-title win) name)
      (when (fboundp 'vikix-titlebar-redraw) (funcall 'vikix-titlebar-redraw win))
      (update-all-mode-lines))
    win))

(define-rule-verb focus ()
  "Go to the window, on whichever workspace it is."
  (let ((win (rule-window)))
    (unless (eq win (current-window))
      (focus-all win))
    win))

(define-rule-verb run (shell-command)
  "Run a shell command."
  (run-shell-command shell-command))

(define-rule-verb command (stumpwm-command)
  "Run a StumpWM command, as a key would: \"vikix-grid\", \"gnext\"."
  (run-commands stumpwm-command))

(define-rule-verb notify (text &optional (body ""))
  "Show a notification."
  (run-shell-command (format nil "notify-send -a Vikix -- ~a ~a"
                             (vikix-shell-quote (princ-to-string text))
                             (vikix-shell-quote (princ-to-string body)))))

(define-rule-verb say (text)
  "Show a message in the middle of the screen, as StumpWM does."
  (message "~a" text))

(define-rule-verb open-project (name)
  "Open one of your projects: a terminal in its folder, its log in Emacs (vikix project open)."
  (run-shell-command (format nil "vikix project open ~a" (vikix-shell-quote (princ-to-string name)))))

(define-rule-verb theme (name)
  "Switch the theme (vikix theme NAME)."
  (run-shell-command (format nil "vikix theme ~a" (vikix-shell-quote (princ-to-string name)))))

;;; --- Rules for the time, the battery, login and workspaces --------------------------------------
;;;
;;;   (at "09:00" :weekdays (open-project "vikix"))
;;;   (each 30 :minutes (run "vikix-wallpaper next"))
;;;   (when-battery-below 20 (notify "Battery at 20%: charger?"))
;;;   (when-charging (say "On the charger"))      (when-on-battery ...)
;;;   (at-login (run "syncthing --no-browser"))
;;;   (when-workspace 3 (command "vikix-grid"))
;;;
;;; They are rules like the others, in the same table: listed, wrapped,
;;; switched off at the third failure. They have no window. One ticker runs
;;; them all, every 30 seconds (whole numbers: a float as a timer's delay
;;; stops StumpWM's event loop), never a timer a rule.
;;;
;;; No new slot in the structure for them: redefining a structure in a
;;; running desktop asks questions at the reload that brings it. What sets
;;; such a rule off is its `on` (:at, :each, :battery-below, :charging,
;;; :on-battery, :login, :workspace), its settings are in `match`, and what
;;; it remembers is kept in tables by its key, as :once is.

(defvar *vikix-rules-now* 'get-universal-time
  "The clock the rules read: a function returning a universal time. Tests
put their own here, and step through a day in a second.")

(defvar *vikix-rules-battery* 'vikix-rules-read-battery
  "How the rules read the battery: a function returning the charge (0 to
100) and, second, true when on the charger; nil without a battery.")

(defparameter *vikix-rules-late* 3600
  "An `at` rule whose time passed while the laptop slept still runs on
waking when it is less than this many seconds late (:late t: however late,
that day; :late nil: only on time).")

(defvar *vikix-rules-ran* (make-hash-table :test 'equal)
  "What timed rules remember, kept in ~/.local/state/vikix/rules/ran too:
\"at HASH HH:MM\" to the day it last ran (YYYYMMDD, or \"seen\"), and
\"each HASH\" to when it last ran (a universal time).")
(defvar *vikix-rules-ran-read* nil "True once the file has been read.")
(defvar *vikix-rules-battery-ran* (make-hash-table :test 'equal)
  "The when-battery-below rules that have run and wait for the charge to
be above their mark, or for the charger, before they can run again.")
(defvar *vikix-rules-power* nil
  "How the laptop was powered at the last tick: :charger or :battery.")
(defvar *vikix-rules-login-ran* '()
  "Without a screen (the tests): the at-login rules that have run. With
one, the root window's property _VIKIX_LOGIN_RULES holds them: it lasts as
long as the X server does, which is one login.")
(defvar *vikix-rules-timer* nil "The ticker.")

(defun vikix-rule-hash (text)
  "A short, lasting name for a rule's key (FNV-1a, 64 bits, as hex)."
  (let ((h #xcbf29ce484222325))
    (loop for c across text
          do (setf h (logand (* (logxor h (char-code c)) #x100000001b3) #xffffffffffffffff)))
    (format nil "~(~16,'0x~)" h)))

(defun vikix-rules-now () (funcall *vikix-rules-now*))

;;; What they remember, on disk: a reload or a restart of StumpWM at 09:05
;;; mustn't run the 09:00 rule again.

(defun vikix-rules-ran-file ()
  (merge-pathnames "rules/ran" (vikix-state-dir)))

(defun vikix-rules-read-ran ()
  (unless *vikix-rules-ran-read*
    (setf *vikix-rules-ran-read* t)
    (ignore-errors
     (with-open-file (in (vikix-rules-ran-file) :if-does-not-exist nil :external-format :utf-8)
       (when in
         (loop for line = (read-line in nil)
               while line
               do (let ((tab (position #\Tab line)))
                    (when tab
                      (setf (gethash (subseq line 0 tab) *vikix-rules-ran*)
                            (subseq line (1+ tab)))))))))))

(defun vikix-rules-write-ran ()
  "Write what the rules there are now remember; what a rule that has gone
remembered goes with it."
  (ignore-errors
   (let ((file (vikix-rules-ran-file))
         (hashes (mapcar (lambda (rule) (vikix-rule-hash (vikix-rule-key rule))) *vikix-rules*)))
     (ensure-directories-exist file)
     (with-open-file (out file :direction :output :if-exists :supersede :external-format :utf-8)
       (maphash (lambda (key value)
                  (let ((hash (second (ppcre:split " " key))))
                    (if (member hash hashes :test #'equal)
                        (format out "~a~c~a~%" key #\Tab value)
                        (remhash key *vikix-rules-ran*))))
                *vikix-rules-ran*)))))

;;; Defining them

(defun vikix-rule-timed-expansion (whole on settings body)
  "The Lisp that adds a rule with no window: ON sets it off, SETTINGS (a
list of keywords and values) say when, BODY is its options (:name) and verbs."
  (multiple-value-bind (options forms) (vikix-rule-options body '(:name))
    (let ((name (getf options :name)))
      (unless (or (null name) (stringp name))
        (error "A rule's :name is a string; this is ~s." name))
      (when (null forms)
        (error "This rule does nothing: after ~(~a~) and its settings come its verbs, like (notify \"...\")." (first whole)))
      `(vikix-add-rule
        :name ,name
        :on ,on
        :match ',settings
        :body (lambda () ,@(mapcar #'vikix-rule-rewrite forms))
        :verbs ',(remove nil (mapcar #'vikix-rule-form-verb forms))
        :text ,(vikix-rules-print whole)))))

(defun vikix-rule-parse-time (time)
  "\"09:00\" as (9 0); an error for anything else."
  (multiple-value-bind (match parts)
      (and (stringp time) (ppcre:scan-to-strings "^([01]?\\d|2[0-3]):([0-5]\\d)$" time))
    (unless match
      (error "A rule's time is written \"09:00\" or \"17:30\", on the 24-hour clock; this is ~s." time))
    (list (parse-integer (aref parts 0)) (parse-integer (aref parts 1)))))

(defparameter *vikix-rule-days* '(:mon :tue :wed :thu :fri :sat :sun)
  "The days, in the order Lisp counts them (Monday is 0).")

(defmacro at (&whole whole time &body body)
  "A rule for a time of day: (at \"09:00\" :weekdays (open-project \"vikix\")).
TIME is \"HH:MM\", or a list of them. Then, in any order: :weekdays,
:weekends or :on (:mon :thu); :late nil (never late) or :late t (however
late, that day; else up to an hour late, after a sleep); :name \"...\"."
  (let ((times (mapcar (lambda (time) (vikix-rule-parse-time time) time)
                       (if (listp time) time (list time))))
        (days nil) (late :default) (rest body) (kept '()))
    (when (null times)
      (error "This rule has no time: (at \"09:00\" ...)."))
    (loop while (keywordp (first rest))
          do (let ((key (pop rest)))
               (case key
                 (:weekdays (setf days '(:mon :tue :wed :thu :fri)))
                 (:weekends (setf days '(:sat :sun)))
                 (:on (let ((value (pop rest)))
                        (setf days (if (listp value) value (list value)))
                        (unless (and days (subsetp days *vikix-rule-days*))
                          (error "A rule's :on is a day or a list of days, from :mon :tue :wed :thu :fri :sat :sun; this is ~s." value))))
                 (:late (let ((value (pop rest)))
                          (unless (member value '(nil t))
                            (error "A rule's :late is t (however late, that day) or nil (never late); this is ~s." value))
                          (setf late value)))
                 (:name (setf kept (list :name (pop rest))))
                 (t (error "~s isn't an option of an at rule. The options: :weekdays, :weekends, :on, :late, :name." key)))))
    (vikix-rule-timed-expansion whole :at (list :times times :days days :late late)
                                (append kept rest))))

(defmacro each (&whole whole count unit &body body)
  "A rule that repeats: (each 30 :minutes (run \"vikix-wallpaper next\")).
UNIT is :minutes or :hours. It first runs that long after it is first
seen, and afterwards that long after it last ran (once, after a sleep)."
  (unless (and (integerp count) (plusp count))
    (error "A rule repeats each whole number of minutes or hours, 1 or more; this is ~s." count))
  (let ((seconds (case unit
                   ((:minute :minutes) (* 60 count))
                   ((:hour :hours) (* 3600 count))
                   (t (error "A rule repeats each so many :minutes or :hours; this is ~s." unit)))))
    (vikix-rule-timed-expansion whole :each (list :seconds seconds) body)))

(defmacro when-battery-below (&whole whole percent &body body)
  "A rule for a low battery: (when-battery-below 20 (notify \"Charger?\")).
It runs once as the charge goes under PERCENT off the charger, and is
ready again once the charge is back above it, or the charger is in."
  (unless (and (integerp percent) (< 0 percent 100))
    (error "A battery rule's mark is a whole number of percent, from 1 to 99; this is ~s." percent))
  (vikix-rule-timed-expansion whole :battery-below (list :percent percent) body))

(defmacro when-charging (&whole whole &body body)
  "A rule for the charger going in: (when-charging (say \"Charging\"))."
  (vikix-rule-timed-expansion whole :charging '() body))

(defmacro when-on-battery (&whole whole &body body)
  "A rule for the charger coming out: (when-on-battery (notify \"On battery\"))."
  (vikix-rule-timed-expansion whole :on-battery '() body))

(defmacro at-login (&whole whole &body body)
  "A rule that runs once a login: (at-login (run \"syncthing --no-browser\")).
Not at a reload, nor when StumpWM alone starts again. One added during a
login runs at the reload that brings it, once."
  (vikix-rule-timed-expansion whole :login '() body))

(defmacro when-workspace (&whole whole workspace &body body)
  "A rule for going to a workspace: (when-workspace 3 (command \"vikix-grid\")).
WORKSPACE is a number, a name, or a list of them."
  (unless (or (integerp workspace) (stringp workspace)
              (and (consp workspace) (every (lambda (w) (or (integerp w) (stringp w))) workspace)))
    (error "A workspace rule names a workspace by number or name, or a list of them; this is ~s." workspace))
  (vikix-rule-timed-expansion whole :workspace (list :workspaces (if (listp workspace) workspace (list workspace)))
                              body))

;;; Running them

(defun vikix-rules-on (on)
  "The rules ON sets off that are switched on."
  (remove-if-not (lambda (rule) (and (eq (vikix-rule-on rule) on) (vikix-rule-on-p rule)))
                 *vikix-rules*))

(defun vikix-rules-day (time)
  "TIME's day as \"YYYYMMDD\", its day of the week (:mon ...), and the
universal time of HOUR:MINUTE on it (a function of the two)."
  (multiple-value-bind (s mi h d mo y dow) (decode-universal-time time)
    (declare (ignore s mi h))
    (values (format nil "~4,'0d~2,'0d~2,'0d" y mo d)
            (nth dow *vikix-rule-days*)
            (lambda (hour minute) (encode-universal-time 0 minute hour d mo y)))))

(defun vikix-rules-run-clock ()
  "The at and each rules that are due. True when something was remembered."
  (vikix-rules-read-ran)
  (let ((now (vikix-rules-now)) (changed nil))
    (multiple-value-bind (today weekday at-time) (vikix-rules-day now)
      (dolist (rule (vikix-rules-on :at))
        (destructuring-bind (&key times days late) (vikix-rule-match rule)
          (dolist (time times)
            (let* ((key (format nil "at ~a ~a" (vikix-rule-hash (vikix-rule-key rule)) time))
                   (last (gethash key *vikix-rules-ran*))
                   (due (apply at-time (vikix-rule-parse-time time)))
                   (passed (- now due)))
              (cond
                ;; A rule seen for the first time doesn't run for a time
                ;; already gone by: only what it missed while it existed.
                ((null last)
                 (setf (gethash key *vikix-rules-ran*) (if (>= passed 0) today "seen")
                       changed t))
                ((or (equal last today) (minusp passed)))
                ((and days (not (member weekday days))))
                (t
                 (setf (gethash key *vikix-rules-ran*) today
                       changed t)
                 (when (<= passed (case late ((t) 86400) ((nil) 90) (t *vikix-rules-late*)))
                   (vikix-run-rule rule nil :at))))))))
      (dolist (rule (vikix-rules-on :each))
        (let* ((key (format nil "each ~a" (vikix-rule-hash (vikix-rule-key rule))))
               (last (ignore-errors (parse-integer (gethash key *vikix-rules-ran* "")))))
          (cond ((or (null last) (> last now))      ; new, or the clock went back
                 (setf (gethash key *vikix-rules-ran*) (princ-to-string now)
                       changed t))
                ((>= (- now last) (getf (vikix-rule-match rule) :seconds))
                 (setf (gethash key *vikix-rules-ran*) (princ-to-string now)
                       changed t)
                 (vikix-run-rule rule nil :each))))))
    (when changed (vikix-rules-write-ran))
    changed))

(defun vikix-rules-read-battery ()
  "The first battery's charge and whether the charger is in, from sysfs as
the bar reads them; nil without a battery."
  (let ((battery (first (directory #p"/sys/class/power_supply/BAT*/"))))
    (when battery
      (flet ((line (name)
               (ignore-errors
                (with-open-file (in (merge-pathnames name battery))
                  (string-trim '(#\Space #\Newline) (read-line in nil ""))))))
        (let ((level (ignore-errors (parse-integer (line "capacity"))))
              (status (line "status")))
          (and level
               (values level (not (equal status "Discharging")))))))))

(defun vikix-rules-run-power ()
  "The battery and charger rules that are due. The battery isn't read
when no rule asks about it."
  (multiple-value-bind (level charger)
      (and (some (lambda (rule) (member (vikix-rule-on rule) '(:battery-below :charging :on-battery)))
                 *vikix-rules*)
           (funcall *vikix-rules-battery*))
    (when level
      (let ((power (if charger :charger :battery))
            (before *vikix-rules-power*))
        (setf *vikix-rules-power* power)
        ;; The first look only notes how it is; a change is what sets these off.
        (when (and before (not (eq before power)))
          (dolist (rule (vikix-rules-on (if charger :charging :on-battery)))
            (vikix-run-rule rule nil (vikix-rule-on rule))))
        (dolist (rule (vikix-rules-on :battery-below))
          (let ((key (vikix-rule-key rule))
                (mark (getf (vikix-rule-match rule) :percent)))
            (cond ((or charger (>= level mark))
                   (remhash key *vikix-rules-battery-ran*))
                  ((not (gethash key *vikix-rules-battery-ran*))
                   (setf (gethash key *vikix-rules-battery-ran*) t)
                   (vikix-run-rule rule nil :battery-below)))))))))

;;; Once a login. The X server lives exactly as long as a login does, so
;;; what has run is noted on its root window: a reload, or StumpWM starting
;;; again in the same login, finds the note; the next login doesn't.

(defun vikix-rules-login-root ()
  (and (boundp '*screen-list*) *screen-list*
       (screen-root (first *screen-list*))))

(defun vikix-rules-login-ran ()
  "The hashes of the at-login rules that have run in this login."
  (let ((root (vikix-rules-login-root)))
    (if root
        (ppcre:split " " (map 'string #'code-char
                              (or (xlib:get-property root :_VIKIX_LOGIN_RULES) '())))
        *vikix-rules-login-ran*)))

(defun vikix-rules-login-note (hashes)
  (let ((root (vikix-rules-login-root))
        (hashes (last hashes 200)))
    (if root
        (xlib:change-property root :_VIKIX_LOGIN_RULES
                              (map 'list #'char-code (format nil "~{~a~^ ~}" hashes))
                              :string 8)
        (setf *vikix-rules-login-ran* hashes))))

(defun vikix-rules-run-login ()
  "The at-login rules that haven't run in this login."
  (let ((rules (vikix-rules-on :login)))
    (when rules
      (let ((ran (vikix-rules-login-ran)))
        (dolist (rule rules)
          (let ((hash (vikix-rule-hash (vikix-rule-key rule))))
            (unless (member hash ran :test #'equal)
              ;; Noted first: a rule that fails isn't tried at every tick.
              (setf ran (append ran (list hash)))
              (vikix-rules-login-note ran)
              (vikix-run-rule rule nil :login))))))))

(defun vikix-rules-tick ()
  "What the ticker does: the rules for login, the clock and the battery
that are due. Never an error: this runs in StumpWM's timer."
  (ignore-errors (vikix-rules-run-login))
  (ignore-errors (vikix-rules-run-clock))
  (ignore-errors (vikix-rules-run-power))
  nil)

(defun vikix-rules-focus-group (new old)
  (declare (ignore old))
  (ignore-errors
   (dolist (rule (vikix-rules-on :workspace))
     (when (some (lambda (w) (if (integerp w)
                                 (eql w (group-number new))
                                 (equal w (group-name new))))
                 (getf (vikix-rule-match rule) :workspaces))
       (vikix-run-rule rule nil :workspace)))))

(remove-hook *focus-group-hook* 'vikix-rules-focus-group)
(add-hook *focus-group-hook* 'vikix-rules-focus-group)

;; The ticker: 5 seconds after the files are loaded (so the rules of
;; rules.lisp and user.lisp are there), then every 30. Only on a desktop:
;; without a screen there is no event loop to run it.
(ignore-errors
 (when (and *vikix-rules-timer* (timer-p *vikix-rules-timer*))
   (cancel-timer *vikix-rules-timer*)))
(setf *vikix-rules-timer*
      (and (boundp '*screen-list*) *screen-list*
           (run-with-timer 5 30 'vikix-rules-tick)))

;;; --- Seeing them ---------------------------------------------------------------------------------

(defun vikix-rules-lines ()
  "A line for each rule: its number, on or off, whose it is, how often it
ran, and the rule."
  (loop for rule in *vikix-rules*
        for n from 1
        collect (format nil "~2d ~:[off~;on ~] ~12a ~3d×  ~a~@[   ^1(~a)^n~]"
                        n (vikix-rule-on-p rule) (vikix-rule-owner rule) (vikix-rule-runs rule)
                        (vikix-one-line (vikix-rule-text rule) 110)
                        (vikix-rule-last-error rule))))

(defcommand vikix-rules () ()
  "Show the desktop's rules: which are on, whose each is, how often it ran."
  (if *vikix-rules*
      (message "Rules (~~/.stumpwm.d/rules.lisp, user.lisp)~%~{~a~^~%~}" (vikix-rules-lines))
      (message "No rules yet. One looks like this, in ~~/.stumpwm.d/rules.lisp or user.lisp:~%(when-window (:class \"Firefox\") (workspace 2))")))
