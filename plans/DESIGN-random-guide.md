# A guide page at random — design

One command that opens one of Vikix's own guides, picked at random, the way `vikix docs` opens it: `vikix docs random`, and Super+m → Help → *Vikix guide: a page at random*.

Drafted 2026-10-11 by a Claude session at a desk, for another provider to build. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

The guides in `docs/` are read when something is wrong or when a page is looked for. Nobody reads *customize* or *rules* for its own sake, so what Vikix can do stays unknown until it is needed. A page at random, a key press away, is the cheap way to find out: open one with the coffee, close it or read it.

## What it is

- **`vikix docs random [--other]`**: picks one of the guides and opens it as `vikix docs open` would, then prints the page's title (so a shell, the palette and the test know which). `--other` opens it the other way, in Emacs, as `open --other` does for a Markdown file.
- **A menu entry** in Help, beside *Vikix guide* and *Vikix guide in the browser*.

That is all. No key, no new program, no new state worth a guide of its own.

## Where it lives

**The work is in `bin/vikix-docs`**, a `random` arm of `main` and one function, `random_guide(other=False)`. The guide catalogue already knows the guides (`files_vikix`), how to open one (`open_doc`: the built web page by `guide_page`, else a page made from the Markdown by `md_html`, in the docs browser through `docs_open`; `--other` through `emacs`) and how to note it for `vikix day` (`note_opened`). The new function does nothing the catalogue doesn't already do: it makes the pick, builds the row `open_doc` wants (`id` as `index_files` writes it, `vikix:PATH`; `source` `vikix`; `kind` `guide`; `title` from `md_title`; `path`), and calls `open_doc`. It reads the files on disk, not the catalogue's table, so it works before the first index and the test needs none.

**The command is one entry in `registry.lisp`**, written after `guide-browser` so Help keeps the three guide entries together:

```lisp
(define-vikix-command guide-random "A page of the Vikix guide at random: something you didn't know it does"
  :run "exec vikix-docs random"
  :menu "Help" :label "Vikix guide: a page at random")
```

No `:key` (below), no `:agent` (it starts a program), no `:needs` (the guides are in every checkout, and the page is made from the Markdown when the built copy isn't there).

The header of `bin/vikix-docs` gets its line, between `open` and `read`:

```
  vikix docs random [--other]    one of Vikix's guides at random, as open
                                  opens it; every page once before any twice
```

and `python3 lib/man.py --guide > docs/commands.md` is run after it (the man page, `-h` and the commands guide come from the header; `tests/man.sh` fails otherwise).

## Which pages count, and how the pick is made

**The pages:** the guides `vikix docs` catalogues as source `vikix`, kind `guide`: every `docs/*.md` of the checkout except `README.md` (the table of the guides: a list, not a page to land on), and less `commands.md` (the reference made from the headers, which nobody reads at random). The main `README.md` (kind `readme`) is out too. So today: sixteen pages, from *Installing from Vikix's stick* to *When something breaks*; a guide added to `docs/` joins when the next round is filled, with no change here.

**The pick is a deck, not a die.** A plain `random.choice` shows the same page twice in three presses often enough to feel broken with sixteen cards. So: `~/.local/state/vikix/docs/random-deck` (`VIKIX_STATE` honoured, as `note_opened` does) holds the names of the pages not yet shown this round, one a line, as `NAME.md` (relative to `docs/`, so a moved checkout keeps its deck). A press takes one at random from the deck, writes the rest back; an empty or missing deck is filled with every page first, and a name in the deck that no longer exists on disk is dropped as it comes up. Every page is shown once before any is shown twice; the order inside a round is random. The file is the user's (600, as the day log), never a reason to fail: an unwritable state folder means a plain random pick that round.

## How the page opens

**`vikix docs`' road, nothing else.** The built web page (`~/.local/share/vikix/guide/NAME.html`, found by `guide_page`) in the docs browser, with the diagrams drawn; when the built copy isn't there (a checkout that hasn't run `40-config`), the page `md_html` makes from the Markdown, styled as the guide. `--other` opens the Markdown in Emacs. The Info manual is not used: the same text, without the diagrams, and `open_doc` doesn't open a guide that way either, so a second road would be a second thing to keep right. The opened page is noted in `~/.local/state/vikix/day/docs.log` as any opened document is, so `vikix day` lists it.

## Key or menu entry

**A Super+m entry only.** By the rule for keys (`keys.lisp`, `docs/customize.md`) it would be a Super key, the everyday ones, where `vikix-docs` already stands (`*vikix-key-everyday*`, for Super+F2); but a page at random is not an everyday act, and the key card has no line left at 32 rows (the same reason the desks have no key). The entry is reached by typing a word of it at Super+m (*random* finds it from the top) and by the palette's `>` search, which is a key press and a word, enough for a thing done once a day.

## What the test checks

A section of `tests/docs.sh` (the test `bin/vikix-docs` maps to in `tests/changed.sh`; the registry change runs `menu`, `registry` and `lisp` by the same map), in the made-up home it already has, with its stand-ins for the browser (`VIKIX_DOCS_OPEN`) and Emacs:

1. `vikix docs random` opens, through the stand-in, an HTML page (the cached one `md_html` makes, since the test home has no built guide) and prints a title that is one of the guides' titles (`md_title` of a `docs/*.md`).
2. The page is never `README.md`, `commands.md` or the main README, over a whole round.
3. The deck: run as many times as there are pages, every page is opened exactly once (the stand-in's log, one line a run, each guide's cached page once); one more run starts a round (the deck file was empty, is full again less one).
4. `--other` opens the Markdown in the Emacs stand-in, nothing in the browser's.
5. `docs.log` in the test's state gets a line with the id `vikix:PATH`.
6. A deck holding a name that isn't on disk is dropped, the run still opens a page.
7. `VIKIX_STATE` pointing at a folder that can't be written: a page still opens, exit 0.

Without a screen; it needs no desktop and no index, like the rest of that test. `tests/registry.sh` and `tests/menu.sh` cover the entry as they cover every command (the menu's Help section, in order).

## The guides to update, in the same commit

- `bin/vikix-docs`'s header (the usage line and a sentence in the prose: "a page at random, every one before any twice") and then `docs/commands.md`, made from it.
- `docs/README.md`: the second paragraph (the three forms the guides come in) gets the sentence "`Super+m` → *Vikix guide: a page at random* opens one of them you didn't choose".
- `docs/first-hour.md`, the *The guides* bullet: the menu entry named beside *Vikix guide*.
- `README.md`, *Finding a document* (`vikix docs`, Super+F2): `vikix docs random` in the example block, with its line.
- `config/claude/skills/vikix/system.md`, the docs line: `vikix docs random` after `find`. The first page gains no rule: nothing here guards a secret or the desktop.

`lib/skill-keys.sh --write` has nothing to change (no key, no agent command), and the site gains nothing a visitor would see.

## Decided, 2026-10-11

- Review clarification, 2026-10-11: newly added guides join the next round, not a round already in progress. The deck keeps only the names still to be drawn; it does not track a separate catalogue of previously seen pages.

- `vikix docs random`, not a command of its own: it is the catalogue's opener with a pick in front, and `vikix docs` already has every road.
- A deck in a state file, every page once before any twice; not a plain random pick, and not "not the last one".
- The browser page through `open_doc`, the Info manual not used; `--other` is Emacs, as everywhere in `vikix docs`.
- `commands.md` out of the deck; `install-stick.md` and `install-void.md` in (a page one reads too late is still a page worth knowing).
- No key: a menu entry in Help, found by typing; the card is full.
- The test is a section of `tests/docs.sh`, not a test of its own: it shares that test's home and stand-ins.

## Non-goals

- A page of a plugin's guide, a man page or a note at random: the deck would need a source and a size, and the point is Vikix's own pages. `vikix docs random --source S` can come later if anyone asks.
- A notification at login with a page ("did you know"): the `at-login` rule a user may write, `(at-login (run "vikix docs random"))`, does that with no code here.
