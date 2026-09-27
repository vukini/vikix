;;; callcc.ss — two things Scheme is known for: continuations and tail calls.
;;;
;;; call/cc hands you "the rest of the computation" as a function. Calling
;;; it jumps straight there, out of however many calls deep you are: here,
;;; out of a search through a nested list, the moment it finds what it's
;;; looking for. Other languages build exceptions, generators and
;;; coroutines in; Scheme lets you make them from this one idea.
;;;
;;; And a call in tail position (the last thing a function does) doesn't
;;; grow the stack, so a loop can be a function calling itself, forever.
(import (chezscheme))

;; The first negative number anywhere in TREE, or #f.
(define (first-negative tree)
  (call/cc
    (lambda (found)                     ; found = "return from first-negative"
      (let walk ([t tree])
        (cond
          [(pair? t) (walk (car t)) (walk (cdr t))]
          [(and (number? t) (negative? t)) (found t)]   ; jump out, all the way
          [else #f]))
      #f)))

(printf "first negative in ((1 2) (3 (4 -5 6)) -7): ~a\n"
        (first-negative '((1 2) (3 (4 -5 6)) -7)))
(printf "first negative in (1 (2 3)): ~a\n" (first-negative '(1 (2 3))))

;; Counting to ten million by calling itself: no stack to run out of.
(define (count-up i limit)
  (if (= i limit)
      i
      (count-up (+ i 1) limit)))        ; a tail call: it replaces this one

(printf "counted to ~a by calling itself\n" (count-up 0 10000000))
