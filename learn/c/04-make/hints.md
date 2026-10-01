As shipped, `wordcount:` lists nothing after its colon, so make never sees a reason to build it again, and it compiles both files every time it does. A rule's prerequisites, after the colon, are what it's made from.
---
Split it like example.mk: `wordcount: main.o words.o` links the two objects (`cc -o wordcount main.o words.o`), and a rule for each object compiles one file: `main.o: main.c` with `cc $(CFLAGS) -c main.c`.
---
Both .c files `#include "words.h"`. make doesn't read the C, so it can't know: list words.h among each object's prerequisites, `main.o: main.c words.h`.
---
`clean:` with `rm -f wordcount main.o words.o`. The command lines start with a tab: an editor that turns tabs into spaces makes make say "missing separator".
