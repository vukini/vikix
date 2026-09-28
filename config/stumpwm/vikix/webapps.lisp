;;;; webapps.lisp — your web apps (vikix webapp), on keys and in Super+m.
;;;;
;;;; `vikix webapp add` writes ~/.config/vikix/webapps, one "NAME URL [KEY]"
;;;; per line. This reads it: each web app's key, if it has one, brings its
;;;; window to the front from any workspace, or starts it (run-or-raise, by
;;;; its window class, vikix-NAME); it's in the key help (Super+F1) and in
;;;; Super+m. `vikix webapp` calls vikix-load-webapps after each change, so
;;;; nothing waits for a reload.

(in-package :stumpwm)

(defparameter *vikix-webapps-file*
  (merge-pathnames ".config/vikix/webapps" (user-homedir-pathname))
  "Your web apps: one \"NAME URL [KEY]\" per line.")

(defvar *vikix-webapp-keys* nil
  "The keys bound to web apps, so a reload unbinds the ones that went.")

(defun vikix-read-webapps ()
  "The web apps, as (NAME URL KEY) lists; KEY is NIL when there's none."
  (with-open-file (in *vikix-webapps-file* :if-does-not-exist nil)
    (when in
      (loop for line = (read-line in nil)
            while line
            for words = (remove "" (split-string (string-trim '(#\Space #\Tab) line) " ")
                                :test #'string=)
            when (and words (char/= (char (first words) 0) #\#))
              collect (list (first words) (second words) (third words))))))

(defun vikix-webapp-title (name)
  (string-capitalize name))

(defcommand vikix-webapp (name) ((:string "Web app: "))
  "Bring the web app NAME to the front, on whatever workspace it is, or start it."
  (run-or-raise (format nil "vikix-webapp launch ~a" name)
                (list :class (format nil "vikix-~a" name))))

(defun vikix-webapp-entry-p (label-or-command prefix)
  (and (stringp label-or-command)
       (eql 0 (search prefix label-or-command))))

(defun vikix-load-webapps ()
  "Read the web apps again: their keys, key help and Super+m entries."
  (dolist (key *vikix-webapp-keys*)
    (undefine-key *top-map* (kbd key)))
  (setf *vikix-webapp-keys* nil
        *vikix-bindings* (remove-if (lambda (b) (vikix-webapp-entry-p (second b) "vikix-webapp "))
                                    *vikix-bindings*)
        *vikix-menu* (remove-if (lambda (e) (vikix-webapp-entry-p (first e) "Web app: "))
                                *vikix-menu*))
  (let ((entries '()))
    (dolist (app (vikix-read-webapps))
      (destructuring-bind (name url &optional key) app
        (declare (ignore url))
        (let ((command (format nil "vikix-webapp ~a" name))
              (title (vikix-webapp-title name)))
          (when key
            (vikix-bind key command)
            (push key *vikix-webapp-keys*)
            (setf *vikix-bindings*
                  (append *vikix-bindings*
                          (list (list key command (format nil "~a (web app)" title))))))
          (push (list (format nil "Web app: ~a" title) (list 'vikix-webapp name)) entries))))
    ;; Before the last entry, Power, so that one stays at the bottom.
    (let ((power (last *vikix-menu*)))
      (setf *vikix-menu* (append (butlast *vikix-menu*) (nreverse entries) power))))
  (length *vikix-webapp-keys*))

(vikix-load-webapps)
