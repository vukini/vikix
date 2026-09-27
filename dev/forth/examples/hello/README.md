# hello (Forth)

The smallest Forth program, run by gforth. Forth reads the file a word at
a time and does each one: `.(` prints, `cr` starts a new line, `bye` leaves.

    make run        # or: gforth hello.fs

Try: `gforth` for a prompt: `2 3 + .` (numbers go on the stack, `+` adds
the top two, `.` prints one); `: double 2 * ;` then `21 double .`.
Docs: `info gforth` (or in Emacs: C-h i, Gforth); Starting Forth (see ~/dev/forth/README.md).
