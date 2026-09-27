# WebAssembly

A small, safe instruction format that runs at near-native speed in every
browser and, with a runtime like wasmtime, anywhere else. You rarely
write it by hand: C, Rust, Zig and others compile to it.

## On this machine

<!-- tools -->

- Compile C to WebAssembly: `zig cc --target=wasm32-wasi -O2 x.c -o x.wasm`; Zig itself: `zig build-exe -target wasm32-wasi x.zig`
- Rust can target WebAssembly too (`wasm32-wasip1`), but Void packages no standard library for it; with rustup it's `rustup target add wasm32-wasip1`
- Examples: `~/dev/wasm/examples/` (`make run` in each)

## Where to start

1. `examples/hello`: the text format, read line by line with MDN's guide beside it.
2. `examples/wordfreq`: the C example, compiled to WebAssembly unchanged.
3. `examples/sandbox`: what a WebAssembly program is and isn't allowed to touch.
4. WASI's site, for what a program outside the browser can ask for.

## Online

- WebAssembly: https://webassembly.org/ (the spec: https://webassembly.github.io/spec/)
- wasmtime: https://wasmtime.dev/ (source: https://github.com/bytecodealliance/wasmtime)
- WASI: https://wasi.dev/
- wabt, the text-format tools: https://github.com/WebAssembly/wabt

## Free guides

- MDN, WebAssembly — https://developer.mozilla.org/en-US/docs/WebAssembly
- MDN, Understanding WebAssembly text format — https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/Understanding_the_text_format
