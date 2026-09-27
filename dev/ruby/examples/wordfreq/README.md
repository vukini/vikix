# wordfreq (Ruby)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing, as one chain of steps.

    make run
    make check      # the same answer as expected.txt?

Try: in `irb`, build the chain one step at a time, looking at each result:
`File.read("text.txt").downcase.scan(/[a-z]+/).tally`.
Docs: `ri Enumerable#tally`, `ri Enumerable#sort_by`.
