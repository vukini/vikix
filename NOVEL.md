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

## 7. Hand a window to another machine

A running program moves from this laptop to that one without closing.

- `vikix hand firefox z13`: the Firefox you have open, with its tabs and its form half filled, leaves the X1's screen and appears on the Z13's, still running where it was. `vikix hand --back`.
- The trick is old and unused: xpra (6.4.4 in Void) can detach a program from one display and attach it to another; nobody has made it a desktop verb. Over the tailnet (`DESIGN-machines.md`) the other machine is a name.
- Programs started by Vikix (Super+Return, the launcher, `vikix project open`) run under xpra's seamless mode from the start when the feature is on, so any of them can be handed; a program started otherwise is told it can't, with the reason.
- Uses: the terminal you were in when you left the desk; the agent's session moved to the office machine with the big models while it keeps its state; a child's program handed to the parent's screen to look at.

Why only Vikix: Vikix starts the programs, so it can start them handable; it knows the machines by name; and it has the door to tell the other side to take the window.

First step: hand one terminal between the X1 and the VM, and measure what xpra costs in latency and memory when it is just sitting there.

## 8. Vikix in your pocket

Your desktop on a USB stick, bootable on any PC, with your settings and without your secrets.

- `vikix stick /dev/sdX`: writes Void's live image with Vikix already installed (the base and the features you name), your `vikix export` applied (theme, keys, rules, web apps, projects list), and a persistence partition, so the stick remembers what you do on it. Encrypted persistence with a passphrase, so a lost stick is a lost stick.
- On any x86-64 machine with a USB port, hold the boot key and you are at your own desk: your Super+m, your theme, `vikix project` with your repos cloned on first use. The local AI models are too big for a stick; `vikix ai use` points at the office over the tailnet, or Claude.
- Also the way to try Vikix without touching a disk, which the site currently answers with "a virtual machine": a stick is the answer for people who don't know what a VM is. TODO 20 (an installer image) becomes a mode of the same tool: the stick can install itself to the machine's disk.

Why only Vikix: `vikix export` and the feature lists already describe a machine as data; the stick is that data plus Void's live tooling (`void-mklive`, built from source as Void does it).

First step: a stick with the base alone, no persistence, booted on one machine that isn't yours.

## 9. Read any window

Point at a window in a language you don't read and read it in yours.

- `Super+Alt+r` on a window: its text is read from the pixels (tesseract 5.5, in Void; the language data fetched per language as `vikix docs get` fetches docsets), translated by the local model, and shown as an overlay in the same places, in the Vikix font; `Esc` takes it away. Nothing leaves the machine.
- The other direction for a learner: a window you can read, shown in the language you're learning, with the original on hover. This is the sibling of idea 1 for programs Vikix doesn't control: a web page, a PDF, the Windows VM's Excel.
- Living in the UAE, this is an everyday tool (a form, a notice, a message); for the books, it is a way to check a translation against the page.

Why only Vikix: the local model, the overlay (the OSD already draws on any window), and the language work from idea 1 are all there; the join is an afternoon once tesseract's data is installed.

First step: OCR one window into a text buffer in Emacs, no overlay; see whether the recognition is good enough on the screen's fonts to be worth the rest.

## 10. Rehearse a change

Any change to the machine itself can be tried on a copy first and shown as a diff.

- `vikix rehearse vikix add music`: the command runs in a throwaway copy of this machine (the VM from a fresh snapshot, with your settings applied, or a bubblewrap copy of your home for changes that stay in it), and what comes back is not output but a diff: packages that would be installed, services linked, files written, keys bound, ports opened, with sizes and times. Then "do it for real" or not.
- `DRY_RUN` already prints what a stage would do; this executes it where it can't hurt and reports what it actually did, which catches what a dry run can't (a package pulling in Qt, an installer touching `~/.bashrc`).
- The agent proposes changes through the same door: an agent's "I'd like to run `vikix add tailscale`" becomes a rehearsal and a diff for your yes, which is Esploro's plan-then-apply for the whole machine.
- Snapshots do this for your files after the fact; rehearsal does it for the system before.

Why only Vikix: every system change already goes through `run` in `lib/common.sh`, the VM and its guest agent exist, and the file ownership rule means the diff is readable.

First step: `vikix rehearse` for `vikix add NAME` alone, in the VM, printing the package and file diff.

## 11. What's new, for you

Every update tells you what changed in your desktop, in your words, and only what touches you.

- After `vikix update`, a card: "Super+g now lists windows with their folders. Esploro opens archives like folders. Your theme gained a high-contrast variant." Three lines, from the release notes, filtered by the features you have and the keys you use (the apprentice's counts), with "show me" on each line running the lesson player (idea 3) or opening the guide page.
- Read aloud on request, in the language of idea 1 at your level.
- The release notes are written already (every `Vikix X.Y.Z:` commit); the new part is tagging each note with the feature and the keys it concerns, which `lib/man.py` and the key tables can mostly do by reading it.

Why only Vikix: one repo holds the releases, the features list, the key tables and the guide, so "what changed for you" is a query over things that exist.

First step: the card from the commit messages since the last update, unfiltered; then the filter.

---

## Not yet written up

A line each, for the next session with Vid:

- **The desktop as a musical instrument** beyond the sketchpad: the bar's beat, keys as pads, is in `DESIGN-music.md`; what isn't is the other direction, the desktop's own events as sound: a quiet tick for a finished build, a chord for a passed test suite, so a long job can be heard from across the room.
- **Teach the agent your desktop by showing it**: record (3) a few minutes of how you work, and the apprentice (`IDEAS.md`) reads that instead of the shell history alone.
