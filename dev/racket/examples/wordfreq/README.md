# wordfreq (Racket)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing. The part that runs from the command line is in a `main`
submodule, so the file can also be loaded without running it.

    make run
    make check      # the same answer as expected.txt?

Try: open it in DrRacket, press Run, then call `(top-words "text.txt" 3)`
at the prompt below.
Docs: the Racket guide, "Hash Tables" and "Regular Expressions" (offline in ~/dev/racket/docs).
