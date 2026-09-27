;;;; wordfreq.lisp — the ten most common words in a text file.
;;;;
;;;; A word is a run of letters, compared in lower case. An equal
;;;; hash table counts them; sort with a two-part test puts the most
;;;; common first.
;;;;
;;;;   sbcl --script wordfreq.fasl text.txt

(defun read-file (path)
  (with-open-file (in path)
    (let ((text (make-string (file-length in))))
      (subseq text 0 (read-sequence text in)))))

(defun count-words (text)
  "A hash table from each word of TEXT to how often it appears."
  (let ((counts (make-hash-table :test #'equal))
        (start nil))
    (flet ((end-word (i)
             (when start
               (incf (gethash (subseq text start i) counts 0))
               (setf start nil))))
      (loop for c across text
            for i from 0
            do (if (char<= #\a c #\z)
                   (unless start (setf start i))
                   (end-word i))
            finally (end-word (length text))))
    counts))

(defun main (path)
  (let ((entries '()))
    (maphash (lambda (word count) (push (cons word count) entries))
             (count-words (string-downcase (read-file path))))
    ;; The higher count first; the same count in alphabetical order.
    (setf entries (sort entries (lambda (a b)
                                  (if (/= (cdr a) (cdr b))
                                      (> (cdr a) (cdr b))
                                      (string< (car a) (car b))))))
    (loop for (word . count) in entries
          repeat 10
          do (format t "~4d ~a~%" count word))))

;; Run as a script, the text's file is the argument after the program's
;; own name. Loaded in the REPL there is none: it only says how to call it,
;; rather than exiting and taking the REPL with it.
(let ((args (rest sb-ext:*posix-argv*)))
  (if (= (length args) 1)
      (main (first args))
      (format *error-output* "usage: wordfreq FILE, or in the REPL (main \"text.txt\")~%")))
