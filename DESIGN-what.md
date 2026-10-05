# Vikix What — design

What is this? Any part of the running computer, explained at the depth you ask for: what this very thing is doing now, a few plain lines about its kind, then the chapter, the manual, the source.

Drafted 2026-10-05 with Vid, from idea 2 of `NOVEL.md` ("Every part of this computer has a chapter"). Phase 0 was built the same day (see Phasing); the books' half is not. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

The desktop is full of things with names: a battery field, a service, a port something listens on, a process using memory, a key. Explanations of all of them are on the machine too: Vikix's guides, 12,000 man pages, and, for a user who writes, their own books. Nothing joins the two. To learn what a thing is you leave it, think of a word for it, and search. `Super+?` (`vikix why`) already answers "what made that happen"; nothing answers "what is this".

## What it is

Point at a thing and press `Super+Alt+?`, or type `vikix what sshd`. A card opens:

```
  sshd, a service
  up 3 days · started by runit from /etc/sv/sshd/run
  listens on port 22, open to the network · 4 MB

  A service is a program the machine keeps running for you. Runit starts
  it at boot and starts it again when it dies.

  > Read the chapter: Services, in "Unix by Hand"        (your own book)
    The guide: How it fits together, From login to desktop
    The manual: sv(8)
    The source: /etc/sv/sshd/run
    Also: the process (pid 812) · the package openssh
```

Three depths in one place: the facts and the short paragraph on the card, the chapter one Enter away, the source last. ("Unix by Hand" is made up, as every book in this file and in the tests is.)

## What stays private (the rule the rest is built around)

Vikix is a public repository; a user's books may not be. Vid's are private (2026-10-05). So:

- **Vikix holds the mechanism and one table,** `config/what/`, whose targets are only Vikix's guides, man pages, Info manuals and files of the checkout. `tests/lint.sh` fails on any other target there.
- **The table that points at a user's chapters, and the paragraphs in their words, live with the books,** in a folder the user names in their own config. Vikix's code, tests, guides, commit messages and screenshots never carry a chapter's name, a section's name or a line of a book. Tests use an invented book.
- **A user's own documents are closed to agents** (`docs_search`, `docs_read`, any later `what` tool) unless the user opens a folder to them, a folder at a time. The local model may read them; nothing here sends them anywhere.
- **Nothing points at a published copy.** A chapter opens from the file on the machine or not at all.
- **What you pointed at is not written down.** A selection's text and a window's title are shown on the card and kept nowhere.

## How it is built

```
  the key ──► StumpWM says what is under the pointer (a bar field, else the window in front)
                    │  never waits: starts the script and returns
                    ▼
  bin/vikix-what ── kind + name ──► facts (from /proc, ss, xbps-query, the desktop)
                    │               tables (the user's, then Vikix's)
                    ▼
                  the card (rofi) ──► vikix docs open TARGET · Emacs · why
```

**Kinds.** A kind is a word, and a thing may have a name: `service sshd`, `port 22`, `process 812`, `package openssh`, `key s-t`, `window`, `file notes.org`, `command grep`, and the bar's fields by what they show (`battery`, `network`, `volume`, `bluetooth`, `memory`, `updates`, `backup`, `drive`, `workspace`, `clock`). New kinds need no code when they have no facts of their own: a table file is enough.

**Saying what "this" is.** In order: what the command line names (`vikix what port 4004`; a bare name is tried as a service, a process, a package, a command, a file, and the card lists every one that fits); the bar field under the pointer; the window in front. The bar part is small: every field becomes an area as volume and the network are now (`vikix-ml-clickable`), and the lookup is the one `vikix-ml-click-dispatcher` does for a click, the narrowest area holding the pointer. The key's command reads Lisp state only and starts the script; StumpWM's main thread never waits on a program.

**Facts**, a few lines a kind, read by `bin/vikix-what` (Python, as `vikix docs` is), each under a timeout, none needing root; a fact that can't be read is left out, never guessed:

| Kind | Facts |
|---|---|
| process | what started it (up to the service or the window), since when, memory, ports it listens on, its package, its window |
| port | who listens, and whether to this machine only or to the network |
| service | up or down and since when, its run file, whether it starts at boot |
| package | version, installed when, size, what needs it |
| window | program and process, workspace, tiled, floating or a strip's column, the rules that ran for it (`vikix-rules-why`) |
| key | what it runs, the file and line it is written at (the registry and `*vikix-key-sources*` have both), how often you press it (`vikix used`) |
| a bar field | what it shows now, which program fills it and how often |
| file | type, size, what opens it, whether the snapshots or a git repository cover it |

**The tables.** A folder, a file a kind: `service.md`, and `service-sshd.md` for one named thing, which falls back to `service.md`. A file is the short paragraph, then a line a depth:

```
A service is a program the machine keeps running for you. Runit starts
it at boot and starts it again when it dies.

chapter: unix-by-hand/ch09-services.md#what-keeps-it-running
guide:   vikix:how-it-works#From-login-to-desktop
manual:  man:sv(8)
see:     process
```

Vikix's folder is `config/what/` (no `chapter:` lines, ever). The user's are named in `~/.config/vikix/docs` (copied once, theirs): `what=FOLDER`. Both are read; the user's paragraph replaces Vikix's, the user's lines come first, Vikix's guide and manual lines stay. A file per kind because the paragraph is prose a person writes, and because a missing file is itself the answer to "what has no chapter yet".

**Your own documents in the catalogue.** `vikix docs` gets a source, `own`, from lines in the same config: `own=FOLDER` (and `agents=FOLDER` to open one to agents; none by default). Unlike the other sources it keeps a row a section, not a file, so a search and a table's target land on the section: `##` headings of Markdown (the anchor pandoc gives them), elements with an id in an HTML page. Opening is what `vikix docs open` does today (a page styled as the guide, in the docs browser, the other way in Emacs), at the anchor. The rendered copies stay in `~/.cache/vikix/docs/`, readable by the user alone.

**The card** is rofi with a message (as `vikix screens` and Esploro's versions menu are): the heading, the facts, the paragraph; then the rows, deepest explanation the user has first (their chapter, else the guide, else the manual), so Enter alone opens the best there is, and Ctrl+Enter opens it the other way. "Also" rows open the card of a neighbouring thing (a service's process, a process's package). The card never grows past six lines of facts and a paragraph of sixty words; `vikix what check` says which table file breaks that.

**The doors.**

- `Super+Alt+?`, in `registry.lisp`, and Super+m → Help. (`Super+?` is `vikix why`; by the key rule Super+Alt opens something else.)
- A row "What is this?" in what `vikix why` offers for a line: the key, the rule's window, the command.
- `vikix what [KIND] [NAME]`, `--json` for scripts.
- `vikix what gaps`: the kinds, and the named things on this machine (the services that run, the bar's fields), with what each has: a paragraph (yours, Vikix's, none), a chapter or none. A writing list drawn from the machine.
- `vikix what check`: every target in every table still leads somewhere (a heading renamed in a book is found here, not on the card).

## Goals

- From a thing on the screen to its explanation in one key, without thinking of a search word.
- The card is right about *this* thing: what it shows was read a moment ago.
- A user with no books gets a useful card from the guides and manuals; a user with books gets their own words first.
- The books' privacy holds by construction, and a test keeps it.

## Non-goals (this version)

- Explanations written by a model. The paragraph is a person's; the card may later offer "ask about this" with the facts, as a separate row.
- Anything inside a window's picture (a word in a PDF, an instruction in a disassembly): that needs the selection, or idea 9 of `NOVEL.md` ("Read any window").
- Hover. One key, pressed on purpose.
- A glossary editor: the tables are files.

## Requirements

### Must have (P0)

Shipped: see Phasing.

### Should have (P1)

1. The `own` source: sections as rows, opening at the anchor, closed to agents by default; `tests/docs.sh` with an invented book; `tests/mcp.sh` that an agent is refused it.
2. The user's tables (`what=`), `gaps`, and `check` over them (it covers Vikix's pages today).
3. The kinds port, service, file and command, each tried for a bare name as a process and a package are now.
4. The row in `vikix why`.

### Later (P2)

5. The selection as "this", when it is the window in front that owns it.
6. Counting what was asked for (the kind's name only, through `vikix-used-note`), so `gaps` lists the most asked first.
7. The palette (Super+Space: "what is …") and Esploro (a file's "What is this?").
8. A read-only `what` tool for agents: the kind, the facts, Vikix's own targets; never the user's.

## Decided with Vid, 2026-10-05

- The key is `Super+Alt+?`, with a row in `vikix why`; the command is `vikix what`.
- The card first; Enter opens the chapter.
- The short paragraphs of a user's table are written by the user, by hand, a kind each.
- A kind with no chapter falls back to the guide or the manual, and `gaps` lists it.
- The user's own documents are closed to agents unless switched on.
- The books are private: the rule above. Their half of this design is in the books' own repository.

## Open questions

Blocking:
- **What a user may read of a runit service without sudo.** (engineering) `supervise/` is root's on Void, so `sv status` may be refused. Measure; if so, "up since" comes from the process whose command is the run file's, and "starts at boot" from the link in `/var/service`.
- **Anchors.** (engineering) pandoc's ids for Markdown headings are stable for a given heading; a book built another way may give others. `check` catches a broken one, but pick one rule for what the anchor is and write it in the table's README.

Non-blocking:
- How many rows does a section each add for a shelf of books, and what does it do to a search's ranking? Measure on a real shelf, report here as counts only.
- Does `vikix debug`'s report carry anything of the tables or the catalogue? If it does, it must leave `own` out.
- When is the selection "this"? It can be old text from another window; hence P2 and the owner check.

## Phasing

**Shipped 2026-10-05: Phase 0.** Public only, no books: `vikix what` (`bin/vikix-what`), `what.lisp`, `Super+Alt+?`, and a page for each of 22 kinds in `config/what/` (the bar's sixteen fields, a field, a window, a workspace, a process, a package, a key). A card's facts for a process (how long, what started it or which service keeps it, memory, ports and whether the network reaches them, its program's package), a package, a window (workspace, how it is held, its process, a terminal's job, the rules that ran), a key (what it runs, whose, its file and line, how often pressed), and for the battery, memory, the clock and the network beyond what the bar shows. Things done differently from the plan above, or beside it:

- **A click on a field with no click of its own opens its card** (the battery, the clock, updates): the area needed a click function anyway. Volume, the network, Bluetooth and memory keep their own clicks.
- **In a terminal the card is printed**, with its explanations numbered; `--open N` opens one, `--card` is the menu the key shows, `--json` the data.
- **A bare name** is tried as a field, a key, a process and a package already (P1 item 8 had this); the card of a process offers its package and its parent as rows.
- **`vikix what KIND`** with no name is the page alone: what a process is.
- **The package of a file** is found by searching xbps's own lists of files as text: `xbps-query -o` takes three seconds, too long for a card.
- **The window's title in the bar** is a thing to point at too (StumpWM's own area for it).
- `vikix what check` exists for Vikix's pages, and `tests/lint.sh` runs it; `gaps` waits for the user's tables.

Now: live with it a week. Is the card right, and is the key pressed? (`vikix used` will say.)

**Phase 1:** P1. The books come in, on the user's side; the second half of this design, in the books' repository, starts then.

**Phase 2:** P2, by what the week showed.

## Risks

- **The wrong thing.** The pointer rests on the bar by chance and the user meant the window. The card's heading says what it took, and a row offers the window in front instead.
- **A wall of text.** The limits on the card, checked.
- **A slow fact** holding the card. Timeouts; the card comes without it.
- **A privacy slip** (a chapter's name in a test, a screenshot with a book open). The lint check on `config/what/`, invented books in tests, and this section for whoever works on it next.
- **Empty answers.** With no table file a kind shows facts and a search of the catalogue for its name; if that is most cards, Phase 0's table is too small.
