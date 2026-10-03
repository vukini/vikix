;;;; plugins.lisp — the plugins you added (vikix plugin add NAME).
;;;;
;;;; A plugin is a folder of the vikix-plugins repo, which Vikix keeps at a
;;;; pinned commit in ~/.local/share/vikix/plugins/; the ones you added are
;;;; named in ~/.config/vikix/plugins.list (a line "#off NAME" is one
;;;; switched off). Each one's Lisp is loaded here a form at a time, as
;;;; Vikix's own files are (errors.lisp): a mistake costs only that form,
;;;; and a menu asks what to do.
;;;;
;;;; What a plugin's Lisp is given:
;;;;   (vikix-plugin-bar NAME FUNCTION &key click)
;;;;       a few words in the bar (%P), from FUNCTION, called at every
;;;;       redraw: it returns nil (nothing), or the text and, as a second
;;;;       value, a colour of the theme (:accent, :subtle, :alert). CLICK is
;;;;       a StumpWM command run on a click on it.
;;;;   (vikix-plugin-key KEY COMMAND DESCRIPTION &optional GROUP)
;;;;       a key, in the key card under GROUP (the plugin's name if none)
;;;;       (a key Vikix had comes back when the plugin goes)
;;;;   (vikix-plugin-menu LABEL ACTION)
;;;;       an entry in Super+m, as *vikix-menu*'s are
;;;; Loading them again (Reload config) first takes away what each gave.
;;;;
;;;; vikix plugin safe: the next login loads none, for a plugin that stops
;;;; the desktop from starting; vikix plugin off NAME then, from a text
;;;; console if need be.

(in-package :stumpwm)

(defparameter *vikix-plugins-dir*
  (merge-pathnames ".local/share/vikix/plugins/" (user-homedir-pathname))
  "Vikix's copy of the plugins repository, at its pinned commit.")

(defparameter *vikix-plugins-list*
  (merge-pathnames ".config/vikix/plugins.list" (user-homedir-pathname))
  "The plugins you added, one name a line.")

(defparameter *vikix-plugins-safe*
  (merge-pathnames ".config/vikix/plugins-safe" (user-homedir-pathname))
  "When this file is there, the next load skips every plugin (and removes it).")

(defvar *vikix-plugin* nil
  "The plugin being loaded: what it registers is marked with its name.")
(defvar *vikix-plugin-bars* '()
  "The bar fields: (PLUGIN FUNCTION CLICK), in the order they came.")
(defvar *vikix-plugin-keys* '()
  "The keys plugins bound, newest first: (PLUGIN KEY OLD-BINDING OLD-COMMAND),
the last two what the key had before, to put back when the plugin goes.")
(defvar *vikix-plugins-loaded* '()
  "The plugins loaded: (NAME . T if all of it loaded, else NIL).")

;;; --- What a plugin is given ----------------------------------------------------

(defun vikix-plugin-bar (name function &key click)
  (setf *vikix-plugin-bars*
        (append (remove name *vikix-plugin-bars* :key #'first :test #'equal)
                (list (list name function click))))
  name)

(defun vikix-plugin-key (key command description &optional group)
  (vikix-note-clash key (format nil "plugin ~a" (or *vikix-plugin* "?")))
  (push (list (or *vikix-plugin* "") key
              (find key *vikix-bindings* :key #'first :test #'equal)
              (ignore-errors (lookup-key *top-map* (kbd key))))
        *vikix-plugin-keys*)
  (vikix-bind key command)
  (setf *vikix-bindings*
        (append (remove key *vikix-bindings* :key #'first :test #'equal)
                (list (list key command description (or group *vikix-plugin* "Plugins")))))
  key)

(defun vikix-plugin-menu-entry-p (entry)
  (and (consp entry) (eq (third entry) :plugin)))

(defun vikix-plugin-menu (label action)
  ;; Marked :plugin (a third element), so a reload can find them; before
  ;; the last entry, Power, so that one stays at the bottom.
  (let ((power (last *vikix-menu*)))
    (setf *vikix-menu*
          (append (butlast (remove label *vikix-menu* :key #'first :test #'equal))
                  (list (list label action :plugin))
                  power)))
  label)

;;; --- The bar: %P --------------------------------------------------------------------

(defun vikix-plugin-click (button command &rest ignore)
  (declare (ignore ignore))
  (when (and (eql button 1) (stringp command))
    (ignore-errors (run-commands command))))

(register-ml-on-click-id :vikix-plugin-click 'vikix-plugin-click)

(defun vikix-mode-line-plugins (ml)
  "Each plugin's few words, in the order they were added. One that fails
shows nothing: the bar is redrawn every second, so it never asks."
  (declare (ignore ml))
  (with-output-to-string (out)
    (dolist (bar *vikix-plugin-bars*)
      (destructuring-bind (name function click) bar
        (declare (ignore name))
        (multiple-value-bind (text colour) (ignore-errors (funcall function))
          (when (and (stringp text) (plusp (length text)))
            (let* ((text (ppcre:regex-replace-all "\\^" text "^^"))
                   (shown (if (member colour '(:accent :subtle :alert))
                              (format nil "^(:push)^(:fg \"~a\")~a^(:pop)" (vikix-colour colour) text)
                              text)))
              (format out "~a  " (if click
                                     (format nil "^(:on-click :vikix-plugin-click ~s)~a^(:on-click-end)" click shown)
                                     shown)))))))))

(add-screen-mode-line-formatter #\P 'vikix-mode-line-plugins)

;;; --- Loading them ---------------------------------------------------------------------

(defun vikix-plugin-names ()
  "The plugins added and on, from plugins.list."
  (with-open-file (in *vikix-plugins-list* :if-does-not-exist nil)
    (when in
      (loop for line = (read-line in nil)
            while line
            for name = (string-trim '(#\Space #\Tab) line)
            when (and (plusp (length name)) (char/= (char name 0) #\#))
              collect name))))

(defun vikix-plugin-manifest (name key)
  "KEY's value in plugin NAME's manifest, or nil."
  (with-open-file (in (merge-pathnames (format nil "~a/manifest" name) *vikix-plugins-dir*)
                      :if-does-not-exist nil)
    (when in
      (let ((prefix (format nil "~a:" key)))
        (loop for line = (read-line in nil)
              while line
              when (eql 0 (search prefix line))
                return (string-trim '(#\Space #\Tab) (subseq line (length prefix))))))))

(defun vikix-unload-plugins ()
  "Take away what plugins gave: bar fields, keys, menu entries. (Hooks a
plugin added stay until StumpWM starts again.)"
  ;; Newest first, so a key two plugins took ends with what it had before both.
  (dolist (k *vikix-plugin-keys*)
    (destructuring-bind (plugin key &optional old-binding old-command) k
      (declare (ignore plugin))
      (ignore-errors (if old-command
                         (define-key *top-map* (kbd key) old-command)
                         (undefine-key *top-map* (kbd key))))
      (setf *vikix-bindings* (remove key *vikix-bindings* :key #'first :test #'equal))
      (when old-binding
        (setf *vikix-bindings* (append *vikix-bindings* (list old-binding))))))
  (vikix-forget-clashes "plugin ")
  (setf *vikix-plugin-keys* '()
        *vikix-plugin-bars* '()
        *vikix-plugins-loaded* '()
        *vikix-menu* (remove-if #'vikix-plugin-menu-entry-p *vikix-menu*)))

(defun vikix-load-plugins ()
  "Load the plugins added, each one's Lisp a form at a time. Returns how
many loaded."
  (vikix-unload-plugins)
  (cond ((probe-file *vikix-plugins-safe*)
         ;; One login without them; the next loads them again.
         (ignore-errors (delete-file *vikix-plugins-safe*))
         (message "^1Vikix: plugins not loaded this time^n (vikix plugin safe).~%vikix plugin off NAME switches one off.")
         0)
        (t
         (prog1 (dolist (name (vikix-plugin-names) (length *vikix-plugins-loaded*))
                  (let* ((lisp (vikix-plugin-manifest name "lisp"))
                         (file (and lisp (probe-file (merge-pathnames (format nil "~a/~a" name lisp)
                                                                      *vikix-plugins-dir*)))))
                    (cond ((null (vikix-plugin-manifest name "name"))
                           (message "^1Vikix: plugin ~a isn't there^n (vikix plugin sync fetches it)" name))
                          ((null lisp))           ; a plugin with no Lisp: nothing to load here
                          ((null file)
                           (message "^1Vikix: plugin ~a: its ~a isn't there^n" name lisp))
                          (t
                           (let ((*vikix-plugin* name))
                             (push (cons name (vikix-load-file file (format nil "~a/~a" name lisp)))
                                   *vikix-plugins-loaded*)))))
          (vikix-say-clashes "plugin "))))))

(defcommand vikix-plugins-reload () ()
  "Load the plugins again (after vikix plugin add, remove or off)."
  (message "Plugins loaded: ~d" (vikix-load-plugins)))

(vikix-load-plugins)
