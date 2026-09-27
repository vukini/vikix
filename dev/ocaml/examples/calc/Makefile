# make        build with dune
# make run    build, then run it
# make clean  remove what dune built
#
# The Makefile only calls OCaml's own tool: `dune exec ./calc.exe` does the same.

build:
	dune build ./calc.exe

run:
	dune exec --no-print-directory ./calc.exe

clean:
	dune clean

.PHONY: build run clean
