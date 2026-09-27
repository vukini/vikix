# make        build ./hello with go build
# make run    build, then run it
# make clean  remove what make built
#
# The Makefile only calls Go's own tool: `go run .` does the same.

hello: main.go go.mod
	go build -o hello .

run: hello
	./hello

clean:
	rm -f hello

.PHONY: run clean
