# make        build with cabal
# make run    build, then run it
# make clean  remove what cabal built
#
# The Makefile only calls Haskell's own tool: `cabal run lazy` does the same.

build:
	cabal build -v0

run:
	cabal run -v0 lazy

clean:
	rm -rf dist-newstyle

.PHONY: build run clean
