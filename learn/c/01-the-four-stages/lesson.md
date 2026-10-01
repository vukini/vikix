# 01 · The four stages

`cc example.c` looks like one step. It's four, and each one can be stopped and looked at. Knowing where you are in the four is most of reading a C error message.

`example.c` is the program here. Every output below came from running it.

## 1. The preprocessor: `cc -E`

The preprocessor works on text. `#include <stdio.h>` is replaced by the whole of stdio.h (several hundred lines), and every macro is replaced by its body. No C is understood yet.

```sh
cc -E example.c | tail -n 6
```

<!-- output: cc -E example.c | tail -n 6 -->
```text
int main(void)
{
    printf("%s\n", "Hello from the preprocessor");
    printf("TWICE(1 + 2) = %d\n", ((1 + 2) + (1 + 2)));
    return 0;
}
```

`GREETING` has become its string, and `TWICE(1 + 2)` its body, with the argument pasted in, brackets and all.

## 2. The compiler: `cc -S`

The compiler turns that C into assembly for this machine. Here are the calls it makes:

```sh
cc -S -o - example.c | grep call
```

<!-- output: cc -S -o - example.c | grep call -->
```text
	call	puts@PLT
	call	printf@PLT
```

Two `printf`s went in, and one came out as `puts`: a `printf("%s\n", s)` does what `puts(s)` does, so gcc made the swap, even at `-O0`. The compiler is allowed to, as long as the program behaves the same.

## 3. The assembler: `cc -c`

The assembler turns the assembly into an object file of machine code, `example.o`. `nm` lists its names:

```sh
cc -c example.c && nm example.o
```

<!-- output: cc -c example.c && nm example.o -->
```text
0000000000000000 T main
                 U printf
                 U puts
```

`T`: `main` is here, in the text (the code). `U`: `printf` and `puts` are *undefined*, used but not here. The object file is a program with holes in it.

## 4. The linker

The linker fills the holes from the C library, and makes a program you can run:

```sh
cc example.o -o example && ./example
```

<!-- output: cc example.o -o example && ./example -->
```text
Hello from the preprocessor
TWICE(1 + 2) = 6
```

An "undefined reference" error comes from this stage: everything compiled, and a name is still a hole.

## Your turn

`exercise.c` has a macro, `SQUARE`, that gives wrong answers. Stage 1 shows why: run `cc -E exercise.c | tail -n 6` and read what the preprocessor made of it. Fix the macro, not the `printf` lines. `vikix learn c hint` gives a hint at a time.
