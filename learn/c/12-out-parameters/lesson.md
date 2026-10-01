# 12 · Out-parameters

C passes every argument as a copy. A function that changes its parameter changes its own copy, and the caller sees nothing. To change the caller's variable, pass its address, `&x`; the function gets a copy of the address, and `*p` reaches the variable itself. The same way, a function can give back more than one answer: the result, and the others through pointers, as `divide` does with the remainder:

<!-- output: ./example -->
```text
after swap_copies: x = 1, y = 2
after swap_ints:   x = 2, y = 1
17 / 5 = 3, remainder 2
```

`swap_copies` swapped its own copies, then threw them away. `swap_ints` was given `&x` and `&y`, and swapped what they point to.

In a function that takes `int *a`:

- `*a = 5` changes the caller's int: that's the point.
- `a = b` changes only which int this function's `a` points to: the caller never notices.

## Your turn

`exercise.c` has `swap`, and `min_max`, which gives two answers through pointers. Both have the second kind of mistake somewhere, and `min_max` has one more, about where it starts. gcc has already noticed one of them.
