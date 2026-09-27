# wordfreq (C)

The ten most common words in `text.txt` (the Gettysburg Address). Every
language in `~/dev` has this same program, printing exactly the same
thing, so you can put two side by side and compare.

    make run
    make check      # the same answer as expected.txt?

Try: count `text.txt` of your own; print all the words, not ten; replace
the plain search in `count()` with a hash table and time both
(`hyperfine './wordfreq big.txt'`).
Docs: `man 3 qsort`, `man 3 fgetc`, `man 3 realloc`.
