# make        build ./hello
# make run    build, then run it
# make clean  remove what make built

CC     ?= cc
CFLAGS ?= -Wall -Wextra -O2 -g

hello: hello.c
	$(CC) $(CFLAGS) -o $@ $<

run: hello
	./hello

clean:
	rm -f hello

.PHONY: run clean
