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
browser. **r** starts engine recording and **Shift+r** stops recording. Each action closes the prefix; Escape cancels. The same choices
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

## Record and preserve a take

Recording is always explicit. In the browser choose **Record source**, then
**Start recording**; **Stop recording** ends the take and releases its recorder.
The browser and bar name the active source in the alert colour. The Music
prefix's **r** starts **engine only**; **Shift+r** stops recording. Recording
state is also in `vikix music control state` or **Super+m → Music → Recording status**
(`vikix music control record-state`). Merely opening Music, choosing a
source or playing a pattern never opens a microphone.

```sh
vikix music control record
vikix music control record-stop
vikix music control record --source microphone
vikix music control record --source mixed
```

The default captures only this session's engine outputs, not other desktop
sound. Start a pattern first. Microphone captures one mono or stereo PipeWire
`Audio/Source`; with multiple sources, name one explicitly using
`--device NODE` (the browser has the same field). Find node names with
`pw-dump`. Mixed connects the engine and that microphone to the recorder;
mono inputs feed both channels and mixed inputs are summed, so leave headroom
to avoid clipping. Microphone audio is never monitored to speakers by Music.
A missing or ambiguous source is refused. Devices with more than two ports
are refused rather than guessing a channel pair.

Playback Stop still stops playback; **Stop recording** is separate. Changing
pads replaces the engine, so an engine/mixed take ends as partial when its
source disappears. Stop recording before changing pads. Closing a browser
leaves an explicitly started take running: reconnect to stop it, or press
Ctrl+C in the session terminal. A session exit stops recording and preview.
No recording starts on its own, and no captures are automatically deleted.

Each take is reserved exclusively under
`~/music/inbox/SONG/YYYY-MM-DD/take-NNNN/`, using the active song's folder
name and the local date at recording start. Repeated takes advance the number;
existing directories are never reused. `audio.pcm` is headerless stereo,
48,000 Hz, signed 16-bit little-endian PCM. `take.json` records source and
format before audio starts; `stopped.json` records a normal stop or a known
partial failure. Missing or unreadable stop metadata means interrupted, never
complete. The listing reports source, status, duration and ID. Raw audio
avoids a final WAV header being lost on interruption. It uses about 11 MB/minute.

Open **Capture inbox** and **Refresh captures**, then **Preview**, **Loop**,
**Stop preview / loop**, or enter a song name and choose **File copy**. Preview
uses PipeWire, not browser audio, and requires a stopped take. Starting a
recording stops preview first. CLI operations use the same authenticated path:

```sh
vikix music control inbox
vikix music control preview --take SONG/YYYY-MM-DD/take-0001
vikix music control loop --take SONG/YYYY-MM-DD/take-0001
vikix music control preview-stop
vikix music control file --take SONG/YYYY-MM-DD/take-0001 --song another-song
```

Filing makes a new exclusive take directory under
`~/music/another-song/captures/YYYY-MM-DD/` and keeps the inbox original as a
recovery copy. Repeating File copy creates another take number; it never
replaces an earlier copy. Song names use letters, digits, underscores and
dashes. Capture operations refuse symlink paths. Audio is outside snapshot
undo: back it up separately. Vikix does not delete either copy.

### Recover and check recording

On device loss, recorder failure or a full disk, the recorder stops and any
bytes already written remain. The browser/state reports the failure; a disk
failure may also prevent writing the stop marker. After freeing space, use
**Refresh captures** and preview the partial take. A filing failure can leave
an incomplete destination directory; keep it and retry to a new take number,
using the intact inbox original. A successful copy has `filed.json` with
`complete: true`; a missing marker means copying did not complete. Do not treat a partial destination as a backup.

If Music cannot run, a preserved take can be heard directly:

```sh
pw-play --raw --rate 48000 --channels 2 --format s16 ~/music/inbox/SONG/DATE/TAKE/audio.pcm
```

An audio editor can import the same raw format; ignore a trailing incomplete
four-byte stereo frame. A hard power failure can lose unflushed data; Music
syncs audio chunks as they arrive but cannot recover bytes the device never
wrote. Keep the original raw file while recovering or converting it.

Manual check after installation: play a pattern, record engine-only for a few
seconds, stop and preview it. Verify other desktop audio is absent. Explicitly
select Microphone, record a short spoken phrase, stop, and confirm the microphone
is released. Repeat Mixed with headphones and check both sources. Loop a take,
stop the loop, file it twice and check both numbered copies and the inbox
original. Finally interrupt the session while recording, restart and preview
the preserved partial take. Isolated automated routing/source fixtures do not
replace this human microphone and real desktop listening check.

## Export a score as MIDI and WAV

`send` reads the saved score once as data and exports every named pattern
separately. It works with Music stopped or playing and never contacts, stops
or changes the shared session. It does not export unsaved edits, session gain,
pad performance or recordings from the capture inbox.

```sh
vikix music send ~/music/first-song/patterns.lisp
vikix music send ~/music/first-song/patterns.lisp --pattern verse --repeat 4
vikix music send ~/music/first-song/patterns.lisp --format midi
```

Without a file, it uses `~/music/first-song/patterns.lisp`. `--pattern NAME`
selects one name, case insensitively; otherwise each name exports once in file
order, including names without pads. Bank gaps and duplicate assignments do
not alter export order or repeat a pattern. `--repeat N` repeats each complete
pattern 1–16 times, default 1: a step pattern is one four-beat bar; a progression
is its entire sequence, including silent bars and expanded block durations.
The total nominal duration of a batch is limited to one hour; select fewer
patterns or repeats for a longer score.

Each successful command prints a new directory beneath the score file's sibling
`render/`, named `send-DATE-TIME-UNIQUE`. It contains numbered pattern files
and `export.json` listing original names, tempo, nominal duration, filenames,
WAV duration and repeat count. Safe filenames may replace punctuation; the
number keeps different names distinct. The default writes both `.mid` and
`.wav`; `--format midi` or `--format wav` writes only that format. MIDI needs
SBCL; WAV also needs SuperCollider and the palette prepared by `music setup`.
It does not need PipeWire, JACK, a browser or an audio device.

Both formats use the saved tempo (default 120), pitches, rests, swing and
progression voicings of the player. Swing delays alternate step onsets by
the saved fraction of a step. Note duration is the shorter of 0.3 seconds
and 80% of a straight step; progression chords rearticulate for 0.3 seconds
on each occupied bar, including repeated bars. They do not sustain across
blocks. Export starts at time zero and keeps trailing silent bars. A note
delayed past the last bar's end keeps its full duration: MIDI ends after its
note-off, WAV after its envelope plus two 64-sample blocks (about 2.7 ms)
for the engine's scheduling and control-rate rounding. Otherwise files end at the nominal bar
boundary. A swung last note can therefore make a file slightly longer than
the bar grid; use the nominal duration when arranging loops in a DAW.

MIDI is a type-0 Standard MIDI File with tempo and 4/4 metadata, at 9,600 ticks
per quarter note. Tempo rounds to the nearest microsecond per quarter and
events to the nearest tick. Pitched notes use channel 1; melodic `x` is A3
(MIDI 57). Drums use channel 10 with General MIDI notes 36 (kick), 38 (snare)
and 42 (closed hat). Velocity scales pattern gain to 1–127; progression voices
divide that gain by three. Gain zero omits note events. There are no program
changes: **MIDI contains notes and timing, not Vikix's synthesized timbres or
raw captured audio**. Choose instruments in the receiving application;
its velocity response and envelopes will differ.

WAV is stereo, 48,000 Hz, signed 16-bit PCM. A finite SuperCollider offline
render uses the same prepared six-voice palette and event functions as live
playback, at fixed session gain 0.08 multiplied by pattern gain (divided by
three per progression voice). It ignores the live session's gain slider.
The renderer's short silent preparation interval is removed. Each voice keeps
its released envelope; the closed hat lasts 61 ms regardless of note duration.
Noise-based sounds can differ between renders; timing is fixed, but identical
audio bytes are not promised. No live sound or microphone is captured, and
no normalization is applied.

The batch becomes visible under its final name only after every requested file
has succeeded. Earlier exports are never replaced. Invalid scores, missing
sounds, renderer failures, full disks and Ctrl+C leave earlier batches intact;
normal failures and handled signals reap the command's children and remove its
temporary `.send-*` directory. A power loss or uncatchable kill can leave that
hidden temporary directory; it is not a completed export. Keep completed batches
backed up separately: snapshot undo covers scores, not rendered files.

Manual check after installation: keep a browser pattern playing, run `send`
with a short swung melody and a progression containing silence, and verify the
browser keeps its selection, gain and playhead. Open the resulting MIDI in a
DAW, choose instruments, and check notes, tempo and rests. Listen to the WAV
and compare its timbre with live playback at session gain 0.08. Run export
again and confirm the earlier batch remains. Automated isolated launcher and
offline waveform checks do not establish real desktop listening quality.

## What comes later

DAW integration, MIDI controller input and variations remain.

`vikix remove music` removes the feature's dependencies when nothing else
needs them and the prepared synth, keeping `~/music`. `vikix music setup`
can rebuild the synth without replacing your patterns.
