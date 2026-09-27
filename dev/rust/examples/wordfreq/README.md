# wordfreq (Rust)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing.

    make run
    make check      # the same answer as expected.txt?

Try: compare with `~/dev/c/examples/wordfreq/wordfreq.c`: no free(), no
buffer sizes; `cargo build --release` and time both on a big file
with `hyperfine`.
Docs: the book, chapter 8.3 (hash maps): `~/dev/rust/docs/rust/book/ch08-03-hash-maps.html`.
