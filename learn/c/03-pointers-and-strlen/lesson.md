# 03 · Pointers and my_strlen

A pointer is an address. `*p` is what's at that address; `p + 1` is the address of the next element, however many bytes an element takes. A string in C is chars in a row, ended by a `'\0'`, and a pointer walking along it is how most string code works.

`example.c` walks a string with `count_char`, and shows the arithmetic. Every output below came from running it.

```sh
cc -std=c17 -Wall -Wextra -pedantic -g -o example example.c && ./example
```

<!-- output: ./example -->
```text
*first = s, *third = p
third - first = 2
sizeof word = 13, sizeof first = 8
ip + 1 is 4 bytes on from ip, and *(ip + 1) = 20
count_char("supercharged", 'e') = 2
```

- **An array, used as a value, becomes a pointer to its first element.** `char *first = word` needs no `&`. But `sizeof` still sees the array: 13 bytes, the 12 letters and the `'\0'`. The pointer is 8 bytes, whatever it points to.
- **Subtracting two pointers** into the same array gives how many elements apart they are: `third - first` is 2.
- **`ip + 1` moves one `int`**, 4 bytes here, not one byte. Pointer arithmetic counts elements, so `*(ip + 1)` is `numbers[1]`. That's all `a[i]` is: `*(a + i)`.

## Your turn

`exercise.c` is `my_strlen`, your own `strlen`. Walk a pointer to the `'\0'`, as `count_char` does. The check puts each test string in a buffer of exactly its size, so reading one char too far is caught.
