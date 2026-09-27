# make        assemble hello.wat into hello.wasm (wat2wasm, from wabt)
# make run    run it with wasmtime
# make clean  remove hello.wasm

hello.wasm: hello.wat
	wat2wasm hello.wat -o hello.wasm

run: hello.wasm
	wasmtime run hello.wasm

clean:
	rm -f hello.wasm

.PHONY: run clean
