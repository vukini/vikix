# make        build with dune
# make run    build, then run it
# make clean  remove what dune built
#
# The Makefile only calls OCaml's own tool: `dune exec ./hello.exe` does the same.

build:
	dune build ./hello.exe

run:
	dune exec --no-print-directory ./hello.exe


clean:
	dune clean

.PHONY: build run clean
