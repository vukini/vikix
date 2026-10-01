The first error is the compiler's: `implicit declaration of function 'mean'`. A C file must say what a function is before it calls it. Copy the line `double mean(const double *v, int n)` from stats.c, and end it with a `;`: that's a declaration.
---
Now it compiles, and the build fails later, at the link: `undefined reference to 'biggest'`. The compiler took the declaration at its word; the linker looked for the function itself, in exercise.o and stats.o, and found none called that.
---
`nm stats.o` (after `cc -c stats.c`) lists what stats.c defines, with `T` before each: there's no `biggest`. What is it called there?
---
Declare `largest` as stats.c defines it, and call `largest(marks, 4)`.
