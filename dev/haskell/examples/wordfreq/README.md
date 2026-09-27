# wordfreq (Haskell)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing. Here it is a pipeline of small pure functions.

    make run
    make check      # the same answer as expected.txt?

Try: load it in ghci (`ghci Main.hs`) and call the pieces on their own:
`wordsOf "Four score"`, `top 3 ["a","b","a"]`.
Docs: Zeal's Haskell docset, Data.Map.Strict and Data.List.
