# macros (Common Lisp)

What Lisp is known for: code is data, so programs can write programs.
Two macros, `while` and `with-timing`, add new control structures to the
language; the program prints what each one expands into, then uses them.

    make run

Try: in the REPL, `(macroexpand-1 '(while t (print 1)))`; write an
`unless-zero` macro; see why `with-timing` uses `gensym` by naming a
variable `start` inside its body.
Docs: the HyperSpec, `defmacro`, `macroexpand-1`; Practical Common Lisp,
chapters 7 and 8 (see ~/dev/lisp/README.md).
