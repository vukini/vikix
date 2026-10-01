# 03 · The linker

Compiling turns each `.c` file into an object file on its own, with holes in it: every function it uses from somewhere else is a name, still to be found. The linker joins the object files and libraries, and fills each hole. When it can't, the error is its own: `undefined reference`.

## What an object file needs: nm

`example.c` prints `sqrt(2.0)`. `nm` lists the names in its object file: `T` for one it defines, `U` for one it needs from elsewhere.

<!-- output: cc -c example.c && nm example.o -->
```text
0000000000000000 T main
                 U printf
```

No `sqrt`: gcc knew the answer, 1.414214, and put the number in instead. `roots.c` takes its number when it runs, so it really calls `sqrt`:

<!-- output: cc -c roots.c && nm roots.o -->
```text
                 U atof
0000000000000000 T main
                 U printf
                 U sqrt
```

`sqrt` is in the maths library, which isn't linked unless you ask for it, with `-lm`:

```sh
cc roots.o -o roots
```

<!-- output: cc roots.o -o roots 2>&1 | grep -o "undefined reference to .sqrt." -->
```text
undefined reference to `sqrt'
```

<!-- output: cc roots.o -o roots -lm && ./roots 9 -->
```text
sqrt(9) = 3
```

So `-lm` is needed when the program calls `sqrt` while it runs, at any `-O`, and not when the compiler can work the answer out.

## Order, for a library of your own

A static library is an archive of object files, `libNAME.a`. The linker reads the command line from left to right, and takes from an archive only what's already missing by then. Named too early, nothing is missing yet:

<!-- output: cc -c area.c usearea.c && ar rcs libarea.a area.o && cc -L. -larea usearea.o -o usearea 2>&1 | grep -o "undefined reference to .area." -->
```text
undefined reference to `area'
```

<!-- output: cc -c area.c usearea.c && ar rcs libarea.a area.o && cc usearea.o -L. -larea -o usearea && ./usearea -->
```text
12
```

The shared maths library forgave the same order (`cc -lm roots.o` links too), but an archive doesn't: put libraries after the files that use them, and both work.

## Your turn

`exercise.c` uses two functions from `stats.c`, and the check builds the two together. First the compiler stops: a function is used before it's declared. Then the linker stops, for a name that isn't there. `nm stats.o` shows what is.
