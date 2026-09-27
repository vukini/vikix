# hello (WebAssembly)

WebAssembly written by hand, in its text format: `make` assembles it
into a `.wasm` file, and wasmtime runs that. Everything the program does
outside itself goes through a function the host gives it, here WASI's
fd_write.

    make run

Try: `wasm2wat hello.wasm` turns it back into text; `wasm-objdump -d
hello.wasm` shows the instructions; change the text (and its length, 23).
Docs: MDN, "Understanding WebAssembly text format" (see ~/dev/wasm/README.md).
