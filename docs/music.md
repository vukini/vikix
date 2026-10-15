# A first musical pattern

Music Phase 0 is a small Lisp sketchpad. SuperCollider makes the sound,
through PipeWire's JACK support; the pattern clock runs in its own SBCL
process, apart from StumpWM.

## First sound

Run `vikix add music`. This installs SuperCollider (Void's package includes
Qt), PipeWire's JACK library and rtkit, enables rtkit, and uses the existing
Quicklisp installation to prepare one synthesized sound with cl-collider.
No samples are downloaded. Your first pattern is copied once into
`~/music/first-song/patterns.lisp`; setup never replaces it.

```sh
vikix music doctor
vikix music tone
vikix music play
```

Start with the speaker volume low. The tone lasts about a third of a
second. Play repeats the first pattern until Ctrl+C. Each invocation owns
its sound engine; it does not connect to an engine you already started.
`doctor` checks installed commands and the prepared synth, not audible
output, latency or realtime priority. If the engine cannot start, check
that PipeWire is running in your login and inspect the error in the terminal.

## Edit while it plays

A file can hold a tempo and up to 32 named patterns. One chosen pattern
plays at a time, each list filling a four-beat bar with equally spaced
steps:

```lisp
(tempo 120)
(defpattern bass '(c3 - e3 - g3 - e3 -))
(defpattern pulse '(x - x -))
```

`-` is a rest; `x` is a 220 Hz hit using the same simple sine sound. Notes
run from C0 to B8; use `cs4` for C sharp and `eb4` for E flat. Tempo is
60 to 200 beats per minute, with 1 to 128 steps in a pattern.

```sh
vikix music check ~/music/first-song/patterns.lisp
vikix music play ~/music/first-song/patterns.lisp --pattern bass
vikix music play ~/music/first-song/patterns.lisp --bars 4
```

The file is read as data, never evaluated. Save a valid edit and it takes
effect at the next bar that has not already been sent to the engine
(about 100 milliseconds ahead). An invalid edit, an incomplete save or a
missing file keeps the last good pattern playing and prints the reason.
At startup, an invalid file is refused. A delayed clock skips missed time
instead of firing a backlog of notes.

Before editing, run `vikix snapshot "before music edit"`. Only
`~/music/SONG/patterns.lisp` files join the existing snapshot history;
recordings, rendered audio and nested folders do not. `vikix changes`
shows the edit; `vikix undo` restores the previous snapshot and the player
reads the restored pattern at the next bar. Undo covers the other files in
that snapshot too: review its list before accepting it. Patterns outside
this folder can be played, but do not gain snapshot coverage automatically.

## Lisp from a terminal or Emacs

`vikix music repl` opens a separate local Lisp REPL. In Emacs, use
`C-u M-x run-lisp` and enter `vikix music repl` as the command.

```lisp
(tone 440)
(play "/home/YOU/music/first-song/patterns.lisp")
(stop)
(quit)
```

Tone is finite; Stop ends the pattern worker and clears queued sound.
Quit or Ctrl+C closes the owned engine as well. This REPL evaluates your
Lisp and has your user's permissions; pattern files do not. There is no
network REPL. The engine listens only on loopback TCP with a fresh session
password, no UDP listener, no microphone inputs and no service advertisement.

## What comes later

This first slice has one sound and a text interface. The grid, capture,
DAW integration, MIDI, swing, chords, variations and Cuis face are later
phases. There is no new desktop key or menu entry yet.

`vikix remove music` removes the feature's dependencies when nothing else
needs them and the prepared synth, keeping `~/music`. `vikix music setup`
can rebuild the synth without replacing your patterns.
