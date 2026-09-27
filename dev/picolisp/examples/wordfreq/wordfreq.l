# wordfreq.l — the ten most common words in a text file.
#
# A word is a run of letters, compared in lower case. The characters are
# read one at a time; each word is counted with accu into an association
# list, which sort then orders, most common first.
#
#   pil wordfreq.l text.txt

(de count-words (File)
   (let (Counts NIL  Word NIL)
      (in File
         (while (char)
            (let C (lowc @)
               (if (and (>= C "a") (>= "z" C))
                  (push 'Word C)
                  (when Word
                     (accu 'Counts (pack (flip Word)) 1)
                     (off Word) ) ) ) )
         (when Word (accu 'Counts (pack (flip Word)) 1)) )
      Counts ) )

# The higher count first; the same count in alphabetical order.
(de before (A B)
   (if (= (cdr A) (cdr B))
      (> (car B) (car A))
      (> (cdr A) (cdr B)) ) )

(if (opt)
   (for Entry (head 10 (sort (count-words @) before))
      (prinl (align 4 (cdr Entry)) " " (car Entry)) )
   (prinl "usage: pil wordfreq.l FILE") )
(bye)
