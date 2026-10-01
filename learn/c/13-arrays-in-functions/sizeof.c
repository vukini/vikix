/* sizeof.c: the same sizeof, inside a function that was passed the
 * array. The [4] in the parameter is decoration: it's a pointer. */
#include <stdio.h>

static void show(int v[4])
{
    printf("inside show: sizeof v = %zu\n", sizeof v);
}

int main(void)
{
    int marks[4] = {7, 9, 4, 8};
    printf("in main: sizeof marks = %zu\n", sizeof marks);
    show(marks);
    return 0;
}
