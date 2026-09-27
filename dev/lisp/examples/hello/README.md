# hello (Common Lisp)

The smallest Common Lisp program. `make` compiles it to a `.fasl`
(compiled Lisp), and `make run` runs that with SBCL.

    make run        # or: sbcl --script hello.lisp

Try: `sbcl` (rlwrap'd in Vikix) for a prompt: `(+ 1 2)`, `(load "hello.lisp")`;
in Emacs, `M-x slime` gives the full Lisp environment; `ccl` is a second
implementation to try the same file with.
Docs: `~/dev/lisp/docs/HyperSpec/`; Zeal's Common Lisp docset.
