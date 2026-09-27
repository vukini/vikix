# make        nothing to build: Forth compiles each word as it reads the file
# make run    run it with gforth on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove

build:
	@echo "nothing to build: gforth compiles wordfreq.fs as it reads it (make run)"

run:
	gforth wordfreq.fs text.txt

check:
	gforth wordfreq.fs text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
