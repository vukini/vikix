# make        compile wordfreq.c to wordfreq.wasm (zig cc, for WASI)
# make run    run it with wasmtime, allowed to read this folder (--dir=.)
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove wordfreq.wasm
#
# Zig's compiler brings a C library for WebAssembly (WASI), so any C
# program that only needs files and the terminal compiles as it is.

wordfreq.wasm: wordfreq.c
	zig cc --target=wasm32-wasi -O2 wordfreq.c -o wordfreq.wasm

run: wordfreq.wasm
	wasmtime run --dir=. wordfreq.wasm text.txt

check: wordfreq.wasm
	wasmtime run --dir=. wordfreq.wasm text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -f wordfreq.wasm

.PHONY: run check clean
