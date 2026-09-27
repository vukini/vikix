# make        build ./list
# make run    run it
# make check  run it under valgrind: any leaked memory is an error
# make clean  remove what make built

CC     ?= cc
CFLAGS ?= -Wall -Wextra -O0 -g     # -O0 -g: exact line numbers in gdb and valgrind

list: list.c
	$(CC) $(CFLAGS) -o $@ $<

run: list
	./list

check: list
	valgrind --quiet --leak-check=full --error-exitcode=1 ./list && echo "no leaks"

clean:
	rm -f list

.PHONY: run check clean
