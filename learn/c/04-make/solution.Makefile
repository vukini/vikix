# solution.Makefile: one way to finish the lesson's Makefile (Vikix's tests
# check it passes; it isn't copied to ~/learn). The Makefile: build wordcount from main.c and words.c, compiling only what
# changed. See example.mk for the shape of a rule.
#
# What it needs:
#   - make (with no name) builds wordcount, from main.o and words.o
#   - main.o is made from main.c, words.o from words.c; and both include
#     words.h, so a change to words.h makes both again
#   - make clean removes wordcount and the .o files
# Use CFLAGS = -std=c17 -Wall -Wextra -pedantic -g when compiling.
# Lines of commands start with a tab, not spaces.
#
# Then delete the NOT DONE line to go on.

CFLAGS = -std=c17 -Wall -Wextra -pedantic -g

wordcount: main.o words.o
	cc -o wordcount main.o words.o

main.o: main.c words.h
	cc $(CFLAGS) -c main.c

words.o: words.c words.h
	cc $(CFLAGS) -c words.c

clean:
	rm -f wordcount main.o words.o
