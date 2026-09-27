# make        build with dune
# make run    build, then run it on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what dune built
#
# The Makefile only calls OCaml's own tool: `dune exec ./wordfreq.exe -- text.txt` does the same.

build:
	dune build ./wordfreq.exe

run:
	dune exec --no-print-directory ./wordfreq.exe -- text.txt

check: build
	dune exec --no-print-directory ./wordfreq.exe -- text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	dune clean

.PHONY: build run check clean
