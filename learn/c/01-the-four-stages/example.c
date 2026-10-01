/* example.c: one small program, to watch cc's four stages at work.
 *
 * Every line here survives to the end, but each stage turns it into
 * something else: the preprocessor pastes in stdio.h and the macros, the
 * compiler turns C into assembly, the assembler into machine code, and
 * the linker joins that to the C library. */
#include <stdio.h>

#define GREETING "Hello from the preprocessor"
#define TWICE(x) ((x) + (x))   /* the brackets matter: see the exercise */

int main(void)
{
    printf("%s\n", GREETING);                 /* a string and a newline */
    printf("TWICE(1 + 2) = %d\n", TWICE(1 + 2));
    return 0;
}
