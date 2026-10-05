;;;; ~/.stumpwm.d/init.lisp — managed by Vikix (a symlink into the checkout).
;;;;
;;;; StumpWM runs this file when it starts. It does only two things:
;;;;   1. load Vikix's layer, one small file per concern
;;;;   2. load ~/.stumpwm.d/user.lisp — yours — last, so your settings win
;;;;
;;;; Don't edit this file: `vikix update` replaces it. Edit user.lisp.

(in-package :stumpwm)

(defparameter *vikix-dir*
  (merge-pathnames ".stumpwm.d/vikix/" (user-homedir-pathname))
  "Where Vikix's StumpWM files live.")

(defparameter *vikix-files*
  '("errors"     ; when something fails, ask what to do (loaded first, plainly)
    "theme"      ; colours and borders, as one palette
    "groups"     ; workspaces 1-9
    "registry"   ; every command once: its key, its place in Super+m, whether agents may run it
    "commands"   ; Vikix's own commands (menu, key help, reload)
    "windows"    ; focus, gaps, layout undo, finding windows
    "rules"      ; rules that read like sentences: (when-window (:class "Firefox") (workspace 2))
    "viri"       ; a workspace that scrolls sideways (vikix-viri), and Super+h/l along it
    "drawer"     ; a few everyday programs at the screen's edge, out and away (Super+Ctrl+b)
    "layouts"    ; saved layouts: vikix layout save NAME, vikix layout NAME
    "overview"   ; every workspace drawn small on a card, to pick a window (Super+o)
    "day"        ; what had the screen, written down for vikix day
    "why"        ; why did that happen? the key, rule or command behind it (Super+?)
    "keys"       ; Super-key bindings
    "help"       ; the key card (s-/), key help (s-F1), all commands, which-key
    "webapps"    ; your web apps (vikix webapp): keys and Super+m
    "modeline"   ; the bar at the top
    "plugins"    ; the plugins you added (vikix plugin add), and their part of the bar
    "rescue"     ; a way out when the desktop is stuck: a watcher, Super+Ctrl+Alt+Escape, vikix rescue
    "swank-guard" ; a wrong Swank password can't take Swank down
    "swank")     ; the door for Emacs, with a password
  "Loaded in this order. Each file only uses what the files before it define.")

;;; Compiled copies. StumpWM compiles every form it loads, and the layer is
;;; ten thousand lines: every reload, and every login, compiled all of it
;;; again (2 of a reload's seconds on a quiet machine, more on a busy one).
;;; So each of Vikix's files is compiled once, into ~/.cache/vikix/fasl/,
;;; and loaded from there until it changes.
;;;
;;; A file with no copy yet is loaded as before, from its text, a form at
;;; a time; when the whole load is done, a thread of its own compiles it in
;;; the background, for the next time. Compiled then, not first: a file's
;;; macros use functions of that same file, which must be the new ones,
;;; and are once its text has been loaded. So the first load after a
;;; change is as slow as it was, and no slower.
;;;
;;; A copy's name holds a number made from the file's text and that of
;;; every file loaded before it (a macro changed in an earlier file changes
;;; what a later one compiles to), and from this Lisp, this StumpWM and
;;; this file. Your own files and the plugins' are small and stay as they
;;; were, read a form at a time, so a mistake has its line. A copy that
;;; fails to load is thrown away and the text loaded instead, where
;;; errors.lisp asks what to do.
;;;
;;; VIKIX_FASL_DIR puts the copies elsewhere (the tests share one folder,
;;; so each hidden desktop needn't compile the layer again).

(defvar *vikix-loading-file* nil
  "The file being loaded, whichever way: from its text, or its compiled
copy (when *load-truename* is the copy's).")

(defun vikix-loading-file ()
  "The file a form being loaded is written in, or nil outside a load."
  (or *vikix-loading-file* *load-truename*))

(defvar *vikix-load-times* '()
  "The last load: (NAME MILLISECONDS HOW) for each file, newest first. HOW
is :compiled (from its compiled copy), :source (one of Vikix's, a form at
a time) or :yours (your file or a plugin's, always a form at a time).")
(defvar *vikix-fasl-chain* ""
  "The number so far: this Lisp, this StumpWM, and every file loaded yet.")
(defvar *vikix-to-compile* '()
  "Files loaded from their text for want of a copy: (FILE BASE KEY), for
the compiler thread.")
(defvar *vikix-fasl-bad* (make-hash-table :test 'equal)
  "Copies that failed, by name and number: not tried or made again.")
(defvar *vikix-compiler-thread* nil)
(defvar *vikix-loaded-once* nil "True after the first load: the next is a reload.")
(defparameter *vikix-source-only* '("errors" "registry")
  "Files of the layer always loaded from their text: errors.lisp, which is
there before anything can go wrong; and registry.lisp, whose commands each
know the line they are written on (`vikix why` opens it there), which only
a form-at-a-time load can tell them.")

(defun vikix-hash (text)
  "A short number for TEXT, as hex (FNV-1a, 64 bits)."
  (let ((h #xcbf29ce484222325))
    (loop for c across text
          do (setf h (logand (* (logxor h (char-code c)) #x100000001b3) #xffffffffffffffff)))
    (format nil "~(~16,'0x~)" h)))

(defun vikix-fasl-shared-p ()
  (let ((dir (sb-posix:getenv "VIKIX_FASL_DIR")))
    (and dir (plusp (length dir)))))

(defun vikix-fasl-dir ()
  (if (vikix-fasl-shared-p)
      (uiop:ensure-directory-pathname (sb-posix:getenv "VIKIX_FASL_DIR"))
      (merge-pathnames ".cache/vikix/fasl/" (user-homedir-pathname))))

(defun vikix-fasl (base key)
  (merge-pathnames (format nil "~a-~a.fasl" base key) (vikix-fasl-dir)))

(defun vikix-load-compiled (file base key)
  "Load FILE from its compiled copy, when there is one. :compiled, or nil
(no copy, or it failed: the caller then loads the text)."
  (let ((fasl (vikix-fasl base key)))
    (when (and (not (gethash (format nil "~a-~a" base key) *vikix-fasl-bad*))
               (probe-file fasl))
      (handler-case
          (let ((*vikix-loading-file* (truename file))
                (*package* *package*))
            (load fasl)
            :compiled)
        (error ()
          (setf (gethash (format nil "~a-~a" base key) *vikix-fasl-bad*) t)
          (ignore-errors (delete-file fasl))
          nil)))))

(defun vikix-fasl-tidy (base key)
  "Throw away the copies of BASE as it was. In a folder of your own, all
of them; in a shared one (the tests'), those not made in the last three days."
  (dolist (old (directory (merge-pathnames "*.fasl" (vikix-fasl-dir))))
    (let* ((name (pathname-name old))
           (dash (- (length name) 17)))
      (when (and (plusp dash)
                 (char= (char name dash) #\-)
                 (string= base name :end2 dash)
                 (string/= key name :start2 (1+ dash))
                 (or (not (vikix-fasl-shared-p))
                     (> (- (get-universal-time) (or (ignore-errors (file-write-date old)) 0))
                        (* 3 24 3600))))
        (ignore-errors (delete-file old))))))

(defun vikix-compile-copy (file base key)
  "Make FILE's compiled copy. True when it is there afterwards."
  (let ((fasl (vikix-fasl base key))
        (name (format nil "~a-~a" base key)))
    (or (probe-file fasl)
        (gethash name *vikix-fasl-bad*)
        (handler-case
            (let ((tmp (merge-pathnames (format nil "~a.making~d" name (sb-posix:getpid)) (vikix-fasl-dir)))
                  (quiet (make-broadcast-stream)))
              (ensure-directories-exist fasl)
              (let ((*compile-verbose* nil) (*compile-print* nil)
                    (*error-output* quiet) (*standard-output* quiet)
                    (*package* (find-package :stumpwm)))
                (handler-bind ((warning #'muffle-warning))
                  (compile-file file :output-file tmp)))
              (cond ((probe-file tmp)
                     ;; In one step: another StumpWM (a test's) may be making the same.
                     (sb-posix:rename (namestring tmp) (namestring fasl))
                     (vikix-fasl-tidy base key)
                     t)
                    (t (setf (gethash name *vikix-fasl-bad*) t) nil)))
          (error ()
            (setf (gethash name *vikix-fasl-bad*) t)
            nil)))))

(defun vikix-compile-later ()
  "Compile, in a thread of its own, the files this load read from their
text for want of a copy. One thread at a time; a newer load's list is
picked up by the one that is running."
  (when (and *vikix-to-compile*
             (not (and *vikix-compiler-thread*
                       (sb-thread:thread-alive-p *vikix-compiler-thread*))))
    (setf *vikix-compiler-thread*
          (sb-thread:make-thread
           (lambda ()
             (ignore-errors
              (sleep 3)                 ; after the load's own rush
              (loop for job = (pop *vikix-to-compile*)
                    while job
                    do (ignore-errors (apply 'vikix-compile-copy job)))))
           :name "vikix-compiler"))))

(defun vikix-load-file (file name &optional key layer)
  "Load FILE. A mistake in it never leaves you with a dead desktop: with
errors.lisp loaded, the file goes a form at a time and you're asked what
to do about the one that failed (the rest still load); without it (a
mistake in errors.lisp itself), the error is shown and the next file loads.
With KEY (Vikix's own files), from its compiled copy when there is one;
when there isn't, the text is loaded and the copy made afterwards. LAYER
says the file is Vikix's, for the note of how it was loaded."
  (let* ((t0 (get-internal-real-time))
         (base (pathname-name file))
         (how (or (and key (vikix-load-compiled file base key))
                  (progn
                    (if (and (fboundp 'vikix-load-forms) (not (equal name "errors.lisp")))
                        (funcall 'vikix-load-forms file name)
                        (handler-case (load file)
                          (error (e)
                            (message "^1Vikix: error in ~a:^n~%~a" name e))))
                    (when key
                      (setf *vikix-to-compile*
                            (append *vikix-to-compile* (list (list file base key)))))
                    (if layer :source :yours)))))
    (push (list name
                (round (* 1000 (- (get-internal-real-time) t0)) internal-time-units-per-second)
                how)
          *vikix-load-times*)
    how))

(defun vikix-load (name)
  "Load one Vikix file."
  (let* ((file (merge-pathnames (concatenate 'string name ".lisp") *vikix-dir*))
         (text (ignore-errors (uiop:read-file-string file))))
    ;; Every file goes into the number, the ones loaded from text too.
    (setf *vikix-fasl-chain* (vikix-hash (concatenate 'string *vikix-fasl-chain* (or text name))))
    (vikix-load-file file (concatenate 'string name ".lisp")
                     (and text (not (member name *vikix-source-only* :test #'string=))
                          *vikix-fasl-chain*)
                     t)))

(defun vikix-note-load (seconds)
  "Write down what this load took: each file in ~/.local/state/vikix/load-times
(`vikix times files`), and a reload's whole in the times log."
  (ignore-errors
   (let ((file (merge-pathnames ".local/state/vikix/load-times" (user-homedir-pathname))))
     (ensure-directories-exist file)
     (with-open-file (out file :direction :output :if-exists :supersede)
       (format out "~,2f ~:[start~;reload~]~%" seconds *vikix-loaded-once*)
       (loop for (name ms how) in (reverse *vikix-load-times*)
             do (format out "~d ~(~a~) ~a~%" ms how name)))))
  (when (and *vikix-loaded-once* (fboundp 'vikix-time-note))
    (funcall 'vikix-time-note "reload" seconds)))

(setf *vikix-load-times* '()
      *vikix-to-compile* '()
      *vikix-fasl-chain* (format nil "~a ~a ~a" (lisp-implementation-version)
                                 (ignore-errors (file-write-date sb-ext:*runtime-pathname*))
                                 (ignore-errors (uiop:read-file-string
                                                 (merge-pathnames ".stumpwm.d/init.lisp" (user-homedir-pathname))))))
(defvar *vikix-load-started* 0)
(setf *vikix-load-started* (get-internal-real-time))

(mapc #'vikix-load *vikix-files*)

;; Your rules (rules.lisp, when you have one), then your file, last.
(let ((rules (merge-pathnames ".stumpwm.d/rules.lisp" (user-homedir-pathname)))
      (user (merge-pathnames ".stumpwm.d/user.lisp" (user-homedir-pathname))))
  (when (probe-file rules)
    (vikix-load-file rules "rules.lisp"))
  (when (probe-file user)
    (vikix-load-file user "user.lisp")))

(vikix-note-load (/ (- (get-internal-real-time) *vikix-load-started*)
                    (float internal-time-units-per-second 1d0)))
(setf *vikix-loaded-once* t)
(vikix-compile-later)
