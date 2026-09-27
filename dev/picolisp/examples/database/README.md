# database (PicoLisp)

What PicoLisp is known for: a database that is part of the language.
A class `+Person`, stored in `people.db`, indexed by name and language;
the program adds three people, finds them through the indexes, and
gives one a birthday. Run it again: they are still there, a year older.

    make run
    make clean      # start over with no people.db

Try: `pil +`, then `(load "database.l")` without its last line, and
look around: `(show (db 'nm '+Person "Ada"))`; add a `(rel email (+String))`.
Docs: the database chapter of the PicoLisp tutorial: https://software-lab.de/doc/tut.html
