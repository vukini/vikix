# Vikix Music — design

A musical sketchpad for the Lisp desktop. Patterns are Lisp; the window is a view of them; the DAW gets the result.

Drafted 2026-10-03 with Vid, from TODO item 22 (music production as a feature) and the IDEAS entry "Live-code music from the same Lisp". This document records the design; music-next.toml schedules the remaining work. Like Esploro's, it is kept honest by deleting what ships and dating what changes.

*2026-10-17: Phase 0 and the first browser sketchpad shipped in 0.72.85: optional
SuperCollider/PipeWire JACK/rtkit setup, independent SBCL timing, validated
patterns, safe live edits and undo, transport, tempo/gain, named-pattern pads,
Lisp subtitles and a scheduled playhead. Vid chose the browser and confirmed
the desktop trial. Cuis remains experimental. See [the user guide](../docs/music.md)
for the shipped behavior; this design describes the remaining work.*

*2026-10-17: Banks implemented at the music-banks desk, awaiting the user
release gate. Office decision d-20261017-017ba8 approved slots 1–32, gaps,
repeated patterns, one bank, and rejection of duplicate slots and missing
names. Scores without a bank retain file-order pads. See the user guide for
assignment editing and undo; desktop pad keys remain a later task.*

## Executable Office plan

[music-next.toml](music-next.toml) is the executable continuation, not a template.
It has one worker at a time and no user gate: each desk is released by the plan
once its tests pass (*2026-10-17: the gate and the "ask Vid before implementation"
lines were removed after the plan stopped four times in its first day; Vid: a plan
runs without his approvals*). A later desk starts from released main; the final
planning task shares the performance desk. The task descriptions narrow the
proposals below and settle the product choices; a worker decides what is left,
records it in the handoff, and asks through Office only when a choice would
change released behaviour. Starting the plan authorizes its task sequence;
pushing remains the user's.

On Vid's machine the Office draft is
`~/.config/vikix/plans/music-next.toml`, a copy of the committed plan. In Office, open **Plans**, choose **music-next**, and **Run**.
The CLI equivalent is `vikix agents plan run ~/.config/vikix/plans/music-next.toml`.
The handoff's manual checks are for after the release, on the desktop. The draft does not
start workers until Run is chosen. `vikix agents plan pause music-next` prevents new starts and releases;
workers already running carry on.

| Order | Task | Result at its release |
|---|---|---|
| 1 | Banks | Persistent pad assignments with undo |
| 2 | Sounds | Original sound palette, bounded dynamics and swing |
| 3 | Progressions | Chord blocks with approved voicing semantics |
| 4 | Desktop | Conflict-free controls, beat/tempo display and theme |
| 5 | Capture | Explicit recording and a preserved capture inbox |
| 6 | Export | Per-pattern MIDI and offline WAV |
| 7 | Ardour | Optional DAW installation and a safe import workflow |
| 8 | Agent access | Read state and user-reviewed proposals |
| 9 | MIDI input | Controller learning and reconnect handling |
| 10 | Variations | Audition, accept and bounded bar choices |
| 11 | DAW transport | Local Ardour and optional Reaper control |
| 12 | Analysis | Honest tempo/key estimates on captures |
| 13 | Latency mode | Measured, reversible recording settings |
| 14 | Performance + next plan | Fullscreen pads/panic and an Office plan for selected later ideas |

Each task owns implementation, regression coverage, guides, commits and handoff.
The tests must use the project runner and isolated launchers. Browser/engine
fixtures are distinct from a human listening or operating a MIDI controller.
Physical round-trip latency still needs an audio loopback connection; a JACK
block duration is not that measurement. Remaining P2 ideas are reconsidered in
the last task rather than automatically turning a speculative engine or private
syllabus into implementation work.

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
  (text) (grid, pads, (pad keys fire  (edits the file,
          knobs,       a pattern;      snapshot first)
          transport)   bar shows beat)
          │
          ▼
  SuperCollider (scsynth) ──► PipeWire (JACK side) ──► speakers / Ardour
```

- **`vikix-music`** runs its Common Lisp clock separately from StumpWM: a crash stops the music, never the desktop. SBCL watches `patterns.lisp` and schedules notes. The Python supervisor owns its engine and carries timestamped notes; the Phase 1 spike adds a local authenticated websocket for views (127.0.0.1, a fresh session secret).
- **The pattern language** is small by design: if a form can't be drawn, it doesn't belong in v1. See below.
- **The web view** is a page served by `vikix-music`, opened in the user's default browser. A second face, in Cuis Smalltalk's Morphic, is the experimental spike described in `DESIGN-cuis.md` (`VikixMusic`): it speaks the same socket protocol, so the two can coexist and the protocol is settled once; Vid chose the browser as the default on 2026-10-16, retaining Cuis as an experimental alternative. Future musical controls may reuse the shared chord and scale logic where its scope and access permit. Every click is one message; the process rewrites one form; every view redraws.
- **Keys and the bar** go through StumpWM as everything else does: `define-vikix-command` entries for play, stop, record, fire-pattern N, so they are on keys, in Super+m, in the key help and offered to the agent from one definition.
- **The DAW link** is `vikix music send`: MIDI files and rendered WAVs into `~/music/<song>/render/`, and OSC transport commands (play, stop, marker, arm) that Ardour and Reaper both answer. The Lisp side does not care which is listening.

### The pattern language, v1

Every form has a picture. Nothing else is in v1.

| Form | Picture | What it is |
|---|---|---|
| `(defpattern hats '(x - x - x x - -))` | a row of cells | a rhythm; `x` hits, `-` rests; length is the bar |
| `(defpattern bass '(c2 - - g1 - c2 eb2 -))` | a row of cells with note names | a melody or bassline |
| `(defprogression verse '(I vi IV V) :key 'f)` | blocks in a row | chords by degree; drag to reorder, stretch to lengthen |
| `:bpm 100` `:swing 0.3` `:gain 0.8` | a knob each | numbers |
| `(bank 1 hats 2 bass 3 verse)` | a grid of pads, labelled with their keys | persistent pad assignments; desktop keys require a binding audit |
| `(every-bar (choose hats-a hats-b))` | a pad with a dice | chance, the one generative form |
| `(variations bass :invert :shift 2)` | a list of candidates with a play button each | audition, pick one, it becomes a pattern |

Sound choices (`:sound 'kick`, `:sound 'piano`) pick from a small shipped set of SuperCollider synthdefs and samples; a dropdown in the view.

### Subtitles

*2026-10-16: the browser grid now shows the selected pattern and tempo as
Lisp forms beneath the cells. The strip follows selection, accepted edits
and external file refreshes, retaining the last good state on invalid data.
It is generated from the same validated state as the cells, not a verbatim
copy of the file's comments and whitespace. No protocol or audio change is
needed. The user guide describes this shipped behavior.*

### The inbox

A conflict-free recording command starts the approved source (mic, engine, or mixed; decide before implementation) into `~/music/inbox/2026-10-03-0734.wav`; the bar shows the alert colour while it runs; the same key stops it. An open-view command opens the last pattern; assign a key only after checking the registry. `vikix music inbox` lists captures with a waveform each; "loop this", "send to <song>", "file under…" as the notes inbox does. Captures are never deleted by Vikix; filing moves them.

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

The installed engine, basic patterns, next-bar reload, browser grid, transport,
subtitles, named-pattern pads, playhead and snapshot undo are implemented.
What remains for the first version is assigned to the first eight Office tasks:

1. **Sounds:** sound selection, bounded swing
   and dynamics, and rhythm hits; old scores must retain their behavior.
2. **Progressions:** validated chord blocks with a browser representation and
   agreed voicings, keys and durations.
3. **Desktop integration:** registry commands, conflict-free keys, a nonblocking
   beat/tempo display, and theme integration.
4. **Capture inbox:** explicit source selection, preserved recordings, preview,
   loop and filing, with interruption recovery.
5. **Export and Ardour:** deterministic MIDI/WAV output, optional DAW installation,
   and a safe workflow that preserves existing user sessions.
6. **Agent access:** read-only state and proposals reviewed and applied by the
   user, with the same validator and undo path; no evaluator into Music.

The executable tasks carry the acceptance checks. Physical round-trip latency
is still an evidence gap; finish it only with suitable measurement equipment.

### Should have (P1)

10. MIDI in: a controller's pads fire the bank, its knobs move the numbers (PipeWire/ALSA → `vikix-music`), with a learn mode in the view.
11. `variations` with audition in the view.
12. OSC transport to Ardour and Reaper (play, stop, drop marker, arm track N) behind the same commands.
13. `vikix add reaper` as a second DAW feature, from reaper.fm, pinned and checksummed as Ollama is.
14. Key and tempo detection on inbox captures (aubio or keyfinder), shown in the list.
15. Low-latency toggle: a Super+m entry that sets the quantum and the CPU governor for recording, and back; the bar says which.

### Later (P2), designed for now

16. Esploro recipe: sort a sample folder by detected key and tempo, plan-then-apply with undo. The catalogue behind it may be the PicoLisp music catalogue (IDEAS, "PicoLisp": track X of *Living in PicoLisp*, a pil program with its database, Pilog and `native` calls to aubio and libkeyfinder, serving a page on loopback), so the inbox's captures and the renders are its first records.
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

Decide through Office when the relevant task starts:

- The first sound palette, any sample source and license, and gain semantics.
- Chord voicings, keys and progression-block durations.
- Pad and recording keys after auditing the registry: Super+digits belong to workspaces.
- Recording sources and defaults, capture filing and recovery behavior.
- The controller available for a real MIDI trial and its learn/reconnect behavior.
- The initial variation operations, DAW session layout and optional Reaper adoption.
- Quantum/governor changes and restoration before adding recording latency mode.
- The syllabus, catalogue scope and evidence for an alternative engine in the later plan.

Already settled: SuperCollider is the engine, the browser is the default view,
short note names and `-` rests are the accepted notation, and realtime scheduling
was observed on the X1 and in the VM's desktop session. Physical round-trip
latency remains unmeasured.

## Phasing

The implemented baseline is described in the user guide. The executable plan
above replaces the old weekend/first-release milestones: small releases let Vid
try one addition before the next starts. Banks through reviewed agent access
complete the remaining first-version work; MIDI through performance cover the
next stage. The final task turns selected P2 ideas into a subsequent executable
plan with current evidence and explicit scope.

## Risks

- **SuperCollider on Void.** Installation and realtime scheduling were exercised; new sounds and recording paths still need their own validation.
- **Timing over a websocket.** None: the view never carries timing. But if someone puts audio in the browser later, this document should stop them.
- **The language grows.** Every new form needs a picture before it is accepted. A form without a picture is a sign the feature is becoming a programming environment, which Emacs already is.
- **Two curricula drift.** The React app and `vikix learn music` share a syllabus file, checked in one place, or they will diverge.
