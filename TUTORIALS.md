# Tutorials: `vikix learn`

The plan for courses inside Vikix, starting with C. Drafted 2026-09-28. Status: **a proposal, with decisions still to make** (at the end). `TODO.md` points here.

What's there now is very basic: the README's Languages section, with a "try it" column, and the examples in `~/dev/<language>/examples/`. C needs much better tutorials, and they should live inside Vikix.

## C

### The idea in one line

`vikix learn c` opens a hands-on C course in the terminal. It runs against the tools the `c` feature and the base already install. Every lesson is a real program you edit, save and watch get checked.

It's the same shape as rustlings and ziglings, but it teaches the toolchain and the machine as well as the language.

### Why Vikix is a good home for it

The tools are already there. Checked in Void on 2026-09-28:

- **In the base:** gcc and make (`base-devel`), gdb, valgrind (`dev.list`); bat (`cli.list`)
- **With the feature `c`:** clang, tcc, rr, cmake, meson, ninja (`lang-c.list`)
- **With `devtools`**, which `c` brings: `entr` (for watch mode), `hyperfine` (`lang-tools.list`)
- **Not on a list yet:** `strace` (Void has 7.1): add it to `lang-c.list`, for tracks 10 and 11

So `vikix learn c` only needs `vikix add c` first, and can offer to run it.

The Bottom-Up C work supplies the evidence. It has 14 measured findings, for example:

- `-lm` is optional at `-O2`
- archive link order matters
- `-Wall -Wextra` miss `signed char s = 200`, and `-pedantic` catches it
- a megabyte of bss costs nothing in the file

These are exactly the "surprising when you run it" lessons that basic tutorials never reach.

The AI agent is already there. Super+a and the skills folder give a natural slot for a tutor.

### How it works

#### Commands

```
vikix learn c            # resume: show the current lesson and start watching
vikix learn c list       # all lessons, with ticks
vikix learn c go 07      # jump to a lesson
vikix learn c hint       # next hint for this lesson
vikix learn c reset 07   # restore the lesson's files
vikix learn c check      # run the checks once, no watching
```

#### Files and ownership (the same rule as the rest of Vikix)

- The course source lives in the Vikix repo at `learn/c/`.
- On first run it's copied to `~/learn/c/`. These are the learner's files: copied once, never overwritten.
- `reset` restores one lesson from the repo copy, after a `vikix snapshot`, so a reset can be undone.
- Progress is kept in `~/.local/state/vikix/learn/c`.

#### One lesson = one folder

```
learn/c/07-pointers-to-locals/
  lesson.md     # short: bullets, one idea per paragraph
  example.c     # complete, commented, runs as shipped
  exercise.c    # the learner's part; marked  // NOT DONE
  check.sh      # what "done" means (see below)
  hints.md      # graded hints, one per `hint`
```

#### What happens on save

`entr` sees the save, and then:

1. The file is compiled with `-std=c17 -Wall -Wextra -pedantic -g -fsanitize=address,undefined`.
2. The lesson's checks run.
3. The terminal shows the first thing that failed, and only that thing.
4. When all the checks pass and `// NOT DONE` is gone, the runner moves on to the next lesson.

#### The design recipe is built into the checks

For any lesson that writes a function, the six steps are checked separately, in order:

1. Data definition compiles
2. Signature and purpose statement are present
3. The examples (given as `assert`s) compile against the signature
4. The template compiles
5. The body passes the examples
6. Everything runs clean under the sanitizers

You're never debugging a whole function at once. The runner tells you which step you're on.

#### House rules carried over from the sites

- **Evidence rule.** Every output quoted in a `lesson.md` is produced by running it. `make check` in `learn/c/` regenerates the outputs and diffs them, like Bottom-Up C's `check-listings.py`. A new gcc that changes behaviour fails the check, not the reader.
- **Copy-pasteable transcripts.** What's typed goes at the left. Output goes behind `#`.
- **Code on its own lines**, not wrapped inside prose.

### Curriculum: twelve tracks, well past the basics

Each track ends in a small project. Lesson counts are estimates.

| # | Track | What it covers | Tools met | Project |
|---|---|---|---|---|
| 1 | The toolchain | `cc` in four stages (`-E -S -c`, link); what each flag really catches; `make` from the stage chain | gcc, clang, tcc, make | A Makefile that rebuilds only what changed |
| 2 | Values and bits | integer types and ranges, overflow, signed vs unsigned, undefined behaviour you can watch happen | UBSan, `-pedantic` | Bit-field flags and a `printbits` tool |
| 3 | Control and functions | loops, early in the course (the fix Bottom-Up C needed); the design recipe with `assert` | gdb: break, step, print | A number-formatting library with tests |
| 4 | Pointers and arrays | addresses, `&` and `*`, arrays decaying, pointer arithmetic | gdb `x/`, ASan | `my_memcpy`, `my_strlen` and friends |
| 5 | Where everything lives | text, data, bss, heap, stack, measured rather than drawn; ASLR | `size`, `nm`, `/proc/self/maps` | The region-sorter program |
| 6 | The heap | `malloc`/`free`, ownership, leaks, use-after-free, double free | valgrind, ASan, rr | A growable array (`vec`) |
| 7 | Strings and text | `string.h` traps, `strncpy`, buffer sizes, `ctype.h` | `-Wstringop-*`, ASan | A word counter (links to Reading JavaScript) |
| 8 | Structs and data | data definitions, linked lists, hash tables, `typedef` | gdb pretty-print | A hash map with tests |
| 9 | Many files | headers, include guards, `static`, the linker, static libraries, link order | `nm`, `ar`, `ld` errors | Split the hash map into a library |
| 10 | Streams and files | `FILE*`, buffering (pipe vs terminal), `errno`, reading lines safely | `strace` | `mytail` / `mygrep` |
| 11 | C on Linux | syscalls, `fork`/`exec`, pipes, signals, file descriptors | `strace`, gdb | A tiny shell |
| 12 | Debugging and speed | reverse debugging, core dumps, `-O0` vs `-O2`, measuring | rr, gdb, hyperfine | Make a slow program fast, and prove it |

#### Capstones

- **A Forth in C.** Links to Living in Forth.
- **A tiny Lisp in C.** Links to the Lisp and PicoLisp threads.
- **Rewrite a Vikix tool in C,** for example `vikix-battery`. The course ends by improving the desktop you're sitting in.

### The tutor (optional, uses the existing AI setup)

- Add a `vikix-tutor` skill next to the Vikix skill in `config/claude/skills/`.
- Super+a inside `~/learn/c/NN-*/` opens Claude Code. The skill reads the lesson, your `exercise.c` and the last check output.
- Default behaviour: explain the failing step, then give the next hint. A full worked answer only when you ask for it.
- `vikix learn c` works completely without it.

### Relationship to Bottom-Up C

- **Bottom-Up C (book and site)** is the reading layer: why things are the way they are.
- **`vikix learn c`** is the doing layer: the same ideas as programs to fix and run.
- Lessons reuse the measured findings and the site's `code/` programs where they fit, and link to the matching step on the site.
- Nothing moves out of the book or site. They stay independent.

## The runner is language-neutral

`bin/vikix-learn` knows nothing about C. Each course folder carries its own compile and check commands. The same runner can later host `vikix learn lisp`, `forth`, `haskell` and `sql`, matching the language features.

## Build order

| Phase | Deliverable | How it's tested |
|---|---|---|
| 0 | `bin/vikix-learn` runner, plus three lessons (one each from tracks 1, 3 and 4) | A `tests/learn.sh`, then worked through in the test VM |
| 1 | Tracks 1–4 complete | `make check` green; worked through in the VM |
| 2 | Tracks 5–8, plus the tutor skill | Same |
| 3 | Tracks 9–12, plus the capstones | Same, and on real hardware |

Phase 0 is small enough to judge the feel of the thing before writing a hundred lessons.

## Decisions to make

1. **Lesson style.** For code lessons, working code with commentary is preferred over stubs to fill in. Proposed:
   - every lesson opens with a complete, commented `example.c`
   - then comes a small exercise that varies it

   Or skip the exercises and just run the examples?
2. **Who is it for?** The maker first, or newcomers to Vikix too? This decides where track 1 starts.
3. **Terminal only,** or also a key in Emacs/Neovim that runs the check?
4. **Is `~/learn/c/` the right place?** Should it go in `yours.list`, so `vikix undo` covers the exercise work?
5. **Phase 0 go-ahead:** the runner plus three lessons.
