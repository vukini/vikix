# hello (Scheme)

The smallest Scheme program, for Chez Scheme. `make` compiles it to
machine code (`hello.so`), and `make run` runs that.

    make run        # or: scheme --script hello.ss

Try: `scheme` for a prompt: `(+ 1 2)`, `(map (lambda (x) (* x x)) '(1 2 3))`;
the same file runs in Guile with `guile hello.ss` if you drop the import line.
Docs: The Scheme Programming Language (see ~/dev/scheme/README.md).
