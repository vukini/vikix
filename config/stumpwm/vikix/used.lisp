;;;; used.lisp — what gets used: counts of the keys you press and the
;;;; commands you run, kept on this machine.
;;;;
;;;; Vikix has over a hundred keys and as many menu entries. Which do you
;;;; use? The desktop already notes each key, menu entry, rule and typed
;;;; command for `vikix why` (why.lisp); here each is also counted, and the
;;;; counts kept from one login to the next.
;;;;
;;;;   vikix used          the keys you use most, and how many you never have
;;;;   vikix used never    the keys never pressed since counting began
;;;;   vikix used all      every count
;;;;   vikix used forget   start counting again
;;;;
;;;; What is counted: a key with the command it ran, an entry of Super+m, a
;;;; pick in the palette (which kind, and which command), a command you
;;;; typed after Ctrl+t ; (its name, not what followed it), a rule that
;;;; ran, a command an agent ran. Only names and numbers, with when each
;;;; was first and last seen: never a window's title, nothing you typed. The file is ~/.local/state/vikix/used, yours to read or delete;
;;;; nothing sends it anywhere.

(in-package :stumpwm)

(defvar *vikix-used* (make-hash-table :test 'equal)
  "\"KIND<tab>WHAT\" to (COUNT FIRST LAST), the two as universal times.")
(defvar *vikix-used-since* nil "When counting began (a universal time).")
(defvar *vikix-used-read* nil "True once the file has been read.")
(defvar *vikix-used-changed* nil "True when there is something to write.")
(defvar *vikix-used-timer* nil)
(defparameter *vikix-used-every* 300
  "Seconds between writes of the counts (a whole number: a timer's).")

(defun vikix-used-file ()
  (merge-pathnames "used" (vikix-state-dir)))

(defun vikix-used-plain (text)
  "TEXT on one line, no tabs: a field of the file."
  (substitute #\Space #\Tab (substitute #\Space #\Newline (princ-to-string text))))

(defun vikix-used-what (kind id)
  "What to count for a thing why.lisp noted, or nil for what isn't counted
(a command a script or the bar asked for: that isn't you choosing)."
  (case kind
    (:key (and (consp id) (stringp (first id)) (stringp (second id))
               (format nil "~a~c~a" (vikix-used-plain (first id)) #\Tab (vikix-used-plain (second id)))))
    (:menu (and (stringp id) (vikix-used-plain id)))
    (:rule (and (stringp id) (vikix-used-plain (vikix-one-line id 120))))
    (:agent (and id (string-downcase (vikix-used-plain id))))
    ;; A typed command by its name alone: what was typed after it stays out.
    (:asked (and (consp id) (eq (first id) :typed) (stringp (second id))
                 (let ((command (string-trim " " (second id))))
                   (vikix-used-plain (subseq command 0 (position #\Space command))))))
    (:palette (and id (vikix-used-plain id)))))

(defun vikix-used-read ()
  "Read the counts kept from before, once."
  (unless *vikix-used-read*
    (setf *vikix-used-read* t)
    (ignore-errors
     (with-open-file (in (vikix-used-file) :if-does-not-exist nil :external-format :utf-8)
       (when in
         (loop for line = (read-line in nil)
               while line
               do (let ((fields (split-string line (string #\Tab))))
                    (cond ((and (equal (first fields) "since") (second fields))
                           (setf *vikix-used-since* (ignore-errors (parse-integer (second fields)))))
                          ((>= (length fields) 5)
                           (let ((count (ignore-errors (parse-integer (second fields))))
                                 (first-seen (ignore-errors (parse-integer (third fields))))
                                 (last-seen (ignore-errors (parse-integer (fourth fields)))))
                             (when (and count first-seen last-seen)
                               (setf (gethash (format nil "~a~{~c~a~}" (first fields)
                                                      (loop for field in (nthcdr 4 fields)
                                                            collect #\Tab collect field))
                                              *vikix-used*)
                                     (list count first-seen last-seen)))))))))))
    (unless *vikix-used-since*
      (setf *vikix-used-since* (get-universal-time)
            *vikix-used-changed* t))))

(defun vikix-used-write ()
  "Write the counts down. True when it did."
  (vikix-used-read)
  (ignore-errors
   (let ((file (vikix-used-file)))
     (ensure-directories-exist file)
     (with-open-file (out file :direction :output :if-exists :supersede :external-format :utf-8)
       (format out "since~c~d~%" #\Tab *vikix-used-since*)
       (maphash (lambda (key value)
                  (let ((tab (position #\Tab key)))
                    (format out "~a~c~d~c~d~c~d~c~a~%"
                            (subseq key 0 tab) #\Tab (first value) #\Tab (second value) #\Tab (third value)
                            #\Tab (subseq key (1+ tab)))))
                *vikix-used*))
     (setf *vikix-used-changed* nil)
     t)))

(defun vikix-used-note (kind id)
  "Count one use. From why.lisp's note of the same thing. Never an error."
  (ignore-errors
   (let ((what (vikix-used-what kind id)))
     (when what
       (vikix-used-read)
       (let* ((key (format nil "~(~a~)~c~a" kind #\Tab what))
              (now (get-universal-time))
              (old (gethash key *vikix-used*)))
         (setf (gethash key *vikix-used*)
               (if old
                   (list (1+ (first old)) (second old) now)
                   (list 1 now now))
               *vikix-used-changed* t))))))

(defun vikix-used-count (kind what)
  "How often WHAT of KIND was used: for the tests, and for you at the REPL."
  (vikix-used-read)
  (first (gethash (format nil "~(~a~)~c~a" kind #\Tab what) *vikix-used* '(0))))

(defun vikix-used-forget ()
  "Start counting again, from now."
  (clrhash *vikix-used*)
  (setf *vikix-used-read* t
        *vikix-used-since* (get-universal-time))
  (vikix-used-write))

(defun vikix-used-tick ()
  (when *vikix-used-changed* (vikix-used-write)))

(defun vikix-used-keys ()
  "Print every key there is, for `vikix used`: the name it is bound under,
as the keyboard says it, its command and what it does, parted by tabs."
  (when (boundp '*vikix-bindings*)
    (dolist (binding (symbol-value '*vikix-bindings*))
      (destructuring-bind (key command description &rest more) binding
        (declare (ignore more))
        (format t "~a~c~a~c~a~c~a~%"
                (vikix-used-plain key) #\Tab
                (vikix-used-plain (if (fboundp 'vikix-pretty-key) (funcall 'vikix-pretty-key key) key)) #\Tab
                (vikix-used-plain command) #\Tab (vikix-used-plain description)))))
  (values))

(remove-hook *quit-hook* 'vikix-used-write)
(add-hook *quit-hook* 'vikix-used-write)

(when (and (boundp '*screen-list*) *screen-list*)
  (when (timer-p *vikix-used-timer*) (cancel-timer *vikix-used-timer*))
  (setf *vikix-used-timer* (run-with-timer *vikix-used-every* *vikix-used-every* 'vikix-used-tick)))
