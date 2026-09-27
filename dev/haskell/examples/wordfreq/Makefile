# make        build with cabal
# make run    build, then run it on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what cabal built
#
# The Makefile only calls Haskell's own tool: `cabal run wordfreq -- text.txt` does the same.

build:
	cabal build -v0

run:
	cabal run -v0 wordfreq -- text.txt

check: build
	cabal run -v0 wordfreq -- text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -rf dist-newstyle

.PHONY: build run check clean
