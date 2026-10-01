# 04 · Make: a project

A program in several files shouldn't be compiled whole each time one changes: compile each `.c` file to its own `.o`, and link them. `make` does that, from a Makefile that says what's made from what, and runs only the steps whose inputs are newer than their outputs.

## A rule

`example.mk` builds `hello` from `hello.c` in two steps. A rule is a target, a colon, what it's made from (its prerequisites), then the commands, each on a line starting with a tab:

<!-- output: sed -n '/^hello:/,/^$/p;/^hello.o:/,/^$/p' example.mk -->
```text
hello: hello.o
	cc -o hello hello.o

hello.o: hello.c
	cc $(CFLAGS) -c hello.c
```

`make` builds the first target, and first whatever it needs:

<!-- output: make -f example.mk -->
```text
cc -std=c17 -Wall -Wextra -pedantic -g -c hello.c
cc -o hello hello.o
```

Nothing has changed since, so the second time there's nothing to do:

<!-- output: make -f example.mk && make -f example.mk -->
```text
make: 'hello' is up to date.
make: 'hello' is up to date.
```

`make -n` says what it would run, without running it. After a change to `hello.c` (here, `touch` makes it newer), both steps are due again:

<!-- output: make -f example.mk >/dev/null && sleep 1 && touch hello.c && make -n -f example.mk -->
```text
cc -std=c17 -Wall -Wextra -pedantic -g -c hello.c
cc -o hello hello.o
```

## The project

`wordcount` is `main.c` and `words.c`, and both include `words.h`. As it comes, the Makefile compiles everything in one go, every time. Write it so that:

- `make` builds `wordcount` from `main.o` and `words.o`, each compiled on its own with `$(CFLAGS)`
- a second `make`, with nothing changed, does nothing
- a change to `words.c` compiles only `words.c`, then links again
- a change to `words.h` compiles both, since both include it: make doesn't read your C, so the Makefile has to say so
- `make clean` removes `wordcount` and the `.o` files

The check builds in a copy of the folder and changes each file in turn, with `make -n` to see what would run.
