;;;; door.lisp — the door: an agent's Lisp is checked before it runs.
;;;;
;;;; An agent (Claude Code at a terminal, the MCP server's eval tool) sends
;;;; a form for the running desktop through `vikix eval`. Code is data: the
;;;; form is read with *read-eval* off and walked before anything runs, and
;;;; every function it calls is looked up in one list. What moves a window,
;;;; switches a workspace, reads the desktop's state or shows a message
;;;; passes. What runs a program, touches a file, defines or redefines
;;;; anything, sets a global, waits on the main thread or evaluates text
;;;; of its own is held: the form waits in *vikix-door-held* for you
;;;; (Super+m, Door; `vikix door`), and the agent is told why, in words.
;;;; Nothing runs at the door; you run a held form or drop it. A form that
;;;; reaches a shell, a file, the secrets, eval or the system is also
;;;; written where errors.lisp writes, so the attempt is kept.
;;;;
;;;; Only forms an agent sends pass this way: bin/vikix-eval looks up the
;;;; process tree for one (a Vikix script of its own between them counts
;;;; as Vikix's: `vikix theme` run by an agent is Vikix's Lisp, not the
;;;; agent's), and the MCP server's eval tool asks for the door outright.
;;;; Your own `vikix eval` at a terminal is yours and isn't checked.
;;;;
;;;; The lists are of names, not symbols, so this file is plain Common
;;;; Lisp up to "The desktop" below, and tests/door.sh loads it without
;;;; StumpWM. Your own names go in ~/.config/vikix/door, one a line.

(in-package :stumpwm)

;;; --- The lists -------------------------------------------------------------------------

(defparameter *vikix-door-allowed*
  '(;; Lisp: control, binding, values
    "IF" "WHEN" "UNLESS" "COND" "CASE" "ECASE" "TYPECASE" "ETYPECASE" "PROGN" "PROG1" "PROG2"
    "AND" "OR" "NOT" "NULL" "LET" "LET*" "LAMBDA" "FUNCTION" "QUOTE" "BLOCK" "RETURN" "RETURN-FROM"
    "LOOP" "DOLIST" "DOTIMES" "DO" "DO*" "MULTIPLE-VALUE-BIND" "MULTIPLE-VALUE-LIST" "VALUES"
    "VALUES-LIST" "NTH-VALUE" "DESTRUCTURING-BIND" "HANDLER-CASE" "HANDLER-BIND" "IGNORE-ERRORS"
    "UNWIND-PROTECT" "THE" "DECLARE" "IDENTITY" "CONSTANTLY" "COMPLEMENT" "ERROR" "WARN" "ASSERT"
    "CHECK-TYPE" "TAGBODY" "GO" "CATCH" "THROW"
    ;; lists, sequences, tables
    "LIST" "LIST*" "CONS" "CAR" "CDR" "CAAR" "CADR" "CDAR" "CDDR" "CADDR" "CDDDR" "FIRST" "SECOND"
    "THIRD" "FOURTH" "FIFTH" "REST" "NTH" "NTHCDR" "LAST" "BUTLAST" "LENGTH" "ENDP" "APPEND"
    "REVERSE" "NREVERSE" "MEMBER" "MEMBER-IF" "ASSOC" "RASSOC" "GETF" "GET" "ELT" "AREF" "SUBSEQ"
    "COPY-LIST" "COPY-SEQ" "COPY-TREE" "MAPCAR" "MAPC" "MAPCAN" "MAPCON" "MAPLIST" "MAPHASH" "MAP"
    "REDUCE" "REMOVE" "REMOVE-IF" "REMOVE-IF-NOT" "REMOVE-DUPLICATES" "DELETE-DUPLICATES"
    "FIND" "FIND-IF" "FIND-IF-NOT" "POSITION" "POSITION-IF" "POSITION-IF-NOT" "COUNT" "COUNT-IF"
    "COUNT-IF-NOT" "SOME" "EVERY" "NOTANY" "NOTEVERY" "SORT" "STABLE-SORT" "CONCATENATE" "COERCE"
    "ADJOIN" "UNION" "INTERSECTION" "SET-DIFFERENCE" "SUBSETP" "FILL" "MAKE-LIST" "MAKE-ARRAY"
    "VECTOR" "GETHASH" "MAKE-HASH-TABLE" "HASH-TABLE-COUNT" "HASH-TABLE-P" "CLRHASH" "REMHASH"
    ;; strings and characters
    "STRING" "STRING=" "STRING/=" "STRING<" "STRING>" "STRING<=" "STRING>=" "STRING-EQUAL"
    "STRING-UPCASE" "STRING-DOWNCASE" "STRING-CAPITALIZE" "STRING-TRIM" "STRING-LEFT-TRIM"
    "STRING-RIGHT-TRIM" "SEARCH" "MISMATCH" "CHAR" "SCHAR" "CHAR=" "CHAR<" "CHAR>" "CHAR-EQUAL"
    "CHAR-CODE" "CODE-CHAR" "DIGIT-CHAR-P" "ALPHA-CHAR-P" "ALPHANUMERICP" "UPPER-CASE-P"
    "LOWER-CASE-P" "CHAR-UPCASE" "CHAR-DOWNCASE" "PARSE-INTEGER" "FORMAT" "PRINC" "PRIN1" "PRINT"
    "TERPRI" "FRESH-LINE" "WRITE-STRING" "WRITE-LINE" "WRITE-CHAR" "WRITE" "PRINC-TO-STRING"
    "PRIN1-TO-STRING" "WRITE-TO-STRING" "WITH-OUTPUT-TO-STRING" "WITH-INPUT-FROM-STRING"
    "READ-FROM-STRING" "SUBSTITUTE" "SUBSTITUTE-IF" "NSUBSTITUTE" "STRING-CHAR-P"
    ;; numbers
    "+" "-" "*" "/" "1+" "1-" "=" "/=" "<" ">" "<=" ">=" "MAX" "MIN" "FLOOR" "CEILING" "ROUND"
    "TRUNCATE" "MOD" "REM" "ABS" "EXPT" "SQRT" "LOG" "EXP" "ZEROP" "PLUSP" "MINUSP" "EVENP" "ODDP"
    "RANDOM" "FLOAT" "GCD" "LCM" "SIGNUM" "ISQRT"
    ;; types, equality, symbols
    "NUMBERP" "INTEGERP" "REALP" "FLOATP" "STRINGP" "SYMBOLP" "KEYWORDP" "LISTP" "CONSP" "ATOM"
    "FUNCTIONP" "CHARACTERP" "VECTORP" "ARRAYP" "SEQUENCEP" "TYPEP" "TYPE-OF" "CLASS-OF"
    "CLASS-NAME" "EQ" "EQL" "EQUAL" "EQUALP" "SYMBOL-NAME" "SYMBOL-VALUE" "SYMBOL-PACKAGE"
    "PACKAGE-NAME" "BOUNDP" "FBOUNDP" "INTERN" "FIND-SYMBOL" "GENSYM" "DOCUMENTATION" "DESCRIBE"
    "APROPOS" "APROPOS-LIST" "MACROEXPAND" "MACROEXPAND-1" "SPECIAL-OPERATOR-P" "MACRO-FUNCTION"
    "SLOT-VALUE" "SLOT-BOUNDP"
    ;; time and paths (reading only: no file is touched)
    "GET-UNIVERSAL-TIME" "GET-DECODED-TIME" "DECODE-UNIVERSAL-TIME" "ENCODE-UNIVERSAL-TIME"
    "GET-INTERNAL-REAL-TIME" "NAMESTRING" "PATHNAME" "PATHNAME-NAME" "PATHNAME-TYPE"
    "PATHNAME-DIRECTORY" "MERGE-PATHNAMES" "USER-HOMEDIR-PATHNAME" "MAKE-PATHNAME"
    ;; StumpWM: what is there
    "CURRENT-GROUP" "CURRENT-WINDOW" "CURRENT-SCREEN" "CURRENT-HEAD" "GROUP-WINDOWS" "GROUP-NAME"
    "GROUP-NUMBER" "GROUP-SCREEN" "GROUP-CURRENT-WINDOW" "GROUP-FRAMES" "TILE-GROUP-FRAME-TREE"
    "TILE-GROUP-CURRENT-FRAME" "SCREEN-GROUPS" "SCREEN-WINDOWS" "SCREEN-CURRENT-GROUP"
    "SCREEN-HEADS" "SCREEN-NUMBER" "SCREEN-WIDTH" "SCREEN-HEIGHT" "FIND-GROUP" "SORT-GROUPS"
    "SORT-WINDOWS" "WINDOW-TITLE" "WINDOW-NAME" "WINDOW-CLASS" "WINDOW-RES" "WINDOW-ROLE"
    "WINDOW-TYPE" "WINDOW-NUMBER" "WINDOW-GROUP" "WINDOW-FRAME" "WINDOW-X" "WINDOW-Y"
    "WINDOW-WIDTH" "WINDOW-HEIGHT" "WINDOW-FULLSCREEN" "WINDOW-MARKED" "WINDOW-ID" "WINDOW-STATE"
    "WINDOW-VISIBLE-P" "WINDOW-HIDDEN-P" "WINDOW-IN-CURRENT-GROUP-P" "WINDOW-PID"
    "FRAME-NUMBER" "FRAME-X" "FRAME-Y" "FRAME-WIDTH" "FRAME-HEIGHT" "FRAME-WINDOW" "FRAME-WINDOWS"
    "HEAD-NUMBER" "HEAD-X" "HEAD-Y" "HEAD-WIDTH" "HEAD-HEIGHT" "LOOKUP-KEY" "KBD" "PRINT-KEY"
    "PRINT-KEY-SEQ" "PARSE-KEY" "ALL-COMMANDS" "GET-COMMAND-STRUCTURE" "MESSAGE" "ECHO-STRING"
    ;; StumpWM: what is put back as easily as done
    "GSELECT" "GNEXT" "GPREV" "GOTHER" "GMOVE" "FNEXT" "FPREV" "FOTHER" "MOVE-FOCUS"
    "MOVE-WINDOW" "FOCUS-WINDOW" "FOCUS-FRAME" "FOCUS-ALL" "PULL-WINDOW" "PULL-WINDOW-BY-NUMBER"
    "SELECT-WINDOW" "SELECT-WINDOW-BY-NUMBER" "NEXT" "PREV" "NEXT-IN-FRAME" "PREV-IN-FRAME"
    "OTHER-WINDOW" "OTHER-IN-FRAME" "HSPLIT" "VSPLIT" "REMOVE-SPLIT" "ONLY" "BALANCE-FRAMES"
    "FULLSCREEN" "REFRESH" "REDISPLAY" "ECHO-WINDOWS" "WINDOWS" "TOGGLE-MODE-LINE" "LOADRC"
    ;; Vikix: what an agent is told to ask, and the checked acts
    "VIKIX-AGENT-COMMANDS" "VIKIX-AGENT-RUN" "VIKIX-BINDINGS" "VIKIX-PRETTY-KEY" "VIKIX-RULES-LIST"
    "VIKIX-RULES-WHY" "VIKIX-RULES-LINES" "VIKIX-RULES-WHEN" "VIKIX-RULES-WINDOW-LINE"
    "VIKIX-RULE-NUMBER" "VIKIX-RULE-TEXT" "VIKIX-RULE-PROPOSE" "VIKIX-RULE-PROPOSALS-LIST"
    "VIKIX-RULE-WAITING-WORDS" "VIKIX-RULES-TICK" "VIKIX-RULES-LOOK" "VIKIX-WHY-ENTRIES"
    "VIKIX-WHY-LINE" "VIKIX-WINDOW-AGENT" "VIKIX-AGENTS-TSV" "VIKIX-PALETTE-LINES"
    "VIKIX-WHAT-LINES" "VIKIX-KEY-PROBLEMS" "VIKIX-RESUME-SUMMARY" "VIKIX-GATHER"
    "VIKIX-APPLY-THEME" "VIKIX-DOOR-CHECK" "VIKIX-DOOR-CHECK-TEXT" "VIKIX-DOOR-ALLOWED-NAMES"
    "VIKIX-DOOR-LINES" "VIKIX-COMMAND" "VIKIX-VERSION")
  "The names a form an agent sends may call. Reads of the desktop, and the
acts put back as easily as done. The registry's :agent commands and
~/.config/vikix/door are added to these.")

(defparameter *vikix-door-refused*
  '((:shell "runs a program"
     "RUN-SHELL-COMMAND" "RUN-PROGRAM" "RUN-PROG" "RUN-PROG-COLLECT-OUTPUT" "SHELL" "EXEC"
     "RUN-COMMANDS" "EVAL-COMMAND" "RUN-OR-RAISE" "RUN-OR-PULL" "VIKIX-OPEN-IN-EMACS")
    (:file "touches a file"
     "OPEN" "WITH-OPEN-FILE" "WITH-OPEN-STREAM" "DELETE-FILE" "RENAME-FILE" "PROBE-FILE"
     "DIRECTORY" "ENSURE-DIRECTORIES-EXIST" "FILE-WRITE-DATE" "FILE-LENGTH" "LOAD" "COMPILE-FILE"
     "DRIBBLE" "ED" "REQUIRE" "VIKIX-LOAD-FILE" "VIKIX-LOAD-FORMS" "VIKIX-RULES-FILE-WRITE"
     "VIKIX-REMEMBER-WRITE" "VIKIX-RULE-PROPOSAL-ADD" "VIKIX-ERROR-REPORT")
    (:eval "runs Lisp the door can't see"
     "EVAL" "COMPILE" "FUNCALL" "APPLY" "MULTIPLE-VALUE-CALL" "VIKIX-EVAL-FORMS"
     "VIKIX-EVAL-FOR-AGENT" "VIKIX-DOOR-RUN" "VIKIX-DOOR-DROP" "VIKIX-DOOR-HOLD")
    (:system "reaches the system"
     "QUIT" "EXIT" "MAKE-THREAD" "INTERRUPT-THREAD" "TERMINATE-THREAD" "JOIN-THREAD" "ABORT"
     "RESTART-HARD" "RESTART-SOFT" "VIKIX-SWANK-RESTART" "VIKIX-START-SWANK" "GETENV" "POSIX-GETENV"))
  "What is refused outright, by kind: each kind's words, then its names. A
form with one of these is held and the attempt written to the errors folder.")

(defparameter *vikix-door-asks*
  '((:define "defines or changes code"
     "DEFUN" "DEFMACRO" "DEFVAR" "DEFPARAMETER" "DEFCONSTANT" "DEFGENERIC" "DEFMETHOD" "DEFCLASS"
     "DEFSTRUCT" "DEFTYPE" "DEFINE-SYMBOL-MACRO" "DEFCOMMAND" "DEFINE-VIKIX-COMMAND"
     "DEFINE-RULE-VERB" "DEFINE-KEY" "UNDEFINE-KEY" "SET-PREFIX-KEY" "FMAKUNBOUND" "MAKUNBOUND"
     "SYMBOL-FUNCTION" "FDEFINITION" "ENCAPSULATE" "UNENCAPSULATE" "FLET" "LABELS" "MACROLET"
     "SYMBOL-MACROLET" "ADD-HOOK" "REMOVE-HOOK" "RUN-HOOK" "RUN-HOOK-WITH-ARGS" "SET"
     "WHEN-WINDOW" "AT" "EACH")
    (:wait "waits, holding the desktop"
     "SLEEP" "READ" "READ-LINE" "READ-CHAR" "READ-PRESERVING-WHITESPACE" "PEEK-CHAR" "LISTEN"
     "Y-OR-N-P" "YES-OR-NO-P" "READ-ONE-LINE" "READ-ONE-CHAR" "SELECT-FROM-MENU" "VIKIX-ASK"
     "COMPLETING-READ" "VIKIX-DIALOG" "FSELECT"))
  "What is held for you, by kind, without a report: a change to the code
the desktop runs, or a wait in its main thread.")

(defparameter *vikix-door-refused-packages*
  '("SB-EXT" "SB-POSIX" "SB-SYS" "SB-ALIEN" "SB-THREAD" "SB-BSD-SOCKETS" "SB-IMPL" "SB-INT"
    "SB-KERNEL" "SB-UNIX" "SB-C" "SB-VM" "SB-DEBUG" "UIOP" "ASDF" "SWANK" "SWANK/BACKEND" "SB-MOP")
  "A symbol of these packages is refused whatever its name: they reach the system.")

(defparameter *vikix-door-setters* '("SETF" "SETQ" "PSETF" "PSETQ" "INCF" "DECF" "PUSH" "PUSHNEW" "POP" "ROTATEF" "SHIFTF")
  "What sets a place: fine on a variable the form itself bound, held on anything else.")

(defparameter *vikix-door-lambda-keywords* '("&OPTIONAL" "&REST" "&KEY" "&AUX" "&BODY" "&WHOLE" "&ALLOW-OTHER-KEYS" "&ENVIRONMENT"))

(defun vikix-door-user-file ()
  (merge-pathnames ".config/vikix/door" (user-homedir-pathname)))

(defun vikix-door-user-names ()
  "The names in ~/.config/vikix/door, upcased, one a line; # starts a comment."
  (ignore-errors
   (with-open-file (in (vikix-door-user-file) :if-does-not-exist nil)
     (and in
          (loop for line = (read-line in nil)
                while line
                for word = (string-trim " " (subseq line 0 (or (position #\# line) (length line))))
                when (plusp (length word)) collect (string-upcase word))))))

(defun vikix-door-registry-names ()
  "The registry's commands an agent may run (:agent t), as function names."
  (and (fboundp 'vikix-agent-commands)
       (loop for command in (funcall 'vikix-agent-commands)
             for run = (getf command :run)
             when (stringp run)
               collect (string-upcase (subseq run 0 (or (position #\Space run) (length run)))))))

(defun vikix-door-allowed-names ()
  "Every name the door lets through now, sorted: the list above, the
registry's :agent commands, and the user's own file."
  (sort (remove-duplicates (append *vikix-door-allowed* (vikix-door-registry-names) (vikix-door-user-names))
                           :test #'string=)
        #'string<))

;;; --- The walker ----------------------------------------------------------------------------

(defun vikix-door-kind-of (name table)
  "The (KIND WORDS) entry of TABLE that has NAME, or NIL."
  (find-if (lambda (entry) (member name (cddr entry) :test #'string=)) table))

(defun vikix-door-problem-with-name (symbol &optional (how "calls"))
  "NIL when a form may call SYMBOL, else (KIND . WHY)."
  (let* ((name (symbol-name symbol))
         (package (and (symbol-package symbol) (package-name (symbol-package symbol))))
         (refused (vikix-door-kind-of name *vikix-door-refused*))
         (asks (vikix-door-kind-of name *vikix-door-asks*)))
    (cond ((member package *vikix-door-refused-packages* :test #'string=)
           (cons :refused (format nil "it ~a ~a:~a, which reaches the system" how package name)))
          (refused (cons :refused (format nil "it ~a ~(~a~), which ~a" how name (second refused))))
          (asks (cons :held (format nil "it ~a ~(~a~), which ~a" how name (second asks))))
          ((member name *vikix-door-allowed* :test #'string=) nil)
          ((member name (vikix-door-registry-names) :test #'string=) nil)
          ((member name (vikix-door-user-names) :test #'string=) nil)
          (t (cons :held (format nil "it ~a ~(~a~), which isn't on the door's list (vikix door allowed shows it)" how name))))))

(defun vikix-door-proper-list-p (x)
  (and (listp x) (handler-case (list-length x) (error () nil)) (null (cdr (last x)))))

(defun vikix-door-tree-symbols (tree)
  "Every symbol in TREE, dotted or not, lambda-list keywords left out."
  (cond ((null tree) '())
        ((symbolp tree)
         (if (member (symbol-name tree) *vikix-door-lambda-keywords* :test #'string=) '() (list tree)))
        ((consp tree) (append (vikix-door-tree-symbols (car tree)) (vikix-door-tree-symbols (cdr tree))))
        (t '())))

(defun vikix-door-quoted-problem (thing)
  "Quoted data runs nothing, but a quoted name handed to mapcar or apply
does: a refused or held name anywhere in THING is a problem."
  (dolist (symbol (vikix-door-tree-symbols thing))
    (let ((problem (vikix-door-problem-with-name symbol "names")))
      (when (and problem (or (eq (car problem) :refused)
                             (vikix-door-kind-of (symbol-name symbol) *vikix-door-asks*)))
        (return problem)))))

(defun vikix-door-body (forms locals)
  "The first problem in FORMS, or NIL."
  (unless (vikix-door-proper-list-p forms)
    (return-from vikix-door-body (cons :held "it isn't a proper list")))
  (dolist (form forms)
    (let ((problem (vikix-door-problem form locals)))
      (when problem (return problem)))))

(defun vikix-door-lambda-list (list locals)
  "LOCALS with LIST's variables added; a second value, the first problem
in a default. Nested lists before &optional are destructuring patterns."
  (unless (vikix-door-proper-list-p list)
    (setf list (vikix-door-tree-symbols list)))
  (let ((after-required nil))
    (dolist (item list)
      (cond ((symbolp item)
             (when (member (symbol-name item) *vikix-door-lambda-keywords* :test #'string=)
               (setf after-required t))
             (push item locals))
            ((and (consp item) (not after-required))
             (multiple-value-bind (more problem) (vikix-door-lambda-list item locals)
               (when problem (return-from vikix-door-lambda-list (values locals problem)))
               (setf locals more)))
            ((consp item)
             ;; (var default [supplied]) or ((:key var) default [supplied])
             (setf locals (append (vikix-door-tree-symbols (first item)) locals))
             (when (cddr item) (setf locals (append (vikix-door-tree-symbols (third item)) locals)))
             (let ((problem (and (cdr item) (vikix-door-problem (second item) locals))))
               (when problem (return-from vikix-door-lambda-list (values locals problem)))))))
    (values locals nil)))

(defun vikix-door-bindings (bindings locals)
  "let's BINDINGS: LOCALS with the variables, and the first problem in a value."
  (unless (vikix-door-proper-list-p bindings)
    (return-from vikix-door-bindings (values locals (cons :held "its bindings aren't a list"))))
  (dolist (binding bindings (values locals nil))
    (cond ((symbolp binding) (push binding locals))
          ((and (consp binding) (symbolp (first binding)) (vikix-door-proper-list-p binding))
           (let ((problem (and (cdr binding) (vikix-door-problem (second binding) locals))))
             (when problem (return (values locals problem))))
           (push (first binding) locals))
          (t (return (values locals (cons :held "a binding isn't (name value)")))))))

(defun vikix-door-loop (parts locals)
  "A loop's PARTS: a name after for, as, with or into is a variable of the
loop's; every list is a form."
  (let ((binder nil))
    (dolist (part parts)
      (cond ((and binder (symbolp part)) (push part locals) (setf binder nil))
            ((and binder (consp part)) (setf locals (append (vikix-door-tree-symbols part) locals)) (setf binder nil))
            ((and (symbolp part) (member (symbol-name part) '("FOR" "AS" "WITH" "INTO") :test #'string=))
             (setf binder t))
            ((consp part)
             (let ((problem (vikix-door-problem part locals)))
               (when problem (return-from vikix-door-loop problem))))))
    nil))

(defun vikix-door-clauses (clauses locals &key keyed)
  "cond's or case's CLAUSES: the first problem. With KEYED the first of each is data."
  (dolist (clause clauses)
    (unless (vikix-door-proper-list-p clause)
      (return (cons :held "a clause isn't a list")))
    (let ((problem (if keyed
                       (vikix-door-body (rest clause) locals)
                       (vikix-door-body clause locals))))
      (when problem (return problem)))))

(defun vikix-door-problem (form &optional locals)
  "NIL when FORM may run, else (KIND . WHY): :refused for what reaches a
shell, a file, eval or the system, :held for anything else not on the list."
  (cond
    ((keywordp form) nil)
    ((symbolp form) nil)                     ; reading a variable
    ((atom form) nil)                        ; a number, a string, a character
    ((not (vikix-door-proper-list-p form)) (cons :held "it isn't a proper list"))
    ((consp (first form))                    ; ((lambda ...) args)
     (or (vikix-door-problem (first form) locals) (vikix-door-body (rest form) locals)))
    ((not (symbolp (first form))) (cons :held (format nil "~s can't be called" (first form))))
    (t
     (let* ((head (first form))
            (name (symbol-name head))
            (args (rest form)))
       (flet ((is (&rest names) (member name names :test #'string=)))
         (cond
           ((is "QUOTE") (vikix-door-quoted-problem (second form)))
           ((is "FUNCTION")
            (let ((it (second form)))
              (cond ((symbolp it) (vikix-door-problem-with-name it "names"))
                    ((consp it) (vikix-door-problem it locals))
                    (t (cons :held "#' of something that isn't a name")))))
           ((is "DECLARE") nil)
           ((is "THE") (vikix-door-problem (third form) locals))
           ((is "LAMBDA")
            (multiple-value-bind (more problem) (vikix-door-lambda-list (second form) locals)
              (or problem (vikix-door-body (cddr form) more))))
           ((is "LET" "LET*")
            (multiple-value-bind (more problem) (vikix-door-bindings (second form) locals)
              (or problem (vikix-door-body (cddr form) more))))
           ((is "MULTIPLE-VALUE-BIND" "DESTRUCTURING-BIND")
            (multiple-value-bind (more problem) (vikix-door-lambda-list (second form) locals)
              (or problem (vikix-door-body (cddr form) more))))
           ((is "DOLIST" "DOTIMES")
            (let ((spec (second form)))
              (unless (and (vikix-door-proper-list-p spec) (symbolp (first spec)))
                (return-from vikix-door-problem (cons :held (format nil "~(~a~) wants (name value)" name))))
              (or (vikix-door-body (rest spec) locals)
                  (vikix-door-body (cddr form) (cons (first spec) locals)))))
           ((is "DO" "DO*")
            (let ((specs (second form)) (more locals))
              (unless (vikix-door-proper-list-p specs)
                (return-from vikix-door-problem (cons :held "do wants a list of variables")))
              (dolist (spec specs)
                (if (symbolp spec) (push spec more) (push (first spec) more)))
              (or (vikix-door-body (loop for spec in specs when (consp spec) append (rest spec)) more)
                  (vikix-door-body (third form) more)
                  (vikix-door-body (cdddr form) more))))
           ((is "LOOP") (vikix-door-loop args locals))
           ((is "COND") (vikix-door-clauses args locals))
           ((is "CASE" "ECASE" "TYPECASE" "ETYPECASE")
            (or (vikix-door-problem (second form) locals)
                (vikix-door-clauses (cddr form) locals :keyed t)))
           ((is "HANDLER-CASE")
            (or (vikix-door-problem (second form) locals)
                (dolist (clause (cddr form))
                  (unless (and (vikix-door-proper-list-p clause) (listp (second clause)))
                    (return (cons :held "a handler-case clause isn't (type (var) ...)")))
                  (let ((problem (vikix-door-body (cddr clause) (append (second clause) locals))))
                    (when problem (return problem))))))
           ((is "HANDLER-BIND")
            (or (vikix-door-body (mapcar (lambda (b) (if (consp b) (second b) b)) (second form)) locals)
                (vikix-door-body (cddr form) locals)))
           ((is "WITH-OUTPUT-TO-STRING" "WITH-INPUT-FROM-STRING")
            (let ((spec (second form)))
              (unless (and (vikix-door-proper-list-p spec) (symbolp (first spec)))
                (return-from vikix-door-problem (cons :held (format nil "~(~a~) wants (stream ...)" name))))
              (or (vikix-door-body (rest spec) locals)
                  (vikix-door-body (cddr form) (cons (first spec) locals)))))
           ((is "BLOCK" "RETURN-FROM" "CATCH" "TAGBODY")
            (vikix-door-body (remove-if #'symbolp (if (is "TAGBODY") args (rest args))) locals))
           ((member name *vikix-door-setters* :test #'string=)
            ;; Places first: a variable the form bound is its own, anything else is the desktop's.
            (let ((places (if (is "SETF" "SETQ" "PSETF" "PSETQ")
                              (loop for (place nil) on args by #'cddr collect place)
                              (if (is "PUSH" "PUSHNEW") (list (second args)) (list (first args)))))
                  (vals (if (is "SETF" "SETQ" "PSETF" "PSETQ")
                            (loop for (nil value) on args by #'cddr collect value)
                            (if (is "PUSH" "PUSHNEW") (list (first args)) (rest args)))))
              (dolist (place places)
                (cond ((and (symbolp place) (member place locals)) nil)
                      ((symbolp place)
                       (return-from vikix-door-problem
                         (cons :held (format nil "it sets ~(~a~), which is the desktop's" place))))
                      ((and (consp place) (symbolp (first place)))
                       (return-from vikix-door-problem
                         (cons :held (format nil "it changes (~(~a~) ...), which is the desktop's" (first place)))))
                      (t (return-from vikix-door-problem (cons :held "it sets something that isn't a place")))))
              (vikix-door-body vals locals)))
           ((is "FUNCALL" "APPLY" "MULTIPLE-VALUE-CALL")
            ;; Only a function named right there: a function in a variable is one the door can't see.
            (let ((it (first args)))
              (cond ((and (consp it) (member (symbol-name (first it)) '("FUNCTION" "QUOTE") :test #'string=)
                          (symbolp (second it)))
                     (or (vikix-door-problem-with-name (second it))
                         (vikix-door-body (rest args) locals)))
                    ((and (consp it) (string= (symbol-name (first it)) "LAMBDA"))
                     (or (vikix-door-problem it locals) (vikix-door-body (rest args) locals)))
                    (t (cons :refused (format nil "it ~(~a~)s something the door can't see" name))))))
           (t
            (or (vikix-door-problem-with-name head)
                (vikix-door-body args locals)))))))))

(defun vikix-door-read (text)
  "TEXT's forms, read in the STUMPWM package with *read-eval* off: nothing runs at reading."
  (let ((*package* (find-package :stumpwm))
        (*read-eval* nil))
    (with-input-from-string (in text)
      (loop with eof = (gensym "EOF")
            for form = (read in nil eof)
            until (eq form eof)
            collect form))))

(defun vikix-door-check (form)
  "May FORM run as an agent's? T; or NIL, the reason in words, and :refused or :held."
  (let ((problem (vikix-door-problem form)))
    (if problem
        (values nil (cdr problem) (car problem))
        (values t nil nil))))

(defun vikix-door-check-text (text)
  "TEXT's forms, checked: \"ok\", or the reason the first one is held. For
`vikix door check`, so an agent can ask before sending."
  (handler-case
      (let ((forms (vikix-door-read text)))
        (if (null forms)
            "ok: nothing to run"
            (dolist (form forms "ok")
              (multiple-value-bind (ok why) (vikix-door-check form)
                (unless ok
                  (return (format nil "held: ~a~%  ~a" (vikix-door-print form) why)))))))
    (error (e) (format nil "error: can't be read: ~a" e))))

(defun vikix-door-print (form)
  (let ((*package* (find-package :stumpwm)) (*print-case* :downcase) (*print-pretty* nil))
    (prin1-to-string form)))

;;; --- The held forms ---------------------------------------------------------------------

(defvar *vikix-door-held* '()
  "The forms held at the door and not decided yet, oldest first: each a
plist of :id, :text, :why, :kind, :from and :time.")
(defvar *vikix-door-count* 0 "The last held form's number.")
(defparameter *vikix-door-most* 10 "How many forms wait at most: more are refused, not kept.")

(defun vikix-door-held (id)
  (find id *vikix-door-held* :key (lambda (h) (getf h :id))))

(defun vikix-door-hold (text why kind from)
  "Keep TEXT, an agent's, for the user to run or drop; tell the desktop.
The number it got, or NIL when the door is full."
  (when (>= (length *vikix-door-held*) *vikix-door-most*)
    (return-from vikix-door-hold nil))
  (setf *vikix-door-held* (remove text *vikix-door-held* :key (lambda (h) (getf h :text)) :test #'string=))
  (let ((held (list :id (incf *vikix-door-count*) :text text :why why :kind kind
                    :from (or from "an agent") :time (get-universal-time))))
    (setf *vikix-door-held* (append *vikix-door-held* (list held)))
    (when (and (eq kind :refused) (fboundp 'vikix-error-report))
      (funcall 'vikix-error-report
               (make-condition 'simple-error
                               :format-control "The door refused a form from ~a: ~a~%~a"
                               :format-arguments (list (getf held :from) why text))
               "at the door (held for you: Super+m, Door; vikix door)"))
    (when (fboundp 'run-shell-command)
      (ignore-errors
       (funcall 'run-shell-command
                (format nil "notify-send -a Vikix -- ~a ~a"
                        (vikix-shell-quote (format nil "~a sent Lisp the door held" (getf held :from)))
                        (vikix-shell-quote (format nil "~a~%~a~%Super+m, Door: run it or drop it there."
                                                   (vikix-one-line text 200) (vikix-one-line why 200)))))))
    (getf held :id)))

(defun vikix-door-drop (held)
  (setf *vikix-door-held* (remove held *vikix-door-held*)))

(defun vikix-door-run (held)
  "Run HELD's forms, as the user, and forget it: what they printed and their values."
  (vikix-door-drop held)
  (with-output-to-string (*standard-output*)
    (if (fboundp 'vikix-eval-forms)
        (funcall 'vikix-eval-forms (getf held :text))
        (format t "error: this desktop can't run it (no vikix-eval-forms)"))))

(defun vikix-door-when (time)
  (multiple-value-bind (s mi h d mo y) (decode-universal-time time)
    (declare (ignore s))
    (format nil "~4,'0d-~2,'0d-~2,'0d ~2,'0d:~2,'0d" y mo d h mi)))

(defun vikix-door-lines ()
  "The held forms for `vikix door`: ID, WHEN, FROM, WHY, TEXT, tab-parted, a line each."
  (format nil "~{~a~^~%~}"
          (mapcar (lambda (h)
                    (format nil "~d~c~a~c~a~c~a~c~a"
                            (getf h :id) #\Tab (vikix-door-when (getf h :time)) #\Tab (getf h :from)
                            #\Tab (vikix-one-line (getf h :why) 300) #\Tab (vikix-one-line (getf h :text) 2000)))
                  *vikix-door-held*)))

(defun vikix-door-indent (text)
  (with-output-to-string (out)
    (loop for start = 0 then (1+ end)
          for end = (position #\Newline text :start start)
          do (write-string text out :start start :end end)
          while end do (format out "~%  "))))

(defun vikix-door-cli (what &optional (arg ""))
  "What `vikix door` asks: list, run N, drop N, check TEXT, allowed."
  (cond ((string= what "list") (vikix-door-lines))
        ((string= what "allowed") (format nil "~{~(~a~)~^~%~}" (vikix-door-allowed-names)))
        ((string= what "check") (vikix-door-check-text arg))
        ((member what '("run" "drop") :test #'string=)
         (let ((held (vikix-door-held (ignore-errors (parse-integer arg)))))
           (cond ((null held) (format nil "error: nothing is held as ~a (vikix door lists them)" arg))
                 ((string= what "drop") (vikix-door-drop held) (format nil "dropped ~a: ~a" arg (vikix-one-line (getf held :text) 200)))
                 ;; Its values' "=> " lines are indented: vikix door drops a bare one as vikix eval's own.
                 (t (format nil "ran ~a: ~a~%  ~a" arg (vikix-one-line (getf held :text) 200)
                            (vikix-door-indent (string-right-trim '(#\Newline) (vikix-door-run held))))))))
        (t (format nil "error: vikix door doesn't know ~a" what))))

;;; --- The desktop ----------------------------------------------------------------------------
;;; From here on, StumpWM: the menu under Super+m.

(defun vikix-door-menu-held (held)
  "What to do with HELD, picked in the menu: its lines first, so a hasty Enter runs nothing."
  (let ((choice (vikix-ask (format nil "~a sent Lisp the door held" (getf held :from))
                           (append
                            (mapcar (lambda (line) (list (vikix-one-line line 150) nil))
                                    (list (format nil "  ~a" (getf held :text))
                                          (format nil "  Held because ~a" (getf held :why))
                                          (format nil "  At ~a" (vikix-door-when (getf held :time)))))
                            '(("Run it now, as me" :run)
                              ("No: drop it" :drop)
                              ("Later" nil))))))
    (case choice
      (:run (let ((out (vikix-door-run held)))
              (message "Ran: ~a~%~a" (vikix-one-line (getf held :text) 150)
                       (vikix-one-line (string-right-trim '(#\Newline) out) 300))))
      (:drop (vikix-door-drop held)
       (message "Dropped: ~a" (vikix-one-line (getf held :text) 150))))))

(defcommand vikix-door () ()
  "The Lisp forms agents sent that the door held: run one as you, or drop it."
  (if (null *vikix-door-held*)
      (message "Nothing waits at the door.~%An agent's Lisp that runs a program, touches a file or changes code is held here for you;~%vikix door allowed lists what passes.")
      (let ((choice (vikix-ask "The door"
                               (mapcar (lambda (h)
                                         (list (vikix-one-line (format nil "~a: ~a" (getf h :from) (getf h :text)) 120) h))
                                       *vikix-door-held*))))
        (when (consp choice) (vikix-door-menu-held choice)))))
