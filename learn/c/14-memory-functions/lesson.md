# 14 · Memory functions: a project

`memcpy`, `memset` and `strcmp` are some of the most used functions in C, and each is a short loop over bytes. Writing them again is the end of this track: pointers walked through memory, `void *` turned into bytes, and the edges where it goes wrong.

<!-- output: ./example -->
```text
memcpy: abcdefg
memset: ---defg
strcmp("apple", "apricot") < 0
strcmp("ab", "ab") == 0
strcmp("abc", "ab") > 0
strcmp("\xe9", "e") > 0
```

- `memcpy` and `memset` count bytes; they don't stop at a `'\0'`. They take `void *`, a pointer to anything, which can't be read until you say what it points to: `unsigned char *` means bytes.
- `strcmp` stops at the end of the shorter string, and answers with a sign, not a particular number.
- It compares bytes as `unsigned char`. A plain `char` is signed here, so a byte like 0xE9 (é in Latin-1) would be -23 and sort before `e`; as unsigned it's 233, and sorts after.

## The project

`exercise.c` has `my_memcpy` and `my_memset` still to write, and a `my_strcmp` with both of the classic mistakes. The check compares all three with the library's, on buffers of exactly the right size, with bytes above 127.
