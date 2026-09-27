# make        compile peek.c to peek.wasm (zig cc, for WASI)
# make run    run it three ways: with no folder, with this one, and at a file outside it
# make clean  remove peek.wasm

peek.wasm: peek.c
	zig cc --target=wasm32-wasi -O2 peek.c -o peek.wasm

run: peek.wasm
	@echo "given no folder at all:"
	-@wasmtime run peek.wasm secret.txt
	@echo "given this folder (--dir=.):"
	@wasmtime run --dir=. peek.wasm secret.txt
	@echo "given this folder, but asking for a file outside it:"
	-@wasmtime run --dir=. peek.wasm /etc/hostname

clean:
	rm -f peek.wasm

.PHONY: run clean
