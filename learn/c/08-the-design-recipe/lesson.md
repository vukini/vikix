# 08 · The design recipe

Most bugs in a function come from writing its body before knowing what it's for. The design recipe is six steps, in order, and each one is checked before the next, so you're never debugging a whole function at once.

1. **Data definition:** what the values mean.
2. **Signature and purpose:** what goes in, what comes out, in one sentence.
3. **Examples:** written as `assert`s, before the body.
4. **Template:** the shape of the body, from the data.
5. **Body:** the template, filled in, until the examples pass.
6. **Run it under the sanitizers:** the examples pass, and nothing undefined happened on the way.

`example.c` goes through all six for `clamp`, which moves a number into a range. Every output below came from running it.

```sh
cc -std=c17 -Wall -Wextra -pedantic -g -o example example.c && ./example
```

<!-- output: ./example -->
```text
clamp(250, 0, 100) = 100
all examples pass
```

The examples came first, so they say what `clamp` is *for*: the edges, 0 and 100, count as inside. A body written first would have decided that by accident.

## Step 6 is not optional

Examples that pass can still hide undefined behaviour: an `int` that overflowed, a read past the end of an array. The program may print the right answer today and a wrong one at `-O2`. `-fsanitize=address,undefined` checks while it runs, and stops at the first one. The checks in this course run every program under them.

## Your turn

`exercise.c` is `digits(n)`, how many decimal digits `n` has. The check goes through the steps and stops at the first that isn't done. Write the purpose and the examples **before** the body; one of the examples, `INT_MIN`, is there to make step 6 count.
