# sandbox (WebAssembly)

What WebAssembly is known for: running code safely, anywhere. The same
small C program (`peek`, print a file's first line) is run three times:
given no folder, it can't open anything; given this folder, it reads
`secret.txt`; asking for a file outside that folder, it's refused again.
The program didn't change; wasmtime decided each time.

    make run

Try: give it `--dir=/etc` and peek at `/etc/hostname`; copy `peek.wasm`
to another computer with wasmtime (any OS) and run it there unchanged.
Docs: https://wasi.dev, and wasmtime's `--dir` in `wasmtime run --help`.
