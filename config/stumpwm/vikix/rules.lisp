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
  "Each window, and the rules that ran for it, newest first: (KEY EVENT TIME
FAILURE), FAILURE the error's words or nil. `vikix rules why` reads them.")
(defparameter *vikix-rule-notes-kept* 12
  "How many of them a window keeps.")
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

(defun vikix-rule-note (rule window event &optional failure)
  "Note on WINDOW that RULE ran for it (or failed, with FAILURE's words).
One note a rule and what set it off, its latest: a rule on :focus runs at
every look, and would push out what happened when the window opened."
  (when window
    (let* ((key (vikix-rule-key rule))
           (notes (cons (list key event (get-universal-time)
                              (and failure (vikix-one-line failure)))
                        (remove-if (lambda (note)
                                     (and (consp note) (equal (first note) key) (eq (second note) event)))
                                   (gethash window *vikix-rule-notes*)))))
      (setf (gethash window *vikix-rule-notes*)
            (subseq notes 0 (min (length notes) *vikix-rule-notes-kept*))))))

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
                                  (ignore-errors (vikix-rule-note rule window event c))
                                  (return-from run nil))))
            (funcall (vikix-rule-body rule))
            (incf (vikix-rule-runs rule))
            (setf (vikix-rule-last-run rule) (get-universal-time))
            (vikix-rule-note rule window event)
            ;; For `vikix day` (day.lisp, loaded later). Not at every change
            ;; of focus: that would be most of the file.
            (when (and (not (eq event :focus)) (fboundp 'vikix-day-rule-ran))
              (ignore-errors (funcall 'vikix-day-rule-ran rule)))
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

(define-rule-verb float (&key width height x y corner own)
  "Float the window: :width and :height (pixels, or \"65%\" of the monitor below the bar; 60% when not given), in the middle, or at a :corner, or at :x and :y. :own t only floats it, at the size and place it asks for itself."
  (let ((win (rule-window)))
    (unless (member corner '(nil :centre :center :top-left :top-right :bottom-left :bottom-right
                             :top :bottom :left :right))
      (error "A float's :corner is one of :top-left, :top-right, :bottom-left, :bottom-right, :top, :bottom, :left, :right, :centre; this is ~s." corner))
    (when (and own (or width height x y corner))
      (error "A float with :own t keeps the window's own size and place: it takes no :width, :height, :x, :y or :corner."))
    (when (and (vikix-rule-float-it win) (not own))
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
  ;; The same ticker writes down what has the screen (day.lisp, loaded later).
  (when (fboundp 'vikix-day-tick)
    (ignore-errors (funcall 'vikix-day-tick)))
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

;;; --- Seeing and steering them ------------------------------------------------------------------
;;;
;;; `vikix rules` in a terminal (bin/vikix-rules, which only asks here) and
;;; Super+m, Rules: the list, a rule off or on, why a window is where it
;;; is, what the rules would do with the windows open now, and doing it.
;;; vikix-rules-list and vikix-rules-why answer with data, for the MCP
;;; server's read-only `rules` tool; the -text functions with lines to read.

(defun vikix-rule-off-reason (rule)
  "Why RULE is off: :failures (switched off at the third), :you, or nil: it's on."
  (cond ((vikix-rule-on-p rule) nil)
        ((>= (vikix-rule-failures rule) *vikix-rule-max-failures*) :failures)
        (t :you)))

(defun vikix-rule-from (rule)
  "Where RULE was written: \"rules.lisp:3\", \"Vikix windows.lisp:40\",
\"plugin inbox plugin.lisp:12\", \"live\" (typed into the running desktop)."
  (let ((owner (vikix-rule-owner rule))
        (file (and (vikix-rule-file rule) (file-namestring (vikix-rule-file rule))))
        (line (vikix-rule-line rule)))
    (cond ((null file) owner)
          ((equal owner file) (format nil "~a~@[:~d~]" file line))
          (t (format nil "~a ~a~@[:~d~]" owner file line)))))

(defun vikix-rules-when (time)
  "TIME for a person: \"09:14\" when it is today, \"3 Oct 09:14\" before, \"never\" for nil."
  (if (null time)
      "never"
      (multiple-value-bind (s mi h d mo y) (decode-universal-time time)
        (declare (ignore s))
        (multiple-value-bind (s2 mi2 h2 d2 mo2 y2) (decode-universal-time (get-universal-time))
          (declare (ignore s2 mi2 h2))
          (if (and (= d d2) (= mo mo2) (= y y2))
              (format nil "~2,'0d:~2,'0d" h mi)
              (format nil "~d ~a ~2,'0d:~2,'0d" d
                      (nth (1- mo) '("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
                      h mi))))))

(defun vikix-rules-list ()
  "The rules as data, in order: a list of keywords and values for each."
  (loop for rule in *vikix-rules*
        for n from 1
        collect (list :number n
                      :on (and (vikix-rule-on-p rule) t)
                      :off (vikix-rule-off-reason rule)
                      :name (vikix-rule-name rule)
                      :text (vikix-rule-text rule)
                      :from (vikix-rule-from rule)
                      :owner (vikix-rule-owner rule)
                      :file (vikix-rule-file rule)
                      :line (vikix-rule-line rule)
                      :event (vikix-rule-on rule)
                      :runs (vikix-rule-runs rule)
                      :last-run (vikix-rule-last-run rule)
                      :failures (vikix-rule-failures rule)
                      :last-error (vikix-rule-last-error rule))))

(defun vikix-rule-number (rule)
  "RULE's number in the list, from 1; nil for one that isn't there any more."
  (let ((at (position rule *vikix-rules*)))
    (and at (1+ at))))

(defun vikix-rule-called (what)
  "The rule WHAT names: its number in the list, its :name, or words that
only its text has. An error says what is wrong with WHAT."
  (let* ((what (string-trim " " (princ-to-string (or what ""))))
         (number (and (plusp (length what)) (every #'digit-char-p what)
                      (parse-integer what))))
    (cond ((zerop (length what))
           (error "Which rule? Give its number in the list (vikix rules), or its name."))
          (number
           (or (and (plusp number) (nth (1- number) *vikix-rules*))
               (error "There is no rule ~d: there are ~d (vikix rules lists them)."
                      number (length *vikix-rules*))))
          ((find what *vikix-rules* :key #'vikix-rule-name :test #'equal))
          (t
           (let ((found (remove-if-not (lambda (rule) (search what (vikix-rule-text rule) :test #'char-equal))
                                       *vikix-rules*)))
             (cond ((null found)
                    (error "No rule is called ~s, or has it in its text (vikix rules lists them)." what))
                   ((rest found)
                    (error "~d rules have ~s in them (~{~d~^, ~}): say which by its number."
                           (length found) what (mapcar #'vikix-rule-number found)))
                   (t (first found))))))))

(defun vikix-rule-switch (rule on)
  "Switch RULE on or off. Off lasts until the next reload, which reads the
files again; on gives a rule that failed its three tries back."
  (setf (vikix-rule-on-p rule) (and on t))
  (when on
    (setf (vikix-rule-failures rule) 0
          (vikix-rule-last-error rule) nil))
  (clrhash *vikix-rule-floaters*)
  rule)

(defun vikix-rule-listed (rule &optional (width 110))
  "RULE as a line of the list: its number, on or off, how often it ran and
when last, the rule, where it's from."
  (format nil "~2d  ~:[off~;on ~]  ~3d×  ~12a  ~a   ~a"
          (or (vikix-rule-number rule) 0) (vikix-rule-on-p rule) (vikix-rule-runs rule)
          (vikix-rules-when (vikix-rule-last-run rule))
          (vikix-one-line (vikix-rule-text rule) width)
          (vikix-rule-from rule)))

(defun vikix-rule-state-line (rule)
  "What there is to say under RULE's line: why it's off, its last failure; or nil."
  (let ((off (vikix-rule-off-reason rule))
        (failure (vikix-rule-last-error rule)))
    (cond ((eq off :failures)
           (format nil "switched off after ~d failures, until the next reload (vikix rules on ~d): ~a"
                   (vikix-rule-failures rule) (vikix-rule-number rule) failure))
          ((eq off :you)
           (format nil "switched off by you, until the next reload (vikix rules on ~d)~@[; it last failed: ~a~]"
                   (vikix-rule-number rule) failure))
          (failure (format nil "failed ~d time~:p, last: ~a" (vikix-rule-failures rule) failure)))))

(defun vikix-rules-text ()
  "The list, for a terminal."
  (if (null *vikix-rules*)
      (format nil "No rules yet. One looks like this, in ~~/.stumpwm.d/rules.lisp or user.lisp:~%  (when-window (:class \"Firefox\") (workspace 2))~%vikix rules verbs lists what a rule can match and do.")
      (with-output-to-string (out)
        (format out " #  is   ran   last          the rule, and where it is written~%")
        (dolist (rule *vikix-rules*)
          (format out "~a~%" (vikix-rule-listed rule 200))
          (let ((state (vikix-rule-state-line rule)))
            (when state (format out "        ~a~%" state))))
        (format out "How often and when: since the last reload."))))

;;; Why a window is where it is

(defun vikix-rule-for-windows-p (rule)
  (and (member (vikix-rule-on rule) '(:open :focus :close)) t))

(defun vikix-rule-fits-p (rule window)
  "Does WINDOW match RULE, as it is now? Only looking: a matcher of yours
that fails is no match here, and no failure of the rule."
  (let ((*vikix-rule-event* :look)
        (*vikix-rule-window* window))
    (and (vikix-rule-for-windows-p rule)
         (ignore-errors (funcall (vikix-rule-test rule) window))
         t)))

(defun vikix-rules-why (window)
  "What the rules did with WINDOW, and what else matches it:
 (values RAN WAITING). RAN, oldest first: (TIME EVENT RULE KEY FAILURE), RULE
nil for one that isn't there any more. WAITING: (RULE REASON) for each rule
that matches the window now and hasn't run for it; REASON is :off-you,
:off-failures, :once-done, :on-focus, :on-close or :before (the window was
here before the rule was)."
  (let* ((notes (reverse (gethash window *vikix-rule-notes*)))
         (ran (mapcar (lambda (note)
                        ;; Before 0.71.125 a note was the rule's key alone.
                        (destructuring-bind (key &optional event time failure)
                            (if (consp note) note (list note))
                          (list time event
                                (find key *vikix-rules* :key #'vikix-rule-key :test #'equal)
                                key failure)))
                      notes))
         (waiting (loop for rule in *vikix-rules*
                        when (and (vikix-rule-fits-p rule window)
                                  (not (find rule ran :key #'third)))
                          collect (list rule
                                        (case (vikix-rule-off-reason rule)
                                          (:you :off-you)
                                          (:failures :off-failures)
                                          (t (cond ((and (vikix-rule-once rule)
                                                         (gethash (vikix-rule-key rule) *vikix-rules-once-done*))
                                                    :once-done)
                                                   ((eq (vikix-rule-on rule) :focus) :on-focus)
                                                   ((eq (vikix-rule-on rule) :close) :on-close)
                                                   (t :before))))))))
    (values ran waiting)))

(defun vikix-rules-window-line (window)
  "WINDOW for a person: its class, title, workspace and number."
  (let ((group (ignore-errors (window-group window))))
    (format nil "~a ~s~@[ (~a)~]"
            (or (ignore-errors (window-class window)) "?")
            (vikix-one-line (or (ignore-errors (window-title window)) "") 60)
            (and group
                 (format nil "workspace ~a, window ~d~:[~;, floating~]"
                         (group-name group) (window-number window)
                         (typep window 'float-window))))))

(defparameter *vikix-rule-waiting-words*
  '((:off-you . "it is switched off, by you")
    (:off-failures . "it was switched off after failing")
    (:once-done . "it is :once, and has had its window")
    (:on-focus . "it runs when the window gets the focus")
    (:on-close . "it runs when the window closes")
    (:before . "the window was here before the rule was: vikix rules apply runs it now")))

(defun vikix-rules-why-text (window)
  "Why WINDOW is where it is, for a terminal or a message."
  (multiple-value-bind (ran waiting) (vikix-rules-why window)
    (with-output-to-string (out)
      (format out "~a~%" (vikix-rules-window-line window))
      (cond (ran
             (format out "  Rules that ran for it:~%")
             (dolist (entry ran)
               (destructuring-bind (time event rule key failure) entry
                 (format out "    ~a~@[  on ~(~a~)~]  ~a~@[~%        FAILED: ~a~]~%"
                         (if time (vikix-rules-when time) "earlier") event
                         (if rule
                             (format nil "~d  ~a   ~a" (vikix-rule-number rule)
                                     (vikix-one-line (vikix-rule-text rule) 200) (vikix-rule-from rule))
                             (format nil "(a rule that isn't there any more)  ~a" (vikix-one-line key 200)))
                         failure))))
            (t (format out "  No rule has run for it.~%")))
      (when waiting
        (format out "  Rules that match it, and haven't run for it:~%")
        (dolist (entry waiting)
          (destructuring-bind (rule reason) entry
            (format out "    ~d  ~a   ~a~%        ~a~%"
                    (vikix-rule-number rule) (vikix-one-line (vikix-rule-text rule) 200)
                    (vikix-rule-from rule)
                    (cdr (assoc reason *vikix-rule-waiting-words*))))))
      (unless (or ran waiting)
        (format out "  No rule matches it either: it is where StumpWM, or you, put it.~%")))))

(defun vikix-rules-open-windows ()
  "Every window of the desktop, by workspace and number."
  (sort (copy-list (screen-windows (current-screen)))
        (lambda (a b)
          (let ((ga (group-number (window-group a))) (gb (group-number (window-group b))))
            (or (< ga gb) (and (= ga gb) (< (window-number a) (window-number b))))))))

(defun vikix-rules-windows-called (what)
  "The windows WHAT names: none given, the focused one; else those whose
class or instance is WHAT (in any case), or, failing that, whose title has it."
  (let ((what (string-trim " " (princ-to-string (or what "")))))
    (if (zerop (length what))
        (list (or (current-window)
                  (error "No window has the focus: name one by its class (vikix rules why Firefox).")))
        (let ((all (vikix-rules-open-windows)))
          (or (remove-if-not (lambda (w) (or (equalp what (ignore-errors (window-class w)))
                                             (equalp what (ignore-errors (window-res w)))))
                             all)
              (remove-if-not (lambda (w) (search what (or (ignore-errors (window-title w)) "") :test #'char-equal))
                             all)
              (error "No window has the class ~s, or has it in its title. The classes open now: ~{~a~^, ~}."
                     what (remove-duplicates (mapcar #'window-class all) :test #'equal)))))))

;;; What the rules would do with the windows open now, and doing it

(defun vikix-rules-would (window &optional only)
  "The rules that would run if WINDOW opened now, as it is (ONLY: that rule alone)."
  (remove-if-not (lambda (rule)
                   (and (vikix-rule-ready-p rule :open)
                        (vikix-rule-fits-p rule window)))
                 (if only (list only) *vikix-rules*)))

(defun vikix-rules-test-text (&optional only)
  "What the rules for a window opening would do with the windows open now.
Nothing is done."
  (let ((windows (vikix-rules-open-windows)) (untouched 0))
    (with-output-to-string (out)
      (dolist (window windows)
        (let ((rules (vikix-rules-would window only)))
          (cond ((null rules) (incf untouched))
                (t (format out "~a~%" (vikix-rules-window-line window))
                   (dolist (rule rules)
                     (format out "    ~d  ~a~%" (vikix-rule-number rule)
                             (vikix-one-line (vikix-rule-text rule) 200)))))))
      (let ((matching (- (length windows) untouched)))
        (format out "~d window~:p open; ~a ~:[a rule for a window opening~;that rule~]. Nothing was done: vikix rules apply~@[ ~d~] does it."
                (length windows)
                (case matching
                  (0 "none of them matches")
                  (1 "1 of them matches")
                  (t (format nil "~d of them match" matching)))
                only (and only (vikix-rule-number only)))))))

(defun vikix-rules-apply (&optional only)
  "Run the rules for a window opening on the windows open now (ONLY: that
rule alone), each rule checked just before it runs, as when a window opens.
What was done, as lines."
  (let ((ran 0) (failed 0))
    (with-output-to-string (out)
      (dolist (window (vikix-rules-open-windows))
        (let ((said nil))
          (dolist (rule (if only (list only) (copy-list *vikix-rules*)))
            (when (and (vikix-rule-ready-p rule :open)
                       (vikix-rule-fits-p rule window))
              (unless said
                (format out "~a~%" (vikix-rules-window-line window))
                (setf said t))
              (let ((ok (vikix-run-rule rule window :apply)))
                (if ok (incf ran) (incf failed))
                (format out "    ~:[FAILED~;ran   ~]  ~d  ~a~@[~%        ~a~]~%"
                        ok (vikix-rule-number rule) (vikix-one-line (vikix-rule-text rule) 200)
                        (and (not ok) (vikix-rule-last-error rule))))))))
      (format out "~d run~:p~[~:;, ~:*~d failed~]." ran failed))))

;;; What a rule can match and do

(defparameter *vikix-rule-forms*
  '(("(when-window (MATCH...) [:name \"..\"] [:on :open|:focus|:close] [:once t] VERB...)"
     "when a window opens (or gets the focus, or closes)")
    ("(at \"09:00\" [:weekdays | :weekends | :on (:mon :thu)] [:late t|nil] VERB...)"
     "at a time of day, or a list of times; up to an hour late after a sleep (:late t: however late that day, nil: never)")
    ("(each 30 :minutes VERB...)" "again and again: :minutes or :hours, counted from when it last ran")
    ("(when-battery-below 20 VERB...)" "once as the charge goes under that, off the charger")
    ("(when-charging VERB...)  (when-on-battery VERB...)" "when the charger goes in, or comes out")
    ("(at-login VERB...)" "once a login, not at a reload")
    ("(when-workspace 3 VERB...)" "on going to a workspace: a number, a name, or a list of them"))
  "The rules there are, each with its line, for `vikix rules verbs`.")

(defparameter *vikix-rule-matchers*
  '((":class :instance :title :role"
     "the window's own words. A string: exactly that; (:has \"text\"): contains it, in any case; (:like \"^regex$\"): a pattern; a list: any of them; a variable: its value when a window comes")
    (":type" ":normal, :dialog ..., or a list of them")
    (":workspace" "where the window opened: a number, a name, or a list of them")
    (":not (MATCH...)" "none of that")
    (":where FUNCTION" "anything else: a function, called with the window"))
  "What a when-window rule can match, each with its line.")

(defun vikix-rules-verbs-text ()
  "The rules, the matchers and the verbs, each with its line."
  (with-output-to-string (out)
    (format out "The rules:~%~:{  ~a~%      ~a~%~}" *vikix-rule-forms*)
    (format out "What a when-window rule matches (MATCH):~%~:{  ~a~%      ~a~%~}" *vikix-rule-matchers*)
    (format out "The verbs (VERB; any other Lisp works too, in which (window) is the window):~%")
    (dolist (name (vikix-rule-verb-names))
      (destructuring-bind (function description arguments) (gethash (string-upcase name) *vikix-rule-verbs*)
        (declare (ignore function))
        (format out "  (~a~{ ~a~})~%      ~a~%" name
                (mapcar (lambda (a) (string-downcase (vikix-rules-print a))) arguments)
                description)))
    (format out "A verb of your own: (define-rule-verb NAME (ARGS) \"its line\" BODY...).")))

;;; What vikix doctor says of them

(defun vikix-rule-workspaces (rule)
  "The workspaces RULE names: where its (workspace ...) sends a window, a
:workspace it matches, a when-workspace's own."
  (let ((match (vikix-rule-match rule)))
    (labels ((named (value) (if (listp value) (copy-list value) (list value)))
             (matched (match)
               (loop for (key value) on match by #'cddr
                     append (case key
                              (:workspace (named value))
                              (:not (and (listp value) (matched value)))))))
      (remove-duplicates
       (append (and (vikix-rule-place rule)
                    (let ((target (first (ignore-errors (funcall (vikix-rule-place rule))))))
                      (and target (list target))))
               (cond ((eq (vikix-rule-on rule) :workspace) (named (getf match :workspaces)))
                     ((vikix-rule-for-windows-p rule) (matched match))))
       :test #'equal))))

(defun vikix-rules-problems ()
  "(values OFF MISSING), each a list of lines: the rules switched off after
failing, and the rules naming a workspace that isn't there."
  (values
   (loop for rule in *vikix-rules*
         when (eq (vikix-rule-off-reason rule) :failures)
           collect (format nil "~d  ~a   ~a: ~a" (vikix-rule-number rule)
                           (vikix-one-line (vikix-rule-text rule) 120) (vikix-rule-from rule)
                           (vikix-rule-last-error rule)))
   (loop for rule in *vikix-rules*
         for missing = (remove-if (lambda (w) (ignore-errors (vikix-rule-find-workspace w)))
                                  (remove-if-not (lambda (w) (or (integerp w) (stringp w)))
                                                 (vikix-rule-workspaces rule)))
         when missing
           collect (format nil "~d  ~a   ~a: no workspace ~{~s~^, ~}" (vikix-rule-number rule)
                           (vikix-one-line (vikix-rule-text rule) 120) (vikix-rule-from rule) missing))))

;;; For bin/vikix-rules: one door, its words checked here

(defun vikix-rules-cli (what &optional (arg ""))
  "What `vikix rules WHAT ARG` prints. ARG is a string, as typed."
  (let ((arg (string-trim " " (princ-to-string (or arg "")))))
    (flet ((one ()
             (let ((rule (and (plusp (length arg)) (vikix-rule-called arg))))
               (when (and rule (not (eq (vikix-rule-on rule) :open)))
                 (error "Rule ~d isn't a rule for a window opening, so there is nothing to try it on: ~a"
                        (vikix-rule-number rule) (vikix-one-line (vikix-rule-text rule) 80)))
               rule))
           (say (text) (format t "~a~%" (string-right-trim '(#\Newline) text))))
      (cond ((equal what "list") (say (vikix-rules-text)))
            ((member what '("off" "on") :test #'equal)
             (let ((rule (vikix-rule-switch (vikix-rule-called arg) (equal what "on"))))
               (say (format nil "~a~@[~%        ~a~]" (vikix-rule-listed rule 200) (vikix-rule-state-line rule)))))
            ((equal what "why")
             (say (format nil "~{~a~^~%~}" (mapcar #'vikix-rules-why-text (vikix-rules-windows-called arg)))))
            ((equal what "test") (say (vikix-rules-test-text (one))))
            ((equal what "apply") (say (vikix-rules-apply (one))))
            ((equal what "verbs") (say (vikix-rules-verbs-text)))
            ((equal what "forget")
             (say (format nil "Taken out of ~~/.stumpwm.d/rules.lisp, and off the desktop:~%  ~a~%vikix undo puts the file back."
                          (vikix-rules-forget (vikix-rule-called arg)))))
            (t (error "vikix rules: list, off, on, why, test, apply, forget or verbs; not ~s." what)))
      (values))))

;;; Super+m, Rules

(defun vikix-rules-carets (text)
  "TEXT for StumpWM's messages and menus, where ^ starts a colour: a rule's
own carets (a pattern's \"^regex$\") written so they show."
  (ppcre:regex-replace-all "\\^" text "^^"))

(defun vikix-rules-show (text)
  "TEXT as a message that stays until a key: its first lines, when it is long."
  (let* ((lines (ppcre:split "\\n" text))
         (shown (subseq lines 0 (min (length lines) 40)))
         (*timeout-wait* 60))
    (message "~{~a~^~%~}~:[~;~%... (the rest: vikix rules, in a terminal)~]"
             (mapcar (lambda (line) (vikix-rules-carets (vikix-one-line line 150))) shown)
             (> (length lines) 40))))

(defun vikix-rules-menu-rule (rule)
  "What to do with RULE, picked in the menu."
  (let ((choice (vikix-ask (vikix-rules-carets (vikix-one-line (vikix-rule-text rule) 120))
                           (remove nil
                                   (list (if (vikix-rule-on-p rule)
                                             '("Switch it off, until the next reload" :off)
                                             '("Switch it on" :on))
                                         (and (eq (vikix-rule-on rule) :open)
                                              '("Run it on the windows open now" :apply))
                                         (and (vikix-rule-file rule)
                                              '("Open it in Emacs, at its line" :edit))
                                         (and (vikix-rule-file rule) (probe-file (vikix-rules-file))
                                              (equal (ignore-errors (truename (vikix-rule-file rule)))
                                                     (truename (vikix-rules-file)))
                                              '("Forget it: take it out of rules.lisp" :forget))
                                         '("Nothing" nil))))))
    (case choice
      (:off (vikix-rule-switch rule nil)
       (message "Off, until the next reload: ~a" (vikix-rules-carets (vikix-one-line (vikix-rule-text rule) 120))))
      (:on (vikix-rule-switch rule t)
       (message "On: ~a" (vikix-rules-carets (vikix-one-line (vikix-rule-text rule) 120))))
      (:apply (vikix-rules-show (vikix-rules-apply rule)))
      (:edit (vikix-open-in-emacs (vikix-rule-file rule) (vikix-rule-line rule)))
      (:forget (handler-case
                   (message "Taken out of ~~/.stumpwm.d/rules.lisp:~%~a~%vikix undo puts the file back."
                            (vikix-rules-carets (vikix-one-line (vikix-rules-forget rule) 150)))
                 (error (e) (message "^1Couldn't forget it:^n ~a" (vikix-one-line e))))))))

(defcommand vikix-rules () ()
  "The desktop's rules: which are on, how often each ran, why the window
in front is where it is; switch one off or on, run them on the open windows."
  (if (null *vikix-rules*)
      (message "No rules yet. One looks like this, in ~~/.stumpwm.d/rules.lisp or user.lisp:~%(when-window (:class \"Firefox\") (workspace 2))")
      (let* ((window (current-window))
             (choice (vikix-ask "Rules"
                                (append
                                 (and window
                                      (list (list (format nil "Why is this window where it is? (~a)" (window-class window)) :why)))
                                 '(("What the rules would do with the windows open now (nothing is done)" :test)
                                   ("Run the rules on the windows open now" :apply)
                                   ("What a rule can match and do" :verbs))
                                 (mapcar (lambda (rule) (list (vikix-rules-carets (vikix-rule-listed rule 100)) rule)) *vikix-rules*)))))
        (cond ((eq choice :why) (vikix-rules-show (vikix-rules-why-text window)))
              ((eq choice :test) (vikix-rules-show (vikix-rules-test-text)))
              ((eq choice :apply) (vikix-rules-show (vikix-rules-apply)))
              ((eq choice :verbs) (vikix-rules-show (vikix-rules-verbs-text)))
              ((vikix-rule-p choice) (vikix-rules-menu-rule choice))))))

;;; --- Remembering a window (Super+Shift+t) ---------------------------------------------------------
;;;
;;; The rule for the window in front, written for you: what to know it by,
;;; its workspace, and when it floats its size and place as shares of the
;;; monitor. It is shown first. On your yes a snapshot is taken, the rule
;;; goes into ~/.stumpwm.d/rules.lisp under a dated comment, named
;;; "remembered: ...", and is loaded. Remembering the same window again
;;; replaces its rule where it stands; `vikix rules forget` takes a rule
;;; out of the file again, and `vikix undo` puts the file back.
;;;
;;; The desktop only ever writes to rules.lisp, never to user.lisp.

(defun vikix-rules-file ()
  "Your file of rules."
  (merge-pathnames ".stumpwm.d/rules.lisp" (user-homedir-pathname)))

(defparameter *vikix-rules-file-head*
  (format nil ";;;; rules.lisp — your rules for the desktop. vikix rules lists them,~%;;;; vikix rules verbs says what a rule can match and do.~%(in-package :stumpwm)~%")
  "What a rules.lisp made here starts with.")

(defparameter *vikix-remember-comment* ";; Remembered "
  "How the comment above a remembered rule begins: it goes with its rule.")

(defparameter *vikix-snapshot-command* "timeout 30 vikix snapshot"
  "What takes a snapshot of your files before the desktop changes one; its
message is added. The tests name another.")

(defun vikix-remember-emacs-named-p (window)
  "Has WINDOW, an Emacs frame, a name of its own (Esploro, a note's box)
rather than its buffer's? Emacs is asked, with two seconds to answer; no
answer is no."
  (let* ((id (ignore-errors (xlib:window-id (window-xwin window))))
         (lisp (and id (format nil "(let ((n 0)) (dolist (f (frame-list)) (when (and (equal (frame-parameter f 'outer-window-id) \"~d\") (frame-parameter f 'explicit-name)) (setq n 1))) n)" id)))
         (out (and lisp (ignore-errors
                         (run-shell-command (format nil "timeout 2 emacsclient -e ~a 2>/dev/null" (vikix-shell-quote lisp))
                                            t)))))
    (and out (equal (string-trim '(#\Space #\Newline) out) "1"))))

(defun vikix-remember-instance-tells-p (window)
  "Does WINDOW's instance say more than its class? It does when it is one
of Vikix's own names (vikix-nmtui), or when another window open now has
the class with another instance (an Alacritty started with --class)."
  (let ((class (ignore-errors (window-class window)))
        (instance (ignore-errors (window-res window))))
    (and instance (plusp (length instance)) (not (equalp instance class))
         (or (eql 0 (search "vikix-" instance))
             (some (lambda (other)
                     (and (not (eq other window))
                          (equal (ignore-errors (window-class other)) class)
                          (not (equal (ignore-errors (window-res other)) instance))))
                   (ignore-errors (screen-windows (current-screen)))))
         t)))

(defun vikix-remember-ways (window)
  "The ways a rule can know WINDOW, the one to offer first: :class,
:instance, :title. An Emacs frame with a name of its own goes by its title,
matched whole: every Emacs frame has the same class."
  (let* ((class (or (ignore-errors (window-class window)) ""))
         (instance (or (ignore-errors (window-res window)) ""))
         (title (or (ignore-errors (window-title window)) ""))
         (ways (remove nil (list (and (plusp (length class)) :class)
                                 (and (plusp (length instance)) (not (equalp instance class)) :instance)
                                 (and (plusp (length title)) :title))))
         (first (cond ((and (equal class "Emacs") (member :title ways) (vikix-remember-emacs-named-p window)) :title)
                      ((and (member :instance ways) (vikix-remember-instance-tells-p window)) :instance)
                      ((member :class ways) :class)
                      (t (first ways)))))
    (and first (cons first (remove first ways)))))

(defun vikix-remember-match (window way)
  "(values MATCH WORDS): the matcher that knows WINDOW by WAY, and what to
call it in the rule's name."
  (let ((class (or (ignore-errors (window-class window)) ""))
        (instance (or (ignore-errors (window-res window)) ""))
        (title (or (ignore-errors (window-title window)) "")))
    (ecase way
      (:class (values (list :class class) class))
      (:instance (values (list :instance instance) instance))
      (:title (if (plusp (length class))
                  (values (list :class class :title title) (format nil "~a ~s" class title))
                  (values (list :title title) (format nil "~s" title)))))))

(defun vikix-remember-share (part whole)
  "PART of WHOLE as a rule writes it: \"65%\"."
  (format nil "~d%" (max 0 (round (* 100 part) (max 1 whole)))))

(defun vikix-remember-verbs (window &key workspace-only)
  "The verbs that put a window like WINDOW where WINDOW is: its workspace,
and when it floats its size and place as shares of the monitor below the
bar (WORKSPACE-ONLY leaves those out). A window kept on every workspace
has no workspace of its own: it is floated and kept everywhere."
  (let* ((group (window-group window))
         (workspace (if (equal (group-name group) (princ-to-string (group-number group)))
                        (group-number group)
                        (group-name group)))
         (sticky (and (member window *always-show-windows*) t))
         (float (and (typep window 'float-window)
                     (multiple-value-bind (ax ay aw ah) (vikix-rule-area (window-head window))
                       (let* ((parent (window-parent window))
                              (w (xlib:drawable-width parent)) (h (xlib:drawable-height parent))
                              (x (- (xlib:drawable-x parent) ax)) (y (- (xlib:drawable-y parent) ay))
                              ;; In the middle, to a hundredth: float puts it there by itself.
                              (middle (and (<= (abs (- x (floor (- aw w) 2))) (ceiling aw 100))
                                           (<= (abs (- y (floor (- ah h) 2))) (ceiling ah 100)))))
                         `(float :width ,(vikix-remember-share w aw) :height ,(vikix-remember-share h ah)
                                 ,@(unless middle
                                     (list :x (vikix-remember-share x aw) :y (vikix-remember-share y ah)))))))))
    (cond (workspace-only `((workspace ,workspace)))
          (sticky `(,(or float '(float)) (sticky)))
          (float `((workspace ,workspace) ,float))
          (t `((workspace ,workspace))))))

(defun vikix-remember-rule (window &key way workspace-only)
  "The rule that remembers WINDOW: (values FORM NAME). WAY is how to know
it (the first of vikix-remember-ways when not given)."
  (let ((way (or way (first (vikix-remember-ways window))
                 (error "This window has no class, instance or title to know it by."))))
    (multiple-value-bind (match words) (vikix-remember-match window way)
      (let ((name (format nil "remembered: ~a" words)))
        (values `(when-window ,match :name ,name ,@(vikix-remember-verbs window :workspace-only workspace-only))
                name)))))

;;; The file

(defun vikix-rules-file-forms (text)
  "The forms of TEXT, a file of rules, each with where it is: (FORM START
END). An error when it can't be read."
  (let ((*package* (find-package :stumpwm))
        (*read-eval* nil)
        (forms '()))
    (with-input-from-string (in text)
      (loop
        (vikix-skip-comments in)
        (let* ((start (file-position in))
               (form (read in nil in)))
          (when (eq form in) (return))
          (push (list form start (file-position in)) forms))))
    (nreverse forms)))

(defun vikix-rules-file-span (text start end)
  "What goes with the form from START to END in TEXT: from the start of
its line, or of the ';; Remembered' comment on the line above, to the end
of its last line. (values FROM TO)."
  (flet ((line-start (position)
           (1+ (or (position #\Newline text :end position :from-end t) -1))))
    (let* ((from (line-start start))
           (above (and (plusp from) (line-start (1- from))))
           (to (let ((newline (position #\Newline text :start end)))
                 (if newline (1+ newline) (length text)))))
      (values (if (and above (eql above (search *vikix-remember-comment* text :start2 above)))
                  above
                  from)
              to))))

(defun vikix-rules-file-text ()
  "Your rules.lisp as it is, or as a new one starts."
  (let ((file (vikix-rules-file)))
    (if (probe-file file)
        (uiop:read-file-string file)
        *vikix-rules-file-head*)))

(defun vikix-rules-file-write (text why)
  "A snapshot of your files (WHY, in words), then TEXT as your rules.lisp:
written through a link to the file it names, never over the link."
  (let ((file (vikix-rules-file)))
    (ignore-errors
     (run-shell-command (format nil "~a ~a >/dev/null 2>&1" *vikix-snapshot-command* (vikix-shell-quote why)) t))
    (ensure-directories-exist file)
    (with-open-file (out (or (probe-file file) file)
                         :direction :output :if-exists :supersede :if-does-not-exist :create
                         :external-format :utf-8)
      (write-string text out))
    file))

(defun vikix-remember-named-p (form name)
  "Is FORM a when-window rule whose :name is NAME?"
  (and (consp form) (eq (first form) 'when-window)
       (equal name (ignore-errors (getf (cddr form) :name)))))

(defun vikix-remember-write (form name words)
  "Write the rule FORM, named NAME, into your rules.lisp (in the place of
the one of that name when there is one, else at its end, under a dated
comment saying WORDS) and load it. Returns the rule, as the desktop has it."
  (let* ((text (vikix-rules-file-text))
         (printed (vikix-rules-print form))
         (block (multiple-value-bind (s mi h d mo y) (get-decoded-time)
                  (declare (ignore s mi h))
                  (format nil "~a~4,'0d-~2,'0d-~2,'0d: ~a~%~a~%" *vikix-remember-comment* y mo d words printed)))
         ;; A file that can't be read is only added to.
         (old (find-if (lambda (entry) (vikix-remember-named-p (first entry) name))
                       (ignore-errors (vikix-rules-file-forms text))))
         (new (if old
                  (multiple-value-bind (from to) (vikix-rules-file-span text (second old) (third old))
                    (concatenate 'string (subseq text 0 from) block (subseq text to)))
                  (format nil "~a~%~%~a" (string-right-trim '(#\Newline #\Space) text) block)))
         (file (vikix-rules-file-write new (format nil "before: a rule for ~a" words)))
         (line (vikix-line-at new (search printed new))))
    (let ((*load-truename* (truename file))
          (*load-pathname* (pathname file))
          (*vikix-load-line* line)
          (*package* (find-package :stumpwm)))
      ;; What is in the file is what runs: read back from its own words.
      (vikix-eval-from file (let ((*read-eval* nil)) (read-from-string printed))))
    (find name *vikix-rules* :key #'vikix-rule-name :test #'equal)))

(defun vikix-rules-forget (rule)
  "Take RULE out of your rules.lisp, and out of the desktop. Its text. An
error for a rule written anywhere else, or not found there as it was loaded."
  (let ((file (vikix-rules-file))
        (number (vikix-rule-number rule)))
    (unless (and (vikix-rule-file rule) (probe-file file)
                 (equal (ignore-errors (truename (vikix-rule-file rule))) (truename file)))
      (error "Rule ~d is written in ~a, not in your rules.lisp: it can only be taken out there (vikix rules off ~d switches it off until the next reload)."
             number (vikix-rule-from rule) number))
    (let* ((text (uiop:read-file-string file))
           (forms (handler-case (vikix-rules-file-forms text)
                    (error (e) (error "rules.lisp can't be read (~a): take the rule out by hand." (vikix-one-line e)))))
           (found (find (vikix-rule-text rule) forms
                        :key (lambda (entry) (ignore-errors (vikix-rules-print (first entry))))
                        :test #'equal)))
      (unless found
        (error "Rule ~d isn't in rules.lisp as it was loaded (was the file changed since?): reload the config, or take it out by hand."
               number))
      (multiple-value-bind (from to) (vikix-rules-file-span text (second found) (third found))
        (let ((left (string-right-trim '(#\Newline) (subseq text 0 from)))
              (right (string-left-trim '(#\Newline) (subseq text to))))
          (vikix-rules-file-write (format nil "~a~%~:[~;~%~]~a" left (plusp (length right)) right)
                                  (format nil "before: forgetting the rule ~a" (vikix-one-line (vikix-rule-text rule) 80)))))
      (vikix-remove-rules :key (vikix-rule-key rule))
      (vikix-rule-text rule))))

;;; The key

(defcommand vikix-remember () ()
  "Remember this window here: write the rule that puts a window like it
where this one is (its workspace, and when it floats its size and place)
into ~/.stumpwm.d/rules.lisp. The rule is shown first."
  (let ((window (current-window)))
    (if (null window)
        (message "No window to remember: go to one first.")
        (let* ((ways (or (vikix-remember-ways window)
                         (return-from vikix-remember
                           (message "This window has no class, instance or title for a rule to know it by."))))
               (placed (or (typep window 'float-window) (member window *always-show-windows*)))
               (words (lambda (way)
                        (ecase way (:class "its class") (:instance "its instance") (:title "its title, exactly"))))
               (label (lambda (start &rest keys)
                        (format nil "~a  ~a" start
                                (vikix-rules-carets (vikix-one-line (vikix-rules-print (apply #'vikix-remember-rule window keys)) 140)))))
               (choice (vikix-ask "Remember this window here? The rule goes into ~/.stumpwm.d/rules.lisp"
                                  (append
                                   (list (list (funcall label "Write it:") (list :way (first ways))))
                                   (and placed
                                        (list (list (funcall label "Its workspace only:" :workspace-only t)
                                                    (list :way (first ways) :workspace-only t))))
                                   (mapcar (lambda (way)
                                             (list (funcall label (format nil "Known by ~a instead:" (funcall words way)) :way way)
                                                   (list :way way)))
                                           (rest ways))
                                   '(("Cancel" nil))))))
          (when choice
            (handler-case
                (multiple-value-bind (form name) (apply #'vikix-remember-rule window choice)
                  (let ((rule (vikix-remember-write form name (subseq name (length "remembered: ")))))
                    (message "Remembered, in ~~/.stumpwm.d/rules.lisp:~%~a~%vikix rules forget ~d takes it out again."
                             (vikix-rules-carets (vikix-one-line (vikix-rules-print form) 150))
                             (or (and rule (vikix-rule-number rule)) 0))))
              (error (e)
                (vikix-error-report e "remembering a window" nil)
                (message "^1Couldn't write the rule:^n ~a" (vikix-one-line e)))))))))

;;; --- Vikix's own rules -------------------------------------------------------------------------
;;;
;;; What the layer itself wants of windows, said as rules like anyone's:
;;; `vikix rules` lists them (from Vikix), and one can be switched off.
;;; They are here, not beside what they are about (windows.lisp,
;;; commands.lisp), because those files load before this one empties the
;;; table. The hooks these were until 0.71.139 are taken off, for a desktop
;;; that was running then.

(remove-hook *new-window-hook* 'vikix-float-lazarus-window)
(remove-hook *new-window-hook* 'vikix-learn-place)

;; Lazarus (windows.lisp): the docked IDE's main window tiles like any
;; other; every other Lazarus window (dialogs, the welcome screen, anything
;; undocked) floats at its own size. Tiled, StumpWM would stretch each to
;; fill a frame and fight Lazarus over its size, which flickers. The main
;; window's title settles as "Lazarus IDE v...", but StumpWM sees it before
;; that, as "Lazarus" or "MainIDE".
(when-window (:class (:has "lazarus")
              :not (:title (:like "^(Lazarus|MainIDE)$|^Lazarus IDE v")))
  :name "Vikix: Lazarus's windows float, all but its main one"
  (float :own t))

;; vikix learn (commands.lisp): its two terminals, each into its half of
;; the workspace as it opens, whichever comes first.
(when-window (:class ("vikix-learn-lesson" "vikix-learn-shell"))
  :name "Vikix: vikix learn's lesson and shell, each in its half"
  ;; By name: this file also loads where commands.lisp hasn't (the tests).
  (funcall 'vikix-learn-place (window)))
