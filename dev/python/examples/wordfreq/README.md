# wordfreq (Python)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing. Compare its length with the C one.

    make run
    make check      # the same answer as expected.txt?

Try: `counts.most_common(10)` is almost the same, but breaks ties in the
order words first appeared; see where it differs from expected.txt.
Docs: `pydoc collections.Counter`, `pydoc re.findall`.
