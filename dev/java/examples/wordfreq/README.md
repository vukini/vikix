# wordfreq (Java)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: write the counting as one stream too, with
`Collectors.groupingBy(w -> w, Collectors.counting())`; try each line in
`jshell` first.
Docs: Zeal's Java docset, java.util.Map and java.util.stream.
