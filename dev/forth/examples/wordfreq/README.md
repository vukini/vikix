# wordfreq (Forth)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing. Forth has no hash table, so it borrows its own dictionary:
each word of the text becomes a Forth word in a wordlist, holding its count.

    make run
    make check      # the same answer as expected.txt?

Try: change the last line, `main bye`, to just `main`; then
`gforth wordfreq.fs text.txt` leaves you at a prompt, where
`counted >order words` lists every word of the text as a Forth word and
`that @ .` prints 13.
Docs: `info gforth`, "Word Lists" and "Defining words".
