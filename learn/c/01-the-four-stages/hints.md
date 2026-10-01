`cc -E exercise.c | tail -n 6` shows the program after the preprocessor. Find the line with `SQUARE(1 + 2)` in it: what did it become?
---
The preprocessor pastes text; it knows nothing about arithmetic. `SQUARE(1 + 2)` becomes `1 + 2 * 1 + 2`, and `*` binds tighter than `+`.
---
Put brackets around each `x` in the macro's body, so the argument stays one thing: `(x) * (x)`. That fixes the first two.
---
`100 / SQUARE(5)` needs one more pair, around the whole body: `((x) * (x))`. Then the macro is one thing too, wherever it lands. Delete the `// NOT DONE` line when all three are right.
