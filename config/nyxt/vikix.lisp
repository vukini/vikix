;;;; vikix.lisp — Vikix's part of Nyxt's config: Nyxt in the desktop's colours.
;;;;
;;;; Linked to ~/.local/share/vikix/nyxt/vikix.lisp; your
;;;; ~/.config/nyxt/config.lisp loads it (the starter Vikix copies there
;;;; does), so `vikix update` changes this file and never yours.
;;;;
;;;; The colours are the palette `vikix theme' writes for every program,
;;;; ~/.config/vikix/theme/palette (bg=#rrggbb lines). Nyxt reads it as it
;;;; starts, and `vikix theme NAME' asks a running Nyxt to read it again,
;;;; over Nyxt's socket ($XDG_RUNTIME_DIR/nyxt/nyxt.socket, yours alone):
;;;;   nyxt --remote --quit --eval '(nyxt-user::vikix-theme-apply)'
;;;; That needs remote execution, which is switched on here.
;;;;
;;;; To keep Nyxt's own colours, take the (load ...) line out of your
;;;; config.lisp; to change one, set it there after the load.

(in-package #:nyxt-user)

(defvar *vikix-palette-file*
  (merge-pathnames "vikix/theme/palette" (uiop:xdg-config-home))
  "The colours `vikix theme' writes.")

(defun vikix-colour-p (value)
  "Whether VALUE is a #rrggbb colour: nothing else from the file is used."
  (and (= (length value) 7)
       (char= (char value 0) #\#)
       (every (lambda (c) (digit-char-p c 16)) (subseq value 1))))

(defun vikix-palette (&optional (file *vikix-palette-file*))
  "The palette as an alist of (\"bg\" . \"#rrggbb\"); nil without the file."
  (with-open-file (in file :if-does-not-exist nil)
    (when in
      (loop for line = (read-line in nil)
            while line
            for = = (position #\= line)
            for key = (and = (string-trim " " (subseq line 0 =)))
            for value = (and = (string-trim " " (subseq line (1+ =))))
            when (and key (plusp (length key)) (char/= (char key 0) #\#)
                      (vikix-colour-p value))
              collect (cons key value)))))

(defun vikix-make-theme (palette)
  "A Nyxt theme from PALETTE, or nil when it lacks bg or fg. Nyxt works out
the lighter and darker variants, and the text on each colour, itself."
  (flet ((c (key &optional default)
           (or (cdr (assoc key palette :test #'string=)) default)))
    (let ((bg (c "bg")) (fg (c "fg")))
      (when (and bg fg)
        (make-instance 'theme:theme
                       :background-color bg
                       ;; Set, not worked out: Nyxt's own guess at the
                       ;; "more contrasting" shade of a dark background is
                       ;; near white, and it's what the current tab's label
                       ;; sits on, under light text.
                       :background-color+ bg
                       :background-color- (c "sel" bg)
                       :text-color fg
                       :text-color- (c "subtle" fg)
                       :text-color+ fg
                       ;; Text on colours too close to fg: the background.
                       :contrast-text-color bg
                       ;; The status bar and the prompt's frame.
                       :primary-color (c "dim" fg)
                       :secondary-color (c "sel" bg)
                       ;; The selected suggestion. Nyxt draws its text in
                       ;; the plain text colour whatever this is, so it's
                       ;; the palette's selection, made for text on it.
                       :action-color (c "sel" bg)
                       :highlight-color (c "color5" (c "accent" fg))
                       :success-color (c "color2" fg)
                       :warning-color (c "alert" fg)
                       :codeblock-color (c "sel" bg))))))

(defun vikix-fresh-style (object &optional (slot-name "STYLE"))
  "Compute OBJECT's style slot (SLOT-NAME, a slot of Nyxt's) again, from
the theme now in use: Nyxt computes it once, when the object is made."
  (let* ((name (find-symbol slot-name :nyxt))
         (slot (and name (find name (closer-mop:class-slots (class-of object))
                               :key #'closer-mop:slot-definition-name)))
         (init (and slot (closer-mop:slot-definition-initfunction slot))))
    (when init
      (setf (slot-value object name) (funcall init)))))

(defun vikix-theme-apply ()
  "Read the palette again and repaint the running Nyxt: the status bars
and the message line now; new buffers and prompts follow by themselves. Returns the theme, or
nil when the palette isn't usable (Nyxt is then left as it was)."
  (let ((theme (vikix-make-theme (vikix-palette))))
    (when (and theme *browser*)
      (setf (theme *browser*) theme)
      (dolist (window (window-list))
        ;; The line under the status bar, where messages show.
        (vikix-fresh-style window "MESSAGE-BUFFER-STYLE")
        (when (status-buffer window)
          (vikix-fresh-style (status-buffer window))
          (nyxt::print-status window))))
    theme))

;;; Swank: Emacs inside the running Nyxt, as with StumpWM. From Emacs:
;;;
;;;   M-x slime-connect RET 127.0.0.1 RET 4006
;;;
;;; and you are at a REPL in Nyxt (package nyxt-user): define a command,
;;; bind a key, inspect a buffer, M-. into Nyxt's source; it takes effect
;;; at once. StumpWM's Swank is 4004; 4005 is left for your own SLIME.
;;;
;;; Swank runs whatever it's sent, as you, with your logins and cookies at
;;; hand, and 127.0.0.1 isn't only yours. So it starts only with a password:
;;; Swank itself checks ~/.slime-secret (40-config makes it) at each
;;; connection, and SLIME sends it by itself. Without the file it doesn't
;;; start at all. The guard below is StumpWM's (swank-guard.lisp): a wrong
;;; password, or a client that sends none, would otherwise stop Swank's one
;;; accepting thread, and with it every later connection.
;;;
;;; No Swank in Nyxt: (setf *vikix-swank-port* nil) in your config.lisp,
;;; after the line that loads this file.

(defvar *vikix-swank-port* 4006
  "The port Nyxt's Swank listens on, on 127.0.0.1; nil for none.")

(defparameter *vikix-swank-auth-seconds* 5
  "Seconds a Swank client has to send the password. SLIME sends it at once.")

(defvar *vikix-swank-started* nil
  "The port, once Swank listens on it: loading this file again (Nyxt's
load-config-file) never starts a second one.")

(defvar *vikix-swank-guarded* nil)

(defun vikix-swank-secret-p ()
  "Whether ~/.slime-secret has a password: Swank checks its first line."
  (with-open-file (in (merge-pathnames ".slime-secret" (user-homedir-pathname))
                      :if-does-not-exist nil)
    (let ((line (and in (read-line in nil))))
      (and line (plusp (length (string-trim '(#\Space #\Tab #\Return) line)))))))

(defun vikix-guard-swank ()
  "Wrap Swank's password check in a time limit, and its accept loop so a
refused client ends only itself."
  (let* ((auth (find-symbol "AUTHENTICATE-CLIENT" :swank))
         (accept (find-symbol "ACCEPT-CONNECTIONS" :swank)))
    (when (and auth accept (fboundp auth) (fboundp accept)
               (not *vikix-swank-guarded*))
      (let ((original-auth (fdefinition auth))
            (original-accept (fdefinition accept)))
        (setf (fdefinition auth)
              (lambda (stream)
                ;; SERIOUS-CONDITION: a deadline passing isn't an ERROR.
                (handler-case
                    (sb-sys:with-deadline (:seconds *vikix-swank-auth-seconds*)
                      (funcall original-auth stream))
                  (serious-condition (e)
                    (ignore-errors (close stream :abort t))
                    (error "Swank client refused: ~a" e)))))
        (setf (fdefinition accept)
              (lambda (&rest args)
                (handler-case (apply original-accept args)
                  (error () nil))))
        (setf *vikix-swank-guarded* t)))))

;; Nyxt's Swank is built into it, and older than the SLIME Emacs gets from
;; MELPA (and the Swank StumpWM gets from Quicklisp), which sends a few
;; calls more arguments: lines and width (how much of a result to show) to
;; the evaluating ones, a macro environment to the expanding ones. The old
;; Swank refuses those ("invalid number of arguments"), so C-x C-e and
;; C-M-x stop in the debugger. Each of these then takes what it's sent, and
;; passes on as many arguments as it has room for. Both kinds are hints:
;; without them a result shows in full.
(defparameter *vikix-swank-newer-calls*
  '("INTERACTIVE-EVAL" "INTERACTIVE-EVAL-REGION" "EVAL-STRING-IN-FRAME"
    "SWANK-EXPAND" "SWANK-EXPAND-1" "SWANK-MACROEXPAND" "SWANK-MACROEXPAND-1"
    "SWANK-MACROEXPAND-ALL" "SWANK-COMPILER-MACROEXPAND"
    "SWANK-COMPILER-MACROEXPAND-1" "SWANK-FORMAT-STRING-EXPAND"))

(defun vikix-positional-count (function)
  "How many arguments FUNCTION takes at most, or nil when it takes any
number (&rest or &key): those need no help."
  (let ((list (sb-introspect:function-lambda-list function)))
    (unless (intersection list '(&rest &key &body))
      (count-if-not (lambda (x) (member x lambda-list-keywords)) list))))

(defun vikix-swank-accept-newer-calls ()
  "Let newer SLIME's calls through to Nyxt's older Swank (see above). Wraps
each function once, and only one that has fewer places than SLIME sends."
  (dolist (name *vikix-swank-newer-calls*)
    (let ((symbol (find-symbol name :swank)))
      (when (and symbol (fboundp symbol) (not (get symbol 'vikix-wrapped)))
        (let* ((original (fdefinition symbol))
               (most (vikix-positional-count original)))
          (when most
            (setf (fdefinition symbol)
                  (lambda (&rest args)
                    (apply original (subseq args 0 (min most (length args))))))
            (setf (get symbol 'vikix-wrapped) t)))))))

(defun vikix-start-swank ()
  "Start Swank on *vikix-swank-port*, once, guarded, and only with a password."
  (cond ((or (null *vikix-swank-port*) *vikix-swank-started*))
        ((not (vikix-swank-secret-p))
         (log:warn "Swank not started: ~~/.slime-secret has no password (vikix update core makes one)"))
        (t
         (vikix-guard-swank)
         (vikix-swank-accept-newer-calls)
         (handler-case
             (let ((swank::*loopback-interface* "127.0.0.1"))
               (uiop:symbol-call :swank :create-server
                                 :port *vikix-swank-port* :dont-close t)
               (setf *vikix-swank-started* *vikix-swank-port*))
           ;; A port taken by something else mustn't stop Nyxt starting.
           (error (e)
             (log:warn "Swank not started on port ~a: ~a" *vikix-swank-port* e))))))

;; As Nyxt starts, once the whole config has loaded (so a setf of
;; *vikix-swank-port* there counts). :after, so a customize-instance of
;; your own (Nyxt's auto-config writes one) still runs, and this comes
;; after it.
(defmethod customize-instance :after ((browser browser) &key)
  (let ((theme (vikix-make-theme (vikix-palette))))
    (when theme (setf (theme browser) theme)))
  (vikix-start-swank))

;; So that `vikix theme' can reach a running Nyxt.
(define-configuration browser
  ((remote-execution-p t)))
;;; The docs catalogue (vikix docs) as a page: M-x vikix-docs here, or
;;; vikix docs page (Super+m, "Docs catalogue in Nyxt"). The hits come from
;;; vikix docs find, grouped by where they're from, and open as Super+F2's
;;; do: a guide, a man page or a README as a page (here), a note in Emacs.

(defparameter *vikix-docs-sources*
  '(("vikix" . "Vikix's guides") ("repo" . "Your projects") ("dev" . "Your languages (~/dev)")
    ("note" . "Your notes") ("man" . "Man pages") ("info" . "Manuals (Info)")
    ("pkgdoc" . "Packages' READMEs") ("pkg" . "Packages"))
  "Each source of the catalogue and its heading, in the order shown.")

(defun vikix-docs-run (&rest args)
  (uiop:run-program (cons "vikix" args) :output :string :error-output nil :ignore-error-status t))

(defun vikix-docs-hits (query)
  "(id source title excerpt) for each hit, best first."
  (unless (str:blankp query)
    (loop for line in (str:lines (apply #'vikix-docs-run "docs" "find" "--tsv" "--limit" "80"
                                        (str:split " " query :omit-nulls t)))
          for fields = (str:split #\Tab line)
          when (= (length fields) 4) collect fields)))

(defun vikix-docs-open-id (id &optional other)
  "Open a hit as Super+F2 does (Ctrl+Enter there: OTHER)."
  (run-thread "vikix docs open"
    (let ((err (nth-value 1 (uiop:run-program
                             (append (list "vikix" "docs" "open" id) (when other (list "--other")))
                             :output nil :error-output :string :ignore-error-status t))))
      (unless (str:emptyp (str:trim err))
        (echo-warning "~a" (str:trim err))))))

(define-internal-page vikix-docs-page (&key (query ""))
    (:title "*Docs*")
  "Every document on this machine, found: vikix docs as a page."
  (let ((hits (vikix-docs-hits query)))
    (spinneret:with-html-string
      (:h1 "Docs")
      (:p (:nbutton :text "Find…" '(nyxt-user::vikix-docs))
          " Every document on this machine: Vikix's guides, your projects and notes, man pages, manuals, packages. "
          "The start of a word is enough; \"exact words\", a OR b.")
      (cond ((str:blankp query)
             (:p "Press Find, or Super+F2 anywhere."))
            ((null hits)
             (:p (format nil "Nothing found for “~a”." query)))
            (t
             (:p (format nil "~d found for “~a”, Vikix's first, then yours, then the system's." (length hits) query))
             (dolist (source *vikix-docs-sources*)
               (let ((group (remove (car source) hits :key #'second :test-not #'string=)))
                 (when group
                   (:h2 (format nil "~a (~d)" (cdr source) (length group)))
                   (:ul
                    (dolist (hit group)
                      (destructuring-bind (id src title excerpt) hit
                        (declare (ignore src))
                        (:li (:nbutton :text "Open" `(nyxt-user::vikix-docs-open-id ,id))
                             (:nbutton :text "The other way" `(nyxt-user::vikix-docs-open-id ,id t))
                             " " (:b title)
                             (unless (or (str:blankp excerpt) (search excerpt title))
                               (:br) (:small excerpt))))))))))))))

(defun vikix-docs-show (query)
  "The catalogue's page for QUERY, in front (vikix docs page)."
  (buffer-load-internal-page-focus 'vikix-docs-page :query query))

(define-command-global vikix-docs (&key (query (prompt1 :prompt "Find in every document"
                                                        :sources 'prompter:raw-source)))
  "Search every document on this machine (vikix docs), as a page."
  (vikix-docs-show query))
