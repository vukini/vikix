# wordfreq (Zig)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: swap the arena for `std.heap.GeneralPurposeAllocator` and free
things yourself: in a debug build it reports anything you forgot;
`zig build -Doptimize=ReleaseFast` and time it against the C one.
Docs: `zig std`, then StringHashMap and mem.sort.
