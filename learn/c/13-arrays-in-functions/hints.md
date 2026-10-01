gcc says it: inside sum, `sizeof v` is the size of a pointer, 8 bytes, not of the array: `[10]` in a parameter is decoration, and the array became a pointer on the way in.
---
The function can't find the length out, so it has to be told: `long sum(const int *v, size_t n)`, in the declaration and the definition, and loop while `i < n`.
---
Where the array really is, in main, sizeof works: `sum(marks, sizeof marks / sizeof marks[0])`.
