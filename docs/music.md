# A first musical pattern

Music is a small Lisp sketchpad. SuperCollider makes the sound,
through PipeWire's JACK support; the pattern clock runs in its own SBCL
process, apart from StumpWM.

## First sound

Run `vikix add music`. This installs SuperCollider (Void's package includes
Qt), PipeWire's JACK library and rtkit, enables rtkit, and uses the existing
Quicklisp installation to compile the original synthesized palette with cl-collider.
No samples are downloaded. If Music was already installed before the palette,
run `vikix music setup` once to compile the new versioned bundle. Your first pattern is copied once into
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
plays at a time, each list filling a four-beat bar, with straight steps by default:

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

## Sounds, pattern gain and swing

Optional fields belong to each pattern, after its note list:

```lisp
(defpattern beat '(x - x x) :sound 'kick :gain 0.7 :swing 0.3)
(defpattern phrase '(c3 - g3 c4) :sound 'bell :gain 0.5)
```

| Sound | Character | What X does |
|---|---|---|
| `sine` (default) | The original pure sine | Plays 220 Hz |
| `kick` | Low sine with a falling pitch | Triggers a kick |
| `snare` | Noise and a low tone | Triggers a snare |
| `closed-hat` | Short metallic tones and noise | Triggers a closed hat |
| `bass` | Fundamental and second harmonic | Plays 220 Hz |
| `bell` | Three inharmonic sine tones | Plays 220 Hz |

Drums accept only `x` and `-`; replace pitched notes before choosing a drum.
Sine, bass and bell accept note pitches as well. All six are original
synthesis in `lib/music/synth.lisp`, distributed under Vikix's MIT license
(`LICENSE`). There are no sampled recordings or third-party patches.

**Pattern gain** is a multiplier from 0 to 1, default 1. **Session gain**
remains 0 to 0.1, default 0.08; the two multiply, so pattern gain 0.5 at
session gain 0.08 produces amplitude 0.04. Session gain is not saved in
the score. These are amplitude bounds per voice, not a speaker-volume or
summed-output limiter. Different timbres can sound louder at the same
amplitude. Existing sine scores retain their original sound and level.

**Swing** ranges from 0 to 0.5, default 0. It delays steps 2, 4, 6 and so
on by that fraction of one straight step, without changing the bar's length.
At 0.5, each pair has a 3:1 timing ratio. Nonzero swing requires an even
step count; rests count as steps. Sound, pattern gain and swing edits take
effect together on the next unscheduled bar, including the playhead.

The browser has Sound, Pattern gain and Swing controls for the selected
pattern, and includes nondefault values in its Lisp subtitle. New fields
use the same snapshot/undo and stale-revision checks as notes. Unknown
sounds, duplicate or unknown options, nonfinite and out-of-range numbers,
pitched drum notes and odd-length swung patterns are rejected as data.
The experimental Cuis view retains its existing controls; use the browser
or score file for these new fields.

## Chord progressions

A progression is another named pattern: select it or assign it to a pad.
The browser shows chord blocks instead of note cells. Add its form to your
score file to create one:

```lisp
(defprogression verse '(I (vi 2) - IV V) :key 'f :sound 'bell :gain 0.6)
```

Each bare degree lasts one four-beat bar. `(vi 2)` lasts two bars; `-` is
a silent bar and `(- 2)` is two silent bars. There are 1–32 blocks, each
1–16 whole bars, and at most 128 bars in total. The sequence loops; selecting
its pad starts at the first bar. `play --bars N` counts bars, including silence,
not whole sequences. Patterns and progressions share the 32-name limit.

Degree spelling is case sensitive: `I II III IV V VI VII` are major triads;
`i ii iii iv v vi vii` are minor triads. Their roots use the major scale's
semitone offsets 0, 2, 4, 5, 7, 9, 11 from the key. Lowercase changes the
third, not the scale: `vi` in C is A minor; `i` in C is C minor. There is
no inferred minor mode, diminished chord, seventh or inversion. Mixed case
such as `Iv` is refused. Other score names and options remain case insensitive.

`:key 'f` sets the tonic for the entire progression; the default is C.
Use a letter C–B with optional `s` for sharp or `b` for flat (`fs`, `bb`).
The root starts at that written tonic in octave 3 (so C-flat is B2), and
degrees rise from there. Major triads add 4 and 7 semitones; minor triads
add 3 and 7. In F, `I` plays F3–A3–C4 and `vi` plays D4–F4–A4.
These are close, root-position voicings, with no voice-leading adjustment.

Each occupied bar rearticulates all three notes together, using the existing
short note envelope (0.3 seconds); lengthening a block repeats that chord
on each bar, rather than sustaining it. The three voices divide pattern gain
equally, then multiply by session gain. Sine, bass and bell are available;
drums and swing are refused for progressions. Existing note patterns keep
their timing and levels.

Choose each block's degree and **Bars**, drag it to a new position or use
its left/right arrows, and choose **Key** to transpose the progression.
Sound and Pattern gain work as before. Each edit validates the whole score,
takes a snapshot and changes only the necessary tokens. Reordering moves
musical values among the existing positions; comments and whitespace stay
in their original positions. Unrelated forms are preserved. A stale edit
is refused. The Lisp subtitle represents the same accepted blocks, durations,
key and sound; it normalizes a one-bar block to a bare degree.

Live edits take effect at the next unscheduled bar, keeping the scheduled bar
index modulo the new progression length. Changing the key transposes that
next bar. Invalid edits keep the last good playback, blocks and subtitle.
The accent outline follows the bar reported by the separate Lisp clock,
including silent bars; no music is scheduled in the browser. The experimental
Cuis view does not edit chord blocks: use the browser or score file.

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

## Open the music interface

The browser is the default Music interface. In one terminal, start the
session; in another, open the browser view:

```sh
vikix music serve
vikix music web
```

`serve` also accepts a song's `patterns.lisp`. For editing it must be in
`~/music/SONG/patterns.lisp`, where snapshots cover it. The browser opens
with your default browser. The experimental Cuis alternative opens with
`vikix music cuis` and needs `vikix add cuis`; it runs
in a disposable base image and does not change your saved Cuis image.
Close its Music window to quit that disposable image.

Click a named pad to select and play its pattern, or choose a pattern and
press Play. One pattern plays at a time; switching pads stops the old one
and starts the new one from its beginning. Clicking the playing pad keeps
it running. Scores without a bank keep pads in file order. Desktop controls
use their own Music prefix (below). Each step paints the selected note; a
second click on that note makes a rest. The browser offers the full note
range; the Cuis comparison cycles a small high-note palette and shows
sixteen steps per page. Tempo and gain controls work in both. Tempo is
saved to the song; session gain is capped at 0.1. The browser also saves
per-pattern sound, relative gain and swing. File edits
arrive at the next bar, and both views refresh from the same file.

The browser's **This pattern in Lisp** strip shows the selected pattern
and tempo as Lisp forms. It follows note edits, tempo changes, pattern
selection and external file edits. This is a readable representation of
the grid; the file keeps its own comments and formatting. An invalid edit
leaves the last good grid and subtitle visible together.

An accent outline follows the playing step, including rests, when the playing
pattern is selected. Its timing comes from the Lisp clock, so a tempo edit
takes effect on the playhead when the next bar is scheduled. This is a
visual guide, not a measurement of speaker latency. A delayed connection
can briefly hide the outline; stopping or disconnecting clears it.

An edit takes a snapshot first and replaces only the changed note, tempo, sound, gain, swing or
bank tokens, keeping existing comments and formatting. Creating a bank appends
a new form. A stale revision is refused: review
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

## Save pad assignments

Open **Edit pad assignments**, choose a pad number and a named pattern, then
click **Save assignment**. Choose **Unassigned** to clear a pad. The first
assignment saves the other file-order pads too, so they stay where they were.
All named patterns remain available in the Pattern selector, even if no pad
refers to them. The score stores assignments as data:

```lisp
(bank 1 melody 2 pulse 8 melody)
```

There can be one bank, with slots 1 through 32. Gaps and the same pattern on
several pads are allowed. `(bank)` leaves every pad unassigned; no bank form
uses the original file-order pads. Names are case insensitive, and a bank may
appear before its patterns. Duplicate pad numbers, multiple banks, unknown
pattern names, out-of-range slots and incomplete pairs are errors, never
silently discarded. Invalid files are refused at startup; invalid live edits
keep the last good pads and playback, with an error shown in the view.

Assignments survive closing the browser and restarting the session. They use
the same snapshot and revision checks as grid edits: `vikix undo` restores
them too, and stale assignment edits or pad launches are refused. Changing
or clearing an assignment does not switch the playing pattern. Click a pad
to switch; **Playing** names the actual pattern and all pads assigned to it
light up. Only one pattern plays at a time. The experimental Cuis view still
selects patterns directly; edit bank assignments in the browser or score.

## Desktop controls

Start `vikix music serve` as before. **Super+Alt+F8** opens the Music
controls: **p** plays the selected pattern, **s** stops, **1–9** plays that
bank pad, **0** picks from all assigned slots (1–32), and **o** opens the
browser. Each action closes the prefix; Escape cancels. The same choices
are in **Super+m → Music**. Super+digits still select workspaces and
existing application keys stay unchanged. An empty pad reports a failure
without changing playback. There is still only one bank; this selects
its assigned pads, not a second bank or a new song.

These commands control only the running shared session. They never start
an engine or service on their own. A missing, stopped or busy session
returns promptly and desktop controls show a notification; check its
terminal. The standalone `vikix music play` still owns its own player and
is not controlled by the shared session's Stop.

```sh
vikix music control play
vikix music control stop
vikix music control bank 12
vikix music control bank
vikix music control state
```

The bar quietly shows `music 2/4 · 120` while playing: a beat sampled
about once a second and the tempo of the scheduled bar. It can skip beat
numbers and is not a flashing metronome or a measurement of audio latency.
It disappears after Stop or loss of the connection at the next sample.
A starting player shows a dash until its clock supplies a bar.
Neither StumpWM nor the browser schedules sound.

The browser follows Vikix's palette, including light themes, on its next
state refresh. Cells, pads and the playhead retain their existing behavior;
the playhead and focus outline use the theme accent. A missing palette
uses Vikix dark. Switching themes needs no Music restart or page reload.

## What comes later

Capture, DAW integration, MIDI and variations remain.

`vikix remove music` removes the feature's dependencies when nothing else
needs them and the prepared synth, keeping `~/music`. `vikix music setup`
can rebuild the synth without replacing your patterns.
