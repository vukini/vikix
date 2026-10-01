/* usearea.c: uses area(), from area.c or libarea.a. */
#include <stdio.h>
double area(double w, double h);
int main(void) { printf("%g\n", area(3, 4)); return 0; }
