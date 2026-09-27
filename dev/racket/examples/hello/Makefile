# make        compile hello.rkt with raco make (into compiled/)
# make run    run it
# make clean  remove what raco made

build:
	raco make hello.rkt

run: build
	racket hello.rkt


clean:
	rm -rf compiled

.PHONY: build run clean
