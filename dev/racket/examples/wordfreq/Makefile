# make        compile wordfreq.rkt with raco make (into compiled/)
# make run    run it on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what raco made

build:
	raco make wordfreq.rkt

run: build
	racket wordfreq.rkt text.txt

check: build
	racket wordfreq.rkt text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -rf compiled

.PHONY: build run check clean
