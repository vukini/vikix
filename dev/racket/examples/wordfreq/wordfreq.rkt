#lang racket/base
;; wordfreq.rkt — the ten most common words in a text file.
;;
;; A word is a run of letters, compared in lower case. regexp-match* finds
;; them all, a hash counts them, and sort with a two-part test puts the
;; most common first.
;;
;;   racket wordfreq.rkt text.txt
(require racket/file racket/format racket/list)

(define (top-words path n)
  (define counts (make-hash))
  (for ([word (regexp-match* #px"[a-z]+" (string-downcase (file->string path)))])
    (hash-update! counts word add1 0))
  ;; The higher count first; the same count in alphabetical order.
  (take (sort (hash->list counts)
              (λ (a b) (if (= (cdr a) (cdr b))
                           (string<? (car a) (car b))
                           (> (cdr a) (cdr b)))))
        (min n (hash-count counts))))

(module+ main
  (define args (current-command-line-arguments))
  (unless (= (vector-length args) 1)
    (eprintf "usage: wordfreq FILE\n")
    (exit 2))
  (for ([entry (top-words (vector-ref args 0) 10)])
    (printf "~a ~a\n" (~a (cdr entry) #:min-width 4 #:align 'right) (car entry))))
