# wordfreq (OCaml)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: replace the Hashtbl with an immutable `Map.Make (String)` threaded
through a fold; notice that the compiler found every type without one
annotation.
Docs: https://ocaml.org/manual (the standard library: Hashtbl, List, Buffer).
