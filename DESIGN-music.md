# Vikix Music — design

A musical sketchpad for the Lisp desktop. Patterns are Lisp; the window is a view of them; the DAW gets the result.

Drafted 2026-10-03 with Vid, from TODO item 22 (music production as a feature) and the IDEAS entry "Live-code music from the same Lisp". This document is the plan for the first version. Like Esploro's, it is kept honest by deleting what ships and dating what changes.

---

## The problem

A musician with a laptop loses ideas to load time. A DAW takes a minute to open and asks for a project name before a note is played; by then the idea is gone. And a DAW is a tape recorder with a grid: good at recording a performance, poor at "give me twelve variations of this bassline", at rhythms that choose on each bar, and at anything the musician wants to change while it plays.

A learner has the opposite problem: theory arrives as rules before it arrives as sound, and nothing on a normal desktop lets them hear why twelve notes, or what a fifth is, by changing a number.

Vikix can serve both, because the desktop is a running Lisp program: a pattern can be a list, a list can be drawn as a grid, and a key, a rule, the agent and a window can all change the same list while it plays.

## Who it is for

- **The producer.** Plays, records, mixes in a DAW. Wants to catch ideas in seconds, make variations fast, and get them into the DAW as MIDI and audio. Will never read Lisp unless curious.
- **The player who never learned theory.** Has an instrument and an ear. Wants to hear why things work. Reader of the Music Theory app in Living in Music.
- **The curious programmer.** Already in Vikix for Lisp. Wants to make sound from a REPL.

The codeless window serves the first two; the text view serves the third; the file on disk serves all three.

## Goals

1. **A sound within a minute of `vikix add music`.** Measured from the end of the install to a note heard, on the test VM and on the X1.
2. **An idea caught in two keypresses,** without naming anything: a key starts a recording, the same key stops it, and the capture is in `~/music/inbox/`.
3. **Every pattern has two faces that stay equal.** Click a cell in the grid, the Lisp form changes; edit the form, the grid redraws. There is one file, and both views read and write it.
4. **The result lands in the DAW** as MIDI and rendered audio, in the song's folder, with one command.
5. **Undo covers a music session** with no new machinery: the pattern file is in the snapshot set, so `vikix undo` already works.

## Non-goals (this version)

- **Not a DAW.** No multitrack audio editing, mixing, mastering or plugin hosting. Ardour (and Reaper) do that; this feeds them. Writing a DAW is years of work to arrive at a worse one.
- **Not a synthesizer of its own.** Sound is made by SuperCollider, a proven engine underneath, Lisp for the behaviour. The same rule as the Lisp apps in IDEAS.
- **Not a tracker or notation editor.** No staff view in v1; the Music Theory app has one, and the two share a syllabus, not code.
- **Not a sample library manager.** Esploro does that (sorting by detected key and tempo is an Esploro recipe, later).
- **Not generative AI music.** The agent operates the tools and answers questions; it does not compose. The music is the person's.
- **No audio in the browser.** The web view draws and sends messages; timing and sound stay in the Lisp process, so the page can be slow or closed without a dropout.

## How it is built

Three pieces, in three processes, as Esploro taught:

```
 ~/music/<song>/patterns.lisp        the truth: one file, plain Lisp
          │
          ▼
 vikix-music (SBCL, its own process)  reads the file, keeps time, talks to
          │                            the sound engine; a websocket for views
     ┌────┼─────────────┬──────────────┐
     ▼    ▼             ▼              ▼
  Emacs  web view    StumpWM keys    agent (vikix mcp)
  (text) (grid, pads, (Super+5 fires  (edits the file,
          knobs,       a pattern;      snapshot first)
          transport)   bar shows beat)
          │
          ▼
  SuperCollider (scsynth) ──► PipeWire (JACK side) ──► speakers / Ardour
```

- **`vikix-music`** is a Common Lisp program, not part of StumpWM: a crash stops the music, never the desktop. It watches `patterns.lisp`, holds the clock, schedules notes to the engine, and serves views over a local websocket (127.0.0.1, a secret as Swank has).
- **The pattern language** is small by design: if a form can't be drawn, it doesn't belong in v1. See below.
- **The web view** is a page served by `vikix-music`, opened in Nyxt as a `vikix:` page or in Firefox. It reuses what Living in Music already has: keyboards, fretboards, chord and scale logic. Every click is one message; the process rewrites one form; every view redraws.
- **Keys and the bar** go through StumpWM as everything else does: `define-vikix-command` entries for play, stop, record, fire-pattern N, so they are on keys, in Super+m, in the key help and offered to the agent from one definition.
- **The DAW link** is `vikix music send`: MIDI files and rendered WAVs into `~/music/<song>/render/`, and OSC transport commands (play, stop, marker, arm) that Ardour and Reaper both answer. The Lisp side does not care which is listening.

### The pattern language, v1

Every form has a picture. Nothing else is in v1.

| Form | Picture | What it is |
|---|---|---|
| `(defpattern hats '(x . x . x x . .))` | a row of cells | a rhythm; `x` hits, `.` rests; length is the bar |
| `(defpattern bass '(c2 . . g1 . c2 eb2 .))` | a row of cells with note names | a melody or bassline |
| `(defprogression verse '(I vi IV V) :key 'f)` | blocks in a row | chords by degree; drag to reorder, stretch to lengthen |
| `:bpm 100` `:swing 0.3` `:gain 0.8` | a knob each | numbers |
| `(bank 1 hats 2 bass 3 verse)` | a grid of pads, labelled with their keys | what Super+1..9 fires |
| `(every-bar (choose hats-a hats-b))` | a pad with a dice | chance, the one generative form |
| `(variations bass :invert :shift 2)` | a list of candidates with a play button each | audition, pick one, it becomes a pattern |

Sound choices (`:sound 'kick`, `:sound 'piano`) pick from a small shipped set of SuperCollider synthdefs and samples; a dropdown in the view.

### Subtitles

Under the grid, a strip shows the form that just changed, as text, as you click. It can be ignored forever. It is the bridge from the codeless user to the learner, and the same idea as Esploro's "edit the plan as text".

### The inbox

`Super+Alt+m` starts recording the mic (and the engine's output, if playing) into `~/music/inbox/2026-10-03-0734.wav`; the bar shows the alert colour while it runs; the same key stops it. `Super+Alt+l` opens the last pattern running in the view. `vikix music inbox` lists captures with a waveform each; "loop this", "send to <song>", "file under…" as the notes inbox does. Captures are never deleted by Vikix; filing moves them.

## User stories

**Producer**
- As a producer, I want to press one key and be recording so that an idea at the piano is caught before it goes.
- As a producer, I want to toggle cells in a grid and hear the change on the next bar so that I can shape a beat without stopping it.
- As a producer, I want twelve variations of a bassline I can audition so that I find the one I wouldn't have written.
- As a producer, I want "send to Ardour" to leave MIDI and audio in the song's folder so that the sketch becomes a track in the DAW I already use.
- As a producer, I want my MIDI controller's pads and knobs to drive the same patterns so that I am not at the keyboard.

**Player who never learned theory**
- As a player, I want to change `(I vi IV V)` to `(I V vi IV)` and hear it so that progressions stop being names.
- As a player, I want a backing band for `(ii V I)` in F at 120 so that I can practise over it in Ardour.
- As a player, I want to see the Lisp under what I clicked so that, when I'm ready, I can type it.

**Curious programmer**
- As a programmer, I want `(tone 440)` from a REPL to make a sound so that the engine is mine from the first minute.
- As a programmer, I want patterns to be plain lists so that I can write my own transformations.

**Everyone**
- As anyone, I want `vikix undo` to take back the last musical change so that trying is free.
- As anyone, I want the agent to "make the hats busier" and show me the diff so that I can say no.

## Requirements

### Must have (P0)

1. **`vikix add music`**: PipeWire's JACK side, realtime priority that works under runit (rtkit with D-Bus and polkit, or `limits.conf`), SuperCollider, `vikix-music`, the shipped sounds, Ardour. `vikix doctor` reports latency class and that the engine answers.
   - [ ] On the VM and the X1: `(tone 440)` heard within 60 s of install end
   - [ ] `vikix music doctor` prints quantum, sample rate, xruns in the last minute
2. **The clock and the engine link**: patterns play in time at 60–200 bpm, change on the next bar when edited, no dropout when a view connects or disconnects.
   - [ ] Edit `patterns.lisp` in Emacs, save: the change is heard at the next bar boundary
   - [ ] Close the web view while playing: no audible change
3. **The pattern language, as tabled above**, with a reader that refuses anything else and says why (as Esploro's `step-shape-problem` does).
   - [ ] A form outside the table is refused with a one-line reason; the music keeps playing
4. **The web view**: grid, progression blocks, knobs, pads, transport, sound dropdown, subtitles strip; follows `vikix theme`.
   - [ ] Click a cell: the form in the file changes and the subtitle shows it within one frame
   - [ ] Edit the file: the grid redraws without a reload
5. **Keys and bar**: play/stop, record, fire pad 1–9 as `define-vikix-command` entries; beat and bpm in the bar in the quiet colour while playing, alert colour while recording.
6. **The inbox**: capture key, stop, list, loop-this, file-under; captures never deleted.
7. **`vikix music send <song>`**: MIDI per pattern and a rendered WAV per pattern into `render/`; `vikix music ardour open` opens the song's Ardour session (creating it on first use) with `render/` as a region list.
8. **Undo**: `~/music/*/patterns.lisp` in the snapshot set; `vikix undo` after a music edit restores the previous file and the engine picks it up.
9. **Agent access**: the pattern file is editable by the agent through the existing propose-and-review route (snapshot first, diff shown); `vikix mcp` gains `music_state` (read) and `music_edit` (a form, checked by the same reader). No `eval` into the music process.

### Should have (P1)

10. MIDI in: a controller's pads fire the bank, its knobs move the numbers (PipeWire/ALSA → `vikix-music`), with a learn mode in the view.
11. `variations` with audition in the view.
12. OSC transport to Ardour and Reaper (play, stop, drop marker, arm track N) behind the same commands.
13. `vikix add reaper` as a second DAW feature, from reaper.fm, pinned and checksummed as Ollama is.
14. Key and tempo detection on inbox captures (aubio or keyfinder), shown in the list.
15. Low-latency toggle: a Super+m entry that sets the quantum and the CPU governor for recording, and back; the bar says which.

### Later (P2), designed for now

16. Esploro recipe: sort a sample folder by detected key and tempo, plan-then-apply with undo.
17. `vikix learn music`: the Music Theory syllabus as lessons whose steps are forms in this language. Shares the syllabus with the React app, not the code.
18. The function time machine for patterns: a history of a pattern's versions beyond snapshots.
19. Live performance mode: full-screen pads, no editing, a panic key.
20. Incudine as an alternative engine, if SuperCollider's install proves heavy on Void.

## What success looks like

Leading, in the first month on Vid's machines:
- Install to first sound under 60 s on the VM (goal 1), every release.
- Inbox used: captures per week > 0 is the only honest target; the feature exists to be reached for.
- Zero xruns in a 10-minute play at the default quantum on the X1.
- The grid and the file never disagree: a test that round-trips every form in the table.

Lagging, by the third month:
- A finished track in Ardour began as a Vikix sketch.
- One lesson of `vikix learn music` written in the pattern language without the language needing a new form.

## What Void has (checked against void-packages master, 2026-10-03)

| Package | Version | Note |
|---|---|---|
| `supercollider` | 3.14.1 | built against JACK; the Qt IDE is a build option |
| `sc3-plugins` | 3.14.0 | extra UGens |
| `rtkit` | 0.14 | ships a runit service (`/etc/sv/rtkit`); needs D-Bus, which Vikix has |
| `libjack-pipewire` | with `pipewire` 1.6.8 | PipeWire's JACK client library and `pw-jack` |
| `libspa-jack` | with `pipewire` | the JACK SPA plugin |
| `ardour` | 9.8 | hosts LV2 itself |
| `aubio` | 0.4.9 | tempo detection |
| `libkeyfinder` | 2.2.8 | key detection |
| `a2jmidid`, `fluidsynth`, `qjackctl` | current | available if wanted |
| `carla` | not in Void | TODO 22 names it; drop it or build from source |
| `reaper` | not in Void | from reaper.fm, pinned and checksummed, as Ollama is |
| Incudine | not in Void | Quicklisp plus a C build; P2 only |

Decided by this check:
- **Engine: SuperCollider**, from the repo, with `cl-collider` from Quicklisp for the Lisp side. Incudine stays the P2 alternative.
- **Realtime: rtkit** through its runit service. `limits.conf` and the `audio` group are the fallback if a VM test shows rtkit refusing `scsynth` or `vikix-music`.

## Open questions

Blocking:
- **Where the shipped sounds come from.** (Vid) A small set of CC0 samples and a dozen synthdefs; which, and the licence file.
- **Does Void's `supercollider` pull Qt6 in?** (one command on the laptop: `xbps-query -Rx supercollider`) The template puts Qt6 behind a build option, so probably not; if it does, the package list still works, it is just heavier.
- **Does rtkit grant RT over D-Bus on Void?** (one VM test) Start the service, run `scsynth`, check `chrt -p` on its threads.

Non-blocking:
- Nyxt `vikix:` page or Firefox as the default home for the view? Both work; Nyxt keeps it in Lisp.
- Should the inbox also take the engine's output while playing, or only the mic? Default proposed: both, mixed, with the mic alone a setting.
- Note names in patterns: `c2 eb2` (short) or `(c 2)` (readable to a parser)? Proposed: short names, since the view shows them.

## Phasing

**Phase 0, a weekend:** `vikix add music` installs the engine; `(tone 440)` from Emacs; one `defpattern` playing in time; `vikix undo` works on the file. Nothing else. If this isn't fun, stop.

**Phase 1, the first release:** P0 items 1–9. The web view ships with the grid, pads, knobs, transport and subtitles; progression blocks may follow in a point release.

**Phase 2:** P1 items, MIDI first.

**Phase 3:** `vikix learn music`, when the Music Theory app's syllabus is settled enough to share.

## Risks

- **SuperCollider on Void.** Checked: 3.14.1 in the repo, so no source build. The risk left is the Qt question above.
- **Timing over a websocket.** None: the view never carries timing. But if someone puts audio in the browser later, this document should stop them.
- **The language grows.** Every new form needs a picture before it is accepted. A form without a picture is a sign the feature is becoming a programming environment, which Emacs already is.
- **Two curricula drift.** The React app and `vikix learn music` share a syllabus file, checked in one place, or they will diverge.
