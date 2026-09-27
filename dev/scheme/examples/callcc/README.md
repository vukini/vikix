# callcc (Scheme)

What Scheme is known for: a tiny core with big ideas. `call/cc` jumps
out of a deep search the moment it finds a negative number; a function
that calls itself ten million times runs in constant space, because a
tail call replaces the one it's in.

    make run

Try: make `count-up` add one after the call, `(+ 1 (count-up ...))`, so
the call is no longer last, and count to ten million again; write
`first-negative` without call/cc and compare.
Docs: The Scheme Programming Language, "Continuations" (see ~/dev/scheme/README.md).
