# wordfreq (Common Lisp)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: in the REPL (`sbcl`, or SLIME in Emacs), `(load "wordfreq.lisp")`,
then `(main "text.txt")`, and look at the pieces: `(count-words "a b a")`.
Docs: the HyperSpec for `sort`, `maphash`, `loop`, `format`.
