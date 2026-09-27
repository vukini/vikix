# C

The language most of the system is written in: small, close to the
machine, and you manage memory yourself. Worth learning for what it shows
about how computers really work.

## On this machine

<!-- tools -->

- Offline docs: `man 3 printf` (the C library), `man 3p printf` (POSIX), `~/dev/c/docs/`, Zeal's C docset
- Examples: `~/dev/c/examples/` (`make run` in each)

## Where to start

1. `examples/hello`, then change it; `make CC=clang run` builds it with the other compiler.
2. Beej's Guide (below) from the start, typing the examples in.
3. `examples/linkedlist` with `make check`: what valgrind says, and why.
4. Modern C, for how C is written today.

## Online

- Standard: https://www.open-std.org/jtc1/sc22/wg14/ (ISO WG14, the C committee)
- Compilers: https://gcc.gnu.org/ (GCC, the `cc` here; source: https://gcc.gnu.org/git.html) and https://clang.llvm.org/ (source: https://github.com/llvm/llvm-project)
- Reference: https://en.cppreference.com/w/c — the library and the language, by standard version
- The GNU C Reference Manual: https://www.gnu.org/software/gnu-c-manual/

## Free books

- Beej's Guide to C Programming — https://beej.us/guide/bgc/ — friendly, from nothing
- Modern C, by Jens Gustedt — https://gustedt.gitlabpages.inria.fr/modern-c/ — the language as it is now (free PDF)
- Build Your Own Lisp — https://buildyourownlisp.com/ — learn C by writing a small language
