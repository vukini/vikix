---
name: doc-to-epub
description: Convert a Word document (.docx) or Markdown into an EPUB tuned for legibility on small (6-7") e-ink readers. Use when the user wants a .docx or Markdown (or similar) turned into an .epub, especially for reading on a dedicated e-reader/tablet like a Kindle, Kobo, BOOX or Android e-ink device. Also use to fix an existing EPUB where tables, callout boxes, code listings or other formatting "collapse" or don't render on an e-reader app (e.g. xReaderPro, Moon+ Reader, FBReader).
---

# Doc-to-EPUB (small-screen e-ink tuning)

Converts a .docx (or Markdown) into a valid, legible EPUB and works around
real rendering bugs found in e-ink reader apps (confirmed against
xReaderPro on a BigMe 7" device, and FBReader; the issues are common
across many Android/e-ink reader engines).

This skill is made from Vikix's `lib/publish/` (`vikix publish skill`):
`scripts/fix_tables.py` and `references/epub.css` are the same files the
laptop's pipeline uses. Change them there, not here.

## On a Vikix machine: use `vikix publish`

If `vikix publish status` works, the whole pipeline below is one command,
checked:

```bash
mkdir book && cd book
printf 'title: "..."\nauthor: "..."\nlang: en-GB\nchapters: [../INPUT.docx]\n' > publish.yml
vikix publish . epub        # out/NAME.epub: pandoc, the fixes, epubcheck
vikix publish . check       # also the PDF and the spelling
```

For a Markdown book, `vikix publish new DIR` starts one. Anywhere else,
follow the workflow.

## Workflow

1. **Convert with pandoc** (docx -> epub3 directly, do not round-trip
   through markdown — it's lossier for tables/formatting), and **always
   with `--no-highlight`** (bug 4 below):

   ```bash
   pandoc INPUT.docx -o OUTPUT.epub \
     --css=references/epub.css \
     --toc --toc-depth=2 \
     --no-highlight \
     --metadata title="..." \
     --metadata author="..." \
     --metadata lang=en
   ```

2. **Unzip and post-process** — pandoc's raw output has problems that
   only show up on real e-readers, not in a desktop/browser preview:

   - Unzip: `unzip -o OUTPUT.epub -d build/`
   - Run `scripts/fix_tables.py build/` (see below for what it does)
   - Rezip preserving the mimetype-first-uncompressed rule:
     ```bash
     cd build
     rm -f ../OUTPUT.epub
     zip -X -q ../OUTPUT.epub mimetype
     zip -X -rq ../OUTPUT.epub META-INF EPUB -x mimetype
     ```

3. **Validate** before delivering:
   ```python
   from epubcheck import EpubCheck  # pip install --break-system-packages epubcheck
   r = EpubCheck("OUTPUT.epub")
   assert r.valid, r.messages
   ```
   (`epubcheck` python package wraps the real Java epubcheck tool and is
   the authoritative validator — always run it, never assume the file is
   fine just because pandoc didn't error. It does not see bug 4.)

## Known e-ink rendering bugs and fixes

### 1. Word "repeat header row" turns every table row into a `<th>` inside `<thead>`

If a docx table was formatted in Word with "repeat as header row at the
top of each page" applied to more than the first row (common when someone
selects the whole table and turns on header-repeat), pandoc emits **every
row** as `<th>` inside a single `<thead>`, with an **empty `<tbody>`**.
This is syntactically valid HTML/EPUB (passes epubcheck) but many e-ink
reader engines choke on it — the whole table renders as a squished,
border-less, illegible block ("collapsed").

Symptom: epubcheck says valid, browser preview looks okay-ish, but the
table is unreadable/collapsed on the actual device.

Detection: `thead` has >1 `<tr>` and `tbody` is empty or missing.

### 2. Many e-ink reader apps don't support `<table>` layout at all

Even after fixing (1) so the table markup is textbook-correct
(one header row in `<thead>`, data rows as `<td>` in `<tbody>`), some
reader apps (confirmed: xReaderPro) still fail to render tables
acceptably on a 7" screen — no amount of correct markup or CSS fixes this,
because the app's rendering engine just doesn't lay out `<table>` well in
reflowable mode.

**Fix that actually works: stop using `<table>` for multi-column data
grids entirely.** Convert each table into a stack of "row cards" — one
`<div class="row-card">` per original row, containing one
`<p class="field">` per column with a `<span class="field-label">`
holding the column header. This is pure block/paragraph markup, which
every reader (e-ink or otherwise) renders correctly. See
`scripts/fix_tables.py` — it detects multi-column tables (via colgroup
column count) and converts them to row-cards automatically; single-column
"box" tables (see #3) are converted differently.

### 3. Docx "callout boxes" become single-cell tables

Boxed asides in Word (e.g. a bordered "Note" or "Key takeaway" box) are
often implemented as a one-cell, one-column table
(`<table><thead><tr><th>...</th></tr></thead><tbody></tbody></table>`,
colgroup width 100%). Table-cell CSS (borders, background) is unreliable
on e-ink apps the same way as #2, so the box's visual styling silently
disappears even though the text is there.

Fix: convert these into `<div class="aside">` with normal border/background
CSS — reliable on divs, unreliable on table cells.

`scripts/fix_tables.py` distinguishes the two cases by column count:
a single 100%-width column -> `.aside` div; more than one column -> stacked
`.row-card` blocks.

### 4. Highlighted code loses its spaces

pandoc's syntax highlighting (on by default for fenced code with a
language) wraps every token of code in a `<span>`. Several reader apps
lay those spans out without the spaces between them: indentation goes,
columns in program output no longer line up, and Python becomes wrong.
The markup is valid; epubcheck passes it.

Fix: `--no-highlight` on every pandoc run, and `references/epub.css`,
which restates `white-space: pre-wrap` on both `pre` and `pre code` (some
readers reset the inner one) and sets code upright in an installed
monospace. Check: no `<span` inside any `<pre><code>`.

Some old readers (desktop FBReader 0.99) still set code in their own
italic and squeeze runs of spaces whatever the book says; that is the
reader, not the book. Foliate, KOReader and the BOOX's own reader show it
right.

## CSS baseline for 7" screens

`references/epub.css` has the full stylesheet. Key choices, tune per book:

- Body font ~130% size, serif, line-height 1.5 (generous for small
  screens; most readers let the user override anyway, this is just a
  sane default)
- Sans-serif headings, `h1` starts a new page (`page-break-before: always`)
- `pre` and `pre code`: `pre-wrap` (kept spaces, long lines wrapped),
  upright monospace, `page-break-inside: avoid`
- `.aside` boxes: bordered div, light background, `page-break-inside: avoid`
- `.row-card` / `.field-label`: bordered card per table row, uppercase
  small-caps label above each value — this is what real tabular data
  becomes after the table->card conversion
- No real `<table>` CSS is needed if `fix_tables.py` has already removed
  all tables; keep a minimal table style anyway as a defensive fallback
  in case a table slips through

## Checklist before delivering

- [ ] `grep -l "<table>" build/EPUB/text/*.xhtml` returns nothing (all
      tables converted, OR intentionally kept because they're simple
      enough — but default to converting all of them, it's cheap and
      the failure mode on e-ink devices is severe)
- [ ] No `<span` inside any `<pre><code>` (built with `--no-highlight`)
- [ ] epubcheck reports valid
- [ ] Skim 2-3 chapters' xhtml for any remaining single-row `<thead>`
      with multiple `<tr>` inside it
- [ ] Deliver with SendUserFile, and if a folder is connected, also
      `device_commit_files` back to the source file's folder
