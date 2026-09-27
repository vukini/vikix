# wordfreq (Scheme)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing. The loop is a named `let`: in Scheme a loop is just a
function that calls itself last.

    make run
    make check      # the same answer as expected.txt?

Try: in `scheme`, `(load "wordfreq.ss")`, then `(main "text.txt")`, and
the pieces: `(count-words "a b a")`, `(hashtable-entries (count-words "a b a"))`.
Docs: The Scheme Programming Language, chapter 6 (see ~/dev/scheme/README.md).
