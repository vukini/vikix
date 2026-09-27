# wordfreq (Lua)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: `%a+` is a Lua pattern, simpler than a regular expression; try
`%a+'?%a*` to keep words like "don't" whole. Time it with `luajit` too.
Docs: the manual, "Patterns" (6.4.1) and `table.sort`.
