# wordfreq (SQL)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing, in one SQL query. No loops: a recursive query walks the text,
a window function numbers the words, and GROUP BY does the rest.

    make run
    make check      # the same answer as expected.txt?

Try: run each part of the WITH on its own (`SELECT * FROM chars LIMIT 20;`
after the WITH) to see what it makes; count letters instead of words.
Docs: the SQLite docs on WITH RECURSIVE and window functions (offline, ~/dev/sql/docs).
