# Vikix Publish — design

Books, sites and EPUBs built on the laptop by one command, checked before they leave, the same way for every project.

Drafted 2026-10-04 for TODO item 79. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

Vid makes about twenty-eight Living Series projects: interactive single-file sites, EPUB books (the SQLite book's first draft is complete; the Toki Pona and Esperanto books are in progress), textbooks with art, and apps. Vikix is meant to be the workshop they're made in (`TODO.md`, "Vikix as the workshop for the Living Series"), and `vikix project build` and `check` already find a project's `make` targets. But nothing on the laptop makes a book:

- The EPUB pipeline that works on real e-ink readers (pandoc, then a fix for tables that collapse on 7" screens, then epubcheck) exists only as a Claude skill, `doc-to-epub`, run in the cloud. On the laptop it is a memory.
- There is no `vikix add publish`: pandoc and Typst are only in `cli-extras`, epubcheck isn't in Void at all, Calibre and Sigil aren't installed, and the fonts a book needs (an Arabic face, a serif for print) aren't either.
- Each project builds its own way, so "is this book finished?" has twenty-eight answers.
- Spell-checking in Esperanto or Arabic isn't possible: Void has `hunspell` but no dictionaries for them (none for `en_GB` either).

## What it is

1. **A feature, `vikix add publish`**: the tools, the fonts, the dictionaries, pinned where Void lacks them.
2. **One pipeline, `lib/publish/`**: a Makefile every project includes, with targets `epub`, `pdf`, `site`, `check` and `publish`, and the scripts behind them. The `doc-to-epub` skill's fixes move here, so the laptop and the cloud run the same code.
3. **A command, `vikix publish`**: build every format a project declares, check them, write the log line, send to a reader.
4. **A house style**, kept in the Living Series repo's `shared/`, with a neutral default in Vikix for anyone else.

## How it is built

```
 ~/src/living-series/<book>/
   book.md (or chapters/*.md, or a .docx)   the text, Vid's
   publish.yml                              title, author, lang, formats, cover
   Makefile:  include $(VIKIX_PUBLISH)/publish.mk
   out/                                     built, never committed
          │
          ▼  make epub pdf site check
 ~/.local/share/vikix/publish/   (linked from this repo's lib/publish/)
   publish.mk        the targets
   epub.sh           pandoc → fix-tables.py → zip in the right order → epubcheck
   pdf.sh            pandoc → Typst → PDF, with the template and fonts
   site.sh           the interactive-site build (already each project's own)
   check.sh          epubcheck, Typst's warnings, a link check, hunspell
   fix-tables.py     from the doc-to-epub skill: tables → row cards for e-ink
   styles/           default epub.css, default.typ; the Living Series' own in shared/
          │
          ▼  vikix publish NAME
 out/<book>.epub, .pdf, site/ ; a line in log.md ; optionally → the e-reader
```

**The feature.** `packages/optional/publish.list`: `pandoc` 3.6, `typst` 0.15.1, `calibre` 9.14 (`ebook-convert`, `ebook-viewer`, `ebook-device` for sending), `sigil` 2.4 (for opening an EPUB and fixing one thing by hand), `foliate` (already in `apps.list`), `zathura`, `mupdf`, `img2pdf`, `tesseract-ocr`, `cmark`, `graphviz`, `gnuplot`, `inkscape` (covers), `hunspell`; fonts `amiri-font` (Arabic), `noto-fonts-ttf`, `dejavu-fonts-ttf`, `font-ibm-plex-ttf` (a print serif that is in Void). Not in Void, so pinned and checksummed from their releases as Ollama is: **epubcheck** (the Java jar; `lang-java`'s OpenJDK 21 runs it; it is the authoritative validator and nothing else is), the **hunspell dictionaries** `en_GB`, `eo` and `ar` from LibreOffice's dictionaries repository, and **Libertinus** if a classic book serif is wanted beyond Plex. Esperanto needs no special font: every face here has the six Latin-3 letters.

**The pipeline.** `publish.mk` reads `publish.yml` (title, author, lang, formats, cover, chapters in order) and provides:

- `make epub`: pandoc to EPUB 3 with the style's CSS, then `fix-tables.py` (the skill's two fixes: a `<thead>` holding every row, and `<table>` itself on small screens, turned into row cards), then the zip with `mimetype` first and uncompressed, then epubcheck. A build that fails epubcheck is not a build.
- `make pdf`: pandoc's Typst writer, then `typst compile` with the style's template and fonts; `make watch` runs `typst watch` beside zathura for live preview.
- `make site`: calls the project's own site build when it has one (the interactive sites already do).
- `make check`: everything above without writing outputs, plus a link check over the site and `hunspell -d LANG` over the text in the language `publish.yml` names, with the project's own word list in `words.txt`.
- `make publish`: `check`, then all formats into `out/`, then a dated line in `log.md`.
- A `.docx` source goes through the same `epub` target (pandoc reads it directly; no Markdown round trip, which loses tables), so the skill's case is covered.

**The command.** `vikix publish NAME` is `vikix project build` with the pipeline's targets and a few more: `vikix publish NAME --send` copies the EPUB to a connected reader (`ebook-device` for Kindle and Kobo, a plain copy for a BOOX mounted by udiskie; this is TODO 26, Calibre as a feature, done here), `vikix publish new NAME` makes a project with `publish.yml` and the Makefile line, `vikix publish doctor` says which tools, fonts and dictionaries are present.

**The skill and the laptop agree.** `fix-tables.py` and `epub.css` live in this repo; the `doc-to-epub` skill is changed to call `vikix publish` when it runs on a Vikix machine and to carry the same two files for when it doesn't. One source, as `SKILL.md` and `AGENTS.md` are.

**House style.** Vikix ships a neutral `styles/default` (readable on e-ink, Plex for print). The Living Series' own CSS, Typst template and cover SVG live in `~/src/living-series/shared/publish/`, named in each project's `publish.yml` with `style: ../shared/publish`. Vikix never carries the series' look.

## Goals

1. **One command makes a book.** `vikix publish sqlite-book` produces an EPUB that passes epubcheck and a PDF from the same text, on the laptop, offline.
2. **Nothing leaves unchecked.** `make publish` refuses an EPUB epubcheck rejects, a PDF Typst warned about, a site with a dead link, or a chapter with spelling errors not in `words.txt`.
3. **Every project builds the same way.** Twenty-eight Makefiles that are one `include` line each; `vikix project build` and `check` already know what to run.
4. **The e-ink fixes are code, not a memory.** What the skill learned on a 7" screen runs on every build.
5. **Esperanto and Arabic are first-class.** Spell-checked, set in a face that has the letters, right-to-left where it should be.

## Non-goals (this version)

- **Not a word processor or an editor.** The text is Markdown (or a `.docx` someone else wrote) in Emacs; Sigil is there for touching an EPUB by hand, not for writing.
- **Not Kindle's old formats.** Amazon takes EPUB now; `kindlegen` is dead and isn't in Void. MOBI only through `ebook-convert` if someone asks.
- **Not a store or a storefront.** Uploading to KDP, Leanpub or a website is the author's step; `out/` is where the files wait for it.
- **Not LaTeX.** `texlive` is in Void and huge; Typst does what the books need. A project that wants LaTeX adds it itself.
- **Not the house style in Vikix.** The default is plain on purpose.

## User stories

- As Vid, I want `vikix publish sqlite-book` to give me an EPUB and a PDF that pass their checks so that the first draft becomes a file I can send.
- As Vid, I want a new book project to start with the Makefile and `publish.yml` already right so that the twenty-ninth project builds like the others.
- As Vid, I want the table fix from the skill applied on every build so that I never again see a collapsed table on the BOOX.
- As the author of the Esperanto textbook, I want `make check` to spell-check in Esperanto with my own word list so that proper nouns don't drown the real errors.
- As the author of anything with Arabic, I want it set right-to-left in a proper face without configuring fonts.
- As anyone, I want `vikix publish NAME --send` to put the book on the reader plugged in so that reading the draft on the device is one step.
- As the agent, I want `make check` to be the gate before I say a book is done.

## Requirements

### Must have (P0)

1. **The feature**: `optional/publish.list`, the `features.list` row, the README row; epubcheck and the three dictionaries pinned and checksummed; `vikix publish doctor`.
   - [ ] On the VM: `vikix add publish` then `vikix publish doctor` reports every tool, font and dictionary present
2. **`publish.mk`** with `epub`, `pdf`, `check`, `publish`, `watch`; `fix-tables.py` and the default `epub.css` moved from the skill; `publish.yml` read by a small Python helper.
   - [ ] A test book (`tests/publish/`: ten pages, two tables, an Esperanto paragraph, an Arabic one) builds an EPUB that passes epubcheck and a PDF with no Typst warnings
   - [ ] The test's tables arrive as row cards, not `<table>`
3. **`vikix publish NAME`**, `new`, `--send`; the log line.
4. **`check`**: epubcheck, Typst warnings, the link check, hunspell with `words.txt`.
5. **The skill agrees**: `doc-to-epub` carries the same `fix-tables.py` and CSS and calls `vikix publish` on a Vikix machine.
6. **Fonts and direction**: Amiri for Arabic, `dir: rtl` through to both pandoc and Typst when `lang` is Arabic; Plex as the print default.

### Should have (P1)

7. `site` target wired to the interactive sites' existing build and link check; the sites' evidence rule (`make check` regenerating quoted outputs) called from the same `check`.
8. Covers: an SVG template rendered by Inkscape to the EPUB's cover and the PDF's first page.
9. `vikix publish all`: every project with a `publish.yml`, in one run, with a table of what passed.
10. A docs-catalogue adapter for `out/` (the built books searchable from `Super+F2`), and an Esploro "Publish…" command on a project folder.
11. `--send` to a phone's reading app over KDE Connect when TODO 18 exists.

### Later (P2)

12. The `vale` prose linter (3.13 in Void) with a Living Series style: house words, banned words, sentence length.
13. OCR'd scans into Markdown (`tesseract`, in Void) for the old material.
14. Audiobook from the EPUB through the local voice (`piper`, TODO 25).

## What Void has (checked 2026-10-04)

| Package | Version | Note |
|---|---|---|
| `pandoc` | 3.6 | |
| `typst` | 0.15.1 | |
| `calibre` | 9.14.0 | `ebook-convert`, `ebook-viewer`, `ebook-device` |
| `sigil` | 2.4.0 | EPUB editor |
| `zathura`, `mupdf` | current | PDF viewers; `zathura --page` for the catalogue |
| `img2pdf`, `tesseract-ocr`, `cmark`, `graphviz`, `gnuplot`, `inkscape`, `scribus` | current | |
| `hunspell` | 1.7.2 | no dictionaries for `en_GB`, `eo`, `ar` in Void |
| `amiri-font` | 1.003 | Arabic |
| `font-ibm-plex-ttf` | 6.4.0 | the print serif |
| `noto-fonts-ttf`, `dejavu-fonts-ttf`, `font-iosevka` | current | |
| `vale` | 3.13.0 | P2 |
| `texlive` | 2026 | not used |
| `epubcheck` | not in Void | the Java jar, pinned; `lang-java` supplies Java |
| `kindlegen` | not in Void | dead upstream; not wanted |
| `hunspell-eo`, `hunspell-ar`, `hunspell-en_GB` | not in Void | LibreOffice's dictionaries repository, pinned |
| Libertinus, Crimson | not in Void | releases, if wanted beyond Plex |

## Open questions

Blocking:
- **epubcheck without Java for people who don't take `lang-java`?** (Vid) Options: make `publish` need `java` (`features.list` can say so), or ship the Python wrapper, which still needs Java underneath. Proposed: `publish` needs `java`, stated plainly.
- **Which source format for the Living Series books: Markdown in the repo, or the `.docx` files some drafts are in?** (Vid) The pipeline takes both; the Makefile needs to know which to prefer when both exist.

Non-blocking:
- Plex or Libertinus as the default print face: a one-page sample of each, in the VM.
- Whether `fix-tables.py` should be the default for every EPUB or only when `publish.yml` says `eink: true`. Proposed: default on, since the row cards read fine on large screens too.
- The dictionaries' pin: LibreOffice's repository moves; pin a commit and move it deliberately, as for plugins.

## Phasing

**Shipped 2026-10-04: Phase 0.** `vikix add publish` (needs `java`), `vikix publish [NAME|DIR] [epub|pdf|check]`, `setup`, `status`, `uninstall`; `lib/publish/build` does the work in Python, not in Make, because chapter names have spaces and dashes (`01 — A Database in Ten Minutes.md`), and `publish.mk` only calls it. Two changes from below: `publish.yml` is pandoc's own metadata file plus Vikix's `name`, `chapters` and `mainfont`, so pandoc reads it as it is; and Arabic goes in as Amiri after the book's face in every PDF, not only in Arabic books (pandoc's Typst template takes one face, so the list goes in through its quotes). Living in SQL (27 chapters, 9 with tables): EPUB 185 KB, epubcheck no errors and no warnings, every table now row cards; PDF 141 pages, no Typst warnings. epubcheck takes most of a build's time (Java starting, a minute on a busy machine). Not yet read on the BOOX. Same day, after Vid read it in FBReader: the EPUB had pandoc's code highlighting on, whose spans e-ink readers lay out without the spaces between them (Living in Python had found this; its Makefile says `--no-highlight` is required). Now built with `--no-highlight`, with Living in Python's `epub.css` (code upright and `pre-wrap` restated on `pre code`), and a build with markup inside code is refused. FBReader 0.99 (Void's, from 2012) still sets code in its own italic and collapses runs of spaces whatever the book says, no-break and figure spaces included; Foliate shows the book as it should be.

**Shipped too, 2026-10-04: the spelling and `--send`.** The spelling runs each chapter through pandoc with `lib/publish/spell.lua`, which keeps the prose of one language (code, raw HTML and maths out; a passage with a `lang` of its own goes to that language), then `hunspell -l` with the dictionary and `words.txt`. Two changes from below: a word with a digit in it or of one letter is never reported (a name or a number: `FTS5`, `0x1000`, Part V), and a curly apostrophe is folded to a straight one so `CTE’s` is `CTE`. Living in SQL has 87 words to look at, most of them terms (`autocommit`, `pragma`), and some real: the book mixes `finalize` with `parameterised`. `--send` tries a drive (Kindle `documents/`, Kobo, a `Books` folder), then MTP through `gio` (gvfs-mtp is in the base), then one adb device; Calibre's `ebook-device` isn't needed for any of them.

**And `new` and the skill (2026-10-04).** `vikix publish new DIR` starts a book that builds at once. The skill's case: the `doc-to-epub` skill is synced down from claude.ai, so the laptop can't change it, and a test diffing it against the repo would only ever fail. Instead its `SKILL.md` lives in `lib/publish/skill/`, `vikix publish skill` zips it with `fix-tables.py` and `epub.css` for Vid to upload, and `tests/publish.sh` compares the synced copy with the repo once it is the uploaded one (its `SKILL.md` names `vikix publish skill`). The skill now says `--no-highlight` (its fourth bug) and, on a Vikix machine, to use `vikix publish` (a `.docx` goes in through `chapters:`).

**Phase 0, a day:** `vikix add publish` with the Void packages and the epubcheck jar; `publish.mk` with `epub` and `check`; the SQLite book built end to end and read on the BOOX. If the EPUB is good there, the rest is plumbing.

**Phase 1:** P0 items 1–6, the test book, the skill made to agree.

**Phase 2:** P1, the sites' `check` first, then covers and `publish all`.

## Risks

- **pandoc's Typst writer is young.** Footnotes, tables and images may need the template's help; the test book exercises each, and the fallback is pandoc → HTML → Typst's `html` import, or a hand-kept Typst file per book.
- **Calibre is large** (several hundred MB with Qt). It carries `--send` and `ebook-convert`; if that's too much for the feature, `--send` becomes a plain copy and Calibre moves to its own feature as TODO 26 first had it.
- **Two copies of the e-ink fix.** The skill and the repo must stay the same file; a test diffs them when the skill is in reach, or the skill fetches it from GitHub at a pinned commit.
