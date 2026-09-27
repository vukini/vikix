# database.l — PicoLisp's own database, built into the language.
#
# A class of objects, +Person, whose objects live in a file on disk.
# rel declares each property; +Ref makes an index on it, so people can be
# found by name without reading them all. new! creates an object and
# commits it at once. Run it twice: the second time the people are
# already in people.db.

(class +Person +Entity)
(rel nm  (+Ref +String))     # the name, indexed
(rel age (+Number))
(rel lang (+Ref +String))    # a favourite language, indexed too

(pool "people.db")           # open (or create) the database file

(if (collect 'nm '+Person)
   (prinl "people.db already has " (length @) " people")
   (prinl "a new people.db; adding three people")
   (new! '(+Person) 'nm "Ada" 'age 36 'lang "PicoLisp")
   (new! '(+Person) 'nm "Grace" 'age 45 'lang "COBOL")
   (new! '(+Person) 'nm "Alan" 'age 41 'lang "PicoLisp") )

(prinl "everyone, in name order (from the index):")
(for P (collect 'nm '+Person)
   (prinl "  " (; P nm) ", " (; P age) ", likes " (; P lang)) )

(prinl "who likes PicoLisp:")
(for P (collect 'lang '+Person "PicoLisp")
   (prinl "  " (; P nm)) )

(let P (db 'nm '+Person "Grace")      # one object, found by name
   (put!> P 'age (inc (; P age)))     # a birthday, committed
   (prinl "Grace is now " (; P age)) )

(bye)
