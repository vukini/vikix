# results (Rust)

What Rust is known for: the compiler makes you deal with failure. A
function that can fail returns `Result`, and `?` passes an error up.
This adds up `numbers.txt` and stops, politely, at the line that isn't a
number (`x4`); then it tries a file that doesn't exist.

    make run

Try: fix line 5 of numbers.txt and run again; remove the `?` after
`fs::read_to_string(path)` and read what the compiler says; make it skip
bad lines and report them all instead of stopping at the first.
Docs: the book, chapter 9 (error handling): `~/dev/rust/docs/rust/book/ch09-00-error-handling.html`.
