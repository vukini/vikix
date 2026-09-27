# wordfreq (Julia)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: run it inside `julia` with `include("wordfreq.jl")` after setting
`push!(ARGS, "text.txt")`, then look at `counts` yourself.
Docs: https://docs.julialang.org, "Strings" and "Collections".
