# calc (OCaml)

What OCaml is known for: types that describe your data exactly, and
pattern matching the compiler checks for you. A calculator for
expressions: numbers, +, *, / and minus, with division by zero as a
result rather than a crash.

    make run

Try: add `| Sub of expr * expr` to the type and run `make`: the compiler
lists each match that doesn't handle it yet; then handle it.
Docs: https://ocaml.org/docs, "Data Types and Pattern Matching".
