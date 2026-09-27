;;;; macros.lisp — macros: Lisp code that writes Lisp code.
;;;;
;;;; Lisp programs are lists, so a program can build programs. A macro
;;;; receives its arguments unevaluated, as code, and returns new code,
;;;; which runs in its place. That is how Lisp grows new control
;;;; structures, like the two below, without changing the compiler.
;;;; macroexpand-1 shows what a macro turns into.

;; while: repeat BODY as long as TEST holds. The backquote builds the
;; new code from a template; comma puts the arguments in.
(defmacro while (test &body body)
  `(loop (unless ,test (return))
         ,@body))

;; with-timing: run BODY and say how long it took. gensym makes a name
;; that can't clash with a variable in BODY.
(defmacro with-timing (label &body body)
  (let ((start (gensym "START")))
    `(let ((,start (get-internal-real-time)))
       (multiple-value-prog1 (progn ,@body)
         (format t "~a took ~,3f s~%" ,label
                 (/ (- (get-internal-real-time) ,start)
                    internal-time-units-per-second))))))

(defun show-expansion (form)
  (format t "~s~%  expands to~%~s~%~%" form (macroexpand-1 form)))

(show-expansion '(while (< i 3) (print i) (incf i)))
(show-expansion '(with-timing "sum" (loop for i below 10 sum i)))

(let ((i 0))
  (while (< i 3)
    (format t "while: i = ~a~%" i)
    (incf i)))

(with-timing "summing a million numbers"
  (loop for i below 1000000 sum i))
