# comptime (Zig)

What Zig is known for: `comptime`, ordinary Zig code run by the compiler.
A table of squares computed while compiling, and one function that
works for any number type because the type is a compile-time argument.
Tests sit beside the code.

    make run
    make check      # zig build test

Try: make the table 100 long and see the binary stay just as fast; call
`biggest(bool, ...)` and read the compile error; add a test that fails.
Docs: the language reference in `~/dev/zig/docs/`, "comptime".
