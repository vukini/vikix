# make        build ./hello with fpc, the Free Pascal compiler
# make run    build, then run it
# make clean  remove what make built

hello: hello.pas
	fpc -v0 -l- hello.pas

run: hello
	./hello

clean:
	rm -f hello hello.o

.PHONY: run clean
