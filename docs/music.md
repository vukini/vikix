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
second, at 880 Hz by default. The starter uses higher notes that are easier
to hear on laptop speakers; low sine notes may be faint even when browser
audio sounds normal. Existing songs are never rewritten by an update.
Play repeats the first pattern until Ctrl+C. Each invocation owns
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
(defpattern melody '(a5 - c6 - e6 - c6 -))
(defpattern pulse '(x - x -))
```

`-` is a rest; `x` is a 220 Hz hit using the same simple sine sound. Notes
run from C0 to B8; use `cs4` for C sharp and `eb4` for E flat. Tempo is
60 to 200 beats per minute, with 1 to 128 steps in a pattern.

```sh
vikix music check ~/music/first-song/patterns.lisp
vikix music play ~/music/first-song/patterns.lisp --pattern melody
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
(tone 880)
(play "/home/YOU/music/first-song/patterns.lisp")
(stop)
(quit)
```

Tone is finite; Stop ends the pattern worker and clears queued sound.
Quit or Ctrl+C closes the owned engine as well. This REPL evaluates your
Lisp and has your user's permissions; pattern files do not. There is no
network REPL. The engine listens only on loopback TCP with a fresh session
password, no UDP listener, no microphone inputs and no service advertisement.

## Compare the prototype views

The Phase 1 interface comparison adds two views of one session. In one
terminal, start the session; in another, open either or both views:

```sh
vikix music serve
vikix music web
vikix music cuis
```

`serve` also accepts a song's `patterns.lisp`. For editing it must be in
`~/music/SONG/patterns.lisp`, where snapshots cover it. The browser opens
with your default browser. The Cuis view needs `vikix add cuis`; it runs
in a disposable base image and does not change your saved Cuis image.
Close its Music window to quit that disposable image.

Choose a pattern and press Play. Each step paints the selected note; a
second click on that note makes a rest. The browser offers the full note
range; the Cuis comparison cycles a small high-note palette and shows
sixteen steps per page. Tempo and gain controls work in both. Tempo is
saved to the song; gain is a session setting, capped at 0.1. File edits
arrive at the next bar, and both views refresh from the same file.

The browser's **This pattern in Lisp** strip shows the selected pattern
and tempo as Lisp forms. It follows note edits, tempo changes, pattern
selection and external file edits. This is a readable representation of
the grid; the file keeps its own comments and formatting. An invalid edit
leaves the last good grid and subtitle visible together.

An edit takes a snapshot first and replaces only the changed note or tempo
token, keeping comments and formatting. A stale revision is refused: review
the refreshed grid and try again. Invalid file edits leave the last good
pattern visible and audible, with an error. The prototype editor accepts
whole-number tempos and plain pattern names made of letters, digits and
dashes. More elaborate Lisp spellings can still be played with `play`.

Closing a view leaves the player running. Stop in either view stops sound;
Ctrl+C in the session terminal stops its player, closes the local server
and removes its connection file. Open another view to reconnect. The
server binds only to 127.0.0.1, checks browser origins and requires a fresh
session token from a private connection file. It accepts music operations,
not Lisp or Smalltalk evaluation. Browser audio is never used.

## What comes later

This comparison has one sound. Pads, a playhead, capture, DAW integration,
MIDI, swing, chords, variations and the final choice of interface remain. There is no new desktop key or menu entry yet.

`vikix remove music` removes the feature's dependencies when nothing else
needs them and the prepared synth, keeping `~/music`. `vikix music setup`
can rebuild the synth without replacing your patterns.
