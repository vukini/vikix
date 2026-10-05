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

> 2026-10-05, the what session: worked out with Vid as `DESIGN-what.md`; not built. `Super+?` had gone to `vikix why` since this was written, so the key is `Super+Alt+?` and the command `vikix what`. A card comes first (what this very thing is doing now, a short paragraph), the chapter one Enter away. The books are private, so Vikix holds only the mechanism and a table to its own guides and man pages; the table to the books, and the paragraphs in Vid's words, live in the books' repository, and the user's own documents are closed to agents unless switched on. Two things learned: the catalogue doesn't read the books yet (the `repo` source takes a project's README, plans and `docs/` only), so an `own` source with a row a section is the larger half; and several of the chapters the examples above name are not written yet, which `vikix what gaps` is for.

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

> 2026-10-04, the diary session: built, as `vikix day` (`bin/vikix-day`, `day.lisp`; the README's Projects section says what it reads). In: the day as `~/journal/DATE.org` with Notes kept, how long each project had the screen (the desktop notes what is in front every 30 seconds, never a title), entries, commits, Esploro's changes, agents' sessions and the settings changed after each, updates, rules that ran, documents opened, the plugins' records; `--week`, `--for NAME`; `vikix day log` offering the missing log entries for a yes, with the next step and the percentage asked, not guessed. Not in: the music inbox's captures (not built yet), the ledger's view of who read the journal (`DESIGN-security.md`), and time for a project whose windows are neither on its workspace nor in its folder (an Emacs frame on another workspace, a browser tab), which idea 6 would give.

> 2026-10-05, exploring with Vid (not yet a TODO): the diary's next phase. **The browser as a source**: Firefox's `places.sqlite` (copied; it's locked while Firefox runs) and Nyxt's history, so the day says what was read, not only "Firefox on workspace 2". Titles for everything by default (the file is the user's alone), with the deny side doing the work: a private list of domains shipped with the obvious categories (banks, webmail, health, dating, adult, the password manager, payment pages), `vikix day private DOMAIN` to add one, nothing from those appears, not even the domain; a few patterns (`login`, `account`, `statement`, `invoice`, `checkout`, `unsubscribe`, `reset`, a long token in the path) drop a page to its domain alone; search queries and URLs never kept, domain and title only; `vikix day forget DOMAIN` also removes it from every past day's file, so a mistake isn't permanent. An allow-list of domains for titles was considered and dropped as too restrictive. **A summary paragraph** at the top, written by the local model from the structured records, a cloud model only when asked and the file saying which wrote it. **A night run and a morning report**: `(at "03:00" (run "vikix day yesterday"))` in the rules, the paragraph as `vikix welcome`'s first card and a quiet notification at a later login; the file reaching the other machines over Syncthing when that lands. **Files changed outside Esploro and git**: a nightly `find` over a folder list, caches and the browser profile excluded, names only for folders the user lists.

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

## The Z13 (touch, pen, a keyboard that comes off)

A tablet mode for a tiling desktop is open ground: the tiling desktops ignore touch, and the touch desktops aren't tiling. The Z13 (TODO 58–63) makes it Vid's problem to solve, and Vikix has the parts. Checked in Void 2026-10-04: `iio-sensor-proxy` 3.9 (rotation), `touchegg` 2.0.17 and `libinput-gestures` 2.81 (gestures on X), `onboard` 1.4.4 (an on-screen keyboard), `xournalpp` 1.3.4 (pen on PDFs), `gromit-mpx` 1.9.0 (drawing on the screen).

## 12. Take the keyboard off and the desktop becomes a strip

Detaching the keyboard is a statement of intent, and the desktop should hear it.

- A rule, `when-keyboard-detached`: the current workspace becomes a Viri strip (`DESIGN-viri.md`) with one column per screen, panned with two fingers; tap focuses; a long press on a window opens the window's menu (close, move, hand to another machine); the bar grows to finger height; notifications wait. Reattach, and the tiles come back as they were.
- The key card becomes a touch card: `Super+/`'s groups as tappable tiles, so every key still exists without a key. The `onboard` keyboard appears only when a text field has the focus, as a column of its own at the strip's right edge, never over the window you're typing into.
- A workspace switch is a three-finger swipe; the overview is a pinch. Each gesture is one entry in a table beside `*vikix-bindings*`, so the key card can print "or swipe left" beside "Super+l".

Why only Vikix: the strip exists, the rules exist, the key tables are data; a tablet mode is a rule and a table, not a second desktop.

First step: the rule and the strip alone, no gestures: detach, strip; attach, tiles. Live with it on the Z13 for a week.

## 13. Draw a letter, press a key

The pen and the finger get the key card for free: draw an `e` anywhere and Esploro opens, as Super+e does.

- The rule for keys (`keys.lisp`: Super everyday, Super+Shift moves, Super+Alt opens something else, Super+Ctrl switches) maps onto strokes: a letter is Super+letter; a letter with a line under it is Super+Shift; a circled letter is Super+Alt; a letter with a dot is Super+Ctrl. Nothing to learn twice: the key card is the gesture card.
- Drawn on the screen with the pen or a finger while a corner is held (so ordinary drawing in an app isn't a command), recognised by a small template matcher in Lisp (the strokes are few and simple; no model needed), shown on the OSD as the key it became.
- The same strokes on the touch card (12) and on the lock screen's drawing area for a pattern unlock, if wanted.

Why only Vikix: one rule for keys means one rule for strokes; a desktop with ad hoc bindings couldn't do this.

First step: three letters (`e`, `t`, `w`) with the pen, in a hidden StumpWM on Xvfb with synthetic strokes, then on the Z13.

## 14. Hold it like a book

Turn the Z13 on its side and it is an e-reader for your own drafts.

- Rotation (iio-sensor-proxy) into portrait becomes a rule, `when-portrait`: the bar hides, the strip turns vertical (columns become rows), the theme warms (the nightlight's colours), notifications wait, and the focused document fills the screen: a PDF in `xournalpp` so the pen writes in the margin, an EPUB in Foliate, Markdown rendered by the guide's CSS.
- Tap at the edges turns pages; the pen's margin notes are saved beside the file (`chapter-3.md.notes.xopp`) and listed by Esploro's "Versions…" neighbour, "Notes…"; `vikix publish check` can list the pages with notes still unresolved.
- This is the proofreading posture for the Living Series: build the EPUB (`DESIGN-publish.md`), pick up the Z13, read it as a reader would, mark it with the pen, put it down, and the marks are in the project.

Why only Vikix: the publish pipeline, the strip, the rules and Esploro meet here; an e-reader app can't know what a project is.

First step: the `when-portrait` rule hiding the bar and opening the focused PDF full-screen in xournalpp; the rest follows if that posture is used.

## 15. The big laptop serves the small ones

When the Z13 is on power and on the tailnet, its 128 GB is everyone's.

- `vikix ai serve` as a rule, `when-charging` and `when-on-network home`: Ollama listens on the Tailscale address, and the X1, the office and the phones' Hermes gateway find it by name; off power or off the network, it stops, and the others fall back to what they had (`vikix ai use` keeps a list, first available wins).
- The bar on the Z13 shows who is using it ("serving: x1, phone"), in the quiet colour; the ledger (`DESIGN-security.md`) shows what was asked, never the text.
- The office machine (`ai-desktop.md`) is the same rule with `always`; the design is one and the hardware decides.

Why only Vikix: the rules know power and network, the machines design gives the names, and `vikix ai use` already abstracts where the model is.

First step: `vikix ai serve on|off` by hand between the Z13 and the X1 over the tailnet; then the rule.

## 16. Tabs are windows

The browser stops being a window with tabs inside and becomes part of the desktop: each page is a window StumpWM arranges.

- Nyxt is written in Lisp and can run each buffer in its own X window; StumpWM is written in Lisp and arranges windows. Join them and a page is tiled beside Emacs, two pages sit side by side without a split-screen extension, a page lives on a project's workspace with the project's files, and a strip (Viri) scrolls through your reading the way it scrolls through everything else.
- The things browsers reinvented badly come back as desktop things: the window list is the tab list; `Super+g` finds a page by title; "close this project" closes its pages; a rule puts documentation pages on the right and the thing you're building on the left; the agent opens a page the way it opens a terminal.
- Firefox stays for what Nyxt can't render; a key sends the current page across. The docs catalogue's pages (`vikix docs`) open this way already, as `vikix:` pages in Nyxt.

Why only Vikix: the browser and the window manager are the same language on the same machine, and Nyxt's buffer-per-window is a setting, not a rewrite.

First step: Nyxt with one window per buffer on a strip, for a day of reading. If pages as columns feel right, the rest is rules and keys.

## 17. Personas

One desktop, two companies, nothing leaking between them.

- `vikix persona centaur`: the accent colour, the web apps' profiles (each already has its own, `~/.local/share/vikix/webapps/NAME`), the browser's container, the mail account the desk (TODO 21) reads, the projects `vikix project` lists first, the folders Esploro opens by default, the notes file capture goes to, even the agent's guide (which company's files it may read). `vikix persona link`, and all of it changes; `vikix persona home` for the evening.
- Not accounts, not logins: one user, one home, with the rules language choosing what is in front of you. A persona is a file of settings a rule applies; `when-workspace` and `at` can switch personas (the Link workspace is Link's; nine o'clock is work).
- The bar names the persona in the quiet colour, so a screenshot sent to the wrong company is caught by the eye.

Why only Vikix: the web apps already have separate profiles, the rules switch things on the desktop, and the desk is designed to keep companies apart; a persona is the word for doing all of that at once.

First step: a persona that changes the accent colour and the web apps shown in Super+m; see whether having the word makes the switching happen.

## 18. Rules you can send

A key, a rule or a layout as a card you hand to someone.

- `vikix share rule firefox-right`: a QR code on the screen (or a short file) holding the rule's text, its one-line description and who made it. Another Vikix scans it (the phone, or the webcam, or the file) and Esploro's review panel shows the rule as text with Apply and Cancel; it lands in `~/.stumpwm.d/rules.lisp` with a comment naming the giver. Snapshot first, undo after.
- The same for a key, a theme, a web app, a saved layout, a music pattern (`DESIGN-music.md`), a Cuis package.
- Because the card is the rule's text and the receiver reads it before applying, this is sharing without a store: no registry, no accounts, no trust in a server. The plugins repo stays for code; cards are for the small things people make for themselves.
- A classroom of Vikix machines (should the children's account ever return) is a teacher showing a card.

Why only Vikix: settings are small readable Lisp forms, and the review panel that shows a plan before applying it already exists.

First step: `vikix share` and `vikix take` for a rule, through a file; the QR after.

## 19. The terminal remembers

Every command's output is a thing you can point at afterwards.

- With `bash-preexec` and atuin already seeing each command, Vikix keeps each command's output (bounded, say the last hundred commands or 50 MB) in the record store, with the command, the folder, the time, the exit status and the project. Then: `vikix last` prints the previous output; `vikix last | esploro` opens the files it named; `Super+i` on a terminal offers "explain the last error" with the real output, not a guess; the agent reads `vikix last --json` instead of asking you to paste; the diary (4) knows what the shell did.
- In the terminal, a key (the same `Super+?` of "why did that happen?") on a line of output shows which command made it and when.
- Outputs are private records: in `records.db`, 600, never in the backup unless asked, never sent anywhere; the ledger shows if the agent read one.

Why only Vikix: the hooks, the record store and the agent's door exist; the terminal is the last part of the desktop that forgets.

First step: keep the last twenty outputs and `vikix last`; see how often it's reached for.

## 20. Every fix becomes a check

When you fix something by hand, the desktop offers to remember how to notice it next time.

- You edit a config to fix a problem (the Wi-Fi driver option, the printer's URL, a font that wasn't picked up). The snapshot history sees the change; the apprentice (`IDEAS.md`) asks, once, "this fixed something; should `vikix doctor` check for it?" and proposes the check as a line in `~/.config/vikix/doctor.d/`: what to look at, what it should say, what to do if it doesn't.
- `vikix doctor` grows with the machine: the checks that matter to this laptop, written at the moment the knowledge was fresh, instead of a fixed list for every machine.
- The developers' rule in `CLAUDE.md` ("a new kind of breakage found by hand should become a check in the matching test") becomes a user's habit, with the desktop doing the writing.
- A check can be shared as a card (18), which is how a fix for one ThinkPad reaches the next.

Why only Vikix: the snapshot history shows every change to your settings, `vikix doctor` is the place checks live, and the agent can write the check from the diff.

First step: a user `doctor.d/` folder that `vikix doctor` reads; the offer after.

## 21. The margin

Every workspace has a margin to write in, the way a book does.

- A thin column at the right edge of any workspace (or the end of a strip), summoned by a key and gone with it: a place for the sentence that occurs to you while doing something else. Not a notes app; a margin. What you write there carries the provenance of what you were looking at (6): the file, the page, the project, the window.
- At the end of the day the diary (4) gathers the margin into `~/journal/`, each note beside what it was written against. The inbox plugin captures to a box; the margin captures to the place.
- For a writer: `vikix margin week` is the raw material of the Substack post, in order, with the things it was about linked; the agent drafts from it only when asked.
- For a reader: a margin note on a page of the docs catalogue or an EPUB stays with the page, so the book you're proofreading (14) and the manual you're learning both carry your marks.

Why only Vikix: the strip has an edge to put it on, provenance tells it what it is about, and the diary knows where to gather it.

First step: the column, a key, one file per day; provenance later.

## 22. An office for agents

Several agents on one desktop, and the desktop as their manager.

- Vid runs several Claude sessions at once, and other agents beside them. Today they share the desktop by luck. Vikix can run the office: each agent gets a workspace of its own, a colour in the bar, its windows marked with its name (6), and a rule that it may not touch another agent's windows or files without the snapshot journal recording the crossing.
- `vikix agents`: who is running, on what, since when, how many files each has changed (from the snapshots), which is waiting for a yes (the `agent-waiting` plugin already knows). `vikix agents stop NAME`, `vikix agents hand NAME z13` (7).
- The door module (`DESIGN-security.md`) gives each agent its own audit line and its own allow-list; a cheaper model gets a shorter list.
- When two agents want the same file, the second is told, and the journal shows both plans side by side for you to choose, as Esploro's review panel does for one.

Why only Vikix: it starts the agents, keeps the journal, owns the workspaces and holds the door; no other desktop knows an agent from a terminal.

First step: a workspace and a bar colour per `vikix agent`, and `vikix agents` listing them; the rules after.

> 2026-10-05, the office session: the first step is built, a little differently. `vikix agents` (and Super+m, AI; the MCP tool `agents`) lists every agent in a terminal here, found from the terminal's processes whether `vikix agent` started it or a shell did: its folder with branch and uncommitted files, workspace, how long, and what it is doing (the agent-waiting note, else Claude Code's mark in the title); its window carries `_VIKIX_AGENT`. Not yet: a workspace and a bar colour each. What the listing showed at once: every session's folder is `~`, because Super+a starts them there and each then works in a worktree it made itself. So the next step is a desk each, `vikix agent` starting an agent in a project and a worktree of its own, before the house rules.

> 2026-10-05, later: the second step, a desk each, is built. `vikix agents desk PROJECT TOPIC` (Super+m, AI) gives an agent the first empty workspace and a git worktree of the project, `PROJECT-TOPIC` beside it on the branch `TOPIC`; Super+a is unchanged. No key (the key card is full), no bar colour yet, and nothing removes a desk but `git worktree remove`. Next: the house rules (two agents reaching for one file; crossings into another's folder).

## 23. Feed the distro

What Vikix builds because Void lacks it goes back to Void.

- Vikix builds StumpWM, PicoLisp, Lazarus's docked IDE, and will pin epubcheck, Cuis and others, each with a version, a URL and a checksum already in the repo. `vikix pkg propose NAME` turns that pin into a void-packages template (the `srcpkgs/NAME/template` file in Void's own shape: version, distfiles, checksum, build style guessed from the build script) and a draft pull request, with the test build in a clean container as Void's `xbps-src` does it.
- Over time, things Vikix had to build from source become `xbps-install` lines, for every Void user; and Vikix's own install gets simpler. The desktop that depends on its distro contributes to it by construction.
- The same path for the hunspell dictionaries, the fonts and the tessdata languages.

Why only Vikix: the pins are already data in one place, and Void's package format is a short template; the translation is mechanical.

First step: `vikix pkg propose picolisp`, by hand to a PR, to learn what the template needs; then the generator.

## 24. Hear the desktop

The desktop usable with your eyes elsewhere.

- One key: the bar read aloud by the local voice ("two updates; the backup is nine days old; Firefox on workspace two; it's twenty past nine"). Another: the key card read for the group you name. Notifications spoken at your choice, in the quiet voice for the quiet ones.
- With voice commands (`IDEAS.md`) this is a desktop you can drive with the lid closed or from across the room, and a desktop a person who can't see the screen well can use, which Linux tiling desktops have never been.
- In the language of idea 1 at your level, which makes it a listening exercise too.
- Only local voices (piper, from its release, as TODO 25 already plans); nothing spoken ever leaves the machine.

Why only Vikix: the bar's state is data in Lisp, the voice keys exist, and `vikix theme`'s one-file approach extends to one voice file.

First step: `vikix say bar`, from the bar's Lisp state through piper; a key after.

*2026-10-04: set aside by Vid ("like them all except talking desktop"). Kept here as the file's rule says; not to be picked up unless he changes his mind. The spoken parts of idea 1 and the Esperanto partner below are a different thing (a tutor that talks, not a desktop that does) and stand.*

## 25. Notes on things

A note left on a key, a program, a file or a device, that reappears when you next touch it.

- `vikix note "lift the tray first" --on printer`; next time you print, the note is in Super+m's printing entry and on the OSD. `--on Super+F9` shows when you press it; `--on ~/src/vikix` when a terminal opens there; `--on z13` when you hand a window to it. Notes to your future self, anchored where your future self will be.
- A note is a record (plugin `notes`, kind `on`, key the thing), so the agent can read it (`records_search`), the diary can list the notes you wrote, and a card (18) can carry one to another machine.
- Vikix's own guides could leave the first notes: the one about the Lazarus build, the one about the lock screen in the VM.

Why only Vikix: the things a note can be anchored to (keys, commands, projects, machines) are all named objects in Vikix, and the record store is already there to hold them.

First step: `vikix note --on COMMAND`, shown by `vikix COMMAND -h` and in Super+m; the other anchors after.

---

## Not yet written up

A line each, for the next session with Vid:

- **The desktop as a musical instrument** beyond the sketchpad: the bar's beat, keys as pads, is in `DESIGN-music.md`; what isn't is the other direction, the desktop's own events as sound: a quiet tick for a finished build, a chord for a passed test suite, so a long job can be heard from across the room.
- **Draw a rhythm.** The music sketchpad's codeless face (`DESIGN-music.md`, `DESIGN-cuis.md`) could take ink on the Z13: a stroke per hit, a longer stroke a longer note, the row redrawn as cells; the pen as the first instrument.
- **Vikix in the browser.** The site's sketch of the desktop could be the real thing: Void in v86 (x86 in WebAssembly) with Vikix installed, slow but true, so "try it without installing" is a click. Measure first whether StumpWM on v86 is bearable.
- **A conversation partner in Esperanto.** Idea 1 plus the voice keys: a daily few minutes of spoken Esperanto with the local model at your level, the desktop as the patient speaker every learner lacks (Vid's own conversation skill is the model for how it talks).
- **Teach the agent your desktop by showing it**: record (3) a few minutes of how you work, and the apprentice (`IDEAS.md`) reads that instead of the shell history alone.
