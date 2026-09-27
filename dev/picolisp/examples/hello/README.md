# hello (PicoLisp)

The smallest PicoLisp program. There is nothing to compile: `make` only
checks that it reads, `make run` runs it with `pil`.

    make run        # or: pil hello.l

Try: `pil +` for a prompt (the + turns on debugging): `(+ 1 2)`,
`(mapcar inc (1 2 3))`; `(load "hello.l")` runs the file, and leaves.
Docs: the reference, https://software-lab.de/doc/ref.html
