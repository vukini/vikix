;;; wordfreq.ss — the ten most common words in a text file.
;;;
;;; A word is a run of letters, compared in lower case. A string hashtable
;;; counts them; sort with a two-part test puts the most common first.
;;;
;;;   scheme --program wordfreq.so text.txt
(import (chezscheme))

(define (count-words text)
  (let ([counts (make-hashtable string-hash string=?)])
    (let loop ([i 0] [start #f])
      (define (end-word)
        (when start
          (hashtable-update! counts (substring text start i) add1 0)))
      (cond
        [(= i (string-length text)) (end-word)]
        [(char<=? #\a (string-ref text i) #\z) (loop (+ i 1) (or start i))]
        [else (end-word) (loop (+ i 1) #f)]))
    counts))

;; The higher count first; the same count in alphabetical order.
(define (before? a b)
  (if (= (cdr a) (cdr b))
      (string<? (car a) (car b))
      (> (cdr a) (cdr b))))

(define (main path)
  (let-values ([(words counts)
                (hashtable-entries
                  (count-words (string-downcase
                                 (call-with-input-file path get-string-all))))])
    (let loop ([entries (sort before? (map cons (vector->list words) (vector->list counts)))]
               [n 0])
      (unless (or (null? entries) (= n 10))
        (printf "~4d ~a\n" (cdar entries) (caar entries))
        (loop (cdr entries) (+ n 1))))))

;; Run as a program, the text's file follows the program's name. Loaded in
;; the REPL there is none: it only says how to call it, rather than exiting.
(let ([args (cdr (command-line))])
  (if (= (length args) 1)
      (main (car args))
      (display "usage: wordfreq FILE, or in the REPL (main \"text.txt\")\n" (current-error-port))))
