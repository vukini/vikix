#lang racket/base
;; pictures.rkt — pictures are values: draw with functions.
;;
;; In Racket's pict library a picture is a value like a number, and
;; functions combine pictures: beside, above, scaled. So a drawing can be
;; recursive: a Sierpinski triangle is three smaller Sierpinski triangles.
;; In DrRacket, a pict prints as the picture itself at the prompt.
(require pict racket/class)

;; A triangle made of N levels of smaller triangles.
(define (sierpinski n)
  (if (= n 0)
      (colorize (filled-rectangle 6 6) "steelblue")
      (let ([smaller (sierpinski (- n 1))])
        (vc-append smaller (hc-append smaller smaller)))))

(define picture
  (vc-append 10
             (text "Sierpinski, 6 levels" 'modern 16)
             (sierpinski 6)))

(void (send (pict->bitmap picture) save-file "triangle.png" 'png))
(printf "drew triangle.png, ~a by ~a pixels\n" (pict-width picture) (pict-height picture))
