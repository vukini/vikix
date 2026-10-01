/* example.c: an array, in the function that has it and in one it's
 * passed to. Passed to a function, an array becomes a pointer to its
 * first element, and its length stays behind. */
#include <stddef.h>
#include <stdio.h>

/* average: the mean of v[0..n-1]. The length comes as its own argument:
 * v is a pointer here, and nothing in it says how many there are. */
static double average(const int *v, size_t n)
{
    long sum = 0;
    for (size_t i = 0; i < n; i++)
        sum += v[i];
    return n > 0 ? (double)sum / n : 0;
}

int main(void)
{
    int marks[] = {7, 9, 4, 8};
    size_t n = sizeof marks / sizeof marks[0];   /* works here: marks is the array */
    printf("sizeof marks = %zu, so %zu marks\n", sizeof marks, n);
    printf("average = %.2f\n", average(marks, n));
    return 0;
}
