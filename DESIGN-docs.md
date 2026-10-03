# Vikix Docs — design

Every document on the machine in one catalogue, found from one key, read in one place.

Drafted 2026-10-03 with Vid. Like Esploro's and the music design, this is kept honest by deleting what ships and dating what changes.

---

## The problem

A Vikix laptop holds thousands of documents and no way to see them together:

- Vikix's own guide, as Info pages and HTML
- the READMEs, DESIGN.md, TODO.md and `docs/` of every repo in `~/src`
- the language guides in `~/dev/<lang>`
- the man pages and Info manuals of every installed program
- `/usr/share/doc/<package>`, and the one-line descriptions xbps keeps
- the Zeal docsets for twenty languages
- the user's own notes

Each has its own door, and three of the seven open only in a terminal, so an ordinary user never sees them at all. Someone who wants to know how to switch a service off has to know, first, that the answer is in `man sv`, which is the thing they didn't know.

## Who it is for

- **The newcomer**, who doesn't know `man` exists and shouldn't need to.
- **Vid**, with about thirty repos whose design notes he loses track of.
- **The agent**, which today answers from memory when the right man page is on the disk beside it.

## Goals

1. **One search over everything.** A word typed on one key finds hits across all seven sources in under 100 ms, offline.
2. **Everything reads in one place.** A man page, an Info node, a README and a guide page all open as styled pages in the docs browser (Nyxt, or the default browser), in Vikix's theme. The terminal stays available for those who want it.
3. **Nothing goes stale.** Package docs reindex when packages change; the user's folders reindex within a day on their own, and within seconds on demand.
4. **The agent reads the manual.** A `docs_search` tool returns the same hits a person sees, with the text to read.
5. **Yours ranks first.** Vikix's guide, then your repos, then the system; a hit always shows whose words it is.

## Non-goals (this version)

- **Not a web search.** Only what is on the machine. The web has its own tools.
- **Not a new notes app.** Notes stay `note`'s; this catalogue reads its index, it doesn't replace it.
- **Not a rewrite of Zeal.** Docsets are read in place through their own `docSet.dsidx`; nothing is copied.
- **Not a web crawler.** Package websites are listed as links, never fetched or indexed; the catalogue is offline and says plainly which hits leave the machine.
- **Not OCR.** PDFs are indexed by the text they carry; scanned PDFs with no text layer are listed by name only (OCR is a later adapter, with tesseract, which Void has).
- **No daemon watching the whole disk.** Reindexing is triggered by the events that change things, and a daily sweep; one optional `inotifywait` on `~/src`.

## How it is built

```
  sources ──adapters──►  index.db (SQLite)  ──►  doors
                          ├ docs       (one row per document)
                          ├ docs_fts   (FTS5: words, instant)
                          └ docs_vec   (sqlite-vec: embeddings, optional)
```

One SQLite file, `~/.local/share/vikix/docs/index.db`, extending what `lib/notes.py` already does. One row per document:

| column | meaning |
|---|---|
| `id` | stable: `source:path` |
| `source` | `vikix`, `repo`, `dev`, `man`, `info`, `pkgdoc`, `pkg`, `zeal`, `note` |
| `title` | as shown in a hit |
| `kind` | `guide`, `readme`, `design`, `man`, `info`, `changelog`, `description`, `api`, `note` |
| `path` | file, or `man:sv(8)`, `info:(stumpwm)Top`, `zeal:python:str.split` |
| `open` | how to open: `nyxt`, `emacs`, `terminal`, `zeal` |
| `excerpt` | first 300 characters of body |
| `mtime` | for incremental reindexing |
| `body` | in `docs_fts` only |

**Adapters**, one function each in `lib/docs/`, all returning rows of that shape:

| Source | Reads | Opens as |
|---|---|---|
| `vikix` | `docs/*.md` in the checkout | the built HTML page in Nyxt; Emacs for the Markdown |
| `repo` | `~/src/*/{README,DESIGN,TODO,CLAUDE}.md`, `docs/**/*.md`, `log.md` | Markdown rendered to HTML in Nyxt (same renderer as the guide); Emacs |
| `dev` | `~/dev/<lang>/README.md`, `tools.list` | same |
| `man` | `apropos -l ''` for titles; `man -Thtml NAME` on open, cached in `~/.cache/vikix/docs/man/` | Nyxt as HTML with `guide.css`; `man` in a terminal |
| `info` | the `dir` files in `/usr/share/info` and `~/.local/share/info`; node list via `info --subnodes -o -` | `makeinfo --html` on open, cached; or Emacs `C-h i` |
| `pkgdoc` | `/usr/share/doc/*/`: `README*`, `NEWS*`, `ChangeLog*`, `*.txt`, `*.md`, `*.html`, and `*.pdf` through `pdftotext` (poppler-utils, in Void), first 20 pages, cached | Nyxt; PDFs in the default viewer |
| `pkg` | `xbps-query -Rs ''` names and short descriptions, installed state, and each package's `homepage` | a card: name, description, installed or not, "install" through `vikix pkg`, and a **Website** link |
| `zeal` | each docset's `docSet.dsidx` (name, type, path), read live, not copied | Zeal, or the docset's HTML in Nyxt |
| `note` | `note`'s own index, joined, not copied | Emacs |
| `web` | links only, never fetched: each package's `homepage` from xbps, the "Docs" and "Manual" links Vikix's own `dev/<lang>/README.md` already list, and a `~/.config/vikix/docs-links` file of the user's own (one URL and title per line) | the default browser; marked with a globe badge so it's clear this one leaves the machine |

PDFs and Markdown shipped by packages are covered by `pkgdoc`: Markdown is rendered like a repo's; PDFs are indexed by their text (`pdftotext`, first 20 pages, so a 400-page manual costs seconds, not minutes) and opened in the PDF viewer at the matching page where the viewer allows (`zathura --page`, `okular -p`).

**Rendering**: one Markdown-to-HTML path (the guide already has one through `lib/md2texi.py` and makeinfo; a plain `markdown` to HTML with `guide.css` is simpler for repos). Man pages through `man -Thtml` (groff's), restyled by the same CSS. Everything a person opens from the catalogue looks like the Vikix guide.

**Search**: FTS5 with BM25, titles weighted over bodies, a boost per source (`vikix` 3, `repo` 2, `dev` 2, the rest 1). Prefix matching so hits appear as you type. The vector table is used only by `vikix docs ask`, built by the `note` machinery, and only for sources the user chose (default: `vikix`, `repo`, `dev`, `note`; never the whole of `/usr/share/doc`, which is big and mostly changelogs).

**Updating**:

| Event | What reindexes |
|---|---|
| end of `vikix update`, `vikix add`, `vikix remove`, `vikix pkg` | `man`, `info`, `pkgdoc`, `pkg`, `zeal` (only if the package set changed: compare `xbps-query -l` hash) |
| daily, by snooze | `repo`, `dev`, `vikix`, by mtime |
| `vikix docs index` | everything, by mtime; `--full` ignores mtimes |
| optional `inotifywait` on `~/src` (`vikix docs watch on`) | the changed file, within a second |

A full first index of a `developer` install should finish in under two minutes; incremental runs in seconds. Both measured and written here.

## The doors

- **`Super+h`.** A searchable menu (the `vikix pick` menu, themed): type, hits appear grouped by source with a badge (`vikix`, `repo`, `man`…), Enter opens in the source's viewer, `Ctrl+Enter` in the other one (terminal for a man page, Emacs for a Markdown file). `Super+h` with text selected searches for it.
- **`vikix:docs` in Nyxt.** The catalogue to browse: a search box, a section per source with counts, recently opened, and for `repo` a page per repository listing its documents. This is also the page `Super+m` → *Vikix guide in the browser* grows into.
- **The command.** `vikix docs find WORDS`, `vikix docs open ID`, `vikix docs ask "QUESTION"` (the `note ask` route over the chosen sources, local model by default), `vikix docs index`, `vikix docs status` (counts per source, last run, size).
- **The agent.** `docs_search(query, sources?)` in `vikix mcp`: hits with excerpts and ids; `docs_read(id)` returns the body as text. Read-only. The agents' guide tells them to use it before answering a how-does-this-work question.
- **Esploro.** A saved search "Docs" whose rows are the catalogue's hits for a query, opened as any file.

## Less typing (decided with Vid 2026-10-03)

The catalogue adds commands, so this is the moment to make every Vikix command shorter to type. Three changes, in `bin/vikix` and `config/bash/vikix.bash`, independent of the rest of this design:

1. **`vk` as a second name for `vikix`.** A symlink in `~/.local/bin`, never a rename: the site, the guides, the agents' skill and every transcript keep saying `vikix`, because `vikix undo` reads better to someone learning. Checked against void-packages: nothing common starts with `vk` except Vulkan's `vkcube` and the game `vkquake`, so there is no clash. StumpWM's `vikix-*` commands stay as they are; a second prefix there would be one more thing to remember.
2. **Unambiguous prefixes, as git and xbps-src allow.** `vk upd` is `vikix update`, `vk doc f runit` is `vikix docs find runit`, `vk th paper` is `vikix theme paper`. The dispatcher in `bin/vikix` matches a prefix against its command list; an ambiguous one (`vk d`: docs, doctor, debug, dictate) prints the candidates and does nothing. Each `bin/vikix-*` does the same for its own subcommands through a shared helper in `lib/common.sh`.
3. **Tab completion.** There is none today. A bash completion in `config/bash/vikix.bash` (and a fish one if fish is in the editors feature) completes commands, subcommands, feature names, theme names, project names and docs ids, read from the same lists the dispatcher uses so they can't drift. Completion is what makes the long names free: `vk the<Tab> pa<Tab>`.

**A rename this forces:** `vikix docs` today downloads the Zeal docsets. The catalogue takes the name, and the download becomes `vikix docs get` (with `vikix docs get LANG` for one), kept working under the old spelling for two releases with a note.

## User stories

- As a newcomer, I want to type "switch off a service" on one key and be shown the Vikix guide's page and `sv(8)` together so that I find the answer without knowing where it lives.
- As a newcomer, I want a man page to open as a readable page in the browser so that I'm not dropped into a pager I don't know how to leave.
- As Vid, I want "websocket" to find the music DESIGN.md in `~/src/vikix` and the Esploro one so that my own decisions are as findable as the system's docs.
- As Vid, I want a new repo in `~/src` to appear in the catalogue by tomorrow without my doing anything, and now if I ask.
- As anyone, I want "ardour" to show whether it's installed and what it is so that the catalogue is also the app store's index.
- As the agent, I want to search and read the machine's docs so that I answer from the man page rather than from memory.
- As anyone, I want to see whose words a hit is (Vikix's, mine, the package's) so that I weigh it right.

## Requirements

### Must have (P0)

1. **The index and the adapters** `vikix`, `repo`, `dev`, `man`, `info`, `pkgdoc`, `pkg`, with FTS5.
   - [ ] `vikix docs index` on a `developer` install finishes in under 2 minutes first time, under 10 s incremental
   - [ ] `vikix docs find runit` returns hits from at least three sources on a Vikix install
2. **`Super+h`** with grouped hits, badges, Enter and `Ctrl+Enter`.
   - [ ] Hits appear within 100 ms of each keystroke
3. **Rendering**: man and Info as HTML in the docs browser, repo Markdown as HTML, all with `guide.css`.
   - [ ] `man sv` opened from a hit reads as a styled page; the terminal route still works
4. **Updating**: reindex at the end of `vikix update`/`add`/`remove` when the package set changed; daily snooze job for the user's folders.
5. **`vikix:docs`**: search box, per-source sections with counts, recent.
6. **The agent**: `docs_search` and `docs_read` in `vikix mcp`; the agents' guide updated.
7. **`vikix docs status`** and a `vikix doctor` line (index present, age, counts).
7a. **Less typing**: the `vk` symlink, prefix matching in `bin/vikix` and the `bin/vikix-*` scripts, bash completion, and `vikix docs get` for the Zeal download with the old spelling kept two releases.
   - [ ] `vk upd`, `vk th paper`, `vk doc f runit` each do what the long form does
   - [ ] `vk d` prints the four candidates and exits 2
   - [ ] `vk the<Tab>` completes; `vk theme <Tab>` lists the themes present

### Should have (P1)

8. `zeal` adapter reading `docSet.dsidx` live.
8a. `web` adapter: homepages, the `dev/` guides' links, the user's links file; globe badge.
8b. PDFs under `/usr/share/doc` and in repos through `pdftotext`, opened at the matching page.
9. `note` adapter joining `note`'s index.
10. `vikix docs ask` over chosen sources, local by default.
11. `vikix docs watch on` with `inotifywait` on `~/src`.
12. Esploro's "Docs" saved search.
13. Hits from Vikix's own `--help` output: every `bin/vikix-*` usage block, indexed as `source: vikix`, kind `command`.

### Later (P2)

14. OCR for scanned PDFs (tesseract).
15. The children's account: a catalogue limited to the education bundle's docs.
16. Esperanto and other languages: the guide's translations indexed beside the English, chosen by the desktop's language.

## What success looks like

- `Super+h` is used daily (a count in `vikix docs status`); the only honest measure of "at our fingertips".
- The agent's answers cite `docs_read` ids when asked how something on the machine works, visible in `vikix mcp status`'s last calls.
- Index freshness: no document older than 24 hours on disk is missing from the catalogue, checked by a test that touches a file in `~/src` and finds it after the sweep.

## Open questions

Blocking:
- **Which renderer for repo Markdown.** (engineering) `lib/md2texi.py` exists for the guide; a direct Markdown-to-HTML step is simpler for a thousand READMEs. Python `markdown` is in Void; check whether it handles GitHub tables and fenced code well enough, else `cmark`.
- **Is `groff`'s `man -Thtml` present on a base Void install,** or does `mandoc` provide man? (Answered 2026-10-03, building the commands' man pages: mandoc. `base.list` installs `mdocml`, `man` is a link to `mandoc`, it reads only `MANPATH` and `/etc/man.conf`, and its index is `makewhatis`; so `mandoc -Thtml`.) (one command: `man -Thtml sv | head`) `mandoc -Thtml` is the alternative.

Non-blocking:
- `Super+h` is free in `*vikix-bindings*` today; confirm it isn't taken by a plugin.
- Where the daily job lives: `snooze` (Void's cron) under `~/.local/share/vikix/sv`, or a timer in StumpWM. Proposed: snooze, so it runs without the desktop.
- Should `pkgdoc` index bodies or titles only? Bodies make "changelog noise" in hits; proposed: titles and the first 300 characters only, bodies for `README*` alone.

## Phasing

**Phase 0, a day:** the `docs` table and FTS5 over `vikix`, `repo`, `dev`, `man` titles; `vikix docs find`; `Super+h` opening in the existing viewers. No rendering yet. Prove the hits are good.

**Phase 1:** P0 items 1–7.

**Phase 2:** P1, Zeal and notes first.

## Risks

- **Man page HTML is ugly.** groff's HTML is dated; `guide.css` will have to work hard, or `mandoc -Thtml` produces cleaner markup. Test both on `sv(8)` and `xbps-install(1)` before deciding.
- **Index size.** Bodies of every man page and `/usr/share/doc` could be hundreds of MB. FTS5 with `detail=none` and excerpts kept separately keeps it small; measure on a `developer` install.
- **Two indexes drift.** `note` and `docs` are both SQLite; join, don't copy, or they will disagree.
