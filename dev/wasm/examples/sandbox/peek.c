/* peek.c — print the first line of a file, if it may.
 *
 * Compiled to WebAssembly, this program can only open files in the
 * folders wasmtime hands it with --dir. Anything else fails as if the
 * file weren't there: the host decides, not the program. */
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: peek FILE\n");
        return 2;
    }
    FILE *f = fopen(argv[1], "r");
    if (!f) {
        printf("  %s: can't open it (%s)\n", argv[1], strerror(errno));
        return 1;
    }
    char line[200];
    if (fgets(line, sizeof line, f))
        printf("  %s: %s", argv[1], line);
    fclose(f);
    return 0;
}
