# example.mk: one program from one file, in two steps. Run it with
#   make -f example.mk

CFLAGS = -std=c17 -Wall -Wextra -pedantic -g

# A rule: the target, a colon, what it's made from; then, each on a line
# that starts with a tab, how to make it.
hello: hello.o
	cc -o hello hello.o

hello.o: hello.c
	cc $(CFLAGS) -c hello.c

clean:
	rm -f hello hello.o
