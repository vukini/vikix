# wordfreq (WebAssembly)

The ten most common words in `text.txt` (the Gettysburg Address): the
same program as in every other language in `~/dev`, printing exactly the
same thing, and in fact the very same C as the C example, compiled to
WebAssembly by `zig cc` and run by wasmtime.

    make run
    make check      # the same answer as expected.txt?

Try: `ls -l wordfreq.wasm` and compare with the C one's size; drop
`--dir=.` from the run line and see it refused the file (examples/sandbox
is about that).
Docs: https://wasi.dev (what WASI gives a program); `zig cc --help`.
