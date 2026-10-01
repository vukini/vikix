# Makefile: build wordcount from main.c and words.c, compiling only what
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
# NOT DONE

CFLAGS = -std=c17 -Wall -Wextra -pedantic -g

wordcount:
	cc $(CFLAGS) -o wordcount main.c words.c
