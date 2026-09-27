# Common Lisp

The programmable programming language: code is data, macros extend the
language, and you build programs live, in a running image, changing them
while they run. Vikix's own window manager, StumpWM, is Common Lisp.

## On this machine

<!-- tools -->

- Quicklisp, the library manager, is in `~/quicklisp` and loads with SBCL: `(ql:quickload "cl-ppcre")`
- Offline docs: the HyperSpec in `~/dev/lisp/docs/HyperSpec/`; Zeal's Common Lisp docset
- Live in your desktop: `vikix eval '(+ 1 2)'` runs Lisp inside the running StumpWM; SLIME in Emacs connects to it on port 4004
- Examples: `~/dev/lisp/examples/` (`make run` in each)

## Where to start

1. A Gentle Introduction to Symbolic Computation, the kindest first book, with `sbcl` open.
2. `examples/wordfreq` in SLIME (`M-x slime`): load it, then call its functions one at a time.
3. Practical Common Lisp, for real programs, and `examples/macros` alongside chapters 7 and 8.
4. The Common Lisp Cookbook when you want to know how something is done.

## Online

- Common Lisp: https://common-lisp.net/
- SBCL: https://www.sbcl.org/ (source: https://github.com/sbcl/sbcl)
- Clozure CL: https://ccl.clozure.com/ (source: https://github.com/Clozure/ccl)
- Libraries: https://www.quicklisp.org/
- The HyperSpec, the standard: https://www.lispworks.com/documentation/HyperSpec/Front/

## Free books

- Common Lisp: A Gentle Introduction to Symbolic Computation — https://www.cs.cmu.edu/~dst/LispBook/
- Practical Common Lisp — https://gigamonkeys.com/book/
- The Common Lisp Cookbook — https://lispcookbook.github.io/cl-cookbook/
- On Lisp, on macros — https://www.paulgraham.com/onlisp.html
