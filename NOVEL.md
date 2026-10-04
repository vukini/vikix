# Novel ideas

Things no other desktop does, that Vikix could, because it is a live Lisp program with local AI, snapshots, rules and the Living Series on the same machine. Kept apart from `IDEAS.md` (which gathers everything not yet decided) so they aren't lost among the small ones.

**Who writes here:** the cloud ideas session (the conversation with Vid that began 2026-10-03, on claude.ai), and Vid. Other sessions **read** this file and may add a dated note under an idea (`> 2026-10-05, the viri session: …`) when they learn something that bears on it; they don't rewrite an idea or delete one. When an idea is picked up it moves to `TODO.md` or a `DESIGN-*.md` and a one-line pointer stays here. Nothing here is decided.

---

## 1. Learn a language by living in it

The desktop teaches you a language by immersion, the way *La Mondo Konata* and the Toki Pona book do, with the machine as the text.

- Day one: the strings you see most (the bar, Super+m, notifications, the key help, `vikix`'s own messages) are five percent in Esperanto, with the English a hover or a long-press away. The words chosen first are the ones that recur most and whose meaning the screen already shows: *fenestro* beside a window, *baterio* beside the battery.
- Each time you act on a translated string without looking at the English, that word is learned; the desktop adds more. Spaced repetition, but the cards are your own menus, and the review is your day.
- Levels, not a switch: the share grows from five percent towards all of it as words are learned; `vikix lingvo` (or whichever name) shows the percentage, lets you step back, and lists what you know. A hard day can be an English day without losing progress.
- The agent speaks it when you do: Super+i and the agent's replies follow the same level, and "what does this word mean" is one key on any string.
- Beyond Esperanto: Arabic (with the right-to-left and font work already planned), Toki Pona, then any language a Vikix user wants, since the strings pass through one Lisp layer and the translations are files beside the code (the translations in `IDEAS.md`, "Vikix in Esperanto", are the first step of this, not the whole).

Why only Vikix: every visible string already goes through one place, and the agent that can explain any of them is on the machine. For an Esperanto educator, this is a product in itself: a desktop that is also the course.

First step: the string table and the hover for one component (the bar), with the counting of "acted without hovering" and the percentage, in Esperanto only. If living with it for two weeks teaches real words, the rest follows.

## 2. Every part of this computer has a chapter

`Super+?` on anything running opens the explanation at the right depth from your own books.

- A process in the bar: what a process is, from the memory project. A port: what a socket is, from Bottom-Up C. A service: the runit chapter of the Void guide. A key: the key card, then `keys.lisp`. An instruction in a disassembly: *Build a Computer in Your Head*. A window: its StumpWM object and what a window manager does.
- The running system becomes the index of the Living Series; the books become the manual for the machine in front of you. Reading and using stop being separate activities.
- Built from two halves that exist: the docs catalogue (`vikix docs`, with the books as a source once `~/src/living-series` is indexed) and `vikix eval`, which can say what the thing under the pointer is. What's new is the join: a table from kinds of thing (process, port, service, key, window, package, file type) to the chapter that explains that kind, kept beside the books.
- Depth follows the reader: the "Four words, explained" register first, the chapter next, the source last.

Why only Vikix: nobody else owns both a desktop and a bottom-up library written for it.

First step: `Super+?` on the bar's items alone (battery, network, updates, a workspace number), each opening the matching guide page in Nyxt. Then the books.

## 3. Record a lesson

Doing a thing once becomes the first draft of teaching it.

- `vikix lesson record NAME`: from then on, every key (as the key card prints it), every command and its output (as a copy-pasteable transcript in the house style: typed at the left, the reply behind the comment marker), every window change (with a screenshot cropped to the window that changed) and your dictation (as the narration) are kept, in order.
- `vikix lesson stop`: `~/lessons/NAME/lesson.md`, numbered steps, screenshots beside it, in the shape the interactive sites and the guides use; the explainer agent tidies the prose and asks about the steps it can't explain.
- `vikix lesson play NAME`: the lesson performed on the desktop slowly, keys shown on the OSD, as "Show me how" (`IDEAS.md`) does for one question. A lesson is both a document and a demonstration.
- For Vikix's own guides: the explainer records the walk-through and writes the page from it, so a guide's screenshots are of the thing it describes.

Why only Vikix: the OSD, the command ring, dictation, the house transcript style and the evidence rule all exist; the recorder is the join.

First step: keys and commands only, no screenshots, into a Markdown file; see whether the draft is better than starting from nothing.

## 4. The desktop keeps your diary

The desktop is the one witness to your day, and today it forgets.

- `vikix day`: today as an Org file from what Vikix already records: projects opened (`vikix project`), commits made, files Esploro moved (its journal), agent sessions and the diffs they left (the snapshot history), documents read (the catalogue's "recent"), captures and renders (the music inbox), rules that fired, how long each project had the screen.
- Then the thing Vid asks of every session anyway: the Work Log entry and the Status Board's percentages written from the record, offered for a yes, never written on their own. The log stops depending on memory at the end of a long day.
- `vikix day --week` and `--for living-in-lambda` for the summaries; the agent reads the file to answer "what did I do on Tuesday".
- Private by construction: the file lives in `~/journal/`, in the backup, and the ledger (`DESIGN-security.md`) shows if anything ever reads it out.

Why only Vikix: the sources are all Vikix's own records, in files and SQLite; the day is a query.

First step: `vikix day` over projects, commits and the Esploro journal, printed to the terminal. If it is right about what the day was, the Work Log can trust it.

## 5. Desktop branches

Trying a configuration should be free.

- `vikix branch try-paper`: a snapshot, and from then on settings changes (theme, keys, rules, `user.lisp`) apply only in this branch; the bar shows the branch name in the quiet colour.
- Live in it for an hour or a week. `vikix keep` merges it into your settings; `vikix drop` discards it and the desktop is as before; `vikix branches` lists what you're trying and when it began.
- Two branches can be compared: `vikix branch diff try-paper main` shows the settings that differ, in words where possible ("Super+t opens a second terminal; theme paper").
- The snapshot repository (`yours.git`) is the store, so this is git branches over the files it already tracks; the new part is StumpWM loading from a branch and switching back without a logout.

Why only Vikix: the settings are already in a git repo with a live reload; most desktops have neither.

First step: a branch that holds only the theme and `user.lisp`, kept or dropped; see whether having it changes how often Vid tries things.

## 6. Windows that know why they exist

Every window carries its provenance: which project, which command, which agent, which link opened it.

- Set at creation: by `vikix project open` (the project), by a rule, by the agent (through the door, so a Firefox tab the agent opened is marked), by Esploro (the file), by a key (which one).
- Then: the window list grouped by purpose instead of by program; "close this project" closes exactly its windows; the overview on a strip labels columns by what they're for; "why is this window here?" (`IDEAS.md`, "Why did that happen?") has its answer by construction; the diary (4) knows which project had the screen.
- Stored as a property on the X window (so it survives StumpWM's reload) and in the rules' notes; nothing to configure.

Why only Vikix: `vikix project`, the rules and the agent's door are the places windows come from, and all three are Vikix's.

First step: the property and the grouped window list; see whether the grouping is what you reach for.

---

## Not yet written up

A line each, for the next session with Vid:

- **The desktop as a musical instrument** beyond the sketchpad: the bar's beat, keys as pads, is in `DESIGN-music.md`; what isn't is the other direction, the desktop's own events as sound: a quiet tick for a finished build, a chord for a passed test suite, so a long job can be heard from across the room.
- **Teach the agent your desktop by showing it**: record (3) a few minutes of how you work, and the apprentice (`IDEAS.md`) reads that instead of the shell history alone.
